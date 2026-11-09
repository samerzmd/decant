import 'package:flutter_riverpod/legacy.dart';

import '../models/level_result.dart';
import '../models/play_stats.dart';
import '../services/persistence_service.dart';

/// Snapshot of the player's overall progress.
class ProgressData {
  final int unlockedLevel;
  final int totalStars;
  final int levelsCompleted;
  final Map<int, LevelResult> results;

  /// Lifetime wins and daily streak.
  final PlayStats stats;

  const ProgressData({
    required this.unlockedLevel,
    required this.totalStars,
    required this.levelsCompleted,
    required this.results,
    this.stats = const PlayStats(),
  });

  LevelResult? resultFor(int levelId) => results[levelId];
  bool isUnlocked(int levelId) => levelId <= unlockedLevel;

  /// Levels solved with the full three stars.
  int get perfectLevels => results.values.where((r) => r.stars >= 3).length;

  /// How many solved levels have 1, 2 and 3 stars (index 0 = one star).
  List<int> get starCounts {
    final counts = [0, 0, 0];
    for (final r in results.values) {
      if (r.stars >= 1) counts[r.stars.clamp(1, 3) - 1]++;
    }
    return counts;
  }
}

/// Loads and mutates persisted progress, exposing it reactively to the UI.
class ProgressController extends StateNotifier<ProgressData> {
  final PersistenceService _persistence;

  /// Local clock, injectable so tests can play across days.
  final DateTime Function() _now;

  ProgressController(this._persistence, {DateTime Function()? now})
      : _now = now ?? DateTime.now,
        super(_read(_persistence));

  static ProgressData _read(PersistenceService p) {
    // Levels are unlimited. You can only have a result for a level you've
    // completed, and completing level N unlocks N+1, so every saved result
    // lives in 1..unlockedLevel — scan exactly that far (no fixed cap).
    final unlocked = p.unlockedLevel();
    final results = <int, LevelResult>{};
    for (var id = 1; id <= unlocked; id++) {
      final r = p.resultFor(id);
      if (r != null) results[id] = r;
    }
    return ProgressData(
      unlockedLevel: unlocked,
      totalStars: p.totalStars(),
      levelsCompleted: p.levelsCompleted(),
      results: results,
      stats: p.loadStats(),
    );
  }

  /// Persist a win (best result + lifetime stats) and refresh the snapshot.
  Future<void> recordWin(int levelId, int stars, int moves) async {
    // Read stats before the result is saved, so a first-ever load doesn't
    // backfill this win from levelsCompleted and then count it again.
    final stats = _persistence.loadStats().recordWin(_now());
    await _persistence.recordResult(levelId, stars, moves);
    await _persistence.saveStats(stats);
    state = _read(_persistence);
  }
}
