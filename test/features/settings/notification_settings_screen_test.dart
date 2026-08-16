import 'dart:convert';

import 'package:budgetsense/app/feature_providers.dart';
import 'package:budgetsense/app/providers.dart';
import 'package:budgetsense/core/constants/enums.dart';
import 'package:budgetsense/core/constants/reminder_messages.dart';
import 'package:budgetsense/core/services/notification_service.dart';
import 'package:budgetsense/core/theme/app_colors.dart';
import 'package:budgetsense/core/theme/app_theme.dart';
import 'package:budgetsense/core/utils/quiet_hours.dart';
import 'package:budgetsense/core/utils/reminder_schedule.dart';
import 'package:budgetsense/data/database/app_database.dart';
import 'package:budgetsense/features/settings/notification_settings_screen.dart';
import 'package:budgetsense/features/settings/settings_controller.dart';
import 'package:budgetsense/features/settings/settings_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/test_database.dart';

/// Behavioural tests for the Notifications screen.
///
/// The screen is the only place a user can say *when* they want to be nudged, so
/// every test here answers one question: does the choice the user made survive a
/// restart, and does it turn into the alarm they actually asked for? Assertions
/// are therefore made on the persisted settings (re-read through a fresh
/// controller, not the live in-memory copy) and on the concrete
/// [ScheduledAlert]s handed to the notification service.

/// Records everything the screen asks of the notification layer, and expands an
/// expense-reminder schedule into concrete alerts the same way
/// [LocalNotificationService] does: a rolling window of future occurrences out
/// of a reserved id block, with rotating titles/messages. The wall clock is
/// injected as [now] so the fire times are exact and never flake.
class _FakeNotificationService implements NotificationService {
  _FakeNotificationService({required this.now});

  /// Stands in for the clock the production service reads.
  final DateTime now;

  /// The reserved id block the production service uses for the nudges.
  static const int reminderIdBase = 900000;

  /// How many future nudges are laid down. Smaller than production's rolling
  /// window purely so the assertions can spell every fire time out.
  static const int window = 3;

  bool permissionGranted = true;
  int permissionRequests = 0;
  int cancelAllCount = 0;
  int cancelExpenseRemindersCount = 0;
  int scheduleExpenseRemindersCount = 0;

  /// The schedule handed over on the most recent call.
  ReminderSchedule? lastSchedule;

  /// The nudges currently laid down.
  final List<ScheduledAlert> expenseReminders = [];

  /// Notifications shown immediately (the "Send a test" button).
  final List<ScheduledAlert> shown = [];

  final List<ScheduledAlert> oneOffs = [];
  final List<int> cancelled = [];

  @override
  Future<void> init() async {}

  @override
  Future<bool> ensurePermission() async {
    permissionRequests++;
    return permissionGranted;
  }

  @override
  Future<void> schedule(ScheduledAlert alert) async => oneOffs.add(alert);

  @override
  Future<void> showNow(int id, String title, String body) async =>
      shown.add(ScheduledAlert(id: id, title: title, body: body, when: now));

  @override
  Future<void> cancel(int id) async => cancelled.add(id);

  @override
  Future<void> cancelAll() async {
    cancelAllCount++;
    expenseReminders.clear();
  }

  @override
  Future<void> cancelExpenseReminders() async {
    cancelExpenseRemindersCount++;
    expenseReminders.clear();
  }

  @override
  Future<void> scheduleExpenseReminders({
    required ReminderSchedule schedule,
    required List<String> messages,
    required List<String> titles,
  }) async {
    scheduleExpenseRemindersCount++;
    lastSchedule = schedule;
    expenseReminders.clear();
    final fireTimes = schedule.occurrences(from: now, count: window);
    for (var slot = 0; slot < fireTimes.length; slot++) {
      expenseReminders.add(
        ScheduledAlert(
          id: reminderIdBase + slot,
          title: titles[slot % titles.length],
          body: messages[slot % messages.length],
          when: fireTimes[slot],
        ),
      );
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The key [SettingsController] persists its JSON blob under.
  const settingsKey = 'budgetsense.settings.v1';

  /// Monday 1 June 2026, 9 AM: before the default 10 PM reminder, so a daily
  /// nudge still has one occurrence left today.
  final now = DateTime(2026, 6, 1, 9, 0);

  /// Puts [state] on "disk" so the screen opens with those preferences.
  void seed(SettingsState state) => SharedPreferences.setMockInitialValues(
        {settingsKey: jsonEncode(state.toMap())},
      );

  /// Re-reads the settings the way a fresh app launch would: a brand new
  /// controller, built from what was actually written to storage. Anything that
  /// only lived in the in-memory copy fails here, which is the point.
  Future<SettingsState> persisted() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container.read(settingsControllerProvider.future);
  }

  /// Drops one known, pre-existing framework warning so it cannot drown out a
  /// real failure. `CalmCard` paints its own background over the nearest
  /// `Material`, so Flutter reports (in debug builds only) that the ink splash
  /// of any `ListTile` inside it will be invisible. That is cosmetic, it is true
  /// of every screen that puts a tile inside a card, and it is not what these
  /// tests are about. Every other error still fails the test, and the test
  /// binding reinstalls its own handler when the test ends.
  void ignoreCardedListTileInkWarning() {
    final reportToTest = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details
          .exceptionAsString()
          .contains('ink splashes may be invisible')) {
        return;
      }
      reportToTest?.call(details);
    };
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    required AppDatabase db,
    required NotificationService notifications,
  }) async {
    ignoreCardedListTileInkWarning();
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final colors = AppColors.light(const Color(0xFFB07C5E));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notificationServiceProvider.overrideWithValue(notifications),
        ],
        child: MaterialApp(
          theme: AppThemeBuilder.build(colors, brightness: Brightness.light),
          home: const NotificationSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Drives the Material time picker through its keyboard entry mode, which is
  /// how a user types a time rather than dragging the dial.
  Future<void> pickTime(
    WidgetTester tester, {
    required int hour,
    required int minute,
  }) async {
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      hour.toString().padLeft(2, '0'),
    );
    await tester.enterText(
      find.byType(TextField).last,
      minute.toString().padLeft(2, '0'),
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  bool switchValueFor(WidgetTester tester, String title) => tester
      .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, title))
      .value;

  setUp(() {
    seed(const SettingsState());
    // Haptics fire on every toggle and chip. Answer the platform channel so the
    // feedback call does not blow up as a missing plugin.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            SystemChannels.platform, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('the master notifications switch', () {
    testWidgets('turning it on lays down the nudges and survives a restart',
        (tester) async {
      seed(const SettingsState(notificationsEnabled: false));
      final db = newTestDatabase();
      closeTestDatabaseOnTearDown(tester, db);
      final notifications = _FakeNotificationService(now: now);
      await pumpScreen(tester, db: db, notifications: notifications);

      // With notifications off there is nothing to configure, so the rest of
      // the screen stays out of the way.
      expect(find.text('Remind me to record expenses'), findsNothing);
      expect(find.text('Threshold alerts'), findsNothing);

      await tap(tester, find.text('Enable notifications'));

      // Permission is asked for exactly once, here, as the copy promises.
      expect(notifications.permissionRequests, 1);
      expect((await persisted()).notificationsEnabled, isTrue);
      expect(find.text('Remind me to record expenses'), findsOneWidget);
      expect(find.text('Threshold alerts'), findsOneWidget);

      // Turning notifications on re-arms the nudge the user already had on.
      expect(notifications.lastSchedule?.frequency, ReminderFrequency.daily);
      expect(
        notifications.expenseReminders.map((a) => a.when),
        [
          DateTime(2026, 6, 1, 22, 0),
          DateTime(2026, 6, 2, 22, 0),
          DateTime(2026, 6, 3, 22, 0),
        ],
      );
    });

    testWidgets('a refused permission leaves notifications off and silent',
        (tester) async {
      seed(const SettingsState(notificationsEnabled: false));
      final db = newTestDatabase();
      closeTestDatabaseOnTearDown(tester, db);
      final notifications = _FakeNotificationService(now: now)
        ..permissionGranted = false;
      await pumpScreen(tester, db: db, notifications: notifications);

      await tap(tester, find.text('Enable notifications'));

      expect(notifications.permissionRequests, 1);
      // Nothing was scheduled and, crucially, the setting did not flip: the
      // switch must not claim notifications are on when the OS said no.
      expect(notifications.scheduleExpenseRemindersCount, 0);
      expect(switchValueFor(tester, 'Enable notifications'), isFalse);
      expect((await persisted()).notificationsEnabled, isFalse);
    });

    testWidgets('turning it off cancels everything and survives a restart',
        (tester) async {
      final db = newTestDatabase();
      closeTestDatabaseOnTearDown(tester, db);
      final notifications = _FakeNotificationService(now: now);
      await pumpScreen(tester, db: db, notifications: notifications);

      await tap(tester, find.text('Enable notifications'));

      expect(notifications.cancelAllCount, 1);
      expect(notifications.expenseReminders, isEmpty);
      expect((await persisted()).notificationsEnabled, isFalse);
      // The reminder controls are gone, so nothing can be edited while off.
      expect(find.text('Remind me to record expenses'), findsNothing);
    });
  });

  group('the record-expenses nudge', () {
    testWidgets(
        'switching it off clears the nudges, switching it on relays '
        'them, and both choices persist', (tester) async {
      final db = newTestDatabase();
      closeTestDatabaseOnTearDown(tester, db);
      final notifications = _FakeNotificationService(now: now);
      await pumpScreen(tester, db: db, notifications: notifications);

      // On by default, so the subtitle describes when it fires.
      expect(find.text('Every day at 10:00 PM'), findsOneWidget);

      await tap(tester, find.text('Remind me to record expenses'));

      expect(notifications.cancelExpenseRemindersCount, 1);
      expect(notifications.expenseReminders, isEmpty);
      expect((await persisted()).dailyRecordRemindersEnabled, isFalse);
      // The schedule editor and its description are gone; the invitation copy
      // takes their place.
      expect(find.text('Every day at 10:00 PM'), findsNothing);
      expect(
        find.text('A gentle nudge so spending never goes untracked'),
        findsOneWidget,
      );
      expect(find.text('How often'), findsNothing);

      await tap(tester, find.text('Remind me to record expenses'));

      expect((await persisted()).dailyRecordRemindersEnabled, isTrue);
      expect(notifications.expenseReminders, hasLength(3));
      expect(find.text('Every day at 10:00 PM'), findsOneWidget);
    });

    testWidgets(
        'choosing weekly on a Wednesday persists and fires only on '
        'Wednesdays', (tester) async {
      final db = newTestDatabase();
      closeTestDatabaseOnTearDown(tester, db);
      final notifications = _FakeNotificationService(now: now);
      await pumpScreen(tester, db: db, notifications: notifications);

      await tap(tester, find.widgetWithText(ChoiceChip, 'Every week'));
      await tap(tester, find.widgetWithText(ChoiceChip, 'Wed'));

      final saved = await persisted();
      expect(saved.reminderFrequency, ReminderFrequency.weekly);
      expect(saved.reminderWeekday, DateTime.wednesday);
      // The time the user never touched is left alone.
      expect(saved.reminderHour, 22);

      // The freshly saved choice (not the pre-tap copy) is what got scheduled.
      expect(notifications.lastSchedule?.frequency, ReminderFrequency.weekly);
      expect(notifications.lastSchedule?.weekday, DateTime.wednesday);
      expect(
        notifications.expenseReminders.map((a) => a.when),
        [
          DateTime(2026, 6, 3, 22, 0),
          DateTime(2026, 6, 10, 22, 0),
          DateTime(2026, 6, 17, 22, 0),
        ],
      );
      // Every alert carries copy from the app's reminder library, so the user
      // never gets an empty or placeholder notification.
      for (final alert in notifications.expenseReminders) {
        expect(reminderTitles, contains(alert.title));
        expect(reminderMessages, contains(alert.body));
      }
      // And the screen now says back what was chosen.
      expect(find.text('Every Wednesday at 10:00 PM'), findsOneWidget);
    });

    testWidgets('choosing monthly on the 15th persists and fires on the 15th',
        (tester) async {
      final db = newTestDatabase();
      closeTestDatabaseOnTearDown(tester, db);
      final notifications = _FakeNotificationService(now: now);
      await pumpScreen(tester, db: db, notifications: notifications);

      await tap(tester, find.widgetWithText(ChoiceChip, 'Every month'));
      await tap(tester, find.byType(DropdownButton<int>));
      await tap(tester, find.text('15').last);

      final saved = await persisted();
      expect(saved.reminderFrequency, ReminderFrequency.monthly);
      expect(saved.reminderDayOfMonth, 15);

      expect(notifications.lastSchedule?.dayOfMonth, 15);
      expect(
        notifications.expenseReminders.map((a) => a.when),
        [
          DateTime(2026, 6, 15, 22, 0),
          DateTime(2026, 7, 15, 22, 0),
          DateTime(2026, 8, 15, 22, 0),
        ],
      );
      expect(find.text('Every month on the 15th at 10:00 PM'), findsOneWidget);
    });

    testWidgets('picking a new time persists and moves every nudge to it',
        (tester) async {
      tester.platformDispatcher.alwaysUse24HourFormatTestValue = true;
      addTearDown(tester.platformDispatcher.clearAlwaysUse24HourTestValue);
      final db = newTestDatabase();
      closeTestDatabaseOnTearDown(tester, db);
      final notifications = _FakeNotificationService(now: now);
      await pumpScreen(tester, db: db, notifications: notifications);

      expect(find.text('10:00 PM'), findsOneWidget);
      await tap(tester, find.text('Time'));
      await pickTime(tester, hour: 7, minute: 15);

      final saved = await persisted();
      expect(saved.reminderHour, 7);
      expect(saved.reminderMinute, 15);

      expect(notifications.lastSchedule?.hour, 7);
      expect(notifications.lastSchedule?.minute, 15);
      // 7:15 AM has already gone by at 9 AM, so the run starts tomorrow.
      expect(
        notifications.expenseReminders.map((a) => a.when),
        [
          DateTime(2026, 6, 2, 7, 15),
          DateTime(2026, 6, 3, 7, 15),
          DateTime(2026, 6, 4, 7, 15),
        ],
      );
      expect(find.text('7:15 AM'), findsOneWidget);
      expect(find.text('Every day at 7:15 AM'), findsOneWidget);
    });
  });

  group('threshold quiet hours', () {
    testWidgets('a window that wraps past midnight persists and reads back',
        (tester) async {
      tester.platformDispatcher.alwaysUse24HourFormatTestValue = true;
      addTearDown(tester.platformDispatcher.clearAlwaysUse24HourTestValue);
      final db = newTestDatabase();
      closeTestDatabaseOnTearDown(tester, db);
      final notifications = _FakeNotificationService(now: now);
      await pumpScreen(tester, db: db, notifications: notifications);

      expect(find.textContaining('10:00 PM to 7:00 AM'), findsOneWidget);

      await tap(tester, find.text('Threshold quiet hours'));
      // Start, then end: the two pickers appear back to back.
      await pickTime(tester, hour: 23, minute: 30);
      await pickTime(tester, hour: 6, minute: 45);

      final saved = await persisted();
      expect(saved.thresholdQuietStartMinute, 23 * 60 + 30);
      expect(saved.thresholdQuietEndMinute, 6 * 60 + 45);

      // The screen reads the saved window back to the user.
      expect(find.textContaining('11:30 PM to 6:45 AM'), findsOneWidget);

      // And it means what it says: a window whose end is "earlier" than its
      // start covers the small hours rather than silencing nothing.
      final window = QuietHours(
        startMinute: saved.thresholdQuietStartMinute,
        endMinute: saved.thresholdQuietEndMinute,
      );
      expect(window.contains(DateTime(2026, 6, 1, 23, 45)), isTrue);
      expect(window.contains(DateTime(2026, 6, 2, 2, 0)), isTrue);
      expect(window.contains(DateTime(2026, 6, 2, 6, 45)), isFalse);
      expect(window.contains(DateTime(2026, 6, 2, 13, 0)), isFalse);
    });

    testWidgets('backing out of the second picker changes nothing',
        (tester) async {
      tester.platformDispatcher.alwaysUse24HourFormatTestValue = true;
      addTearDown(tester.platformDispatcher.clearAlwaysUse24HourTestValue);
      final db = newTestDatabase();
      closeTestDatabaseOnTearDown(tester, db);
      final notifications = _FakeNotificationService(now: now);
      await pumpScreen(tester, db: db, notifications: notifications);

      await tap(tester, find.text('Threshold quiet hours'));
      await pickTime(tester, hour: 23, minute: 30);
      // Second picker up: cancel it. A half-entered range must not be saved.
      await tap(tester, find.text('Cancel'));

      final saved = await persisted();
      expect(saved.thresholdQuietStartMinute, 1320);
      expect(saved.thresholdQuietEndMinute, 420);
      expect(find.textContaining('10:00 PM to 7:00 AM'), findsOneWidget);
    });
  });

  group('the other reminder switches', () {
    testWidgets('payment and threshold alerts persist independently',
        (tester) async {
      final db = newTestDatabase();
      closeTestDatabaseOnTearDown(tester, db);
      final notifications = _FakeNotificationService(now: now);
      await pumpScreen(tester, db: db, notifications: notifications);

      await tap(tester, find.text('Payment & EMI reminders'));

      var saved = await persisted();
      expect(saved.paymentRemindersEnabled, isFalse);
      expect(saved.thresholdAlertsEnabled, isTrue,
          reason: 'one switch must not drag the other with it');

      await tap(tester, find.text('Threshold alerts'));

      saved = await persisted();
      expect(saved.paymentRemindersEnabled, isFalse);
      expect(saved.thresholdAlertsEnabled, isFalse);
      // Quiet hours only exist for threshold alerts, so they go away with them.
      expect(find.text('Threshold quiet hours'), findsNothing);
    });
  });

  group('send a test', () {
    testWidgets('shows a real sample reminder and says so', (tester) async {
      final db = newTestDatabase();
      closeTestDatabaseOnTearDown(tester, db);
      final notifications = _FakeNotificationService(now: now);
      await pumpScreen(tester, db: db, notifications: notifications);

      await tap(tester, find.text('Send a test'));

      expect(notifications.shown, hasLength(1));
      final sample = notifications.shown.single;
      expect(reminderTitles, contains(sample.title));
      expect(reminderMessages, contains(sample.body));
      expect(find.text('Sent a sample reminder your way'), findsOneWidget);
    });

    testWidgets('sends nothing and stays quiet when permission is refused',
        (tester) async {
      final db = newTestDatabase();
      closeTestDatabaseOnTearDown(tester, db);
      final notifications = _FakeNotificationService(now: now)
        ..permissionGranted = false;
      await pumpScreen(tester, db: db, notifications: notifications);

      await tap(tester, find.text('Send a test'));

      expect(notifications.shown, isEmpty);
      // No cheerful confirmation for something that never happened.
      expect(find.text('Sent a sample reminder your way'), findsNothing);
    });
  });
}
