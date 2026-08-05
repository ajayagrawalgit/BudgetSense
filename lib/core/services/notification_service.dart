import 'dart:math';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../constants/enums.dart';
import '../utils/reminder_schedule.dart';

/// A due reminder / alert the app wants to schedule.
class ScheduledAlert {
  const ScheduledAlert({
    required this.id,
    required this.title,
    required this.body,
    required this.when,
  });

  final int id;
  final String title;
  final String body;
  final DateTime when;
}

/// Abstraction over local notifications (Section 12). Kept behind an interface
/// so business logic never depends on the plugin directly and so it can be
/// stubbed in tests. Permissions are requested only when first needed.
abstract interface class NotificationService {
  Future<void> init();
  Future<bool> ensurePermission();
  Future<void> schedule(ScheduledAlert alert);
  Future<void> showNow(int id, String title, String body);
  Future<void> cancel(int id);
  Future<void> cancelAll();

  /// Schedules the "record your expenses" nudge according to [schedule] (daily,
  /// weekly, or monthly at a chosen time), laying down a rolling window of
  /// future alerts, each with a different message picked from [messages] /
  /// [titles]. Any previously-scheduled nudges are replaced. Payment/threshold
  /// alerts are left untouched.
  Future<void> scheduleExpenseReminders({
    required ReminderSchedule schedule,
    required List<String> messages,
    required List<String> titles,
  });

  /// Cancels only the expense nudges (not other reminders).
  Future<void> cancelExpenseReminders();
}

class LocalNotificationService implements NotificationService {
  LocalNotificationService();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channelId = 'budgetsense_reminders';
  static const _channelName = 'Reminders';

  /// Reserved notification-id block for the expense nudges, so they can be
  /// replaced/cancelled without touching payment or threshold alerts.
  static const _reminderIdBase = 900000;

  /// Upper bound on how many nudges we lay down (and therefore cancel). Daily
  /// uses the most; weekly/monthly use fewer but stay inside this block.
  static const _maxReminderSlots = 30;

  /// How many future occurrences to schedule for each frequency. We keep these
  /// modest so the total pending count stays well under the OS ceiling.
  static int _occurrenceCountFor(ReminderFrequency f) => switch (f) {
        ReminderFrequency.daily => 30,
        ReminderFrequency.weekly => 12,
        ReminderFrequency.monthly => 12,
      };

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Payment due, threshold and reminder alerts',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: DarwinNotificationDetails(),
  );

  @override
  Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    _configureLocalTimeZone();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings);
    _initialized = true;
  }

  @override
  Future<bool> ensurePermission() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(alert: true, badge: true);
      return granted ?? false;
    }
    return false;
  }

  @override
  Future<void> schedule(ScheduledAlert alert) async {
    await init();
    // Never schedule in the past.
    final when =
        alert.when.isBefore(DateTime.now()) ? DateTime.now() : alert.when;
    await _plugin.zonedSchedule(
      alert.id,
      alert.title,
      alert.body,
      tz.TZDateTime.from(when, tz.local),
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  @override
  Future<void> showNow(int id, String title, String body) async {
    await init();
    await _plugin.show(id, title, body, _details);
  }

  @override
  Future<void> scheduleExpenseReminders({
    required ReminderSchedule schedule,
    required List<String> messages,
    required List<String> titles,
  }) async {
    await init();
    await cancelExpenseReminders();
    if (messages.isEmpty) return;

    final now = DateTime.now();
    final count =
        _occurrenceCountFor(schedule.frequency).clamp(0, _maxReminderSlots);
    final fireTimes = schedule.occurrences(from: now, count: count);

    final rand = Random();
    var msgIndex = rand.nextInt(messages.length);
    var titleIndex = titles.isEmpty ? 0 : rand.nextInt(titles.length);

    for (var slot = 0; slot < fireTimes.length; slot++) {
      final title =
          titles.isEmpty ? 'BudgetSense' : titles[titleIndex % titles.length];
      final body = messages[msgIndex % messages.length];
      await _plugin.zonedSchedule(
        _reminderIdBase + slot,
        title,
        body,
        tz.TZDateTime.from(fireTimes[slot], tz.local),
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      msgIndex++;
      titleIndex++;
    }
  }

  @override
  Future<void> cancelExpenseReminders() async {
    await init();
    for (var i = 0; i < _maxReminderSlots; i++) {
      await _plugin.cancel(_reminderIdBase + i);
    }
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id);

  @override
  Future<void> cancelAll() => _plugin.cancelAll();

  /// Points `tz.local` at the device's actual zone so scheduled times mean
  /// wall-clock time (without this the plugin defaults to UTC). We can't read
  /// the IANA name offline, so we match the current UTC offset, preferring
  /// Asia/Kolkata (the app's default region / IST) when it fits.
  void _configureLocalTimeZone() {
    try {
      final offset = DateTime.now().timeZoneOffset;
      final kolkata = tz.getLocation('Asia/Kolkata');
      if (tz.TZDateTime.now(kolkata).timeZoneOffset == offset) {
        tz.setLocalLocation(kolkata);
        return;
      }
      for (final location in tz.timeZoneDatabase.locations.values) {
        if (tz.TZDateTime.now(location).timeZoneOffset == offset) {
          tz.setLocalLocation(location);
          return;
        }
      }
      tz.setLocalLocation(kolkata);
    } catch (_) {
      // Leave the default location if anything goes wrong.
    }
  }
}
