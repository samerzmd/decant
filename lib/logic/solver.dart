import '../models/game_state.dart';
import '../models/move.dart';
import 'pour_engine.dart';

/// Internal search node — stores a board plus a back-pointer so we can
/// reconstruct the move path without copying the whole path into every node.
class _Node {
  final GameState state;
  final int parent;
  final Move? move;
  const _Node(this.state, this.parent, this.move);
}

/// Tiny binary min-heap over (priority, nodeIndex) pairs. Avoids pulling in an
/// external collections dependency for the solver's priority queue.
class _MinHeap {
  final List<int> _prio = <int>[];
  final List<int> _idx = <int>[];

  bool get isEmpty => _prio.isEmpty;

  void push(int priority, int nodeIndex) {
    _prio.add(priority);
    _idx.add(nodeIndex);
    var i = _prio.length - 1;
    while (i > 0) {
      final parent = (i - 1) >> 1;
      if (_prio[parent] <= _prio[i]) break;
      _swap(i, parent);
      i = parent;
    }
  }

  int pop() {
    final top = _idx[0];
    final last = _prio.length - 1;
    _swap(0, last);
    _prio.removeLast();
    _idx.removeLast();
    var i = 0;
    final n = _prio.length;
    while (true) {
      final l = 2 * i + 1;
      final r = 2 * i + 2;
      var smallest = i;
      if (l < n && _prio[l] < _prio[smallest]) smallest = l;
      if (r < n && _prio[r] < _prio[smallest]) smallest = r;
      if (smallest == i) break;
      _swap(i, smallest);
      i = smallest;
    }
    return top;
  }

  void _swap(int a, int b) {
    final p = _prio[a];
    _prio[a] = _prio[b];
    _prio[b] = p;
    final x = _idx[a];
    _idx[a] = _idx[b];
    _idx[b] = x;
  }
}

/// Best-first solver used both to validate generated levels and to power hints.
///
/// The search is greedy on a fragmentation heuristic with a node budget, so it
/// returns a valid (not necessarily shortest) solution quickly even for hard
/// boards. For hints we only need the next sensible move.
class Solver {
  const Solver._();

  /// Returns a full sequence of moves that solves [start], or `null` if no
  /// solution was found within [maxExpansions].
  static List<Move>? solve(GameState start, {int maxExpansions = 200000}) {
    if (start.isSolved) return <Move>[];

    final nodes = <_Node>[_Node(start, -1, null)];
    final heap = _MinHeap()..push(_heuristic(start), 0);
    final visited = <String>{start.canonicalKey};
    var expansions = 0;
    final n = start.tubes.length;

    while (!heap.isEmpty && expansions < maxExpansions) {
      expansions++;
      final idx = heap.pop();
      final state = nodes[idx].state;

      for (var i = 0; i < n; i++) {
        final src = state.tubes[i];
        // Never pour from an empty or already-complete tube.
        if (src.isEmpty || src.isComplete) continue;
        final srcUniform = src.topRunLength == src.segments.length;

        for (var j = 0; j < n; j++) {
          if (i == j) continue;
          if (!PourEngine.canPour(state, i, j)) continue;
          // Pruning: relocating a whole uniform stack into an empty tube makes
          // no progress and only inflates the search.
          if (srcUniform && state.tubes[j].isEmpty) continue;

          final outcome = PourEngine.applyPour(state, i, j);
          if (outcome == null) continue;
          final key = outcome.state.canonicalKey;
          if (!visited.add(key)) continue;

          final childIndex = nodes.length;
          nodes.add(_Node(outcome.state, idx, outcome.move));
          if (outcome.state.isSolved) {
            return _reconstruct(nodes, childIndex);
          }
          heap.push(_heuristic(outcome.state), childIndex);
        }
      }
    }
    return null;
  }

  /// The single best next move from [state], or `null` if unsolvable / solved.
  static Move? nextMove(GameState state) {
    final path = solve(state);
    if (path == null || path.isEmpty) return null;
    return path.first;
  }

  /// Cheap check used by the level generator to confirm solvability.
  static bool isSolvable(GameState state, {int maxExpansions = 200000}) =>
      solve(state, maxExpansions: maxExpansions) != null;

  static List<Move> _reconstruct(List<_Node> nodes, int leaf) {
    final moves = <Move>[];
    var i = leaf;
    while (i > 0) {
      final node = nodes[i];
      moves.add(node.move!);
      i = node.parent;
    }
    return moves.reversed.toList();
  }

  /// Heuristic: total adjacent color transitions plus one per unfinished tube.
  /// Lower is closer to solved. 0 ⇔ solved.
  static int _heuristic(GameState state) {
    var h = 0;
    for (final t in state.tubes) {
      if (t.isEmpty) continue;
      for (var i = 1; i < t.segments.length; i++) {
        if (t.segments[i] != t.segments[i - 1]) h++;
      }
      if (!t.isComplete) h++;
    }
    return h;
  }
}
