import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:decant/l10n/app_localizations.dart';
import 'package:decant/logic/achievements.dart';
import 'package:decant/logic/custom_level.dart';
import 'package:decant/logic/daily_challenge.dart';
import 'package:decant/models/daily_stats.dart';
import 'package:decant/models/level_result.dart';
import 'package:decant/models/play_stats.dart';
import 'package:decant/services/leaderboard_service.dart';
import 'package:decant/services/persistence_service.dart';
import 'package:decant/state/progress_controller.dart';
import 'package:decant/state/providers.dart';
import 'package:decant/ui/screens/achievements_screen.dart';

ProgressData progress({
  int levels = 0,
  int stars = 0,
  int perfect = 0,
  DailyStats daily = const DailyStats(),
  PlayStats stats = const PlayStats(),
}) =>
    ProgressData(
      unlockedLevel: levels + 1,
      totalStars: stars,
      levelsCompleted: levels,
      results: {
        for (var i = 1; i <= perfect; i++)
          i: const LevelResult(stars: 3, bestMoves: 5, perfect: true),
      },
      daily: daily,
      stats: stats,
    );

void main() {
  group('achievements', () {
    test('unlock from existing progress, best streaks included', () {
      final p = progress(
        levels: 120,
        stars: 200,
        perfect: 1,
        daily: const DailyStats(completed: 3, bestStreak: 8),
        stats: const PlayStats(bestStreak: 3),
      );
      final ids = Achievements.unlockedIds(p);
      expect(ids, containsAll(['levels_1', 'levels_100', 'stars_150']));
      expect(ids, containsAll(['perfect_1', 'dailyStreak_7', 'playStreak_3']));
      expect(ids, isNot(contains('levels_250')));
      expect(ids, isNot(contains('dailyStreak_30')));
    });

    test('a win reports only the badges it newly earns', () {
      final before = progress(levels: 9, stars: 29);
      final after = progress(levels: 10, stars: 31);
      final fresh = Achievements.newlyUnlocked(before, after);
      expect(fresh.map((a) => a.id), ['levels_10', 'stars_30']);
      expect(Achievements.newlyUnlocked(after, after), isEmpty);
    });

    test('every badge has a name in every language', () {
      for (final code in ['en', 'es', 'fr', 'de']) {
        final l = lookupAppLocalizations(Locale(code));
        for (final a in Achievements.all) {
          expect(achievementName(l, a), isNotEmpty);
        }
      }
      final en = lookupAppLocalizations(const Locale('en'));
      expect(achievementName(en, Achievements.all.first),
          'Solve your first level');
    });
  });

  group('custom levels', () {
    final tubes = [
      [0, 1, 2, 0],
      [1, 2, 0, 1],
      [2, 0, 1, 2],
    ];

    test('codes round-trip, even inside a pasted message', () {
      final code = CustomLevel.encode(tubes);
      expect(code, startsWith('DCT1-'));
      expect(CustomLevel.decode(code), tubes);
      expect(CustomLevel.decode('Try this! $code — have fun'), tubes);
    });

    test('broken or tampered codes are rejected', () {
      final code = CustomLevel.encode(tubes);
      final flipped = code.substring(0, code.length - 2) +
          (code[code.length - 2] == 'A' ? 'B' : 'A') +
          code[code.length - 1];
      expect(CustomLevel.decode(flipped), isNull);
      expect(CustomLevel.decode('DCT1-!!!'), isNull);
      expect(CustomLevel.decode('hello'), isNull);
      expect(
          CustomLevel.decode(CustomLevel.encode([
            [0, 0, 0],
            [1, 1, 1, 1],
            [2, 2, 2, 2],
          ])),
          isNull);
    });

    test('checks counts, an already-sorted board and solvability', () {
      expect(CustomLevel.problem(tubes), isNull);
      expect(
          CustomLevel.problem([
            [0, 1],
            [1, 2],
            [2, 0],
          ]),
          CustomLevelProblem.incomplete);
      expect(
          CustomLevel.problem([
            [0, 0, 0, 0],
            [1, 1, 1, 1],
            [2, 2, 2, 2],
          ]),
          CustomLevelProblem.alreadySolved);
    });

    test('custom ids never look like dailies or campaign levels', () {
      final id = CustomLevel.idFor(tubes);
      expect(CustomLevel.isCustom(id), isTrue);
      expect(DailyChallenge.isDaily(id), isFalse);
      final daily = DailyChallenge.idFor(DateTime(2026, 11, 13));
      expect(DailyChallenge.isDaily(daily), isTrue);
      expect(CustomLevel.isCustom(daily), isFalse);
      expect(CustomLevel.toLevel(tubes).emptyTubes, 2);
    });

    test('winning a custom level records no progress', () async {
      SharedPreferences.setMockInitialValues({});
      final persistence = await PersistenceService.create();
      final controller = ProgressController(persistence);
      await controller.recordWin(CustomLevel.idFor(tubes), 3, 9);
      expect(controller.state.levelsCompleted, 0);
      expect(controller.state.stats.wins, 0);
    });

    test('My levels keeps the newest 20 codes without duplicates', () async {
      SharedPreferences.setMockInitialValues({});
      final p = await PersistenceService.create();
      for (var i = 0; i < 25; i++) {
        await p.rememberCustomLevel('DCT1-$i');
      }
      await p.rememberCustomLevel('DCT1-10');
      final codes = p.customLevelCodes();
      expect(codes.length, PersistenceService.maxCustomLevels);
      expect(codes.first, 'DCT1-10');
      expect(codes.where((c) => c == 'DCT1-10').length, 1);
    });
  });

  group('leaderboard', () {
    test('names are friendly, stable and short', () {
      final a = LeaderboardService.nameFor('abc123');
      expect(a, LeaderboardService.nameFor('abc123'));
      expect(a, matches(RegExp(r'^[A-Z][a-z]+ [A-Z][a-z]+ \d{2}$')));
      expect(a.length, lessThanOrEqualTo(32));
      expect(LeaderboardService.nameFor('xyz789'), isNot(a));
    });

    test('day keys are the daily date', () {
      final id = DailyChallenge.idFor(DateTime(2026, 11, 13));
      expect(LeaderboardService.dayKey(id), '20261113');
    });
  });

  testWidgets('achievements screen lists earned badges first', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final persistence = await PersistenceService.create();
    await persistence.recordResult(1, 3, 6);
    await tester.pumpWidget(ProviderScope(
      overrides: [persistenceProvider.overrideWithValue(persistence)],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AchievementsScreen(),
      ),
    ));
    expect(find.text('Achievements'), findsOneWidget);
    expect(
        find.text('1 of ${Achievements.all.length} unlocked'), findsOneWidget);
    expect(find.text('Solve your first level'), findsOneWidget);
    expect(find.text('1 / 10'), findsOneWidget);
  });
}
