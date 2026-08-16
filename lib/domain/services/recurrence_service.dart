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
  ///
  /// Anchored to [RecurringPaymentEntity.billingAnchorDay] so a short month
  /// never permanently shifts the schedule: a SIP set for the 31st takes the
  /// 28th in February and returns to the 31st in March.
  DateTime advance(RecurringPaymentEntity p) => nextOccurrence(
        p.nextDueDate,
        p.frequency,
        customIntervalDays: p.customIntervalDays,
        anchorDay: p.billingAnchorDay,
      );

  /// Marks a payment as completed for its current due date. Returns the
  /// (optional) transaction to persist and the payment with its due date
  /// advanced to the next cycle. Honors [RecurringPaymentEntity.endDate].
  ///
  /// This is the ONLY place in the app that turns a recurring payment into a
  /// real transaction, and it is only ever reached from an explicit user tap
  /// on "Mark paid". Nothing in BudgetSense posts money on a timer, on launch,
  /// or in the background. If you add a caller, it must be driven by a
  /// deliberate user action. See docs/DESIGN.md "Nothing posts itself".
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
        : nextOccurrence(
            loan.nextPaymentDate!,
            loan.frequency,
            anchorDay: loan.billingAnchorDay,
          );

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

  /// Advances a payment's schedule past every period that has already come
  /// due, WITHOUT creating a single transaction.
  ///
  /// This exists so a payment that was due while the app was closed still
  /// shows a sensible "next due" date instead of being stuck in the past
  /// forever. It deliberately posts no money: an unpaid period is simply a
  /// period the user never marked paid, and BudgetSense does not invent
  /// spending on the user's behalf.
  ///
  /// Pure and idempotent. [maxRoll] caps how many periods we skip in one pass
  /// so a long-dormant install can never spin forever.
  RecurringPaymentEntity rollScheduleForward(
    RecurringPaymentEntity payment, {
    required DateTime now,
    int maxRoll = 600,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    var current = payment;
    var guard = 0;

    while (!current.isArchived &&
        !current.nextDueDate.isAfter(today) &&
        guard < maxRoll) {
      final next = advance(current);
      final ended = current.endDate != null && next.isAfter(current.endDate!);
      current = current.copyWith(
        nextDueDate: next,
        updatedAt: now,
        archivedAt: ended ? now : null,
      );
      guard++;
      if (current.isArchived) break; // reached endDate
    }

    return current;
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
