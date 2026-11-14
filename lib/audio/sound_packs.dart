import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../services/log.dart';
import '../services/platform_support.dart';

/// Where a store-delivered sound pack stands on this device.
enum PackStatus {
  unknown,
  notInstalled,
  pending,
  downloading,
  transferring,
  completed,
  failed,
  canceled,
  waitingForWifi,
  needsConfirmation,

  /// The platform can't deliver packs here (sideloaded/debug build, desktop,
  /// tests). Bundled sounds still work.
  unavailable,
}

@immutable
class PackState {
  final PackStatus status;
  final int downloaded;
  final int total;

  const PackState(this.status, {this.downloaded = 0, this.total = 0});

  bool get ready => status == PackStatus.completed;
  bool get inProgress =>
      status == PackStatus.pending ||
      status == PackStatus.downloading ||
      status == PackStatus.transferring;
  double get progress => total > 0 ? (downloaded / total).clamp(0.0, 1.0) : 0.0;
}

/// The extra ambience/music loops are delivered by the stores after install:
/// Play Asset Delivery fast-follow packs on Android, On-Demand Resources
/// (prefetched) on iOS. This wraps the native bridge
/// (`MainActivity.kt` / `AppDelegate.swift`): per-pack state for the UI and
/// file-path resolution for the audio engine.
class SoundPacks {
  SoundPacks._();
  static final SoundPacks instance = SoundPacks._();

  static const List<String> packs = ['ambient', 'music'];
  static const _channel = MethodChannel('decant/sound_packs');
  static const _events = EventChannel('decant/sound_packs/events');

  final Map<String, ValueNotifier<PackState>> _states = {
    for (final p in packs)
      p: ValueNotifier(const PackState(PackStatus.unknown)),
  };
  final Map<String, String> _paths = {};
  StreamSubscription<dynamic>? _sub;
  bool _started = false;

  bool get _supported => isPhone;

  ValueListenable<PackState> stateOf(String pack) => _states[pack]!;

  /// Start listening for progress and nudge any pack that isn't on the device
  /// yet (the store usually has it downloading already).
  Future<void> start() async {
    if (_started) return;
    _started = true;
    if (!_supported) {
      for (final n in _states.values) {
        n.value = const PackState(PackStatus.unavailable);
      }
      return;
    }
    _sub = _events.receiveBroadcastStream().listen(_onEvent, onError: (_) {});
    for (final p in packs) {
      await refresh(p);
      final s = _states[p]!.value.status;
      if (s != PackStatus.completed && s != PackStatus.unavailable) {
        unawaited(fetch(p));
      }
    }
  }

  Future<void> refresh(String pack) async {
    try {
      final m = await _channel.invokeMapMethod<String, dynamic>('state', {
        'pack': pack,
      });
      if (m != null) _apply(m);
    } catch (_) {
      _states[pack]?.value = const PackState(PackStatus.unavailable);
    }
  }

  /// Ask the store to download [pack] now (no-op if it's already on disk).
  Future<void> fetch(String pack) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<bool>('fetch', {'pack': pack});
      await refresh(pack);
    } catch (_) {}
  }

  /// Absolute path of [file] inside [pack], or null if the pack isn't on the
  /// device yet.
  Future<String?> resolve(String pack, String file) async {
    final key = '$pack/$file';
    final cached = _paths[key];
    if (cached != null) return cached;
    if (!_supported) return null;
    try {
      final path = await _channel.invokeMethod<String>('resolve', {
        'pack': pack,
        'file': file,
      });
      if (path != null) {
        _paths[key] = path;
        if (!_states[pack]!.value.ready) {
          _states[pack]!.value = const PackState(PackStatus.completed);
        }
      }
      return path;
    } catch (e) {
      Log.w('SoundPacks', 'resolve($key) failed', e);
      return null;
    }
  }

  void _onEvent(dynamic e) {
    if (e is Map) _apply(e.cast<String, dynamic>());
  }

  void _apply(Map<String, dynamic> m) {
    final pack = m['pack'] as String?;
    final n = _states[pack];
    if (n == null) return;
    final status = PackStatus.values.firstWhere(
      (s) => s.name == m['status'],
      orElse: () => PackStatus.unknown,
    );
    if (status != PackStatus.completed) {
      _paths.removeWhere((k, _) => k.startsWith('$pack/'));
    }
    n.value = PackState(
      status,
      downloaded: (m['downloaded'] as num?)?.toInt() ?? 0,
      total: (m['total'] as num?)?.toInt() ?? 0,
    );
  }

  @visibleForTesting
  void dispose() => _sub?.cancel();
}
