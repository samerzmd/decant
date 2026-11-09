import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/decant_button.dart';
import '../widgets/decant_logo.dart';
import 'game_screen.dart';
import 'level_select_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Start the ambient bed if enabled (reads settings, constructing the
    // controller so saved settings are applied to the audio engine).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = ref.read(settingsProvider);
      if (settings.audio.ambientEnabled && !settings.audio.muted) {
        ref.read(audioServiceProvider).startAmbient();
      }
      if (settings.audio.musicEnabled && !settings.audio.muted) {
        ref.read(audioServiceProvider).startMusic();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(progressProvider);
    final continueLevel = progress.unlockedLevel;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final exit = await showDecantConfirm(
          context,
          title: 'Exit Decant?',
          message: 'Take a breath — your progress is saved. Leave the app?',
          confirmLabel: 'Exit',
          cancelLabel: 'Stay',
          icon: Icons.logout_rounded,
        );
        if (exit) await SystemNavigator.pop();
      },
      child: Scaffold(
      body: DecantBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                const DecantLogo(size: 96),
                const SizedBox(height: 18),
                const Text(
                  'Decant',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: DecantColors.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Pour. Sort. Unwind.',
                  style: TextStyle(
                    fontSize: 15,
                    letterSpacing: 1.8,
                    color: DecantColors.accent.withOpacity(0.95),
                  ),
                ),
                const SizedBox(height: 14),
                _StatPill(
                  stars: progress.totalStars,
                  completed: progress.levelsCompleted,
                ),
                const Spacer(),
                DecantButton(
                  label: continueLevel > 1
                      ? 'Continue · Level $continueLevel'
                      : 'Play',
                  icon: Icons.play_arrow_rounded,
                  expand: true,
                  onPressed: () => _openLevel(context, continueLevel),
                ),
                const SizedBox(height: 14),
                DecantButton(
                  label: 'Levels',
                  icon: Icons.grid_view_rounded,
                  primary: false,
                  expand: true,
                  onPressed: () => Navigator.of(context).push(
                    _route(const LevelSelectScreen(), name: '/level_select'),
                  ),
                ),
                const SizedBox(height: 14),
                DecantButton(
                  label: 'Settings',
                  icon: Icons.tune_rounded,
                  primary: false,
                  expand: true,
                  onPressed: () => Navigator.of(context).push(
                    _route(const SettingsScreen(), name: '/settings'),
                  ),
                ),
                const Spacer(),
                Text(
                  'A calm sorting game',
                  style: TextStyle(
                    color: DecantColors.subtle.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  void _openLevel(BuildContext context, int levelId) {
    Navigator.of(context)
        .push(_route(GameScreen(levelId: levelId), name: '/game'));
  }

  Route<T> _route<T>(Widget page, {required String name}) => PageRouteBuilder<T>(
        settings: RouteSettings(name: name),
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: anim,
          child: child,
        ),
      );
}

class _StatPill extends StatelessWidget {
  final int stars;
  final int completed;
  const _StatPill({required this.stars, required this.completed});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: DecantColors.star, size: 18),
          const SizedBox(width: 6),
          Text('$stars',
              style: const TextStyle(
                  color: DecantColors.onSurface, fontWeight: FontWeight.w700)),
          const SizedBox(width: 16),
          const Icon(Icons.check_circle_rounded,
              color: DecantColors.accent, size: 18),
          const SizedBox(width: 6),
          Text('$completed solved',
              style: const TextStyle(
                  color: DecantColors.onSurface, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
