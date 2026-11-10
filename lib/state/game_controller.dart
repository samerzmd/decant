import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../audio/audio_service.dart';
import '../audio/haptic_service.dart';
import '../logic/challenge.dart';
import '../logic/pour_engine.dart';
import '../logic/solver.dart';
import '../logic/star_rating.dart';
import '../models/game_state.dart';
import '../models/level.dart';
import '../services/analytics_service.dart';
import 'game_session.dart';
import 'providers.dart';

/// Drives a single play session: selection, pouring (with synced audio/haptics),
/// undo, restart, hints, the add-tube power-up, win detection and scoring.
class GameController extends StateNotifier<GameSession> {
  final Ref _ref;
  final Level _level;

  /// Consecutive completing moves → escalating combo sound.
  int _comboChain = 0;
  int _pourSeq = 0;

  /// Ticks the Against the clock timer once a second.
  Timer? _clock;

  GameController(this._ref, this._level) : super(_initial(_level)) {
    _analytics.logLevelStart(_level.id);
  }

  AudioService get _audio => _ref.read(audioServiceProvider);
  HapticService get _haptic => _ref.read(hapticServiceProvider);
  AnalyticsService get _analytics => _ref.read(analyticsServiceProvider);

  @override
  void dispose() {
    _clock?.cancel();
    // Leaving the level must immediately kill the looping pour sound, even if
    // we were mid-pour when the screen was popped.
    try {
      _ref.read(audioServiceProvider).stopPour();
    } catch (_) {/* container already tearing down */}
    super.dispose();
  }

  static GameSession _initial(Level level) {
    final state = GameState(
      tubes: level.buildTubes(),
      extraTubesRemaining: level.extraTubeAllowance,
    );
    // Estimate optimal length for the star rating (board is guaranteed solvable).
    final solution = Solver.solve(state);
    final par = solution?.length ?? (level.colorCount * level.capacity);
    final mode =
        Challenge.isChallenge(level.id) ? Challenge.modeOf(level.id) : null;
    final timeLimit =
        mode == ChallengeMode.timed ? Challenge.timeLimit(par) : null;
    return GameSession(
      level: level,
      state: state,
      par: par,
      moveLimit: mode == ChallengeMode.moves ? Challenge.moveLimit(par) : null,
      timeLimit: timeLimit,
      timeLeft: timeLimit,
    );
  }

  // ---- Input ------------------------------------------------------------- //

  void tapTube(int index) {
    if (state.status != GameStatus.playing || state.isAnimating) return;

    final selected = state.selected;
    if (selected == null) {
      // Select a non-empty tube as the pour source.
      if (state.state.tubes[index].isEmpty) return;
      _audio.tap();
      _haptic.select();
      state = state.copyWith(selected: index, clearHint: true);
      return;
    }

    if (selected == index) {
      // Tapping the selected tube again deselects it.
      _audio.tap();
      state = state.copyWith(clearSelected: true);
      return;
    }

    if (PourEngine.canPour(state.state, selected, index)) {
      _pour(selected, index);
    } else {
      // Illegal target: switch selection to it if it can be a source.
      if (!state.state.tubes[index].isEmpty) {
        _audio.tap();
        _haptic.select();
        state = state.copyWith(selected: index, clearHint: true);
      } else {
        state = state.copyWith(clearSelected: true);
      }
    }
  }

  Future<void> _pour(int from, int to) async {
    final capacity = _level.capacity;
    final destBefore = state.state.tubes[to].segments.length;
    final outcome = PourEngine.applyPour(state.state, from, to);
    if (outcome == null) return;

    final anim = PourAnim(
      id: ++_pourSeq,
      from: from,
      to: to,
      color: outcome.move.color,
      count: outcome.move.count,
      destFillBefore: destBefore,
      // Pour speed setting; audio sequencing below is timed to match.
      duration: _ref.read(settingsProvider).pourSpeed.duration,
    );

    state = state.copyWith(
      state: outcome.state,
      clearSelected: true,
      clearHint: true,
      pour: anim,
      stuck: false,
    );
    _startClockIfNeeded();

    // --- Audio + haptics, timed to the animation -------------------------- //
    // The board plays the same timeline (see PourAnim.flowStart/flowEnd):
    // fly over and tip, flow, tip back and return. Nothing on this timeline
    // awaits audio, so a slow sound call can't push the game out of step.
    var at = 0.0;
    Future<void> until(double fraction) {
      final wait = anim.duration * (fraction - at);
      at = fraction;
      return Future<void>.delayed(wait);
    }

    await until(PourAnim.flowStart);
    if (!mounted) return;
    _haptic.pourStart();
    // Ramp the pour pitch upward as the destination fills.
    final destAfter = destBefore + outcome.move.count;
    var flowing = true;
    unawaited(
      _audio.startPour(fillFraction: destBefore / capacity).then((_) {
        // A slow start (first pour, audio waking up) that lands after the
        // flow ended must not leave the trickle looping.
        if (!flowing || !mounted) return _audio.stopPour();
        return _rampPourPitch(
          destBefore,
          destAfter,
          capacity,
          anim.duration * (PourAnim.flowEnd - PourAnim.flowStart),
        );
      }),
    );

    await until(PourAnim.flowEnd + PourAnim.fall);
    flowing = false;
    if (!mounted) {
      // Screen left mid-pour: make sure the looping trickle doesn't linger.
      await _audio.stopPour();
      return;
    }

    await _audio.stopPour();
    _audio.droplet();
    _haptic.droplet();
    _audio.glug();

    if (outcome.move.completedDestination) {
      _audio.completion(chainIndex: _comboChain);
      _haptic.tubeComplete();
      _comboChain++;
    } else {
      _comboChain = 0;
    }

    // Let the source tube tip back and fly home before the next move.
    await until(1);
    if (!mounted) return;

    final solved = state.state.isSolved;
    final stuck = !solved &&
        PourEngine.isStuck(state.state) &&
        !PourEngine.extraTubeWouldHelp(state.state);

    state = state.copyWith(clearPour: true, stuck: stuck);

    // Time ran out while this pour was in the air: it doesn't count.
    if (state.status == GameStatus.failed) return;
    if (solved) {
      _onWin();
    } else if ((state.movesLeft ?? 1) <= 0) {
      _fail();
    }
  }

  Future<void> _rampPourPitch(
    int before,
    int after,
    int capacity,
    Duration duration,
  ) async {
    const steps = 5;
    for (var i = 1; i <= steps; i++) {
      if (!mounted || state.pour == null) return;
      final f = (before + (after - before) * (i / steps)) / capacity;
      _audio.updatePourPitch(f);
      await Future<void>.delayed(duration ~/ steps);
    }
  }

  void _startClockIfNeeded() {
    if (state.timeLimit == null || state.clockStarted) return;
    state = state.copyWith(clockStarted: true);
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted || state.status != GameStatus.playing) {
      _clock?.cancel();
      return;
    }
    final left = (state.timeLeft ?? Duration.zero) - const Duration(seconds: 1);
    if (left <= Duration.zero) {
      state = state.copyWith(timeLeft: Duration.zero);
      _fail();
    } else {
      state = state.copyWith(timeLeft: left);
    }
  }

  /// A challenge ran out of moves or time.
  void _fail() {
    _clock?.cancel();
    _comboChain = 0;
    state = state.copyWith(
      status: GameStatus.failed,
      clearSelected: true,
      clearHint: true,
    );
    _haptic.select();
  }

  void _onWin() {
    _clock?.cancel();
    // Zen mode earns no stars: the level counts as solved, nothing more.
    final zen = _ref.read(settingsProvider).zenMode;
    final moves = state.moves;
    final hints = state.state.hintsUsed;
    final stars =
        zen ? 0 : StarRating.stars(moves: moves, par: state.par, hints: hints);
    final perfect = !zen &&
        !Challenge.isChallenge(_level.id) &&
        StarRating.isPerfect(
          moves: moves,
          par: state.par,
          hints: hints,
          usedExtraTube:
              state.state.extraTubesRemaining < _level.extraTubeAllowance,
        );
    state = state.copyWith(
      status: GameStatus.won,
      stars: stars,
      perfect: perfect,
    );
    _audio.win();
    _haptic.win();
    _ref
        .read(progressProvider.notifier)
        .recordWin(_level.id, stars, moves, perfect: perfect);
    _analytics.logLevelComplete(
      levelId: _level.id,
      stars: stars,
      moves: moves,
      hintsUsed: hints,
    );
  }

  // ---- Actions ----------------------------------------------------------- //

  void undo() {
    if (!state.canUndo || state.isAnimating) return;
    final newState = PourEngine.undo(state.state);
    _comboChain = 0;
    _audio.tap();
    _haptic.select();
    state = state.copyWith(
      state: newState,
      clearSelected: true,
      clearHint: true,
      status: GameStatus.playing,
      stuck: false,
    );
  }

  void restart() {
    if (state.isAnimating) return;
    _comboChain = 0;
    _clock?.cancel();
    _audio.tap();
    final fresh = GameState(
      tubes: _level.buildTubes(),
      extraTubesRemaining: _level.extraTubeAllowance,
    );
    state = state.copyWith(
      state: fresh,
      clearSelected: true,
      clearHint: true,
      status: GameStatus.playing,
      stuck: false,
      stars: 0,
      perfect: false,
      timeLeft: state.timeLimit,
      clockStarted: false,
    );
  }

  /// Highlight the next optimal move. Returns false if none is available.
  bool requestHint() {
    if (state.isAnimating || state.status != GameStatus.playing) return false;
    final move = Solver.nextMove(state.state);
    if (move == null) return false;
    _audio.tap();
    state = state.copyWith(
      hint: move,
      state: state.state.copyWith(hintsUsed: state.state.hintsUsed + 1),
      clearSelected: true,
    );
    _analytics.logHintUsed(_level.id);
    return true;
  }

  void clearHint() {
    if (state.hint != null) state = state.copyWith(clearHint: true);
  }

  /// Use the "add empty tube" power-up. Returns false if no uses remain.
  bool addEmptyTube() {
    if (state.isAnimating ||
        !state.canAddTube ||
        state.status != GameStatus.playing) {
      return false;
    }
    final next = PourEngine.addEmptyTube(state.state);
    if (next == null) return false;
    _audio.glug();
    _haptic.select();
    state = state.copyWith(
      state: next,
      clearSelected: true,
      clearHint: true,
      stuck: false,
    );
    _analytics.logAddTubeUsed(_level.id);
    return true;
  }
}
