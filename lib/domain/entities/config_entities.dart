import 'dart:convert';

import '../../core/constants/enums.dart';
import 'transaction_entity.dart';

/// A simple named account (wallet, bank, card) money can belong to.
class AccountEntity with AuditableEntity {
  const AccountEntity({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
    this.syncStatus = SyncStatus.localOnly,
  });

  @override
  final String id;
  final String name;
  final int sortOrder;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final DateTime? archivedAt;
  @override
  final SyncStatus syncStatus;
}

/// A payment method (cash, UPI, credit card, etc.).
class PaymentMethodEntity with AuditableEntity {
  const PaymentMethodEntity({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
    this.syncStatus = SyncStatus.localOnly,
  });

  @override
  final String id;
  final String name;
  final int sortOrder;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final DateTime? archivedAt;
  @override
  final SyncStatus syncStatus;
}

/// Definition of a user-created custom field (Section 6).
class CustomFieldEntity with AuditableEntity {
  const CustomFieldEntity({
    required this.id,
    required this.name,
    required this.fieldType,
    required this.displayOrder,
    required this.createdAt,
    required this.updatedAt,
    this.defaultValue,
    this.required = false,
    this.visible = true,
    this.allowedValues = const [],
    this.appliesTo = const [],
    this.archivedAt,
    this.syncStatus = SyncStatus.localOnly,
  });

  @override
  final String id;
  final String name;
  final CustomFieldType fieldType;
  final String? defaultValue;
  final bool required;
  final bool visible;
  final int displayOrder;
  final List<String> allowedValues;

  /// Which transaction types this field applies to.
  final List<TransactionType> appliesTo;

  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final DateTime? archivedAt;
  @override
  final SyncStatus syncStatus;

  bool appliesToType(TransactionType type) =>
      appliesTo.isEmpty || appliesTo.contains(type);

  static List<String> decodeList(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) return decoded.map((e) => e.toString()).toList();
    } catch (_) {/* ignore */}
    return const [];
  }

  static List<TransactionType> decodeTypes(String json) {
    return decodeList(json)
        .map(int.tryParse)
        .whereType<int>()
        .where((i) => i >= 0 && i < TransactionType.values.length)
        .map((i) => TransactionType.values[i])
        .toList();
  }

  CustomFieldEntity copyWith({
    String? name,
    CustomFieldType? fieldType,
    String? defaultValue,
    bool? required,
    bool? visible,
    int? displayOrder,
    List<String>? allowedValues,
    List<TransactionType>? appliesTo,
    DateTime? updatedAt,
    DateTime? archivedAt,
  }) {
    return CustomFieldEntity(
      id: id,
      name: name ?? this.name,
      fieldType: fieldType ?? this.fieldType,
      defaultValue: defaultValue ?? this.defaultValue,
      required: required ?? this.required,
      visible: visible ?? this.visible,
      displayOrder: displayOrder ?? this.displayOrder,
      allowedValues: allowedValues ?? this.allowedValues,
      appliesTo: appliesTo ?? this.appliesTo,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      archivedAt: archivedAt ?? this.archivedAt,
      syncStatus: syncStatus,
    );
  }
}

/// A single stored value for a custom field on a specific record.
class CustomFieldValueEntity {
  const CustomFieldValueEntity({
    required this.id,
    required this.fieldId,
    required this.ownerId,
    required this.ownerType,
    this.value,
  });

  final String id;
  final String fieldId;
  final String ownerId;
  final String ownerType;
  final String? value;
}

/// Per-kind notification preference (Section 12).
class NotificationPreferenceEntity {
  const NotificationPreferenceEntity({
    required this.id,
    required this.kind,
    this.enabled = true,
    this.timingMinutes = 0,
    this.quietStartMinute,
    this.quietEndMinute,
  });

  final String id;

  /// e.g. 'threshold_approaching', 'payment_due', 'salary_missing'.
  final String kind;
  final bool enabled;
  final int timingMinutes;
  final int? quietStartMinute;
  final int? quietEndMinute;
}
