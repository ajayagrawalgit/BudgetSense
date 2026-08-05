import '../../core/constants/enums.dart';
import '../../core/utils/financial_calendar.dart';
import '../../core/utils/money.dart';
import '../entities/commitment_entities.dart';
import '../entities/transaction_entity.dart';

/// Pure logic for recurring payments & loans (Section 7 & 9): computing the
/// next due date, deciding what's overdue/upcoming, and generating the
/// transaction that a completed payment optionally creates. No Flutter, no DB.
class RecurrenceService {
  const RecurrenceService();

  /// Advance a payment's [RecurringPaymentEntity.nextDueDate] by one cycle.
  DateTime advance(RecurringPaymentEntity p) => nextOccurrence(
        p.nextDueDate,
        p.frequency,
        customIntervalDays: p.customIntervalDays,
      );

  /// Marks a payment as completed for its current due date. Returns the
  /// (optional) transaction to persist and the payment with its due date
  /// advanced to the next cycle. Honors [RecurringPaymentEntity.endDate].
  ({TransactionEntity? transaction, RecurringPaymentEntity updated}) complete(
    RecurringPaymentEntity p, {
    required String newTransactionId,
    DateTime? paidAt,
  }) {
    final when = paidAt ?? p.nextDueDate;
    final now = DateTime.now();

    TransactionEntity? txn;
    if (p.autoAddTransaction) {
      txn = TransactionEntity(
        id: newTransactionId,
        type: p.isInvestment
            ? TransactionType.investment
            : TransactionType.recurringPayment,
        name: p.name,
        amount: p.amount,
        occurredAt: when,
        createdAt: now,
        updatedAt: now,
        categoryId: p.categoryId,
        accountId: p.accountId,
        notes: p.notes,
        linkedPaymentId: p.id,
      );
    }

    final next = advance(p);
    final ended = p.endDate != null && next.isAfter(p.endDate!);

    return (
      transaction: txn,
      updated: p.copyWith(
        nextDueDate: next,
        updatedAt: now,
        archivedAt: ended ? now : null,
      ),
    );
  }

  /// Records a loan payment: reduces outstanding principal, bumps total paid,
  /// advances the next payment date, and produces a loan-payment transaction.
  ///
  /// Pass [amount] to record a custom installment (e.g. a part-payment or a
  /// lump sum); when omitted the loan's EMI is used. Either way the payment is
  /// clamped to what is still owed so we never overstate spend or total paid.
  ({TransactionEntity transaction, LoanEntity updated}) payLoan(
    LoanEntity loan, {
    required String newTransactionId,
    DateTime? paidAt,
    Money? amount,
  }) {
    final when = paidAt ?? loan.nextPaymentDate ?? DateTime.now();
    final now = DateTime.now();

    // The installment is only ever as large as what is still owed, so we never
    // record paying more than the outstanding principal (which would overstate
    // both this month's spend and the loan's total paid). A custom [amount]
    // (when given) is likewise capped at the outstanding balance.
    final owed = loan.outstandingPrincipal;
    final requested = amount ?? loan.emi;
    final payment = owed.minorUnits < requested.minorUnits ? owed : requested;
    final clamped = (owed - payment).isNegative ? Money.zero : owed - payment;

    final next = loan.nextPaymentDate == null
        ? null
        : nextOccurrence(loan.nextPaymentDate!, loan.frequency);

    final txn = TransactionEntity(
      id: newTransactionId,
      type: TransactionType.loanPayment,
      name: '${loan.name} payment',
      amount: payment,
      occurredAt: when,
      createdAt: now,
      updatedAt: now,
      notes: loan.notes,
      linkedLoanId: loan.id,
    );

    return (
      transaction: txn,
      updated: loan.copyWith(
        outstandingPrincipal: clamped,
        totalPaid: loan.totalPaid + payment,
        nextPaymentDate: next,
        updatedAt: now,
      ),
    );
  }

  /// Auto-rolls a recurring payment forward to the present.
  ///
  /// This is what makes a yearly/monthly/weekly commitment "recreate itself":
  /// for every period whose due date has already arrived (due today or earlier)
  /// it posts that period's transaction and advances to the next cycle, so the
  /// list only ever surfaces the current period's occurrence. Only payments
  /// with [RecurringPaymentEntity.autoAddTransaction] participate; manual ones
  /// are left untouched so the user can still "Mark paid" themselves.
  ///
  /// Pure and idempotent: give it the same [now] twice and the second call does
  /// nothing. [newId] mints a fresh id per posted transaction (kept out of the
  /// domain layer). [maxCatchUp] caps how many missed periods we backfill in one
  /// pass, so a long-dormant install can never spin forever.
  ({List<TransactionEntity> transactions, RecurringPaymentEntity updated})
      catchUp(
    RecurringPaymentEntity payment, {
    required DateTime now,
    required String Function() newId,
    int maxCatchUp = 60,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final posted = <TransactionEntity>[];
    var current = payment;
    var guard = 0;

    while (current.autoAddTransaction &&
        !current.isArchived &&
        !current.nextDueDate.isAfter(today) &&
        guard < maxCatchUp) {
      final result = complete(
        current,
        newTransactionId: newId(),
        paidAt: current.nextDueDate,
      );
      if (result.transaction != null) posted.add(result.transaction!);
      current = result.updated;
      guard++;
      if (current.isArchived) break; // reached endDate
    }

    return (transactions: posted, updated: current);
  }

  /// Payments due on/before today.
  List<RecurringPaymentEntity> overdue(
    List<RecurringPaymentEntity> payments,
    DateTime now,
  ) =>
      payments.where((p) => !p.isArchived && p.isOverdue(now)).toList();

  /// Payments due within the next [days] (inclusive of today, excluding
  /// already-overdue ones).
  List<RecurringPaymentEntity> upcoming(
    List<RecurringPaymentEntity> payments,
    DateTime now, {
    int days = 7,
  }) =>
      payments
          .where((p) => !p.isArchived && p.isUpcomingWithin(now, days))
          .toList();
}
