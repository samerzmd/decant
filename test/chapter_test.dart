import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:decant/audio/audio_service.dart';
import 'package:decant/logic/daily_challenge.dart';
import 'package:decant/models/app_settings.dart';
import 'package:decant/models/chapter.dart';
import 'package:decant/models/liquid_palette.dart';
import 'package:decant/services/analytics_service.dart';
import 'package:decant/services/persistence_service.dart';
import 'package:decant/state/providers.dart';
import 'package:decant/ui/screens/game_screen.dart';
import 'package:decant/ui/screens/level_select_screen.dart';
import 'package:decant/ui/theme/app_theme.dart';

class _QuietAnalytics implements AnalyticsService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  test('every 20 levels is a chapter, and the six themes cycle', () {
    expect(Chapter.forLevel(1).number, 1);
    expect(Chapter.forLevel(20).number, 1);
    expect(Chapter.forLevel(21).number, 2);
    expect(Chapter.forLevel(21).title, 'Chapter 2 · Tide');
    expect(Chapter.forLevel(26).firstLevel, 21);
    expect(Chapter.forLevel(26).lastLevel, 40);
    // Chapter 7 reuses chapter 1's theme but keeps counting.
    final seventh = Chapter.forLevel(121);
    expect(seventh.number, 7);
    expect(seventh.name, 'Dawn');
    expect(seventh.colors, Chapter.forLevel(1).colors);
    expect(Chapter.names.length, Chapter.palettes.length);
    for (final p in Chapter.palettes) {
      expect(p.length, 3);
    }
  });

  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    Future<void> Function(PersistenceService p)? seed,
  }) async {
    tester.view.physicalSize = const Size(1440, 3088);
    tester.view.devicePixelRatio = 3.5;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final persistence = await PersistenceService.create();
    await persistence.saveSettings(const AppSettings(tutorialSeen: true));
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
        child: MaterialApp(home: home),
      ),
    );
    await tester.pump();
  }

  List<Color>? backgroundColors(WidgetTester tester) =>
      tester.widget<DecantBackground>(find.byType(DecantBackground)).colors;

  testWidgets('the level grid is split into chapters', (tester) async {
    await pump(
      tester,
      const LevelSelectScreen(),
      seed: (p) async {
        await p.recordResult(1, 3, 6);
        await p.recordResult(2, 2, 9);
      },
    );
    expect(find.text('Chapter 1 · Dawn'), findsOneWidget);
    expect(find.text('2/20 solved'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Chapter 2 · Tide'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('0/20 solved'), findsWidgets);
  });

  testWidgets('a campaign level wears its chapter', (tester) async {
    await pump(tester, const GameScreen(levelId: 26));
    expect(find.text('Level 26 · Tide'), findsOneWidget);
    expect(backgroundColors(tester), Chapter.forLevel(26).colors);
  });

  testWidgets('dailies keep the usual background', (tester) async {
    final id = DailyChallenge.idFor(DateTime(2026, 11, 10));
    await pump(tester, GameScreen(levelId: id));
    expect(backgroundColors(tester), isNull);
  });

  testWidgets('other themes override chapter colors', (tester) async {
    activeUiTheme = UiTheme.midnight;
    addTearDown(() => activeUiTheme = UiTheme.twilight);
    await pump(tester, const GameScreen(levelId: 26));
    expect(backgroundColors(tester), isNull);
    final bg = tester.widget<DecantBackground>(find.byType(DecantBackground));
    expect(bg.effectiveColors, UiTheme.midnight.colors);
  });
}
