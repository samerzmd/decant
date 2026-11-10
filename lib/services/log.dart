import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

/// App-wide logging behind one switch.
///
/// Logging is on in debug and profile builds and off in release builds, so
/// players' logcat stays quiet. To chase a bug that only shows up in a
/// release build, turn it back on at build time:
///
///     flutter build appbundle --dart-define=DECANT_LOG=true
///
/// [enabled], [minLevel] and [sink] can also be changed at runtime (tests use
/// [sink] to capture lines).
class Log {
  Log._();

  static const bool _forced = bool.fromEnvironment('DECANT_LOG');

  /// Whether anything is logged at all.
  static bool enabled = !kReleaseMode || _forced;

  /// Lines below this level are dropped.
  static LogLevel minLevel = LogLevel.debug;

  /// Where lines go. Defaults to [debugPrint], which shows in logcat/Xcode.
  static void Function(String line) sink = _defaultSink;

  static void _defaultSink(String line) => debugPrint(line);

  /// Routine detail: lifecycle changes, engine state.
  static void d(String tag, String message) =>
      _write(LogLevel.debug, tag, message);

  static void i(String tag, String message) =>
      _write(LogLevel.info, tag, message);

  /// Something failed but the app carries on (e.g. no audio, no shader).
  static void w(String tag, String message, [Object? error]) =>
      _write(LogLevel.warning, tag, message, error);

  static void e(String tag, String message, [Object? error]) =>
      _write(LogLevel.error, tag, message, error);

  static void _write(
    LogLevel level,
    String tag,
    String message, [
    Object? error,
  ]) {
    if (!enabled || level.index < minLevel.index) return;
    final letter = level.name[0].toUpperCase();
    final detail = error == null ? '' : ': $error';
    sink('Decant $letter/$tag: $message$detail');
  }
}
