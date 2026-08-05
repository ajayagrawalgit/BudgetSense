import 'package:budgetsense/core/constants/enums.dart';
import 'package:budgetsense/core/utils/money.dart';
import 'package:budgetsense/domain/entities/commitment_entities.dart';
import 'package:budgetsense/features/widgets/widget_sync.dart';
import 'package:flutter_test/flutter_test.dart';

RecurringPaymentEntity _payment(String name, int minor, DateTime due) {
  final now = DateTime(2026, 1, 1);
  return RecurringPaymentEntity(
    id: name,
    name: name,
    amount: Money(minor),
    kind: PaymentKind.subscription,
    frequency: Frequency.monthly,
    startDate: now,
    nextDueDate: due,
    createdAt: now,
    updatedAt: now,
  );
}

LoanEntity _loan(String name, int emi, DateTime? due) {
  final now = DateTime(2026, 1, 1);
  return LoanEntity(
    id: name,
    name: name,
    originalPrincipal: const Money(1000000),
    outstandingPrincipal: const Money(400000),
    emi: Money(emi),
    frequency: Frequency.monthly,
    startDate: now,
    nextPaymentDate: due,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('soonestDue', () {
    test('returns null when nothing is scheduled', () {
      expect(soonestDue(const [], const []), isNull);
    });

    test('picks the earliest across payments and loans', () {
      final result = soonestDue(
        [_payment('Netflix', 49900, DateTime(2026, 7, 20))],
        [_loan('Car', 50000, DateTime(2026, 7, 10))],
      );
      expect(result, isNotNull);
      expect(result!.name, 'Car');
      expect(result.amount, const Money(50000));
      expect(result.due, DateTime(2026, 7, 10));
    });

    test('ignores archived commitments and null loan dates', () {
      final result = soonestDue(
        [_payment('Rent', 100000, DateTime(2026, 7, 5))],
        [_loan('NoDate', 50000, null)],
      );
      expect(result!.name, 'Rent');
    });
  });

  group('relativePercents', () {
    test('scales to the largest value', () {
      expect(relativePercents([50, 100, 25, 0]), [50, 100, 25, 0]);
    });

    test('all zeros stay zero (no divide by zero)', () {
      expect(relativePercents([0, 0, 0, 0]), [0, 0, 0, 0]);
    });
  });
}
