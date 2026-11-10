/// The daily challenge: one level per local calendar day, the same for every
/// player.
///
/// Daily levels live in their own id space: the negative of the date as
/// `yyyymmdd` (10 Nov 2026 → -20261110). Campaign levels are positive, so
/// everything keyed by level id (the generator, the level and game providers,
/// the game screen) works for dailies unchanged and the two never collide.
class DailyChallenge {
  DailyChallenge._();

  /// The level id of the daily challenge for local day [day].
  static int idFor(DateTime day) =>
      -(day.year * 10000 + day.month * 100 + day.day);

  static bool isDaily(int levelId) => levelId < 0;

  /// The local day a daily [levelId] belongs to.
  static DateTime dateOf(int levelId) {
    final v = -levelId;
    return DateTime(v ~/ 10000, (v ~/ 100) % 100, v % 100);
  }

  /// Colors in the daily for each weekday, Monday first: a gentle start to
  /// the week, building to the hardest puzzle on Sunday.
  static const List<int> colorsByWeekday = [5, 5, 6, 6, 7, 8, 9];

  static int colorsFor(DateTime day) => colorsByWeekday[day.weekday - 1];

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// Short title for a daily level, e.g. "Daily · Nov 10".
  static String title(int levelId) {
    final d = dateOf(levelId);
    return 'Daily · ${_months[d.month - 1]} ${d.day}';
  }
}
