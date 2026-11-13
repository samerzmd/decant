import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import 'daily_challenge.dart';

/// The text a player shares after solving the daily challenge, e.g.
///
/// ```
/// Decant Daily · Nov 13, 2026
/// ★★☆ · 14 moves
/// 🔥 6-day streak
/// Can you beat it? https://play.google.com/store/apps/details?id=…
/// ```
///
/// Everyone gets the same daily, so the result means something to friends.
/// It never includes anything personal: no name, account or device details.
class DailyShare {
  DailyShare._();

  static const storeUrl =
      'https://play.google.com/store/apps/details?id=com.buildable.decant';

  static String text({
    required AppLocalizations l10n,
    required int levelId,
    required int stars,
    required int moves,
    required int streak,
    bool perfect = false,
    bool zen = false,
  }) {
    final day = DailyChallenge.dateOf(levelId);
    final date = DateFormat.yMMMd(l10n.localeName).format(day);
    final lines = <String>[l10n.dailyShareTitle(date)];
    if (zen) {
      // Zen mode hides stars and moves, so the share does too.
      lines.add('✓ ${l10n.dailySolved}');
    } else {
      final s = stars.clamp(0, 3);
      final result = '${'★' * s}${'☆' * (3 - s)} · ${l10n.moveCount(moves)}';
      lines.add(perfect ? '$result · ✨ ${l10n.perfect}' : result);
    }
    if (streak > 1) lines.add('🔥 ${l10n.dailyShareStreak(streak)}');
    lines.add('${l10n.dailyShareInvite} $storeUrl');
    return lines.join('\n');
  }
}
