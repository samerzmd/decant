import 'tube.dart';

/// A puzzle definition: the starting arrangement of tubes plus metadata.
///
/// [filledTubes] lists the colored tubes (bottom-to-top color ids); the level
/// also includes [emptyTubes] empty tubes of the same [capacity]. Levels are
/// produced by the procedural generator and are guaranteed solvable.
class Level {
  final int id;
  final int capacity;
  final int colorCount;

  /// Bottom-to-top color ids for each pre-filled tube.
  final List<List<int>> filledTubes;

  /// Number of additional empty tubes provided at the start.
  final int emptyTubes;

  /// Power-up budget (extra empty tubes the player may summon).
  final int extraTubeAllowance;

  /// 1..5 coarse difficulty rating, derived from colors/tubes.
  final int difficulty;

  const Level({
    required this.id,
    required this.capacity,
    required this.colorCount,
    required this.filledTubes,
    required this.emptyTubes,
    this.extraTubeAllowance = 1,
    this.difficulty = 1,
  });

  int get totalTubes => filledTubes.length + emptyTubes;

  /// Build the concrete list of [Tube]s for a fresh play of this level.
  List<Tube> buildTubes() {
    final tubes = <Tube>[
      for (final segs in filledTubes) Tube(capacity: capacity, segments: segs),
      for (var i = 0; i < emptyTubes; i++) Tube.empty(capacity),
    ];
    return tubes;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'capacity': capacity,
        'colorCount': colorCount,
        'filledTubes': filledTubes,
        'emptyTubes': emptyTubes,
        'extraTubeAllowance': extraTubeAllowance,
        'difficulty': difficulty,
      };

  factory Level.fromJson(Map<String, dynamic> json) => Level(
        id: json['id'] as int,
        capacity: json['capacity'] as int,
        colorCount: json['colorCount'] as int,
        filledTubes: (json['filledTubes'] as List)
            .map((t) => (t as List).map((e) => e as int).toList())
            .toList(),
        emptyTubes: json['emptyTubes'] as int,
        extraTubeAllowance: json['extraTubeAllowance'] as int? ?? 1,
        difficulty: json['difficulty'] as int? ?? 1,
      );
}
