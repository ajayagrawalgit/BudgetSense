import '../../core/constants/enums.dart';
import '../../core/utils/money.dart';
import 'transaction_entity.dart';

/// A recurring or scheduled financial commitment (Section 7): SIPs,
/// subscriptions, rent, EMIs, insurance premiums, etc.
class RecurringPaymentEntity with AuditableEntity {
  const RecurringPaymentEntity({
    required this.id,
    required this.name,
    required this.amount,
    required this.kind,
    required this.frequency,
    required this.startDate,
    required this.nextDueDate,
    required this.createdAt,
    required this.updatedAt,
    this.customIntervalDays = 30,
    this.endDate,
    this.categoryId,
    this.accountId,
    this.notes,
    this.autoAddTransaction = false,
    this.reminderEnabled = true,
    this.reminderDaysBefore = 1,
    this.archivedAt,
    this.syncStatus = SyncStatus.localOnly,
  });

  @override
  final String id;
  final String name;
  final Money amount;
  final PaymentKind kind;
  final Frequency frequency;
  final int customIntervalDays;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime nextDueDate;
  final String? categoryId;
  final String? accountId;
  final String? notes;
  final bool autoAddTransaction;
  final bool reminderEnabled;
  final int reminderDaysBefore;

  /// The day-of-month this commitment is really billed on.
  ///
  /// Anchors monthly and longer cadences so a short month cannot permanently
  /// drag the schedule earlier: a payment on the 31st must take the 28th in
  /// February and then return to the 31st, never decay to the 28th forever.
  ///
  /// Uses the later of [startDate] and [nextDueDate] day-of-month. Taking the
  /// max is what makes this self-healing: [nextDueDate] may currently be a
  /// clamped 28, but the original 31 survives in [startDate], so the intended
  /// day is recovered rather than lost.
  int get billingAnchorDay =>
      startDate.day > nextDueDate.day ? startDate.day : nextDueDate.day;

  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final DateTime? archivedAt;
  @override
  final SyncStatus syncStatus;

  bool get isInvestment => kind.isInvestment;

  bool isOverdue(DateTime now) =>
      nextDueDate.isBefore(DateTime(now.year, now.month, now.day));

  bool isUpcomingWithin(DateTime now, int days) {
    final horizon =
        DateTime(now.year, now.month, now.day).add(Duration(days: days));
    return !nextDueDate.isBefore(DateTime(now.year, now.month, now.day)) &&
        !nextDueDate.isAfter(horizon);
  }

  static const _unset = Object();

  RecurringPaymentEntity copyWith({
    String? name,
    Money? amount,
    PaymentKind? kind,
    Frequency? frequency,
    int? customIntervalDays,
    DateTime? startDate,
    Object? endDate = _unset,
    DateTime? nextDueDate,
    Object? categoryId = _unset,
    Object? accountId = _unset,
    Object? notes = _unset,
    bool? autoAddTransaction,
    bool? reminderEnabled,
    int? reminderDaysBefore,
    DateTime? updatedAt,
    Object? archivedAt = _unset,
    SyncStatus? syncStatus,
  }) {
    return RecurringPaymentEntity(
      id: id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      kind: kind ?? this.kind,
      frequency: frequency ?? this.frequency,
      customIntervalDays: customIntervalDays ?? this.customIntervalDays,
      startDate: startDate ?? this.startDate,
      endDate: identical(endDate, _unset) ? this.endDate : endDate as DateTime?,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      categoryId: identical(categoryId, _unset)
          ? this.categoryId
          : categoryId as String?,
      accountId:
          identical(accountId, _unset) ? this.accountId : accountId as String?,
      notes: identical(notes, _unset) ? this.notes : notes as String?,
      autoAddTransaction: autoAddTransaction ?? this.autoAddTransaction,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      archivedAt: identical(archivedAt, _unset)
          ? this.archivedAt
          : archivedAt as DateTime?,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

/// A loan / liability the user is repaying (Section 9).
class LoanEntity with AuditableEntity {
  const LoanEntity({
    required this.id,
    required this.name,
    required this.originalPrincipal,
    required this.outstandingPrincipal,
    required this.emi,
    required this.frequency,
    required this.startDate,
    required this.createdAt,
    required this.updatedAt,
    this.lender,
    this.interestRateBps = 0,
    this.endDate,
    this.nextPaymentDate,
    this.totalPaid = Money.zero,
    this.notes,
    this.showInUpcoming = false,
    this.archivedAt,
    this.syncStatus = SyncStatus.localOnly,
  });

  @override
  final String id;
  final String name;
  final String? lender;
  final Money originalPrincipal;
  final Money outstandingPrincipal;
  final Money emi;

  /// Interest rate as basis points ×100 (e.g. 8.75% -> 875).
  final int interestRateBps;
  final Frequency frequency;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime? nextPaymentDate;
  final Money totalPaid;
  final String? notes;

  /// Opt-in: treat this EMI as a recurring commitment, so it appears in the
  /// due / Upcoming lists next to subscriptions and rent.
  ///
  /// This is a *view* flag, not a second copy of the loan. No
  /// [RecurringPaymentEntity] row is ever created for a loan: duplicating it
  /// would double-count every EMI in monthly spend and leave two schedules
  /// free to drift apart. The loan stays the single source of truth and the
  /// lists simply read it.
  final bool showInUpcoming;

  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final DateTime? archivedAt;
  @override
  final SyncStatus syncStatus;

  double get interestRatePercent => interestRateBps / 100;

  Money get remaining => outstandingPrincipal;

  /// The day-of-month the EMI is really due. See
  /// [RecurringPaymentEntity.billingAnchorDay] for why the max is taken: it
  /// lets a schedule clamped by February recover its original day.
  int get billingAnchorDay {
    final next = nextPaymentDate;
    if (next == null) return startDate.day;
    return startDate.day > next.day ? startDate.day : next.day;
  }

  /// Whether this loan currently has a live schedule to show in a due list.
  /// An archived or fully-repaid loan has nothing left to fall due.
  bool get isSchedulable =>
      showInUpcoming &&
      archivedAt == null &&
      nextPaymentDate != null &&
      !outstandingPrincipal.isZero;

  /// Fraction of the original principal repaid (0.0 to 1.0).
  double get repaymentProgress {
    if (originalPrincipal.isZero) return 0;
    final paid = originalPrincipal - outstandingPrincipal;
    return paid.ratioOf(originalPrincipal).clamp(0.0, 1.0);
  }

  static const _unset = Object();

  LoanEntity copyWith({
    String? name,
    Object? lender = _unset,
    Money? originalPrincipal,
    Money? outstandingPrincipal,
    Money? emi,
    int? interestRateBps,
    Frequency? frequency,
    DateTime? startDate,
    Object? endDate = _unset,
    Object? nextPaymentDate = _unset,
    Money? totalPaid,
    Object? notes = _unset,
    bool? showInUpcoming,
    DateTime? updatedAt,
    Object? archivedAt = _unset,
    SyncStatus? syncStatus,
  }) {
    return LoanEntity(
      id: id,
      name: name ?? this.name,
      lender: identical(lender, _unset) ? this.lender : lender as String?,
      originalPrincipal: originalPrincipal ?? this.originalPrincipal,
      outstandingPrincipal: outstandingPrincipal ?? this.outstandingPrincipal,
      emi: emi ?? this.emi,
      interestRateBps: interestRateBps ?? this.interestRateBps,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      endDate: identical(endDate, _unset) ? this.endDate : endDate as DateTime?,
      nextPaymentDate: identical(nextPaymentDate, _unset)
          ? this.nextPaymentDate
          : nextPaymentDate as DateTime?,
      totalPaid: totalPaid ?? this.totalPaid,
      notes: identical(notes, _unset) ? this.notes : notes as String?,
      showInUpcoming: showInUpcoming ?? this.showInUpcoming,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      archivedAt: identical(archivedAt, _unset)
          ? this.archivedAt
          : archivedAt as DateTime?,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
