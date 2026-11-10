import 'play_stats.dart';

/// Daily challenge progress: the streak of days solved in a row and the best
/// stars earned on recent days.
class DailyStats {
  /// Days in a row with the daily solved, as of [lastDay].
  final int streak;

  /// Longest streak ever reached.
  final int bestStreak;

  /// Dailies solved in total (each day counts once).
  final int completed;

  /// Most recent day solved (`yyyy-mm-dd`), or null.
  final String? lastDay;

  /// Best stars per solved day (`yyyy-mm-dd` → 1..3), recent days only.
  final Map<String, int> stars;

  /// How many days of stars to keep; older days only matter to the counters.
  static const keepDays = 60;

  const DailyStats({
    this.streak = 0,
    this.bestStreak = 0,
    this.completed = 0,
    this.lastDay,
    this.stars = const {},
  });

  /// Records solving the daily for local day [day] with [stars].
  ///
  /// The first solve of a day extends the streak if the previous solved day
  /// was the day before, and restarts it at 1 otherwise. Replays only improve
  /// that day's stars. Finishing an older daily after midnight (started the
  /// evening before) still counts for its own day but can't rewind the
  /// streak.
  DailyStats record(DateTime day, int stars) {
    final key = PlayStats.dayKey(day);
    final next = Map<String, int>.of(this.stars);
    final already = next.containsKey(key);
    next[key] = (next[key] ?? 0) > stars ? next[key]! : stars;

    // Drop days older than [keepDays] (yyyy-mm-dd sorts by date).
    final cutoff = PlayStats.dayKey(
      DateTime(day.year, day.month, day.day - keepDays),
    );
    next.removeWhere((k, _) => k.compareTo(cutoff) < 0);

    if (already) return _copy(stars: next);
    final older = lastDay != null && lastDay!.compareTo(key) > 0;
    if (older) return _copy(stars: next, completed: completed + 1);

    final yesterday =
        PlayStats.dayKey(DateTime(day.year, day.month, day.day - 1));
    final s = lastDay == yesterday ? streak + 1 : 1;
    return DailyStats(
      streak: s,
      bestStreak: s > bestStreak ? s : bestStreak,
      completed: completed + 1,
      lastDay: key,
      stars: next,
    );
  }

  /// The streak as it stands at [now]: alive if today's or yesterday's daily
  /// was solved, otherwise broken (0).
  int currentStreak(DateTime now) {
    final yesterday =
        PlayStats.dayKey(DateTime(now.year, now.month, now.day - 1));
    if (lastDay == PlayStats.dayKey(now) || lastDay == yesterday) return streak;
    return 0;
  }

  /// Best stars on local day [day], or null if that daily wasn't solved.
  int? starsOn(DateTime day) => stars[PlayStats.dayKey(day)];

  bool solvedOn(DateTime day) => starsOn(day) != null;

  DailyStats _copy({Map<String, int>? stars, int? completed}) => DailyStats(
        streak: streak,
        bestStreak: bestStreak,
        completed: completed ?? this.completed,
        lastDay: lastDay,
        stars: stars ?? this.stars,
      );

  Map<String, dynamic> toJson() => {
        'streak': streak,
        'bestStreak': bestStreak,
        'completed': completed,
        if (lastDay != null) 'lastDay': lastDay,
        'stars': stars,
      };

  factory DailyStats.fromJson(Map<String, dynamic> j) => DailyStats(
        streak: j['streak'] as int? ?? 0,
        bestStreak: j['bestStreak'] as int? ?? 0,
        completed: j['completed'] as int? ?? 0,
        lastDay: j['lastDay'] as String?,
        stars: {
          for (final e in ((j['stars'] as Map?) ?? const {}).entries)
            e.key as String: (e.value as num).toInt(),
        },
      );
}
