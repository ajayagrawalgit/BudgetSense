import 'package:budgetsense/app/providers.dart';
import 'package:budgetsense/core/constants/enums.dart';
import 'package:budgetsense/core/theme/app_colors.dart';
import 'package:budgetsense/core/theme/app_theme.dart';
import 'package:budgetsense/core/utils/money.dart';
import 'package:budgetsense/data/database/app_database.dart';
import 'package:budgetsense/data/repositories/transaction_repository.dart';
import 'package:budgetsense/domain/entities/transaction_entity.dart';
import 'package:budgetsense/features/common/calm_widgets.dart';
import 'package:budgetsense/features/settings/trash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/test_database.dart';

/// Behavioural tests for the Trash can (Settings > Trash).
///
/// Trash is the app's safety net, so the tests cover the promises that matter
/// when someone is standing in front of their own deleted money: restore really
/// brings an entry back, delete forever only happens once the question has been
/// answered yes, and emptying the Trash never reaches past the archived rows.

final _t0 = DateTime(2026, 1, 1, 9);

Widget _host(AppDatabase db) {
  final colors = AppColors.light(const Color(0xFFB07C5E));
  return ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: MaterialApp(
      theme: AppThemeBuilder.build(colors, brightness: Brightness.light),
      home: const TrashScreen(),
    ),
  );
}

TransactionEntity _txn(String id, String name) => TransactionEntity(
      id: id,
      type: TransactionType.expense,
      name: name,
      amount: const Money(50000),
      occurredAt: _t0,
      createdAt: _t0,
      updatedAt: _t0,
    );

Future<void> _trash(
    DriftTransactionRepository repo, String id, String name) async {
  await repo.upsert(_txn(id, name));
  await repo.archive(id);
}

/// The action buttons carry the same tooltips on every row, so scope the lookup
/// to the card that names the entry the user is aiming at.
Finder _rowAction(String name, String tooltip) => find.descendant(
      of: find.ancestor(of: find.text(name), matching: find.byType(CalmCard)),
      matching: find.byTooltip(tooltip),
    );

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
  testWidgets('restoring an entry takes it out of Trash and back into history',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = newTestDatabase();
    final repo = DriftTransactionRepository(db);
    await _trash(repo, 'coffee', 'Coffee');
    await _trash(repo, 'rent', 'Rent');

    await tester.pumpWidget(_host(db));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 items in Trash'), findsOneWidget);

    await tester.tap(_rowAction('Coffee', 'Restore'));
    await tester.pumpAndSettle();

    expect(find.text('Coffee'), findsNothing);
    expect(find.text('Rent'), findsOneWidget, reason: 'only one entry moved');
    expect(find.textContaining('1 item in Trash'), findsOneWidget);
    expect(find.text('Restored "Coffee"'), findsOneWidget);

    final restored = await repo.getById('coffee');
    expect(
      restored!.isArchived,
      isFalse,
      reason: 'a restored entry counts in the month again',
    );
    expect((await repo.getById('rent'))!.isArchived, isTrue);

    await _unmountScreen(tester, db);
  });

  testWidgets('cancelling delete forever keeps the entry in Trash',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = newTestDatabase();
    final repo = DriftTransactionRepository(db);
    await _trash(repo, 'coffee', 'Coffee');

    await tester.pumpWidget(_host(db));
    await tester.pumpAndSettle();
    await tester.tap(_rowAction('Coffee', 'Delete forever'));
    await tester.pumpAndSettle();
    expect(find.text('Delete forever?'), findsOneWidget);
    expect(find.textContaining('permanently removed'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Delete forever?'), findsNothing);
    expect(find.text('Coffee'), findsOneWidget);
    final kept = await repo.getById('coffee');
    expect(kept, isNotNull, reason: 'saying no must not delete anything');
    expect(kept!.isArchived, isTrue, reason: 'it stays in the Trash');

    await _unmountScreen(tester, db);
  });

  testWidgets('confirming delete forever destroys only that entry',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = newTestDatabase();
    final repo = DriftTransactionRepository(db);
    await _trash(repo, 'coffee', 'Coffee');
    await _trash(repo, 'rent', 'Rent');

    await tester.pumpWidget(_host(db));
    await tester.pumpAndSettle();
    await tester.tap(_rowAction('Coffee', 'Delete forever'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete forever'));
    await tester.pumpAndSettle();

    expect(find.text('Coffee'), findsNothing);
    expect(find.text('Rent'), findsOneWidget);
    expect(find.textContaining('1 item in Trash'), findsOneWidget);
    expect(await repo.getById('coffee'), isNull, reason: 'gone for good');
    expect(await repo.getById('rent'), isNotNull);

    await _unmountScreen(tester, db);
  });

  testWidgets('emptying Trash clears the archived rows and spares live ones',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = newTestDatabase();
    final repo = DriftTransactionRepository(db);
    await _trash(repo, 'coffee', 'Coffee');
    await _trash(repo, 'rent', 'Rent');
    await repo.upsert(_txn('salary', 'Salary'));

    await tester.pumpWidget(_host(db));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Empty'));
    await tester.pumpAndSettle();
    expect(find.text('Empty Trash?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Empty Trash'));
    await tester.pumpAndSettle();

    expect(find.text('Trash is empty'), findsOneWidget);
    expect(find.text('Trash emptied. A clean slate.'), findsOneWidget);
    expect(
      find.text('Empty'),
      findsNothing,
      reason: 'nothing left to empty, so the action is withdrawn',
    );
    expect(await repo.getById('coffee'), isNull);
    expect(await repo.getById('rent'), isNull);
    expect(
      await repo.getById('salary'),
      isNotNull,
      reason: 'emptying Trash must never touch live transactions',
    );

    await _unmountScreen(tester, db);
  });
}
