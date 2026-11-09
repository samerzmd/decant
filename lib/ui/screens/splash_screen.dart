import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/decant_logo.dart';
import 'home_screen.dart';

/// Brief branded splash. It deliberately mirrors the native (OS) splash — same
/// `#243156` background and the same centered mark — so the hand-off from the
/// native splash is seamless and reads as a single splash. It simply holds the
/// logo briefly (the native splash now disappears almost instantly thanks to the
/// fast startup), fades the tagline in, then routes to Home.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    return Scaffold(
      // Solid color matches the native splash background exactly.
      backgroundColor: DecantColors.bgMid,
      body: Stack(
        children: [
          // Logo stays dead-centre — same place as the native splash mark — so
          // there is no jump during the hand-off.
          const Center(child: DecantLogo(size: 120)),
          Align(
            alignment: const Alignment(0, 0.45),
            child: FadeTransition(
              opacity: fade,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Decant',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: DecantColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pour. Sort. Unwind.',
                    style: TextStyle(
                      fontSize: 15,
                      letterSpacing: 1.8,
                      color: DecantColors.accent.withValues(alpha: 0.95),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
