import 'package:flutter/material.dart';

import '../../logic/challenge.dart';
import '../../logic/daily_challenge.dart';
import '../theme/app_theme.dart';
import 'decant_button.dart';
import 'star_row.dart';
import '../../l10n/l10n.dart';

/// Celebratory overlay shown when a level is solved.
class WinOverlay extends StatelessWidget {
  final int levelId;
  final int stars;
  final int moves;
  final VoidCallback onNext;
  final VoidCallback onReplay;
  final VoidCallback onLevels;

  /// For a daily challenge: the daily streak after this win.
  final int dailyStreak;

  /// Zen mode: no stars or move count, just the celebration.
  final bool zen;

  /// A perfect solve (par, no hints, no extra tube), and the level's par.
  final bool perfect;
  final int par;

  const WinOverlay({
    super.key,
    required this.levelId,
    required this.stars,
    required this.moves,
    required this.onNext,
    required this.onReplay,
    required this.onLevels,
    this.dailyStreak = 0,
    this.zen = false,
    this.perfect = false,
    this.par = 0,
  });

  @override
  Widget build(BuildContext context) {
    final daily = DailyChallenge.isDaily(levelId);
    final challenge = Challenge.isChallenge(levelId);
    final title = daily
        ? context.l10n.dailySolved
        : challenge
            ? context.l10n.stageCleared(Challenge.stageOf(levelId))
            : context.l10n.levelSolved(levelId);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: child,
      ),
      child: Container(
        color: DecantColors.scrim,
        alignment: Alignment.center,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.7, end: 1),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutBack,
          builder: (context, s, child) =>
              Transform.scale(scale: s, child: child),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 36),
            padding: const EdgeInsets.fromLTRB(28, 30, 28, 26),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: DecantColors.panel,
              ),
              borderRadius: BorderRadius.circular(28),
              border:
                  Border.all(color: DecantColors.ink.withValues(alpha: 0.12)),
              boxShadow: [
                BoxShadow(
                  color: DecantColors.accent.withValues(alpha: 0.25),
                  blurRadius: 40,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: DecantColors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  daily && dailyStreak > 0
                      ? context.l10n.streakBeautifullyDone(dailyStreak)
                      : context.l10n.beautifullyDone,
                  style: TextStyle(
                    color: DecantColors.accent.withValues(alpha: 0.95),
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
                if (!zen) ...[
                  const SizedBox(height: 20),
                  StarRow(earned: stars, size: 40, animate: true),
                  const SizedBox(height: 18),
                  Text(
                    context.l10n.moveCount(moves),
                    style: TextStyle(
                      color: DecantColors.subtle,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (perfect)
                    const _PerfectChip()
                  else if (par > 0)
                    Text(
                      context.l10n.perfectTarget(context.l10n.moveCount(par)),
                      style: TextStyle(
                        color: DecantColors.subtle.withValues(alpha: 0.75),
                        fontSize: 12,
                      ),
                    ),
                ],
                const SizedBox(height: 24),
                DecantButton(
                  label: daily
                      ? context.l10n.done
                      : challenge
                          ? context.l10n.nextStage
                          : context.l10n.nextLevel,
                  icon:
                      daily ? Icons.check_rounded : Icons.arrow_forward_rounded,
                  expand: true,
                  onPressed: onNext,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DecantButton(
                        label: context.l10n.replay,
                        icon: Icons.refresh_rounded,
                        primary: false,
                        onPressed: onReplay,
                      ),
                    ),
                    // A daily has no next level, and "Done" already goes home.
                    if (!daily) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: DecantButton(
                          label: challenge
                              ? context.l10n.challenges
                              : context.l10n.levels,
                          icon: Icons.grid_view_rounded,
                          primary: false,
                          onPressed: onLevels,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Badge for a perfect solve.
class _PerfectChip extends StatelessWidget {
  const _PerfectChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: DecantColors.accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DecantColors.accent.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, color: DecantColors.accent, size: 16),
          const SizedBox(width: 6),
          Text(
            context.l10n.perfect,
            style: TextStyle(
              color: DecantColors.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
