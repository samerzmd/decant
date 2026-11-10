import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'decant_button.dart';

/// Shown when a challenge runs out of moves or time.
class FailOverlay extends StatelessWidget {
  /// True for Against the clock (time ran out), false for Move limit.
  final bool timedOut;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  const FailOverlay({
    super.key,
    required this.timedOut,
    required this.onRetry,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 36),
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2A3766), Color(0xFF31265C)],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              timedOut ? Icons.timer_off_outlined : Icons.block_rounded,
              color: DecantColors.subtle,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              timedOut ? "Time's up" : 'Out of moves',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: DecantColors.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Take a breath and try again.',
              style: TextStyle(
                color: DecantColors.accent.withValues(alpha: 0.95),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 22),
            DecantButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              expand: true,
              onPressed: onRetry,
            ),
            const SizedBox(height: 12),
            DecantButton(
              label: 'Back',
              icon: Icons.arrow_back_rounded,
              primary: false,
              expand: true,
              onPressed: onBack,
            ),
          ],
        ),
      ),
    );
  }
}
