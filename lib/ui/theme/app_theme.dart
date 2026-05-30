import 'package:flutter/material.dart';

/// Decant's calm visual identity: deep twilight gradients, soft glass, a single
/// warm-teal accent. Centralized so every screen stays on-brand.
class DecantColors {
  static const Color bgTop = Color(0xFF1B2440);
  static const Color bgMid = Color(0xFF243156);
  static const Color bgBottom = Color(0xFF2E2150);

  static const Color accent = Color(0xFF49D6C3); // calm teal
  static const Color accentDeep = Color(0xFF2BB6A6);
  static const Color onSurface = Color(0xFFEFF3FF);
  static const Color subtle = Color(0xFFA9B3D0);
  static const Color glassEdge = Color(0x55FFFFFF);
  static const Color star = Color(0xFFFFD66B);

  const DecantColors._();
}

/// The signature background gradient used across all screens.
const LinearGradient kBackgroundGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [DecantColors.bgTop, DecantColors.bgMid, DecantColors.bgBottom],
  stops: [0.0, 0.55, 1.0],
);

ThemeData buildDecantTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: DecantColors.bgMid,
    colorScheme: base.colorScheme.copyWith(
      primary: DecantColors.accent,
      secondary: DecantColors.accentDeep,
      surface: DecantColors.bgMid,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: DecantColors.onSurface,
      displayColor: DecantColors.onSurface,
      fontFamily: 'Roboto',
    ),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: DecantColors.accent,
      thumbColor: DecantColors.accent,
      inactiveTrackColor: DecantColors.subtle.withOpacity(0.3),
    ),
  );
}

/// A full-screen container painting the brand gradient. Wrap each screen body.
class DecantBackground extends StatelessWidget {
  final Widget child;
  const DecantBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: kBackgroundGradient),
      child: child,
    );
  }
}
