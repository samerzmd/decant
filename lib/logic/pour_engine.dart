import '../models/game_state.dart';
import '../models/move.dart';
import '../models/tube.dart';

/// Result of attempting a pour, returned to the UI/audio layer so it can play
/// the right sounds, haptics and animations.
class PourOutcome {
  final GameState state;
  final Move move;

  /// Number of *other* tubes (besides the destination) that are already complete
  /// — used together with [move.completedDestination] for combo detection.
  final int totalComplete;

  const PourOutcome({
    required this.state,
    required this.move,
    required this.totalComplete,
  });
}

/// Pure functions implementing classic water-sort rules. No Flutter, no I/O —
/// fully unit-testable.
class PourEngine {
  const PourEngine._();

  /// How many segments would move if we poured [from] → [to].
  /// Returns 0 if the pour is illegal.
  static int pourableCount(GameState state, int from, int to) {
    if (from == to) return 0;
    final src = state.tubes[from];
    final dst = state.tubes[to];
    if (src.isEmpty || dst.isFull) return 0;

    final color = src.topColor!;
    if (!dst.isEmpty && dst.topColor != color) return 0;

    final movable = src.topRunLength;
    final room = dst.freeSpace;
    return movable < room ? movable : room;
  }

  /// Whether a pour [from] → [to] is currently legal.
  static bool canPour(GameState state, int from, int to) =>
      pourableCount(state, from, to) > 0;

  /// Apply a pour. Returns `null` if the move is illegal.
  static PourOutcome? applyPour(GameState state, int from, int to) {
    final count = pourableCount(state, from, to);
    if (count == 0) return null;

    final color = state.tubes[from].topColor!;
    final newTubes = List<Tube>.from(state.tubes);
    newTubes[from] = state.tubes[from].withRemovedTop(count);
    newTubes[to] = state.tubes[to].withAdded(color, count);

    final completed = newTubes[to].isComplete && !newTubes[to].isEmpty;
    final move = Move(
      from: from,
      to: to,
      count: count,
      color: color,
      completedDestination: completed,
    );

    final newState = state.copyWith(
      tubes: newTubes,
      history: [...state.history, move],
    );

    return PourOutcome(
      state: newState,
      move: move,
      totalComplete: newState.solvedColorCount,
    );
  }

  /// Undo the most recent pour. Returns the unchanged state if history is empty.
  static GameState undo(GameState state) {
    if (state.history.isEmpty) return state;
    final move = state.history.last;
    final newTubes = List<Tube>.from(state.tubes);
    // Reverse: take [count] of [color] off `to`, put them back on `from`.
    newTubes[move.to] = state.tubes[move.to].withRemovedTop(move.count);
    newTubes[move.from] = state.tubes[move.from].withAdded(move.color, move.count);
    return state.copyWith(
      tubes: newTubes,
      history: state.history.sublist(0, state.history.length - 1),
    );
  }

  /// Undo every move back to the starting position.
  static GameState undoAll(GameState state) {
    var s = state;
    while (s.history.isNotEmpty) {
      s = undo(s);
    }
    return s;
  }

  /// Add an empty tube using the power-up, if any uses remain.
  /// Returns `null` if no uses are left.
  static GameState? addEmptyTube(GameState state) {
    if (state.extraTubesRemaining <= 0) return null;
    final capacity = state.tubes.first.capacity;
    return state.copyWith(
      tubes: [...state.tubes, Tube.empty(capacity)],
      extraTubesRemaining: state.extraTubesRemaining - 1,
    );
  }

  /// True if at least one legal pour exists from the current position.
  static bool hasAnyLegalMove(GameState state) {
    for (var i = 0; i < state.tubes.length; i++) {
      for (var j = 0; j < state.tubes.length; j++) {
        if (i != j && canPour(state, i, j)) return true;
      }
    }
    return false;
  }

  /// "Stuck" = not solved and no legal move remains. (The UI may still offer the
  /// add-empty-tube power-up, which can unstick some positions.)
  static bool isStuck(GameState state) =>
      !state.isSolved && !hasAnyLegalMove(state);

  /// Whether adding one empty tube would create at least one new legal move.
  static bool extraTubeWouldHelp(GameState state) {
    if (state.extraTubesRemaining <= 0) return false;
    final probe = addEmptyTube(state);
    return probe != null && hasAnyLegalMove(probe);
  }
}
