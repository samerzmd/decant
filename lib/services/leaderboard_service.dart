import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../logic/daily_challenge.dart';
import 'log.dart';

/// One row on the daily leaderboard.
@immutable
class LeaderboardEntry {
  final String uid;
  final String name;
  final int moves;
  final int stars;
  const LeaderboardEntry({
    required this.uid,
    required this.name,
    required this.moves,
    required this.stars,
  });
}

/// The daily challenge leaderboard: fewest moves on today's puzzle, for
/// players signed in to cloud save.
///
/// Firestore layout: `daily/{yyyymmdd}/scores/{uid}` holding
/// `{ name, moves, stars, at }`. Security rules let a player write only their
/// own row, with sane values, and only to improve it; anyone can read.
///
/// Names are never typed by players: [nameFor] turns the account id into a
/// friendly random name like "Teal Otter 42", so there's nothing to moderate
/// and nothing personal is shown.
class LeaderboardService {
  final FirebaseFirestore? _db;

  LeaderboardService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  /// No leaderboard (tests, unsupported builds): calls do nothing.
  LeaderboardService.off() : _db = null;

  bool get enabled => _db != null;

  static String dayKey(int dailyId) => '${-dailyId}';

  CollectionReference<Map<String, dynamic>> _scores(int dailyId) =>
      _db!.collection('daily').doc(dayKey(dailyId)).collection('scores');

  /// Records a solve if it beats the player's best for that day.
  Future<void> submit({
    required int dailyId,
    required String uid,
    required int moves,
    required int stars,
  }) async {
    if (_db == null || !DailyChallenge.isDaily(dailyId)) return;
    try {
      final doc = _scores(dailyId).doc(uid);
      final old = await doc.get();
      final best = (old.data()?['moves'] as num?)?.toInt();
      if (best != null && best <= moves) return;
      await doc.set({
        'name': nameFor(uid),
        'moves': moves,
        'stars': stars,
        'at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      Log.w('Leaderboard', 'submit failed', e);
    }
  }

  /// The top [limit] scores for a day, fewest moves first.
  Future<List<LeaderboardEntry>> top(int dailyId, {int limit = 50}) async {
    if (_db == null) return const [];
    final snap = await _scores(dailyId).orderBy('moves').limit(limit).get();
    return [
      for (final d in snap.docs)
        LeaderboardEntry(
          uid: d.id,
          name: d.data()['name'] as String? ?? nameFor(d.id),
          moves: (d.data()['moves'] as num?)?.toInt() ?? 0,
          stars: (d.data()['stars'] as num?)?.toInt() ?? 0,
        ),
    ];
  }

  static const _adjectives = [
    'Teal', 'Amber', 'Coral', 'Jade', 'Azure', 'Ruby', 'Ivory', 'Violet', //
    'Golden', 'Misty', 'Quiet', 'Bright', 'Calm', 'Swift', 'Gentle', 'Lunar',
  ];
  static const _animals = [
    'Otter', 'Heron', 'Fox', 'Koala', 'Lynx', 'Panda', 'Robin', 'Seal', //
    'Swan', 'Tiger', 'Whale', 'Wren', 'Badger', 'Crane', 'Dolphin', 'Owl',
  ];

  /// A stable, friendly name for an account id, e.g. "Teal Otter 42".
  static String nameFor(String uid) {
    var h = 0;
    for (final c in uid.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    final adjective = _adjectives[h % _adjectives.length];
    final animal = _animals[(h ~/ 16) % _animals.length];
    return '$adjective $animal ${(h ~/ 256) % 90 + 10}';
  }
}
