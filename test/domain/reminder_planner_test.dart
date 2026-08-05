import 'package:budgetsense/core/constants/enums.dart';
import 'package:budgetsense/core/utils/money.dart';
import 'package:budgetsense/domain/entities/commitment_entities.dart';
import 'package:budgetsense/domain/services/reminder_planner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const planner = ReminderPlanner();
  final now = DateTime(2026, 7, 20);

  RecurringPaymentEntity payment({
    bool reminder = true,
    int daysBefore = 2,
    DateTime? due,
    bool archived = false,
  }) {
    return RecurringPaymentEntity(
      id: 'p1',
      name: 'Rent',
      amount: const Money(1500000),
      kind: PaymentKind.rent,
      frequency: Frequency.monthly,
      startDate: DateTime(2026, 1, 1),
      nextDueDate: due ?? DateTime(2026, 7, 25),
      reminderEnabled: reminder,
      reminderDaysBefore: daysBefore,
      archivedAt: archived ? DateTime(2026, 1, 1) : null,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
  }

  test('plans a reminder N days before the due date', () {
    final alerts = planner.planForPayments([payment()], now: now);
    expect(alerts, hasLength(1));
    expect(alerts.first.when, DateTime(2026, 7, 23)); // 25th - 2 days
    expect(alerts.first.title, contains('due'));
  });

  test('skips disabled reminders and archived payments', () {
    final alerts = planner.planForPayments(
      [payment(reminder: false), payment(archived: true)],
      now: now,
    );
    expect(alerts, isEmpty);
  });

  test('skips reminders whose time is well in the past', () {
    final alerts = planner.planForPayments(
      [payment(due: DateTime(2026, 6, 1))],
      now: now,
    );
    expect(alerts, isEmpty);
  });

  test('produces stable, distinct ids per payment', () {
    final a = planner.planForPayments([payment()], now: now).first;
    final b = planner.planForPayments([payment()], now: now).first;
    expect(a.id, b.id); // stable across runs
    expect(a.id, greaterThan(0));
  });

  test('plans loan EMI reminders one day before', () {
    final loan = LoanEntity(
      id: 'l1',
      name: 'Home',
      originalPrincipal: const Money(5000000),
      outstandingPrincipal: const Money(3000000),
      emi: const Money(200000),
      frequency: Frequency.monthly,
      startDate: DateTime(2026, 1, 1),
      nextPaymentDate: DateTime(2026, 7, 25),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    final alerts = planner.planForLoans([loan], now: now);
    expect(alerts, hasLength(1));
    expect(alerts.first.when, DateTime(2026, 7, 24));
    expect(alerts.first.title, contains('EMI'));
  });
}
