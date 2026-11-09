/// Lifetime play counters that per-level results can't give: total wins
/// (replays included) and the daily win streak.
class PlayStats {
  /// Every level won, replays included.
  final int wins;

  /// Days in a row with at least one win, as of [lastWinDay].
  final int streak;

  /// Longest streak ever reached.
  final int bestStreak;

  /// Local calendar day of the most recent win (`yyyy-mm-dd`), or null.
  final String? lastWinDay;

  const PlayStats({
    this.wins = 0,
    this.streak = 0,
    this.bestStreak = 0,
    this.lastWinDay,
  });

  /// Records a win at local time [now], extending the streak if the previous
  /// win was yesterday, keeping it if it was today, and restarting it at 1
  /// otherwise.
  PlayStats recordWin(DateTime now) {
    final today = dayKey(now);
    final int next;
    if (lastWinDay == today) {
      next = streak;
    } else if (lastWinDay == dayKey(_previousDay(now))) {
      next = streak + 1;
    } else {
      next = 1;
    }
    return PlayStats(
      wins: wins + 1,
      streak: next,
      bestStreak: next > bestStreak ? next : bestStreak,
      lastWinDay: today,
    );
  }

  /// The streak as it stands at [now]: still alive through today if the last
  /// win was today or yesterday, otherwise broken (0).
  int currentStreak(DateTime now) {
    if (lastWinDay == dayKey(now) || lastWinDay == dayKey(_previousDay(now))) {
      return streak;
    }
    return 0;
  }

  /// Whether there's already a win today (so the streak is safe until
  /// tomorrow).
  bool wonToday(DateTime now) => lastWinDay == dayKey(now);

  static String dayKey(DateTime t) => '${t.year.toString().padLeft(4, '0')}-'
      '${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';

  // Calendar arithmetic (not "minus 24 hours") so DST changes can't skip or
  // repeat a day.
  static DateTime _previousDay(DateTime t) =>
      DateTime(t.year, t.month, t.day - 1);

  Map<String, dynamic> toJson() => {
        'wins': wins,
        'streak': streak,
        'bestStreak': bestStreak,
        if (lastWinDay != null) 'lastWinDay': lastWinDay,
      };

  factory PlayStats.fromJson(Map<String, dynamic> j) => PlayStats(
        wins: j['wins'] as int? ?? 0,
        streak: j['streak'] as int? ?? 0,
        bestStreak: j['bestStreak'] as int? ?? 0,
        lastWinDay: j['lastWinDay'] as String?,
      );
}
