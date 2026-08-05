import 'package:budgetsense/core/constants/enums.dart';
import 'package:budgetsense/core/utils/money.dart';
import 'package:budgetsense/data/database/app_database.dart';
import 'package:budgetsense/data/repositories/reference_repository.dart';
import 'package:budgetsense/data/repositories/transaction_repository.dart';
import 'package:budgetsense/domain/entities/config_entities.dart';
import 'package:budgetsense/domain/entities/transaction_entity.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  late AppDatabase db;
  late DriftAccountRepository accounts;
  late DriftPaymentMethodRepository methods;
  late DriftTransactionRepository txns;

  final t0 = DateTime(2026, 1, 1, 9);

  AccountEntity account(String id, String name, {int sortOrder = 0}) =>
      AccountEntity(
        id: id,
        name: name,
        sortOrder: sortOrder,
        createdAt: t0,
        updatedAt: t0,
      );

  PaymentMethodEntity method(String id, String name, {int sortOrder = 0}) =>
      PaymentMethodEntity(
        id: id,
        name: name,
        sortOrder: sortOrder,
        createdAt: t0,
        updatedAt: t0,
      );

  setUp(() {
    db = newTestDatabase();
    accounts = DriftAccountRepository(db);
    methods = DriftPaymentMethodRepository(db);
    txns = DriftTransactionRepository(db);
  });

  tearDown(() => db.close());

  group('AccountRepository', () {
    test('upsert then getAll round-trips and orders by sortOrder', () async {
      await accounts.upsert(account('b', 'Bank', sortOrder: 1));
      await accounts.upsert(account('a', 'Cash', sortOrder: 0));
      final all = await accounts.getAll();
      expect(all.map((a) => a.id), ['a', 'b']);
      expect(all.first.name, 'Cash');
    });

    test('archive hides the account from the default list', () async {
      await accounts.upsert(account('a', 'Cash'));
      await accounts.archive('a');
      expect(await accounts.getAll(), isEmpty);
      expect(
        (await accounts.getAll(includeArchived: true)).map((a) => a.id),
        ['a'],
      );
    });

    test('watchAll emits live accounts', () async {
      await accounts.upsert(account('a', 'Cash'));
      final first = await accounts.watchAll().first;
      expect(first.single.id, 'a');
    });

    test('delete nullifies the accountId on referencing transactions',
        () async {
      await accounts.upsert(account('a', 'Cash'));
      await txns.upsert(
        TransactionEntity(
          id: 't1',
          type: TransactionType.expense,
          name: 'Lunch',
          amount: const Money(1000),
          occurredAt: t0,
          createdAt: t0,
          updatedAt: t0,
          accountId: 'a',
        ),
      );
      await accounts.delete('a');
      expect(await accounts.getAll(includeArchived: true), isEmpty);
      expect((await txns.getById('t1'))!.accountId, isNull);
    });
  });

  group('PaymentMethodRepository', () {
    test('upsert then getAll round-trips and orders by sortOrder', () async {
      await methods.upsert(method('b', 'UPI', sortOrder: 1));
      await methods.upsert(method('a', 'Cash', sortOrder: 0));
      expect((await methods.getAll()).map((m) => m.id), ['a', 'b']);
    });

    test('archive hides the method from the default list', () async {
      await methods.upsert(method('a', 'Cash'));
      await methods.archive('a');
      expect(await methods.getAll(), isEmpty);
      expect(
        (await methods.getAll(includeArchived: true)).map((m) => m.id),
        ['a'],
      );
    });

    test('delete nullifies the paymentMethodId on referencing transactions',
        () async {
      await methods.upsert(method('a', 'Cash'));
      await txns.upsert(
        TransactionEntity(
          id: 't1',
          type: TransactionType.expense,
          name: 'Lunch',
          amount: const Money(1000),
          occurredAt: t0,
          createdAt: t0,
          updatedAt: t0,
          paymentMethodId: 'a',
        ),
      );
      await methods.delete('a');
      expect(await methods.getAll(includeArchived: true), isEmpty);
      expect((await txns.getById('t1'))!.paymentMethodId, isNull);
    });
  });
}
