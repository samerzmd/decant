import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../logic/solver.dart';
import '../../models/move.dart';
import '../../state/game_controller.dart';
import '../../state/game_session.dart';
import '../../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/decant_button.dart';
import '../widgets/game_board.dart';
import '../widgets/tutorial_card.dart';
import '../widgets/win_overlay.dart';
import '../../logic/challenge.dart';
import '../../logic/star_rating.dart';
import '../../models/chapter.dart';
import '../../models/liquid_palette.dart';
import '../../logic/daily_challenge.dart';
import '../widgets/fail_overlay.dart';
import '../../l10n/l10n.dart';

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

  /// Whether an empty hint pool offers a video. Challenge ladders don't: the
  /// clock would keep running during the video.
  bool get _videoHintsOffered =>
      ref.read(adServiceProvider).enabled && !Challenge.isChallenge(levelId);

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  /// Out of hints: offers a short rewarded video for one, then shows it.
  Future<void> _offerVideoHint() async {
    final l10n = context.l10n;
    final watch = await showDecantConfirm(
      context,
      title: l10n.outOfHintsTitle,
      message: l10n.watchForHintMessage,
      confirmLabel: l10n.watchVideo,
      cancelLabel: l10n.notNow,
      icon: Icons.ondemand_video_rounded,
    );
    if (!watch || !mounted) return;
    final ads = ref.read(adServiceProvider);
    if (!ads.rewardedReady) {
      _toast(l10n.noVideoReady);
      return;
    }
    // On Android the video is its own activity, so the app lifecycle pauses
    // and resumes the sound around it.
    final earned = await ads.showRewarded();
    ref.read(analyticsServiceProvider).logRewardedHint(earned: earned);
    if (!mounted) return;
    if (!earned) {
      _toast(l10n.videoNotFinished);
      return;
    }
    await ref.read(progressProvider.notifier).grantHint();
    if (!mounted) return;
    final outcome =
        ref.read(gameControllerProvider(levelId).notifier).requestHint();
    // The board may have no useful move; the earned hint stays in the pool.
    if (outcome == HintOutcome.noMove) _toast(l10n.noMovesHint);
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
        title: context.l10n.leaveLevelTitle,
        message: context.l10n.leaveLevelMessage,
        confirmLabel: context.l10n.leave,
        cancelLabel: context.l10n.keepPlaying,
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
          // Campaign levels take their chapter's palette, on the default
          // theme only; other themes keep their own background.
          colors: _isCampaign(levelId) && activeUiTheme == UiTheme.twilight
              ? Chapter.forLevel(levelId).colors
              : null,
          child: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    _Header(
                      levelId: levelId,
                      counter: _counter(
                        session,
                        zen: ref.watch(settingsProvider).zenMode,
                      ),
                      // Challenges and Zen mode don't award stars.
                      threeStarMoves: ref.watch(settingsProvider).zenMode ||
                              Challenge.isChallenge(levelId)
                          ? null
                          : StarRating.threeStarMoves(session.par),
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
                      hints: ref.watch(settingsProvider).zenMode
                          ? null
                          : ref.watch(progressProvider).hints,
                      onHint: () {
                        final outcome = controller.requestHint();
                        if (outcome == HintOutcome.noHintsLeft &&
                            _videoHintsOffered) {
                          _offerVideoHint();
                          return;
                        }
                        final message = switch (outcome) {
                          HintOutcome.shown => null,
                          HintOutcome.noMove => context.l10n.noMovesHint,
                          HintOutcome.noHintsLeft => context.l10n.noHintsLeft,
                        };
                        if (message != null) _toast(message);
                      },
                      onAddTube: () {
                        final ok = controller.addEmptyTube();
                        if (!ok) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(context.l10n.noExtraTubes),
                              duration: const Duration(seconds: 2),
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
                if (session.status == GameStatus.failed)
                  Positioned.fill(
                    child: FailOverlay(
                      timedOut: session.timeLimit != null,
                      onRetry: controller.restart,
                      onBack: () => Navigator.of(context).pop(),
                    ),
                  ),
                if (session.status == GameStatus.won)
                  Positioned.fill(
                    child: WinOverlay(
                      levelId: levelId,
                      stars: session.stars,
                      moves: session.moves,
                      dailyStreak: ref.watch(progressProvider).daily.streak,
                      // Challenges don't award stars either.
                      zen: ref.watch(settingsProvider).zenMode ||
                          Challenge.isChallenge(levelId),
                      perfect: session.perfect,
                      par: session.par,
                      onNext: DailyChallenge.isDaily(levelId)
                          ? () => Navigator.of(context).pop()
                          : () => Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  settings: const RouteSettings(name: '/game'),
                                  builder: (_) =>
                                      GameScreen(levelId: levelId + 1),
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

/// The header pill: pours left in a Move limit challenge, the clock in
/// Against the clock, otherwise the move count (hidden in Zen mode).
String? _counter(GameSession s, {required bool zen}) {
  final left = s.movesLeft;
  if (left != null) return '$left ${left == 1 ? 'move' : 'moves'} left';
  final time = s.timeLeft;
  if (time != null) {
    final secs = time.inSeconds;
    return '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}';
  }
  if (zen) return null;
  return '${s.moves} ${s.moves == 1 ? 'move' : 'moves'}';
}

class _Header extends StatelessWidget {
  final int levelId;

  /// Text for the counter pill, or null to hide it.
  final String? counter;

  /// Move target for three stars, or null when stars don't apply.
  final int? threeStarMoves;
  final int difficulty;
  final bool muted;
  final VoidCallback onBack;
  final VoidCallback onRestart;
  final VoidCallback onToggleMute;

  const _Header({
    required this.levelId,
    required this.counter,
    required this.threeStarMoves,
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
            icon: Icon(Icons.arrow_back_rounded, color: DecantColors.onSurface),
            onPressed: onBack,
          ),
          // Takes the width the pill doesn't need. The title shrinks a little
          // rather than cutting off a long level number, and the line under
          // it truncates, so the header never overflows on narrow screens or
          // with large system text.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    DailyChallenge.isDaily(levelId)
                        ? context.l10n.dailyChallengeTitle(levelId)
                        : Challenge.isChallenge(levelId)
                            ? context.l10n.challengeTitle(levelId)
                            : context.l10n.levelTitle(levelId),
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: DecantColors.onSurface,
                    ),
                  ),
                ),
                Text(
                  [
                    if (!DailyChallenge.isDaily(levelId) &&
                        !Challenge.isChallenge(levelId))
                      context.l10n.chapterName(Chapter.forLevel(levelId)),
                    context.l10n.difficulty(
                        '${'●' * difficulty}${'○' * (5 - difficulty)}'),
                    if (threeStarMoves != null)
                      context.l10n.threeStarsIn(threeStarMoves!),
                  ].join(' · '),
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
          if (counter != null)
            // As wide as its text, up to a cap; past that (large system text)
            // the text scales down instead of overflowing.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: DecantColors.ink.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    counter!,
                    style: TextStyle(
                      color: DecantColors.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
            icon: Icon(Icons.refresh_rounded, color: DecantColors.onSurface),
            onPressed: onRestart,
          ),
        ],
      ),
    );
  }
}

class _ControlBar extends StatelessWidget {
  final bool canUndo;

  /// Hints in the pool, or null when unlimited (Zen mode).
  final int? hints;
  final int extraTubes;
  final VoidCallback onUndo;
  final VoidCallback onHint;
  final VoidCallback onAddTube;
  final VoidCallback? onHelp;

  const _ControlBar({
    required this.canUndo,
    required this.hints,
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
            tooltip: context.l10n.undo,
            onPressed: canUndo ? onUndo : null,
          ),
          DecantIconButton(
            icon: Icons.lightbulb_outline_rounded,
            tooltip: context.l10n.hint,
            tint: DecantColors.star,
            badge: hints == null ? null : '$hints',
            onPressed: onHint,
          ),
          DecantIconButton(
            icon: Icons.add_circle_outline_rounded,
            tooltip: context.l10n.addTube,
            badge: '$extraTubes',
            onPressed: extraTubes > 0 ? onAddTube : null,
          ),
          DecantIconButton(
            icon: Icons.help_outline_rounded,
            tooltip: context.l10n.howToPlay,
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
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              color: DecantColors.danger, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.l10n.stuckBanner,
              style: TextStyle(color: DecantColors.onSurface, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Campaign levels are the positive ids below the challenge ranges.
bool _isCampaign(int levelId) =>
    !DailyChallenge.isDaily(levelId) && !Challenge.isChallenge(levelId);
