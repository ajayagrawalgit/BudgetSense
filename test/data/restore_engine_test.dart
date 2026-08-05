import 'package:budgetsense/data/database/app_database.dart';
import 'package:budgetsense/data/snapshot/restore_engine.dart';
import 'package:budgetsense/domain/services/snapshot_service.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_database.dart';

/// Proves the append-only, non-destructive restore invariants (Phase 4/13).

final _t = DateTime.utc(2026, 1, 1, 12);
String _iso(DateTime d) => d.toIso8601String();

Future<void> _seedCategory(AppDatabase db, String id, String name) =>
    db.into(db.categories).insert(
          CategoriesCompanion.insert(
            id: id,
            createdAt: _t,
            updatedAt: _t,
            name: name,
            colorValue: 0xFF000000,
            iconCodePoint: 0xe000,
          ),
        );

Future<void> _seedTxn(
  AppDatabase db,
  String id,
  String name,
  int amount, {
  String? categoryId,
}) =>
    db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            id: id,
            createdAt: _t,
            updatedAt: _t,
            type: 0,
            name: name,
            amountMinor: amount,
            occurredAt: _t,
            categoryId: Value(categoryId),
          ),
        );

Map<String, Object?> _txnRow(
  String id,
  String name,
  int amount, {
  String? categoryId,
  DateTime? updated,
}) =>
    {
      'id': id,
      'createdAt': _iso(_t),
      'updatedAt': _iso(updated ?? _t),
      'syncStatus': 0,
      'type': 0,
      'name': name,
      'amountMinor': amount,
      'occurredAt': _iso(_t),
      'tagsJson': '[]',
      if (categoryId != null) 'categoryId': categoryId,
    };

Map<String, Object?> _catRow(String id, String name,
        {int color = 0xFF111111}) =>
    {
      'id': id,
      'createdAt': _iso(_t),
      'updatedAt': _iso(_t),
      'syncStatus': 0,
      'name': name,
      'colorValue': color,
      'iconCodePoint': 0xe000,
      'sortOrder': 0,
      'isDefault': false,
      'semanticBucket': '',
    };

AppSnapshot _snap(
  Map<String, List<Map<String, Object?>>> tables, {
  String backupId = 'backup-1',
}) =>
    AppSnapshot(
      exportedAt: _t,
      appVersion: 'test',
      schemaVersion: 4,
      backupId: backupId,
      settings: const {},
      tables: {
        for (final t in const [
          'categories',
          'accounts',
          'paymentMethods',
          'transactions',
          'recurringPayments',
          'loans',
          'customFields',
          'customFieldValues',
          'thresholds',
          'notificationPreferences',
          'exportRecords',
        ])
          t: tables[t] ?? const [],
      },
    );

Future<RestoreExecutionResult> _restore(
  RestoreEngine engine,
  AppSnapshot snap,
) async {
  final plan = await engine.plan(snap);
  return engine.executeCollections(plan);
}

void main() {
  late AppDatabase db;
  late RestoreEngine engine;

  setUp(() {
    db = newTestDatabase();
    engine = RestoreEngine(db);
  });
  tearDown(() => db.close());

  test('empty destination: rows are inserted with preserved ids', () async {
    final res = await _restore(
      engine,
      _snap({
        'categories': [_catRow('c1', 'Food')],
        'transactions': [_txnRow('t1', 'Coffee', 4500, categoryId: 'c1')],
      }),
    );
    expect(res.totalInserted, 2);
    final txns = await db.select(db.transactions).get();
    expect(txns.single.id, 't1');
    expect(txns.single.categoryId, 'c1');
  });

  test(
      'existing record is NEVER updated or deleted (id collision, new content)',
      () async {
    await _seedTxn(db, 'A', 'Original', 100);
    final res = await _restore(
      engine,
      _snap({
        'transactions': [_txnRow('A', 'Tampered', 999)],
      }),
    );
    final txns = await db.select(db.transactions).get();
    // Original preserved verbatim; imported copy appended under a new id.
    final original = txns.firstWhere((t) => t.id == 'A');
    expect(original.name, 'Original');
    expect(original.amountMinor, 100);
    expect(txns.length, 2);
    expect(res.totalRemapped, 1);
    final appended = txns.firstWhere((t) => t.id != 'A');
    expect(appended.amountMinor, 999);
  });

  test('repeated restore is idempotent', () async {
    final snap = _snap({
      'categories': [_catRow('c1', 'Food')],
      'transactions': [_txnRow('t1', 'Coffee', 4500, categoryId: 'c1')],
    });
    await _restore(engine, snap);
    final second = await _restore(engine, snap);
    expect(second.totalInserted, 0);
    expect(second.totalSkipped, 2);
    expect(await db.select(db.transactions).get(), hasLength(1));
    expect(await db.select(db.categories).get(), hasLength(1));
  });

  test(
      'two legitimate identical-looking records with distinct ids both survive',
      () async {
    final res = await _restore(
      engine,
      _snap({
        'transactions': [
          _txnRow('x', 'Coffee', 4500),
          _txnRow('y', 'Coffee', 4500),
        ],
      }),
    );
    expect(res.totalInserted, 2);
    expect(await db.select(db.transactions).get(), hasLength(2));
  });

  test('id collision remaps and rewrites every FK consistently', () async {
    // Local already owns category id "c1" with different content.
    await _seedCategory(db, 'c1', 'LocalFood');
    final res = await _restore(
      engine,
      _snap({
        'categories': [_catRow('c1', 'BackupFood', color: 0xFF222222)],
        'transactions': [_txnRow('t1', 'Coffee', 4500, categoryId: 'c1')],
      }),
    );
    expect(res.totalRemapped, 1); // the category was remapped
    final cats = await db.select(db.categories).get();
    expect(cats, hasLength(2));
    final local = cats.firstWhere((c) => c.id == 'c1');
    expect(local.name, 'LocalFood'); // untouched
    final imported = cats.firstWhere((c) => c.id != 'c1');
    expect(imported.name, 'BackupFood');
    // The imported transaction points at the REMAPPED category, not the local.
    final txn = (await db.select(db.transactions).get()).single;
    expect(txn.categoryId, imported.id);
    expect(txn.categoryId, isNot('c1'));
  });

  test(
      'a changed source record in a newer snapshot is appended, not overwritten',
      () async {
    final v1 = _snap({
      'transactions': [_txnRow('A', 'Rent', 100000)],
    }, backupId: 'b1');
    await _restore(engine, v1);

    final v2 = _snap({
      'transactions': [
        _txnRow('A', 'Rent', 120000, updated: _t.add(const Duration(days: 40))),
      ],
    }, backupId: 'b2');
    final res = await _restore(engine, v2);

    expect(res.totalVersioned, 1);
    final txns = await db.select(db.transactions).get();
    expect(txns, hasLength(2));
    final original = txns.firstWhere((t) => t.id == 'A');
    expect(original.amountMinor, 100000); // untouched
    final versioned = txns.firstWhere((t) => t.id != 'A');
    expect(versioned.amountMinor, 120000);
  });

  test('duplicate source ids inside the backup => zero mutations', () async {
    await expectLater(
      _restore(
        engine,
        _snap({
          'transactions': [
            _txnRow('dup', 'A', 100),
            _txnRow('dup', 'B', 200),
          ],
        }),
      ),
      throwsA(isA<SnapshotException>()),
    );
    expect(await db.select(db.transactions).get(), isEmpty);
    expect(await db.select(db.importLedger).get(), isEmpty);
  });

  test('non-finite money => zero mutations', () async {
    await expectLater(
      _restore(
        engine,
        _snap({
          'transactions': [
            {..._txnRow('t1', 'x', 0)..['amountMinor'] = double.nan},
          ],
        }),
      ),
      throwsA(isA<SnapshotException>()),
    );
    expect(await db.select(db.transactions).get(), isEmpty);
  });

  test('a mid-restore insert failure rolls back EVERYTHING', () async {
    // The category is valid and comes first; the transaction omits the required
    // amountMinor, so its insert fails a NOT NULL constraint. The whole restore
    // must roll back, leaving zero rows and no ledger entries.
    final bad = <String, Object?>{
      'id': 't1',
      'createdAt': _iso(_t),
      'updatedAt': _iso(_t),
      'type': 0,
      'name': 'Broken',
      'occurredAt': _iso(_t),
      'tagsJson': '[]',
      // amountMinor deliberately absent -> NOT NULL violation on insert.
    };
    await expectLater(
      _restore(
        engine,
        _snap({
          'categories': [_catRow('c1', 'Food')],
          'transactions': [bad],
        }),
      ),
      throwsA(anything),
    );
    expect(await db.select(db.categories).get(), isEmpty);
    expect(await db.select(db.transactions).get(), isEmpty);
    expect(await db.select(db.importLedger).get(), isEmpty);
  });

  test('full pre-restore state is unchanged after restore (invariant capture)',
      () async {
    await _seedCategory(db, 'c1', 'Food');
    await _seedTxn(db, 'A', 'Original', 100, categoryId: 'c1');
    await _seedTxn(db, 'B', 'Second', 200);
    final before = await db.select(db.transactions).get();
    final beforeCats = await db.select(db.categories).get();

    await _restore(
      engine,
      _snap({
        'categories': [_catRow('c9', 'NewCat')],
        'transactions': [_txnRow('t9', 'NewTxn', 700, categoryId: 'c9')],
      }),
    );

    // Every pre-existing record is byte-for-byte identical afterward.
    final afterExisting = (await db.select(db.transactions).get())
        .where((t) => t.id == 'A' || t.id == 'B')
        .toList();
    expect(afterExisting.toSet(), before.toSet());
    final afterCatsExisting = (await db.select(db.categories).get())
        .where((c) => c.id == 'c1')
        .toList();
    expect(afterCatsExisting.toSet(), beforeCats.toSet());
    // And the new data was appended.
    expect(await db.select(db.transactions).get(), hasLength(3));
  });
}
