import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:decant/audio/audio_service.dart';
import 'package:decant/logic/solver.dart';
import 'package:decant/models/app_settings.dart';
import 'package:decant/services/analytics_service.dart';
import 'package:decant/services/persistence_service.dart';
import 'package:decant/state/game_session.dart';
import 'package:decant/state/providers.dart';
import 'package:decant/ui/screens/game_screen.dart';
import 'package:decant/ui/widgets/star_row.dart';
import 'package:decant/ui/widgets/tube_widget.dart';
import 'package:decant/ui/widgets/win_overlay.dart';

class _QuietAnalytics implements AnalyticsService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  test('Zen mode is off by default and survives a save', () {
    expect(const AppSettings().zenMode, isFalse);
    expect(AppSettings.fromJson({'haptics': true}).zenMode, isFalse);
    const on = AppSettings(zenMode: true);
    expect(AppSettings.fromJson(on.toJson()).zenMode, isTrue);
  });

  /// Plays level 1 to the end with [zen] on or off; returns the container.
  Future<ProviderContainer> solveLevel1(
    WidgetTester tester, {
    required bool zen,
    Future<void> Function(PersistenceService p)? seed,
  }) async {
    tester.view.physicalSize = const Size(1440, 3088);
    tester.view.devicePixelRatio = 3.5;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final persistence = await PersistenceService.create();
    await persistence.saveSettings(
      AppSettings(tutorialSeen: true, zenMode: zen),
    );
    if (seed != null) await seed(persistence);
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
        child: const MaterialApp(home: GameScreen(levelId: 1)),
      ),
    );
    await tester.pump();

    // The moves pill shows only outside Zen mode.
    expect(find.text('0 moves'), zen ? findsNothing : findsOneWidget);

    for (var guard = 0; guard < 200; guard++) {
      final session = container.read(gameControllerProvider(1));
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
    return container;
  }

  testWidgets('a Zen win shows no stars or moves and records no stars', (
    tester,
  ) async {
    final c = await solveLevel1(tester, zen: true);
    final overlay = find.byType(WinOverlay);
    expect(
      find.descendant(of: overlay, matching: find.byType(StarRow)),
      findsNothing,
    );
    expect(
      find.descendant(of: overlay, matching: find.textContaining('move')),
      findsNothing,
    );
    expect(find.text('Beautifully done.'), findsOneWidget);

    final progress = c.read(progressProvider);
    expect(progress.resultFor(1)!.stars, 0);
    expect(progress.totalStars, 0);
    expect(progress.isUnlocked(2), isTrue); // still moves you on
    expect(progress.levelsCompleted, 1);
  });

  testWidgets('a Zen replay keeps stars earned before', (tester) async {
    final c = await solveLevel1(
      tester,
      zen: true,
      seed: (p) => p.recordResult(1, 3, 6),
    );
    expect(c.read(progressProvider).resultFor(1)!.stars, 3);
  });

  testWidgets('outside Zen mode the win still shows stars', (tester) async {
    final c = await solveLevel1(tester, zen: false);
    expect(
      find.descendant(
        of: find.byType(WinOverlay),
        matching: find.byType(StarRow),
      ),
      findsOneWidget,
    );
    expect(c.read(progressProvider).resultFor(1)!.stars, greaterThan(0));
  });
}
