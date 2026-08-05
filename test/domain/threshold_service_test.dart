import 'package:budgetsense/core/constants/enums.dart';
import 'package:budgetsense/core/utils/money.dart';
import 'package:budgetsense/domain/services/threshold_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = ThresholdService();
  const income = Money(1000000); // 10,000.00

  group('ThresholdService - max percentage rules', () {
    const rule = ThresholdRule(
      id: 'r',
      label: 'Wants under 10%',
      type: ThresholdType.maxPercentage,
      value: 10,
      warningPercent: 0.8,
      criticalPercent: 0.95,
    );

    test('well under the limit is safe', () {
      final e = service.evaluate(
        rule,
        actual: const Money(50000),
        monthlyIncome: income,
      ); // 5% used of 10%
      expect(e.limit.minorUnits, 100000); // 10% of income
      expect(e.status, ThresholdStatus.safe);
    });

    test('near the limit warns', () {
      final e = service.evaluate(
        rule,
        actual: const Money(90000),
        monthlyIncome: income,
      ); // 90% of limit
      expect(e.status, ThresholdStatus.approaching);
    });

    test('over the limit is exceeded', () {
      final e = service.evaluate(
        rule,
        actual: const Money(120000),
        monthlyIncome: income,
      );
      expect(e.status, ThresholdStatus.exceeded);
      expect(e.usedFraction, greaterThan(1.0));
    });
  });

  group('ThresholdService - min percentage rules', () {
    const rule = ThresholdRule(
      id: 'inv',
      label: 'Invest at least 35%',
      type: ThresholdType.minPercentage,
      value: 35,
      warningPercent: 0.85,
      criticalPercent: 1.0,
    );

    test('below target when investing too little', () {
      final e = service.evaluate(
        rule,
        actual: const Money(100000),
        monthlyIncome: income,
      ); // ~28% of 35% target
      expect(e.status, ThresholdStatus.belowTarget);
    });

    test('target achieved when at or above', () {
      final e = service.evaluate(
        rule,
        actual: const Money(350000),
        monthlyIncome: income,
      );
      expect(e.status, ThresholdStatus.targetAchieved);
    });
  });

  group('ThresholdService - fixed amount rules', () {
    test('max amount limit resolves without income', () {
      const rule = ThresholdRule(
        id: 'cap',
        label: 'Coffee under 50',
        type: ThresholdType.maxAmount,
        value: 5000, // minor units
        warningPercent: 0.8,
        criticalPercent: 0.95,
      );
      final e = service.evaluate(
        rule,
        actual: const Money(6000),
        monthlyIncome: Money.zero,
      );
      expect(e.limit.minorUnits, 5000);
      expect(e.status, ThresholdStatus.exceeded);
    });
  });

  test('suggested defaults are category-agnostic app-level thresholds', () {
    final defaults = SuggestedThresholds.defaults();
    // Only app-level scopes remain: no rule references any specific category,
    // so the suggestions make sense whatever categories a user creates.
    expect(defaults.length, 2);

    final byScope = {for (final r in defaults) r.scopeKey!: r};
    expect(
      byScope.keys,
      containsAll(<String>['investments', 'unallocated']),
    );

    // These numbers are the contract.
    expect(byScope['unallocated']!.value, 20);
    expect(byScope['unallocated']!.type, ThresholdType.maxPercentage);
    expect(byScope['investments']!.value, 15);
    expect(byScope['investments']!.type, ThresholdType.minPercentage);

    // The investing target stays gentle and achievable.
    expect(byScope['investments']!.value, lessThanOrEqualTo(20));

    // Belt and braces: none of the seeded suggestions name a category concept.
    for (final r in defaults) {
      expect(
        const ['needs', 'wants', 'responsibilities'].contains(r.scopeKey),
        isFalse,
      );
    }
  });
}
