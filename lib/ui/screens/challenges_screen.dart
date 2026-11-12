import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../logic/challenge.dart';
import '../../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/decant_button.dart';
import 'game_screen.dart';
import '../../l10n/l10n.dart';

/// Picks a challenge mode. Each mode is an endless ladder of stages; this
/// shows the best stage cleared and starts the next one.
class ChallengesScreen extends ConsumerWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(progressProvider).challenges;

    return Scaffold(
      body: DecantBackground(
        child: SafeArea(
          child: ReadableWidth(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 24),
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_rounded,
                          color: DecantColors.onSurface),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(
                        context.l10n.challenges,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: DecantColors.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final mode in ChallengeMode.values)
                  _ModeCard(
                    mode: mode,
                    best: stats.bestStage(mode),
                    onPlay: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        settings: const RouteSettings(name: '/game'),
                        builder: (_) => GameScreen(
                          levelId: Challenge.idFor(mode, stats.nextStage(mode)),
                        ),
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

class _ModeCard extends StatelessWidget {
  final ChallengeMode mode;
  final int best;
  final VoidCallback onPlay;

  const _ModeCard({
    required this.mode,
    required this.best,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: DecantColors.ink.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: DecantColors.ink.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                mode == ChallengeMode.moves
                    ? Icons.filter_list_rounded
                    : Icons.timer_outlined,
                color: DecantColors.accent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.l10n.challengeMode(mode),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: DecantColors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.challengeBlurb(mode),
            style: TextStyle(
              color: DecantColors.subtle.withValues(alpha: 0.9),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            best > 0 ? context.l10n.bestStage(best) : context.l10n.notPlayed,
            style: TextStyle(
              color: DecantColors.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          DecantButton(
            label: context.l10n.playStage(best + 1),
            icon: Icons.play_arrow_rounded,
            expand: true,
            onPressed: onPlay,
          ),
        ],
      ),
    );
  }
}
