import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:decant/l10n/app_localizations.dart';
import 'package:decant/logic/challenge.dart';
import 'package:decant/models/challenge_stats.dart';
import 'package:decant/models/daily_stats.dart';
import 'package:decant/models/level_result.dart';
import 'package:decant/models/play_stats.dart';
import 'package:decant/models/progress_snapshot.dart';
import 'package:decant/services/cloud_sync_service.dart';
import 'package:decant/services/persistence_service.dart';
import 'package:decant/state/providers.dart';
import 'package:decant/ui/widgets/cloud_save_section.dart';

/// An in-memory cloud.
class FakeBackend implements CloudBackend {
  final docs = <String, Map<String, dynamic>>{};
  final _users = StreamController<CloudUser?>.broadcast();
  CloudUser? user;
  CloudUser? nextSignIn = const CloudUser(uid: 'u1', email: 'p@example.com');
  bool offline = false;
  int saves = 0;

  @override
  CloudUser? get currentUser => user;

  @override
  Stream<CloudUser?> userChanges() => _users.stream;

  @override
  Future<CloudUser?> signIn() async {
    user = nextSignIn;
    _users.add(user);
    return user;
  }

  @override
  Future<void> signOut() async {
    user = null;
    _users.add(null);
  }

  @override
  Future<Map<String, dynamic>?> load(String uid) async {
    if (offline) throw StateError('offline');
    return docs[uid];
  }

  @override
  Future<void> save(String uid, Map<String, dynamic> progress) async {
    if (offline) throw StateError('offline');
    saves++;
    docs[uid] = progress;
  }

  @override
  Future<void> deleteAccount(String uid) async {
    if (offline) throw StateError('offline');
    docs.remove(uid);
    user = null;
    _users.add(null);
  }
}

void main() {
  group('merge', () {
    test('keeps the best of each level and the furthest unlock', () {
      const a = ProgressSnapshot(
        unlockedLevel: 5,
        hints: 1,
        results: {
          1: LevelResult(stars: 3, bestMoves: 6),
          2: LevelResult(stars: 1, bestMoves: 20),
        },
      );
      const b = ProgressSnapshot(
        unlockedLevel: 8,
        hints: 4,
        results: {
          2: LevelResult(stars: 3, bestMoves: 12, perfect: true),
          7: LevelResult(stars: 2, bestMoves: 15),
        },
      );
      final m = a.merge(b);
      expect(m.unlockedLevel, 8);
      expect(m.hints, 4);
      expect(m.results.keys, unorderedEquals([1, 2, 7]));
      expect(m.results[1]!.stars, 3);
      expect(m.results[2]!.stars, 3);
      expect(m.results[2]!.bestMoves, 12);
      expect(m.results[2]!.perfect, isTrue);
      // Merging is idempotent, and the order of the two sides doesn't change
      // what's kept.
      expect(m.merge(m), m);
      final r = b.merge(a);
      expect(r.unlockedLevel, m.unlockedLevel);
      expect(r.results.keys, unorderedEquals(m.results.keys));
    });

    test('the current streak comes from the most recent win', () {
      const older = PlayStats(
          wins: 30, streak: 9, bestStreak: 9, lastWinDay: '2026-11-01');
      const newer = PlayStats(
          wins: 12, streak: 2, bestStreak: 4, lastWinDay: '2026-11-13');
      final m = const ProgressSnapshot(hints: 0, stats: older)
          .merge(const ProgressSnapshot(hints: 0, stats: newer))
          .stats;
      expect(m.wins, 30);
      expect(m.streak, 2);
      expect(m.bestStreak, 9);
      expect(m.lastWinDay, '2026-11-13');
    });

    test('daily runs split across two devices join up', () {
      const phone = DailyStats(
        streak: 1,
        bestStreak: 1,
        completed: 1,
        lastDay: '2026-11-11',
        stars: {'2026-11-11': 3},
      );
      const tablet = DailyStats(
        streak: 2,
        bestStreak: 2,
        completed: 2,
        lastDay: '2026-11-13',
        stars: {'2026-11-12': 2, '2026-11-13': 3},
      );
      final m = const ProgressSnapshot(hints: 0, daily: phone)
          .merge(const ProgressSnapshot(hints: 0, daily: tablet))
          .daily;
      expect(m.stars.length, 3);
      expect(m.streak, 3);
      expect(m.bestStreak, 3);
      expect(m.completed, 3);
      expect(m.lastDay, '2026-11-13');
    });

    test('challenge bests take the higher stage per mode', () {
      final first = ChallengeMode.values.first;
      final last = ChallengeMode.values.last;
      final a = ProgressSnapshot(
          hints: 0, challenges: ChallengeStats(best: {first: 4}));
      final b = ProgressSnapshot(
          hints: 0, challenges: ChallengeStats(best: {first: 2, last: 7}));
      final m = a.merge(b).challenges;
      expect(m.bestStage(first), 4);
      expect(m.bestStage(last), 7);
    });

    test('the most recent hint count wins, even when it is smaller', () {
      const spent = ProgressSnapshot(hints: 2, hintsChangedAt: 200);
      const stale = ProgressSnapshot(hints: 5, hintsChangedAt: 100);
      expect(spent.merge(stale).hints, 2);
      expect(stale.merge(spent).hints, 2);
      expect(spent.merge(stale).hintsChangedAt, 200);
      // Saves from before timestamps keep the larger pool.
      expect(
        const ProgressSnapshot(hints: 1)
            .merge(const ProgressSnapshot(hints: 4))
            .hints,
        4,
      );
    });

    test('survives a round trip through JSON', () {
      final s = ProgressSnapshot(
        unlockedLevel: 12,
        hints: 2,
        results: const {3: LevelResult(stars: 2, bestMoves: 9)},
        stats: const PlayStats(
            wins: 11, streak: 3, bestStreak: 5, lastWinDay: '2026-11-13'),
        daily: const DailyStats(
            streak: 1, completed: 4, lastDay: '2026-11-13', stars: {}),
        challenges: ChallengeStats(best: {ChallengeMode.values.first: 3}),
      );
      expect(ProgressSnapshot.fromJson(s.toJson()), s);
    });
  });

  group('sync', () {
    late PersistenceService persistence;
    late FakeBackend backend;
    late CloudSyncService cloud;
    var reloads = 0;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      persistence = await PersistenceService.create();
      backend = FakeBackend();
      reloads = 0;
      cloud = CloudSyncService(persistence, backend,
          debounce: const Duration(milliseconds: 10))
        ..onLocalChanged = (() => reloads++);
      cloud.init();
    });
    tearDown(() => cloud.dispose());

    test('signing in uploads local progress to an empty cloud', () async {
      await persistence.recordResult(1, 3, 6);
      expect(await cloud.signIn(), SignInResult.signedIn);
      await cloud.sync();
      final saved = ProgressSnapshot.fromJson(backend.docs['u1']!);
      expect(saved.results[1]!.stars, 3);
      expect(saved.unlockedLevel, 2);
      expect(cloud.state.value.lastSynced, isNotNull);
      expect(reloads, 0);
    });

    test('a new phone gets the cloud progress, merged with its own', () async {
      backend.docs['u1'] = const ProgressSnapshot(
        unlockedLevel: 40,
        hints: 5,
        results: {39: LevelResult(stars: 3, bestMoves: 10)},
      ).toJson();
      await persistence.recordResult(1, 2, 8);

      await cloud.signIn();
      await cloud.sync();

      final local = persistence.exportSnapshot();
      expect(local.unlockedLevel, 40);
      expect(local.results.keys, containsAll([1, 39]));
      expect(local.hints, 5);
      expect(reloads, greaterThan(0));
      // The cloud now has the device's level 1 as well.
      expect(
          ProgressSnapshot.fromJson(backend.docs['u1']!).results[1]!.stars, 2);
    });

    test('a spent hint stays spent after the next sync', () async {
      await persistence.saveHints(5);
      await cloud.signIn();
      await cloud.sync();
      expect(ProgressSnapshot.fromJson(backend.docs['u1']!).hints, 5);

      // Make sure the spend gets a later timestamp than the first save.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await persistence.saveHints(4);
      await cloud.sync();

      expect(persistence.hints(), 4);
      expect(ProgressSnapshot.fromJson(backend.docs['u1']!).hints, 4);
    });

    test('nothing is written when both sides already match', () async {
      await cloud.signIn();
      await cloud.sync();
      final before = backend.saves;
      await cloud.sync();
      expect(backend.saves, before);
    });

    test('a change is pushed after the debounce', () async {
      await cloud.signIn();
      await cloud.sync();
      await persistence.recordResult(1, 3, 6);
      cloud.schedulePush();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await cloud.sync();
      expect(
          ProgressSnapshot.fromJson(backend.docs['u1']!).results[1], isNotNull);
    });

    test('offline: marks the failure and keeps local progress', () async {
      await persistence.recordResult(1, 3, 6);
      await cloud.signIn();
      await cloud.sync();
      backend.offline = true;
      await persistence.recordResult(2, 3, 6);
      await cloud.sync();
      expect(cloud.state.value.failed, isTrue);
      expect(persistence.exportSnapshot().results.keys, containsAll([1, 2]));
      backend.offline = false;
      await cloud.sync();
      expect(cloud.state.value.failed, isFalse);
    });

    test('deleting the account keeps progress on the device', () async {
      await persistence.recordResult(1, 3, 6);
      await cloud.signIn();
      await cloud.sync();
      expect(await cloud.deleteAccount(), isTrue);
      expect(backend.docs, isEmpty);
      expect(cloud.state.value.signedIn, isFalse);
      expect(persistence.exportSnapshot().results[1], isNotNull);
    });

    test('a cancelled sign-in stays signed out', () async {
      backend.nextSignIn = null;
      expect(await cloud.signIn(), SignInResult.cancelled);
      expect(cloud.state.value.signedIn, isFalse);
    });
  });

  group('settings card', () {
    Future<void> pump(WidgetTester tester, CloudSyncService cloud) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [cloudSyncProvider.overrideWithValue(cloud)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: CloudSaveSection()),
        ),
      ));
    }

    testWidgets('signed out offers Google sign-in; signed in shows controls',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final persistence = await PersistenceService.create();
      final cloud =
          CloudSyncService(persistence, FakeBackend(), debounce: Duration.zero)
            ..init();
      addTearDown(cloud.dispose);
      await pump(tester, cloud);

      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(find.text('Sign out'), findsNothing);

      await tester.tap(find.text('Sign in with Google'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Signed in as p@example.com'), findsOneWidget);
      expect(find.text('Progress backed up'), findsOneWidget);
      expect(find.text('Sync now'), findsOneWidget);
      expect(find.text('Delete cloud save'), findsOneWidget);

      await tester.tap(find.text('Sign out'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Sign in with Google'), findsOneWidget);
    });

    testWidgets('hidden when cloud save is off', (tester) async {
      await pump(tester, CloudSyncService.off());
      expect(find.text('Sign in with Google'), findsNothing);
      expect(find.text('Cloud save'), findsNothing);
    });
  });
}
