/// Challenge modes: endless ladders of stages with a twist on the rules.
///
/// Like the daily challenge, stages live in their own level-id range so the
/// generator, providers and game screen handle them unchanged: Move limit
/// stage N is `1000000 + N`, Against the clock stage N is `2000000 + N`.
/// Campaign levels stay well below (1, 2, 3, …) and dailies are negative.
enum ChallengeMode {
  /// Solve within a move budget. Undo is off, since it would refund moves.
  moves('Move limit', 'Solve within the move limit. No undo.'),

  /// Solve before the timer runs out. The clock starts on your first pour.
  timed('Against the clock', 'Beat the timer. It starts on your first pour.');

  final String label;
  final String blurb;
  const ChallengeMode(this.label, this.blurb);

  int get _base => (index + 1) * Challenge.span;
}

class Challenge {
  Challenge._();

  /// Size of each mode's id range.
  static const int span = 1000000;

  static int idFor(ChallengeMode mode, int stage) => mode._base + stage;

  static bool isChallenge(int levelId) => levelId > span;

  static ChallengeMode modeOf(int levelId) =>
      ChallengeMode.values[levelId ~/ span - 1];

  static int stageOf(int levelId) => levelId % span;

  /// Colors for a stage: starts at 4 and adds one every two stages, up to 11.
  static int colorsFor(int stage) => (4 + (stage - 1) ~/ 2).clamp(4, 11);

  /// Moves allowed for a board the solver finishes in [par] moves: the
  /// three-star target, with at least two moves of slack.
  static int moveLimit(int par) {
    final relaxed = (par * 1.25).ceil();
    return relaxed < par + 2 ? par + 2 : relaxed;
  }

  /// Time allowed for a board the solver finishes in [par] moves: enough for
  /// a few seconds of thought per pour on top of the pours themselves.
  static Duration timeLimit(int par) => Duration(seconds: 20 + par * 5);

  /// Header title, e.g. "Move limit · Stage 3".
  static String title(int levelId) =>
      '${modeOf(levelId).label} · Stage ${stageOf(levelId)}';
}
