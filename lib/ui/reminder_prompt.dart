import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../models/app_settings.dart';
import '../state/progress_controller.dart';
import '../state/providers.dart';
import 'widgets/confirm_dialog.dart';
import 'widgets/decant_notice.dart';

/// Turns streak reminders on, asking the system for notification permission
/// first. If it's refused, reminders stay off and the player is told why.
/// Returns whether reminders are now on.
Future<bool> turnOnReminders(BuildContext context, WidgetRef ref) async {
  final blocked = context.l10n.notificationsBlocked;
  final granted = await ref.read(reminderServiceProvider).requestPermission();
  if (granted) {
    ref.read(settingsProvider.notifier).setStreakReminders(true);
  } else if (context.mounted) {
    showDecantNotice(context, blocked,
        icon: Icons.notifications_off_outlined, tone: NoticeTone.warning);
  }
  return granted;
}

/// Whether to offer reminders now: once, after the player has shown they
/// come back (a daily or two levels solved), and only if they're still off.
bool shouldOfferReminders(AppSettings settings, ProgressData progress) =>
    !settings.reminderOffered &&
    !settings.streakReminders &&
    (progress.daily.completed >= 1 || progress.levelsCompleted >= 2);

/// Asks "Keep your streak?" the first time [shouldOfferReminders] holds.
/// The system permission prompt only follows a yes, so it's never shown
/// cold, and the offer itself is never repeated.
Future<void> maybeOfferReminders(BuildContext context, WidgetRef ref) async {
  final settings = ref.read(settingsProvider);
  if (!shouldOfferReminders(settings, ref.read(progressProvider))) return;
  ref.read(settingsProvider.notifier).markReminderOffered();
  final l = context.l10n;
  final time = MaterialLocalizations.of(context)
      .formatTimeOfDay(TimeOfDay(hour: settings.reminderHour, minute: 0));
  final yes = await showDecantConfirm(
    context,
    title: l.reminderOfferTitle,
    message: l.reminderOfferMessage(time),
    confirmLabel: l.remindMe,
    cancelLabel: l.notNow,
    icon: Icons.notifications_active_rounded,
  );
  if (yes && context.mounted) await turnOnReminders(context, ref);
}
