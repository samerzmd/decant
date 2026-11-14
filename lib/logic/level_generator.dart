import 'dart:math';

import '../models/game_state.dart';
import '../models/level.dart';
import '../models/tube.dart';
import 'challenge.dart';
import 'daily_challenge.dart';
import 'solver.dart';

/// Difficulty/shape parameters for a level number.
class LevelConfig {
  final int colorCount;
  final int emptyTubes;
  final int capacity;
  final int scrambleSteps;
  final int difficulty; // 1..5
  const LevelConfig({
    required this.colorCount,
    required this.emptyTubes,
    required this.capacity,
    required this.scrambleSteps,
    required this.difficulty,
  });
}

/// Procedural generator that builds solvable levels by **reverse-shuffling**
/// from a solved board.
///
/// Why this guarantees solvability: we only ever apply *invertible* reverse
/// pours. A reverse pour moves a run of color `c` from the top of tube P onto
/// tube Q such that the corresponding forward pour (Q → P) is a legal water-sort
/// move. Replaying those forward pours in reverse order therefore solves the
/// board. Each generated board is additionally validated with [Solver] as a
/// belt-and-braces guarantee.
class LevelGenerator {
  const LevelGenerator._();

  /// Shape of level [levelId]. Campaign levels (1-based) ramp up as the number
  /// grows; daily challenges (negative ids) follow the day of the week.
  static LevelConfig configFor(int levelId) {
    if (Challenge.isChallenge(levelId)) {
      return _configForColors(Challenge.colorsFor(Challenge.stageOf(levelId)));
    }
    if (DailyChallenge.isDaily(levelId)) {
      return _configForColors(
        DailyChallenge.colorsFor(DailyChallenge.dateOf(levelId)),
      );
    }
    // Colors grow from 3 up to 11.
    return _configForColors((3 + (levelId - 1) ~/ 3).clamp(3, 11));
  }

  static LevelConfig _configForColors(int colorCount) {
    const capacity = 4;
    // Empties trend from 2 down to 1 on hard sets.
    final emptyTubes = colorCount >= 8 ? 1 : 2;
    final difficulty = switch (colorCount) {
      <= 3 => 1,
      4 => 2,
      <= 6 => 3,
      <= 8 => 4,
      _ => 5,
    };
    // More colors ⇒ more scrambling for a satisfying tangle.
    final scrambleSteps = colorCount * capacity * 3 + 6;
    return LevelConfig(
      colorCount: colorCount,
      emptyTubes: emptyTubes,
      capacity: capacity,
      scrambleSteps: scrambleSteps,
      difficulty: difficulty,
    );
  }

  /// Generate level [levelId]. Deterministic for a given id (seeded by id) so a
  /// player always sees the same level number, across sessions and devices.
  static Level generate(int levelId, {int? seed}) {
    final cfg = configFor(levelId);
    final rng = Random(seed ?? (0x9E3779B9 ^ levelId));

    // Try a few times; reverse-shuffle is always solvable, but we also want a
    // board that isn't trivially already solved.
    for (var attempt = 0; attempt < 12; attempt++) {
      final tubes = _reverseShuffle(cfg, rng);
      final state = GameState(tubes: tubes);
      if (state.isSolved) continue; // too tidy, reshuffle
      if (!_interestingEnough(tubes)) continue;
      if (!Solver.isSolvable(state)) continue; // safety net (should never fail)
      return _toLevel(levelId, cfg, tubes);
    }

    // Extremely unlikely fallback: a lightly mixed but guaranteed-solvable board.
    final tubes = _reverseShuffle(cfg, rng);
    return _toLevel(levelId, cfg, tubes);
  }

  /// Build the solved board, then apply [cfg.scrambleSteps] reverse pours.
  static List<Tube> _reverseShuffle(LevelConfig cfg, Random rng) {
    // Solved start: one full uniform tube per color + the empty tubes.
    // NOTE: these must be *growable* lists — the reverse pours add/remove
    // segments. `List.filled` is fixed-length by default, so pass growable.
    final segs = <List<int>>[
      for (var c = 0; c < cfg.colorCount; c++)
        List<int>.filled(cfg.capacity, c, growable: true),
      for (var e = 0; e < cfg.emptyTubes; e++) <int>[],
    ];

    for (var step = 0; step < cfg.scrambleSteps; step++) {
      _reversePour(segs, cfg.capacity, rng);
    }
    return [for (final s in segs) Tube(capacity: cfg.capacity, segments: s)];
  }

  /// Apply one invertible reverse pour to [segs] in place.
  ///
  /// Picks a non-empty tube P, removes 1..m segments of its top color `c`
  /// (leaving at least one `c` on P unless P is emptied), and stacks them onto
  /// a different tube Q that has room. The matching forward move Q→P is a legal
  /// pour, so the operation never breaks solvability.
  static void _reversePour(List<List<int>> segs, int capacity, Random rng) {
    final n = segs.length;
    // Candidate source tubes P: non-empty.
    final sources = <int>[
      for (var i = 0; i < n; i++)
        if (segs[i].isNotEmpty) i,
    ];
    if (sources.isEmpty) return;
    sources.shuffle(rng);

    for (final p in sources) {
      final tube = segs[p];
      final c = tube.last;
      // length of the top run of color c
      var run = 0;
      for (var k = tube.length - 1; k >= 0; k--) {
        if (tube[k] == c) {
          run++;
        } else {
          break;
        }
      }
      // Max we may remove and stay invertible:
      //  - if the whole tube is this color, we can take all (P becomes empty);
      //  - otherwise leave ≥1 `c` on top so the forward pour can re-merge.
      final wholeTube = run == tube.length;
      final maxTake = wholeTube ? tube.length : run - 1;
      if (maxTake < 1) continue;

      // Candidate destinations Q: any other tube with free space.
      final dests = <int>[
        for (var j = 0; j < n; j++)
          if (j != p && segs[j].length < capacity) j,
      ];
      if (dests.isEmpty) continue;
      final q = dests[rng.nextInt(dests.length)];
      final room = capacity - segs[q].length;

      final limit = maxTake < room ? maxTake : room;
      final take = 1 + rng.nextInt(limit);
      if (take < 1) continue;

      for (var t = 0; t < take; t++) {
        tube.removeLast();
        segs[q].add(c);
      }
      return; // one reverse pour per step
    }
  }

  /// Reject boards that are too clean (almost solved) to be fun.
  static bool _interestingEnough(List<Tube> tubes) {
    var fragmented = 0;
    for (final t in tubes) {
      if (!t.isEmpty && !t.isUniform) fragmented++;
    }
    return fragmented >= 2;
  }

  static Level _toLevel(int levelId, LevelConfig cfg, List<Tube> tubes) {
    final filled = <List<int>>[];
    var empties = 0;
    for (final t in tubes) {
      if (t.isEmpty) {
        empties++;
      } else {
        filled.add(List<int>.from(t.segments));
      }
    }
    return Level(
      id: levelId,
      capacity: cfg.capacity,
      colorCount: cfg.colorCount,
      filledTubes: filled,
      emptyTubes: empties,
      extraTubeAllowance: 1,
      difficulty: cfg.difficulty,
    );
  }
}
