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
import 'package:decant/state/game_session.dart';
import 'package:decant/state/providers.dart';
import 'package:decant/ui/screens/game_screen.dart';
import 'package:decant/ui/widgets/tube_widget.dart';

class _QuietAnalytics implements AnalyticsService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  test('pour speed and reduce motion persist; unknown values fall back', () {
    const s = AppSettings(pourSpeed: PourSpeed.quick, reduceMotion: true);
    final back = AppSettings.fromJson(s.toJson());
    expect(back.pourSpeed, PourSpeed.quick);
    expect(back.reduceMotion, isTrue);

    final old = AppSettings.fromJson({'haptics': true});
    expect(old.pourSpeed, PourSpeed.normal);
    expect(old.reduceMotion, isFalse);
    expect(
      AppSettings.fromJson({'pourSpeed': 'warp'}).pourSpeed,
      PourSpeed.normal,
    );
  });

  test('speeds are ordered and Normal flows for the original 540 ms', () {
    final flow =
        PourSpeed.normal.duration * (PourAnim.flowEnd - PourAnim.flowStart);
    expect(flow.inMilliseconds, 540);
    expect(PourSpeed.quick.duration < PourSpeed.normal.duration, isTrue);
    expect(PourSpeed.relaxed.duration > PourSpeed.normal.duration, isTrue);
  });

  /// Opens level 1 with [settings] saved, tutorial already seen.
  Future<ProviderContainer> pumpLevel(
    WidgetTester tester,
    AppSettings settings,
  ) async {
    tester.view.physicalSize = const Size(1440, 3088);
    tester.view.devicePixelRatio = 3.5;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final persistence = await PersistenceService.create();
    await persistence.saveSettings(settings.copyWith(tutorialSeen: true));
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
    return container;
  }

  Future<void> pourFirstMove(WidgetTester tester) async {
    final level = LevelGenerator.generate(1);
    final move = Solver.nextMove(
      GameState(
        tubes: level.buildTubes(),
        extraTubesRemaining: level.extraTubeAllowance,
      ),
    )!;
    await tester.tap(
      find.byType(TubeWidget).at(move.from),
      warnIfMissed: false,
    );
    await tester.pump();
    await tester.tap(find.byType(TubeWidget).at(move.to), warnIfMissed: false);
    await tester.pump();
  }

  List<double> tilts(WidgetTester tester) => tester
      .widgetList<TubeWidget>(find.byType(TubeWidget))
      .map((t) => t.tilt)
      .toList();

  testWidgets('a quick pour finishes in the quick time', (tester) async {
    final container = await pumpLevel(
      tester,
      const AppSettings(pourSpeed: PourSpeed.quick),
    );
    await pourFirstMove(tester);

    final session = container.read(gameControllerProvider(1));
    expect(session.pour, isNotNull);
    expect(session.pour!.duration, PourSpeed.quick.duration);

    // Well before Normal's 1000 ms, the quick pour is already done.
    await tester.pump(const Duration(milliseconds: 680));
    await tester.pump();
    expect(container.read(gameControllerProvider(1)).pour, isNull);
  });

  testWidgets('reduce motion keeps tubes upright and bubbles still', (
    tester,
  ) async {
    await pumpLevel(tester, const AppSettings(reduceMotion: true));

    double bubbleTime() =>
        tester.widget<TubeWidget>(find.byType(TubeWidget).first).time;
    final before = bubbleTime();
    await tester.pump(const Duration(seconds: 1));
    expect(bubbleTime(), before);

    await pourFirstMove(tester);
    await tester.pump(const Duration(milliseconds: 500)); // mid-pour
    expect(tilts(tester).every((t) => t == 0), isTrue);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('without reduce motion the source tube tilts mid-pour', (
    tester,
  ) async {
    await pumpLevel(tester, const AppSettings());
    await pourFirstMove(tester);
    await tester.pump(const Duration(milliseconds: 500)); // mid-pour
    expect(tilts(tester).any((t) => t != 0), isTrue);
    await tester.pump(const Duration(seconds: 1));
  });
}
