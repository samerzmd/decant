import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/daily_stats.dart';
import '../models/level_result.dart';
import '../models/play_stats.dart';

/// Persists settings and progress with `shared_preferences`.
///
/// Keys:
///  * `decant.settings`        — JSON of [AppSettings]
///  * `decant.unlocked`        — int, highest unlocked level (1-based)
///  * `decant.result.<id>`     — JSON of [LevelResult] per level
///  * `decant.stats`           — JSON of [PlayStats] (wins, daily streak)
///  * `decant.daily`           — JSON of [DailyStats] (daily challenge)
class PersistenceService {
  static const _kSettings = 'decant.settings';
  static const _kUnlocked = 'decant.unlocked';
  static const _kResultPrefix = 'decant.result.';
  static const _kStats = 'decant.stats';
  static const _kDaily = 'decant.daily';

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
  Future<LevelResult> recordResult(int levelId, int stars, int moves) async {
    final prev =
        resultFor(levelId) ?? const LevelResult(stars: 0, bestMoves: 0);
    final merged = prev.mergedWith(stars, moves);
    await _prefs.setString(
        '$_kResultPrefix$levelId', jsonEncode(merged.toJson()));
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
}
