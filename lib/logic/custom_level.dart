import 'dart:convert';
import 'dart:typed_data';

import '../models/game_state.dart';
import '../models/level.dart';
import 'solver.dart';

/// Why a hand-made puzzle can't be played yet.
enum CustomLevelProblem { incomplete, alreadySolved, unsolvable }

/// Player-made levels, shared as short codes like `DCT1-BAIGAQ…`.
///
/// Custom levels live in their own id space, at or below -1,000,000,000, so
/// they never collide with campaign (positive), challenge (above a million)
/// or daily (minus `yyyymmdd`) ids. A win on one records no progress.
class CustomLevel {
  CustomLevel._();

  static const prefix = 'DCT1-';
  static const _base = -1000000000;

  static const minColors = 3;
  static const maxColors = 9;
  static const capacity = 4;
  static const emptyTubes = 2;

  static bool isCustom(int levelId) => levelId <= _base;

  /// The id a level with these tubes plays under (stable for a given code).
  static int idFor(List<List<int>> tubes) {
    var h = 17;
    for (final t in tubes) {
      h = (h * 31 + t.length) & 0x3fffffff;
      for (final c in t) {
        h = (h * 31 + c + 1) & 0x3fffffff;
      }
    }
    return _base - h;
  }

  /// A playable level from the filled tubes (empty tubes are added).
  static Level toLevel(List<List<int>> tubes) {
    final colors = {for (final t in tubes) ...t};
    return Level(
      id: idFor(tubes),
      capacity: capacity,
      colorCount: colors.length,
      filledTubes: [for (final t in tubes) List<int>.of(t)],
      emptyTubes: emptyTubes,
      difficulty: ((colors.length - 2) / 1.4).ceil().clamp(1, 5),
    );
  }

  /// Checks the counts and that the puzzle isn't already sorted. Returns null
  /// if it's ready to be checked for solvability.
  static CustomLevelProblem? shapeProblem(List<List<int>> tubes) {
    final counts = <int, int>{};
    for (final t in tubes) {
      if (t.length > capacity) return CustomLevelProblem.incomplete;
      for (final c in t) {
        counts[c] = (counts[c] ?? 0) + 1;
      }
    }
    if (counts.length < minColors || counts.values.any((n) => n != capacity)) {
      return CustomLevelProblem.incomplete;
    }
    final sorted = tubes.every(
      (t) => t.isEmpty || (t.length == capacity && t.toSet().length == 1),
    );
    return sorted ? CustomLevelProblem.alreadySolved : null;
  }

  /// Full check: shape, then a solver run (can take a moment; call it off the
  /// UI thread for big puzzles).
  static CustomLevelProblem? problem(List<List<int>> tubes) {
    final shape = shapeProblem(tubes);
    if (shape != null) return shape;
    final level = toLevel(tubes);
    final start = GameState(tubes: level.buildTubes(), extraTubesRemaining: 0);
    return Solver.isSolvable(start) ? null : CustomLevelProblem.unsolvable;
  }

  /// Encodes the filled tubes as `DCT1-` + base64url of
  /// `[tubeCount, (length, colors…)…, checksum]`.
  static String encode(List<List<int>> tubes) {
    final bytes = <int>[tubes.length];
    for (final t in tubes) {
      bytes
        ..add(t.length)
        ..addAll(t);
    }
    bytes.add(_checksum(bytes));
    return prefix +
        base64Url.encode(Uint8List.fromList(bytes)).replaceAll('=', '');
  }

  /// The filled tubes in [code], or null if it isn't a valid code. Accepts
  /// surrounding text (a pasted message) and missing padding.
  static List<List<int>>? decode(String code) {
    final match = RegExp(r'DCT1-([A-Za-z0-9_-]+)').firstMatch(code);
    if (match == null) return null;
    var body = match.group(1)!;
    body = body.padRight((body.length + 3) ~/ 4 * 4, '=');
    final List<int> bytes;
    try {
      bytes = base64Url.decode(body);
    } on FormatException {
      return null;
    }
    if (bytes.length < 3) return null;
    final payload = bytes.sublist(0, bytes.length - 1);
    if (_checksum(payload) != bytes.last) return null;
    final count = payload[0];
    if (count < minColors || count > maxColors) return null;
    final tubes = <List<int>>[];
    var i = 1;
    for (var t = 0; t < count; t++) {
      if (i >= payload.length) return null;
      final len = payload[i++];
      if (len > capacity || i + len > payload.length) return null;
      final tube = payload.sublist(i, i + len);
      if (tube.any((c) => c >= 12)) return null;
      tubes.add(tube);
      i += len;
    }
    if (i != payload.length) return null;
    return shapeProblem(tubes) == CustomLevelProblem.incomplete ? null : tubes;
  }

  static int _checksum(List<int> bytes) {
    var s = 7;
    for (final b in bytes) {
      s = (s * 33 + b) & 0xff;
    }
    return s;
  }
}
