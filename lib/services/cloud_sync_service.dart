import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/progress_snapshot.dart';
import 'log.dart';
import 'persistence_service.dart';

/// The signed-in player, as cloud save sees them.
@immutable
class CloudUser {
  final String uid;
  final String? email;
  final String? name;
  const CloudUser({required this.uid, this.email, this.name});
}

/// Where cloud saves live. [FirebaseCloudBackend] in the app; tests use a
/// fake.
abstract class CloudBackend {
  CloudUser? get currentUser;
  Stream<CloudUser?> userChanges();

  /// Shows the sign-in sheet. Null if the player closed it.
  Future<CloudUser?> signIn();
  Future<void> signOut();

  /// The saved progress JSON, or null if this player has none yet.
  Future<Map<String, dynamic>?> load(String uid);
  Future<void> save(String uid, Map<String, dynamic> progress);

  /// Deletes the saved progress and the account itself.
  Future<void> deleteAccount(String uid);
}

/// What the Settings screen shows about cloud save.
@immutable
class CloudSyncState {
  /// This build can sync at all (false in tests and on unsupported platforms).
  final bool available;
  final CloudUser? user;
  final bool syncing;
  final DateTime? lastSynced;

  /// The last attempt failed (usually offline). It retries on the next change
  /// or launch.
  final bool failed;

  const CloudSyncState({
    this.available = false,
    this.user,
    this.syncing = false,
    this.lastSynced,
    this.failed = false,
  });

  bool get signedIn => user != null;

  CloudSyncState copyWith({
    CloudUser? user,
    bool clearUser = false,
    bool? syncing,
    DateTime? lastSynced,
    bool? failed,
  }) =>
      CloudSyncState(
        available: available,
        user: clearUser ? null : (user ?? this.user),
        syncing: syncing ?? this.syncing,
        lastSynced: lastSynced ?? this.lastSynced,
        failed: failed ?? this.failed,
      );
}

/// How a sign-in attempt ended.
enum SignInResult { signedIn, cancelled, failed }

/// Optional cloud save: once the player signs in, their progress is merged
/// with the copy in the cloud (nothing either side earned is lost) and kept
/// in sync after every change, at launch and when the app comes back.
///
/// The game never waits on it. Everything works offline and signed out; a
/// failed sync just tries again later.
class CloudSyncService {
  final PersistenceService? _persistence;
  final CloudBackend? _backend;
  final Duration _debounce;

  /// Called after cloud progress was merged into local storage, so the UI
  /// can re-read it.
  VoidCallback? onLocalChanged;

  final ValueNotifier<CloudSyncState> state;

  StreamSubscription<CloudUser?>? _sub;
  Timer? _pushTimer;
  Future<void>? _running;
  bool _again = false;
  bool _applying = false;

  CloudSyncService(
    PersistenceService persistence,
    CloudBackend backend, {
    Duration debounce = const Duration(seconds: 4),
  })  : _persistence = persistence,
        _backend = backend,
        _debounce = debounce,
        state = ValueNotifier(const CloudSyncState(available: true));

  /// Cloud save switched off: Settings hides it and every call is a no-op.
  CloudSyncService.off()
      : _persistence = null,
        _backend = null,
        _debounce = Duration.zero,
        state = ValueNotifier(const CloudSyncState());

  bool get available => _backend != null;

  /// Starts watching the sign-in state and syncs if already signed in.
  void init() {
    final backend = _backend;
    if (backend == null || _sub != null) return;
    _sub = backend.userChanges().listen((user) {
      final wasSignedIn = state.value.signedIn;
      state.value = user == null
          ? state.value.copyWith(clearUser: true, failed: false)
          : state.value.copyWith(user: user);
      if (user != null && !wasSignedIn) sync();
    }, onError: (Object e) => Log.w('Cloud', 'auth state', e));
  }

  Future<SignInResult> signIn() async {
    final backend = _backend;
    if (backend == null) return SignInResult.failed;
    try {
      final user = await backend.signIn();
      if (user == null) return SignInResult.cancelled;
      // The auth listener may not have fired yet.
      if (!state.value.signedIn) {
        state.value = state.value.copyWith(user: user);
        unawaited(sync());
      }
      return SignInResult.signedIn;
    } catch (e) {
      Log.w('Cloud', 'sign-in failed', e);
      return SignInResult.failed;
    }
  }

  /// Signs out. Progress stays on this device.
  Future<void> signOut() async {
    _pushTimer?.cancel();
    try {
      await _backend?.signOut();
    } catch (e) {
      Log.w('Cloud', 'sign-out', e);
    }
    state.value = state.value.copyWith(clearUser: true, failed: false);
  }

  /// Deletes the cloud copy and the account. Progress stays on this device.
  /// Returns false if it failed (try again online).
  Future<bool> deleteAccount() async {
    final backend = _backend;
    final user = state.value.user;
    if (backend == null || user == null) return false;
    _pushTimer?.cancel();
    try {
      await _running;
      await backend.deleteAccount(user.uid);
      state.value = state.value.copyWith(clearUser: true, failed: false);
      return true;
    } catch (e) {
      Log.w('Cloud', 'delete account failed', e);
      return false;
    }
  }

  /// Progress changed locally: sync a few seconds later, so a burst of
  /// changes (a win saves several things) becomes one write.
  void schedulePush() {
    if (_backend == null || _applying || !state.value.signedIn) return;
    _pushTimer?.cancel();
    _pushTimer = Timer(_debounce, sync);
  }

  /// Merges local and cloud progress and saves the result on both sides.
  /// Overlapping calls are folded into one more run afterwards.
  Future<void> sync() {
    if (_running != null) {
      _again = true;
      return _running!;
    }
    final run = _sync().whenComplete(() {
      _running = null;
      if (_again) {
        _again = false;
        sync();
      }
    });
    _running = run;
    return run;
  }

  Future<void> _sync() async {
    final backend = _backend;
    final persistence = _persistence;
    final user = state.value.user;
    if (backend == null || persistence == null || user == null) return;
    state.value = state.value.copyWith(syncing: true);
    try {
      final local = persistence.exportSnapshot();
      final raw = await backend.load(user.uid);
      final remote = raw == null ? null : ProgressSnapshot.fromJson(raw);
      final merged = remote == null ? local : local.merge(remote);
      if (merged != local) {
        _applying = true;
        try {
          await persistence.importSnapshot(merged);
          onLocalChanged?.call();
        } finally {
          _applying = false;
        }
      }
      if (merged != remote) await backend.save(user.uid, merged.toJson());
      state.value = state.value
          .copyWith(syncing: false, failed: false, lastSynced: DateTime.now());
    } catch (e) {
      Log.w('Cloud', 'sync failed', e);
      state.value = state.value.copyWith(syncing: false, failed: true);
    }
  }

  void dispose() {
    _pushTimer?.cancel();
    _sub?.cancel();
  }
}
