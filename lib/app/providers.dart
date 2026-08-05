import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/enums.dart';
import '../core/utils/financial_calendar.dart';
import '../data/database/app_database.dart';
import '../data/repositories/category_repository.dart';
import '../data/repositories/transaction_repository.dart';
import '../domain/entities/transaction_entity.dart';
import '../domain/services/summary_service.dart';
import '../domain/services/threshold_service.dart';
import '../features/settings/settings_controller.dart';

/// Central dependency-injection graph (Section 22). Everything is wired through
/// Riverpod providers so nothing constructs its own dependencies.

/// The singleton database. Disposed when the provider container is torn down.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return DriftTransactionRepository(ref.watch(databaseProvider));
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return DriftCategoryRepository(ref.watch(databaseProvider));
});

final summaryServiceProvider =
    Provider<SummaryService>((ref) => const SummaryService());

final thresholdServiceProvider =
    Provider<ThresholdService>((ref) => const ThresholdService());

/// The financial calendar derived from the user's configured month start day.
final financialCalendarProvider = Provider<FinancialCalendar>((ref) {
  final settings = ref.watch(settingsControllerProvider).valueOrNull;
  return FinancialCalendar(
    monthStartDay: settings?.financialMonthStartDay ?? 1,
  );
});

/// The month currently in focus on the dashboard / insights (any date within).
final focusedMonthProvider = StateProvider<DateTime>((_) => DateTime.now());

/// Live categories stream for the whole app.
final categoriesStreamProvider = StreamProvider((ref) {
  return ref.watch(categoryRepositoryProvider).watchAll();
});

/// Live transactions for the focused month.
final monthTransactionsProvider = StreamProvider((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  final calendar = ref.watch(financialCalendarProvider);
  final month = ref.watch(focusedMonthProvider);
  return repo.watchForMonth(month, calendar: calendar);
});

/// Live transactions for the financial month *before* the focused one. Used by
/// the delight layer to tell whether this month beats the last (Section 11).
final previousMonthTransactionsProvider = StreamProvider((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  final calendar = ref.watch(financialCalendarProvider);
  final month = ref.watch(focusedMonthProvider);
  // A date one day before the focused financial month starts lands squarely in
  // the previous financial month, whatever the configured start day.
  final inPrevMonth =
      calendar.monthRangeFor(month).start.subtract(const Duration(days: 1));
  return repo.watchForMonth(inPrevMonth, calendar: calendar);
});

/// Live stream of soft-deleted transactions - powers the Trash can screen.
final archivedTransactionsProvider = StreamProvider((ref) {
  return ref.watch(transactionRepositoryProvider).watchArchived();
});

/// Builds a [MonthlySummary] from a given transaction list using the user's
/// investment-treatment setting. Shared by the focused-month and previous-month
/// summaries so the math lives in exactly one place. Spend is tracked per
/// category dynamically; there are no fixed classification buckets.
MonthlySummary _summarize(Ref ref, List<TransactionEntity> txns) {
  final service = ref.watch(summaryServiceProvider);
  final settings = ref.watch(settingsControllerProvider).valueOrNull;

  return service.summarize(
    txns,
    investmentTreatment:
        settings?.investmentTreatment ?? InvestmentTreatment.separate,
  );
}

/// The computed monthly summary for the focused month. Recomputes reactively
/// whenever transactions, categories, or the investment-treatment setting
/// change - this is what makes the dashboard update immediately after saving.
final monthlySummaryProvider = Provider((ref) {
  final txns = ref.watch(monthTransactionsProvider).valueOrNull ?? const [];
  return _summarize(ref, txns);
});

/// The computed summary for the previous financial month. Used only to decide
/// whether the current month beats it (drives the firework celebration).
final previousMonthSummaryProvider = Provider((ref) {
  final txns =
      ref.watch(previousMonthTransactionsProvider).valueOrNull ?? const [];
  return _summarize(ref, txns);
});
