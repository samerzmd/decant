import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../l10n/app_localizations.dart';
import '../logic/streak_reminder.dart';
import 'log.dart';

/// Local notifications for streak reminders.
///
/// Every call is a safe no-op until [init] succeeds (and in tests, where
/// [init] never runs), so callers never need to check.
class ReminderService {
  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  ReminderService([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// The one reminder that can be pending.
  static const int _id = 7001;

  bool get ready => _ready;

  Future<void> init() async {
    if (kIsWeb) return;
    try {
      tzdata.initializeTimeZones();
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_launcher_monochrome'),
          // Ask on iOS only when the player turns reminders on.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _ready = true;
    } catch (e) {
      Log.w('Reminders', 'init failed (reminders off)', e);
    }
  }

  /// Asks the system for permission to notify. True when it's granted.
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(alert: true, sound: true) ?? false;
      }
    } catch (e) {
      Log.w('Reminders', 'permission request failed', e);
    }
    return false;
  }

  /// Replaces any pending reminder with [plan], worded in [l].
  Future<void> schedule(ReminderPlan plan, AppLocalizations l) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: _id);
      await _plugin.zonedSchedule(
        id: _id,
        title: plan.streak > 0
            ? l.reminderStreakTitle(plan.streak)
            : l.reminderTitle,
        body: plan.streak > 0 ? l.reminderStreakBody : l.reminderBody,
        scheduledDate: tz.TZDateTime.from(plan.at, tz.local),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'streak_reminders',
            l.streakReminders,
            channelDescription: l.streakRemindersSubtitle,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        // Within a few minutes is fine for a nudge, and needs no
        // exact-alarm permission.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      Log.d('Reminders', 'scheduled $plan');
    } catch (e) {
      Log.w('Reminders', 'schedule failed', e);
    }
  }

  /// Removes the pending reminder, if any.
  Future<void> cancel() async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: _id);
    } catch (e) {
      Log.w('Reminders', 'cancel failed', e);
    }
  }
}
