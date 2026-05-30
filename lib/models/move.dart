/// A single pour from one tube to another.
///
/// Stores enough information to (a) replay the move forward and (b) undo it by
/// moving [count] segments of [color] back from [to] to [from].
class Move {
  final int from;
  final int to;
  final int count;
  final int color;

  /// Whether the destination tube became "complete" as a result of this move.
  /// Used to drive completion chimes / combo detection.
  final bool completedDestination;

  const Move({
    required this.from,
    required this.to,
    required this.count,
    required this.color,
    this.completedDestination = false,
  });

  Move copyWith({bool? completedDestination}) => Move(
        from: from,
        to: to,
        count: count,
        color: color,
        completedDestination: completedDestination ?? this.completedDestination,
      );

  @override
  String toString() =>
      'Move($from→$to ×$count color=$color${completedDestination ? " ✓" : ""})';
}
