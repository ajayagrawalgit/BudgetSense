import 'package:drift/drift.dart';

import '../../core/utils/financial_calendar.dart';
import '../../domain/entities/transaction_entity.dart';
import '../database/app_database.dart';
import '../mappers/transaction_mapper.dart';

/// Repository for transaction persistence. The rest of the app depends on this
/// abstraction, never on Drift directly (repository pattern, Section 22).
abstract interface class TransactionRepository {
  Stream<List<TransactionEntity>> watchForMonth(
    DateTime anyDateInMonth, {
    required FinancialCalendar calendar,
  });

  /// Live stream of soft-deleted (archived) transactions - the Trash can.
  /// Ordered by when they were removed, newest first.
  Stream<List<TransactionEntity>> watchArchived();

  Future<List<TransactionEntity>> getInRange(DateRange range);

  /// Live stream of non-archived transactions whose date falls in [range].
  /// Powers the no-spend graph widget, which needs many months of history.
  Stream<List<TransactionEntity>> watchInRange(DateRange range);

  Future<TransactionEntity?> getById(String id);

  Future<void> upsert(TransactionEntity entity);

  Future<void> archive(String id);

  Future<void> unarchive(String id);

  Future<void> delete(String id);

  Future<void> deleteMany(List<String> ids);

  /// Permanently removes every archived (trashed) transaction.
  Future<void> emptyTrash();

  /// The most recent non-archived transaction date, or null when empty. Used
  /// after an import to focus the month that actually has data.
  Future<DateTime?> latestActiveDate();

  /// The most recent (non-archived) transaction linked to [loanId], newest
  /// first. Powers the loan card's "last EMI recorded" line.
  Future<TransactionEntity?> latestForLoan(String loanId);
}

class DriftTransactionRepository implements TransactionRepository {
  DriftTransactionRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<TransactionEntity>> watchForMonth(
    DateTime anyDateInMonth, {
    required FinancialCalendar calendar,
  }) {
    final range = calendar.monthRangeFor(anyDateInMonth);
    final query = _db.select(_db.transactions)
      ..where(
        (t) =>
            t.occurredAt.isBiggerOrEqualValue(range.start) &
            t.occurredAt.isSmallerOrEqualValue(range.end) &
            t.archivedAt.isNull(),
      )
      ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)]);
    return query.watch().map(
          (rows) => rows.map(TransactionMapper.toEntity).toList(),
        );
  }

  @override
  Stream<List<TransactionEntity>> watchArchived() {
    final query = _db.select(_db.transactions)
      ..where((t) => t.archivedAt.isNotNull())
      ..orderBy([(t) => OrderingTerm.desc(t.archivedAt)]);
    return query.watch().map(
          (rows) => rows.map(TransactionMapper.toEntity).toList(),
        );
  }

  @override
  Future<List<TransactionEntity>> getInRange(DateRange range) async {
    final query = _db.select(_db.transactions)
      ..where(
        (t) =>
            t.occurredAt.isBiggerOrEqualValue(range.start) &
            t.occurredAt.isSmallerOrEqualValue(range.end),
      )
      ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)]);
    final rows = await query.get();
    return rows.map(TransactionMapper.toEntity).toList();
  }

  @override
  Stream<List<TransactionEntity>> watchInRange(DateRange range) {
    final query = _db.select(_db.transactions)
      ..where(
        (t) =>
            t.occurredAt.isBiggerOrEqualValue(range.start) &
            t.occurredAt.isSmallerOrEqualValue(range.end) &
            t.archivedAt.isNull(),
      )
      ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)]);
    return query.watch().map(
          (rows) => rows.map(TransactionMapper.toEntity).toList(),
        );
  }

  @override
  Future<TransactionEntity?> getById(String id) async {
    final row = await (_db.select(_db.transactions)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : TransactionMapper.toEntity(row);
  }

  @override
  Future<void> upsert(TransactionEntity entity) {
    return _db
        .into(_db.transactions)
        .insertOnConflictUpdate(TransactionMapper.toCompanion(entity));
  }

  @override
  Future<void> archive(String id) => _touchArchive(id, DateTime.now());

  @override
  Future<void> unarchive(String id) => _touchArchive(id, null);

  Future<void> _touchArchive(String id, DateTime? when) {
    return (_db.update(_db.transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(
        archivedAt: Value(when),
        updatedAt: Value(DateTime.now()),
        syncStatus: const Value(1), // pendingUpload
      ),
    );
  }

  @override
  Future<void> delete(String id) {
    return (_db.delete(_db.transactions)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<void> deleteMany(List<String> ids) {
    if (ids.isEmpty) return Future.value();
    return (_db.delete(_db.transactions)..where((t) => t.id.isIn(ids))).go();
  }

  @override
  Future<void> emptyTrash() {
    return (_db.delete(_db.transactions)
          ..where((t) => t.archivedAt.isNotNull()))
        .go();
  }

  @override
  Future<DateTime?> latestActiveDate() async {
    final query = _db.select(_db.transactions)
      ..where((t) => t.archivedAt.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
      ..limit(1);
    final row = await query.getSingleOrNull();
    return row?.occurredAt;
  }

  @override
  Future<TransactionEntity?> latestForLoan(String loanId) async {
    final query = _db.select(_db.transactions)
      ..where((t) => t.linkedLoanId.equals(loanId) & t.archivedAt.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
      ..limit(1);
    final row = await query.getSingleOrNull();
    return row == null ? null : TransactionMapper.toEntity(row);
  }
}
