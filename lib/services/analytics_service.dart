import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/widgets.dart';

/// Thin wrapper over Firebase Analytics (Google Analytics) for gameplay and
/// screen-view events. All calls are fire-and-forget — analytics must never
/// block or crash gameplay.
class AnalyticsService {
  final FirebaseAnalytics? _analytics;

  AnalyticsService() : _analytics = FirebaseAnalytics.instance;

  /// No analytics (the web demo, which has no Firebase app): every call is a
  /// no-op.
  AnalyticsService.off() : _analytics = null;

  /// Attach to `MaterialApp.navigatorObservers` for automatic screen_view
  /// events, keyed off each route's [RouteSettings.name].
  NavigatorObserver get observer {
    final a = _analytics;
    return a == null
        ? NavigatorObserver()
        : FirebaseAnalyticsObserver(analytics: a);
  }

  void logLevelStart(int levelId) => _log('level_start', {
        'level_id': levelId,
      });

  void logLevelComplete({
    required int levelId,
    required int stars,
    required int moves,
    required int hintsUsed,
  }) =>
      _log('level_complete', {
        'level_id': levelId,
        'stars': stars,
        'moves': moves,
        'hints_used': hintsUsed,
      });

  void logHintUsed(int levelId) => _log('hint_used', {'level_id': levelId});

  /// A rewarded video for a hint closed; [earned] when it was watched through.
  void logRewardedHint({required bool earned}) =>
      _log('rewarded_hint', {'earned': earned ? 1 : 0});

  /// A badge was earned (Firebase's standard `unlock_achievement` event).
  void logAchievement(String id) =>
      _log('unlock_achievement', {'achievement_id': id});

  /// The player opened the share sheet for their daily result.
  void logDailyShared() => _log('daily_shared', const {});

  void logAddTubeUsed(int levelId) =>
      _log('add_tube_used', {'level_id': levelId});

  void logTutorialBegin({required bool replay}) =>
      _log('tutorial_begin', {'replay': replay ? 1 : 0});

  /// [skipped] is true when the player dismissed the guide early.
  void logTutorialComplete({required bool skipped}) =>
      _log('tutorial_complete', {'skipped': skipped ? 1 : 0});

  void _log(String name, Map<String, Object> params) {
    _analytics?.logEvent(name: name, parameters: params);
  }
}
