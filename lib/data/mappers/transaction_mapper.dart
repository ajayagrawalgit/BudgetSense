import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/constants/enums.dart';
import '../../core/utils/money.dart';
import '../../domain/entities/transaction_entity.dart';
import '../database/app_database.dart';

/// Maps between Drift's generated [Transaction] row and the domain
/// [TransactionEntity]. Keeping this in one place means the rest of the app
/// never touches raw rows (clean separation of data and domain).
abstract final class TransactionMapper {
  static TransactionEntity toEntity(Transaction row) {
    return TransactionEntity(
      id: row.id,
      type: TransactionType.values[row.type],
      name: row.name,
      amount: Money(row.amountMinor),
      occurredAt: row.occurredAt,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      iconCodePoint: row.iconCodePoint,
      categoryId: row.categoryId,
      incomeType:
          row.incomeType == null ? null : IncomeType.values[row.incomeType!],
      accountId: row.accountId,
      paymentMethodId: row.paymentMethodId,
      merchant: row.merchant,
      notes: row.notes,
      tags: _decodeTags(row.tagsJson),
      linkedPaymentId: row.linkedPaymentId,
      linkedLoanId: row.linkedLoanId,
      archivedAt: row.archivedAt,
      syncStatus: SyncStatus.values[row.syncStatus],
    );
  }

  static TransactionsCompanion toCompanion(TransactionEntity e) {
    return TransactionsCompanion.insert(
      id: e.id,
      type: e.type.index,
      name: e.name,
      amountMinor: e.amount.minorUnits,
      occurredAt: e.occurredAt,
      createdAt: e.createdAt,
      updatedAt: e.updatedAt,
      iconCodePoint: Value(e.iconCodePoint),
      categoryId: Value(e.categoryId),
      accountId: Value(e.accountId),
      paymentMethodId: Value(e.paymentMethodId),
      incomeType: Value(e.incomeType?.index),
      merchant: Value(e.merchant),
      notes: Value(e.notes),
      tagsJson: Value(jsonEncode(e.tags)),
      linkedPaymentId: Value(e.linkedPaymentId),
      linkedLoanId: Value(e.linkedLoanId),
      archivedAt: Value(e.archivedAt),
      syncStatus: Value(e.syncStatus.index),
    );
  }

  static List<String> _decodeTags(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) return decoded.map((e) => e.toString()).toList();
    } catch (_) {/* fall through */}
    return const [];
  }
}
