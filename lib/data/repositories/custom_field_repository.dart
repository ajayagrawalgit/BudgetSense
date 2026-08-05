import 'package:drift/drift.dart';

import '../../domain/entities/config_entities.dart';
import '../database/app_database.dart';
import '../mappers/entity_mappers.dart';

/// Repository for custom-field definitions (Section 6).
abstract interface class CustomFieldRepository {
  Stream<List<CustomFieldEntity>> watchAll({bool includeArchived = false});
  Future<List<CustomFieldEntity>> getAll({bool includeArchived = false});
  Future<void> upsert(CustomFieldEntity entity);
  Future<void> reorder(List<String> orderedIds);
  Future<void> archive(String id);
  Future<void> delete(String id);
}

class DriftCustomFieldRepository implements CustomFieldRepository {
  DriftCustomFieldRepository(this._db);
  final AppDatabase _db;

  @override
  Stream<List<CustomFieldEntity>> watchAll({bool includeArchived = false}) {
    final q = _db.select(_db.customFields)
      ..orderBy([(f) => OrderingTerm.asc(f.displayOrder)]);
    if (!includeArchived) q.where((f) => f.archivedAt.isNull());
    return q.watch().map((r) => r.map(CustomFieldMapper.toEntity).toList());
  }

  @override
  Future<List<CustomFieldEntity>> getAll({bool includeArchived = false}) async {
    final q = _db.select(_db.customFields)
      ..orderBy([(f) => OrderingTerm.asc(f.displayOrder)]);
    if (!includeArchived) q.where((f) => f.archivedAt.isNull());
    return (await q.get()).map(CustomFieldMapper.toEntity).toList();
  }

  @override
  Future<void> upsert(CustomFieldEntity entity) => _db
      .into(_db.customFields)
      .insertOnConflictUpdate(CustomFieldMapper.toCompanion(entity));

  @override
  Future<void> reorder(List<String> orderedIds) async {
    await _db.batch((b) {
      for (var i = 0; i < orderedIds.length; i++) {
        b.update(
          _db.customFields,
          CustomFieldsCompanion(
            displayOrder: Value(i),
            updatedAt: Value(DateTime.now()),
          ),
          where: (f) => f.id.equals(orderedIds[i]),
        );
      }
    });
  }

  @override
  Future<void> archive(String id) =>
      (_db.update(_db.customFields)..where((f) => f.id.equals(id))).write(
        CustomFieldsCompanion(
          archivedAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );

  @override
  Future<void> delete(String id) async {
    await _db.transaction(() async {
      await (_db.delete(_db.customFieldValues)
            ..where((v) => v.fieldId.equals(id)))
          .go();
      await (_db.delete(_db.customFields)..where((f) => f.id.equals(id))).go();
    });
  }
}
