import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/audio_service.dart';
import '../audio/haptic_service.dart';
import '../logic/pour_engine.dart';
import '../logic/solver.dart';
import '../models/game_state.dart';
import '../models/level.dart';
import '../services/analytics_service.dart';
import 'game_session.dart';
import 'providers.dart';

/// How long a single pour animation runs. Audio sequencing is timed to match.
const Duration kPourDuration = Duration(milliseconds: 540);

/// Drives a single play session: selection, pouring (with synced audio/haptics),
/// undo, restart, hints, the add-tube power-up, win detection and scoring.
class GameController extends StateNotifier<GameSession> {
  final Ref _ref;
  final Level _level;

  /// Consecutive completing moves → escalating combo sound.
  int _comboChain = 0;
  int _pourSeq = 0;

  GameController(this._ref, this._level) : super(_initial(_level)) {
    _analytics.logLevelStart(_level.id);
  }

  AudioService get _audio => _ref.read(audioServiceProvider);
  HapticService get _haptic => _ref.read(hapticServiceProvider);
  AnalyticsService get _analytics => _ref.read(analyticsServiceProvider);

  @override
  void dispose() {
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
    return GameSession(level: level, state: state, par: par);
  }

  // ---- Input ------------------------------------------------------------- //

  void tapTube(int index) {
    if (state.status == GameStatus.won || state.isAnimating) return;

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
    );

    state = state.copyWith(
      state: outcome.state,
      clearSelected: true,
      clearHint: true,
      pour: anim,
      stuck: false,
    );

    // --- Audio + haptics, timed to the animation -------------------------- //
    _haptic.pourStart();
    await _audio.startPour(fillFraction: destBefore / capacity);
    // Ramp the pour pitch upward as the destination fills.
    final destAfter = destBefore + outcome.move.count;
    unawaited(_rampPourPitch(destBefore, destAfter, capacity));

    await Future<void>.delayed(kPourDuration);
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

    final solved = state.state.isSolved;
    final stuck = !solved &&
        PourEngine.isStuck(state.state) &&
        !PourEngine.extraTubeWouldHelp(state.state);

    state = state.copyWith(clearPour: true, stuck: stuck);

    if (solved) {
      _onWin();
    }
  }

  Future<void> _rampPourPitch(int before, int after, int capacity) async {
    const steps = 5;
    for (var i = 1; i <= steps; i++) {
      if (!mounted || state.pour == null) return;
      final f = (before + (after - before) * (i / steps)) / capacity;
      _audio.updatePourPitch(f);
      await Future<void>.delayed(kPourDuration ~/ steps);
    }
  }

  void _onWin() {
    final stars = _computeStars();
    state = state.copyWith(status: GameStatus.won, stars: stars);
    _audio.win();
    _haptic.win();
    _ref
        .read(progressProvider.notifier)
        .recordWin(_level.id, stars, state.moves);
    _analytics.logLevelComplete(
      levelId: _level.id,
      stars: stars,
      moves: state.moves,
      hintsUsed: state.state.hintsUsed,
    );
  }

  int _computeStars() {
    final moves = state.moves;
    final par = state.par <= 0 ? 1 : state.par;
    final hints = state.state.hintsUsed;
    int stars;
    if (moves <= (par * 1.25).ceil()) {
      stars = 3;
    } else if (moves <= (par * 1.9).ceil()) {
      stars = 2;
    } else {
      stars = 1;
    }
    if (hints > 0) stars = (stars - 1).clamp(1, 3);
    return stars;
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
    );
  }

  /// Highlight the next optimal move. Returns false if none is available.
  bool requestHint() {
    if (state.isAnimating || state.status == GameStatus.won) return false;
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
    if (state.isAnimating || !state.canAddTube) return false;
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
