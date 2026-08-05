import 'package:budgetsense/core/constants/enums.dart';
import 'package:budgetsense/data/database/app_database.dart';
import 'package:budgetsense/data/repositories/custom_field_repository.dart';
import 'package:budgetsense/domain/entities/config_entities.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  late AppDatabase db;
  late DriftCustomFieldRepository repo;

  final t0 = DateTime(2026, 1, 1, 9);

  CustomFieldEntity field(
    String id,
    String name, {
    int displayOrder = 0,
    List<String> allowedValues = const [],
    List<TransactionType> appliesTo = const [],
    DateTime? archivedAt,
  }) =>
      CustomFieldEntity(
        id: id,
        name: name,
        fieldType: CustomFieldType.text,
        displayOrder: displayOrder,
        createdAt: t0,
        updatedAt: t0,
        allowedValues: allowedValues,
        appliesTo: appliesTo,
        archivedAt: archivedAt,
      );

  setUp(() {
    db = newTestDatabase();
    repo = DriftCustomFieldRepository(db);
  });

  tearDown(() => db.close());

  test('upsert round-trips including list-encoded fields', () async {
    await repo.upsert(
      field(
        'f1',
        'Merchant',
        allowedValues: ['Amazon', 'Local'],
        appliesTo: [TransactionType.expense, TransactionType.income],
      ),
    );
    final loaded = (await repo.getAll()).single;
    expect(loaded.name, 'Merchant');
    expect(loaded.allowedValues, ['Amazon', 'Local']);
    expect(loaded.appliesTo, [TransactionType.expense, TransactionType.income]);
  });

  test('getAll orders by displayOrder and hides archived by default', () async {
    await repo.upsert(field('b', 'B', displayOrder: 1));
    await repo.upsert(field('a', 'A', displayOrder: 0));
    await repo.upsert(field('z', 'Z', displayOrder: 5, archivedAt: t0));
    expect((await repo.getAll()).map((f) => f.id), ['a', 'b']);
    expect(
      (await repo.getAll(includeArchived: true)).map((f) => f.id).toSet(),
      {'a', 'b', 'z'},
    );
  });

  test('watchAll emits ordered live fields', () async {
    await repo.upsert(field('a', 'A', displayOrder: 1));
    await repo.upsert(field('b', 'B', displayOrder: 0));
    final first = await repo.watchAll().first;
    expect(first.map((f) => f.id), ['b', 'a']);
  });

  test('reorder rewrites displayOrder', () async {
    await repo.upsert(field('a', 'A', displayOrder: 0));
    await repo.upsert(field('b', 'B', displayOrder: 1));
    await repo.reorder(['b', 'a']);
    expect((await repo.getAll()).map((f) => f.id), ['b', 'a']);
  });

  test('archive removes the field from the live list', () async {
    await repo.upsert(field('a', 'A'));
    await repo.archive('a');
    expect(await repo.getAll(), isEmpty);
  });

  test('delete cascades to stored custom-field values', () async {
    await repo.upsert(field('a', 'A'));
    await db.into(db.customFieldValues).insert(
          CustomFieldValuesCompanion.insert(
            id: 'v1',
            fieldId: 'a',
            ownerId: 'txn-1',
            ownerType: 'transaction',
            value: const Value('hello'),
            createdAt: t0,
            updatedAt: t0,
          ),
        );
    expect(await db.select(db.customFieldValues).get(), hasLength(1));

    await repo.delete('a');

    expect(await repo.getAll(includeArchived: true), isEmpty);
    expect(await db.select(db.customFieldValues).get(), isEmpty);
  });
}
