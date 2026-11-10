import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:decant/audio/audio_service.dart';
import 'package:decant/models/app_settings.dart';
import 'package:decant/services/analytics_service.dart';
import 'package:decant/services/persistence_service.dart';
import 'package:decant/state/game_controller.dart';
import 'package:decant/state/progress_controller.dart';
import 'package:decant/state/providers.dart';
import 'package:decant/ui/screens/game_screen.dart';

class _QuietAnalytics implements AnalyticsService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  test('the pool starts at 3, refills on wins, and stops at 5', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await PersistenceService.create();
    final c = ProgressController(p);
    expect(c.state.hints, 3);

    expect(await c.spendHint(), isTrue);
    expect(c.state.hints, 2);
    await c.recordWin(1, 3, 6);
    expect(c.state.hints, 3);
    for (var i = 0; i < 5; i++) {
      await c.recordWin(1, 3, 6);
    }
    expect(c.state.hints, 5);
  });

  test('an empty pool refuses', () async {
    SharedPreferences.setMockInitialValues({'decant.hints': 0});
    final c = ProgressController(await PersistenceService.create());
    expect(await c.spendHint(), isFalse);
    expect(c.state.hints, 0);
  });

  Future<ProviderContainer> pumpLevel(
    WidgetTester tester, {
    int hints = 3,
    bool zen = false,
  }) async {
    tester.view.physicalSize = const Size(1440, 3088);
    tester.view.devicePixelRatio = 3.5;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'decant.hints': hints});
    final persistence = await PersistenceService.create();
    await persistence.saveSettings(
      AppSettings(tutorialSeen: true, zenMode: zen),
    );
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
        child: const MaterialApp(home: GameScreen(levelId: 2)),
      ),
    );
    await tester.pump();
    return container;
  }

  testWidgets('a hint uses one from the pool', (tester) async {
    final c = await pumpLevel(tester);
    expect(find.text('3'), findsOneWidget); // hint badge
    await tester.tap(find.byTooltip('Hint'));
    await tester.pump();
    await tester.pump();
    expect(c.read(gameControllerProvider(2)).hint, isNotNull);
    expect(c.read(progressProvider).hints, 2);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('an empty pool says how to earn more', (tester) async {
    final c = await pumpLevel(tester, hints: 0);
    expect(
      c.read(gameControllerProvider(2).notifier).requestHint(),
      HintOutcome.noHintsLeft,
    );
    await tester.tap(find.byTooltip('Hint'));
    await tester.pump();
    expect(
      find.text('No hints left. Solve a level to earn one.'),
      findsOneWidget,
    );
    expect(c.read(gameControllerProvider(2)).hint, isNull);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Zen mode has unlimited hints', (tester) async {
    final c = await pumpLevel(tester, hints: 0, zen: true);
    expect(
      c.read(gameControllerProvider(2).notifier).requestHint(),
      HintOutcome.shown,
    );
    await tester.pump();
    expect(c.read(progressProvider).hints, 0); // nothing spent
  });
}
