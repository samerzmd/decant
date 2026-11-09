import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'decant_button.dart';

/// Steps of the how-to-play guide.
enum TutorialStep {
  /// Tap the glowing tube to pick up its top color.
  pick,

  /// Tap the other glowing tube to pour.
  pour,

  /// The goal and the helper tools; ends the guide.
  goal,
}

/// The floating card that walks a player through their first pour. It sits
/// over the top of the board and leaves the tubes tappable, because the first
/// two steps are done on the real level.
class TutorialCard extends StatelessWidget {
  final TutorialStep step;
  final VoidCallback onSkip;
  final VoidCallback onDone;

  const TutorialCard({
    super.key,
    required this.step,
    required this.onSkip,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xF22A3766), Color(0xF231265C)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: DecantColors.accent.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: KeyedSubtree(
            key: ValueKey(step),
            child: switch (step) {
              TutorialStep.pick => _Instruction(
                  icon: Icons.touch_app_rounded,
                  title: 'Tap the glowing tube',
                  body: 'That picks up the color on top.',
                  step: 0,
                  onSkip: onSkip,
                ),
              TutorialStep.pour => _Instruction(
                  icon: Icons.water_drop_rounded,
                  title: 'Now tap the other glowing tube',
                  body: 'Colors pour onto the same color or into an empty tube.',
                  step: 1,
                  onSkip: onSkip,
                ),
              TutorialStep.goal => _Goal(onDone: onDone),
            },
          ),
        ),
      ),
    );
  }
}

class _Instruction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final int step;
  final VoidCallback onSkip;

  const _Instruction({
    required this.icon,
    required this.title,
    required this.body,
    required this.step,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: DecantColors.accent.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: DecantColors.accent, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: DecantColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    body,
                    style: const TextStyle(fontSize: 13.5, color: DecantColors.subtle),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _Dots(active: step, count: 3),
            const Spacer(),
            TextButton(
              onPressed: onSkip,
              style: TextButton.styleFrom(
                foregroundColor: DecantColors.subtle,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Skip'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Goal extends StatelessWidget {
  final VoidCallback onDone;
  const _Goal({required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sort every tube into one color',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: DecantColors.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          "Fewer moves earn more stars. If you're stuck:",
          style: TextStyle(fontSize: 13.5, color: DecantColors.subtle),
        ),
        const SizedBox(height: 12),
        const _Tool(icon: Icons.undo_rounded, label: 'Undo a pour'),
        const _Tool(
          icon: Icons.lightbulb_outline_rounded,
          label: 'Show a hint (costs a star)',
          tint: DecantColors.star,
        ),
        const _Tool(icon: Icons.add_circle_outline_rounded, label: 'Add an empty tube'),
        const SizedBox(height: 8),
        Row(
          children: [
            const _Dots(active: 2, count: 3),
            const Spacer(),
            SizedBox(
              width: 132,
              child: DecantButton(label: 'Got it', primary: true, onPressed: onDone),
            ),
          ],
        ),
      ],
    );
  }
}

class _Tool extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? tint;
  const _Tool({required this.icon, required this.label, this.tint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: tint ?? DecantColors.onSurface),
          const SizedBox(width: 12),
          Flexible(
            child: Text(label,
                style: const TextStyle(fontSize: 14, color: DecantColors.onSurface)),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int active;
  final int count;
  const _Dots({required this.active, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(right: 6),
            width: i == active ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == active
                  ? DecantColors.accent
                  : Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}
