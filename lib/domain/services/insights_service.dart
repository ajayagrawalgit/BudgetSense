import '../../core/constants/enums.dart';
import '../../core/utils/financial_calendar.dart';
import '../../core/utils/money.dart';
import '../entities/transaction_entity.dart';

/// One month's headline figures for trend charts.
class MonthPoint {
  const MonthPoint({
    required this.monthKey,
    required this.income,
    required this.spent,
    required this.invested,
  });

  final String monthKey; // e.g. 2026-07
  final Money income;
  final Money spent;
  final Money invested;

  Money get net => income - spent - invested;
}

/// Pure, offline insight calculations (Section 14). Everything is derived from
/// the same raw transactions the rest of the app uses, so figures are
/// transparent and never diverge. No Flutter, no DB.
class InsightsService {
  const InsightsService();

  /// Build a per-financial-month trend series from [transactions], oldest to
  /// newest, limited to the most recent [months].
  List<MonthPoint> trend(
    List<TransactionEntity> transactions, {
    required FinancialCalendar calendar,
    int months = 6,
  }) {
    final byMonth =
        <String, ({List<Money> inc, List<Money> spent, List<Money> inv})>{};

    for (final t in transactions) {
      if (t.isArchived) continue;
      final key = calendar.monthKeyFor(t.occurredAt);
      final bucket = byMonth.putIfAbsent(
        key,
        () => (inc: <Money>[], spent: <Money>[], inv: <Money>[]),
      );
      switch (t.type) {
        case TransactionType.income:
          bucket.inc.add(t.amount);
        case TransactionType.investment:
          bucket.inv.add(t.amount);
        case TransactionType.expense:
        case TransactionType.recurringPayment:
        case TransactionType.loanPayment:
        case TransactionType.custom:
          bucket.spent.add(t.amount);
      }
    }

    final points = byMonth.entries
        .map(
          (e) => MonthPoint(
            monthKey: e.key,
            income: sumMoney(e.value.inc),
            spent: sumMoney(e.value.spent),
            invested: sumMoney(e.value.inv),
          ),
        )
        .toList()
      ..sort((a, b) => a.monthKey.compareTo(b.monthKey));

    if (points.length <= months) return points;
    return points.sublist(points.length - months);
  }

  /// Average daily spend within [range] given the outflow [totalSpent].
  Money averageDailySpend(Money totalSpent, DateRange range) {
    final days = range.inclusiveDays;
    if (days <= 0) return Money.zero;
    return Money((totalSpent.minorUnits / days).round());
  }

  /// Projected month-end balance: extrapolate spend at the current daily rate
  /// across the full financial month, then subtract from income & investments.
  Money projectedMonthEndBalance({
    required Money income,
    required Money spentSoFar,
    required Money invested,
    required DateRange monthRange,
    required DateTime now,
  }) {
    final elapsed = now.isAfter(monthRange.end)
        ? monthRange.inclusiveDays
        : now.difference(monthRange.start).inDays + 1;
    final safeElapsed = elapsed <= 0 ? 1 : elapsed;
    final dailyRate = spentSoFar.minorUnits / safeElapsed;
    final projectedSpend =
        Money((dailyRate * monthRange.inclusiveDays).round());
    return income - projectedSpend - invested;
  }

  /// Month-over-month change fraction for spend (positive = spending more).
  double momSpendChange(List<MonthPoint> points) {
    if (points.length < 2) return 0;
    final prev = points[points.length - 2].spent;
    final curr = points.last.spent;
    if (prev.isZero) return curr.isZero ? 0 : 1;
    return (curr - prev).ratioOf(prev);
  }

  /// Whether a transaction counts as "spending" for these breakdowns: any
  /// outflow that is not an investment (mirrors [SummaryService.totalSpent]).
  bool _isSpend(TransactionEntity t) =>
      !t.isArchived && t.isOutflow && t.type != TransactionType.investment;

  /// Total spend per weekday (DateTime.monday..DateTime.sunday). Missing days
  /// are simply absent from the map. Powers the "spending rhythm" card.
  Map<int, Money> spendByWeekday(List<TransactionEntity> transactions) {
    final byDay = <int, List<Money>>{};
    for (final t in transactions) {
      if (!_isSpend(t)) continue;
      byDay.putIfAbsent(t.occurredAt.weekday, () => <Money>[]).add(t.amount);
    }
    return {for (final e in byDay.entries) e.key: sumMoney(e.value)};
  }

  /// Count, average size and the single biggest spend in [transactions].
  ({int count, Money average, TransactionEntity? biggest}) expenseStats(
    List<TransactionEntity> transactions,
  ) {
    final spends = transactions.where(_isSpend).toList();
    if (spends.isEmpty) {
      return (count: 0, average: Money.zero, biggest: null);
    }
    final total = sumMoney(spends.map((t) => t.amount));
    spends.sort((a, b) => b.amount.compareTo(a.amount));
    return (
      count: spends.length,
      average: Money((total.minorUnits / spends.length).round()),
      biggest: spends.first,
    );
  }

  /// Income totals grouped by [IncomeType] (unspecified falls to `other`).
  Map<IncomeType, Money> incomeByType(List<TransactionEntity> transactions) {
    final byType = <IncomeType, List<Money>>{};
    for (final t in transactions) {
      if (t.isArchived || t.type != TransactionType.income) continue;
      final type = t.incomeType ?? IncomeType.other;
      byType.putIfAbsent(type, () => <Money>[]).add(t.amount);
    }
    return {for (final e in byType.entries) e.key: sumMoney(e.value)};
  }
}
