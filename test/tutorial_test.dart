import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:decant/audio/audio_service.dart';
import 'package:decant/logic/level_generator.dart';
import 'package:decant/logic/solver.dart';
import 'package:decant/models/app_settings.dart';
import 'package:decant/models/game_state.dart';
import 'package:decant/services/analytics_service.dart';
import 'package:decant/services/persistence_service.dart';
import 'package:decant/state/providers.dart';
import 'package:decant/ui/screens/game_screen.dart';
import 'package:decant/ui/widgets/tube_widget.dart';

/// Records tutorial events instead of talking to Firebase.
class _FakeAnalytics implements AnalyticsService {
  final events = <String>[];

  @override
  void logTutorialBegin({required bool replay}) =>
      events.add('begin${replay ? ':replay' : ''}');

  @override
  void logTutorialComplete({required bool skipped}) =>
      events.add('complete${skipped ? ':skipped' : ''}');

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late PersistenceService persistence;
  late _FakeAnalytics analytics;

  Future<void> pumpLevel(WidgetTester tester, int levelId) async {
    // A phone-sized surface so the board lays out like it does on a device.
    tester.view.physicalSize = const Size(1440, 3088);
    tester.view.devicePixelRatio = 3.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          persistenceProvider.overrideWithValue(persistence),
          audioServiceProvider.overrideWithValue(AudioService()),
          analyticsServiceProvider.overrideWithValue(analytics),
        ],
        child: MaterialApp(home: GameScreen(levelId: levelId)),
      ),
    );
    // The board animates forever (bubbles), so pump frames instead of settling.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> tapTube(WidgetTester tester, int index) async {
    await tester.tap(find.byType(TubeWidget).at(index), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 50));
  }

  setUp(() {
    analytics = _FakeAnalytics();
  });

  testWidgets('new player is walked through the first pour', (tester) async {
    SharedPreferences.setMockInitialValues({});
    persistence = await PersistenceService.create();
    await pumpLevel(tester, 1);

    expect(find.text('Tap the glowing tube'), findsOneWidget);

    final level = LevelGenerator.generate(1);
    final move = Solver.nextMove(GameState(
      tubes: level.buildTubes(),
      extraTubesRemaining: level.extraTubeAllowance,
    ))!;

    // One tube glows at a time: only the source until it's picked up.
    TubeWidget tube(int i) =>
        tester.widget<TubeWidget>(find.byType(TubeWidget).at(i));
    expect(tube(move.from).hintSource, isTrue);
    expect(tube(move.to).hintTarget, isFalse);

    await tapTube(tester, move.from);
    expect(find.text('Now tap the other glowing tube'), findsOneWidget);
    expect(tube(move.to).hintTarget, isTrue);

    await tapTube(tester, move.to);
    await tester.pump(const Duration(milliseconds: 700)); // pour animation
    expect(find.text('Sort every tube into one color'), findsOneWidget);

    await tester.tap(find.text('Got it'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Sort every tube into one color'), findsNothing);
    expect(persistence.loadSettings().tutorialSeen, isTrue);
    expect(analytics.events, ['begin', 'complete']);
  });

  testWidgets('skipping also marks the guide as seen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    persistence = await PersistenceService.create();
    await pumpLevel(tester, 1);

    await tester.tap(find.text('Skip'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Tap the glowing tube'), findsNothing);
    expect(persistence.loadSettings().tutorialSeen, isTrue);
    expect(analytics.events, ['begin', 'complete:skipped']);
  });

  testWidgets(
      'returning players skip it but can replay it from the help button',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'decant.unlocked': 3,
      'decant.result.1': '{"stars":3,"moves":5}',
      'decant.result.2': '{"stars":2,"moves":9}',
    });
    persistence = await PersistenceService.create();
    await pumpLevel(tester, 3);
    expect(find.text('Tap the glowing tube'), findsNothing);

    await tester.tap(find.byTooltip('How to play'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Tap the glowing tube'), findsOneWidget);
    expect(analytics.events, ['begin:replay']);
  });

  test('tutorialSeen persists and defaults to false for older settings', () {
    expect(AppSettings.fromJson({'haptics': true}).tutorialSeen, isFalse);
    final round =
        AppSettings.fromJson(const AppSettings(tutorialSeen: true).toJson());
    expect(round.tutorialSeen, isTrue);
  });
}
