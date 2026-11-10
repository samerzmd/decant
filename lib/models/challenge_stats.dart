import '../logic/challenge.dart';

/// Highest stage cleared in each challenge mode.
class ChallengeStats {
  final Map<ChallengeMode, int> best;

  const ChallengeStats({this.best = const {}});

  /// Highest stage cleared in [mode] (0 if none).
  int bestStage(ChallengeMode mode) => best[mode] ?? 0;

  /// The stage to play next in [mode].
  int nextStage(ChallengeMode mode) => bestStage(mode) + 1;

  /// Whether [stage] of [mode] can be played (cleared ones can be replayed).
  bool isUnlocked(ChallengeMode mode, int stage) => stage <= nextStage(mode);

  ChallengeStats recordClear(ChallengeMode mode, int stage) {
    if (stage <= bestStage(mode)) return this;
    return ChallengeStats(best: {...best, mode: stage});
  }

  Map<String, dynamic> toJson() => {
        'best': {for (final e in best.entries) e.key.name: e.value},
      };

  factory ChallengeStats.fromJson(Map<String, dynamic> j) {
    final raw = (j['best'] as Map?) ?? const {};
    final best = <ChallengeMode, int>{};
    for (final mode in ChallengeMode.values) {
      final v = raw[mode.name];
      if (v is num && v > 0) best[mode] = v.toInt();
    }
    return ChallengeStats(best: best);
  }
}
