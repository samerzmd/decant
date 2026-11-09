import 'package:firebase_analytics/firebase_analytics.dart';

/// Thin wrapper over Firebase Analytics (Google Analytics) for gameplay and
/// screen-view events. All calls are fire-and-forget — analytics must never
/// block or crash gameplay.
class AnalyticsService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Attach to `MaterialApp.navigatorObservers` for automatic screen_view
  /// events, keyed off each route's [RouteSettings.name].
  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

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

  void logAddTubeUsed(int levelId) =>
      _log('add_tube_used', {'level_id': levelId});

  void _log(String name, Map<String, Object> params) {
    _analytics.logEvent(name: name, parameters: params);
  }
}
