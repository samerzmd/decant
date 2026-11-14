import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../logic/achievements.dart';
import '../../state/progress_controller.dart';
import '../../state/providers.dart';
import '../theme/app_theme.dart';

/// The badge's name, e.g. "Solve 100 levels".
String achievementName(AppLocalizations l, Achievement a) => switch (a.kind) {
      AchievementKind.levels => l.achLevels(a.target),
      AchievementKind.stars => l.achStars(a.target),
      AchievementKind.perfect => l.achPerfect(a.target),
      AchievementKind.dailies => l.achDailies(a.target),
      AchievementKind.dailyStreak => l.achDailyStreak(a.target),
      AchievementKind.playStreak => l.achPlayStreak(a.target),
      AchievementKind.challengeStage => l.achChallengeStage(a.target),
    };

IconData achievementIcon(AchievementKind kind) => switch (kind) {
      AchievementKind.levels => Icons.check_circle_rounded,
      AchievementKind.stars => Icons.star_rounded,
      AchievementKind.perfect => Icons.auto_awesome_rounded,
      AchievementKind.dailies => Icons.today_rounded,
      AchievementKind.dailyStreak => Icons.local_fire_department_rounded,
      AchievementKind.playStreak => Icons.event_repeat_rounded,
      AchievementKind.challengeStage => Icons.bolt_rounded,
    };

/// Bronze, silver and gold.
Color tierColor(int tier) => switch (tier) {
      1 => const Color(0xFFCD8B4E),
      2 => const Color(0xFFB4BDCC),
      _ => DecantColors.star,
    };

/// Every badge, earned ones first, with progress towards the rest.
class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final progress = ref.watch(progressProvider);
    final earned = Achievements.all.where((a) => a.unlockedIn(progress));
    final locked = Achievements.all.where((a) => !a.unlockedIn(progress));

    return Scaffold(
      body: DecantBackground(
        child: SafeArea(
          child: ReadableWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 20, 6),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back_rounded,
                          color: DecantColors.onSurface,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Text(
                          l.achievements,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: DecantColors.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
                  child: Text(
                    l.achievementsProgress(
                      earned.length,
                      Achievements.all.length,
                    ),
                    style: TextStyle(
                      color: DecantColors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                    children: [
                      for (final a in [...earned, ...locked])
                        _BadgeTile(achievement: a, progress: progress),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final Achievement achievement;
  final ProgressData progress;
  const _BadgeTile({required this.achievement, required this.progress});

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    final done = a.unlockedIn(progress);
    final value = a.progressIn(progress);
    final tint = done ? tierColor(a.tier) : DecantColors.subtle;
    final name = achievementName(context.l10n, a);
    return Semantics(
      label: done ? name : '$name: $value / ${a.target}',
      excludeSemantics: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
        decoration: BoxDecoration(
          color: DecantColors.ink.withValues(alpha: done ? 0.08 : 0.04),
          borderRadius: BorderRadius.circular(16),
          border: done ? Border.all(color: tint.withValues(alpha: 0.45)) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tint.withValues(alpha: done ? 0.2 : 0.1),
              ),
              child: Icon(
                done ? achievementIcon(a.kind) : Icons.lock_outline_rounded,
                color: tint,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: done
                          ? DecantColors.onSurface
                          : DecantColors.onSurface.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                  ),
                  if (!done) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: value / a.target,
                              minHeight: 6,
                              color: DecantColors.accent,
                              backgroundColor: DecantColors.recess,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '$value / ${a.target}',
                          style: TextStyle(
                            color: DecantColors.subtle,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
