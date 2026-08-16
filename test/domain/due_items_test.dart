import 'package:budgetsense/core/constants/enums.dart';
import 'package:budgetsense/core/utils/money.dart';
import 'package:budgetsense/domain/entities/commitment_entities.dart';
import 'package:budgetsense/domain/services/due_items.dart';
import 'package:flutter_test/flutter_test.dart';

LoanEntity _loan({
  String id = 'l1',
  String name = 'Car loan',
  bool showInUpcoming = true,
  DateTime? nextPaymentDate,
  Money outstanding = const Money(500000),
  DateTime? archivedAt,
}) {
  final now = DateTime(2026, 1, 1);
  return LoanEntity(
    id: id,
    name: name,
    originalPrincipal: const Money(1000000),
    outstandingPrincipal: outstanding,
    emi: const Money(15000),
    frequency: Frequency.monthly,
    startDate: now,
    nextPaymentDate: nextPaymentDate,
    showInUpcoming: showInUpcoming,
    archivedAt: archivedAt,
    createdAt: now,
    updatedAt: now,
  );
}

RecurringPaymentEntity _payment({
  String id = 'p1',
  String name = 'Netflix',
  required DateTime due,
}) {
  final now = DateTime(2026, 1, 1);
  return RecurringPaymentEntity(
    id: id,
    name: name,
    amount: const Money(49900),
    kind: PaymentKind.subscription,
    frequency: Frequency.monthly,
    startDate: now,
    nextDueDate: due,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('buildDueItems', () {
    test('a loan only appears when the user opts in', () {
      final loan = _loan(
        showInUpcoming: false,
        nextPaymentDate: DateTime(2026, 2, 10),
      );
      expect(buildDueItems(payments: const [], loans: [loan]), isEmpty);

      final opted = loan.copyWith(showInUpcoming: true);
      expect(buildDueItems(payments: const [], loans: [opted]), hasLength(1));
    });

    test('merges both sources into one chronological list', () {
      final items = buildDueItems(
        payments: [
          _payment(id: 'p1', name: 'Netflix', due: DateTime(2026, 2, 15)),
          _payment(id: 'p2', name: 'Rent', due: DateTime(2026, 2, 1)),
        ],
        loans: [_loan(nextPaymentDate: DateTime(2026, 2, 5))],
      );

      expect(
        items.map((i) => i.name),
        ['Rent', 'Car loan', 'Netflix'],
        reason: 'a merged list is useless if it is not sorted by due date',
      );
    });

    test('a fully repaid loan drops out of the list', () {
      // Nothing is owed, so there is no commitment left to show. Without this
      // a cleared loan would linger forever as a phantom monthly due.
      final cleared = _loan(
        outstanding: Money.zero,
        nextPaymentDate: DateTime(2026, 2, 10),
      );
      expect(buildDueItems(payments: const [], loans: [cleared]), isEmpty);
    });

    test('an archived loan drops out of the list', () {
      final archived = _loan(
        nextPaymentDate: DateTime(2026, 2, 10),
        archivedAt: DateTime(2026, 1, 20),
      );
      expect(buildDueItems(payments: const [], loans: [archived]), isEmpty);
    });

    test('a loan with no next payment date is not schedulable', () {
      // The row reads dueDate via a non-null assertion, so an undated loan
      // reaching the list would crash the payments screen.
      final undated = _loan(nextPaymentDate: null);
      expect(undated.isSchedulable, isFalse);
      expect(buildDueItems(payments: const [], loans: [undated]), isEmpty);
    });

    test('loan items are tagged so the UI can offer Record EMI', () {
      final items = buildDueItems(
        payments: [_payment(due: DateTime(2026, 2, 1))],
        loans: [_loan(nextPaymentDate: DateTime(2026, 2, 5))],
      );
      expect(items.where((i) => i.isLoan).map((i) => i.name), ['Car loan']);
      expect(items.where((i) => !i.isLoan).map((i) => i.name), ['Netflix']);
    });
  });

  group('LoanEntity.showInUpcoming', () {
    test('defaults to off so existing loans are unaffected', () {
      final now = DateTime(2026, 1, 1);
      final loan = LoanEntity(
        id: 'l',
        name: 'Home',
        originalPrincipal: const Money(100),
        outstandingPrincipal: const Money(100),
        emi: const Money(10),
        frequency: Frequency.monthly,
        startDate: now,
        createdAt: now,
        updatedAt: now,
      );
      expect(loan.showInUpcoming, isFalse);
    });

    test('survives a copyWith that does not mention it', () {
      final loan = _loan(nextPaymentDate: DateTime(2026, 2, 10));
      expect(loan.copyWith(name: 'Renamed').showInUpcoming, isTrue);
    });
  });
}
