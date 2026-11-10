import '../models/game_state.dart';
import '../models/level.dart';
import '../models/move.dart';

/// [failed]: a challenge ran out of moves or time.
enum GameStatus { playing, won, failed }

/// Transient description of an in-flight pour, consumed by the board widget to
/// drive the arc stream, tube tilt, rising-liquid and splash animations.
class PourAnim {
  /// Monotonic id so the widget knows when a *new* pour starts.
  final int id;
  final int from;
  final int to;
  final int color;
  final int count;

  /// Segment count in the destination before this pour (so the new liquid can
  /// animate "rising" on top of it).
  final int destFillBefore;

  /// How long this pour takes (from the pour-speed setting). The board's
  /// animation and the controller's timing both use it, so they stay in step.
  final Duration duration;

  /// The pour timeline, as fractions of [duration]: the source tube flies
  /// over and tips until [flowStart], liquid flows until [flowEnd], then the
  /// tube tips back and returns home.
  static const double flowStart = 0.24;
  static const double flowEnd = 0.78;

  /// How long (as a fraction of [duration]) the stream takes to fall from the
  /// lip into the destination.
  static const double fall = 0.05;

  const PourAnim({
    required this.id,
    required this.from,
    required this.to,
    required this.color,
    required this.count,
    required this.destFillBefore,
    this.duration = const Duration(milliseconds: 1000),
  });
}

/// Everything the gameplay UI needs for one play session of a [Level].
class GameSession {
  final Level level;
  final GameState state;

  /// Currently selected source tube, or null.
  final int? selected;

  final GameStatus status;

  /// Stars awarded once [status] == won.
  final int stars;

  /// Whether the win was perfect: par, no hints, no extra tube.
  final bool perfect;

  /// Estimated optimal move count (solver result on the initial board), used
  /// for the star rating.
  final int par;

  /// Active hint move to highlight, or null.
  final Move? hint;

  /// Non-null only while a pour animation is playing.
  final PourAnim? pour;

  /// True when the board has no legal moves and isn't solved.
  final bool stuck;

  /// Move limit challenge: pours allowed in total (null otherwise).
  final int? moveLimit;

  /// Against the clock: time allowed, and time left (null otherwise). The
  /// clock runs only once [clockStarted] is true (on the first pour).
  final Duration? timeLimit;
  final Duration? timeLeft;
  final bool clockStarted;

  const GameSession({
    required this.level,
    required this.state,
    required this.par,
    this.selected,
    this.status = GameStatus.playing,
    this.stars = 0,
    this.perfect = false,
    this.hint,
    this.pour,
    this.stuck = false,
    this.moveLimit,
    this.timeLimit,
    this.timeLeft,
    this.clockStarted = false,
  });

  bool get isAnimating => pour != null;

  /// Undo is off in a move limit challenge: it would hand moves back.
  bool get canUndo =>
      moveLimit == null &&
      state.history.isNotEmpty &&
      status == GameStatus.playing;

  /// Pours left in a move limit challenge.
  int? get movesLeft {
    final limit = moveLimit;
    if (limit == null) return null;
    final left = limit - moves;
    return left < 0 ? 0 : left;
  }

  bool get canAddTube => state.extraTubesRemaining > 0;
  int get moves => state.moveCount;

  GameSession copyWith({
    GameState? state,
    int? selected,
    bool clearSelected = false,
    GameStatus? status,
    int? stars,
    bool? perfect,
    Move? hint,
    bool clearHint = false,
    PourAnim? pour,
    bool clearPour = false,
    bool? stuck,
    Duration? timeLeft,
    bool? clockStarted,
  }) {
    return GameSession(
      level: level,
      state: state ?? this.state,
      par: par,
      selected: clearSelected ? null : (selected ?? this.selected),
      status: status ?? this.status,
      stars: stars ?? this.stars,
      perfect: perfect ?? this.perfect,
      hint: clearHint ? null : (hint ?? this.hint),
      pour: clearPour ? null : (pour ?? this.pour),
      stuck: stuck ?? this.stuck,
      moveLimit: moveLimit,
      timeLimit: timeLimit,
      timeLeft: timeLeft ?? this.timeLeft,
      clockStarted: clockStarted ?? this.clockStarted,
    );
  }
}
