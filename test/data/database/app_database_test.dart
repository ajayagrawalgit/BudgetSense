import 'package:budgetsense/core/constants/enums.dart';
import 'package:budgetsense/core/utils/money.dart';
import 'package:budgetsense/data/database/app_database.dart';
import 'package:budgetsense/data/repositories/category_repository.dart';
import 'package:budgetsense/data/repositories/transaction_repository.dart';
import 'package:budgetsense/domain/entities/transaction_entity.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

/// Behavioural tests for the central database: foreign-key enforcement,
/// performance indexes, and the Section-18 "delete all my data" wipe. These
/// exercise the production migration/beforeOpen path (forTesting shares it).
void main() {
  late AppDatabase db;

  final t0 = DateTime(2026, 1, 1);

  setUp(() => db = newTestDatabase());
  tearDown(() => db.close());

  test('foreign keys are enforced (PRAGMA foreign_keys = ON in beforeOpen)',
      () async {
    // Inserting a transaction that references a non-existent category id must
    // be rejected by SQLite, proving referential integrity is on in every
    // connection (this is what protects finance data from dangling links).
    expect(
      () => db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              id: 't-bad',
              type: TransactionType.expense.index,
              name: 'Orphan',
              amountMinor: 1000,
              occurredAt: t0,
              createdAt: t0,
              updatedAt: t0,
              categoryId: const Value('does-not-exist'),
            ),
          ),
      throwsA(anything),
    );
  });

  test('performance indexes exist after a fresh onCreate', () async {
    final rows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND name LIKE 'idx_%'",
        )
        .get();
    final names = rows.map((r) => r.read<String>('name')).toSet();
    expect(names, contains('idx_txn_occurred'));
    expect(names, contains('idx_txn_category'));
    expect(names, contains('idx_recpay_next_due'));
    expect(names, contains('idx_cfv_owner'));
  });

  test('wipeAllData clears every table inside one transaction', () async {
    final categories = DriftCategoryRepository(db);
    final txns = DriftTransactionRepository(db);

    await categories.upsert(
      CategoryEntity(
        id: 'c1',
        name: 'Food',
        colorValue: 0xFF000000,
        iconCodePoint: 0xe57f,
        sortOrder: 0,
        createdAt: t0,
        updatedAt: t0,
      ),
    );
    await txns.upsert(
      TransactionEntity(
        id: 't1',
        type: TransactionType.expense,
        name: 'Lunch',
        amount: const Money(1000),
        occurredAt: t0,
        createdAt: t0,
        updatedAt: t0,
        categoryId: 'c1',
      ),
    );

    expect(await categories.getAll(), isNotEmpty);

    await db.wipeAllData();

    expect(await categories.getAll(includeArchived: true), isEmpty);
    expect(await txns.getById('t1'), isNull);
  });

  test('schemaVersion is the expected current version', () {
    expect(db.schemaVersion, 4);
  });

  test('v4 adds the device-local import_ledger table', () async {
    await db.select(db.importLedger).get(); // resolves -> table exists
    final cols =
        await db.customSelect("PRAGMA table_info('import_ledger')").get();
    final names = cols.map((r) => r.read<String>('name')).toSet();
    expect(names, containsAll({'source_entity_type', 'source_record_id'}));
  });
}
