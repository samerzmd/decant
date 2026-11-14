import '../logic/challenge.dart';
import 'challenge_stats.dart';
import 'daily_stats.dart';
import 'level_result.dart';
import 'play_stats.dart';

/// Everything that makes up a player's progress, in one value that can be
/// saved to the cloud and merged with another device's copy.
///
/// Settings aren't part of it: theme, sound and language are chosen per
/// device.
class ProgressSnapshot {
  /// Bumped if the JSON layout ever changes incompatibly.
  static const version = 1;

  final int unlockedLevel;
  final Map<int, LevelResult> results;
  final PlayStats stats;
  final DailyStats daily;
  final ChallengeStats challenges;
  final int hints;

  /// When [hints] last changed (ms since epoch); 0 if unknown.
  final int hintsChangedAt;

  const ProgressSnapshot({
    this.unlockedLevel = 1,
    this.results = const {},
    this.stats = const PlayStats(),
    this.daily = const DailyStats(),
    this.challenges = const ChallengeStats(),
    required this.hints,
    this.hintsChangedAt = 0,
  });

  /// No level, daily or challenge has been played.
  bool get isFresh =>
      unlockedLevel <= 1 &&
      results.isEmpty &&
      stats.wins == 0 &&
      daily.completed == 0 &&
      challenges.best.isEmpty;

  /// Combines two copies of the same player's progress without losing
  /// anything either one earned: the furthest level, the best result per
  /// level, the longest streaks and the best challenge stages.
  ProgressSnapshot merge(ProgressSnapshot other) => ProgressSnapshot(
        unlockedLevel: _max(unlockedLevel, other.unlockedLevel),
        results: _mergeResults(results, other.results),
        stats: _mergeStats(stats, other.stats),
        daily: _mergeDaily(daily, other.daily),
        challenges: _mergeChallenges(challenges, other.challenges),
        // Hints are spent as well as earned, so the most recent count wins;
        // keeping the larger one would hand back every hint spent since the
        // last sync. Without timestamps (older saves), keep the larger pool.
        hints: hintsChangedAt == other.hintsChangedAt
            ? _max(hints, other.hints)
            : hintsChangedAt > other.hintsChangedAt
                ? hints
                : other.hints,
        hintsChangedAt: _max(hintsChangedAt, other.hintsChangedAt),
      );

  Map<String, dynamic> toJson() => {
        'v': version,
        'unlocked': unlockedLevel,
        'results': {
          for (final e in results.entries) '${e.key}': e.value.toJson()
        },
        'stats': stats.toJson(),
        'daily': daily.toJson(),
        'challenges': challenges.toJson(),
        'hints': hints,
        'hintsAt': hintsChangedAt,
      };

  factory ProgressSnapshot.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic> map(Object? v) =>
        v is Map ? Map<String, dynamic>.from(v) : const {};
    final results = <int, LevelResult>{};
    for (final e in map(j['results']).entries) {
      final id = int.tryParse(e.key);
      if (id != null && id > 0) {
        results[id] = LevelResult.fromJson(map(e.value));
      }
    }
    return ProgressSnapshot(
      unlockedLevel: (j['unlocked'] as num?)?.toInt() ?? 1,
      results: results,
      stats: PlayStats.fromJson(map(j['stats'])),
      daily: DailyStats.fromJson(map(j['daily'])),
      challenges: ChallengeStats.fromJson(map(j['challenges'])),
      hints: (j['hints'] as num?)?.toInt() ?? 0,
      hintsChangedAt: (j['hintsAt'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ProgressSnapshot && _json(this) == _json(other);

  @override
  int get hashCode => _json(this).hashCode;

  /// A canonical string, for equality (maps compare by identity in Dart).
  static String _json(ProgressSnapshot s) => s.toJson().toString();
}

int _max(int a, int b) => a > b ? a : b;

Map<int, LevelResult> _mergeResults(
  Map<int, LevelResult> a,
  Map<int, LevelResult> b,
) {
  final out = Map<int, LevelResult>.of(a);
  for (final e in b.entries) {
    final mine = out[e.key];
    out[e.key] = mine == null
        ? e.value
        : mine.mergedWith(
            e.value.stars,
            e.value.bestMoves,
            perfect: e.value.perfect,
          );
  }
  return out;
}

/// Day keys are `yyyy-mm-dd`, so they compare as strings.
bool _later(String? a, String? b) =>
    a != null && (b == null || a.compareTo(b) > 0);

PlayStats _mergeStats(PlayStats a, PlayStats b) {
  // The current streak belongs to whichever copy won most recently; on the
  // same day, the longer one.
  final PlayStats latest;
  if (_later(a.lastWinDay, b.lastWinDay)) {
    latest = a;
  } else if (_later(b.lastWinDay, a.lastWinDay)) {
    latest = b;
  } else {
    latest = a.streak >= b.streak ? a : b;
  }
  return PlayStats(
    // Wins can't be added up: both copies may count the same wins.
    wins: _max(a.wins, b.wins),
    streak: latest.streak,
    bestStreak: _max(_max(a.bestStreak, b.bestStreak), latest.streak),
    lastWinDay: latest.lastWinDay,
  );
}

DailyStats _mergeDaily(DailyStats a, DailyStats b) {
  final stars = Map<String, int>.of(a.stars);
  for (final e in b.stars.entries) {
    stars[e.key] = _max(stars[e.key] ?? 0, e.value);
  }
  final latest = _later(a.lastDay, b.lastDay)
      ? a
      : _later(b.lastDay, a.lastDay)
          ? b
          : (a.streak >= b.streak ? a : b);
  // Two devices may each hold part of a run (one solved Monday, the other
  // Tuesday), so count the run back from the last day in the combined list.
  final run = _runEndingOn(latest.lastDay, stars);
  final streak = _max(latest.streak, run);
  return DailyStats(
    streak: streak,
    bestStreak: _max(_max(a.bestStreak, b.bestStreak), streak),
    completed: _max(_max(a.completed, b.completed), stars.length),
    lastDay: latest.lastDay,
    stars: stars,
  );
}

/// Consecutive solved days in [stars] ending on [lastDay].
int _runEndingOn(String? lastDay, Map<String, int> stars) {
  if (lastDay == null) return 0;
  final parts = lastDay.split('-').map(int.tryParse).toList();
  if (parts.length != 3 || parts.contains(null)) return 0;
  var day = DateTime(parts[0]!, parts[1]!, parts[2]!);
  var run = 0;
  while (stars.containsKey(PlayStats.dayKey(day))) {
    run++;
    day = DateTime(day.year, day.month, day.day - 1);
  }
  return run;
}

ChallengeStats _mergeChallenges(ChallengeStats a, ChallengeStats b) =>
    ChallengeStats(
      best: {
        for (final mode in ChallengeMode.values)
          if (_max(a.bestStage(mode), b.bestStage(mode)) > 0)
            mode: _max(a.bestStage(mode), b.bestStage(mode)),
      },
    );
