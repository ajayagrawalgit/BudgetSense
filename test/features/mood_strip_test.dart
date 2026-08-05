import 'package:budgetsense/core/constants/enums.dart';
import 'package:budgetsense/core/utils/money.dart';
import 'package:budgetsense/domain/entities/transaction_entity.dart';
import 'package:budgetsense/domain/services/threshold_service.dart';
import 'package:budgetsense/features/common/confetti_overlay.dart';
import 'package:budgetsense/features/dashboard/mood_strip.dart';
import 'package:flutter_test/flutter_test.dart';

TransactionEntity _t(TransactionType type, DateTime when) {
  return TransactionEntity(
    id: 'id-${when.microsecondsSinceEpoch}-${type.index}',
    type: type,
    name: 'x',
    amount: const Money(10000),
    occurredAt: when,
    createdAt: when,
    updatedAt: when,
  );
}

void main() {
  group('classifyWeather', () {
    test('negative balance is always drizzle', () {
      expect(
        classifyWeather(balancePositive: false, savingsRate: 0.9),
        WalletWeather.drizzle,
      );
    });
    test('positive with strong saving is sunny', () {
      expect(
        classifyWeather(balancePositive: true, savingsRate: 0.25),
        WalletWeather.sunny,
      );
    });
    test('positive with modest saving is fair, tiny saving is cloudy', () {
      expect(
        classifyWeather(balancePositive: true, savingsRate: 0.10),
        WalletWeather.fair,
      );
      expect(
        classifyWeather(balancePositive: true, savingsRate: 0.01),
        WalletWeather.cloudy,
      );
    });
  });

  group('noSpendDaysThisMonth', () {
    test('counts days with no expense up to today', () {
      final now = DateTime(2026, 7, 5, 12);
      // Spent on the 2nd and 4th; income/investment do not count as spend.
      final txns = [
        _t(TransactionType.expense, DateTime(2026, 7, 2)),
        _t(TransactionType.income, DateTime(2026, 7, 3)),
        _t(TransactionType.investment, DateTime(2026, 7, 4)),
        _t(TransactionType.expense, DateTime(2026, 7, 4)),
      ];
      // Days 1..5, spent on 2 and 4 -> clean = 1,3,5 = 3.
      expect(noSpendDaysThisMonth(txns, now), 3);
    });

    test('empty month returns days elapsed', () {
      final now = DateTime(2026, 7, 3);
      expect(noSpendDaysThisMonth(const [], now), 3);
    });
  });

  group('savingsTarget', () {
    test('defaults to 20% with no rules', () {
      expect(savingsTarget(const []), 0.20);
    });
    test('uses the first enabled min-percentage rule', () {
      const rule = ThresholdRule(
        id: 'r',
        label: 'Save at least 30%',
        type: ThresholdType.minPercentage,
        value: 30,
        warningPercent: 0.8,
        criticalPercent: 0.95,
      );
      expect(savingsTarget([rule]), 0.30);
    });
  });

  group('celebrationVariant', () {
    test('beating last month wins over everything', () {
      expect(
        celebrationVariant(beatLastMonth: true, loanCleared: true, month: 10),
        ConfettiVariant.firework,
      );
    });
    test('cleared loan yields coins', () {
      expect(
        celebrationVariant(beatLastMonth: false, loanCleared: true, month: 3),
        ConfettiVariant.coins,
      );
    });
    test('autumn yields leaves, otherwise confetti', () {
      expect(
        celebrationVariant(beatLastMonth: false, loanCleared: false, month: 10),
        ConfettiVariant.leaves,
      );
      expect(
        celebrationVariant(beatLastMonth: false, loanCleared: false, month: 4),
        ConfettiVariant.confetti,
      );
    });
  });
}
