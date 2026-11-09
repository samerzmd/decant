import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../logic/solver.dart';
import '../../models/move.dart';
import '../../state/game_session.dart';
import '../../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/decant_button.dart';
import '../widgets/game_board.dart';
import '../widgets/tutorial_card.dart';
import '../widgets/win_overlay.dart';

/// The gameplay screen: header (level + moves), the tube board, the control
/// bar (undo / hint / add-tube / how-to-play), a stuck banner, the win overlay
/// and the how-to-play guide.
class GameScreen extends ConsumerStatefulWidget {
  final int levelId;
  const GameScreen({super.key, required this.levelId});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  /// Current guide step, or null when the guide isn't showing.
  TutorialStep? _step;

  /// The move the guide highlights (free, unlike a hint).
  Move? _guide;

  int get levelId => widget.levelId;

  @override
  void initState() {
    super.initState();
    // Brand-new players get the guide on their first level automatically.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final seen = ref.read(settingsProvider).tutorialSeen;
      final played = ref.read(progressProvider).levelsCompleted > 0;
      if (!seen && !played) _startGuide(replay: false);
    });
  }

  void _startGuide({required bool replay}) {
    final controller = ref.read(gameControllerProvider(levelId).notifier);
    var session = ref.read(gameControllerProvider(levelId));
    if (session.status != GameStatus.playing || session.isAnimating) return;
    controller.clearHint();
    final move = Solver.nextMove(session.state);
    // Drop a selection that isn't the guide's source, so the first tap can't
    // pour somewhere unexpected.
    final sel = session.selected;
    if (sel != null && sel != move?.from) {
      controller.tapTube(sel);
      session = ref.read(gameControllerProvider(levelId));
    }
    ref.read(analyticsServiceProvider).logTutorialBegin(replay: replay);
    setState(() {
      _guide = move;
      _step = move == null
          ? TutorialStep.goal // stuck board: just explain the tools
          : (session.selected == move.from
              ? TutorialStep.pour
              : TutorialStep.pick);
    });
  }

  void _finishGuide({required bool skipped}) {
    if (_step == null) return;
    ref.read(analyticsServiceProvider).logTutorialComplete(skipped: skipped);
    ref.read(settingsProvider.notifier).markTutorialSeen();
    setState(() {
      _step = null;
      _guide = null;
    });
  }

  /// Advances the guide as the player follows it on the real board.
  void _onSession(GameSession? prev, GameSession next) {
    final step = _step;
    if (step == null) return;
    if (next.status == GameStatus.won) {
      _finishGuide(skipped: false);
      return;
    }
    if (step == TutorialStep.goal) return;
    final prevMoves = prev?.moves ?? 0;
    if (next.moves > prevMoves) {
      // Any pour completes the hands-on part.
      setState(() {
        _step = TutorialStep.goal;
        _guide = null;
      });
    } else if (next.moves < prevMoves) {
      // Undo / restart: re-aim the guide at the new board.
      final move = Solver.nextMove(next.state);
      setState(() {
        _guide = move;
        _step = move == null ? TutorialStep.goal : TutorialStep.pick;
      });
    } else {
      final picked = next.selected != null && next.selected == _guide?.from;
      final want = picked ? TutorialStep.pour : TutorialStep.pick;
      if (want != step) setState(() => _step = want);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(gameControllerProvider(levelId), _onSession);
    final session = ref.watch(gameControllerProvider(levelId));
    final controller = ref.read(gameControllerProvider(levelId).notifier);
    final muted = ref.watch(settingsProvider).audio.muted;

    // Only confirm if a level is genuinely in progress (moves made, not won).
    final needsConfirm =
        session.status == GameStatus.playing && session.moves > 0;

    Future<void> attemptLeave() async {
      if (!needsConfirm) {
        Navigator.of(context).pop();
        return;
      }
      final leave = await showDecantConfirm(
        context,
        title: 'Leave this level?',
        message: "Your progress on this level isn't saved — you'll start it "
            'over next time.',
        confirmLabel: 'Leave',
        cancelLabel: 'Keep playing',
        icon: Icons.exit_to_app_rounded,
      );
      if (leave && context.mounted) Navigator.of(context).pop();
    }

    return PopScope(
      canPop: !needsConfirm,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        attemptLeave();
      },
      child: Scaffold(
        body: DecantBackground(
          child: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    _Header(
                      levelId: levelId,
                      moves: session.moves,
                      difficulty: session.level.difficulty,
                      muted: muted,
                      onBack: attemptLeave,
                      onRestart: controller.restart,
                      onToggleMute: () =>
                          ref.read(settingsProvider.notifier).toggleMute(),
                    ),
                    // In the layout (not floating) so it never hides a tube.
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      child: _step == null
                          ? const SizedBox(width: double.infinity)
                          : TutorialCard(
                              step: _step!,
                              onSkip: () => _finishGuide(skipped: true),
                              onDone: () => _finishGuide(skipped: false),
                            ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: GameBoard(levelId: levelId, guide: _guide),
                      ),
                    ),
                    if (session.stuck && session.status == GameStatus.playing)
                      const _StuckBanner(),
                    _ControlBar(
                      canUndo: session.canUndo,
                      extraTubes: session.state.extraTubesRemaining,
                      onUndo: controller.undo,
                      onHint: () {
                        final ok = controller.requestHint();
                        if (!ok) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('No moves left — try undo or restart'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      onAddTube: () {
                        final ok = controller.addEmptyTube();
                        if (!ok) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('No extra tubes left'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      onHelp: _step == null
                          ? () => _startGuide(replay: true)
                          : null,
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
                if (session.status == GameStatus.won)
                  Positioned.fill(
                    child: WinOverlay(
                      levelId: levelId,
                      stars: session.stars,
                      moves: session.moves,
                      onNext: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          settings: const RouteSettings(name: '/game'),
                          builder: (_) => GameScreen(levelId: levelId + 1),
                        ),
                      ),
                      onReplay: controller.restart,
                      onLevels: () => Navigator.of(context).pop(),
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

class _Header extends StatelessWidget {
  final int levelId;
  final int moves;
  final int difficulty;
  final bool muted;
  final VoidCallback onBack;
  final VoidCallback onRestart;
  final VoidCallback onToggleMute;

  const _Header({
    required this.levelId,
    required this.moves,
    required this.difficulty,
    required this.muted,
    required this.onBack,
    required this.onRestart,
    required this.onToggleMute,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded,
                color: DecantColors.onSurface),
            onPressed: onBack,
          ),
          // Takes the leftover width and truncates, so the header never
          // overflows on narrow screens or with large system text.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Level $levelId',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: DecantColors.onSurface,
                  ),
                ),
                Text(
                  'Difficulty ${'●' * difficulty}${'○' * (5 - difficulty)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: DecantColors.subtle.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '$moves moves',
              style: const TextStyle(
                color: DecantColors.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
                muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                color: DecantColors.onSurface),
            onPressed: onToggleMute,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: DecantColors.onSurface),
            onPressed: onRestart,
          ),
        ],
      ),
    );
  }
}

class _ControlBar extends StatelessWidget {
  final bool canUndo;
  final int extraTubes;
  final VoidCallback onUndo;
  final VoidCallback onHint;
  final VoidCallback onAddTube;
  final VoidCallback? onHelp;

  const _ControlBar({
    required this.canUndo,
    required this.extraTubes,
    required this.onUndo,
    required this.onHint,
    required this.onAddTube,
    required this.onHelp,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          DecantIconButton(
            icon: Icons.undo_rounded,
            tooltip: 'Undo',
            onPressed: canUndo ? onUndo : null,
          ),
          DecantIconButton(
            icon: Icons.lightbulb_outline_rounded,
            tooltip: 'Hint',
            tint: DecantColors.star,
            onPressed: onHint,
          ),
          DecantIconButton(
            icon: Icons.add_circle_outline_rounded,
            tooltip: 'Add empty tube',
            badge: '$extraTubes',
            onPressed: extraTubes > 0 ? onAddTube : null,
          ),
          DecantIconButton(
            icon: Icons.help_outline_rounded,
            tooltip: 'How to play',
            onPressed: onHelp,
          ),
        ],
      ),
    );
  }
}

class _StuckBanner extends StatelessWidget {
  const _StuckBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE2425B).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: const Color(0xFFE2425B).withValues(alpha: 0.5)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: Color(0xFFF08AA6), size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'No moves left. Undo, restart, or add an empty tube.',
              style: TextStyle(color: DecantColors.onSurface, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
