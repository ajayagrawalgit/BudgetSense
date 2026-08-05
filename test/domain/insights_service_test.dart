import 'package:budgetsense/core/constants/enums.dart';
import 'package:budgetsense/core/utils/financial_calendar.dart';
import 'package:budgetsense/core/utils/money.dart';
import 'package:budgetsense/domain/entities/transaction_entity.dart';
import 'package:budgetsense/domain/services/insights_service.dart';
import 'package:flutter_test/flutter_test.dart';

TransactionEntity _t(TransactionType type, int minor, DateTime when) {
  return TransactionEntity(
    id: 'id-${when.microsecondsSinceEpoch}-$minor',
    type: type,
    name: 'x',
    amount: Money(minor),
    occurredAt: when,
    createdAt: when,
    updatedAt: when,
  );
}

void main() {
  const service = InsightsService();
  const cal = FinancialCalendar(monthStartDay: 1);

  group('InsightsService.trend', () {
    test('aggregates per month and sorts oldest to newest', () {
      final txns = [
        _t(TransactionType.income, 500000, DateTime(2026, 5, 3)),
        _t(TransactionType.expense, 20000, DateTime(2026, 5, 10)),
        _t(TransactionType.expense, 30000, DateTime(2026, 6, 4)),
        _t(TransactionType.investment, 100000, DateTime(2026, 6, 20)),
      ];
      final points = service.trend(txns, calendar: cal);
      expect(points, hasLength(2));
      expect(points.first.monthKey, '2026-05');
      expect(points.first.income.minorUnits, 500000);
      expect(points.first.spent.minorUnits, 20000);
      expect(points.last.monthKey, '2026-06');
      expect(points.last.invested.minorUnits, 100000);
    });

    test('limits to the requested number of months', () {
      final txns = [
        for (var m = 1; m <= 8; m++)
          _t(TransactionType.expense, 1000 * m, DateTime(2026, m, 5)),
      ];
      final points = service.trend(txns, calendar: cal, months: 3);
      expect(points, hasLength(3));
      expect(points.last.monthKey, '2026-08');
    });
  });

  group('InsightsService.averageDailySpend', () {
    test('divides spend across inclusive days', () {
      final range = DateRange(DateTime(2026, 7, 1), DateTime(2026, 7, 10));
      final avg = service.averageDailySpend(const Money(100000), range);
      expect(avg.minorUnits, 10000); // 10 days inclusive
    });
  });

  group('InsightsService.projectedMonthEndBalance', () {
    test('extrapolates spend at the current daily rate', () {
      final range = DateRange(DateTime(2026, 7, 1), DateTime(2026, 7, 31));
      final projected = service.projectedMonthEndBalance(
        income: const Money(1000000),
        spentSoFar: const Money(100000), // 10 days in -> ~10k/day
        invested: const Money(0),
        monthRange: range,
        now: DateTime(2026, 7, 10),
      );
      // ~10k/day * 31 days = ~310k projected spend -> ~690k balance.
      expect(projected.minorUnits, closeTo(690000, 5000));
    });
  });

  group('InsightsService.momSpendChange', () {
    test('computes fractional change vs previous month', () {
      final points = [
        const MonthPoint(
          monthKey: '2026-05',
          income: Money(0),
          spent: Money(100000),
          invested: Money(0),
        ),
        const MonthPoint(
          monthKey: '2026-06',
          income: Money(0),
          spent: Money(150000),
          invested: Money(0),
        ),
      ];
      expect(service.momSpendChange(points), closeTo(0.5, 0.0001));
    });
  });

  group('InsightsService.spendByWeekday', () {
    test('sums spend per weekday, ignoring income and investment', () {
      final mon = DateTime(2026, 7, 6); // a Monday
      final txns = [
        _t(TransactionType.expense, 10000, mon),
        _t(TransactionType.expense, 5000, mon),
        _t(TransactionType.income, 999999, mon),
        _t(TransactionType.investment, 5000, mon),
      ];
      final byDay = service.spendByWeekday(txns);
      expect(byDay[DateTime.monday]!.minorUnits, 15000);
      expect(byDay.containsKey(DateTime.tuesday), isFalse);
    });
  });

  group('InsightsService.expenseStats', () {
    test('counts, averages and finds the biggest spend', () {
      final d = DateTime(2026, 7, 6);
      final stats = service.expenseStats([
        _t(TransactionType.expense, 10000, d),
        _t(TransactionType.expense, 30000, d),
        _t(TransactionType.income, 500000, d),
      ]);
      expect(stats.count, 2);
      expect(stats.average.minorUnits, 20000);
      expect(stats.biggest!.amount.minorUnits, 30000);
    });

    test('is empty-safe', () {
      final stats = service.expenseStats(const []);
      expect(stats.count, 0);
      expect(stats.biggest, isNull);
    });
  });

  group('InsightsService.incomeByType', () {
    test('groups income by source, defaulting to other', () {
      final d = DateTime(2026, 7, 6);
      final salary = _t(TransactionType.income, 500000, d)
          .copyWith(incomeType: IncomeType.salary);
      final misc = _t(TransactionType.income, 20000, d); // null -> other
      final byType = service.incomeByType([
        salary,
        misc,
        _t(TransactionType.expense, 100, d),
      ]);
      expect(byType[IncomeType.salary]!.minorUnits, 500000);
      expect(byType[IncomeType.other]!.minorUnits, 20000);
    });
  });
}
