import '../models/daily_stats.dart';

/// When the next streak reminder goes off and which streak it mentions.
class ReminderPlan {
  /// Local time the reminder shows.
  final DateTime at;

  /// The daily streak that's at stake then, or 0 for a plain "new puzzle"
  /// nudge.
  final int streak;

  const ReminderPlan(this.at, this.streak);

  @override
  bool operator ==(Object other) =>
      other is ReminderPlan && other.at == at && other.streak == streak;

  @override
  int get hashCode => Object.hash(at, streak);

  @override
  String toString() => 'ReminderPlan($at, streak $streak)';
}

/// Reminder hours offered in Settings.
const List<int> kReminderHours = [9, 13, 19, 21];

/// Plans one reminder, at [hour] o'clock, for the first day whose daily
/// isn't solved yet: today if it's still open and the hour hasn't passed,
/// otherwise tomorrow. Only one is ever pending, so a player who stops
/// playing gets a single nudge, not one every day.
///
/// The app plans again whenever progress changes or it comes back to the
/// foreground, so solving today's daily moves the reminder to tomorrow.
ReminderPlan planReminder({
  required DateTime now,
  required int hour,
  required DailyStats daily,
}) {
  final todayAt = DateTime(now.year, now.month, now.day, hour);
  final streakNow = daily.currentStreak(now);
  if (!daily.solvedOn(now) && now.isBefore(todayAt)) {
    // Solving today keeps a streak that's alive from yesterday.
    return ReminderPlan(todayAt, streakNow);
  }
  final tomorrowAt = DateTime(now.year, now.month, now.day + 1, hour);
  // Tomorrow the streak survives only if today's daily is solved.
  return ReminderPlan(tomorrowAt, daily.solvedOn(now) ? streakNow : 0);
}
