import 'package:budgetsense/core/constants/enums.dart';
import 'package:budgetsense/core/utils/money.dart';
import 'package:budgetsense/domain/entities/transaction_entity.dart';
import 'package:budgetsense/domain/services/export_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TransactionEntity txn(TransactionType type, {String? categoryId}) {
    final now = DateTime(2026, 7, 20, 9, 5);
    return TransactionEntity(
      id: 'x-$type',
      type: type,
      name: 'Coffee',
      amount: const Money(45000),
      occurredAt: now,
      createdAt: now,
      updatedAt: now,
      categoryId: categoryId,
      notes: 'morning',
      tags: const ['cafe', 'treat'],
    );
  }

  group('ExportSchema', () {
    test('row projects fields in header order', () {
      final row = ExportSchema.row(
        txn(TransactionType.expense, categoryId: 'c1'),
        categoryName: (_) => 'Wants',
        currencySymbol: r'$',
        locale: 'en_US',
      );
      expect(row.length, ExportSchema.headers.length);
      expect(row[0], '2026-07-20');
      expect(row[1], '09:05');
      expect(row[2], 'Expense');
      expect(row[3], 'Coffee');
      expect(row[4], contains('450.00'));
      expect(row[5], 'Wants');
      expect(row[8], 'morning');
      expect(row[9], 'cafe; treat');
    });

    test('applyScope filters by type', () {
      final all = [
        txn(TransactionType.expense),
        txn(TransactionType.income),
        txn(TransactionType.investment),
      ];
      expect(
        ExportSchema.applyScope(all, ExportScope.expensesOnly).length,
        1,
      );
      expect(
        ExportSchema.applyScope(all, ExportScope.incomeOnly).single.type,
        TransactionType.income,
      );
      expect(ExportSchema.applyScope(all, ExportScope.all).length, 3);
    });
  });
}
