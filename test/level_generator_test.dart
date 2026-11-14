import 'package:flutter_test/flutter_test.dart';

import 'package:decant/logic/level_generator.dart';
import 'package:decant/logic/pour_engine.dart';
import 'package:decant/logic/solver.dart';
import 'package:decant/models/game_state.dart';

void main() {
  GameState toState(level) => GameState(
        tubes: level.buildTubes(),
        extraTubesRemaining: level.extraTubeAllowance,
      );

  test('every generated level is solvable and not already solved', () {
    for (var id = 1; id <= 25; id++) {
      final level = LevelGenerator.generate(id);
      final s = toState(level);
      expect(s.isSolved, false, reason: 'level $id starts solved');
      expect(Solver.isSolvable(s), true, reason: 'level $id is unsolvable');
    }
  });

  test('generation is deterministic for a given level id', () {
    final a = LevelGenerator.generate(7);
    final b = LevelGenerator.generate(7);
    expect(a.filledTubes, b.filledTubes);
    expect(a.emptyTubes, b.emptyTubes);
  });

  test('color counts are conserved (capacity units of each color)', () {
    for (var id = 1; id <= 15; id++) {
      final level = LevelGenerator.generate(id);
      final counts = <int, int>{};
      for (final tube in level.filledTubes) {
        for (final c in tube) {
          counts[c] = (counts[c] ?? 0) + 1;
        }
      }
      expect(counts.length, level.colorCount);
      for (final entry in counts.entries) {
        expect(
          entry.value,
          level.capacity,
          reason: 'color ${entry.key} should have ${level.capacity} units',
        );
      }
    }
  });

  test('difficulty ramps and tube totals are consistent', () {
    final easy = LevelGenerator.generate(1);
    final hard = LevelGenerator.generate(40);
    expect(easy.difficulty, lessThanOrEqualTo(hard.difficulty));
    expect(easy.colorCount, lessThanOrEqualTo(hard.colorCount));

    final level = LevelGenerator.generate(10);
    // Reverse-shuffling can move a source tube's whole run out, or completely
    // fill a starting-empty tube, so the *final* filled/empty split may not
    // match the generator's recipe — only the total tube count is invariant.
    final cfg = LevelGenerator.configFor(10);
    expect(level.totalTubes, cfg.colorCount + cfg.emptyTubes);
    expect(level.difficulty, inInclusiveRange(1, 5));
  });

  test(
    'a fully solved generated board is reachable by replaying a solution',
    () {
      final level = LevelGenerator.generate(12);
      var s = toState(level);
      final solution = Solver.solve(s)!;
      for (final m in solution) {
        s = PourEngine.applyPour(s, m.from, m.to)!.state;
      }
      expect(s.isSolved, true);
    },
  );
}
