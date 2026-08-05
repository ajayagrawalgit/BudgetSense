import 'package:drift/drift.dart';

import '../../domain/entities/config_entities.dart';
import '../database/app_database.dart';
import '../mappers/entity_mappers.dart';

/// Repository for accounts (Section 18).
abstract interface class AccountRepository {
  Stream<List<AccountEntity>> watchAll({bool includeArchived = false});
  Future<List<AccountEntity>> getAll({bool includeArchived = false});
  Future<void> upsert(AccountEntity entity);
  Future<void> archive(String id);
  Future<void> delete(String id);
}

class DriftAccountRepository implements AccountRepository {
  DriftAccountRepository(this._db);
  final AppDatabase _db;

  @override
  Stream<List<AccountEntity>> watchAll({bool includeArchived = false}) {
    final q = _db.select(_db.accounts)
      ..orderBy([(a) => OrderingTerm.asc(a.sortOrder)]);
    if (!includeArchived) q.where((a) => a.archivedAt.isNull());
    return q.watch().map((r) => r.map(AccountMapper.toEntity).toList());
  }

  @override
  Future<List<AccountEntity>> getAll({bool includeArchived = false}) async {
    final q = _db.select(_db.accounts)
      ..orderBy([(a) => OrderingTerm.asc(a.sortOrder)]);
    if (!includeArchived) q.where((a) => a.archivedAt.isNull());
    return (await q.get()).map(AccountMapper.toEntity).toList();
  }

  @override
  Future<void> upsert(AccountEntity entity) => _db
      .into(_db.accounts)
      .insertOnConflictUpdate(AccountMapper.toCompanion(entity));

  @override
  Future<void> archive(String id) =>
      (_db.update(_db.accounts)..where((a) => a.id.equals(id))).write(
        AccountsCompanion(
          archivedAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );

  @override
  Future<void> delete(String id) async {
    await _db.transaction(() async {
      // Nullify references in transactions that use this account.
      await (_db.update(_db.transactions)..where((t) => t.accountId.equals(id)))
          .write(const TransactionsCompanion(accountId: Value(null)));
      // Nullify references in recurring payments.
      await (_db.update(_db.recurringPayments)
            ..where((r) => r.accountId.equals(id)))
          .write(const RecurringPaymentsCompanion(accountId: Value(null)));
      await (_db.delete(_db.accounts)..where((a) => a.id.equals(id))).go();
    });
  }
}

/// Repository for payment methods (Section 18).
abstract interface class PaymentMethodRepository {
  Stream<List<PaymentMethodEntity>> watchAll({bool includeArchived = false});
  Future<List<PaymentMethodEntity>> getAll({bool includeArchived = false});
  Future<void> upsert(PaymentMethodEntity entity);
  Future<void> archive(String id);
  Future<void> delete(String id);
}

class DriftPaymentMethodRepository implements PaymentMethodRepository {
  DriftPaymentMethodRepository(this._db);
  final AppDatabase _db;

  @override
  Stream<List<PaymentMethodEntity>> watchAll({bool includeArchived = false}) {
    final q = _db.select(_db.paymentMethods)
      ..orderBy([(m) => OrderingTerm.asc(m.sortOrder)]);
    if (!includeArchived) q.where((m) => m.archivedAt.isNull());
    return q.watch().map((r) => r.map(PaymentMethodMapper.toEntity).toList());
  }

  @override
  Future<List<PaymentMethodEntity>> getAll({
    bool includeArchived = false,
  }) async {
    final q = _db.select(_db.paymentMethods)
      ..orderBy([(m) => OrderingTerm.asc(m.sortOrder)]);
    if (!includeArchived) q.where((m) => m.archivedAt.isNull());
    return (await q.get()).map(PaymentMethodMapper.toEntity).toList();
  }

  @override
  Future<void> upsert(PaymentMethodEntity entity) => _db
      .into(_db.paymentMethods)
      .insertOnConflictUpdate(PaymentMethodMapper.toCompanion(entity));

  @override
  Future<void> archive(String id) =>
      (_db.update(_db.paymentMethods)..where((m) => m.id.equals(id))).write(
        PaymentMethodsCompanion(
          archivedAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );

  @override
  Future<void> delete(String id) async {
    await _db.transaction(() async {
      // Nullify references in transactions that use this payment method.
      await (_db.update(_db.transactions)
            ..where((t) => t.paymentMethodId.equals(id)))
          .write(const TransactionsCompanion(paymentMethodId: Value(null)));
      await (_db.delete(_db.paymentMethods)..where((m) => m.id.equals(id)))
          .go();
    });
  }
}
