/// Best recorded result for a level: star rating (1..3) and fewest moves.
class LevelResult {
  final int stars;
  final int bestMoves;

  const LevelResult({required this.stars, required this.bestMoves});

  Map<String, dynamic> toJson() => {'stars': stars, 'moves': bestMoves};

  factory LevelResult.fromJson(Map<String, dynamic> j) => LevelResult(
        stars: j['stars'] as int? ?? 0,
        bestMoves: j['moves'] as int? ?? 0,
      );

  /// Merge a new attempt, keeping the better star count and lower move count.
  LevelResult mergedWith(int stars, int moves) => LevelResult(
        stars: stars > this.stars ? stars : this.stars,
        bestMoves:
            bestMoves == 0 ? moves : (moves < bestMoves ? moves : bestMoves),
      );
}
