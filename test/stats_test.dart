import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:decant/models/play_stats.dart';
import 'package:decant/services/persistence_service.dart';
import 'package:decant/state/progress_controller.dart';
import 'package:decant/state/providers.dart';
import 'package:decant/ui/screens/stats_screen.dart';

void main() {
  group('PlayStats streak', () {
    test('first win starts a 1-day streak', () {
      final s = const PlayStats().recordWin(DateTime(2026, 11, 9, 10));
      expect(s.wins, 1);
      expect(s.streak, 1);
      expect(s.bestStreak, 1);
      expect(s.lastWinDay, '2026-11-09');
    });

    test('more wins the same day count as wins but not streak days', () {
      final s = const PlayStats()
          .recordWin(DateTime(2026, 11, 9, 8))
          .recordWin(DateTime(2026, 11, 9, 23, 59));
      expect(s.wins, 2);
      expect(s.streak, 1);
    });

    test('a win the next day extends it, across month and year ends', () {
      var s = const PlayStats().recordWin(DateTime(2026, 12, 30, 22));
      s = s.recordWin(DateTime(2026, 12, 31, 0, 5));
      s = s.recordWin(DateTime(2027, 1, 1, 9));
      expect(s.streak, 3);
      expect(s.bestStreak, 3);
    });

    test('a missed day restarts it but keeps the best', () {
      var s = const PlayStats()
          .recordWin(DateTime(2026, 11, 1))
          .recordWin(DateTime(2026, 11, 2))
          .recordWin(DateTime(2026, 11, 3));
      s = s.recordWin(DateTime(2026, 11, 5));
      expect(s.streak, 1);
      expect(s.bestStreak, 3);
    });

    test('the current streak survives until a whole day is missed', () {
      final s = const PlayStats()
          .recordWin(DateTime(2026, 11, 8))
          .recordWin(DateTime(2026, 11, 9));
      expect(s.currentStreak(DateTime(2026, 11, 9, 20)), 2);
      expect(s.wonToday(DateTime(2026, 11, 9, 20)), isTrue);
      expect(s.currentStreak(DateTime(2026, 11, 10, 23)), 2);
      expect(s.wonToday(DateTime(2026, 11, 10, 23)), isFalse);
      expect(s.currentStreak(DateTime(2026, 11, 11)), 0);
    });

    test('round-trips through JSON and tolerates missing fields', () {
      final s = const PlayStats().recordWin(DateTime(2026, 11, 9));
      final back = PlayStats.fromJson(s.toJson());
      expect(back.wins, 1);
      expect(back.streak, 1);
      expect(back.lastWinDay, '2026-11-09');
      expect(PlayStats.fromJson({}).wins, 0);
    });
  });

  group('progress', () {
    test('backfills wins for existing players without double counting',
        () async {
      SharedPreferences.setMockInitialValues({
        'decant.unlocked': 3,
        'decant.result.1': '{"stars":3,"moves":5}',
        'decant.result.2': '{"stars":2,"moves":9}',
      });
      final persistence = await PersistenceService.create();
      final ctrl = ProgressController(
        persistence,
        now: () => DateTime(2026, 11, 9, 12),
      );
      expect(ctrl.state.stats.wins, 2);

      await ctrl.recordWin(3, 1, 20);
      expect(ctrl.state.stats.wins, 3);
      expect(ctrl.state.stats.streak, 1);
      expect(persistence.loadStats().wins, 3);

      // Replaying a solved level counts as a win too.
      await ctrl.recordWin(1, 3, 5);
      expect(ctrl.state.stats.wins, 4);
      expect(ctrl.state.levelsCompleted, 3);
    });

    test('counts perfect levels and stars per level', () async {
      SharedPreferences.setMockInitialValues({
        'decant.unlocked': 5,
        'decant.result.1': '{"stars":3,"moves":5}',
        'decant.result.2': '{"stars":2,"moves":9}',
        'decant.result.3': '{"stars":3,"moves":7}',
        'decant.result.4': '{"stars":1,"moves":30}',
      });
      final ctrl = ProgressController(await PersistenceService.create());
      expect(ctrl.state.perfectLevels, 2);
      expect(ctrl.state.starCounts, [1, 1, 2]);
    });
  });

  testWidgets('stats screen shows progress and the streak', (tester) async {
    final today = PlayStats.dayKey(DateTime.now());
    SharedPreferences.setMockInitialValues({
      'decant.unlocked': 4,
      'decant.result.1': '{"stars":3,"moves":5}',
      'decant.result.2': '{"stars":2,"moves":9}',
      'decant.result.3': '{"stars":3,"moves":7}',
      'decant.stats':
          '{"wins":6,"streak":4,"bestStreak":5,"lastWinDay":"$today"}',
    });
    final persistence = await PersistenceService.create();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [persistenceProvider.overrideWithValue(persistence)],
        child: const MaterialApp(home: StatsScreen()),
      ),
    );

    expect(find.text('4-day streak'), findsOneWidget);
    expect(find.text("Today's win is in. See you tomorrow."), findsOneWidget);
    expect(find.text('Next up: level 4'), findsOneWidget);
    expect(find.text('8'), findsOneWidget); // stars
    expect(find.text('of 9 possible'), findsOneWidget);
    expect(find.text('6'), findsOneWidget); // wins
    expect(find.text('2 levels'), findsOneWidget); // three-star levels

    // The star bar's segments fill its height (they were once 0px tall).
    final segments = find.descendant(
      of: find.byType(ClipRRect),
      matching: find.byType(ColoredBox),
    );
    expect(segments, findsNWidgets(2)); // 3-star and 2-star levels
    expect(tester.getSize(segments.first).height, 12);
  });
}
