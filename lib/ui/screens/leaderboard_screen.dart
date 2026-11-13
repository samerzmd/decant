import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../services/cloud_sync_service.dart';
import '../../services/leaderboard_service.dart';
import '../../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/star_row.dart';

/// Today's daily challenge, ranked by fewest moves.
class LeaderboardScreen extends ConsumerStatefulWidget {
  final int dailyId;
  const LeaderboardScreen({super.key, required this.dailyId});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  late Future<List<LeaderboardEntry>> _scores;

  @override
  void initState() {
    super.initState();
    _scores = ref.read(leaderboardProvider).top(widget.dailyId);
  }

  Future<void> _refresh() async {
    final next = ref.read(leaderboardProvider).top(widget.dailyId);
    setState(() => _scores = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cloud = ref.watch(cloudSyncProvider);
    return Scaffold(
      body: DecantBackground(
        child: SafeArea(
          child: ReadableWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 20, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_rounded,
                            color: DecantColors.onSurface),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.leaderboard,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: DecantColors.onSurface,
                              ),
                            ),
                            Text(
                              '${l.leaderboardToday} · ${l.dailyChallengeTitle(widget.dailyId)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: DecantColors.subtle, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                ValueListenableBuilder<CloudSyncState>(
                  valueListenable: cloud.state,
                  builder: (context, s, _) => Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                    child: Text(
                      s.user == null
                          ? l.leaderboardSignIn
                          : l.leaderboardYouAs(
                              LeaderboardService.nameFor(s.user!.uid)),
                      style:
                          TextStyle(color: DecantColors.accent, fontSize: 13),
                    ),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    child: FutureBuilder<List<LeaderboardEntry>>(
                      future: _scores,
                      builder: (context, snap) {
                        if (snap.connectionState != ConnectionState.done) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        final me = cloud.state.value.user?.uid;
                        final message = snap.hasError
                            ? l.leaderboardFailed
                            : (snap.data ?? const []).isEmpty
                                ? l.leaderboardEmpty
                                : null;
                        if (message != null) {
                          return ListView(children: [
                            Padding(
                              padding: const EdgeInsets.all(32),
                              child: Text(
                                message,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: DecantColors.subtle),
                              ),
                            ),
                          ]);
                        }
                        final rows = snap.data!;
                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                          itemCount: rows.length,
                          itemBuilder: (context, i) => _Row(
                            rank: i + 1,
                            entry: rows[i],
                            mine: rows[i].uid == me,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final int rank;
  final LeaderboardEntry entry;
  final bool mine;
  const _Row({required this.rank, required this.entry, required this.mine});

  @override
  Widget build(BuildContext context) {
    final medal = switch (rank) {
      1 => DecantColors.star,
      2 => const Color(0xFFB4BDCC),
      3 => const Color(0xFFCD8B4E),
      _ => null,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: DecantColors.ink.withValues(alpha: mine ? 0.12 : 0.05),
        borderRadius: BorderRadius.circular(14),
        border: mine
            ? Border.all(color: DecantColors.accent.withValues(alpha: 0.6))
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              '$rank',
              style: TextStyle(
                color: medal ?? DecantColors.subtle,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            child: Text(
              mine ? '${entry.name} (${context.l10n.you})' : entry.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: DecantColors.onSurface,
                fontWeight: mine ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          StarRow(earned: entry.stars, size: 14),
          const SizedBox(width: 12),
          Text(
            context.l10n.moveCount(entry.moves),
            style: TextStyle(
              color: DecantColors.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
