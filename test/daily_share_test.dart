import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:decant/l10n/app_localizations.dart';
import 'package:decant/logic/daily_challenge.dart';
import 'package:decant/logic/daily_share.dart';
import 'package:decant/ui/widgets/win_overlay.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final day = DailyChallenge.idFor(DateTime(2026, 11, 13));
  // The app's localization delegates load date formats; plain tests don't.
  setUpAll(initializeDateFormatting);

  group('share text', () {
    test('stars, moves, streak and the store link', () {
      final text = DailyShare.text(
        l10n: en,
        levelId: day,
        stars: 2,
        moves: 14,
        streak: 6,
      );
      expect(
        text,
        'Decant Daily · Nov 13, 2026\n'
        '★★☆ · 14 moves\n'
        '🔥 6-day streak\n'
        'Can you beat it? ${DailyShare.storeUrl}',
      );
    });

    test('a perfect solve says so; a one-day streak is left out', () {
      final text = DailyShare.text(
        l10n: en,
        levelId: day,
        stars: 3,
        moves: 9,
        streak: 1,
        perfect: true,
      );
      expect(text, contains('★★★ · 9 moves · ✨ Perfect'));
      expect(text, isNot(contains('🔥')));
    });

    test('Zen mode shares no stars or moves', () {
      final text = DailyShare.text(
        l10n: en,
        levelId: day,
        stars: 3,
        moves: 9,
        streak: 0,
        zen: true,
      );
      expect(text, contains('✓ Daily challenge solved'));
      expect(text, isNot(contains('★')));
      expect(text, isNot(contains('moves')));
    });

    test('is translated, with a local date format', () {
      final de = lookupAppLocalizations(const Locale('de'));
      final text = DailyShare.text(
        l10n: de,
        levelId: day,
        stars: 3,
        moves: 1,
        streak: 3,
      );
      expect(text, startsWith('Decant Tagesrätsel · 13. Nov. 2026'));
      expect(text, contains('1 Zug'));
      expect(text, contains('🔥 3 Tage in Folge'));
      expect(text, contains('Schaffst du es besser?'));
    });
  });

  group('win card', () {
    Future<void> pump(
      WidgetTester tester,
      int levelId, {
      VoidCallback? onShare,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: WinOverlay(
              levelId: levelId,
              stars: 3,
              moves: 10,
              onNext: () {},
              onReplay: () {},
              onLevels: () {},
              onShare: onShare,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('a solved daily offers Share', (tester) async {
      var shared = 0;
      await pump(tester, day, onShare: () => shared++);
      expect(find.text('Share'), findsOneWidget);
      await tester.tap(find.text('Share'));
      expect(shared, 1);
    });

    testWidgets('campaign levels have no Share button', (tester) async {
      await pump(tester, 12, onShare: () {});
      expect(find.text('Share'), findsNothing);
      expect(find.text('Levels'), findsOneWidget);
    });
  });
}
