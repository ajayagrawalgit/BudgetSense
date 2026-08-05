import 'package:budgetsense/core/constants/enums.dart';
import 'package:budgetsense/core/utils/money.dart';
import 'package:budgetsense/domain/entities/transaction_entity.dart';
import 'package:budgetsense/domain/services/summary_service.dart';
import 'package:flutter_test/flutter_test.dart';

TransactionEntity _txn(
  TransactionType type,
  int minor, {
  String? categoryId,
}) {
  final now = DateTime(2026, 7, 10);
  return TransactionEntity(
    id: 'id-$type-$minor-$categoryId',
    type: type,
    name: 'test',
    amount: Money(minor),
    occurredAt: now,
    createdAt: now,
    updatedAt: now,
    categoryId: categoryId,
  );
}

void main() {
  const service = SummaryService();

  group('SummaryService', () {
    test('aggregates income, spend, investments and per-category spend', () {
      final txns = [
        _txn(TransactionType.income, 500000),
        _txn(TransactionType.expense, 10000, categoryId: 'groceries'),
        _txn(TransactionType.expense, 5000, categoryId: 'fun'),
        _txn(TransactionType.loanPayment, 20000, categoryId: 'emi'),
        _txn(TransactionType.investment, 100000),
      ];

      final s = service.summarize(
        txns,
        investmentTreatment: InvestmentTreatment.separate,
      );

      expect(s.totalGains.minorUnits, 500000);
      // spent = expenses + loan payment (investments excluded)
      expect(s.totalSpent.minorUnits, 35000);
      expect(s.totalInvestments.minorUnits, 100000);
      expect(s.totalLoanPayments.minorUnits, 20000);
      // Fully dynamic: spend is tracked per whatever category id was used.
      expect(s.perCategory['groceries']!.minorUnits, 10000);
      expect(s.perCategory['fun']!.minorUnits, 5000);
      expect(s.perCategory['emi']!.minorUnits, 20000);
    });

    test('per-category sums multiple transactions in the same category', () {
      final s = service.summarize(
        [
          _txn(TransactionType.expense, 3000, categoryId: 'food'),
          _txn(TransactionType.expense, 4500, categoryId: 'food'),
          _txn(TransactionType.expense, 1000, categoryId: 'travel'),
        ],
        investmentTreatment: InvestmentTreatment.separate,
      );
      expect(s.perCategory['food']!.minorUnits, 7500);
      expect(s.perCategory['travel']!.minorUnits, 1000);
    });

    test('investment treatment "separate" excludes investments from balance',
        () {
      final txns = [
        _txn(TransactionType.income, 100000),
        _txn(TransactionType.investment, 30000),
      ];
      final s = service.summarize(
        txns,
        investmentTreatment: InvestmentTreatment.separate,
      );
      // separate: balance = gains - spent (no investment subtraction)
      expect(s.totalBalance.minorUnits, 100000);
      // but savings still nets out investments
      expect(s.totalSavings.minorUnits, 70000);
    });

    test('investment treatment "savings" subtracts investments from balance',
        () {
      final txns = [
        _txn(TransactionType.income, 100000),
        _txn(TransactionType.investment, 30000),
      ];
      final s = service.summarize(
        txns,
        investmentTreatment: InvestmentTreatment.savings,
      );
      expect(s.totalBalance.minorUnits, 70000);
    });

    test('ignores archived transactions', () {
      final now = DateTime(2026, 7, 1);
      final archived = TransactionEntity(
        id: 'a',
        type: TransactionType.expense,
        name: 'old',
        amount: const Money(9999),
        occurredAt: now,
        createdAt: now,
        updatedAt: now,
        archivedAt: now,
      );
      final s = service.summarize(
        [archived, _txn(TransactionType.income, 5000)],
        investmentTreatment: InvestmentTreatment.separate,
      );
      expect(s.totalSpent, Money.zero);
      expect(s.totalGains.minorUnits, 5000);
    });

    test('savings and investment rates are fractions of income', () {
      final s = service.summarize(
        [
          _txn(TransactionType.income, 100000),
          _txn(TransactionType.investment, 35000),
          _txn(TransactionType.expense, 25000, categoryId: 'groceries'),
        ],
        investmentTreatment: InvestmentTreatment.separate,
      );
      expect(s.investmentRate, closeTo(0.35, 0.0001));
      expect(s.savingsRate, closeTo(0.40, 0.0001)); // (100k-25k-35k)/100k
    });
  });

  group('MonthlySummary.positiveNote', () {
    MonthlySummary summarize(List<TransactionEntity> txns) => service.summarize(
          txns,
          investmentTreatment: InvestmentTreatment.savings,
        );

    test('celebrates keeping more than half of income', () {
      final s = summarize([
        _txn(TransactionType.income, 100000),
        _txn(TransactionType.expense, 20000),
      ]);
      expect(
        s.positiveNote,
        "You saved more than you spent this month. That's a good feeling.",
      );
    });

    test('acknowledges a solid-but-not-huge saving share', () {
      final s = summarize([
        _txn(TransactionType.income, 100000),
        _txn(TransactionType.expense, 60000),
      ]);
      expect(
        s.positiveNote,
        'A solid share of this month stayed with you. Nicely done.',
      );
    });

    test('recognises an investment-heavy month', () {
      final s = summarize([
        _txn(TransactionType.income, 100000),
        _txn(TransactionType.expense, 70000),
        _txn(TransactionType.investment, 25000),
      ]);
      expect(
        s.positiveNote,
        'A good chunk went into investments this month. '
        'Future you says thanks.',
      );
    });

    test('gives a gentle default when merely net-positive', () {
      final s = summarize([
        _txn(TransactionType.income, 100000),
        _txn(TransactionType.expense, 92000),
        _txn(TransactionType.investment, 3000),
      ]);
      expect(
          s.positiveNote, 'You ended the month in the green. Nicely balanced.');
    });

    test('stays silent on a net-negative month', () {
      final s = summarize([
        _txn(TransactionType.income, 50000),
        _txn(TransactionType.expense, 80000),
      ]);
      expect(s.positiveNote, isNull);
    });

    test('stays silent with no income', () {
      final s = summarize([_txn(TransactionType.expense, 5000)]);
      expect(s.positiveNote, isNull);
    });

    test('stays silent when the month exactly breaks even', () {
      final s = summarize([
        _txn(TransactionType.income, 50000),
        _txn(TransactionType.expense, 50000),
      ]);
      expect(s.positiveNote, isNull);
    });
  });
}
