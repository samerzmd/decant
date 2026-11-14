import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:decant/audio/audio_service.dart';
import 'package:decant/logic/challenge.dart';
import 'package:decant/logic/daily_challenge.dart';
import 'package:decant/logic/level_generator.dart';
import 'package:decant/logic/pour_engine.dart';
import 'package:decant/logic/solver.dart';
import 'package:decant/models/app_settings.dart';
import 'package:decant/models/challenge_stats.dart';
import 'package:decant/models/game_state.dart';
import 'package:decant/services/analytics_service.dart';
import 'package:decant/services/persistence_service.dart';
import 'package:decant/state/game_session.dart';
import 'package:decant/state/progress_controller.dart';
import 'package:decant/state/providers.dart';
import 'package:decant/ui/screens/challenges_screen.dart';
import 'package:decant/ui/screens/game_screen.dart';
import 'package:decant/ui/widgets/fail_overlay.dart';
import 'package:decant/ui/widgets/tube_widget.dart';
import 'package:decant/ui/widgets/win_overlay.dart';

class _QuietAnalytics implements AnalyticsService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  group('challenge ids and rules', () {
    test('map to a mode and stage, apart from campaign and dailies', () {
      final id = Challenge.idFor(ChallengeMode.timed, 7);
      expect(Challenge.isChallenge(id), isTrue);
      expect(Challenge.modeOf(id), ChallengeMode.timed);
      expect(Challenge.stageOf(id), 7);
      expect(Challenge.title(id), 'Against the clock · Stage 7');
      expect(Challenge.isChallenge(500), isFalse);
      final daily = DailyChallenge.idFor(DateTime(2026, 11, 10));
      expect(Challenge.isChallenge(daily), isFalse);
      expect(
        Challenge.modeOf(Challenge.idFor(ChallengeMode.moves, 1)),
        ChallengeMode.moves,
      );
    });

    test('stages ramp up from 4 colors and stay solvable', () {
      expect(Challenge.colorsFor(1), 4);
      expect(Challenge.colorsFor(3), 5);
      expect(Challenge.colorsFor(99), 11);
      for (final stage in [1, 4, 9]) {
        final level = LevelGenerator.generate(
          Challenge.idFor(ChallengeMode.moves, stage),
        );
        expect(level.colorCount, Challenge.colorsFor(stage));
        expect(Solver.isSolvable(GameState(tubes: level.buildTubes())), isTrue);
      }
    });

    test('limits leave room to breathe', () {
      expect(Challenge.moveLimit(4), 6); // at least two spare
      expect(Challenge.moveLimit(20), 25); // the three-star target
      expect(Challenge.timeLimit(10), const Duration(seconds: 70));
    });

    test('best stages only go up and survive a save', () {
      var s = const ChallengeStats();
      expect(s.nextStage(ChallengeMode.moves), 1);
      s = s
          .recordClear(ChallengeMode.moves, 3)
          .recordClear(ChallengeMode.moves, 2);
      expect(s.bestStage(ChallengeMode.moves), 3);
      expect(s.bestStage(ChallengeMode.timed), 0);
      final back = ChallengeStats.fromJson(s.toJson());
      expect(back.bestStage(ChallengeMode.moves), 3);
    });
  });

  test(
    'clearing a stage counts as a win but leaves the campaign alone',
    () async {
      SharedPreferences.setMockInitialValues({});
      final p = await PersistenceService.create();
      final c = ProgressController(p);
      await c.recordWin(Challenge.idFor(ChallengeMode.timed, 1), 3, 10);
      expect(c.state.challenges.bestStage(ChallengeMode.timed), 1);
      expect(c.state.stats.wins, 1);
      expect(c.state.unlockedLevel, 1);
      expect(c.state.totalStars, 0);
    },
  );

  Future<ProviderContainer> pumpChallenges(WidgetTester tester) async {
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
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ChallengesScreen()),
      ),
    );
    await tester.pump();
    return container;
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pour(WidgetTester tester, int from, int to) async {
    final tubes = find.byType(TubeWidget);
    await tester.tap(tubes.at(from), warnIfMissed: false);
    await tester.pump();
    await tester.tap(tubes.at(to), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1100));
  }

  /// Opens stage 1 of the [index]th mode card.
  Future<int> openStage1(WidgetTester tester, int index) async {
    await tester.tap(find.text('Play stage 1').at(index));
    await settle(tester);
    return tester.widget<GameScreen>(find.byType(GameScreen)).levelId;
  }

  testWidgets('Move limit: careless pours run out, Retry starts over', (
    tester,
  ) async {
    final c = await pumpChallenges(tester);
    final id = await openStage1(tester, 0);
    expect(Challenge.modeOf(id), ChallengeMode.moves);
    expect(find.text('Move limit · Stage 1'), findsOneWidget);

    var session = c.read(gameControllerProvider(id));
    final limit = session.moveLimit!;
    expect(find.text('$limit moves left'), findsOneWidget);
    expect(session.canUndo, isFalse);

    // Shuffle liquid back and forth with the first legal pour each time.
    for (var guard = 0; guard < 100; guard++) {
      session = c.read(gameControllerProvider(id));
      if (session.status != GameStatus.playing) break;
      final s = session.state;
      int? from;
      int? to;
      outer:
      for (var a = 0; a < s.tubes.length; a++) {
        for (var b = 0; b < s.tubes.length; b++) {
          if (a != b && PourEngine.canPour(s, a, b)) {
            from = a;
            to = b;
            break outer;
          }
        }
      }
      await pour(tester, from!, to!);
    }
    expect(c.read(gameControllerProvider(id)).status, GameStatus.failed);
    expect(find.byType(FailOverlay), findsOneWidget);
    expect(find.text('Out of moves'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    session = c.read(gameControllerProvider(id));
    expect(session.status, GameStatus.playing);
    expect(session.moves, 0);
    expect(find.byType(FailOverlay), findsNothing);
  });

  testWidgets('clearing a stage moves on to the next one', (tester) async {
    final c = await pumpChallenges(tester);
    final id = await openStage1(tester, 0);
    for (var guard = 0; guard < 100; guard++) {
      final session = c.read(gameControllerProvider(id));
      if (session.status != GameStatus.playing) break;
      final move = Solver.nextMove(session.state)!;
      await pour(tester, move.from, move.to);
    }
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(WinOverlay), findsOneWidget);
    expect(find.text('Stage 1 cleared'), findsOneWidget);
    expect(
      c.read(progressProvider).challenges.bestStage(ChallengeMode.moves),
      1,
    );

    await tester.tap(find.text('Next stage'));
    await settle(tester);
    expect(
      tester.widget<GameScreen>(find.byType(GameScreen)).levelId,
      Challenge.idFor(ChallengeMode.moves, 2),
    );
  });

  testWidgets('Against the clock waits for the first pour, then runs out', (
    tester,
  ) async {
    final c = await pumpChallenges(tester);
    final id = await openStage1(tester, 1);
    expect(Challenge.modeOf(id), ChallengeMode.timed);
    final limit = c.read(gameControllerProvider(id)).timeLimit!;
    String clock(Duration d) =>
        '${d.inSeconds ~/ 60}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
    expect(find.text(clock(limit)), findsOneWidget);

    // Nothing ticks before the first pour.
    await tester.pump(const Duration(seconds: 5));
    expect(c.read(gameControllerProvider(id)).timeLeft, limit);

    final move = Solver.nextMove(c.read(gameControllerProvider(id)).state)!;
    await pour(tester, move.from, move.to);
    expect(c.read(gameControllerProvider(id)).clockStarted, isTrue);

    await tester.pump(limit);
    await tester.pump();
    expect(c.read(gameControllerProvider(id)).status, GameStatus.failed);
    expect(find.text("Time's up"), findsOneWidget);
  });
}
