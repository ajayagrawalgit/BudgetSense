import 'dart:convert';

import 'package:budgetsense/core/constants/enums.dart';
import 'package:budgetsense/data/database/app_database.dart';
import 'package:budgetsense/data/import/paisa_import_service.dart';
import 'package:budgetsense/domain/services/import_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Robustness tests for the Paisa importer against a real in-memory database.
void main() {
  late AppDatabase db;
  late DriftPaisaImportService importer;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    importer = DriftPaisaImportService(db);
  });

  tearDown(() async {
    await db.close();
  });

  List<int> bytesOf(Object json) => utf8.encode(jsonEncode(json));

  Map<String, dynamic> sampleExport() => {
        'backupVersion': 8,
        'users': [
          {
            'uuid': 'u1',
            'name': 'Vini',
            'currency': 'INR',
            'isSelected': true,
          },
        ],
        'accounts': [
          {
            'uuid': 'acc1',
            'name': 'Vinita',
            'bankName': 'Axis',
            'createdAt': '2024-01-01T10:00:00.000',
            'updatedAt': '2024-01-01T10:00:00.000',
          },
        ],
        'categories': [
          {
            'uuid': 'cat-food',
            'name': 'Food and drinks',
            'type': 0,
            'color': 4294940672,
            'icon': 983642,
            'createdAt': '2024-01-01T10:00:00.000',
            'updatedAt': '2024-01-01T10:00:00.000',
          },
          {
            'uuid': 'cat-salary',
            'name': 'Monthly Salary',
            'type': 1,
            'color': 4278228616,
            'icon': 985107,
            'createdAt': '2024-01-01T10:00:00.000',
            'updatedAt': '2024-01-01T10:00:00.000',
          },
        ],
        'transactions': [
          {
            'uuid': 't-exp',
            'name': 'Lunch',
            'amount': 250.5,
            'type': 0,
            'account': 'acc1',
            'category': 'cat-food',
            'description': 'tasty',
            'tags': <String>[],
            'createdAt': '2024-02-10T13:00:00.000',
            'updatedAt': '2024-02-10T13:00:00.000',
          },
          {
            'uuid': 't-inc',
            'name': 'Salary',
            'amount': 50000.0,
            'type': 1,
            'account': 'acc1',
            'category': 'cat-salary',
            'createdAt': '2024-02-01T09:00:00.000',
            'updatedAt': '2024-02-01T09:00:00.000',
          },
          {
            'uuid': 't-transfer',
            'name': 'Move money',
            'amount': 1000.0,
            'type': 2,
            'account': 'acc1',
            'category': null,
            'createdAt': '2024-02-05T09:00:00.000',
            'updatedAt': '2024-02-05T09:00:00.000',
          },
        ],
      };

  test('imports categories, accounts and transactions with correct mapping',
      () async {
    final outcome =
        await importer.import(ImportSource.paisa, bytesOf(sampleExport()));

    expect(outcome.categories, 2);
    expect(outcome.accounts, 1);
    expect(outcome.transactions, 2); // transfer skipped
    expect(outcome.skippedTransfers, 1);

    final txns = await db.select(db.transactions).get();
    expect(txns, hasLength(2));

    final expense = txns.firstWhere((t) => t.id == 't-exp');
    expect(expense.type, TransactionType.expense.index);
    expect(expense.amountMinor, 25050); // 250.50 -> minor units
    expect(expense.categoryId, 'cat-food');
    expect(expense.accountId, 'acc1');
    expect(expense.notes, 'tasty');
    expect(expense.occurredAt, DateTime(2024, 2, 10, 13));

    final income = txns.firstWhere((t) => t.id == 't-inc');
    expect(income.type, TransactionType.income.index);
    expect(income.incomeType, IncomeType.salary.index);

    // Profile detected and returned for the caller to persist.
    expect(outcome.profile?.name, 'Vini');
    expect(outcome.profile?.currencyCode, 'INR');
    expect(outcome.profile?.currencySymbol, '₹');
  });

  test('importProfile:false imports data but returns no profile to apply',
      () async {
    final outcome = await importer.import(
      ImportSource.paisa,
      bytesOf(sampleExport()),
      importProfile: false,
    );

    // Financial data still comes in fully.
    expect(outcome.transactions, 2);
    expect(outcome.categories, 2);
    expect(outcome.accounts, 1);
    // But no profile is surfaced, so the caller never touches personal info.
    expect(outcome.profile, isNull);
  });

  test('re-importing is append-only: no duplicates and nothing re-added',
      () async {
    final first =
        await importer.import(ImportSource.paisa, bytesOf(sampleExport()));
    expect(first.transactions, 2); // all newly added the first time

    final second =
        await importer.import(ImportSource.paisa, bytesOf(sampleExport()));
    // Everything already existed, so nothing new is added on the second run.
    expect(second.transactions, 0);
    expect(second.categories, 0);
    expect(second.accounts, 0);

    // And the database is unchanged (no duplication).
    expect(await db.select(db.transactions).get(), hasLength(2));
    expect(await db.select(db.categories).get(), hasLength(2));
    expect(await db.select(db.accounts).get(), hasLength(1));
  });

  test('never removes or overwrites locally-created entries', () async {
    final now = DateTime(2026, 1, 1);
    // A category + transaction the user created locally in BudgetSense.
    await db.into(db.categories).insert(
          CategoriesCompanion.insert(
            id: 'local-cat',
            name: 'My Local Category',
            colorValue: 0xFF112233,
            iconCodePoint: 100,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            id: 'local-txn',
            type: 0,
            name: 'Local coffee',
            amountMinor: 9900,
            occurredAt: now,
            createdAt: now,
            updatedAt: now,
            categoryId: const Value('local-cat'),
          ),
        );

    await importer.import(ImportSource.paisa, bytesOf(sampleExport()));

    // Local records are still present and completely unchanged.
    final localTxn = (await db.select(db.transactions).get())
        .firstWhere((t) => t.id == 'local-txn');
    expect(localTxn.name, 'Local coffee');
    expect(localTxn.amountMinor, 9900);
    final localCat = (await db.select(db.categories).get())
        .firstWhere((c) => c.id == 'local-cat');
    expect(localCat.name, 'My Local Category');

    // Imported rows were appended alongside them.
    expect(await db.select(db.transactions).get(), hasLength(3)); // 1 local + 2
  });

  test('does not overwrite a user edit to a previously-imported row', () async {
    await importer.import(ImportSource.paisa, bytesOf(sampleExport()));

    // User edits an imported transaction locally.
    await (db.update(db.transactions)..where((t) => t.id.equals('t-exp')))
        .write(const TransactionsCompanion(name: Value('Edited by user')));

    // Re-import the same file: the edit must survive (append-only, no update).
    await importer.import(ImportSource.paisa, bytesOf(sampleExport()));

    final edited = (await db.select(db.transactions).get())
        .firstWhere((t) => t.id == 't-exp');
    expect(edited.name, 'Edited by user');
  });

  test('nulls dangling category/account references instead of failing',
      () async {
    final export = sampleExport();
    (export['transactions'] as List).add({
      'uuid': 't-orphan',
      'name': 'Orphan',
      'amount': 10.0,
      'type': 0,
      'account': 'missing-account',
      'category': 'missing-category',
      'createdAt': '2024-03-01T09:00:00.000',
      'updatedAt': '2024-03-01T09:00:00.000',
    });

    final outcome = await importer.import(ImportSource.paisa, bytesOf(export));
    expect(outcome.transactions, 3);

    final orphan = (await db.select(db.transactions).get())
        .firstWhere((t) => t.id == 't-orphan');
    expect(orphan.categoryId, isNull);
    expect(orphan.accountId, isNull);
  });

  test('inspect summarises without writing to the database', () async {
    final preview =
        await importer.inspect(ImportSource.paisa, bytesOf(sampleExport()));

    expect(preview.transactions, 2);
    expect(preview.incomeCount, 1);
    expect(preview.expenseCount, 1);
    expect(preview.categories, 2);
    expect(preview.accounts, 1);
    expect(preview.earliest, DateTime(2024, 2, 1, 9));
    expect(preview.latest, DateTime(2024, 2, 10, 13));

    // Nothing was written.
    expect(await db.select(db.transactions).get(), isEmpty);
    expect(await db.select(db.categories).get(), isEmpty);
  });

  test('throws a friendly error for non-Paisa / invalid JSON', () async {
    await expectLater(
      () => importer.import(ImportSource.paisa, utf8.encode('not json')),
      throwsA(isA<ImportException>()),
    );
    await expectLater(
      () => importer.inspect(ImportSource.paisa, bytesOf({'foo': 'bar'})),
      throwsA(isA<ImportException>()),
    );
  });
}
