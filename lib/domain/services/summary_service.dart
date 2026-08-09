import '../../core/constants/enums.dart';
import '../../core/utils/money.dart';
import '../entities/transaction_entity.dart';

/// The computed financial picture for one month (Section 10).
///
/// Immutable value object - the UI reads it, never mutates it.
class MonthlySummary {
  const MonthlySummary({
    required this.totalGains,
    required this.totalSpent,
    required this.totalInvestments,
    required this.totalLoanPayments,
    required this.perCategory,
    required this.investmentTreatment,
  });

  final Money totalGains; // all income
  final Money totalSpent; // all outflows except investments
  final Money totalInvestments;
  final Money totalLoanPayments;

  /// Spend per category id (outflows only).
  final Map<String, Money> perCategory;

  final InvestmentTreatment investmentTreatment;

  /// Total Balance = Gains - Spent - Investments (spec formula), but the
  /// treatment of investments is configurable.
  Money get totalBalance {
    switch (investmentTreatment) {
      case InvestmentTreatment.spending:
      case InvestmentTreatment.savings:
        // Both reduce the wallet: money spent, or money moved into investments,
        // has left the available balance either way.
        return totalGains - totalSpent - totalInvestments;
      case InvestmentTreatment.separate:
      case InvestmentTreatment.custom:
        // Report balance before investment allocation. A custom-labeled
        // bucket is still tracked separately, financially identical to
        // "separate", the user has just renamed it.
        return totalGains - totalSpent;
    }
  }

  /// Money not yet spent or invested - the "remaining" figure.
  Money get totalSavings => totalGains - totalSpent - totalInvestments;

  double get savingsRate => totalSavings.ratioOf(totalGains).clamp(0.0, 1.0);
  double get investmentRate =>
      totalInvestments.ratioOf(totalGains).clamp(0.0, 1.0);

  /// A gentle, optional line of encouragement for a good month. Null when there
  /// is nothing to celebrate yet, so the UI simply shows nothing, mirroring how
  /// the "spent more than earned" line only appears when it applies. Wording is
  /// kept honest against the actual ratios so it never over-claims.
  String? get positiveNote {
    // Need real income before praising any ratio against it.
    if (totalGains.minorUnits <= 0) return null;
    // Only celebrate a month that genuinely ended in the black.
    if (totalBalance.isNegative || totalBalance.minorUnits == 0) return null;

    if (savingsRate >= 0.5) {
      return "You saved more than you spent this month. That's a good feeling.";
    }
    if (savingsRate >= 0.25) {
      return 'A solid share of this month stayed with you. Nicely done.';
    }
    if (investmentRate >= 0.2) {
      return 'A good chunk went into investments this month. '
          'Future you says thanks.';
    }
    return 'You ended the month in the green. Nicely balanced.';
  }
}

/// Pure, dependency-free service that turns a list of transactions into a
/// [MonthlySummary]. No Flutter, no database - trivially unit-testable.
class SummaryService {
  const SummaryService();

  /// [transactions] should already be filtered to the target month and
  /// exclude archived rows. Spend is tracked per category id via [perCategory];
  /// there are no fixed classification buckets, so every category the user
  /// defines is treated equally and dynamically.
  MonthlySummary summarize(
    List<TransactionEntity> transactions, {
    required InvestmentTreatment investmentTreatment,
  }) {
    final income = <Money>[];
    final investments = <Money>[];
    final loanPayments = <Money>[];
    final spent = <Money>[];
    final perCategory = <String, Money>{};

    for (final t in transactions) {
      if (t.isArchived) continue;
      switch (t.type) {
        case TransactionType.income:
          income.add(t.amount);
        case TransactionType.investment:
          investments.add(t.amount);
        case TransactionType.loanPayment:
          loanPayments.add(t.amount);
          spent.add(t.amount);
        case TransactionType.expense:
        case TransactionType.recurringPayment:
        case TransactionType.custom:
          spent.add(t.amount);
      }

      if (t.isOutflow && t.type != TransactionType.investment) {
        if (t.categoryId != null) {
          perCategory[t.categoryId!] =
              (perCategory[t.categoryId!] ?? Money.zero) + t.amount;
        }
      }
    }

    return MonthlySummary(
      totalGains: sumMoney(income),
      totalSpent: sumMoney(spent),
      totalInvestments: sumMoney(investments),
      totalLoanPayments: sumMoney(loanPayments),
      perCategory: perCategory,
      investmentTreatment: investmentTreatment,
    );
  }
}
