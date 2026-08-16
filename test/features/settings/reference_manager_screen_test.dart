import 'package:budgetsense/app/providers.dart';
import 'package:budgetsense/core/constants/enums.dart';
import 'package:budgetsense/core/theme/app_colors.dart';
import 'package:budgetsense/core/theme/app_theme.dart';
import 'package:budgetsense/core/utils/money.dart';
import 'package:budgetsense/data/database/app_database.dart';
import 'package:budgetsense/data/repositories/reference_repository.dart';
import 'package:budgetsense/data/repositories/transaction_repository.dart';
import 'package:budgetsense/domain/entities/config_entities.dart';
import 'package:budgetsense/domain/entities/transaction_entity.dart';
import 'package:budgetsense/features/settings/reference_manager_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

/// Behavioural tests for the Accounts and Payment methods managers, which are
/// the two thin wrappers over [ReferenceManagerBody].
///
/// These lists feed every transaction form, so the promises worth pinning down
/// are: what the user types is stored, an edit renames in place rather than
/// duplicating, cancelling changes nothing, and deleting an account never takes
/// spend history with it.

final _t0 = DateTime(2026, 1, 1, 9);

Widget _host(AppDatabase db, Widget screen) {
  final colors = AppColors.light(const Color(0xFFB07C5E));
  return ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: MaterialApp(
      theme: AppThemeBuilder.build(colors, brightness: Brightness.light),
      home: screen,
    ),
  );
}

AccountEntity _account(String id, String name, int sortOrder) => AccountEntity(
      id: id,
      name: name,
      sortOrder: sortOrder,
      createdAt: _t0,
      updatedAt: _t0,
    );

Finder _nameField() => find.byType(TextField);

Future<void> _tapSave(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Save'));
  await tester.pumpAndSettle();
}

/// Drift holds a query-stream cache open on a zero-duration timer after its last
/// listener goes away. Bringing the tree down here, while the fake clock can
/// still be advanced, lets that timer fire; left to the binding's own teardown it
/// is reported as a timer still pending after the test.
Future<void> _unmountScreen(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  await closeTestDatabase(tester, db);
}

void main() {
  testWidgets('adding an account lists it and stores it', (tester) async {
    final db = newTestDatabase();
    final accounts = DriftAccountRepository(db);

    await tester.pumpWidget(_host(db, const AccountsManagerScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Add accounts like Cash, Bank, or Card.'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(_nameField(), 'HDFC Bank');
    await _tapSave(tester);

    expect(find.text('HDFC Bank'), findsOneWidget);
    expect(find.text('Nothing here yet'), findsNothing);

    final stored = (await accounts.getAll()).single;
    expect(stored.name, 'HDFC Bank');
    expect(stored.sortOrder, 0, reason: 'the first account sorts first');

    await _unmountScreen(tester, db);
  });

  testWidgets('renaming an account keeps one row and its place in the list',
      (tester) async {
    final db = newTestDatabase();
    final accounts = DriftAccountRepository(db);
    await accounts.upsert(_account('a1', 'Bank', 0));
    await accounts.upsert(_account('a2', 'Wallet', 1));

    await tester.pumpWidget(_host(db, const AccountsManagerScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bank'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(_nameField()).controller?.text,
      'Bank',
      reason:
          'the dialog opens prefilled so the user edits rather than retypes',
    );

    await tester.enterText(_nameField(), 'Union Bank');
    await _tapSave(tester);

    expect(find.text('Union Bank'), findsOneWidget);
    expect(find.text('Bank'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Union Bank')).dy <
          tester.getTopLeft(find.text('Wallet')).dy,
      isTrue,
      reason: 'a rename must not shuffle the list',
    );

    final stored = await accounts.getAll();
    expect(stored.map((a) => a.name), ['Union Bank', 'Wallet']);
    expect(stored.first.id, 'a1', reason: 'the same row was updated');
    expect(stored.first.createdAt, _t0);

    await _unmountScreen(tester, db);
  });

  testWidgets('cancelling the rename dialog leaves the account untouched',
      (tester) async {
    final db = newTestDatabase();
    final accounts = DriftAccountRepository(db);
    await accounts.upsert(_account('a1', 'Bank', 0));

    await tester.pumpWidget(_host(db, const AccountsManagerScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bank'));
    await tester.pumpAndSettle();
    await tester.enterText(_nameField(), 'Typed by mistake');
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Typed by mistake'), findsNothing);
    expect(find.text('Bank'), findsOneWidget);
    expect((await accounts.getAll()).single.name, 'Bank');

    await _unmountScreen(tester, db);
  });

  testWidgets('a blank name is not saved as an account', (tester) async {
    final db = newTestDatabase();
    final accounts = DriftAccountRepository(db);

    await tester.pumpWidget(_host(db, const AccountsManagerScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(_nameField(), '   ');
    await _tapSave(tester);

    expect(find.text('Nothing here yet'), findsOneWidget);
    expect(
      await accounts.getAll(),
      isEmpty,
      reason: 'a nameless account would be unpickable in every form',
    );

    await _unmountScreen(tester, db);
  });

  testWidgets('deleting an account unlinks its transactions but keeps them',
      (tester) async {
    final db = newTestDatabase();
    final accounts = DriftAccountRepository(db);
    final transactions = DriftTransactionRepository(db);
    await accounts.upsert(_account('a1', 'Bank', 0));
    await transactions.upsert(
      TransactionEntity(
        id: 't1',
        type: TransactionType.expense,
        name: 'Groceries',
        amount: const Money(120000),
        occurredAt: _t0,
        createdAt: _t0,
        updatedAt: _t0,
        accountId: 'a1',
      ),
    );

    await tester.pumpWidget(_host(db, const AccountsManagerScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete Bank'));
    await tester.pumpAndSettle();

    expect(find.text('Bank'), findsNothing);
    expect(find.text('Nothing here yet'), findsOneWidget);
    expect(await accounts.getAll(includeArchived: true), isEmpty);

    final txn = await transactions.getById('t1');
    expect(txn, isNotNull, reason: 'spend history outlives an account');
    expect(txn!.accountId, isNull, reason: 'it is simply unlinked');

    await _unmountScreen(tester, db);
  });

  testWidgets('payment methods are stored apart from accounts', (tester) async {
    final db = newTestDatabase();
    final methods = DriftPaymentMethodRepository(db);
    final accounts = DriftAccountRepository(db);

    await tester.pumpWidget(_host(db, const PaymentMethodsManagerScreen()));
    await tester.pumpAndSettle();
    expect(
      find.text('Add methods like UPI, Cash, or Credit card.'),
      findsOneWidget,
    );

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(_nameField(), 'UPI');
    await _tapSave(tester);

    expect(find.text('UPI'), findsOneWidget);
    expect((await methods.getAll()).single.name, 'UPI');
    expect(
      await accounts.getAll(),
      isEmpty,
      reason: 'a payment method must not land in the accounts list',
    );

    await _unmountScreen(tester, db);
  });
}
