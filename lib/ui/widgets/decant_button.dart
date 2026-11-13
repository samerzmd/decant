import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A soft, animated button used across Decant. Scales down slightly on press
/// and comes in a filled (primary) or outlined (secondary) style.
class DecantButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool primary;
  final bool expand;

  const DecantButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.primary = true,
    this.expand = false,
  });

  @override
  State<DecantButton> createState() => _DecantButtonState();
}

class _DecantButtonState extends State<DecantButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final bg = widget.primary
        ? DecantColors.accent
        : DecantColors.ink.withValues(alpha: 0.06);
    final fg = widget.primary ? DecantColors.onAccent : DecantColors.onSurface;

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _down ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: LayoutBuilder(builder: (context, box) {
            // Side-by-side buttons on a phone get ~110 dp: trim the padding
            // so labels like "Replay" still fit.
            final compact = box.maxWidth < 150;
            return Container(
              width: widget.expand ? double.infinity : null,
              padding: EdgeInsets.symmetric(
                  horizontal: compact ? 10 : 18, vertical: 15),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(18),
                border: widget.primary
                    ? null
                    : Border.all(
                        color: DecantColors.ink.withValues(alpha: 0.16)),
                boxShadow: widget.primary
                    ? [
                        BoxShadow(
                          color: DecantColors.accent.withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        )
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize:
                    widget.expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, color: fg, size: 20),
                    SizedBox(width: compact ? 6 : 8),
                  ],
                  // When the button is tight (side-by-side buttons, long
                  // translations, large text) the label shrinks to fit rather
                  // than being cut off.
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        softWrap: false,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: fg,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// A circular icon button (used for in-game controls).
class DecantIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final String? badge;
  final Color? tint;

  const DecantIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.badge,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: Opacity(
        opacity: enabled ? 1 : 0.35,
        child: GestureDetector(
          onTap: onPressed,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: DecantColors.ink.withValues(alpha: 0.07),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: DecantColors.ink.withValues(alpha: 0.12)),
                ),
                child:
                    Icon(icon, color: tint ?? DecantColors.onSurface, size: 24),
              ),
              if (badge != null)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: DecantColors.accentDeep,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
