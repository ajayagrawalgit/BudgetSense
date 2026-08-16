import 'package:budgetsense/core/constants/enums.dart';
import 'package:budgetsense/core/utils/money.dart';
import 'package:budgetsense/core/utils/quiet_hours.dart';
import 'package:budgetsense/domain/services/threshold_alert_planner.dart';
import 'package:budgetsense/domain/services/threshold_service.dart';
import 'package:flutter_test/flutter_test.dart';

ThresholdEvaluation _evaluation(ThresholdStatus status, {String id = 'rule'}) {
  return ThresholdEvaluation(
    rule: ThresholdRule(
      id: id,
      label: 'Wants',
      type: ThresholdType.maxAmount,
      value: 10000,
      warningPercent: .8,
      criticalPercent: .95,
    ),
    status: status,
    actual: const Money(9000),
    limit: const Money(10000),
    usedFraction: .9,
  );
}

void main() {
  const planner = ThresholdAlertPlanner();
  final now = DateTime(2026, 8, 13, 12);

  test('alerts once at nearing, then once on a real escalation', () {
    final nearing = planner.plan(
      [_evaluation(ThresholdStatus.approaching)],
      monthKey: '2026-08',
      alreadyAlerted: const {},
      now: now,
    );
    expect(nearing, hasLength(1));
    expect(nearing.single.level, AlertLevel.nearing);

    final breach = planner.plan(
      [_evaluation(ThresholdStatus.exceeded)],
      monthKey: '2026-08',
      alreadyAlerted: {nearing.single.dedupeKey},
      now: now,
    );
    expect(breach, hasLength(1));
    expect(breach.single.level, AlertLevel.breached);

    final regression = planner.plan(
      [_evaluation(ThresholdStatus.approaching)],
      monthKey: '2026-08',
      alreadyAlerted: {
        nearing.single.dedupeKey,
        breach.single.dedupeKey,
      },
      now: now,
    );
    expect(regression, isEmpty);
  });

  test('never alerts for safe or below-target states', () {
    for (final status in [
      ThresholdStatus.safe,
      ThresholdStatus.belowTarget,
    ]) {
      expect(
        planner.plan(
          [_evaluation(status)],
          monthKey: '2026-08',
          alreadyAlerted: const {},
          now: now,
        ),
        isEmpty,
      );
    }
  });

  test('deduplicates corrupted duplicate evaluations in one pass', () {
    final alerts = planner.plan(
      [
        _evaluation(ThresholdStatus.approaching),
        _evaluation(ThresholdStatus.approaching),
      ],
      monthKey: '2026-08',
      alreadyAlerted: const {},
      now: now,
    );
    expect(alerts, hasLength(1));
  });

  test('quiet hours wrap midnight and use an exclusive end boundary', () {
    const quiet = QuietHours(startMinute: 22 * 60, endMinute: 7 * 60);
    expect(quiet.contains(DateTime(2026, 8, 13, 22)), isTrue);
    expect(quiet.contains(DateTime(2026, 8, 14, 6, 59)), isTrue);
    expect(quiet.contains(DateTime(2026, 8, 14, 7)), isFalse);
    expect(quiet.contains(DateTime(2026, 8, 13, 21, 59)), isFalse);
  });

  test('a new financial month naturally rearms a rule', () {
    final august = planner.plan(
      [_evaluation(ThresholdStatus.exceeded)],
      monthKey: '2026-08',
      alreadyAlerted: const {},
      now: now,
    );
    final september = planner.plan(
      [_evaluation(ThresholdStatus.exceeded)],
      monthKey: '2026-09',
      alreadyAlerted: {august.single.dedupeKey},
      now: now,
    );
    expect(september, hasLength(1));
  });
}
