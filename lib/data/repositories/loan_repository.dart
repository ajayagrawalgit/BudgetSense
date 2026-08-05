import 'package:drift/drift.dart';

import '../../domain/entities/commitment_entities.dart';
import '../database/app_database.dart';
import '../mappers/entity_mappers.dart';

/// Repository for loans & liabilities (Section 9).
abstract interface class LoanRepository {
  Stream<List<LoanEntity>> watchAll({bool includeArchived = false});
  Future<List<LoanEntity>> getAll({bool includeArchived = false});
  Future<LoanEntity?> getById(String id);
  Future<void> upsert(LoanEntity entity);
  Future<void> archive(String id);
  Future<void> delete(String id);
}

class DriftLoanRepository implements LoanRepository {
  DriftLoanRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<LoanEntity>> watchAll({bool includeArchived = false}) {
    final query = _db.select(_db.loans)
      ..orderBy([(l) => OrderingTerm.asc(l.name)]);
    if (!includeArchived) {
      query.where((l) => l.archivedAt.isNull());
    }
    return query.watch().map((rows) => rows.map(LoanMapper.toEntity).toList());
  }

  @override
  Future<List<LoanEntity>> getAll({bool includeArchived = false}) async {
    final query = _db.select(_db.loans)
      ..orderBy([(l) => OrderingTerm.asc(l.name)]);
    if (!includeArchived) {
      query.where((l) => l.archivedAt.isNull());
    }
    final rows = await query.get();
    return rows.map(LoanMapper.toEntity).toList();
  }

  @override
  Future<LoanEntity?> getById(String id) async {
    final row = await (_db.select(_db.loans)..where((l) => l.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : LoanMapper.toEntity(row);
  }

  @override
  Future<void> upsert(LoanEntity entity) => _db
      .into(_db.loans)
      .insertOnConflictUpdate(LoanMapper.toCompanion(entity));

  @override
  Future<void> archive(String id) =>
      (_db.update(_db.loans)..where((l) => l.id.equals(id))).write(
        LoansCompanion(
          archivedAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );

  @override
  Future<void> delete(String id) =>
      (_db.delete(_db.loans)..where((l) => l.id.equals(id))).go();
}
