/// Star targets and the "perfect" badge, worked out per level from its par:
/// the solver's move count for the starting board.
///
/// The targets scale with each level, so a short level isn't as forgiving
/// (in moves) as a long one, and the game shows them while you play.
class StarRating {
  StarRating._();

  /// Most moves that still earn three stars: par plus a quarter, rounded up.
  static int threeStarMoves(int par) => (_safe(par) * 1.25).ceil();

  /// Most moves that still earn two stars: par plus 90%, rounded up.
  static int twoStarMoves(int par) => (_safe(par) * 1.9).ceil();

  /// Stars for a solve in [moves] on a level with [par]. Using hints costs a
  /// star (never below one).
  static int stars({required int moves, required int par, int hints = 0}) {
    var stars = moves <= threeStarMoves(par)
        ? 3
        : moves <= twoStarMoves(par)
            ? 2
            : 1;
    if (hints > 0) stars = (stars - 1).clamp(1, 3);
    return stars;
  }

  /// A perfect solve: no more moves than par, with no hints and no extra
  /// tube.
  static bool isPerfect({
    required int moves,
    required int par,
    required int hints,
    required bool usedExtraTube,
  }) =>
      moves <= _safe(par) && hints == 0 && !usedExtraTube;

  static int _safe(int par) => par <= 0 ? 1 : par;
}
