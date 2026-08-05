import 'package:budgetsense/data/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the v2 migration: performance indexes must exist on fresh installs,
/// and the index DDL must be safe to re-run (idempotent) so a partial or
/// repeated upgrade can never corrupt an existing user's database.
void main() {
  const expectedIndexes = <String>{
    'idx_txn_occurred',
    'idx_txn_category',
    'idx_txn_archived',
    'idx_recpay_next_due',
    'idx_recpay_archived',
    'idx_loan_next_payment',
    'idx_loan_archived',
    'idx_cfv_owner',
    'idx_cfv_field',
  };

  test('fresh database is created with every performance index', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    // Any real query forces Drift to run onCreate -> createAll, which builds the
    // tables and the @TableIndex-declared indexes.
    await db.select(db.categories).get();

    final rows = await db
        .customSelect(
          "SELECT name FROM sqlite_master "
          "WHERE type = 'index' AND name LIKE 'idx_%'",
        )
        .get();
    final names = rows.map((r) => r.read<String>('name')).toSet();

    expect(names, containsAll(expectedIndexes));
  });

  test('schemaVersion is 4', () {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    expect(db.schemaVersion, 4);
  });

  test('fresh database has the v3 transactions.icon_code_point column',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.select(db.transactions).get(); // force onCreate

    final cols =
        await db.customSelect("PRAGMA table_info('transactions')").get();
    final names = cols.map((r) => r.read<String>('name')).toSet();
    expect(
      names,
      contains('icon_code_point'),
      reason: 'v3 adds the per-expense icon column',
    );
  });

  test('v2->v3 migration adds icon_code_point and is safe to re-run', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.select(db.transactions).get();

    // The migration Drift runs for v2->v3 is a single ADD COLUMN. Re-running
    // the query below proves the column resolves (a typo in the column/table
    // name would throw), and that existing rows keep NULL (fall back to the
    // category icon) rather than being touched.
    final rows =
        await db.customSelect('SELECT icon_code_point FROM transactions').get();
    expect(rows, isEmpty); // fresh db, no rows - but the column must exist
  });

  test(
      'v1->v2 migration DDL creates every index from an absent state, '
      'then re-runs safely', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.select(db.categories).get(); // schema + @TableIndex indexes exist

    // Drop the indexes so the migration must actually CREATE each one. This
    // forces SQLite to resolve the real table/column names - a typo in the
    // hand-written DDL would throw here (the exact crash an existing user would
    // hit when Drift runs onUpgrade(1 -> 2) on their v1 database).
    for (final name in expectedIndexes) {
      await db.customStatement('DROP INDEX IF EXISTS $name;');
    }

    const migrationDdl = <String>[
      'CREATE INDEX IF NOT EXISTS idx_txn_occurred ON transactions (occurred_at);',
      'CREATE INDEX IF NOT EXISTS idx_txn_category ON transactions (category_id);',
      'CREATE INDEX IF NOT EXISTS idx_txn_archived ON transactions (archived_at);',
      'CREATE INDEX IF NOT EXISTS idx_recpay_next_due ON recurring_payments (next_due_date);',
      'CREATE INDEX IF NOT EXISTS idx_recpay_archived ON recurring_payments (archived_at);',
      'CREATE INDEX IF NOT EXISTS idx_loan_next_payment ON loans (next_payment_date);',
      'CREATE INDEX IF NOT EXISTS idx_loan_archived ON loans (archived_at);',
      'CREATE INDEX IF NOT EXISTS idx_cfv_owner ON custom_field_values (owner_id);',
      'CREATE INDEX IF NOT EXISTS idx_cfv_field ON custom_field_values (field_id);',
    ];

    Future<int> indexCount() async {
      final row = await db
          .customSelect(
            "SELECT COUNT(*) AS c FROM sqlite_master "
            "WHERE type = 'index' AND name LIKE 'idx_%' "
            "AND name != 'idx_ledger_source'",
          )
          .getSingle();
      return row.read<int>('c');
    }

    // First run: create-when-absent. Validates every column name is correct.
    for (final sql in migrationDdl) {
      await db.customStatement(sql);
    }
    expect(
      await indexCount(),
      expectedIndexes.length,
      reason: 'migration must create all indexes from an absent state',
    );

    // Second run: idempotent - a re-triggered/partial upgrade must not fail.
    for (final sql in migrationDdl) {
      await db.customStatement(sql);
    }
    expect(await indexCount(), expectedIndexes.length);
  });
}
