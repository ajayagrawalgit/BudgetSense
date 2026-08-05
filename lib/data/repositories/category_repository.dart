import 'package:drift/drift.dart';

import '../../core/constants/enums.dart';
import '../../domain/entities/transaction_entity.dart';
import '../database/app_database.dart';

/// Repository for expense categories. Enforces the spec rule that a category
/// in use may not be deleted without choosing a replacement (Section 5).
abstract interface class CategoryRepository {
  Stream<List<CategoryEntity>> watchAll({bool includeArchived = false});
  Future<List<CategoryEntity>> getAll({bool includeArchived = false});
  Future<CategoryEntity?> getById(String id);
  Future<void> upsert(CategoryEntity entity);
  Future<void> reorder(List<String> orderedIds);
  Future<void> setDefault(String id);

  /// Deletes [id]; if any transactions reference it they are reassigned to
  /// [replacementId] first. Throws if in use and no replacement is given.
  Future<void> deleteOrReassign(String id, {String? replacementId});
}

class DriftCategoryRepository implements CategoryRepository {
  DriftCategoryRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<CategoryEntity>> watchAll({bool includeArchived = false}) {
    final query = _db.select(_db.categories)
      ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]);
    if (!includeArchived) {
      query.where((c) => c.archivedAt.isNull());
    }
    return query.watch().map((rows) => rows.map(_toEntity).toList());
  }

  @override
  Future<List<CategoryEntity>> getAll({bool includeArchived = false}) async {
    final query = _db.select(_db.categories)
      ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]);
    if (!includeArchived) {
      query.where((c) => c.archivedAt.isNull());
    }
    final rows = await query.get();
    return rows.map(_toEntity).toList();
  }

  @override
  Future<CategoryEntity?> getById(String id) async {
    final row = await (_db.select(_db.categories)
          ..where((c) => c.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<void> upsert(CategoryEntity entity) {
    return _db.into(_db.categories).insertOnConflictUpdate(
          CategoriesCompanion.insert(
            id: entity.id,
            name: entity.name,
            colorValue: entity.colorValue,
            iconCodePoint: entity.iconCodePoint,
            sortOrder: Value(entity.sortOrder),
            isDefault: Value(entity.isDefault),
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt,
            archivedAt: Value(entity.archivedAt),
            syncStatus: Value(entity.syncStatus.index),
          ),
        );
  }

  @override
  Future<void> reorder(List<String> orderedIds) async {
    await _db.batch((b) {
      for (var i = 0; i < orderedIds.length; i++) {
        b.update(
          _db.categories,
          CategoriesCompanion(
            sortOrder: Value(i),
            updatedAt: Value(DateTime.now()),
          ),
          where: (c) => c.id.equals(orderedIds[i]),
        );
      }
    });
  }

  @override
  Future<void> setDefault(String id) async {
    await _db.transaction(() async {
      await _db.update(_db.categories).write(
            const CategoriesCompanion(isDefault: Value(false)),
          );
      await (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
        CategoriesCompanion(
          isDefault: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  @override
  Future<void> deleteOrReassign(String id, {String? replacementId}) async {
    await _db.transaction(() async {
      final inUseByTxns = await (_db.select(_db.transactions)
            ..where((t) => t.categoryId.equals(id))
            ..limit(1))
          .get();

      final inUseByPayments = await (_db.select(_db.recurringPayments)
            ..where((r) => r.categoryId.equals(id))
            ..limit(1))
          .get();

      if (inUseByTxns.isNotEmpty || inUseByPayments.isNotEmpty) {
        if (replacementId == null) {
          throw StateError(
            'Category is in use. Provide a replacement category before deleting.',
          );
        }
        await (_db.update(_db.transactions)
              ..where((t) => t.categoryId.equals(id)))
            .write(TransactionsCompanion(categoryId: Value(replacementId)));
        await (_db.update(_db.recurringPayments)
              ..where((r) => r.categoryId.equals(id)))
            .write(
          RecurringPaymentsCompanion(categoryId: Value(replacementId)),
        );
      }

      await (_db.delete(_db.categories)..where((c) => c.id.equals(id))).go();
    });
  }

  CategoryEntity _toEntity(Category row) => CategoryEntity(
        id: row.id,
        name: row.name,
        colorValue: row.colorValue,
        iconCodePoint: row.iconCodePoint,
        sortOrder: row.sortOrder,
        isDefault: row.isDefault,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        archivedAt: row.archivedAt,
        syncStatus: SyncStatus.values[row.syncStatus],
      );
}
