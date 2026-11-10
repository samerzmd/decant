import '../models/game_state.dart';
import '../models/level.dart';
import '../models/move.dart';

enum GameStatus { playing, won }

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

  /// Estimated optimal move count (solver result on the initial board), used
  /// for the star rating.
  final int par;

  /// Active hint move to highlight, or null.
  final Move? hint;

  /// Non-null only while a pour animation is playing.
  final PourAnim? pour;

  /// True when the board has no legal moves and isn't solved.
  final bool stuck;

  const GameSession({
    required this.level,
    required this.state,
    required this.par,
    this.selected,
    this.status = GameStatus.playing,
    this.stars = 0,
    this.hint,
    this.pour,
    this.stuck = false,
  });

  bool get isAnimating => pour != null;
  bool get canUndo => state.history.isNotEmpty && status == GameStatus.playing;
  bool get canAddTube => state.extraTubesRemaining > 0;
  int get moves => state.moveCount;

  GameSession copyWith({
    GameState? state,
    int? selected,
    bool clearSelected = false,
    GameStatus? status,
    int? stars,
    Move? hint,
    bool clearHint = false,
    PourAnim? pour,
    bool clearPour = false,
    bool? stuck,
  }) {
    return GameSession(
      level: level,
      state: state ?? this.state,
      par: par,
      selected: clearSelected ? null : (selected ?? this.selected),
      status: status ?? this.status,
      stars: stars ?? this.stars,
      hint: clearHint ? null : (hint ?? this.hint),
      pour: clearPour ? null : (pour ?? this.pour),
      stuck: stuck ?? this.stuck,
    );
  }
}
