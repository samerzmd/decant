import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Displays [earned] of [total] stars. When [animate] is true the filled stars
/// pop in sequence (used on the win overlay).
class StarRow extends StatelessWidget {
  final int earned;
  final int total;
  final double size;
  final bool animate;

  const StarRow({
    super.key,
    required this.earned,
    this.total = 3,
    this.size = 28,
    this.animate = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final filled = i < earned;
        final star = Icon(
          filled ? Icons.star_rounded : Icons.star_outline_rounded,
          color: filled ? DecantColors.star : DecantColors.subtle.withOpacity(0.5),
          size: size,
        );
        if (!animate || !filled) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: star,
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 350 + i * 180),
            curve: Curves.elasticOut,
            builder: (_, v, child) =>
                Transform.scale(scale: v.clamp(0.0, 1.4), child: child),
            child: star,
          ),
        );
      }),
    );
  }
}
