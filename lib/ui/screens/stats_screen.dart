import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../theme/app_theme.dart';

/// Lifetime stats: daily streak, levels solved, stars, perfect levels, total
/// wins and how stars are spread across solved levels.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    final stats = progress.stats;
    final now = DateTime.now();
    final solved = progress.levelsCompleted;

    return Scaffold(
      body: DecantBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 20, 6),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: DecantColors.onSurface,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Text(
                      'Stats',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: DecantColors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(22, 6, 22, 24),
                  children: [
                    _StreakCard(
                      streak: stats.currentStreak(now),
                      best: stats.bestStreak,
                      wonToday: stats.wonToday(now),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _Tile(
                            icon: Icons.check_circle_rounded,
                            tint: DecantColors.accent,
                            value: '$solved',
                            label: 'Levels solved',
                            detail: 'Next up: level ${progress.unlockedLevel}',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Tile(
                            icon: Icons.star_rounded,
                            tint: DecantColors.star,
                            value: '${progress.totalStars}',
                            label: 'Stars',
                            detail: 'of ${solved * 3} possible',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _Tile(
                            icon: Icons.auto_awesome_rounded,
                            tint: DecantColors.star,
                            value: '${progress.perfectLevels}',
                            label: 'Perfect levels',
                            detail: 'Par moves, no hints',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Tile(
                            icon: Icons.emoji_events_rounded,
                            tint: DecantColors.accent,
                            value: '${stats.wins}',
                            label: 'Wins',
                            detail: 'Replays included',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const _SectionLabel('Stars per level'),
                    _StarBreakdown(counts: progress.starCounts),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  final int streak;
  final int best;
  final bool wonToday;

  const _StreakCard({
    required this.streak,
    required this.best,
    required this.wonToday,
  });

  @override
  Widget build(BuildContext context) {
    final title = streak == 0 ? 'No streak yet' : '$streak-day streak';
    final body = streak == 0
        ? 'Win a level today to start one.'
        : wonToday
            ? "Today's win is in. See you tomorrow."
            : 'Win a level today to keep it going.';
    const fire = Color(0xFFF2913D);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xF22A3766), Color(0xF231265C)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: DecantColors.accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: fire.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.local_fire_department_rounded,
              size: 30,
              color: streak == 0 ? DecantColors.subtle : fire,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: DecantColors.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: DecantColors.subtle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              Text(
                '$best',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: DecantColors.onSurface,
                ),
              ),
              const Text(
                'best',
                style: TextStyle(fontSize: 12, color: DecantColors.subtle),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final String value;
  final String label;
  final String detail;

  const _Tile({
    required this.icon,
    required this.tint,
    required this.value,
    required this.label,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tint, size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: DecantColors.onSurface,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: DecantColors.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: DecantColors.subtle),
          ),
        ],
      ),
    );
  }
}

class _StarBreakdown extends StatelessWidget {
  /// Levels with 1, 2 and 3 stars (index 0 = one star).
  final List<int> counts;
  const _StarBreakdown({required this.counts});

  // Brightest for three stars, fading down to one.
  static const _shades = [
    Color(0x66FFD66B),
    Color(0xAAFFD66B),
    DecantColors.star
  ];

  @override
  Widget build(BuildContext context) {
    final total = counts.fold<int>(0, (a, b) => a + b);
    if (total == 0) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Text(
          'Solve a level to see how your stars stack up.',
          style: TextStyle(fontSize: 13.5, color: DecantColors.subtle),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var s = 3; s >= 1; s--)
                    if (counts[s - 1] > 0)
                      Expanded(
                        flex: counts[s - 1],
                        child: ColoredBox(color: _shades[s - 1]),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          for (var s = 3; s >= 1; s--)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  for (var i = 0; i < 3; i++)
                    Icon(
                      Icons.star_rounded,
                      size: 18,
                      color: i < s
                          ? _shades[s - 1]
                          : Colors.white.withValues(alpha: 0.12),
                    ),
                  const SizedBox(width: 12),
                  Text(
                    '${counts[s - 1]} ${counts[s - 1] == 1 ? 'level' : 'levels'}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: DecantColors.onSurface,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
          color: DecantColors.subtle,
        ),
      ),
    );
  }
}
