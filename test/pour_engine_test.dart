import 'package:flutter_test/flutter_test.dart';

import 'package:decant/logic/pour_engine.dart';
import 'package:decant/models/game_state.dart';
import 'package:decant/models/tube.dart';

void main() {
  GameState state(List<List<int>> tubes, {int capacity = 4, int extra = 1}) {
    return GameState(
      tubes: [for (final t in tubes) Tube(capacity: capacity, segments: t)],
      extraTubesRemaining: extra,
    );
  }

  group('Tube', () {
    test('top run length counts consecutive top colors', () {
      final t = Tube(capacity: 4, segments: [0, 1, 1, 1]);
      expect(t.topColor, 1);
      expect(t.topRunLength, 3);
      expect(t.freeSpace, 0);
      expect(t.isFull, true);
    });

    test('completeness: empty or full uniform', () {
      expect(Tube.empty(4).isComplete, true);
      expect(Tube(capacity: 4, segments: [2, 2, 2, 2]).isComplete, true);
      expect(Tube(capacity: 4, segments: [2, 2, 2]).isComplete, false);
      expect(Tube(capacity: 4, segments: [2, 3, 2, 2]).isComplete, false);
    });
  });

  group('pourableCount', () {
    test('pours onto matching top color up to capacity', () {
      final s = state([
        [0, 0, 1, 1],
        [1, 1],
      ]);
      // top of tube0 is two 1's; tube1 has room for 2 → moves 2.
      expect(PourEngine.pourableCount(s, 0, 1), 2);
    });

    test('limited by destination free space', () {
      final s = state([
        [1, 1, 1],
        [1, 1, 1],
      ]);
      // tube1 has room for 1 only.
      expect(PourEngine.pourableCount(s, 0, 1), 1);
    });

    test('cannot pour onto a different color', () {
      final s = state([
        [0, 0, 1],
        [2, 2],
      ]);
      expect(PourEngine.pourableCount(s, 0, 1), 0);
      expect(PourEngine.canPour(s, 0, 1), false);
    });

    test('pours into an empty tube', () {
      final s = state([
        [3, 3, 3, 3],
        [],
      ]);
      expect(PourEngine.pourableCount(s, 0, 1), 4);
    });
  });

  group('applyPour', () {
    test('moves the full top run and records the move', () {
      final s = state([
        [0, 1, 1],
        [1],
      ]);
      final out = PourEngine.applyPour(s, 0, 1)!;
      expect(out.state.tubes[0].segments, [0]);
      expect(out.state.tubes[1].segments, [1, 1, 1]);
      expect(out.move.count, 2);
      expect(out.move.color, 1);
      expect(out.state.moveCount, 1);
    });

    test('flags destination completion', () {
      final s = state([
        [5, 5],
        [5, 5],
      ]);
      final out = PourEngine.applyPour(s, 0, 1)!;
      expect(out.state.tubes[1].isComplete, true);
      expect(out.move.completedDestination, true);
    });

    test('illegal pour returns null', () {
      final s = state([
        [0, 0],
        [1, 1, 1, 1],
      ]);
      expect(PourEngine.applyPour(s, 0, 1), isNull);
    });
  });

  group('undo', () {
    test('reverses the most recent pour exactly', () {
      final s = state([
        [0, 1, 1],
        [1],
      ]);
      final out = PourEngine.applyPour(s, 0, 1)!;
      final back = PourEngine.undo(out.state);
      expect(back.tubes[0].segments, [0, 1, 1]);
      expect(back.tubes[1].segments, [1]);
      expect(back.history, isEmpty);
    });

    test('undoAll returns to the start', () {
      var s = state([
        [0, 1],
        [1, 0],
        [],
      ]);
      final a = PourEngine.applyPour(s, 0, 2)!.state; // move top 1
      final b = PourEngine.applyPour(a, 1, 2)!.state; // move top 0
      final restored = PourEngine.undoAll(b);
      expect(restored.tubes[0].segments, [0, 1]);
      expect(restored.tubes[1].segments, [1, 0]);
      expect(restored.tubes[2].segments, isEmpty);
    });
  });

  group('win / stuck detection', () {
    test('isSolved when every tube is empty or uniform-full', () {
      final solved = state([
        [0, 0, 0, 0],
        [1, 1, 1, 1],
        [],
      ]);
      expect(solved.isSolved, true);
    });

    test('detects a stuck position', () {
      // Two full tubes of mixed colors, no empties, nothing legal.
      final s = state([
        [0, 1, 0, 1],
        [1, 0, 1, 0],
      ], extra: 0);
      expect(PourEngine.hasAnyLegalMove(s), false);
      expect(PourEngine.isStuck(s), true);
    });

    test('add empty tube consumes a power-up use', () {
      final s = state([
        [0, 1, 0, 1],
      ], extra: 1);
      final next = PourEngine.addEmptyTube(s)!;
      expect(next.tubes.length, 2);
      expect(next.tubes.last.isEmpty, true);
      expect(next.extraTubesRemaining, 0);
      expect(PourEngine.addEmptyTube(next), isNull);
    });
  });
}
