import '../../core/constants/enums.dart';
import '../../core/utils/money.dart';

/// Base fields every persisted record carries (Section 21).
///
/// Includes a [syncStatus] placeholder so future cloud sync can be layered on
/// without a schema rewrite.
mixin AuditableEntity {
  String get id;
  DateTime get createdAt;
  DateTime get updatedAt;
  DateTime? get archivedAt;
  SyncStatus get syncStatus;

  bool get isArchived => archivedAt != null;
}

/// A single money movement. This is the unifying entity behind expenses,
/// income, investments, loan payments and recurring payments - one shape,
/// discriminated by [type], so summaries and history stay DRY.
class TransactionEntity with AuditableEntity {
  const TransactionEntity({
    required this.id,
    required this.type,
    required this.name,
    required this.amount,
    required this.occurredAt,
    required this.createdAt,
    required this.updatedAt,
    this.iconCodePoint,
    this.categoryId,
    this.incomeType,
    this.accountId,
    this.paymentMethodId,
    this.merchant,
    this.notes,
    this.tags = const [],
    this.linkedPaymentId,
    this.linkedLoanId,
    this.archivedAt,
    this.syncStatus = SyncStatus.localOnly,
  });

  @override
  final String id;
  final TransactionType type;
  final String name;
  final Money amount;

  /// When the money actually moved (user-editable). Defaults to creation time.
  final DateTime occurredAt;

  /// Optional per-transaction icon (code point into kCategoryIcons). Null means
  /// "use the category's icon".
  final int? iconCodePoint;

  final String? categoryId;
  final IncomeType? incomeType;
  final String? accountId;
  final String? paymentMethodId;
  final String? merchant;
  final String? notes;
  final List<String> tags;

  /// Back-links for auto-created transactions (recurring / loan).
  final String? linkedPaymentId;
  final String? linkedLoanId;

  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final DateTime? archivedAt;
  @override
  final SyncStatus syncStatus;

  bool get isOutflow => type.isOutflow;

  static const _unset = Object();

  TransactionEntity copyWith({
    TransactionType? type,
    String? name,
    Money? amount,
    DateTime? occurredAt,
    Object? iconCodePoint = _unset,
    Object? categoryId = _unset,
    Object? incomeType = _unset,
    Object? accountId = _unset,
    Object? paymentMethodId = _unset,
    Object? merchant = _unset,
    Object? notes = _unset,
    List<String>? tags,
    Object? linkedPaymentId = _unset,
    Object? linkedLoanId = _unset,
    DateTime? updatedAt,
    Object? archivedAt = _unset,
    SyncStatus? syncStatus,
  }) {
    return TransactionEntity(
      id: id,
      type: type ?? this.type,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      occurredAt: occurredAt ?? this.occurredAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      iconCodePoint: identical(iconCodePoint, _unset)
          ? this.iconCodePoint
          : iconCodePoint as int?,
      categoryId: identical(categoryId, _unset)
          ? this.categoryId
          : categoryId as String?,
      incomeType: identical(incomeType, _unset)
          ? this.incomeType
          : incomeType as IncomeType?,
      accountId:
          identical(accountId, _unset) ? this.accountId : accountId as String?,
      paymentMethodId: identical(paymentMethodId, _unset)
          ? this.paymentMethodId
          : paymentMethodId as String?,
      merchant:
          identical(merchant, _unset) ? this.merchant : merchant as String?,
      notes: identical(notes, _unset) ? this.notes : notes as String?,
      tags: tags ?? this.tags,
      linkedPaymentId: identical(linkedPaymentId, _unset)
          ? this.linkedPaymentId
          : linkedPaymentId as String?,
      linkedLoanId: identical(linkedLoanId, _unset)
          ? this.linkedLoanId
          : linkedLoanId as String?,
      archivedAt: identical(archivedAt, _unset)
          ? this.archivedAt
          : archivedAt as DateTime?,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

/// A customizable spending category. Categories are fully dynamic: users add,
/// rename, recolor and reorder them under Settings. The optional starter set
/// (Needs / Wants / Responsibilities) is only a suggestion offered during
/// onboarding and is fully editable or removable; nothing in the app depends on
/// those names existing.
class CategoryEntity with AuditableEntity {
  const CategoryEntity({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.iconCodePoint,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.isDefault = false,
    this.archivedAt,
    this.syncStatus = SyncStatus.localOnly,
  });

  @override
  final String id;
  final String name;
  final int colorValue;
  final int iconCodePoint;
  final int sortOrder;

  final bool isDefault;

  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final DateTime? archivedAt;
  @override
  final SyncStatus syncStatus;
}
