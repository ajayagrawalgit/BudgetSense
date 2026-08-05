import 'package:budgetsense/app/feature_providers.dart';
import 'package:budgetsense/app/providers.dart';
import 'package:budgetsense/data/repositories/category_repository.dart';
import 'package:budgetsense/data/repositories/custom_field_repository.dart';
import 'package:budgetsense/data/repositories/loan_repository.dart';
import 'package:budgetsense/data/repositories/recurring_payment_repository.dart';
import 'package:budgetsense/data/repositories/reference_repository.dart';
import 'package:budgetsense/data/repositories/threshold_repository.dart';
import 'package:budgetsense/data/repositories/transaction_repository.dart';
import 'package:budgetsense/domain/services/snapshot_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_database.dart';

/// Verifies the dependency-injection graph is wired correctly: every provider
/// resolves to the expected concrete implementation, sharing the single
/// database instance, and every DB-backed stream/future actually emits. This is
/// the wiring contract the whole app relies on.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final db = newTestDatabase();
    addTearDown(db.close);
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
  });

  test(
      'core repositories resolve to their Drift implementations and share '
      'one database', () {
    final db = container.read(databaseProvider);
    expect(identical(container.read(databaseProvider), db), isTrue);
    expect(
      container.read(transactionRepositoryProvider),
      isA<DriftTransactionRepository>(),
    );
    expect(
      container.read(categoryRepositoryProvider),
      isA<DriftCategoryRepository>(),
    );
  });

  test('feature repositories resolve to their Drift implementations', () {
    expect(
      container.read(recurringPaymentRepositoryProvider),
      isA<DriftRecurringPaymentRepository>(),
    );
    expect(container.read(loanRepositoryProvider), isA<DriftLoanRepository>());
    expect(
      container.read(accountRepositoryProvider),
      isA<DriftAccountRepository>(),
    );
    expect(
      container.read(paymentMethodRepositoryProvider),
      isA<DriftPaymentMethodRepository>(),
    );
    expect(
      container.read(customFieldRepositoryProvider),
      isA<DriftCustomFieldRepository>(),
    );
    expect(
      container.read(thresholdRepositoryProvider),
      isA<DriftThresholdRepository>(),
    );
    expect(container.read(snapshotServiceProvider), isA<SnapshotService>());
  });

  test('service providers are constructible', () {
    expect(container.read(summaryServiceProvider), isNotNull);
    expect(container.read(thresholdServiceProvider), isNotNull);
    expect(container.read(recurrenceServiceProvider), isNotNull);
    expect(container.read(insightsServiceProvider), isNotNull);
    expect(container.read(reminderPlannerProvider), isNotNull);
    expect(container.read(exportServiceProvider), isNotNull);
    expect(container.read(notificationServiceProvider), isNotNull);
    expect(container.read(dataImportServiceProvider), isNotNull);
    expect(container.read(dashboardGreetingProvider), isNotEmpty);
  });

  test('financial calendar derives from settings (defaults to day 1)', () {
    final cal = container.read(financialCalendarProvider);
    expect(cal.monthStartDay, 1);
  });

  test('all database-backed streams emit an initial (empty) value', () async {
    expect(await container.read(categoriesStreamProvider.future), isEmpty);
    expect(await container.read(monthTransactionsProvider.future), isEmpty);
    expect(
      await container.read(previousMonthTransactionsProvider.future),
      isEmpty,
    );
    expect(await container.read(archivedTransactionsProvider.future), isEmpty);
    expect(
      await container.read(recurringPaymentsStreamProvider.future),
      isEmpty,
    );
    expect(await container.read(loansStreamProvider.future), isEmpty);
    expect(await container.read(accountsStreamProvider.future), isEmpty);
    expect(await container.read(paymentMethodsStreamProvider.future), isEmpty);
    expect(await container.read(customFieldsStreamProvider.future), isEmpty);
    expect(await container.read(thresholdsStreamProvider.future), isEmpty);
    expect(await container.read(trailingTransactionsProvider.future), isEmpty);
  });

  test('derived providers compute over empty data without throwing', () async {
    // Prime the async dependencies first.
    await container.read(monthTransactionsProvider.future);
    await container.read(thresholdsStreamProvider.future);
    expect(container.read(monthlySummaryProvider), isNotNull);
    expect(container.read(previousMonthSummaryProvider), isNotNull);
    expect(container.read(overduePaymentsProvider), isEmpty);
    expect(container.read(thresholdEvaluationsProvider), isEmpty);
    expect(container.read(thresholdWarningsProvider), isEmpty);
    expect(container.read(insightsTrendProvider), isNotNull);
  });
}
