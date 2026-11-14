import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../services/cloud_sync_service.dart';
import '../../state/providers.dart';
import '../theme/app_theme.dart';
import 'confirm_dialog.dart';
import 'decant_button.dart';
import 'decant_notice.dart';

/// Settings card for optional cloud save: sign in with Google, see the sync
/// state, sync now, sign out, or delete the cloud copy and account.
///
/// Hidden when the build has no cloud save ([CloudSyncService.off]).
class CloudSaveSection extends ConsumerWidget {
  const CloudSaveSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cloud = ref.watch(cloudSyncProvider);
    if (!cloud.available) return const SizedBox.shrink();
    return ValueListenableBuilder<CloudSyncState>(
      valueListenable: cloud.state,
      builder: (context, s, _) => _Card(cloud: cloud, state: s),
    );
  }
}

class _Card extends StatelessWidget {
  final CloudSyncService cloud;
  final CloudSyncState state;
  const _Card({required this.cloud, required this.state});

  Future<void> _signIn(BuildContext context) async {
    final failed = context.l10n.signInFailed;
    final result = await cloud.signIn();
    if (result == SignInResult.failed && context.mounted) {
      showDecantNotice(
        context,
        failed,
        icon: Icons.cloud_off_rounded,
        tone: NoticeTone.warning,
      );
    }
  }

  Future<void> _signOut(BuildContext context) async {
    final message = context.l10n.signedOutNotice;
    await cloud.signOut();
    if (context.mounted) {
      showDecantNotice(context, message, icon: Icons.logout_rounded);
    }
  }

  Future<void> _delete(BuildContext context) async {
    final l = context.l10n;
    final yes = await showDecantConfirm(
      context,
      title: '${l.deleteCloudSave}?',
      message: l.deleteCloudSaveMessage,
      confirmLabel: l.delete,
      cancelLabel: l.notNow,
      icon: Icons.delete_outline_rounded,
    );
    if (!yes) return;
    final ok = await cloud.deleteAccount();
    if (!context.mounted) return;
    showDecantNotice(
      context,
      ok ? l.cloudDeleted : l.cloudDeleteFailed,
      icon: ok ? Icons.delete_outline_rounded : Icons.cloud_off_rounded,
      tone: ok ? NoticeTone.info : NoticeTone.warning,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final user = state.user;
    final IconData icon;
    final Color tint;
    if (user == null) {
      icon = Icons.cloud_upload_outlined;
      tint = DecantColors.accent;
    } else if (state.failed) {
      icon = Icons.cloud_off_rounded;
      tint = DecantColors.star;
    } else {
      icon = Icons.cloud_done_rounded;
      tint = DecantColors.accent;
    }
    final status = user == null
        ? l.cloudSaveSubtitle
        : state.syncing
            ? l.cloudSyncing
            : state.failed
                ? l.cloudSyncFailed
                : l.cloudSynced;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DecantColors.ink.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tint.withValues(alpha: 0.15),
                ),
                child: state.syncing
                    ? Padding(
                        padding: const EdgeInsets.all(11),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: tint,
                        ),
                      )
                    : Icon(icon, color: tint, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user == null
                          ? l.cloudSave
                          : l.cloudSignedInAs(
                              user.email ?? user.name ?? l.cloudSave,
                            ),
                      style: TextStyle(
                        color: DecantColors.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status,
                      style: TextStyle(
                        color: DecantColors.subtle.withValues(alpha: 0.85),
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (user == null)
            DecantButton(
              label: l.signInWithGoogle,
              icon: Icons.login_rounded,
              onPressed: () => _signIn(context),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: DecantButton(
                    label: l.syncNow,
                    icon: Icons.sync_rounded,
                    onPressed: state.syncing ? null : cloud.sync,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DecantButton(
                    label: l.signOut,
                    primary: false,
                    onPressed: () => _signOut(context),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _delete(context),
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: DecantColors.danger,
                ),
                label: Text(
                  l.deleteCloudSave,
                  style: TextStyle(color: DecantColors.danger),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
