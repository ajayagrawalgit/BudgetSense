import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_info.dart';
import '../core/constants/enums.dart';
import '../core/constants/greetings.dart';
import '../core/services/notification_service.dart';
import '../core/utils/financial_calendar.dart';
import '../core/utils/money.dart';
import '../data/repositories/custom_field_repository.dart';
import '../data/seed/default_data.dart';
import '../domain/entities/transaction_entity.dart';
import '../data/repositories/loan_repository.dart';
import '../data/repositories/recurring_payment_repository.dart';
import '../data/repositories/reference_repository.dart';
import '../data/repositories/threshold_repository.dart';
import '../data/export/file_export_service.dart';
import '../data/import/paisa_import_service.dart';
import '../data/snapshot/app_snapshot_service.dart';
import '../domain/services/export_service.dart';
import '../domain/services/import_service.dart';
import '../domain/services/insights_service.dart';
import '../domain/services/recurrence_service.dart';
import '../domain/services/reminder_planner.dart';
import '../domain/services/snapshot_service.dart';
import '../domain/services/threshold_service.dart';
import '../features/settings/settings_controller.dart';
import '../features/settings/settings_state.dart';
import 'providers.dart';

/// Providers for the payments, loans, thresholds, custom-fields and reference
/// data domains. Split out from [providers.dart] to keep each file small.

// ---- Repositories --------------------------------------------------------

final recurringPaymentRepositoryProvider = Provider<RecurringPaymentRepository>(
  (ref) => DriftRecurringPaymentRepository(ref.watch(databaseProvider)),
);

final loanRepositoryProvider = Provider<LoanRepository>(
  (ref) => DriftLoanRepository(ref.watch(databaseProvider)),
);

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => DriftAccountRepository(ref.watch(databaseProvider)),
);

final paymentMethodRepositoryProvider = Provider<PaymentMethodRepository>(
  (ref) => DriftPaymentMethodRepository(ref.watch(databaseProvider)),
);

final customFieldRepositoryProvider = Provider<CustomFieldRepository>(
  (ref) => DriftCustomFieldRepository(ref.watch(databaseProvider)),
);

final thresholdRepositoryProvider = Provider<ThresholdRepository>(
  (ref) => DriftThresholdRepository(ref.watch(databaseProvider)),
);

final recurrenceServiceProvider =
    Provider<RecurrenceService>((_) => const RecurrenceService());

final exportServiceProvider =
    Provider<ExportService>((_) => const FileExportService());

final notificationServiceProvider =
    Provider<NotificationService>((_) => LocalNotificationService());

final reminderPlannerProvider =
    Provider<ReminderPlanner>((_) => const ReminderPlanner());

/// Imports data exported from other budgeting apps (Paisa, and more later).
final dataImportServiceProvider = Provider<DataImportService>(
  (ref) => DriftPaisaImportService(ref.watch(databaseProvider)),
);

/// Complete-app snapshot (JSON / CSV / XML): exports and restores every table
/// PLUS all settings, profile, theme, accent, font and app-icon. On import it
/// fully replaces settings (so the live theme/icon update immediately) and
/// upserts all data. This is the user's durable, forward-compatible backup.
final snapshotServiceProvider = Provider<SnapshotService>(
  (ref) => AppSnapshotService(
    ref.watch(databaseProvider),
    appVersion: AppInfo.version,
    readSettings: () async =>
        (ref.read(settingsControllerProvider).valueOrNull ??
                const SettingsState())
            .toMap(),
    writeSettings: (settings) => ref
        .read(settingsControllerProvider.notifier)
        .save((_) => SettingsState.fromMap(settings)),
  ),
);

final insightsServiceProvider =
    Provider<InsightsService>((_) => const InsightsService());

/// Picks a greeting template for the dashboard. Computed once per app launch
/// (the provider is cached for the container's lifetime), so the user sees a
/// fresh greeting each time they open the app but it stays stable while they
/// browse around. `{name}` is filled in by the dashboard.
final dashboardGreetingProvider = Provider<String>((_) {
  final index = Random().nextInt(dashboardGreetings.length);
  return dashboardGreetings[index];
});

/// Transactions across the trailing 12 financial months, for trend insights.
final trailingTransactionsProvider = FutureProvider((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  final now = DateTime.now();
  final start = DateTime(now.year - 1, now.month, 1);
  return repo.getInRange(DateRange(start, now));
});

/// Monthly trend series for the Insights screen.
final insightsTrendProvider = Provider((ref) {
  final txns = ref.watch(trailingTransactionsProvider).valueOrNull ?? const [];
  final calendar = ref.watch(financialCalendarProvider);
  return ref
      .watch(insightsServiceProvider)
      .trend(txns, calendar: calendar, months: 6);
});

// ---- Streams -------------------------------------------------------------

final recurringPaymentsStreamProvider = StreamProvider(
  (ref) => ref.watch(recurringPaymentRepositoryProvider).watchAll(),
);

final loansStreamProvider = StreamProvider(
  (ref) => ref.watch(loanRepositoryProvider).watchAll(),
);

/// The most recent EMI transaction recorded against a loan (or null). Rebuilds
/// whenever loans change - i.e. right after a new EMI is recorded.
final lastLoanPaymentProvider = FutureProvider.autoDispose
    .family<TransactionEntity?, String>((ref, loanId) {
  ref.watch(loansStreamProvider);
  return ref.watch(transactionRepositoryProvider).latestForLoan(loanId);
});

final accountsStreamProvider = StreamProvider(
  (ref) => ref.watch(accountRepositoryProvider).watchAll(),
);

final paymentMethodsStreamProvider = StreamProvider(
  (ref) => ref.watch(paymentMethodRepositoryProvider).watchAll(),
);

final customFieldsStreamProvider = StreamProvider(
  (ref) => ref.watch(customFieldRepositoryProvider).watchAll(),
);

final thresholdsStreamProvider = StreamProvider(
  (ref) => ref.watch(thresholdRepositoryProvider).watchAll(),
);

// ---- Derived: overdue / upcoming ----------------------------------------

final overduePaymentsProvider = Provider((ref) {
  final all =
      ref.watch(recurringPaymentsStreamProvider).valueOrNull ?? const [];
  return ref.watch(recurrenceServiceProvider).overdue(all, DateTime.now());
});

// ---- Derived: live threshold evaluations --------------------------------

/// Evaluates every enabled threshold against the focused month's summary.
/// This is what powers the calm dashboard warnings (Section 11).
final thresholdEvaluationsProvider = Provider<List<ThresholdEvaluation>>((ref) {
  final rules = ref.watch(thresholdsStreamProvider).valueOrNull ?? const [];
  final summary = ref.watch(monthlySummaryProvider);
  final service = ref.watch(thresholdServiceProvider);
  final income = summary.totalGains;

  Money actualFor(String? scopeKey) {
    switch (scopeKey) {
      case 'investments':
        return summary.totalInvestments;
      case 'unallocated':
        final bal = summary.totalSavings;
        return bal.isNegative ? Money.zero : bal;
      default:
        // A category-id scoped rule: look it up in per-category spend. This is
        // fully dynamic - any category the user creates can be a scope.
        return summary.perCategory[scopeKey] ?? Money.zero;
    }
  }

  // Collapse duplicate rules before evaluating so the same threshold can never
  // be surfaced twice on the Insights "Attention" card, no matter how a
  // duplicate got into the store (e.g. a suggested rule plus a hand-made one
  // that target the same scope). Identity is scope + type + target value.
  final seen = <String>{};
  final evaluations = <ThresholdEvaluation>[];
  for (final rule in rules) {
    if (!rule.enabled) continue;
    final identity = '${rule.scopeKey}|${rule.type.index}|${rule.value}';
    if (!seen.add(identity)) continue;
    evaluations.add(
      service.evaluate(
        rule,
        actual: actualFor(rule.scopeKey),
        monthlyIncome: income,
      ),
    );
  }
  return evaluations;
});

/// Only the evaluations worth surfacing as warnings (not "safe").
final thresholdWarningsProvider = Provider<List<ThresholdEvaluation>>((ref) {
  return ref
      .watch(thresholdEvaluationsProvider)
      .where(
        (e) =>
            e.status == ThresholdStatus.exceeded ||
            e.status == ThresholdStatus.approaching ||
            e.status == ThresholdStatus.belowTarget,
      )
      .toList();
});

// ---- Bulk-mutation refresh ------------------------------------------------

/// Forces every database-backed provider to re-query immediately.
///
/// Call this right after a bulk external mutation such as a snapshot restore or
/// a Paisa import. Individual Drift `.watch()` streams normally self-refresh on
/// each write, but a full restore replaces so many rows across so many tables in
/// one transaction (while the affected screens are kept alive off-stage in the
/// shell's IndexedStack) that the surest way to guarantee an instant, consistent
/// refresh on every screen is to invalidate the data providers in one shot. This
/// is why an app restart used to be needed to see restored data; now it isn't.
///
/// Kept in one place (DRY) so both the backup restore and the Paisa import use
/// the exact same, complete list. Derived providers (summaries, threshold
/// evaluations, overdue/upcoming) rebuild automatically because they watch these.
void refreshAllDataProviders(WidgetRef ref) {
  ref.invalidate(monthTransactionsProvider);
  ref.invalidate(archivedTransactionsProvider);
  ref.invalidate(categoriesStreamProvider);
  ref.invalidate(trailingTransactionsProvider);
  ref.invalidate(recurringPaymentsStreamProvider);
  ref.invalidate(loansStreamProvider);
  ref.invalidate(accountsStreamProvider);
  ref.invalidate(paymentMethodsStreamProvider);
  ref.invalidate(customFieldsStreamProvider);
  ref.invalidate(thresholdsStreamProvider);
}

/// Rolls every auto-adding recurring payment forward to the present.
///
/// Called once on launch (and whenever the app returns to the current month):
/// for each recurring payment whose due date has arrived, it posts that
/// period's expense and advances the schedule via [RecurrenceService.catchUp].
/// This is what makes a monthly/weekly/yearly commitment "recreate itself" each
/// period without the user tapping anything. Idempotent, so calling it twice in
/// a day is harmless. Manual (non-auto-add) payments are left for the user to
/// "Mark paid". Returns how many transactions were posted.
Future<int> catchUpRecurringPayments(WidgetRef ref) async {
  final repo = ref.read(recurringPaymentRepositoryProvider);
  final txnRepo = ref.read(transactionRepositoryProvider);
  final service = ref.read(recurrenceServiceProvider);

  final payments = await repo.getAll();
  final now = DateTime.now();
  var posted = 0;

  for (final payment in payments) {
    if (!payment.autoAddTransaction) continue;
    final result = service.catchUp(
      payment,
      now: now,
      newId: DefaultDataSeeder.newId,
    );
    if (result.transactions.isEmpty) continue;
    for (final txn in result.transactions) {
      await txnRepo.upsert(txn);
    }
    await repo.upsert(result.updated);
    posted += result.transactions.length;
  }

  if (posted > 0) refreshAllDataProviders(ref);
  return posted;
}
