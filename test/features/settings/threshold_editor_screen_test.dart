import 'package:budgetsense/app/providers.dart';
import 'package:budgetsense/core/constants/enums.dart';
import 'package:budgetsense/core/theme/app_colors.dart';
import 'package:budgetsense/core/theme/app_theme.dart';
import 'package:budgetsense/core/utils/money.dart';
import 'package:budgetsense/data/database/app_database.dart';
import 'package:budgetsense/data/repositories/category_repository.dart';
import 'package:budgetsense/data/repositories/threshold_repository.dart';
import 'package:budgetsense/domain/entities/transaction_entity.dart';
import 'package:budgetsense/domain/services/threshold_service.dart';
import 'package:budgetsense/features/common/calm_widgets.dart';
import 'package:budgetsense/features/settings/threshold_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

/// Behavioural tests for the threshold editor (Section 11). Each test drives the
/// real screen against its own in-memory database and checks both what the user
/// ends up seeing and what actually landed in storage.

final _t0 = DateTime(2026, 1, 1, 9);

ThresholdRule _rule(
  String id,
  String label, {
  ThresholdType type = ThresholdType.maxPercentage,
  double value = 20,
  String? scopeKey,
  bool enabled = true,
}) =>
    ThresholdRule(
      id: id,
      label: label,
      type: type,
      value: value,
      warningPercent: 0.8,
      criticalPercent: 0.95,
      scopeKey: scopeKey,
      enabled: enabled,
    );

CategoryEntity _cat(String id, String name) => CategoryEntity(
      id: id,
      name: name,
      colorValue: 0xFF112233,
      iconCodePoint: 0xe57f,
      sortOrder: 0,
      createdAt: _t0,
      updatedAt: _t0,
    );

Widget _host(AppDatabase db) {
  final colors = AppColors.light(const Color(0xFFB07C5E));
  return ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: MaterialApp(
      theme: AppThemeBuilder.build(colors, brightness: Brightness.light),
      home: const ThresholdEditorScreen(),
    ),
  );
}

/// A tall phone-sized surface so the whole editor sheet, sliders and Save button
/// included, is on screen and tappable.
void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _pumpScreen(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(_host(db));
  await tester.pumpAndSettle();
}

/// Tears the tree down and closes [db] inside the test.
///
/// Cancelling a drift query stream posts a zero-duration timer. Under
/// `testWidgets` that timer only runs while the fake clock is advancing, so
/// `db.close()` from a bare `addTearDown` would await a timer that never fires
/// and hang the whole suite. See [closeTestDatabase].
Future<void> _unmountScreen(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  await closeTestDatabase(tester, db);
}

Finder _rowFor(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(CalmCard));

Finder _fieldLabelled(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(TextFormField));

Finder _saveButton() => find.widgetWithText(FilledButton, 'Save');

Future<void> _pickFromDropdown<T>(WidgetTester tester, String option) async {
  await tester.tap(find.byType(DropdownButtonFormField<T>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('with no rules the user is told what thresholds are for', (
    tester,
  ) async {
    final db = newTestDatabase();
    await _pumpScreen(tester, db);

    expect(find.text('No thresholds'), findsOneWidget);
    expect(
      find.text(
        'Add a percentage or fixed-amount limit to get gentle nudges when '
        'spending drifts.',
      ),
      findsOneWidget,
    );
    expect(find.byType(Switch), findsNothing);

    await _unmountScreen(tester, db);
  });

  testWidgets('a saved percentage rule is listed and stored as entered', (
    tester,
  ) async {
    _useTallSurface(tester);
    final db = newTestDatabase();
    final repo = DriftThresholdRepository(db);
    await _pumpScreen(tester, db);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('New threshold'), findsOneWidget);

    await tester.enterText(_fieldLabelled('Label'), 'Dining cap');
    await tester.enterText(_fieldLabelled('Percentage (0 to 100)'), '25');
    await tester.tap(_saveButton());
    await tester.pumpAndSettle();

    expect(find.text('New threshold'), findsNothing);
    expect(find.text('No thresholds'), findsNothing);
    expect(find.text('Dining cap'), findsOneWidget);
    expect(find.text('Max 25%'), findsOneWidget);

    final saved = await repo.getAll();
    expect(saved, hasLength(1));
    expect(saved.single.label, 'Dining cap');
    expect(saved.single.type, ThresholdType.maxPercentage);
    expect(saved.single.value, 25);
    expect(saved.single.scopeKey, isNull, reason: 'no scope means whole month');
    expect(saved.single.enabled, isTrue, reason: 'a new rule starts active');
    expect(saved.single.warningPercent, 0.8);
    expect(saved.single.criticalPercent, 0.95);

    await _unmountScreen(tester, db);
  });

  testWidgets('choosing a minimum type flips the rule to a target', (
    tester,
  ) async {
    _useTallSurface(tester);
    final db = newTestDatabase();
    final repo = DriftThresholdRepository(db);
    await _pumpScreen(tester, db);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(_fieldLabelled('Label'), 'Invest at least');
    await _pickFromDropdown<ThresholdType>(tester, 'Minimum %');
    await tester.enterText(_fieldLabelled('Percentage (0 to 100)'), '15');
    await tester.tap(_saveButton());
    await tester.pumpAndSettle();

    expect(find.text('Min 15%'), findsOneWidget);
    final saved = await repo.getAll();
    expect(saved.single.type, ThresholdType.minPercentage);
    expect(saved.single.value, 15);

    await _unmountScreen(tester, db);
  });

  testWidgets('an amount rule relabels the value field and stores minor units',
      (
    tester,
  ) async {
    _useTallSurface(tester);
    final db = newTestDatabase();
    final repo = DriftThresholdRepository(db);
    await _pumpScreen(tester, db);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Percentage (0 to 100)'), findsOneWidget);

    await tester.enterText(_fieldLabelled('Label'), 'Rent cap');
    await _pickFromDropdown<ThresholdType>(tester, 'Maximum amount');

    expect(find.text('Percentage (0 to 100)'), findsNothing);
    expect(find.text('Amount (major units)'), findsOneWidget);

    await tester.enterText(_fieldLabelled('Amount (major units)'), '250');
    await tester.tap(_saveButton());
    await tester.pumpAndSettle();

    expect(find.text('Rent cap'), findsOneWidget);
    final saved = await repo.getAll();
    expect(saved.single.type, ThresholdType.maxAmount);
    // Typed in major units, stored in minor units, so the limit is 250.00.
    expect(saved.single.amountLimit, const Money(25000));

    await _unmountScreen(tester, db);
  });

  testWidgets('a missing label or a non-numeric value blocks the save', (
    tester,
  ) async {
    _useTallSurface(tester);
    final db = newTestDatabase();
    final repo = DriftThresholdRepository(db);
    await _pumpScreen(tester, db);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(_fieldLabelled('Percentage (0 to 100)'), 'abc');
    await tester.tap(_saveButton());
    await tester.pumpAndSettle();

    expect(find.text('Label is required'), findsOneWidget);
    expect(find.text('Enter a number'), findsOneWidget);
    expect(find.text('New threshold'), findsOneWidget, reason: 'sheet stays');
    expect(await repo.getAll(), isEmpty);

    // Fixing only the label is not enough to get past the value check.
    await tester.enterText(_fieldLabelled('Label'), 'Dining cap');
    await tester.tap(_saveButton());
    await tester.pumpAndSettle();

    expect(find.text('Label is required'), findsNothing);
    expect(find.text('Enter a number'), findsOneWidget);
    expect(await repo.getAll(), isEmpty);

    // Once both are valid the same sheet saves, so a typo is recoverable.
    await tester.enterText(_fieldLabelled('Percentage (0 to 100)'), '30');
    await tester.tap(_saveButton());
    await tester.pumpAndSettle();

    expect(find.text('New threshold'), findsNothing);
    expect(find.text('Max 30%'), findsOneWidget);
    expect((await repo.getAll()).single.value, 30);

    await _unmountScreen(tester, db);
  });

  testWidgets('the switch mutes one rule and leaves the others alone', (
    tester,
  ) async {
    final db = newTestDatabase();
    final repo = DriftThresholdRepository(db);
    await repo.upsert(_rule('r1', 'Alpha cap'));
    await repo.upsert(_rule('r2', 'Beta cap'));
    await _pumpScreen(tester, db);

    Finder switchFor(String label) =>
        find.descendant(of: _rowFor(label), matching: find.byType(Switch));

    expect(tester.widget<Switch>(switchFor('Alpha cap')).value, isTrue);

    await tester.tap(switchFor('Alpha cap'));
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(switchFor('Alpha cap')).value, isFalse);
    expect(tester.widget<Switch>(switchFor('Beta cap')).value, isTrue);
    final byId = {for (final r in await repo.getAll()) r.id: r.enabled};
    expect(byId, {'r1': false, 'r2': true});

    // Turning it back on must restore the rule, not lose it.
    await tester.tap(switchFor('Alpha cap'));
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(switchFor('Alpha cap')).value, isTrue);
    expect((await repo.getAll()).every((r) => r.enabled), isTrue);

    await _unmountScreen(tester, db);
  });

  testWidgets('editing a rule updates it in place and keeps it enabled', (
    tester,
  ) async {
    _useTallSurface(tester);
    final db = newTestDatabase();
    final repo = DriftThresholdRepository(db);
    await repo.upsert(_rule('r1', 'Old cap', value: 20));
    await _pumpScreen(tester, db);

    await tester.tap(find.text('Old cap'));
    await tester.pumpAndSettle();
    expect(find.text('Edit threshold'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Old cap'), findsOneWidget);

    await tester.enterText(_fieldLabelled('Label'), 'New cap');
    await tester.enterText(_fieldLabelled('Percentage (0 to 100)'), '35');

    // Pull the warning point down to its floor; the caption must follow.
    expect(find.text('Warning at 80%'), findsOneWidget);
    await tester.drag(find.byType(Slider).first, const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Warning at 50%'), findsOneWidget);

    await tester.tap(_saveButton());
    await tester.pumpAndSettle();

    expect(find.text('New cap'), findsOneWidget);
    expect(find.text('Old cap'), findsNothing);
    expect(find.text('Max 35%'), findsOneWidget);

    final all = await repo.getAll();
    expect(all, hasLength(1), reason: 'an edit must not create a second rule');
    expect(all.single.id, 'r1');
    expect(all.single.label, 'New cap');
    expect(all.single.value, 35);
    expect(all.single.warningPercent, 0.5);
    expect(all.single.criticalPercent, 0.95, reason: 'untouched slider holds');
    expect(all.single.enabled, isTrue);

    await _unmountScreen(tester, db);
  });

  testWidgets('a category limit binds to the category, not to its name', (
    tester,
  ) async {
    _useTallSurface(tester);
    final db = newTestDatabase();
    final thresholds = DriftThresholdRepository(db);
    final categories = DriftCategoryRepository(db);
    await categories.upsert(_cat('c1', 'Groceries'));
    await _pumpScreen(tester, db);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(_fieldLabelled('Label'), 'Grocery cap');
    await tester.enterText(_fieldLabelled('Percentage (0 to 100)'), '30');
    await _pickFromDropdown<String>(tester, 'Groceries');
    await tester.tap(_saveButton());
    await tester.pumpAndSettle();

    expect((await thresholds.getAll()).single.scopeKey, 'c1');
    expect(find.textContaining('Max 30%'), findsOneWidget);
    expect(find.textContaining('Groceries'), findsOneWidget);

    // Renaming the category must re-label the rule rather than orphan it.
    await categories.upsert(_cat('c1', 'Food'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Food'), findsOneWidget);
    expect(find.textContaining('Groceries'), findsNothing);
    expect((await thresholds.getAll()).single.scopeKey, 'c1');

    await _unmountScreen(tester, db);
  });
}
