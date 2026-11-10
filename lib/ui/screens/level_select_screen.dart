import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../logic/level_generator.dart';
import '../../models/chapter.dart';
import '../../state/progress_controller.dart';
import '../../state/providers.dart';
import '../theme/app_theme.dart';
import 'game_screen.dart';
import '../../l10n/l10n.dart';

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
                // One section per chapter, built lazily as you scroll; there's
                // no end, since levels are infinite.
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemBuilder: (context, index) {
                    final chapter = Chapter.forLevel(index * Chapter.size + 1);
                    return _ChapterSection(
                      chapter: chapter,
                      progress: progress,
                      onOpen: (levelId) => _open(context, levelId),
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
          Expanded(
            child: Text(
              context.l10n.levels,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: DecantColors.onSurface,
              ),
            ),
          ),
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
        // Scales down inside the fixed grid cell at large text sizes.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                        filled
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 12,
                        color: filled
                            ? DecantColors.star
                            : DecantColors.subtle.withValues(alpha: 0.4),
                      );
                    }),
                    if (result?.perfect ?? false)
                      Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: Icon(
                          Icons.verified_rounded,
                          size: 12,
                          color: DecantColors.accent,
                          semanticLabel: context.l10n.perfect,
                        ),
                      ),
                  ],
                )
              else
                Text(context.l10n.levelShort(levelId),
                    style: TextStyle(
                        fontSize: 11,
                        color: DecantColors.subtle.withValues(alpha: 0.6))),
            ],
          ),
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

/// A chapter's header (with its palette as a swatch) and its 20 levels.
class _ChapterSection extends StatelessWidget {
  final Chapter chapter;
  final ProgressData progress;
  final ValueChanged<int> onOpen;

  const _ChapterSection({
    required this.chapter,
    required this.progress,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    var solved = 0;
    for (var id = chapter.firstLevel; id <= chapter.lastLevel; id++) {
      if (progress.resultFor(id) != null) solved++;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 14, 2, 10),
          child: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: chapter.colors),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.l10n.chapter(chapter),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: DecantColors.onSurface,
                  ),
                ),
              ),
              Text(
                context.l10n.chapterSolved(solved, Chapter.size),
                style: TextStyle(
                  fontSize: 12,
                  color: DecantColors.subtle.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
        GridView.count(
          // Four across on phones, more on tablets and in landscape. Each
          // count divides a 20-level chapter, so no row is left half full.
          crossAxisCount: _columnsFor(MediaQuery.sizeOf(context).width),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.82,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            for (var id = chapter.firstLevel; id <= chapter.lastLevel; id++)
              _LevelTile(
                levelId: id,
                progress: progress,
                onTap: progress.isUnlocked(id) ? _opener(id) : null,
              ),
          ],
        ),
      ],
    );
  }

  VoidCallback _opener(int levelId) => () => onOpen(levelId);
}

/// Level-grid columns for a screen [width] in dp.
int _columnsFor(double width) => width >= 1100
    ? 10
    : width >= 600
        ? 5
        : 4;
