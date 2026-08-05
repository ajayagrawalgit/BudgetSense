import 'package:budgetsense/core/constants/enums.dart';
import 'package:budgetsense/core/utils/money.dart';
import 'package:budgetsense/data/database/app_database.dart';
import 'package:budgetsense/data/repositories/category_repository.dart';
import 'package:budgetsense/data/repositories/transaction_repository.dart';
import 'package:budgetsense/domain/entities/transaction_entity.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  late AppDatabase db;
  late DriftCategoryRepository repo;
  late DriftTransactionRepository txns;

  final t0 = DateTime(2026, 1, 1, 9);

  CategoryEntity cat(
    String id,
    String name, {
    int sortOrder = 0,
    bool isDefault = false,
    DateTime? archivedAt,
  }) =>
      CategoryEntity(
        id: id,
        name: name,
        colorValue: 0xFF112233,
        iconCodePoint: 0xe57f,
        sortOrder: sortOrder,
        isDefault: isDefault,
        createdAt: t0,
        updatedAt: t0,
        archivedAt: archivedAt,
      );

  setUp(() {
    db = newTestDatabase();
    repo = DriftCategoryRepository(db);
    txns = DriftTransactionRepository(db);
  });

  tearDown(() => db.close());

  test('upsert then getById round-trips every field', () async {
    await repo.upsert(cat('c1', 'Food', sortOrder: 3, isDefault: true));
    final loaded = await repo.getById('c1');
    expect(loaded, isNotNull);
    expect(loaded!.name, 'Food');
    expect(loaded.colorValue, 0xFF112233);
    expect(loaded.iconCodePoint, 0xe57f);
    expect(loaded.sortOrder, 3);
    expect(loaded.isDefault, isTrue);
    expect(loaded.syncStatus, SyncStatus.localOnly);
  });

  test('getById returns null for an unknown id', () async {
    expect(await repo.getById('nope'), isNull);
  });

  test('upsert updates an existing row rather than duplicating', () async {
    await repo.upsert(cat('c1', 'Food'));
    await repo.upsert(cat('c1', 'Groceries'));
    final all = await repo.getAll();
    expect(all.length, 1);
    expect(all.single.name, 'Groceries');
  });

  test('getAll orders by sortOrder ascending', () async {
    await repo.upsert(cat('b', 'B', sortOrder: 2));
    await repo.upsert(cat('a', 'A', sortOrder: 0));
    await repo.upsert(cat('c', 'C', sortOrder: 1));
    final ordered = (await repo.getAll()).map((c) => c.id).toList();
    expect(ordered, ['a', 'c', 'b']);
  });

  test('archived categories are hidden unless explicitly included', () async {
    await repo.upsert(cat('live', 'Live'));
    await repo.upsert(cat('gone', 'Gone', archivedAt: t0));
    expect((await repo.getAll()).map((c) => c.id), ['live']);
    expect(
      (await repo.getAll(includeArchived: true)).map((c) => c.id).toSet(),
      {'live', 'gone'},
    );
  });

  test('watchAll emits an ordered live list', () async {
    await repo.upsert(cat('a', 'A', sortOrder: 1));
    await repo.upsert(cat('b', 'B', sortOrder: 0));
    final first = await repo.watchAll().first;
    expect(first.map((c) => c.id), ['b', 'a']);
  });

  test('reorder rewrites sortOrder to match the given id order', () async {
    await repo.upsert(cat('a', 'A', sortOrder: 0));
    await repo.upsert(cat('b', 'B', sortOrder: 1));
    await repo.upsert(cat('c', 'C', sortOrder: 2));
    await repo.reorder(['c', 'a', 'b']);
    expect((await repo.getAll()).map((c) => c.id), ['c', 'a', 'b']);
  });

  test('setDefault makes exactly one category the default', () async {
    await repo.upsert(cat('a', 'A', isDefault: true));
    await repo.upsert(cat('b', 'B'));
    await repo.setDefault('b');
    final all = await repo.getAll();
    final defaults = all.where((c) => c.isDefault).map((c) => c.id).toList();
    expect(defaults, ['b']);
  });

  test('deleteOrReassign removes a free (unused) category', () async {
    await repo.upsert(cat('a', 'A'));
    await repo.deleteOrReassign('a');
    expect(await repo.getById('a'), isNull);
  });

  test(
      'deleteOrReassign throws when the category is in use and no '
      'replacement is provided', () async {
    await repo.upsert(cat('a', 'A'));
    await txns.upsert(
      TransactionEntity(
        id: 't1',
        type: TransactionType.expense,
        name: 'Lunch',
        amount: const Money(1000),
        occurredAt: t0,
        createdAt: t0,
        updatedAt: t0,
        categoryId: 'a',
      ),
    );
    expect(
      () => repo.deleteOrReassign('a'),
      throwsA(isA<StateError>()),
    );
    // The category and its transaction must be untouched after the failure.
    expect(await repo.getById('a'), isNotNull);
    expect((await txns.getById('t1'))!.categoryId, 'a');
  });

  test('deleteOrReassign reassigns in-use transactions to the replacement',
      () async {
    await repo.upsert(cat('a', 'A'));
    await repo.upsert(cat('b', 'B'));
    await txns.upsert(
      TransactionEntity(
        id: 't1',
        type: TransactionType.expense,
        name: 'Lunch',
        amount: const Money(1000),
        occurredAt: t0,
        createdAt: t0,
        updatedAt: t0,
        categoryId: 'a',
      ),
    );
    await repo.deleteOrReassign('a', replacementId: 'b');
    expect(await repo.getById('a'), isNull);
    expect((await txns.getById('t1'))!.categoryId, 'b');
  });
}
