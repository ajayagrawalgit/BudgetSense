import 'package:budgetsense/app/feature_providers.dart';
import 'package:budgetsense/app/providers.dart';
import 'package:budgetsense/core/constants/enums.dart';
import 'package:budgetsense/core/utils/financial_calendar.dart';
import 'package:budgetsense/core/utils/money.dart';
import 'package:budgetsense/data/repositories/recurring_payment_repository.dart';
import 'package:budgetsense/data/repositories/transaction_repository.dart';
import 'package:budgetsense/domain/entities/commitment_entities.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_database.dart';

/// Exercises the WidgetRef-driven launch routines: rolling auto-add recurring
/// payments forward and the bulk provider-refresh helper.
///
/// All database work runs inside [WidgetTester.runAsync] because drift's
/// NativeDatabase relies on real timers/microtasks that the default widget-test
/// fake-async clock does not advance.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'catchUpRecurringPayments posts overdue auto-add periods and refreshes',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = newTestDatabase();
    addTearDown(db.close);

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

    await tester.runAsync(() async {
      final payments = DriftRecurringPaymentRepository(db);
      final txns = DriftTransactionRepository(db);

      final now = DateTime.now();
      final start = DateTime(now.year, now.month - 3, 1);
      await payments.upsert(
        RecurringPaymentEntity(
          id: 'rent',
          name: 'Rent',
          amount: const Money(1500000),
          kind: PaymentKind.rent,
          frequency: Frequency.monthly,
          startDate: start,
          nextDueDate: start,
          createdAt: start,
          updatedAt: start,
          autoAddTransaction: true,
        ),
      );

      final posted = await catchUpRecurringPayments(capturedRef);
      expect(posted, greaterThan(0));

      final all =
          await txns.getInRange(DateRange(DateTime(2000), DateTime(2100)));
      expect(all, isNotEmpty);
      expect(all.every((t) => t.amount == const Money(1500000)), isTrue);

      final updated = await payments.getById('rent');
      expect(updated!.nextDueDate.isAfter(start), isTrue);

      expect(() => refreshAllDataProviders(capturedRef), returnsNormally);
    });
  });

  testWidgets('catchUpRecurringPayments ignores manual (non-auto-add) payments',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = newTestDatabase();
    addTearDown(db.close);

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

    await tester.runAsync(() async {
      final payments = DriftRecurringPaymentRepository(db);
      final txns = DriftTransactionRepository(db);

      final now = DateTime.now();
      final start = DateTime(now.year, now.month - 2, 1);
      await payments.upsert(
        RecurringPaymentEntity(
          id: 'gym',
          name: 'Gym',
          amount: const Money(200000),
          kind: PaymentKind.subscription,
          frequency: Frequency.monthly,
          startDate: start,
          nextDueDate: start,
          createdAt: start,
          updatedAt: start,
        ),
      );

      final posted = await catchUpRecurringPayments(capturedRef);
      expect(posted, 0);
      expect(
        await txns.getInRange(DateRange(DateTime(2000), DateTime(2100))),
        isEmpty,
      );
    });
  });
}
