import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:decant/audio/audio_service.dart';
import 'package:decant/logic/streak_reminder.dart';
import 'package:decant/models/app_settings.dart';
import 'package:decant/models/daily_stats.dart';
import 'package:decant/services/persistence_service.dart';
import 'package:decant/services/reminder_service.dart';
import 'package:decant/state/progress_controller.dart';
import 'package:decant/state/providers.dart';
import 'package:decant/services/analytics_service.dart';
import 'package:decant/ui/reminder_prompt.dart';
import 'package:decant/ui/screens/home_screen.dart';
import 'package:decant/ui/screens/settings_screen.dart';

class _QuietAnalytics implements AnalyticsService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Answers the permission prompt with [grant]; schedules nothing.
class _FakeReminders extends ReminderService {
  final bool grant;
  int asked = 0;
  _FakeReminders(this.grant);

  @override
  Future<bool> requestPermission() async {
    asked++;
    return grant;
  }
}

void main() {
  final mon = DateTime(2026, 11, 9);
  final tue = DateTime(2026, 11, 10);
  // Solved Sunday and Monday: a 2-day streak.
  final solvedThroughMonday =
      const DailyStats().record(DateTime(2026, 11, 8), 3).record(mon, 2);

  test('reminds today when the daily is still open', () {
    final plan = planReminder(
      now: tue.add(const Duration(hours: 10)),
      hour: 19,
      daily: solvedThroughMonday,
    );
    expect(plan, ReminderPlan(DateTime(2026, 11, 10, 19), 2));
  });

  test('moves to tomorrow once today is solved, with the longer streak', () {
    final daily = solvedThroughMonday.record(tue, 3);
    final plan = planReminder(
      now: tue.add(const Duration(hours: 10)),
      hour: 19,
      daily: daily,
    );
    expect(plan, ReminderPlan(DateTime(2026, 11, 11, 19), 3));
  });

  test('after the hour passes unsolved, tomorrow is a plain nudge', () {
    final plan = planReminder(
      now: tue.add(const Duration(hours: 20)),
      hour: 19,
      daily: solvedThroughMonday,
    );
    expect(plan, ReminderPlan(DateTime(2026, 11, 11, 19), 0));
  });

  test('no streak yet: a plain nudge today', () {
    final plan = planReminder(
      now: tue.add(const Duration(hours: 8)),
      hour: 9,
      daily: const DailyStats(),
    );
    expect(plan, ReminderPlan(DateTime(2026, 11, 10, 9), 0));
  });

  test('a broken streak is not mentioned', () {
    // Last solved Sunday; by Tuesday the streak is gone.
    final daily = const DailyStats().record(DateTime(2026, 11, 8), 3);
    final plan = planReminder(
      now: tue.add(const Duration(hours: 8)),
      hour: 19,
      daily: daily,
    );
    expect(plan.streak, 0);
  });

  test('month ends roll over', () {
    final plan = planReminder(
      now: DateTime(2026, 11, 30, 22),
      hour: 9,
      daily: const DailyStats(),
    );
    expect(plan.at, DateTime(2026, 12, 1, 9));
  });

  test('reminder settings survive a save; bad hours fall back', () {
    const s = AppSettings(streakReminders: true, reminderHour: 21);
    final back = AppSettings.fromJson(s.toJson());
    expect(back.streakReminders, true);
    expect(back.reminderHour, 21);
    expect(AppSettings.fromJson({}).streakReminders, false);
    expect(AppSettings.fromJson({}).reminderHour, 19);
    expect(AppSettings.fromJson({'reminderHour': 31}).reminderHour, 19);
  });

  Future<(ProviderContainer, _FakeReminders)> pumpSettings(
    WidgetTester tester, {
    required bool grant,
  }) async {
    tester.view.physicalSize = const Size(1440, 3088);
    tester.view.devicePixelRatio = 3.5;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final persistence = await PersistenceService.create();
    final fake = _FakeReminders(grant);
    final c = ProviderContainer(
      overrides: [
        persistenceProvider.overrideWithValue(persistence),
        audioServiceProvider.overrideWithValue(AudioService()),
        reminderServiceProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();
    final label = find.text('Streak reminders');
    await tester.scrollUntilVisible(
      label,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(label);
    await tester.pump();
    return (c, fake);
  }

  Finder reminderSwitch() => find.descendant(
        of: find
            .ancestor(
              of: find.text('Streak reminders'),
              matching: find.byType(Container),
            )
            .first,
        matching: find.byType(Switch),
      );

  testWidgets('turning reminders on asks first, then offers times', (
    tester,
  ) async {
    final (c, fake) = await pumpSettings(tester, grant: true);
    expect(find.text('Reminder time'), findsNothing);
    await tester.tap(reminderSwitch());
    await tester.pump();
    expect(fake.asked, 1);
    expect(c.read(settingsProvider).streakReminders, true);
    await tester.pump();
    expect(find.text('Reminder time'), findsOneWidget);
    await tester.ensureVisible(find.text('9:00 AM'));
    await tester.pump();
    await tester.tap(find.text('9:00 AM'));
    await tester.pump();
    expect(c.read(settingsProvider).reminderHour, 9);
  });

  testWidgets('a refused permission leaves reminders off', (tester) async {
    final (c, fake) = await pumpSettings(tester, grant: false);
    await tester.tap(reminderSwitch());
    await tester.pump();
    expect(fake.asked, 1);
    expect(c.read(settingsProvider).streakReminders, false);
    await tester.pump();
    expect(find.textContaining('Notifications are off'), findsOneWidget);
  });

  test('reminders are offered once, after the player comes back', () {
    ProgressData progress({int levels = 0, int dailies = 0}) => ProgressData(
          unlockedLevel: levels + 1,
          totalStars: 0,
          levelsCompleted: levels,
          results: const {},
          daily: DailyStats(completed: dailies),
        );
    const fresh = AppSettings();
    expect(shouldOfferReminders(fresh, progress()), false);
    expect(shouldOfferReminders(fresh, progress(levels: 1)), false);
    expect(shouldOfferReminders(fresh, progress(levels: 2)), true);
    expect(shouldOfferReminders(fresh, progress(dailies: 1)), true);
    expect(
      shouldOfferReminders(
        const AppSettings(reminderOffered: true),
        progress(levels: 5),
      ),
      false,
    );
    expect(
      shouldOfferReminders(
        const AppSettings(streakReminders: true),
        progress(levels: 5),
      ),
      false,
    );
  });

  Future<(ProviderContainer, _FakeReminders)> pumpHome(
    WidgetTester tester, {
    required int solved,
    AppSettings settings = const AppSettings(tutorialSeen: true),
  }) async {
    tester.view.physicalSize = const Size(1440, 3088);
    tester.view.devicePixelRatio = 3.5;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final persistence = await PersistenceService.create();
    await persistence.saveSettings(settings);
    for (var id = 1; id <= solved; id++) {
      await persistence.recordResult(id, 3, 10);
    }
    final fake = _FakeReminders(true);
    final c = ProviderContainer(
      overrides: [
        persistenceProvider.overrideWithValue(persistence),
        audioServiceProvider.overrideWithValue(AudioService()),
        analyticsServiceProvider.overrideWithValue(_QuietAnalytics()),
        reminderServiceProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();
    return (c, fake);
  }

  /// Opens Stats from Home and comes back.
  Future<void> visitStats(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Stats'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('back on Home after two wins, it offers reminders once', (
    tester,
  ) async {
    final (c, fake) = await pumpHome(tester, solved: 2);
    expect(find.text('Keep your streak?'), findsNothing);
    await visitStats(tester);
    expect(find.text('Keep your streak?'), findsOneWidget);
    expect(find.textContaining('7:00 PM'), findsOneWidget);
    await tester.tap(find.text('Remind me'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(fake.asked, 1);
    expect(c.read(settingsProvider).streakReminders, true);
    expect(c.read(settingsProvider).reminderOffered, true);

    // Never again.
    await visitStats(tester);
    expect(find.text('Keep your streak?'), findsNothing);
    expect(fake.asked, 1);
  });

  testWidgets('"Not now" skips the permission prompt for good', (tester) async {
    final (c, fake) = await pumpHome(tester, solved: 2);
    await visitStats(tester);
    await tester.tap(find.text('Not now'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(fake.asked, 0);
    expect(c.read(settingsProvider).streakReminders, false);
    await visitStats(tester);
    expect(find.text('Keep your streak?'), findsNothing);
  });

  testWidgets('a new player is not asked yet', (tester) async {
    final (_, fake) = await pumpHome(tester, solved: 1);
    await visitStats(tester);
    expect(find.text('Keep your streak?'), findsNothing);
    expect(fake.asked, 0);
  });
}
