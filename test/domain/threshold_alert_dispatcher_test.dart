import 'package:budgetsense/core/constants/enums.dart';
import 'package:budgetsense/core/services/notification_service.dart';
import 'package:budgetsense/core/utils/money.dart';
import 'package:budgetsense/core/utils/quiet_hours.dart';
import 'package:budgetsense/core/utils/reminder_schedule.dart';
import 'package:budgetsense/data/local/threshold_alert_log.dart';
import 'package:budgetsense/domain/services/threshold_alert_dispatcher.dart';
import 'package:budgetsense/domain/services/threshold_alert_planner.dart';
import 'package:budgetsense/domain/services/threshold_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _Notifications implements NotificationService {
  var shown = 0;
  var permission = true;

  @override
  Future<void> cancel(int id) async {}
  @override
  Future<void> cancelAll() async {}
  @override
  Future<void> cancelExpenseReminders() async {}
  @override
  Future<bool> ensurePermission() async => permission;
  @override
  Future<void> init() async {}
  @override
  Future<void> schedule(ScheduledAlert alert) async {}
  @override
  Future<void> scheduleExpenseReminders({
    required ReminderSchedule schedule,
    required List<String> messages,
    required List<String> titles,
  }) async {}
  @override
  Future<void> showNow(int id, String title, String body) async {
    await Future<void>.delayed(const Duration(milliseconds: 2));
    shown++;
  }
}

ThresholdEvaluation _breach() => const ThresholdEvaluation(
      rule: ThresholdRule(
        id: 'wants',
        label: 'Wants',
        type: ThresholdType.maxAmount,
        value: 10000,
        warningPercent: .8,
        criticalPercent: .95,
      ),
      status: ThresholdStatus.exceeded,
      actual: Money(11000),
      limit: Money(10000),
      usedFraction: 1.1,
    );

void main() {
  ThresholdAlertDispatcher dispatcher(_Notifications notifications) =>
      ThresholdAlertDispatcher(
        planner: const ThresholdAlertPlanner(),
        log: InMemoryThresholdAlertLog(),
        notifications: notifications,
      );

  test('quiet-hour breaches are consumed instead of deferred', () async {
    final notifications = _Notifications();
    final subject = dispatcher(notifications);
    const quiet = QuietHours(startMinute: 22 * 60, endMinute: 7 * 60);

    await subject.dispatch(
      [_breach()],
      monthKey: '2026-08',
      enabled: true,
      now: DateTime(2026, 8, 13, 2),
      quietHours: quiet,
    );
    await subject.dispatch(
      [_breach()],
      monthKey: '2026-08',
      enabled: true,
      now: DateTime(2026, 8, 13, 8),
      quietHours: quiet,
    );
    expect(notifications.shown, 0);
  });

  test('concurrent reactive dispatches show one notification', () async {
    final notifications = _Notifications();
    final subject = dispatcher(notifications);
    await Future.wait([
      subject.dispatch(
        [_breach()],
        monthKey: '2026-08',
        enabled: true,
        now: DateTime(2026, 8, 13, 12),
      ),
      subject.dispatch(
        [_breach()],
        monthKey: '2026-08',
        enabled: true,
        now: DateTime(2026, 8, 13, 12),
      ),
    ]);
    expect(notifications.shown, 1);
  });

  test('denied permission never burns the alert receipt', () async {
    final notifications = _Notifications()..permission = false;
    final subject = dispatcher(notifications);
    await subject.dispatch(
      [_breach()],
      monthKey: '2026-08',
      enabled: true,
      now: DateTime(2026, 8, 13, 12),
    );
    notifications.permission = true;
    await subject.dispatch(
      [_breach()],
      monthKey: '2026-08',
      enabled: true,
      now: DateTime(2026, 8, 13, 12),
    );
    expect(notifications.shown, 1);
  });
}
