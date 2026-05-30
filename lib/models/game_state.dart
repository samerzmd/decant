import 'move.dart';
import 'tube.dart';

/// Immutable snapshot of the board plus bookkeeping for moves and power-ups.
///
/// All transitions are produced by `logic/pour_engine.dart`, which returns a
/// fresh [GameState]; this object never mutates itself.
class GameState {
  final List<Tube> tubes;

  /// History of applied moves (most recent last). Drives multi-step undo.
  final List<Move> history;

  /// Remaining uses of the "add empty tube" power-up.
  final int extraTubesRemaining;

  /// Hints used so far (affects the star rating).
  final int hintsUsed;

  const GameState({
    required this.tubes,
    this.history = const <Move>[],
    this.extraTubesRemaining = 1,
    this.hintsUsed = 0,
  });

  int get moveCount => history.length;

  /// Solved when every tube is empty or a full single color.
  bool get isSolved => tubes.every((t) => t.isComplete);

  /// Number of tubes that are currently "complete" (empty tubes excluded so we
  /// count actual solved colors, not blanks).
  int get solvedColorCount =>
      tubes.where((t) => !t.isEmpty && t.isComplete).length;

  GameState copyWith({
    List<Tube>? tubes,
    List<Move>? history,
    int? extraTubesRemaining,
    int? hintsUsed,
  }) {
    return GameState(
      tubes: tubes ?? this.tubes,
      history: history ?? this.history,
      extraTubesRemaining: extraTubesRemaining ?? this.extraTubesRemaining,
      hintsUsed: hintsUsed ?? this.hintsUsed,
    );
  }

  /// A stable, order-independent-ish key of the board for solver visited sets.
  /// Tubes are sorted by their contents so two boards that are identical up to
  /// tube ordering collapse to the same key (greatly shrinks the search space).
  String get canonicalKey {
    final keys = tubes.map((t) => t.key).toList()..sort();
    return keys.join('|');
  }

  @override
  String toString() => 'GameState(moves=$moveCount, tubes=$tubes)';
}
