import 'package:budgetsense/app/providers.dart';
import 'package:budgetsense/core/constants/enums.dart';
import 'package:budgetsense/core/theme/app_colors.dart';
import 'package:budgetsense/core/theme/app_theme.dart';
import 'package:budgetsense/core/utils/money.dart';
import 'package:budgetsense/data/database/app_database.dart';
import 'package:budgetsense/data/repositories/category_repository.dart';
import 'package:budgetsense/data/repositories/transaction_repository.dart';
import 'package:budgetsense/domain/entities/transaction_entity.dart';
import 'package:budgetsense/features/common/calm_widgets.dart';
import 'package:budgetsense/features/settings/category_manager_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

/// Behavioural tests for the category manager (Section 5). Every test drives the
/// real screen against its own in-memory database and asserts both what the user
/// ends up seeing and what actually landed in storage.

final _t0 = DateTime(2026, 1, 1, 9);

CategoryEntity _cat(
  String id,
  String name, {
  int sortOrder = 0,
  bool isDefault = false,
  int iconCodePoint = 0xe57f,
}) =>
    CategoryEntity(
      id: id,
      name: name,
      colorValue: 0xFF112233,
      iconCodePoint: iconCodePoint,
      sortOrder: sortOrder,
      isDefault: isDefault,
      createdAt: _t0,
      updatedAt: _t0,
    );

TransactionEntity _txn(String id, String categoryId) => TransactionEntity(
      id: id,
      type: TransactionType.expense,
      name: 'Lunch',
      amount: const Money(1000),
      occurredAt: _t0,
      createdAt: _t0,
      updatedAt: _t0,
      categoryId: categoryId,
    );

Widget _host(AppDatabase db) {
  final colors = AppColors.light(const Color(0xFFB07C5E));
  return ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: MaterialApp(
      theme: AppThemeBuilder.build(colors, brightness: Brightness.light),
      home: const CategoryManagerScreen(),
    ),
  );
}

/// A tall phone-sized surface so the editor sheet is fully reachable.
void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _pumpScreen(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(_host(db));
  await tester.pumpAndSettle();
}

/// Tears the tree down inside the test. Cancelling a drift query stream posts a
/// zero-duration timer, and the framework's own end-of-test unmount does not
/// pump long enough to drain it, which would fail the "no pending timers" check.
Future<void> _unmountScreen(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  await closeTestDatabase(tester, db);
}

Finder _rowFor(String name) =>
    find.ancestor(of: find.text(name), matching: find.byType(CalmCard));

Finder _menuFor(String name) =>
    find.descendant(of: _rowFor(name), matching: find.byIcon(Icons.more_vert));

Finder _saveButton() => find.widgetWithText(FilledButton, 'Save');

/// The names that are currently on screen, ordered the way the user reads them.
List<String> _asDisplayed(WidgetTester tester, List<String> names) {
  return names.where((n) => find.text(n).evaluate().isNotEmpty).toList()
    ..sort(
      (a, b) => tester
          .getCenter(find.text(a))
          .dy
          .compareTo(tester.getCenter(find.text(b)).dy),
    );
}

Future<void> _openMenuAndPick(
  WidgetTester tester,
  String name,
  String action,
) async {
  await tester.tap(_menuFor(name));
  await tester.pumpAndSettle();
  await tester.tap(find.text(action));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('with nothing saved the user is told how to start', (
    tester,
  ) async {
    final db = newTestDatabase();
    await _pumpScreen(tester, db);

    expect(find.text('No categories'), findsOneWidget);
    expect(
      find.text('Add your first category to organize spending.'),
      findsOneWidget,
    );
    expect(find.byType(ReorderableListView), findsNothing);

    await _unmountScreen(tester, db);
  });

  testWidgets('saving a new category lists it and stores its fields', (
    tester,
  ) async {
    _useTallSurface(tester);
    final db = newTestDatabase();
    final repo = DriftCategoryRepository(db);
    await _pumpScreen(tester, db);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('New category'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '  Groceries  ');
    await tester.pumpAndSettle();
    await tester.tap(_saveButton());
    await tester.pumpAndSettle();

    expect(find.text('New category'), findsNothing);
    expect(find.text('No categories'), findsNothing);
    expect(find.text('Groceries'), findsOneWidget);

    final saved = await repo.getAll();
    expect(saved, hasLength(1));
    expect(saved.single.name, 'Groceries');
    expect(saved.single.colorValue, CategoryManagerScreen.palette.first);
    // The name drives the icon when the user never opened the picker.
    expect(
      saved.single.iconCodePoint,
      Icons.local_grocery_store_outlined.codePoint,
    );
    expect(saved.single.isDefault, isFalse);
    expect(saved.single.archivedAt, isNull);

    await _unmountScreen(tester, db);
  });

  testWidgets('a blank name is refused and writes nothing', (tester) async {
    _useTallSurface(tester);
    final db = newTestDatabase();
    final repo = DriftCategoryRepository(db);
    await _pumpScreen(tester, db);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(_saveButton());
    await tester.pumpAndSettle();

    expect(find.text('Name is required'), findsOneWidget);
    expect(find.text('New category'), findsOneWidget, reason: 'sheet stays');
    expect(await repo.getAll(), isEmpty);

    // Whitespace is not a name either.
    await tester.enterText(find.byType(TextFormField), '    ');
    await tester.tap(_saveButton());
    await tester.pumpAndSettle();

    expect(find.text('Name is required'), findsOneWidget);
    expect(await repo.getAll(), isEmpty);

    await _unmountScreen(tester, db);
  });

  testWidgets('editing renames and recolours the same row in place', (
    tester,
  ) async {
    _useTallSurface(tester);
    final db = newTestDatabase();
    final repo = DriftCategoryRepository(db);
    await repo.upsert(_cat('c1', 'Food', sortOrder: 4, isDefault: true));
    await _pumpScreen(tester, db);

    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    expect(find.text('Edit category'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Food'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'Groceries');
    final swatches = find.descendant(
      of: find.byType(Wrap),
      matching: find.byType(GestureDetector),
    );
    expect(swatches, findsNWidgets(CategoryManagerScreen.palette.length));
    await tester.tap(swatches.at(3));
    await tester.pumpAndSettle();
    await tester.tap(_saveButton());
    await tester.pumpAndSettle();

    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Food'), findsNothing);

    final all = await repo.getAll();
    expect(all, hasLength(1), reason: 'an edit must not create a second row');
    expect(all.single.id, 'c1');
    expect(all.single.name, 'Groceries');
    expect(all.single.colorValue, CategoryManagerScreen.palette[3]);
    expect(all.single.sortOrder, 4, reason: 'position survives an edit');
    expect(all.single.isDefault, isTrue, reason: 'default flag survives');
    expect(all.single.createdAt, _t0);
    // Renaming must not silently re-run icon auto-detection over a saved icon.
    expect(all.single.iconCodePoint, 0xe57f);

    await _unmountScreen(tester, db);
  });

  testWidgets('deleting an unused category drops it everywhere', (
    tester,
  ) async {
    final db = newTestDatabase();
    final repo = DriftCategoryRepository(db);
    await repo.upsert(_cat('c1', 'Food'));
    await repo.upsert(_cat('c2', 'Travel', sortOrder: 1));
    await _pumpScreen(tester, db);

    await _openMenuAndPick(tester, 'Food', 'Delete');

    expect(find.text('Food'), findsNothing);
    expect(find.text('Travel'), findsOneWidget);
    expect(
      (await repo.getAll(includeArchived: true)).map((c) => c.id),
      ['c2'],
    );

    await _unmountScreen(tester, db);
  });

  testWidgets('deleting a category in use reassigns its transactions', (
    tester,
  ) async {
    final db = newTestDatabase();
    final repo = DriftCategoryRepository(db);
    final txns = DriftTransactionRepository(db);
    await repo.upsert(_cat('c1', 'Food'));
    await repo.upsert(_cat('c2', 'Travel', sortOrder: 1));
    await txns.upsert(_txn('t1', 'c1'));
    await _pumpScreen(tester, db);

    await _openMenuAndPick(tester, 'Food', 'Delete');

    expect(find.text('Reassign transactions to'), findsOneWidget);
    // The category being deleted must not be offered as its own replacement.
    // Scope this to the dialog: the list behind it legitimately still shows
    // "Food" until the deletion is confirmed.
    expect(
      find.descendant(
        of: find.byType(SimpleDialog),
        matching: find.text('Food'),
      ),
      findsNothing,
      reason: 'cannot replace itself',
    );
    expect(
      find.descendant(
        of: find.byType(SimpleDialog),
        matching: find.text('Travel'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(SimpleDialog),
        matching: find.text('Travel'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Food'), findsNothing);
    expect(find.text('Travel'), findsOneWidget);
    expect(await repo.getById('c1'), isNull);
    expect((await txns.getById('t1'))!.categoryId, 'c2');

    await _unmountScreen(tester, db);
  });

  testWidgets('backing out of the reassign prompt keeps the category and data',
      (
    tester,
  ) async {
    final db = newTestDatabase();
    final repo = DriftCategoryRepository(db);
    final txns = DriftTransactionRepository(db);
    await repo.upsert(_cat('c1', 'Food'));
    await repo.upsert(_cat('c2', 'Travel', sortOrder: 1));
    await txns.upsert(_txn('t1', 'c1'));
    await _pumpScreen(tester, db);

    await _openMenuAndPick(tester, 'Food', 'Delete');
    expect(find.text('Reassign transactions to'), findsOneWidget);

    // Tap the scrim above the dialog to dismiss it without choosing.
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    expect(find.text('Reassign transactions to'), findsNothing);
    expect(find.text('Food'), findsOneWidget);
    expect(await repo.getById('c1'), isNotNull);
    expect((await txns.getById('t1'))!.categoryId, 'c1');

    await _unmountScreen(tester, db);
  });

  testWidgets('setting a default moves the badge and leaves exactly one', (
    tester,
  ) async {
    final db = newTestDatabase();
    final repo = DriftCategoryRepository(db);
    await repo.upsert(_cat('c1', 'Food', isDefault: true));
    await repo.upsert(_cat('c2', 'Travel', sortOrder: 1));
    await _pumpScreen(tester, db);

    expect(
      find.descendant(of: _rowFor('Food'), matching: find.text('Default')),
      findsOneWidget,
    );

    await _openMenuAndPick(tester, 'Travel', 'Set default');

    expect(find.text('Default'), findsOneWidget);
    expect(
      find.descendant(of: _rowFor('Travel'), matching: find.text('Default')),
      findsOneWidget,
    );
    final all = await repo.getAll();
    expect(all.where((c) => c.isDefault).map((c) => c.id), ['c2']);

    await _unmountScreen(tester, db);
  });

  testWidgets('archiving hides the category without destroying the record', (
    tester,
  ) async {
    final db = newTestDatabase();
    final repo = DriftCategoryRepository(db);
    await repo.upsert(_cat('c1', 'Food'));
    await repo.upsert(_cat('c2', 'Travel', sortOrder: 1));
    await _pumpScreen(tester, db);

    await _openMenuAndPick(tester, 'Food', 'Archive');

    expect(find.text('Food'), findsNothing);
    expect(find.text('Travel'), findsOneWidget);
    expect((await repo.getAll()).map((c) => c.id), ['c2']);

    final archived = await repo.getById('c1');
    expect(archived, isNotNull, reason: 'archive is not a delete');
    expect(archived!.archivedAt, isNotNull);

    await _unmountScreen(tester, db);
  });

  testWidgets('dragging a category to the top persists the new order', (
    tester,
  ) async {
    final db = newTestDatabase();
    final repo = DriftCategoryRepository(db);
    await repo.upsert(_cat('c1', 'Food'));
    await repo.upsert(_cat('c2', 'Travel', sortOrder: 1));
    await repo.upsert(_cat('c3', 'Rent', sortOrder: 2));
    await _pumpScreen(tester, db);

    const names = ['Food', 'Travel', 'Rent'];
    expect(_asDisplayed(tester, names), ['Food', 'Travel', 'Rent']);

    final start = tester.getCenter(find.text('Rent'));
    final target = tester.getCenter(find.text('Food'));
    final drag = await tester.startGesture(start);
    await tester.pump(kLongPressTimeout + kPressTimeout);
    // ReorderableListView recalculates the drop slot as the pointer moves, so
    // walk the gesture up in steps and pump between them. A single jump can
    // land a slot short. Overshoot above Food's centre so the item is
    // unambiguously in the first position.
    await drag.moveTo(Offset(start.dx, start.dy - 20));
    await tester.pump();
    final travel = start.dy - (target.dy - 24);
    for (var i = 1; i <= 8; i++) {
      await drag.moveTo(Offset(start.dx, start.dy - travel * i / 8));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await drag.up();
    await tester.pumpAndSettle();

    expect(_asDisplayed(tester, names), ['Rent', 'Food', 'Travel']);
    expect((await repo.getAll()).map((c) => c.id), ['c3', 'c1', 'c2']);

    await _unmountScreen(tester, db);
  });
}
