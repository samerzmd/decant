import 'dart:math' as math;

import '../logic/challenge.dart';
import '../state/progress_controller.dart';

/// What an achievement counts.
enum AchievementKind {
  levels,
  stars,
  perfect,
  dailies,
  dailyStreak,
  playStreak,
  challengeStage,
}

/// One badge: reach [target] of [kind]. Tiers 1–3 are bronze, silver, gold.
class Achievement {
  final AchievementKind kind;
  final int target;
  final int tier;
  const Achievement(this.kind, this.target, this.tier);

  /// Stable id, e.g. `levels_100`; used for analytics and unlock tracking.
  String get id => '${kind.name}_$target';

  /// How far the player is, from 0 to [target].
  int progressIn(ProgressData p) =>
      math.min(target, Achievements.valueOf(kind, p));

  bool unlockedIn(ProgressData p) => Achievements.valueOf(kind, p) >= target;
}

/// Decant's achievements. Every one is worked out from progress the game
/// already keeps (levels, stars, streaks…), so nothing extra is stored, they
/// can't get out of step, and cloud save carries them to other devices.
class Achievements {
  Achievements._();

  static const all = <Achievement>[
    Achievement(AchievementKind.levels, 1, 1),
    Achievement(AchievementKind.levels, 10, 1),
    Achievement(AchievementKind.levels, 50, 2),
    Achievement(AchievementKind.levels, 100, 2),
    Achievement(AchievementKind.levels, 250, 3),
    Achievement(AchievementKind.levels, 500, 3),
    Achievement(AchievementKind.levels, 1000, 3),
    Achievement(AchievementKind.stars, 30, 1),
    Achievement(AchievementKind.stars, 150, 2),
    Achievement(AchievementKind.stars, 600, 3),
    Achievement(AchievementKind.perfect, 1, 1),
    Achievement(AchievementKind.perfect, 25, 2),
    Achievement(AchievementKind.perfect, 100, 3),
    Achievement(AchievementKind.dailies, 1, 1),
    Achievement(AchievementKind.dailies, 30, 2),
    Achievement(AchievementKind.dailyStreak, 7, 2),
    Achievement(AchievementKind.dailyStreak, 30, 3),
    Achievement(AchievementKind.playStreak, 3, 1),
    Achievement(AchievementKind.playStreak, 14, 2),
    Achievement(AchievementKind.challengeStage, 5, 1),
    Achievement(AchievementKind.challengeStage, 15, 2),
    Achievement(AchievementKind.challengeStage, 30, 3),
  ];

  /// The player's current count for [kind]. Streaks use the best ever, so a
  /// badge stays earned after a streak ends.
  static int valueOf(AchievementKind kind, ProgressData p) => switch (kind) {
        AchievementKind.levels => p.levelsCompleted,
        AchievementKind.stars => p.totalStars,
        AchievementKind.perfect => p.perfectLevels,
        AchievementKind.dailies => p.daily.completed,
        AchievementKind.dailyStreak => p.daily.bestStreak,
        AchievementKind.playStreak => p.stats.bestStreak,
        AchievementKind.challengeStage =>
          ChallengeMode.values.map(p.challenges.bestStage).fold(0, math.max),
      };

  static Set<String> unlockedIds(ProgressData p) => {
        for (final a in all)
          if (a.unlockedIn(p)) a.id,
      };

  /// Badges unlocked going from [before] to [after], in list order.
  static List<Achievement> newlyUnlocked(
    ProgressData before,
    ProgressData after,
  ) {
    final had = unlockedIds(before);
    return [
      for (final a in all)
        if (!had.contains(a.id) && a.unlockedIn(after)) a,
    ];
  }
}
