// Every screen on a landscape phone, a tablet and a landscape tablet.
// Any overflow fails.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:decant/audio/audio_service.dart';
import 'package:decant/l10n/l10n.dart';
import 'package:decant/logic/challenge.dart';
import 'package:decant/logic/daily_challenge.dart';
import 'package:decant/models/app_settings.dart';
import 'package:decant/services/analytics_service.dart';
import 'package:decant/services/persistence_service.dart';
import 'package:decant/state/providers.dart';
import 'package:decant/ui/screens/challenges_screen.dart';
import 'package:decant/ui/screens/game_screen.dart';
import 'package:decant/ui/screens/home_screen.dart';
import 'package:decant/ui/screens/level_select_screen.dart';
import 'package:decant/ui/screens/settings_screen.dart';
import 'package:decant/ui/screens/sound_browser_screen.dart';
import 'package:decant/ui/screens/stats_screen.dart';

class _Q implements AnalyticsService {
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

void main() {
  final screens = <String, Widget>{
    'home': const HomeScreen(),
    'levels': const LevelSelectScreen(),
    'challenges': const ChallengesScreen(),
    'settings': const SettingsScreen(),
    'stats': const StatsScreen(),
    'sounds': const SoundBrowserScreen(kind: SoundKind.ambient),
    'level26': const GameScreen(levelId: 26),
    'daily': GameScreen(levelId: DailyChallenge.idFor(DateTime(2026, 11, 15))),
    'timed': GameScreen(levelId: Challenge.idFor(ChallengeMode.timed, 3)),
  };
  for (final (name, size) in [
    ('phone-landscape', const Size(1280, 720)),
    ('tablet', const Size(1600, 2400)),
    ('tablet-landscape', const Size(2400, 1600)),
  ]) {
    for (final e in screens.entries) {
      testWidgets('${e.key} $name', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        SharedPreferences.setMockInitialValues({});
        final p = await PersistenceService.create();
        await p.saveSettings(const AppSettings(tutorialSeen: true));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              persistenceProvider.overrideWithValue(p),
              audioServiceProvider.overrideWithValue(AudioService()),
              analyticsServiceProvider.overrideWithValue(_Q()),
            ],
            child: MaterialApp(
              locale: const Locale('en'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              builder: (c, child) => MediaQuery(
                data: MediaQuery.of(
                  c,
                ).copyWith(textScaler: TextScaler.noScaling),
                child: child!,
              ),
              home: e.value,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        // Overflows are reported by the framework with the widget path.
      });
    }
  }

  // Four-digit levels on a narrow phone used to show "Level 10…".
  testWidgets('level 1000 shows its whole number on a 360 dp phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'decant.unlocked': 1000});
    final p = await PersistenceService.create();
    await p.saveSettings(const AppSettings(tutorialSeen: true));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          persistenceProvider.overrideWithValue(p),
          audioServiceProvider.overrideWithValue(AudioService()),
          analyticsServiceProvider.overrideWithValue(_Q()),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: GameScreen(levelId: 1000),
        ),
      ),
    );
    await tester.pump();

    final title = find.text('Level 1000');
    expect(title, findsOneWidget);
    expect(
      tester.renderObject<RenderParagraph>(title).didExceedMaxLines,
      isFalse,
    );
    // The chapter moved to the line under the title.
    expect(find.textContaining('Tide · Difficulty'), findsOneWidget);
  });
}
