import 'package:budgetsense/core/constants/enums.dart';
import 'package:budgetsense/core/utils/money.dart';
import 'package:budgetsense/domain/entities/transaction_entity.dart';
import 'package:budgetsense/domain/services/month_close_service.dart';
import 'package:budgetsense/domain/services/summary_service.dart';
import 'package:budgetsense/domain/services/threshold_service.dart';
import 'package:flutter_test/flutter_test.dart';

TransactionEntity _txn(TransactionType type, int amount, DateTime date) =>
    TransactionEntity(
      id: '${type.name}-${date.microsecondsSinceEpoch}-$amount',
      type: type,
      name: amount == 30000 ? 'Laptop repair' : 'Entry',
      amount: Money(amount),
      occurredAt: date,
      createdAt: date,
      updatedAt: date,
    );

MonthlySummary _summary(int income, int spent) => MonthlySummary(
      totalGains: Money(income),
      totalSpent: Money(spent),
      totalInvestments: Money.zero,
      totalLoanPayments: Money.zero,
      perCategory: const {},
      investmentTreatment: InvestmentTreatment.separate,
    );

ThresholdEvaluation _threshold(ThresholdStatus status) => ThresholdEvaluation(
      rule: const ThresholdRule(
        id: 'wants',
        label: 'Wants',
        type: ThresholdType.maxAmount,
        value: 100000,
        warningPercent: .8,
        criticalPercent: .95,
      ),
      status: status,
      actual: const Money(90000),
      limit: const Money(100000),
      usedFraction: .9,
    );

void main() {
  const service = MonthCloseService();

  test('assembles an honest reflection from existing primitives', () {
    final monday = DateTime(2026, 7, 6);
    final report = service.build(
      summary: _summary(100000, 50000),
      previousSummary: _summary(100000, 40000),
      transactions: [
        _txn(TransactionType.expense, 20000, monday),
        _txn(TransactionType.expense, 30000, monday),
        _txn(TransactionType.income, 100000, monday),
      ],
      thresholds: [
        _threshold(ThresholdStatus.safe),
        _threshold(ThresholdStatus.exceeded),
        _threshold(ThresholdStatus.approaching),
      ],
    );

    expect(report.expenseCount, 2);
    expect(report.averageExpense, const Money(25000));
    expect(report.biggestExpense!.name, 'Laptop repair');
    expect(report.busiestWeekday, DateTime.monday);
    expect(report.spendChange, closeTo(.25, .0001));
    expect(report.thresholdsKept, 1);
    expect(report.thresholdsBreached, 1);
    expect(report.hasActivity, isTrue);
  });

  test('is empty-safe and never invents a spending rhythm', () {
    final report = service.build(
      summary: _summary(0, 0),
      previousSummary: _summary(0, 0),
      transactions: const [],
      thresholds: const [],
    );
    expect(report.hasActivity, isFalse);
    expect(report.busiestWeekday, isNull);
    expect(report.biggestExpense, isNull);
    expect(report.spendChange, 0);
  });
}
