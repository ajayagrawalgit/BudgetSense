import '../../core/constants/enums.dart';
import '../../core/utils/money.dart';
import '../entities/transaction_entity.dart';
import 'insights_service.dart';
import 'summary_service.dart';
import 'threshold_service.dart';

/// A quiet, factual closing note for one completed financial month.
///
/// It owns no persistence and makes no financial decisions. Every number is
/// derived from the same transactions and [MonthlySummary] shown elsewhere, so
/// a monthly reflection can never disagree with the dashboard.
class MonthCloseReport {
  const MonthCloseReport({
    required this.summary,
    required this.spendChange,
    required this.expenseCount,
    required this.averageExpense,
    required this.biggestExpense,
    required this.busiestWeekday,
    required this.thresholdsKept,
    required this.thresholdsBreached,
  });

  final MonthlySummary summary;

  /// Positive means spending rose compared with the preceding month.
  final double spendChange;
  final int expenseCount;
  final Money averageExpense;
  final TransactionEntity? biggestExpense;

  /// DateTime.monday through DateTime.sunday, null when there was no spend.
  final int? busiestWeekday;
  final int thresholdsKept;
  final int thresholdsBreached;

  bool get hasActivity =>
      summary.totalGains != Money.zero ||
      summary.totalSpent != Money.zero ||
      summary.totalInvestments != Money.zero;
}

/// Assembles the existing summary and insight primitives into a month-close
/// report. This class is intentionally pure, keeping the monthly close easy to
/// verify without widgets, a database or clock manipulation.
class MonthCloseService {
  const MonthCloseService({InsightsService insights = const InsightsService()})
      : _insights = insights;

  final InsightsService _insights;

  MonthCloseReport build({
    required MonthlySummary summary,
    required MonthlySummary previousSummary,
    required List<TransactionEntity> transactions,
    required List<ThresholdEvaluation> thresholds,
  }) {
    final stats = _insights.expenseStats(transactions);
    final rhythm = _insights.spendByWeekday(transactions);
    final busiest = rhythm.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    var kept = 0;
    var breached = 0;
    for (final evaluation in thresholds) {
      switch (evaluation.status) {
        case ThresholdStatus.exceeded:
        case ThresholdStatus.belowTarget:
          breached++;
        case ThresholdStatus.safe:
        case ThresholdStatus.targetAchieved:
          kept++;
        case ThresholdStatus.approaching:
          // Honest ambiguity: close to a boundary is neither a kept promise
          // nor a broken one. The report states it separately in the UI.
          break;
      }
    }

    final previousSpent = previousSummary.totalSpent;
    final spendChange = previousSpent.isZero
        ? (summary.totalSpent.isZero ? 0.0 : 1.0)
        : (summary.totalSpent - previousSpent).ratioOf(previousSpent);

    return MonthCloseReport(
      summary: summary,
      spendChange: spendChange,
      expenseCount: stats.count,
      averageExpense: stats.average,
      biggestExpense: stats.biggest,
      busiestWeekday: busiest.isEmpty ? null : busiest.first.key,
      thresholdsKept: kept,
      thresholdsBreached: breached,
    );
  }
}
