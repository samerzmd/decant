import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'decant_button.dart';
import '../../l10n/l10n.dart';

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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: DecantColors.panelTranslucent,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: DecantColors.accent.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: DecantColors.shadow,
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
                  title: context.l10n.tutorialTapTitle,
                  body: context.l10n.tutorialTapBody,
                  step: 0,
                  onSkip: onSkip,
                ),
              TutorialStep.pour => _Instruction(
                  icon: Icons.water_drop_rounded,
                  title: context.l10n.tutorialPourTitle,
                  body: context.l10n.tutorialPourBody,
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
  static TextStyle get _bodyStyle =>
      TextStyle(fontSize: 13.5, color: DecantColors.subtle);

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
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: DecantColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  // Always two lines tall (the invisible '\n' reserves them),
                  // so the board doesn't jump between the pick and pour steps.
                  Stack(
                    children: [
                      Text('\n', style: _bodyStyle),
                      Text(body, style: _bodyStyle),
                    ],
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
              child: Text(context.l10n.skip),
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
        Text(
          context.l10n.tutorialGoal,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: DecantColors.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.tutorialStars,
          style: TextStyle(fontSize: 13.5, color: DecantColors.subtle),
        ),
        const SizedBox(height: 12),
        _Tool(icon: Icons.undo_rounded, label: context.l10n.tutorialUndo),
        _Tool(
          icon: Icons.lightbulb_outline_rounded,
          label: context.l10n.tutorialHint,
          tint: DecantColors.star,
        ),
        _Tool(
          icon: Icons.add_circle_outline_rounded,
          label: context.l10n.tutorialAddTube,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const _Dots(active: 2, count: 3),
            const Spacer(),
            SizedBox(
              width: 132,
              child: DecantButton(
                label: context.l10n.gotIt,
                primary: true,
                onPressed: onDone,
              ),
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
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: DecantColors.onSurface),
            ),
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
                  : DecantColors.ink.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}
