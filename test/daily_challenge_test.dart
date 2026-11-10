import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:decant/audio/audio_service.dart';
import 'package:decant/logic/daily_challenge.dart';
import 'package:decant/logic/level_generator.dart';
import 'package:decant/logic/solver.dart';
import 'package:decant/models/app_settings.dart';
import 'package:decant/models/daily_stats.dart';
import 'package:decant/models/game_state.dart';
import 'package:decant/services/analytics_service.dart';
import 'package:decant/services/persistence_service.dart';
import 'package:decant/state/game_session.dart';
import 'package:decant/state/progress_controller.dart';
import 'package:decant/state/providers.dart';
import 'package:decant/ui/screens/game_screen.dart';
import 'package:decant/ui/screens/home_screen.dart';
import 'package:decant/ui/widgets/tube_widget.dart';
import 'package:decant/ui/widgets/win_overlay.dart';

class _QuietAnalytics implements AnalyticsService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  // Monday 9 and Sunday 15 November 2026.
  final monday = DateTime(2026, 11, 9);
  final sunday = DateTime(2026, 11, 15);

  group('daily ids', () {
    test('map to and from the local day, apart from campaign levels', () {
      final id = DailyChallenge.idFor(DateTime(2026, 11, 10, 23, 59));
      expect(id, -20261110);
      expect(DailyChallenge.isDaily(id), isTrue);
      expect(DailyChallenge.isDaily(1), isFalse);
      expect(DailyChallenge.dateOf(id), DateTime(2026, 11, 10));
      expect(DailyChallenge.title(id), 'Daily · Nov 10');
    });

    test('a new year and a new month still round-trip', () {
      for (final d in [DateTime(2026, 12, 31), DateTime(2027, 1, 1)]) {
        expect(DailyChallenge.dateOf(DailyChallenge.idFor(d)), d);
      }
    });
  });

  group('daily levels', () {
    test('are the same for everyone on a day, and differ between days', () {
      final a = LevelGenerator.generate(DailyChallenge.idFor(monday));
      final b = LevelGenerator.generate(DailyChallenge.idFor(monday));
      final c = LevelGenerator.generate(
        DailyChallenge.idFor(monday.add(const Duration(days: 7))),
      );
      expect(a.filledTubes, b.filledTubes);
      expect(a.filledTubes, isNot(c.filledTubes));
    });

    test('get harder through the week, and are always solvable', () {
      expect(
        LevelGenerator.generate(DailyChallenge.idFor(monday)).colorCount,
        5,
      );
      expect(
        LevelGenerator.generate(DailyChallenge.idFor(sunday)).colorCount,
        9,
      );
      for (var i = 0; i < 7; i++) {
        final level = LevelGenerator.generate(
          DailyChallenge.idFor(monday.add(Duration(days: i))),
        );
        expect(
          Solver.isSolvable(GameState(tubes: level.buildTubes())),
          isTrue,
        );
      }
    });
  });

  group('daily streak', () {
    test('grows on consecutive days and restarts after a gap', () {
      var d = const DailyStats();
      d = d.record(monday, 2);
      d = d.record(monday.add(const Duration(days: 1)), 3);
      expect(d.streak, 2);
      d = d.record(monday.add(const Duration(days: 3)), 1); // skipped a day
      expect(d.streak, 1);
      expect(d.bestStreak, 2);
      expect(d.completed, 3);
    });

    test('replays keep the streak and only improve the stars', () {
      var d = const DailyStats().record(monday, 1).record(monday, 3);
      expect(d.streak, 1);
      expect(d.completed, 1);
      expect(d.starsOn(monday), 3);
      d = d.record(monday, 2);
      expect(d.starsOn(monday), 3);
    });

    test("finishing yesterday's daily after midnight can't rewind it", () {
      final tue = monday.add(const Duration(days: 1));
      final d = const DailyStats().record(tue, 2).record(monday, 2);
      expect(d.streak, 1);
      expect(d.lastDay, '2026-11-10');
      expect(d.completed, 2);
      expect(d.solvedOn(monday), isTrue);
    });

    test('is alive through tomorrow, then broken', () {
      final d = const DailyStats().record(monday, 3);
      expect(d.currentStreak(monday), 1);
      expect(d.currentStreak(monday.add(const Duration(days: 1))), 1);
      expect(d.currentStreak(monday.add(const Duration(days: 2))), 0);
    });

    test('keeps only recent days of stars and survives a save', () {
      var d = const DailyStats().record(DateTime(2026, 1, 1), 3);
      d = d.record(DateTime(2026, 11, 10), 2);
      expect(d.solvedOn(DateTime(2026, 1, 1)), isFalse); // pruned
      final back = DailyStats.fromJson(d.toJson());
      expect(back.stars, d.stars);
      expect(back.completed, 2);
      expect(back.lastDay, '2026-11-10');
    });
  });

  test('a daily win counts as a win but leaves the campaign alone', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await PersistenceService.create();
    final c = ProgressController(p, now: () => monday);
    await c.recordWin(DailyChallenge.idFor(monday), 3, 20);
    expect(c.state.daily.solvedOn(monday), isTrue);
    expect(c.state.daily.streak, 1);
    expect(c.state.stats.wins, 1);
    expect(c.state.unlockedLevel, 1);
    expect(c.state.levelsCompleted, 0);
    expect(c.state.totalStars, 0);
  });

  testWidgets('solving the daily from home shows it done with a streak', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 3088);
    tester.view.devicePixelRatio = 3.5;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final persistence = await PersistenceService.create();
    await persistence.saveSettings(const AppSettings(tutorialSeen: true));
    final container = ProviderContainer(
      overrides: [
        persistenceProvider.overrideWithValue(persistence),
        audioServiceProvider.overrideWithValue(AudioService()),
        analyticsServiceProvider.overrideWithValue(_QuietAnalytics()),
        progressProvider.overrideWith(
          (ref) => ProgressController(persistence, now: () => monday),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Daily challenge'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final id = DailyChallenge.idFor(monday);
    expect(tester.widget<GameScreen>(find.byType(GameScreen)).levelId, id);
    expect(find.text('Daily · Nov 9'), findsOneWidget);

    for (var guard = 0; guard < 200; guard++) {
      final session = container.read(gameControllerProvider(id));
      if (session.status == GameStatus.won) break;
      final move = Solver.nextMove(session.state)!;
      final tubes = find.byType(TubeWidget);
      await tester.tap(tubes.at(move.from), warnIfMissed: false);
      await tester.pump();
      await tester.tap(tubes.at(move.to), warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1100));
    }
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(WinOverlay), findsOneWidget);
    expect(find.text('Daily challenge solved'), findsOneWidget);
    expect(find.text('1-day streak. Beautifully done.'), findsOneWidget);
    expect(find.text('Levels'), findsNothing);

    await tester.tap(find.text('Done'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(GameScreen), findsNothing);
    expect(find.text('Daily done · 1-day streak'), findsOneWidget);
    expect(container.read(progressProvider).unlockedLevel, 1);
  });
}
