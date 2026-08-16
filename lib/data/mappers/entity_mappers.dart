import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/constants/enums.dart';
import '../../core/utils/money.dart';
import '../../domain/entities/commitment_entities.dart';
import '../../domain/entities/config_entities.dart';
import '../../domain/services/threshold_service.dart';
import '../database/app_database.dart';

/// Mappers between Drift rows and domain entities for every non-transaction
/// entity. Centralized so no screen or repository touches raw rows.

abstract final class RecurringPaymentMapper {
  static RecurringPaymentEntity toEntity(RecurringPayment r) =>
      RecurringPaymentEntity(
        id: r.id,
        name: r.name,
        amount: Money(r.amountMinor),
        kind: PaymentKind.values[r.kind],
        frequency: Frequency.values[r.frequency],
        customIntervalDays: r.customIntervalDays,
        startDate: r.startDate,
        endDate: r.endDate,
        nextDueDate: r.nextDueDate,
        categoryId: r.categoryId,
        accountId: r.accountId,
        notes: r.notes,
        autoAddTransaction: r.autoAddTransaction,
        reminderEnabled: r.reminderEnabled,
        reminderDaysBefore: r.reminderDaysBefore,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
        archivedAt: r.archivedAt,
        syncStatus: SyncStatus.values[r.syncStatus],
      );

  static RecurringPaymentsCompanion toCompanion(RecurringPaymentEntity e) =>
      RecurringPaymentsCompanion.insert(
        id: e.id,
        name: e.name,
        amountMinor: e.amount.minorUnits,
        kind: e.kind.index,
        frequency: e.frequency.index,
        customIntervalDays: Value(e.customIntervalDays),
        startDate: e.startDate,
        endDate: Value(e.endDate),
        nextDueDate: e.nextDueDate,
        categoryId: Value(e.categoryId),
        accountId: Value(e.accountId),
        notes: Value(e.notes),
        autoAddTransaction: Value(e.autoAddTransaction),
        reminderEnabled: Value(e.reminderEnabled),
        reminderDaysBefore: Value(e.reminderDaysBefore),
        createdAt: e.createdAt,
        updatedAt: e.updatedAt,
        archivedAt: Value(e.archivedAt),
        syncStatus: Value(e.syncStatus.index),
      );
}

abstract final class LoanMapper {
  static LoanEntity toEntity(Loan l) => LoanEntity(
        id: l.id,
        name: l.name,
        lender: l.lender,
        originalPrincipal: Money(l.originalPrincipalMinor),
        outstandingPrincipal: Money(l.outstandingPrincipalMinor),
        emi: Money(l.emiMinor),
        interestRateBps: l.interestRateBps,
        frequency: Frequency.values[l.frequency],
        startDate: l.startDate,
        endDate: l.endDate,
        nextPaymentDate: l.nextPaymentDate,
        totalPaid: Money(l.totalPaidMinor),
        notes: l.notes,
        showInUpcoming: l.showInUpcoming,
        createdAt: l.createdAt,
        updatedAt: l.updatedAt,
        archivedAt: l.archivedAt,
        syncStatus: SyncStatus.values[l.syncStatus],
      );

  static LoansCompanion toCompanion(LoanEntity e) => LoansCompanion.insert(
        id: e.id,
        name: e.name,
        lender: Value(e.lender),
        originalPrincipalMinor: e.originalPrincipal.minorUnits,
        outstandingPrincipalMinor: e.outstandingPrincipal.minorUnits,
        emiMinor: e.emi.minorUnits,
        interestRateBps: Value(e.interestRateBps),
        frequency: e.frequency.index,
        startDate: e.startDate,
        endDate: Value(e.endDate),
        nextPaymentDate: Value(e.nextPaymentDate),
        totalPaidMinor: Value(e.totalPaid.minorUnits),
        notes: Value(e.notes),
        showInUpcoming: Value(e.showInUpcoming),
        createdAt: e.createdAt,
        updatedAt: e.updatedAt,
        archivedAt: Value(e.archivedAt),
        syncStatus: Value(e.syncStatus.index),
      );
}

abstract final class AccountMapper {
  static AccountEntity toEntity(Account a) => AccountEntity(
        id: a.id,
        name: a.name,
        sortOrder: a.sortOrder,
        createdAt: a.createdAt,
        updatedAt: a.updatedAt,
        archivedAt: a.archivedAt,
        syncStatus: SyncStatus.values[a.syncStatus],
      );

  static AccountsCompanion toCompanion(AccountEntity e) =>
      AccountsCompanion.insert(
        id: e.id,
        name: e.name,
        sortOrder: Value(e.sortOrder),
        createdAt: e.createdAt,
        updatedAt: e.updatedAt,
        archivedAt: Value(e.archivedAt),
        syncStatus: Value(e.syncStatus.index),
      );
}

abstract final class PaymentMethodMapper {
  static PaymentMethodEntity toEntity(PaymentMethod m) => PaymentMethodEntity(
        id: m.id,
        name: m.name,
        sortOrder: m.sortOrder,
        createdAt: m.createdAt,
        updatedAt: m.updatedAt,
        archivedAt: m.archivedAt,
        syncStatus: SyncStatus.values[m.syncStatus],
      );

  static PaymentMethodsCompanion toCompanion(PaymentMethodEntity e) =>
      PaymentMethodsCompanion.insert(
        id: e.id,
        name: e.name,
        sortOrder: Value(e.sortOrder),
        createdAt: e.createdAt,
        updatedAt: e.updatedAt,
        archivedAt: Value(e.archivedAt),
        syncStatus: Value(e.syncStatus.index),
      );
}

abstract final class CustomFieldMapper {
  static CustomFieldEntity toEntity(CustomField f) => CustomFieldEntity(
        id: f.id,
        name: f.name,
        fieldType: CustomFieldType.values[f.fieldType],
        defaultValue: f.defaultValue,
        required: f.required,
        visible: f.visible,
        displayOrder: f.displayOrder,
        allowedValues: CustomFieldEntity.decodeList(f.allowedValuesJson),
        appliesTo: CustomFieldEntity.decodeTypes(f.appliesToJson),
        createdAt: f.createdAt,
        updatedAt: f.updatedAt,
        archivedAt: f.archivedAt,
        syncStatus: SyncStatus.values[f.syncStatus],
      );

  static CustomFieldsCompanion toCompanion(CustomFieldEntity e) =>
      CustomFieldsCompanion.insert(
        id: e.id,
        name: e.name,
        fieldType: e.fieldType.index,
        defaultValue: Value(e.defaultValue),
        required: Value(e.required),
        visible: Value(e.visible),
        displayOrder: Value(e.displayOrder),
        allowedValuesJson: Value(jsonEncode(e.allowedValues)),
        appliesToJson:
            Value(jsonEncode(e.appliesTo.map((t) => t.index).toList())),
        createdAt: e.createdAt,
        updatedAt: e.updatedAt,
        archivedAt: Value(e.archivedAt),
        syncStatus: Value(e.syncStatus.index),
      );
}

abstract final class ThresholdMapper {
  static ThresholdRule toRule(Threshold t) => ThresholdRule(
        id: t.id,
        label: t.label,
        type: ThresholdType.values[t.thresholdType],
        value: t.value,
        warningPercent: t.warningPercent,
        criticalPercent: t.criticalPercent,
        scopeKey: t.scopeKey,
        enabled: t.enabled,
      );

  static ThresholdsCompanion toCompanion(
    ThresholdRule r, {
    required DateTime now,
    DateTime? createdAt,
  }) =>
      ThresholdsCompanion.insert(
        id: r.id,
        label: r.label,
        thresholdType: r.type.index,
        value: r.value,
        warningPercent: Value(r.warningPercent),
        criticalPercent: Value(r.criticalPercent),
        scopeKey: Value(r.scopeKey),
        enabled: Value(r.enabled),
        createdAt: createdAt ?? now,
        updatedAt: now,
      );
}
