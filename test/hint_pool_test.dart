import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:decant/audio/audio_service.dart';
import 'package:decant/models/app_settings.dart';
import 'package:decant/services/ad_service.dart';
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

/// Rewarded ads without the SDK: [ready] says whether a video is loaded, and
/// [earn] whether the player watches it through.
class _FakeAds extends AdService {
  bool ready;
  final bool earn;
  int shown = 0;
  _FakeAds({this.ready = true, this.earn = true}) : super.off();

  @override
  bool get enabled => true;

  @override
  bool get rewardedReady => ready;

  @override
  Future<bool> showRewarded() async {
    shown++;
    return ready && earn;
  }
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
    AdService? ads,
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
        if (ads != null) adServiceProvider.overrideWithValue(ads),
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

  group('watch a video for a hint', () {
    // The board animates without end, so step time instead of settling.
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> offerAndWatch(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Hint'));
      await settle(tester);
      expect(find.text('Out of hints'), findsOneWidget);
      await tester.tap(find.text('Watch video'));
      await settle(tester);
    }

    testWidgets('a watched video gives a hint and shows it', (tester) async {
      final ads = _FakeAds();
      final c = await pumpLevel(tester, hints: 0, ads: ads);
      await offerAndWatch(tester);
      expect(ads.shown, 1);
      expect(c.read(gameControllerProvider(2)).hint, isNotNull);
      expect(c.read(progressProvider).hints, 0); // earned, then used
      expect(c.read(gameControllerProvider(2)).state.hintsUsed, 1);
    });

    testWidgets('closing the video early gives nothing', (tester) async {
      final c = await pumpLevel(tester, hints: 0, ads: _FakeAds(earn: false));
      await offerAndWatch(tester);
      expect(c.read(gameControllerProvider(2)).hint, isNull);
      expect(c.read(progressProvider).hints, 0);
      expect(
        find.text('The video ended early, so no hint this time.'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('says so when no video is ready', (tester) async {
      final ads = _FakeAds(ready: false);
      final c = await pumpLevel(tester, hints: 0, ads: ads);
      await offerAndWatch(tester);
      expect(ads.shown, 0);
      expect(c.read(gameControllerProvider(2)).hint, isNull);
      expect(
        find.text('No video is ready right now. Try again in a moment.'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('"Not now" plays nothing', (tester) async {
      final ads = _FakeAds();
      final c = await pumpLevel(tester, hints: 0, ads: ads);
      await tester.tap(find.byTooltip('Hint'));
      await settle(tester);
      await tester.tap(find.text('Not now'));
      await settle(tester);
      expect(ads.shown, 0);
      expect(c.read(gameControllerProvider(2)).hint, isNull);
    });

    testWidgets('a hint left in the pool never offers a video', (tester) async {
      final ads = _FakeAds();
      await pumpLevel(tester, hints: 1, ads: ads);
      await tester.tap(find.byTooltip('Hint'));
      await settle(tester);
      expect(find.text('Out of hints'), findsNothing);
      expect(ads.shown, 0);
    });
  });
}
