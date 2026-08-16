import 'package:budgetsense/app/feature_providers.dart';
import 'package:budgetsense/app/providers.dart';
import 'package:budgetsense/core/constants/enums.dart';
import 'package:budgetsense/core/utils/financial_calendar.dart';
import 'package:budgetsense/core/utils/money.dart';
import 'package:budgetsense/data/database/app_database.dart';
import 'package:budgetsense/data/repositories/recurring_payment_repository.dart';
import 'package:budgetsense/data/repositories/transaction_repository.dart';
import 'package:budgetsense/domain/entities/commitment_entities.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_database.dart';

/// Guards the single most important promise BudgetSense makes about money:
/// nothing is ever recorded as spent unless the user said so.
///
/// A recurring payment (SIP, rent, subscription) that comes due while the app
/// is closed must NOT turn into an expense on next launch. The launch routine
/// may only move the schedule forward so the due date is not stale.
///
/// All database work runs inside [WidgetTester.runAsync] because drift's
/// NativeDatabase relies on real timers/microtasks that the default widget-test
/// fake-async clock does not advance.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Boots a ProviderScope over a real test database and hands back a ref.
  Future<WidgetRef> pumpRef(WidgetTester tester, AppDatabase db) async {
    late WidgetRef capturedRef;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: Consumer(
          builder: (context, ref, _) {
            capturedRef = ref;
            return const SizedBox();
          },
        ),
      ),
    );
    return capturedRef;
  }

  RecurringPaymentEntity overduePayment({
    required String id,
    required String name,
    required DateTime start,
    required bool autoAdd,
  }) =>
      RecurringPaymentEntity(
        id: id,
        name: name,
        amount: const Money(1500000),
        kind: PaymentKind.rent,
        frequency: Frequency.monthly,
        startDate: start,
        nextDueDate: start,
        createdAt: start,
        updatedAt: start,
        autoAddTransaction: autoAdd,
      );

  // The critical case: autoAddTransaction is ON and three periods are overdue.
  // Before this guarantee existed, launching the app silently created three
  // expenses the user never confirmed.
  testWidgets(
      'launch roll-forward posts NO transaction even when auto-add is on',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = newTestDatabase();
    closeTestDatabaseOnTearDown(tester, db);
    final ref = await pumpRef(tester, db);

    await tester.runAsync(() async {
      final payments = DriftRecurringPaymentRepository(db);
      final txns = DriftTransactionRepository(db);

      final now = DateTime.now();
      final start = DateTime(now.year, now.month - 3, 1);
      await payments.upsert(
        overduePayment(
          id: 'rent',
          name: 'Rent',
          start: start,
          autoAdd: true,
        ),
      );

      await rollRecurringSchedulesForward(ref);

      // The whole point: not one rupee was invented.
      expect(
        await txns.getInRange(DateRange(DateTime(2000), DateTime(2100))),
        isEmpty,
        reason: 'A payment the user never marked paid must never become '
            'an expense, no matter how many periods elapsed.',
      );

      // The schedule still moved forward so the UI is not stuck in the past.
      final updated = await payments.getById('rent');
      expect(updated!.nextDueDate.isAfter(start), isTrue);
    });
  });

  testWidgets('launch roll-forward posts nothing for manual payments either',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = newTestDatabase();
    closeTestDatabaseOnTearDown(tester, db);
    final ref = await pumpRef(tester, db);

    await tester.runAsync(() async {
      final payments = DriftRecurringPaymentRepository(db);
      final txns = DriftTransactionRepository(db);

      final now = DateTime.now();
      final start = DateTime(now.year, now.month - 2, 1);
      await payments.upsert(
        overduePayment(
          id: 'gym',
          name: 'Gym',
          start: start,
          autoAdd: false,
        ),
      );

      await rollRecurringSchedulesForward(ref);

      expect(
        await txns.getInRange(DateRange(DateTime(2000), DateTime(2100))),
        isEmpty,
      );
    });
  });

  testWidgets('roll-forward is idempotent and refresh helper stays safe',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = newTestDatabase();
    closeTestDatabaseOnTearDown(tester, db);
    final ref = await pumpRef(tester, db);

    await tester.runAsync(() async {
      final payments = DriftRecurringPaymentRepository(db);
      final txns = DriftTransactionRepository(db);

      final now = DateTime.now();
      final start = DateTime(now.year, now.month - 3, 1);
      await payments.upsert(
        overduePayment(
          id: 'sip',
          name: 'Index fund SIP',
          start: start,
          autoAdd: true,
        ),
      );

      await rollRecurringSchedulesForward(ref);
      final afterFirst = (await payments.getById('sip'))!.nextDueDate;

      // A second launch on the same day must be a complete no-op.
      final rolledAgain = await rollRecurringSchedulesForward(ref);
      expect(rolledAgain, 0);
      expect((await payments.getById('sip'))!.nextDueDate, afterFirst);
      expect(
        await txns.getInRange(DateRange(DateTime(2000), DateTime(2100))),
        isEmpty,
      );

      expect(() => refreshAllDataProviders(ref), returnsNormally);
    });
  });
}
