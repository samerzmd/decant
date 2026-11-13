import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The colour a notice is tinted with.
enum NoticeTone {
  /// Neutral information, in the accent teal.
  info,

  /// Something the player can't do right now, in gold.
  warning,

  /// A dead end (no moves left), in the warning red.
  blocked;

  Color get color => switch (this) {
        NoticeTone.info => DecantColors.accent,
        NoticeTone.warning => DecantColors.star,
        NoticeTone.blocked => DecantColors.danger,
      };
}

/// Shows a short branded notice: a floating glass card with a tinted icon,
/// in place of Material's flat grey snackbar.
///
/// It replaces any notice already showing, so tapping a button repeatedly
/// doesn't queue up copies. [bottom] lifts it above controls at the bottom of
/// the screen (the game screen's control bar).
void showDecantNotice(
  BuildContext context,
  String message, {
  IconData icon = Icons.info_outline_rounded,
  NoticeTone tone = NoticeTone.info,
  double bottom = 16,
  Duration duration = const Duration(milliseconds: 2600),
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: DecantNotice(message: message, icon: icon, tone: tone),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        // The card draws its own soft shadow; don't clip it to a hard band.
        clipBehavior: Clip.none,
        padding: EdgeInsets.zero,
        margin: EdgeInsets.fromLTRB(20, 0, 20, bottom),
        duration: duration,
        dismissDirection: DismissDirection.horizontal,
      ),
    );
}

/// The card [showDecantNotice] shows, public so it can be tested and reused.
class DecantNotice extends StatelessWidget {
  final String message;
  final IconData icon;
  final NoticeTone tone;

  const DecantNotice({
    super.key,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.tone = NoticeTone.info,
  });

  @override
  Widget build(BuildContext context) {
    final tint = tone.color;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.92, end: 1),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutBack,
          builder: (context, s, child) =>
              Transform.scale(scale: s, child: child),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 18, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: DecantColors.panel,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: tint.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(
                  color: DecantColors.shadow.withValues(
                      alpha: DecantColors.shadow.a * 0.6),
                  blurRadius: 16,
                  spreadRadius: -4,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: tint, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: DecantColors.onSurface,
                    ),
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
