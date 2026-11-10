import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:decant/audio/audio_service.dart';
import 'package:decant/l10n/l10n.dart';
import 'package:decant/logic/daily_challenge.dart';
import 'package:decant/models/app_settings.dart';
import 'package:decant/models/chapter.dart';
import 'package:decant/services/analytics_service.dart';
import 'package:decant/services/persistence_service.dart';
import 'package:decant/state/providers.dart';
import 'package:decant/ui/screens/game_screen.dart';
import 'package:decant/ui/screens/home_screen.dart';

class _QuietAnalytics implements AnalyticsService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Map<String, dynamic> _arb(String locale) =>
    jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  test('every language has every string', () {
    final keys = _arb('en').keys.where((k) => !k.startsWith('@')).toSet();
    for (final l in ['es', 'fr', 'de']) {
      final other = _arb(l).keys.where((k) => !k.startsWith('@')).toSet();
      expect(other, keys, reason: l);
    }
  });

  test('every language in Settings is supported', () {
    final supported =
        AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet();
    for (final l in AppLanguage.values) {
      if (l.code != null) expect(supported, contains(l.code), reason: l.name);
    }
  });

  test('the language survives a save; unknown names fall back', () {
    const s = AppSettings(language: AppLanguage.fr);
    expect(AppSettings.fromJson(s.toJson()).language, AppLanguage.fr);
    expect(AppSettings.fromJson({}).language, AppLanguage.system);
    expect(
      AppSettings.fromJson({'language': 'xx'}).language,
      AppLanguage.system,
    );
  });

  test('chapter names and dailies are translated', () async {
    final es = await AppLocalizations.delegate.load(const Locale('es'));
    expect(es.chapter(Chapter.forLevel(21)), 'Capítulo 2 · Marea');
    expect(es.moveCount(1), '1 movimiento');
    expect(es.moveCount(4), '4 movimientos');
  });

  Future<void> pump(WidgetTester tester, Widget home, Locale locale) async {
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
        child: MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: home,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('Home speaks Spanish', (tester) async {
    await pump(tester, const HomeScreen(), const Locale('es'));
    expect(find.text('Jugar'), findsOneWidget);
    expect(find.byTooltip('Ajustes'), findsOneWidget);
  });

  testWidgets('a daily in German shows a German date', (tester) async {
    final id = DailyChallenge.idFor(DateTime(2026, 3, 9));
    await pump(tester, GameScreen(levelId: id), const Locale('de'));
    expect(find.text('Täglich · 9. März'), findsOneWidget);
  });
}
