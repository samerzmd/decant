import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../logic/level_generator.dart';
import '../../state/progress_controller.dart';
import '../../state/providers.dart';
import '../theme/app_theme.dart';
import 'game_screen.dart';

/// Scrollable grid of levels. Unlocked levels show their best star rating;
/// locked levels show a padlock.
class LevelSelectScreen extends ConsumerWidget {
  const LevelSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);

    return Scaffold(
      body: DecantBackground(
        child: SafeArea(
          child: Column(
            children: [
              _Header(stars: progress.totalStars),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.82,
                  ),
                  // No itemCount → the grid is unbounded and builds tiles
                  // lazily as you scroll. Levels are infinite; a level is only
                  // generated when its tile is tapped.
                  itemBuilder: (context, i) {
                    final levelId = i + 1;
                    return _LevelTile(
                      levelId: levelId,
                      progress: progress,
                      onTap: progress.isUnlocked(levelId)
                          ? () => _open(context, levelId)
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, int levelId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/game'),
        builder: (_) => GameScreen(levelId: levelId),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int stars;
  const _Header({required this.stars});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 20, 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded,
                color: DecantColors.onSurface),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Text(
            'Levels',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: DecantColors.onSurface,
            ),
          ),
          const Spacer(),
          const Icon(Icons.star_rounded, color: DecantColors.star, size: 20),
          const SizedBox(width: 6),
          Text('$stars',
              style: const TextStyle(
                  color: DecantColors.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 16)),
        ],
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  final int levelId;
  final ProgressData progress;
  final VoidCallback? onTap;

  const _LevelTile({
    required this.levelId,
    required this.progress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final locked = onTap == null;
    final result = progress.resultFor(levelId);
    final difficulty = LevelGenerator.configFor(levelId).difficulty;
    final diffColor = _difficultyColor(difficulty);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: locked
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: locked
                ? Colors.white.withValues(alpha: 0.06)
                : diffColor.withValues(alpha: 0.55),
            width: 1.4,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (locked)
              Icon(Icons.lock_rounded,
                  color: DecantColors.subtle.withValues(alpha: 0.6), size: 22)
            else
              Text(
                '$levelId',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: DecantColors.onSurface,
                ),
              ),
            const SizedBox(height: 6),
            if (!locked)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ...List.generate(3, (s) {
                    final filled = result != null && s < result.stars;
                    return Icon(
                      filled ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 12,
                      color: filled
                          ? DecantColors.star
                          : DecantColors.subtle.withValues(alpha: 0.4),
                    );
                  }),
                  if (result?.perfect ?? false)
                    const Padding(
                      padding: EdgeInsets.only(left: 2),
                      child: Icon(
                        Icons.verified_rounded,
                        size: 12,
                        color: DecantColors.accent,
                        semanticLabel: 'Perfect',
                      ),
                    ),
                ],
              )
            else
              Text('Lvl $levelId',
                  style: TextStyle(
                      fontSize: 11,
                      color: DecantColors.subtle.withValues(alpha: 0.6))),
          ],
        ),
      ),
    );
  }

  Color _difficultyColor(int d) {
    switch (d) {
      case 1:
        return const Color(0xFF54B86B);
      case 2:
        return const Color(0xFF2BB6A6);
      case 3:
        return const Color(0xFF4AA6E8);
      case 4:
        return const Color(0xFF8E5BD9);
      default:
        return const Color(0xFFE2425B);
    }
  }
}
