import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/level_result.dart';
import '../services/persistence_service.dart';

/// Snapshot of the player's overall progress.
class ProgressData {
  final int unlockedLevel;
  final int totalStars;
  final int levelsCompleted;
  final Map<int, LevelResult> results;

  const ProgressData({
    required this.unlockedLevel,
    required this.totalStars,
    required this.levelsCompleted,
    required this.results,
  });

  LevelResult? resultFor(int levelId) => results[levelId];
  bool isUnlocked(int levelId) => levelId <= unlockedLevel;
}

/// Loads and mutates persisted progress, exposing it reactively to the UI.
class ProgressController extends StateNotifier<ProgressData> {
  final PersistenceService _persistence;

  ProgressController(this._persistence) : super(_read(_persistence));

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
    );
  }

  /// Persist a win and refresh the in-memory snapshot.
  Future<void> recordWin(int levelId, int stars, int moves) async {
    await _persistence.recordResult(levelId, stars, moves);
    state = _read(_persistence);
  }
}
