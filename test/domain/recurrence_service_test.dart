import 'package:budgetsense/core/constants/enums.dart';
import 'package:budgetsense/core/utils/money.dart';
import 'package:budgetsense/domain/entities/commitment_entities.dart';
import 'package:budgetsense/domain/services/recurrence_service.dart';
import 'package:flutter_test/flutter_test.dart';

RecurringPaymentEntity _payment({
  bool autoAdd = true,
  Frequency freq = Frequency.monthly,
  DateTime? due,
  DateTime? end,
}) {
  final now = DateTime(2026, 7, 1);
  return RecurringPaymentEntity(
    id: 'p1',
    name: 'Netflix',
    amount: const Money(49900),
    kind: PaymentKind.subscription,
    frequency: freq,
    startDate: now,
    nextDueDate: due ?? DateTime(2026, 7, 15),
    endDate: end,
    autoAddTransaction: autoAdd,
    createdAt: now,
    updatedAt: now,
  );
}

LoanEntity _loan() {
  final now = DateTime(2026, 1, 1);
  return LoanEntity(
    id: 'l1',
    name: 'Car',
    originalPrincipal: const Money(1000000),
    outstandingPrincipal: const Money(400000),
    emi: const Money(50000),
    frequency: Frequency.monthly,
    startDate: now,
    nextPaymentDate: DateTime(2026, 8, 1),
    totalPaid: const Money(600000),
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  const service = RecurrenceService();

  group('RecurrenceService.complete', () {
    test('creates a transaction when autoAdd is on and advances due date', () {
      final result = service.complete(_payment(), newTransactionId: 't1');
      expect(result.transaction, isNotNull);
      expect(result.transaction!.type, TransactionType.recurringPayment);
      expect(result.transaction!.amount.minorUnits, 49900);
      expect(result.transaction!.linkedPaymentId, 'p1');
      expect(result.updated.nextDueDate, DateTime(2026, 8, 15));
    });

    test('skips transaction when autoAdd is off', () {
      final result =
          service.complete(_payment(autoAdd: false), newTransactionId: 't1');
      expect(result.transaction, isNull);
      expect(result.updated.nextDueDate, DateTime(2026, 8, 15));
    });

    test('investments produce investment transactions', () {
      final sip = _payment().copyWith(kind: PaymentKind.sip);
      final result = service.complete(sip, newTransactionId: 't1');
      expect(result.transaction!.type, TransactionType.investment);
    });

    test('archives payment when advancing past its end date', () {
      final p = _payment(
        due: DateTime(2026, 7, 15),
        end: DateTime(2026, 8, 1),
      );
      final result = service.complete(p, newTransactionId: 't1');
      expect(result.updated.isArchived, isTrue);
    });

    test('paidAt controls the recorded transaction date, not the due date', () {
      // Paid early: three days before the scheduled due date.
      final early = service.complete(
        _payment(due: DateTime(2026, 7, 15)),
        newTransactionId: 't1',
        paidAt: DateTime(2026, 7, 12),
      );
      expect(early.transaction!.occurredAt, DateTime(2026, 7, 12));
      // The schedule still advances from its own due date, not from paidAt.
      expect(early.updated.nextDueDate, DateTime(2026, 8, 15));

      // Paid late: cleared ten days after an overdue due date.
      final late = service.complete(
        _payment(due: DateTime(2026, 7, 15)),
        newTransactionId: 't2',
        paidAt: DateTime(2026, 7, 25),
      );
      expect(late.transaction!.occurredAt, DateTime(2026, 7, 25));
      expect(late.updated.nextDueDate, DateTime(2026, 8, 15));

      // No paidAt given (e.g. the automatic catch-up path) still falls back
      // to the due date, exactly as before.
      final fallback = service.complete(_payment(due: DateTime(2026, 7, 15)),
          newTransactionId: 't3');
      expect(fallback.transaction!.occurredAt, DateTime(2026, 7, 15));
    });
  });

  group('RecurrenceService.payLoan', () {
    test('reduces outstanding, bumps total paid, advances date', () {
      final result = service.payLoan(_loan(), newTransactionId: 't1');
      expect(result.transaction.type, TransactionType.loanPayment);
      expect(result.transaction.amount.minorUnits, 50000);
      expect(result.updated.outstandingPrincipal.minorUnits, 350000);
      expect(result.updated.totalPaid.minorUnits, 650000);
      expect(result.updated.nextPaymentDate, DateTime(2026, 9, 1));
    });

    test('final installment pays only what is owed, never a full EMI', () {
      final almostPaid = _loan().copyWith(
        outstandingPrincipal: const Money(10000),
        totalPaid: const Money(990000),
      );
      final result = service.payLoan(almostPaid, newTransactionId: 't1');
      // Records the actual amount paid (10000), not the 50000 EMI.
      expect(result.transaction.amount, const Money(10000));
      expect(result.updated.outstandingPrincipal, Money.zero);
      expect(result.updated.totalPaid, const Money(1000000));
    });

    test('custom amount records a part-payment instead of the EMI', () {
      final result = service.payLoan(
        _loan(),
        newTransactionId: 't1',
        amount: const Money(20000),
      );
      expect(result.transaction.amount, const Money(20000));
      expect(result.updated.outstandingPrincipal.minorUnits, 380000);
      expect(result.updated.totalPaid.minorUnits, 620000);
    });

    test('custom amount is clamped to what is still owed', () {
      final almostPaid = _loan().copyWith(
        outstandingPrincipal: const Money(10000),
        totalPaid: const Money(990000),
      );
      final result = service.payLoan(
        almostPaid,
        newTransactionId: 't1',
        amount: const Money(50000), // more than owed
      );
      expect(result.transaction.amount, const Money(10000));
      expect(result.updated.outstandingPrincipal, Money.zero);
    });
  });

  group('RecurrenceService.catchUp', () {
    String Function() counter() {
      var n = 0;
      return () => 't${n++}';
    }

    test('posts every missed period and advances to the next cycle', () {
      final p = _payment(due: DateTime(2026, 5, 15));
      final result = service.catchUp(
        p,
        now: DateTime(2026, 7, 20),
        newId: counter(),
      );
      // May 15, Jun 15, Jul 15 are all due by Jul 20.
      expect(result.transactions, hasLength(3));
      expect(result.updated.nextDueDate, DateTime(2026, 8, 15));
    });

    test('does nothing for manual (non auto-add) payments', () {
      final p = _payment(autoAdd: false, due: DateTime(2026, 5, 15));
      final result = service.catchUp(
        p,
        now: DateTime(2026, 7, 20),
        newId: counter(),
      );
      expect(result.transactions, isEmpty);
      expect(result.updated.nextDueDate, DateTime(2026, 5, 15));
    });

    test('is idempotent: a second pass on the same day posts nothing', () {
      final first = service.catchUp(
        _payment(due: DateTime(2026, 5, 15)),
        now: DateTime(2026, 7, 20),
        newId: counter(),
      );
      final second = service.catchUp(
        first.updated,
        now: DateTime(2026, 7, 20),
        newId: counter(),
      );
      expect(second.transactions, isEmpty);
      expect(second.updated.nextDueDate, first.updated.nextDueDate);
    });

    test('stops and archives when it rolls past the end date', () {
      final p = _payment(
        due: DateTime(2026, 5, 15),
        end: DateTime(2026, 6, 20),
      );
      final result = service.catchUp(
        p,
        now: DateTime(2026, 7, 20),
        newId: counter(),
      );
      expect(result.updated.isArchived, isTrue);
    });
  });

  group('overdue / upcoming', () {
    final now = DateTime(2026, 7, 20);
    test('overdue detects past-due payments', () {
      final overdue = _payment(due: DateTime(2026, 7, 10));
      final list = service.overdue([overdue], now);
      expect(list, hasLength(1));
    });

    test('upcoming detects payments within window', () {
      final soon = _payment(due: DateTime(2026, 7, 22));
      final far = _payment(due: DateTime(2026, 9, 1));
      final list = service.upcoming([soon, far], now, days: 7);
      expect(list, hasLength(1));
      expect(list.first.nextDueDate, DateTime(2026, 7, 22));
    });
  });
}
