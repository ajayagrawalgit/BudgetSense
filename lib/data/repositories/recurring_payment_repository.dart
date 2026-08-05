import 'package:drift/drift.dart';

import '../../domain/entities/commitment_entities.dart';
import '../database/app_database.dart';
import '../mappers/entity_mappers.dart';

/// Repository for recurring payments & investments (Section 7).
abstract interface class RecurringPaymentRepository {
  Stream<List<RecurringPaymentEntity>> watchAll({bool includeArchived = false});
  Future<List<RecurringPaymentEntity>> getAll({bool includeArchived = false});
  Future<RecurringPaymentEntity?> getById(String id);
  Future<void> upsert(RecurringPaymentEntity entity);
  Future<void> archive(String id);
  Future<void> delete(String id);
}

class DriftRecurringPaymentRepository implements RecurringPaymentRepository {
  DriftRecurringPaymentRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<RecurringPaymentEntity>> watchAll({
    bool includeArchived = false,
  }) {
    final query = _db.select(_db.recurringPayments)
      ..orderBy([(r) => OrderingTerm.asc(r.nextDueDate)]);
    if (!includeArchived) {
      query.where((r) => r.archivedAt.isNull());
    }
    return query
        .watch()
        .map((rows) => rows.map(RecurringPaymentMapper.toEntity).toList());
  }

  @override
  Future<List<RecurringPaymentEntity>> getAll({
    bool includeArchived = false,
  }) async {
    final query = _db.select(_db.recurringPayments)
      ..orderBy([(r) => OrderingTerm.asc(r.nextDueDate)]);
    if (!includeArchived) {
      query.where((r) => r.archivedAt.isNull());
    }
    final rows = await query.get();
    return rows.map(RecurringPaymentMapper.toEntity).toList();
  }

  @override
  Future<RecurringPaymentEntity?> getById(String id) async {
    final row = await (_db.select(_db.recurringPayments)
          ..where((r) => r.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : RecurringPaymentMapper.toEntity(row);
  }

  @override
  Future<void> upsert(RecurringPaymentEntity entity) => _db
      .into(_db.recurringPayments)
      .insertOnConflictUpdate(RecurringPaymentMapper.toCompanion(entity));

  @override
  Future<void> archive(String id) =>
      (_db.update(_db.recurringPayments)..where((r) => r.id.equals(id))).write(
        RecurringPaymentsCompanion(
          archivedAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );

  @override
  Future<void> delete(String id) =>
      (_db.delete(_db.recurringPayments)..where((r) => r.id.equals(id))).go();
}
