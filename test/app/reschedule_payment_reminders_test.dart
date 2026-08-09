import 'dart:convert';

import 'package:budgetsense/app/feature_providers.dart';
import 'package:budgetsense/core/constants/enums.dart';
import 'package:budgetsense/core/services/notification_service.dart';
import 'package:budgetsense/core/utils/money.dart';
import 'package:budgetsense/core/utils/reminder_schedule.dart';
import 'package:budgetsense/domain/entities/commitment_entities.dart';
import 'package:budgetsense/features/settings/settings_controller.dart';
import 'package:budgetsense/features/settings/settings_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records what would have been scheduled/cancelled, so tests never touch a
/// real platform channel.
class FakeNotificationService implements NotificationService {
  final Map<int, ScheduledAlert> scheduled = {};
  final List<int> cancelled = [];

  @override
  Future<void> init() async {}

  @override
  Future<bool> ensurePermission() async {
    return true;
  }

  @override
  Future<void> schedule(ScheduledAlert alert) async {
    scheduled[alert.id] = alert;
  }

  @override
  Future<void> showNow(int id, String title, String body) async {}

  @override
  Future<void> cancel(int id) async {
    scheduled.remove(id);
    cancelled.add(id);
  }

  @override
  Future<void> cancelAll() async {
    scheduled.clear();
  }

  @override
  Future<void> scheduleExpenseReminders({
    required ReminderSchedule schedule,
    required List<String> messages,
    required List<String> titles,
  }) async {}

  @override
  Future<void> cancelExpenseReminders() async {}
}

Future<WidgetRef> pumpRef(
  WidgetTester tester, {
  required bool notificationsEnabled,
  required List<RecurringPaymentEntity> payments,
  required List<LoanEntity> loans,
  required FakeNotificationService fake,
}) async {
  final settings = const SettingsState()
      .copyWith(notificationsEnabled: notificationsEnabled)
      .toMap();
  SharedPreferences.setMockInitialValues({
    'budgetsense.settings.v1': jsonEncode(settings),
  });
  late WidgetRef capturedRef;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        notificationServiceProvider.overrideWithValue(fake),
        recurringPaymentsStreamProvider
            .overrideWith((ref) => Stream.value(payments)),
        loansStreamProvider.overrideWith((ref) => Stream.value(loans)),
      ],
      child: Consumer(
        builder: (context, ref, child) {
          capturedRef = ref;
          return const SizedBox();
        },
      ),
    ),
  );
  await tester.pump();
  await capturedRef.read(settingsControllerProvider.future);
  // A StreamProvider's first value only lands on the next microtask; force it
  // to arrive before returning so reschedulePaymentReminders' .valueOrNull
  // reads don't race an empty AsyncLoading state.
  await capturedRef.read(recurringPaymentsStreamProvider.future);
  await capturedRef.read(loansStreamProvider.future);
  return capturedRef;
}

RecurringPaymentEntity _payment({String id = 'netflix', bool reminderEnabled = true}) {
  final now = DateTime.now();
  return RecurringPaymentEntity(
    id: id,
    name: 'Netflix',
    amount: const Money(49900),
    kind: PaymentKind.subscription,
    frequency: Frequency.monthly,
    startDate: now,
    nextDueDate: now.add(const Duration(days: 2)),
    createdAt: now,
    updatedAt: now,
    reminderEnabled: reminderEnabled,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('schedules an alert for a due payment when enabled',
      (tester) async {
    final fake = FakeNotificationService();
    final ref = await pumpRef(
      tester,
      notificationsEnabled: true,
      payments: [_payment(id: 'p-schedule-test')],
      loans: const [],
      fake: fake,
    );

    await reschedulePaymentReminders(ref);
    expect(fake.scheduled.length, 1);
    expect(fake.scheduled.values.first.title, 'Payment due soon');
  });

  testWidgets(
      'cancels a reminder once its payment stops qualifying '
      '(e.g. reminder turned off)', (tester) async {
    final fake = FakeNotificationService();
    final ref = await pumpRef(
      tester,
      notificationsEnabled: true,
      payments: [_payment(id: 'p-cancel-test')],
      loans: const [],
      fake: fake,
    );
    await reschedulePaymentReminders(ref);
    expect(fake.scheduled.length, 1);
    final scheduledId = fake.scheduled.keys.first;

    // Same payment, reminder now off: rescheduling should drop the alert.
    // Tear the tree down first so the second pumpRef gets a brand-new
    // ProviderScope/container instead of Riverpod trying to hot-update the
    // existing one's overrides.
    await tester.pumpWidget(const SizedBox());
    final ref2 = await pumpRef(
      tester,
      notificationsEnabled: true,
      payments: [_payment(id: 'p-cancel-test', reminderEnabled: false)],
      loans: const [],
      fake: fake,
    );
    await reschedulePaymentReminders(ref2);

    expect(fake.scheduled, isEmpty);
    expect(fake.cancelled, contains(scheduledId));
  });

  testWidgets(
      'is a no-op (and clears anything pending) when notifications are '
      'disabled', (tester) async {
    final fake = FakeNotificationService();
    final ref = await pumpRef(
      tester,
      notificationsEnabled: false,
      payments: [_payment(id: 'p-disabled-test')],
      loans: const [],
      fake: fake,
    );

    await reschedulePaymentReminders(ref);
    expect(fake.scheduled, isEmpty);
  });
}
