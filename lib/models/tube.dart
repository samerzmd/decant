/// A single glass tube holding a stack of colored liquid segments.
///
/// Segments are stored bottom-to-top: `segments.first` is the bottom of the
/// tube and `segments.last` is the exposed surface that can be poured out.
/// The model is immutable; every mutation returns a new [Tube].
class Tube {
  /// Maximum number of segments the tube can hold.
  final int capacity;

  /// Liquid segments, bottom (index 0) to top (last index).
  final List<int> segments;

  Tube({required this.capacity, List<int>? segments})
      : segments = List<int>.unmodifiable(segments ?? const <int>[]);

  /// An empty tube with the given [capacity].
  Tube.empty(this.capacity) : segments = const <int>[];

  bool get isEmpty => segments.isEmpty;

  bool get isFull => segments.length >= capacity;

  /// Free space left in the tube.
  int get freeSpace => capacity - segments.length;

  /// The color id of the exposed top segment, or `null` if the tube is empty.
  int? get topColor => isEmpty ? null : segments.last;

  /// Number of consecutive segments of the same color at the top of the tube.
  /// Returns 0 for an empty tube.
  int get topRunLength {
    if (isEmpty) return 0;
    final top = segments.last;
    var run = 0;
    for (var i = segments.length - 1; i >= 0; i--) {
      if (segments[i] == top) {
        run++;
      } else {
        break;
      }
    }
    return run;
  }

  /// Whether every segment in the tube is the same color.
  bool get isUniform {
    if (isEmpty) return true;
    final first = segments.first;
    for (final s in segments) {
      if (s != first) return false;
    }
    return true;
  }

  /// A tube is "complete" when it is empty, or full and a single color.
  /// (Generated levels always have exactly [capacity] units of each color, so
  /// a finished tube is necessarily full.)
  bool get isComplete => isEmpty || (isFull && isUniform);

  /// Whether this tube can currently receive a segment of [color].
  bool canReceive(int color) => !isFull && (isEmpty || segments.last == color);

  /// Return a copy with [count] segments of [color] added on top.
  Tube withAdded(int color, int count) {
    final next = List<int>.from(segments);
    for (var i = 0; i < count; i++) {
      next.add(color);
    }
    return Tube(capacity: capacity, segments: next);
  }

  /// Return a copy with [count] segments removed from the top.
  Tube withRemovedTop(int count) {
    final next = List<int>.from(segments);
    next.removeRange(next.length - count, next.length);
    return Tube(capacity: capacity, segments: next);
  }

  Tube copy() => Tube(capacity: capacity, segments: segments);

  /// Compact key for use in solver visited-sets (e.g. "0,1,1,2").
  String get key => segments.join(',');

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Tube) return false;
    if (capacity != other.capacity) return false;
    if (segments.length != other.segments.length) return false;
    for (var i = 0; i < segments.length; i++) {
      if (segments[i] != other.segments[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(capacity, Object.hashAll(segments));

  @override
  String toString() => 'Tube(${segments.join("·")})';
}
