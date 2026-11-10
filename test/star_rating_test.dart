import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:decant/audio/audio_service.dart';
import 'package:decant/logic/challenge.dart';
import 'package:decant/logic/solver.dart';
import 'package:decant/logic/star_rating.dart';
import 'package:decant/models/app_settings.dart';
import 'package:decant/models/level_result.dart';
import 'package:decant/services/analytics_service.dart';
import 'package:decant/services/persistence_service.dart';
import 'package:decant/state/game_session.dart';
import 'package:decant/state/providers.dart';
import 'package:decant/ui/screens/game_screen.dart';
import 'package:decant/ui/screens/level_select_screen.dart';
import 'package:decant/ui/widgets/star_row.dart';
import 'package:decant/ui/widgets/tube_widget.dart';
import 'package:decant/ui/widgets/win_overlay.dart';

class _QuietAnalytics implements AnalyticsService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  group('star targets', () {
    test('scale with each level and keep the old thresholds', () {
      expect(StarRating.threeStarMoves(4), 5);
      expect(StarRating.twoStarMoves(4), 8);
      expect(StarRating.threeStarMoves(20), 25);
      expect(StarRating.twoStarMoves(20), 38);
    });

    test('award stars by moves, and hints cost one', () {
      expect(StarRating.stars(moves: 10, par: 10), 3);
      expect(StarRating.stars(moves: 13, par: 10), 3);
      expect(StarRating.stars(moves: 14, par: 10), 2);
      expect(StarRating.stars(moves: 20, par: 10), 1);
      expect(StarRating.stars(moves: 10, par: 10, hints: 1), 2);
      expect(StarRating.stars(moves: 40, par: 10, hints: 2), 1);
    });

    test('perfect means par moves with no help', () {
      bool perfect(int moves, {int hints = 0, bool tube = false}) =>
          StarRating.isPerfect(
            moves: moves,
            par: 10,
            hints: hints,
            usedExtraTube: tube,
          );
      expect(perfect(10), isTrue);
      expect(perfect(9), isTrue); // beating the solver counts
      expect(perfect(11), isFalse);
      expect(perfect(10, hints: 1), isFalse);
      expect(perfect(10, tube: true), isFalse);
    });

    test('a perfect badge is kept once earned', () async {
      var r = const LevelResult(stars: 2, bestMoves: 14);
      r = r.mergedWith(3, 10, perfect: true).mergedWith(2, 15);
      expect(r.perfect, isTrue);
      expect(r.stars, 3);
      expect(LevelResult.fromJson(r.toJson()).perfect, isTrue);
      expect(LevelResult.fromJson({'stars': 3, 'moves': 5}).perfect, isFalse);

      SharedPreferences.setMockInitialValues({});
      final p = await PersistenceService.create();
      await p.recordResult(1, 3, 6, perfect: true);
      await p.recordResult(1, 3, 9);
      expect(p.resultFor(1)!.perfect, isTrue);
    });
  });

  Future<ProviderContainer> pumpLevel(WidgetTester tester, int id) async {
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
        child: MaterialApp(home: GameScreen(levelId: id)),
      ),
    );
    await tester.pump();
    return container;
  }

  Future<void> solve(
    WidgetTester tester,
    ProviderContainer c,
    int id, {
    bool hintFirst = false,
  }) async {
    if (hintFirst) {
      c.read(gameControllerProvider(id).notifier).requestHint();
      await tester.pump();
    }
    for (var guard = 0; guard < 200; guard++) {
      final session = c.read(gameControllerProvider(id));
      if (session.status != GameStatus.playing) break;
      final move = Solver.nextMove(session.state)!;
      final tubes = find.byType(TubeWidget);
      await tester.tap(tubes.at(move.from), warnIfMissed: false);
      await tester.pump();
      await tester.tap(tubes.at(move.to), warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1100));
    }
    await tester.pump(const Duration(seconds: 2));
  }

  testWidgets('the header shows the three-star target', (tester) async {
    final c = await pumpLevel(tester, 3);
    final par = c.read(gameControllerProvider(3)).par;
    expect(
      find.textContaining('★★★ in ${StarRating.threeStarMoves(par)}'),
      findsOneWidget,
    );
  });

  testWidgets('a solver-perfect solve earns the badge everywhere', (
    tester,
  ) async {
    final c = await pumpLevel(tester, 3);
    await solve(tester, c, 3);
    expect(c.read(gameControllerProvider(3)).perfect, isTrue);
    expect(find.text('Perfect'), findsOneWidget);
    expect(c.read(progressProvider).resultFor(3)!.perfect, isTrue);
    expect(c.read(progressProvider).perfectLevels, 1);

    // And on the level grid.
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: LevelSelectScreen()),
      ),
    );
    await tester.pump();
    expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
  });

  testWidgets('a hint rules out perfect and shows what perfect takes', (
    tester,
  ) async {
    final c = await pumpLevel(tester, 3);
    await solve(tester, c, 3, hintFirst: true);
    final session = c.read(gameControllerProvider(3));
    expect(session.perfect, isFalse);
    expect(find.text('Perfect'), findsNothing);
    expect(
      find.textContaining('Perfect: ${session.par} moves'),
      findsOneWidget,
    );
    expect(c.read(progressProvider).resultFor(3)!.perfect, isFalse);
  });

  testWidgets('a challenge win shows no stars or badge', (tester) async {
    final id = Challenge.idFor(ChallengeMode.moves, 1);
    final c = await pumpLevel(tester, id);
    expect(find.textContaining('★★★'), findsNothing);
    await solve(tester, c, id);
    final overlay = find.byType(WinOverlay);
    expect(overlay, findsOneWidget);
    expect(
      find.descendant(of: overlay, matching: find.byType(StarRow)),
      findsNothing,
    );
    expect(c.read(gameControllerProvider(id)).perfect, isFalse);
  });
}
