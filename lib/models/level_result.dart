/// Best recorded result for a level: star rating (1..3), fewest moves, and
/// whether it has ever been solved perfectly (par, no hints, no extra tube).
class LevelResult {
  final int stars;
  final int bestMoves;
  final bool perfect;

  const LevelResult({
    required this.stars,
    required this.bestMoves,
    this.perfect = false,
  });

  Map<String, dynamic> toJson() => {
        'stars': stars,
        'moves': bestMoves,
        if (perfect) 'perfect': true,
      };

  factory LevelResult.fromJson(Map<String, dynamic> j) => LevelResult(
        stars: j['stars'] as int? ?? 0,
        bestMoves: j['moves'] as int? ?? 0,
        perfect: j['perfect'] as bool? ?? false,
      );

  /// Merge a new attempt, keeping the better star count and lower move count.
  /// A perfect badge, once earned, is kept.
  LevelResult mergedWith(int stars, int moves, {bool perfect = false}) =>
      LevelResult(
        stars: stars > this.stars ? stars : this.stars,
        bestMoves:
            bestMoves == 0 ? moves : (moves < bestMoves ? moves : bestMoves),
        perfect: this.perfect || perfect,
      );
}
