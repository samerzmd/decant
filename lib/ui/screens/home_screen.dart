import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../logic/challenge.dart';
import '../../logic/daily_challenge.dart';
import '../../models/chapter.dart';
import '../../models/tube.dart';
import '../../state/progress_controller.dart';
import '../../state/providers.dart';
import '../reminder_prompt.dart';
import '../theme/app_theme.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/decant_button.dart';
import '../widgets/tube_widget.dart';
import 'challenges_screen.dart';
import 'game_screen.dart';
import 'level_select_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

/// The title screen: a shelf of live tubes, the next level one tap away, and
/// the daily and challenge modes as cards. Stats and settings sit up top as
/// small icons, out of the way of playing.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  /// Drives the tube bob, bubbles and the play button's glow.
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );

  /// Index of the shelf tube lifted by a tap, if any.
  int? _lifted;

  /// Four mixed tubes, the way a level looks before it's sorted.
  static final List<Tube> _shelf = [
    Tube(capacity: 4, segments: const [0, 5, 2, 3]),
    Tube(capacity: 4, segments: const [4, 1, 7, 0]),
    Tube(capacity: 4, segments: const [2, 3, 5]),
    Tube(capacity: 4, segments: const [7, 4, 1, 9]),
  ];

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
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(progressProvider);
    final today = ref.read(progressProvider.notifier).now();
    final reduceMotion = ref.watch(settingsProvider).reduceMotion ||
        MediaQuery.of(context).disableAnimations;
    if (reduceMotion && _idle.isAnimating) {
      _idle.stop();
    } else if (!reduceMotion && !_idle.isAnimating) {
      _idle.repeat();
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final exit = await showDecantConfirm(
          context,
          title: context.l10n.exitTitle,
          message: context.l10n.exitMessage,
          confirmLabel: context.l10n.exit,
          cancelLabel: context.l10n.stay,
          icon: Icons.logout_rounded,
        );
        if (exit) await SystemNavigator.pop();
      },
      child: Scaffold(
        body: DecantBackground(
          child: SafeArea(
            child: ReadableWidth(
              // Fills the screen with the spacers on normal phones; scrolls
              // instead of overflowing on short ones and in landscape.
              child: LayoutBuilder(
                builder: (context, box) =>
                    _buildPage(context, box, progress, today),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPage(
    BuildContext context,
    BoxConstraints box,
    ProgressData progress,
    DateTime today,
  ) {
    final l = context.l10n;
    final level = progress.unlockedLevel;
    var bestStage = 0;
    for (final mode in ChallengeMode.values) {
      bestStage = math.max(bestStage, progress.challenges.bestStage(mode));
    }
    final dailyDone = progress.daily.solvedOn(today);
    final streak = progress.daily.currentStreak(today);

    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: box.maxHeight),
        child: IntrinsicHeight(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
            child: Column(
              children: [
                _TopBar(
                  stars: progress.totalStars,
                  solved: progress.levelsCompleted,
                  onStats: () => _push(const StatsScreen(), '/stats'),
                  onSettings: () => _push(const SettingsScreen(), '/settings'),
                ),
                const Spacer(),
                AnimatedBuilder(
                  animation: _idle,
                  builder: (context, _) => _buildShelf(),
                ),
                const SizedBox(height: 14),
                const _Title(),
                const SizedBox(height: 6),
                Text(
                  l.tagline,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    letterSpacing: 2,
                    color: DecantColors.accent.withValues(alpha: 0.95),
                  ),
                ),
                const Spacer(),
                const SizedBox(height: 16),
                _ChapterCard(
                  chapter: Chapter.forLevel(level),
                  progress: progress,
                  onTap: () =>
                      _push(const LevelSelectScreen(), '/level_select'),
                ),
                const SizedBox(height: 14),
                AnimatedBuilder(
                  animation: _idle,
                  builder: (context, _) => _buildPlay(level),
                ),
                const SizedBox(height: 14),
                // Equal-height cards, however long either label is.
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _ModeCard(
                          title: dailyDone ? l.dailyDone : l.dailyChallenge,
                          subtitle: streak > 0 ? l.streak(streak) : l.dailyNew,
                          icon: dailyDone
                              ? Icons.check_circle_rounded
                              : Icons.today_rounded,
                          colors: const [Color(0xFFF2913D), Color(0xFFD94A6A)],
                          onTap: () => _openLevel(DailyChallenge.idFor(today)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ModeCard(
                          title: l.challenges,
                          subtitle: bestStage > 0
                              ? l.bestStage(bestStage)
                              : l.notPlayed,
                          icon: Icons.bolt_rounded,
                          colors: const [Color(0xFF8E5BD9), Color(0xFF4C63D2)],
                          onTap: () =>
                              _push(const ChallengesScreen(), '/challenges'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Plain methods rather than nested closures: per-frame code kept simple
  // for the release compiler (see the GameBoard GC crash fix).
  Widget _buildShelf() {
    final phase = _idle.value * 2 * math.pi;
    final time = _idle.value * 6.0;
    final shader = ref.watch(glassShaderProvider).asData?.value;
    final colorblind = ref.watch(settingsProvider).colorblindMode;
    final tubes = <Widget>[];
    for (var i = 0; i < _shelf.length; i++) {
      if (i > 0) tubes.add(const SizedBox(width: 18));
      tubes.add(_shelfTube(i, phase, time, shader, colorblind));
    }
    return SizedBox(
      height: 214,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // A soft oval pool of light under the tubes.
          Transform.scale(
            scaleX: 7,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    DecantColors.accent.withValues(alpha: 0.32),
                    DecantColors.accent.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: tubes,
            ),
          ),
        ],
      ),
    );
  }

  Widget _shelfTube(
    int i,
    double phase,
    double time,
    ui.FragmentShader? shader,
    bool colorblind,
  ) {
    final bob = math.sin(phase + i * 1.4) * 4;
    return Transform.translate(
      offset: Offset(0, bob),
      child: TubeWidget(
        tube: _shelf[i],
        width: 48,
        height: 168,
        time: time + i,
        colorblind: colorblind,
        selected: _lifted == i,
        wobble: math.sin(phase * 2 + i) * 0.015,
        shader: shader,
        onTap: () => _toggleLift(i),
      ),
    );
  }

  void _toggleLift(int i) {
    HapticFeedback.selectionClick();
    setState(() => _lifted = _lifted == i ? null : i);
  }

  Widget _buildPlay(int level) {
    final l = context.l10n;
    return _PlayButton(
      label: l.play,
      detail: l.levelHeader(level, l.chapterName(Chapter.forLevel(level))),
      glow: 0.5 + 0.5 * math.sin(_idle.value * 4 * math.pi),
      onTap: () => _openLevel(level),
    );
  }

  void _openLevel(int levelId) => _push(GameScreen(levelId: levelId), '/game');

  /// Opens [page]; back on Home, offers streak reminders once the player
  /// has started coming back.
  Future<void> _push(Widget page, String name) async {
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        settings: RouteSettings(name: name),
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
    if (mounted) await maybeOfferReminders(context, ref);
  }
}

class _TopBar extends StatelessWidget {
  final int stars;
  final int solved;
  final VoidCallback onStats;
  final VoidCallback onSettings;

  const _TopBar({
    required this.stars,
    required this.solved,
    required this.onStats,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                children: [
                  _Counter(
                    icon: Icons.star_rounded,
                    color: DecantColors.star,
                    value: stars,
                    semantics: context.l10n.stars,
                  ),
                  const SizedBox(width: 8),
                  _Counter(
                    icon: Icons.check_circle_rounded,
                    color: DecantColors.accent,
                    value: solved,
                    semantics: context.l10n.levelsSolved,
                  ),
                ],
              ),
            ),
          ),
        ),
        DecantIconButton(
          icon: Icons.insights_rounded,
          tooltip: context.l10n.stats,
          onPressed: onStats,
        ),
        const SizedBox(width: 10),
        DecantIconButton(
          icon: Icons.tune_rounded,
          tooltip: context.l10n.settings,
          onPressed: onSettings,
        ),
      ],
    );
  }
}

class _Counter extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int value;
  final String semantics;

  const _Counter({
    required this.icon,
    required this.color,
    required this.value,
    required this.semantics,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$semantics: $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 7, 14, 7),
        decoration: BoxDecoration(
          color: DecantColors.recess,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: DecantColors.ink.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 6),
            Text(
              '$value',
              style: TextStyle(
                color: DecantColors.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Decant" in a white-to-teal sheen.
class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          DecantColors.isLight ? DecantColors.onSurface : Colors.white,
          DecantColors.accent
        ],
      ).createShader(rect),
      child: const Text(
        'Decant',
        style: TextStyle(
          fontSize: 46,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          height: 1.0,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// The current chapter and how much of it is solved. Opens the level grid.
class _ChapterCard extends StatelessWidget {
  final Chapter chapter;
  final ProgressData progress;
  final VoidCallback onTap;

  const _ChapterCard({
    required this.chapter,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    var solved = 0;
    for (var id = chapter.firstLevel; id <= chapter.lastLevel; id++) {
      if (progress.resultFor(id) != null) solved++;
    }
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 10, 14),
          decoration: BoxDecoration(
            color: DecantColors.ink.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: DecantColors.ink.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l.chapter(chapter),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: DecantColors.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l.levels,
                    style: TextStyle(
                      color: DecantColors.subtle,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: DecantColors.subtle, size: 20),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        height: 8,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ColoredBox(
                              color: DecantColors.ink.withValues(alpha: 0.08),
                            ),
                            FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: solved / Chapter.size,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [
                                    DecantColors.accentDeep,
                                    DecantColors.accent,
                                  ]),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    l.chapterSolved(solved, Chapter.size),
                    style: TextStyle(
                      color: DecantColors.subtle.withValues(alpha: 0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The big call to action: a glowing pill naming the next level.
class _PlayButton extends StatelessWidget {
  final String label;
  final String detail;

  /// 0..1, how bright the halo is right now.
  final double glow;
  final VoidCallback onTap;

  const _PlayButton({
    required this.label,
    required this.detail,
    required this.glow,
    required this.onTap,
  });

  static const Color _ink = Color(0xFF0E1A2B);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          height: 84,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(42),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF6BE8D6), Color(0xFF2BB6A6)],
            ),
            boxShadow: [
              BoxShadow(
                color: DecantColors.accent.withValues(alpha: 0.25 + 0.2 * glow),
                blurRadius: 18 + 14 * glow,
                spreadRadius: 1,
              ),
              const BoxShadow(
                color: Color(0x66000000),
                offset: Offset(0, 6),
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: _ink,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.play_arrow_rounded,
                    color: DecantColors.accent, size: 38),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                          ),
                        ),
                        Text(
                          detail,
                          style: TextStyle(
                            color: _ink.withValues(alpha: 0.7),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// A colorful game-mode tile: daily challenge, challenges.
class _ModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 116),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.last.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
