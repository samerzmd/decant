import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'decant_button.dart';
import 'star_row.dart';

/// Celebratory overlay shown when a level is solved.
class WinOverlay extends StatelessWidget {
  final int levelId;
  final int stars;
  final int moves;
  final VoidCallback onNext;
  final VoidCallback onReplay;
  final VoidCallback onLevels;

  const WinOverlay({
    super.key,
    required this.levelId,
    required this.stars,
    required this.moves,
    required this.onNext,
    required this.onReplay,
    required this.onLevels,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: child,
      ),
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
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
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2A3766), Color(0xFF31265C)],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
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
                  'Level $levelId solved',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: DecantColors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Beautifully done.',
                  style: TextStyle(
                    color: DecantColors.accent.withValues(alpha: 0.95),
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 20),
                StarRow(earned: stars, size: 40, animate: true),
                const SizedBox(height: 18),
                Text(
                  '$moves moves',
                  style: const TextStyle(
                    color: DecantColors.subtle,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                DecantButton(
                  label: 'Next level',
                  icon: Icons.arrow_forward_rounded,
                  expand: true,
                  onPressed: onNext,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DecantButton(
                        label: 'Replay',
                        icon: Icons.refresh_rounded,
                        primary: false,
                        onPressed: onReplay,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DecantButton(
                        label: 'Levels',
                        icon: Icons.grid_view_rounded,
                        primary: false,
                        onPressed: onLevels,
                      ),
                    ),
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
