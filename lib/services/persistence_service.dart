import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/challenge_stats.dart';
import '../models/daily_stats.dart';
import '../models/level_result.dart';
import '../models/play_stats.dart';
import '../models/progress_snapshot.dart';

/// Persists settings and progress with `shared_preferences`.
///
/// Keys:
///  * `decant.settings`        — JSON of [AppSettings]
///  * `decant.unlocked`        — int, highest unlocked level (1-based)
///  * `decant.result.<id>`     — JSON of [LevelResult] per level
///  * `decant.stats`           — JSON of [PlayStats] (wins, daily streak)
///  * `decant.daily`           — JSON of [DailyStats] (daily challenge)
///  * `decant.challenges`      — JSON of [ChallengeStats] (best stages)
///  * `decant.hints`           — int, hints in the pool
///  * `decant.hintsAt`         — int, when the pool last changed (ms since
///                               epoch), so cloud save keeps the newest count
class PersistenceService {
  static const _kSettings = 'decant.settings';
  static const _kUnlocked = 'decant.unlocked';
  static const _kResultPrefix = 'decant.result.';
  static const _kStats = 'decant.stats';
  static const _kDaily = 'decant.daily';
  static const _kChallenges = 'decant.challenges';
  static const _kHints = 'decant.hints';
  static const _kHintsAt = 'decant.hintsAt';

  /// Hints a new player starts with, and the most the pool holds.
  static const startHints = 3;
  static const maxHints = 5;

  final SharedPreferences _prefs;
  PersistenceService(this._prefs);

  static Future<PersistenceService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return PersistenceService(prefs);
  }

  // ---- Settings ---------------------------------------------------------- //

  AppSettings loadSettings() {
    final raw = _prefs.getString(_kSettings);
    if (raw == null) return const AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> saveSettings(AppSettings settings) =>
      _prefs.setString(_kSettings, jsonEncode(settings.toJson()));

  // ---- Progress ---------------------------------------------------------- //

  /// Highest unlocked level (always ≥ 1).
  int unlockedLevel() => (_prefs.getInt(_kUnlocked) ?? 1).clamp(1, 1 << 30);

  Future<void> unlockUpTo(int level) async {
    if (level > unlockedLevel()) {
      await _prefs.setInt(_kUnlocked, level);
    }
  }

  LevelResult? resultFor(int levelId) {
    final raw = _prefs.getString('$_kResultPrefix$levelId');
    if (raw == null) return null;
    try {
      return LevelResult.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Record a completed level, merging with any previous best.
  Future<LevelResult> recordResult(
    int levelId,
    int stars,
    int moves, {
    bool perfect = false,
  }) async {
    final prev =
        resultFor(levelId) ?? const LevelResult(stars: 0, bestMoves: 0);
    final merged = prev.mergedWith(stars, moves, perfect: perfect);
    await _prefs.setString(
      '$_kResultPrefix$levelId',
      jsonEncode(merged.toJson()),
    );
    await unlockUpTo(levelId + 1);
    return merged;
  }

  /// Total stars earned across all played levels (for the home screen stat).
  int totalStars() {
    var total = 0;
    for (final key in _prefs.getKeys()) {
      if (key.startsWith(_kResultPrefix)) {
        final raw = _prefs.getString(key);
        if (raw == null) continue;
        try {
          total += (jsonDecode(raw) as Map)['stars'] as int? ?? 0;
        } catch (_) {}
      }
    }
    return total;
  }

  int levelsCompleted() =>
      _prefs.getKeys().where((k) => k.startsWith(_kResultPrefix)).length;

  // ---- Lifetime stats ---------------------------------------------------- //

  /// Lifetime counters. Players from before stats existed get their wins
  /// backfilled from levels solved, so the screen doesn't start at zero.
  PlayStats loadStats() {
    final raw = _prefs.getString(_kStats);
    if (raw != null) {
      try {
        return PlayStats.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    return PlayStats(wins: levelsCompleted());
  }

  Future<void> saveStats(PlayStats stats) =>
      _prefs.setString(_kStats, jsonEncode(stats.toJson()));

  // ---- Daily challenge --------------------------------------------------- //

  DailyStats loadDaily() {
    final raw = _prefs.getString(_kDaily);
    if (raw == null) return const DailyStats();
    try {
      return DailyStats.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const DailyStats();
    }
  }

  Future<void> saveDaily(DailyStats daily) =>
      _prefs.setString(_kDaily, jsonEncode(daily.toJson()));

  // ---- Challenge modes --------------------------------------------------- //

  ChallengeStats loadChallenges() {
    final raw = _prefs.getString(_kChallenges);
    if (raw == null) return const ChallengeStats();
    try {
      return ChallengeStats.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const ChallengeStats();
    }
  }

  Future<void> saveChallenges(ChallengeStats stats) =>
      _prefs.setString(_kChallenges, jsonEncode(stats.toJson()));

  // ---- Hints ------------------------------------------------------------- //

  int hints() => (_prefs.getInt(_kHints) ?? startHints).clamp(0, maxHints);

  /// When the pool last changed (ms since epoch), or 0 if never recorded.
  int hintsChangedAt() => _prefs.getInt(_kHintsAt) ?? 0;

  /// Saves the pool. A real change is stamped with [changedAt] (now by
  /// default), so a cloud merge keeps the newest count instead of the
  /// largest. Saving the same count leaves the stamp alone.
  Future<void> saveHints(int hints, {int? changedAt}) async {
    final value = hints.clamp(0, maxHints);
    if (changedAt == null && value == this.hints()) return;
    await _prefs.setInt(_kHints, value);
    await _prefs.setInt(
      _kHintsAt,
      changedAt ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  // ---- Custom levels ----------------------------------------------------- //

  static const _kCustom = 'decant.custom';
  static const maxCustomLevels = 20;

  /// Codes of levels the player made or opened, newest first.
  List<String> customLevelCodes() => _prefs.getStringList(_kCustom) ?? const [];

  /// Remembers [code] at the front of "My levels" (no duplicates).
  Future<void> rememberCustomLevel(String code) {
    final codes = [code, ...customLevelCodes().where((c) => c != code)];
    return _prefs.setStringList(_kCustom, codes.take(maxCustomLevels).toList());
  }

  // ---- Cloud save -------------------------------------------------------- //

  /// All progress as one value, for cloud save.
  ProgressSnapshot exportSnapshot() {
    final results = <int, LevelResult>{};
    for (final key in _prefs.getKeys()) {
      if (!key.startsWith(_kResultPrefix)) continue;
      final id = int.tryParse(key.substring(_kResultPrefix.length));
      final r = id == null ? null : resultFor(id);
      if (r != null) results[id!] = r;
    }
    return ProgressSnapshot(
      unlockedLevel: unlockedLevel(),
      results: results,
      stats: loadStats(),
      daily: loadDaily(),
      challenges: loadChallenges(),
      hints: hints(),
      hintsChangedAt: hintsChangedAt(),
    );
  }

  /// Replaces local progress with [s] (normally local merged with the cloud
  /// copy, so nothing is lost). Settings are left alone.
  Future<void> importSnapshot(ProgressSnapshot s) async {
    await _prefs.setInt(_kUnlocked, s.unlockedLevel < 1 ? 1 : s.unlockedLevel);
    for (final e in s.results.entries) {
      await _prefs.setString(
        '$_kResultPrefix${e.key}',
        jsonEncode(e.value.toJson()),
      );
    }
    await saveStats(s.stats);
    await saveDaily(s.daily);
    await saveChallenges(s.challenges);
    await saveHints(s.hints, changedAt: s.hintsChangedAt);
  }
}
