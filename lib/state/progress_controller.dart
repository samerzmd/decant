import 'package:flutter_riverpod/legacy.dart';

import '../logic/challenge.dart';
import '../logic/daily_challenge.dart';
import '../models/challenge_stats.dart';
import '../models/daily_stats.dart';
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

  /// Daily challenge streak and recent results.
  final DailyStats daily;

  /// Best stage cleared in each challenge mode.
  final ChallengeStats challenges;

  const ProgressData({
    required this.unlockedLevel,
    required this.totalStars,
    required this.levelsCompleted,
    required this.results,
    this.stats = const PlayStats(),
    this.daily = const DailyStats(),
    this.challenges = const ChallengeStats(),
  });

  LevelResult? resultFor(int levelId) => results[levelId];
  bool isUnlocked(int levelId) => levelId <= unlockedLevel;

  /// Levels with a perfect badge: solved in par, with no hints or extra tube.
  int get perfectLevels => results.values.where((r) => r.perfect).length;

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
      daily: p.loadDaily(),
      challenges: p.loadChallenges(),
    );
  }

  /// The current local time, as seen by this controller (tests inject it).
  DateTime now() => _now();

  /// Persist a win (best result + lifetime stats) and refresh the snapshot.
  ///
  /// A daily challenge win counts toward lifetime wins and the daily streak,
  /// but isn't a campaign level: it saves no level result and unlocks nothing.
  Future<void> recordWin(
    int levelId,
    int stars,
    int moves, {
    bool perfect = false,
  }) async {
    if (Challenge.isChallenge(levelId)) {
      final cleared = _persistence.loadChallenges().recordClear(
            Challenge.modeOf(levelId),
            Challenge.stageOf(levelId),
          );
      await _persistence.saveChallenges(cleared);
      await _persistence.saveStats(_persistence.loadStats().recordWin(_now()));
      state = _read(_persistence);
      return;
    }
    if (DailyChallenge.isDaily(levelId)) {
      final day = DailyChallenge.dateOf(levelId);
      await _persistence.saveDaily(_persistence.loadDaily().record(day, stars));
      await _persistence.saveStats(_persistence.loadStats().recordWin(_now()));
      state = _read(_persistence);
      return;
    }
    // Read stats before the result is saved, so a first-ever load doesn't
    // backfill this win from levelsCompleted and then count it again.
    final stats = _persistence.loadStats().recordWin(_now());
    await _persistence.recordResult(levelId, stars, moves, perfect: perfect);
    await _persistence.saveStats(stats);
    state = _read(_persistence);
  }
}
