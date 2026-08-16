import '../entities/commitment_entities.dart';

/// One entry in a due / Upcoming list, from either source.
///
/// The payments screen shows subscriptions, rent, SIPs and (opt-in) loan EMIs
/// in a single chronological list. Those are two different entities with two
/// different settlement actions, so rather than fabricate a
/// [RecurringPaymentEntity] for each loan (which would double-count every EMI
/// in monthly spend and leave two schedules to drift apart), each source is
/// wrapped in a small read-only view with the handful of fields a row needs.
///
/// Exactly one of [payment] / [loan] is non-null. Use [isLoan] to branch on
/// which settlement action to offer: "Mark paid" for a recurring payment,
/// "Record EMI" for a loan.
sealed class DueItem {
  const DueItem();

  /// Wraps a recurring payment. Always schedulable: it always has a due date.
  factory DueItem.payment(RecurringPaymentEntity p) = PaymentDueItem;

  /// Wraps a loan EMI. Only call when [LoanEntity.isSchedulable] is true, so
  /// the non-null assertion on the due date below is always safe.
  factory DueItem.loan(LoanEntity l) = LoanDueItem;

  String get id;
  String get name;

  /// The date this falls due, used for sorting and for the due/upcoming split.
  DateTime get dueDate;

  bool get isLoan => this is LoanDueItem;
}

class PaymentDueItem extends DueItem {
  const PaymentDueItem(this.payment);

  final RecurringPaymentEntity payment;

  @override
  String get id => payment.id;
  @override
  String get name => payment.name;
  @override
  DateTime get dueDate => payment.nextDueDate;
}

class LoanDueItem extends DueItem {
  const LoanDueItem(this.loan);

  final LoanEntity loan;

  @override
  String get id => loan.id;
  @override
  String get name => loan.name;

  /// Safe: only schedulable loans (which always carry a next payment date)
  /// are ever wrapped. See [buildDueItems].
  @override
  DateTime get dueDate => loan.nextPaymentDate!;
}

/// Merges recurring payments with the loans that opted into [
/// LoanEntity.showInUpcoming], soonest first.
///
/// Archived, fully-repaid and undated loans are filtered out by
/// [LoanEntity.isSchedulable], so a cleared loan stops appearing the moment its
/// balance hits zero rather than lingering as a phantom commitment.
List<DueItem> buildDueItems({
  required List<RecurringPaymentEntity> payments,
  required List<LoanEntity> loans,
}) {
  final items = <DueItem>[
    for (final p in payments) DueItem.payment(p),
    for (final l in loans)
      if (l.isSchedulable) DueItem.loan(l),
  ]..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  return items;
}
