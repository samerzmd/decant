import 'package:flutter_test/flutter_test.dart';

import 'package:decant/logic/pour_engine.dart';
import 'package:decant/logic/solver.dart';
import 'package:decant/models/game_state.dart';
import 'package:decant/models/tube.dart';

void main() {
  GameState state(List<List<int>> tubes, {int capacity = 4}) => GameState(
        tubes: [for (final t in tubes) Tube(capacity: capacity, segments: t)],
      );

  /// Replay a move list and return the resulting state.
  GameState replay(GameState start, List moves) {
    var s = start;
    for (final m in moves) {
      final out = PourEngine.applyPour(s, m.from, m.to);
      expect(out, isNotNull, reason: 'solver produced an illegal move $m');
      s = out!.state;
    }
    return s;
  }

  test('already-solved board returns an empty solution', () {
    final s = state([
      [0, 0, 0, 0],
      [],
    ]);
    expect(Solver.solve(s), isEmpty);
  });

  test('solves a simple two-color board and the path is valid', () {
    final s = state([
      [0, 1, 0, 1],
      [1, 0, 1, 0],
      [],
      [],
    ]);
    final solution = Solver.solve(s);
    expect(solution, isNotNull);
    final end = replay(s, solution!);
    expect(end.isSolved, true);
  });

  test('nextMove returns a legal, progress-making move', () {
    final s = state([
      [2, 3, 2, 3],
      [3, 2, 3, 2],
      [],
      [],
    ]);
    final move = Solver.nextMove(s);
    expect(move, isNotNull);
    expect(PourEngine.canPour(s, move!.from, move.to), true);
  });

  test('reports an unsolvable/stuck board as not solvable', () {
    final s = state([
      [0, 1, 0, 1],
      [1, 0, 1, 0],
    ]);
    expect(Solver.isSolvable(s), false);
  });
}
