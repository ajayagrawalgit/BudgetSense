import 'package:budgetsense/app/providers.dart';
import 'package:budgetsense/core/constants/enums.dart';
import 'package:budgetsense/core/theme/app_colors.dart';
import 'package:budgetsense/core/theme/app_theme.dart';
import 'package:budgetsense/data/database/app_database.dart';
import 'package:budgetsense/data/repositories/custom_field_repository.dart';
import 'package:budgetsense/domain/entities/config_entities.dart';
import 'package:budgetsense/features/settings/custom_field_manager_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

/// Behavioural tests for the Custom fields manager (Settings > Custom fields).
///
/// A custom field is only useful if what the user typed into the sheet ends up
/// in two places at once: the list in front of them, and the database that every
/// transaction form reads from. Each test drives the real screen against a real
/// in-memory database and checks both.

final _t0 = DateTime(2026, 1, 1, 9);

Widget _host(AppDatabase db) {
  final colors = AppColors.light(const Color(0xFFB07C5E));
  return ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: MaterialApp(
      theme: AppThemeBuilder.build(colors, brightness: Brightness.light),
      home: const CustomFieldManagerScreen(),
    ),
  );
}

CustomFieldEntity _field(
  String id,
  String name, {
  CustomFieldType type = CustomFieldType.text,
  List<String> allowedValues = const [],
  int displayOrder = 0,
}) =>
    CustomFieldEntity(
      id: id,
      name: name,
      fieldType: type,
      displayOrder: displayOrder,
      allowedValues: allowedValues,
      createdAt: _t0,
      updatedAt: _t0,
    );

/// The edit sheet is taller than the 800x600 default test surface, so give the
/// tests a phone-shaped window where every control is genuinely tappable.
void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

Finder _input(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(TextFormField));

/// Advances only the finite Material transitions this screen starts.
///
/// `pumpAndSettle` is unsuitable here because Drift query-stream cleanup and
/// optional shimmer animations may keep scheduling frames. A bounded pump makes
/// the intended UI transition deterministic and prevents a test teardown hang.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> _pickType(WidgetTester tester, String label) async {
  await tester.tap(find.byType(DropdownButtonFormField<CustomFieldType>));
  await _settle(tester);
  // The chosen label also sits on the closed button, so take the menu copy.
  await tester.tap(find.text(label).last);
  await _settle(tester);
}

/// Brings the tree down and closes [db] while the fake clock can still advance.
///
/// Drift holds a query-stream cache open on a zero-duration timer after its
/// last listener goes away. That timer only runs while the clock is being
/// pumped, so closing the database from a bare `addTearDown` would await a
/// timer that never fires and hang the test. See [closeTestDatabase].
Future<void> _unmountScreen(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await _settle(tester);
  await closeTestDatabase(tester, db);
}

void main() {
  testWidgets('a new field is stored with its type, options and required flag',
      (tester) async {
    _useTallSurface(tester);
    final db = newTestDatabase();
    final repo = DriftCustomFieldRepository(db);

    await tester.pumpWidget(_host(db));
    await _settle(tester);
    expect(find.text('No custom fields'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await _settle(tester);
    await tester.enterText(_input('Field name'), 'Mood');
    await _pickType(tester, 'Dropdown');
    await tester.enterText(
      _input('Allowed values (comma separated)'),
      ' Calm , Rushed ',
    );
    await tester.tap(find.byType(SwitchListTile));
    await _settle(tester);
    await tester.tap(find.widgetWithText(FilterChip, 'Expense'));
    await _settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await _settle(tester);

    // What the user sees back on the list.
    expect(find.text('Mood'), findsOneWidget);
    expect(find.text('Dropdown · required'), findsOneWidget);

    // What every transaction form will actually read.
    final saved = (await repo.getAll()).single;
    expect(saved.name, 'Mood');
    expect(saved.fieldType, CustomFieldType.dropdown);
    expect(saved.required, isTrue);
    expect(
      saved.allowedValues,
      ['Calm', 'Rushed'],
      reason: 'options are split on commas and trimmed',
    );
    expect(saved.appliesTo, [TransactionType.expense]);

    await _unmountScreen(tester, db);
  });

  testWidgets('editing a field rewrites the same row instead of adding another',
      (tester) async {
    _useTallSurface(tester);
    final db = newTestDatabase();
    final repo = DriftCustomFieldRepository(db);
    await repo.upsert(_field('trip', 'Trip'));

    await tester.pumpWidget(_host(db));
    await _settle(tester);
    await tester.tap(find.text('Trip'));
    await _settle(tester);
    expect(find.text('Edit field'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(_input('Field name')).controller?.text,
      'Trip',
      reason: 'the sheet opens prefilled so the user edits rather than retypes',
    );

    await tester.enterText(_input('Field name'), 'Journey');
    await _pickType(tester, 'Dropdown');
    await tester.enterText(
      _input('Allowed values (comma separated)'),
      'Solo, Family',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await _settle(tester);

    expect(find.text('Journey'), findsOneWidget);
    expect(find.text('Trip'), findsNothing);

    final all = await repo.getAll();
    expect(all, hasLength(1), reason: 'an edit must not leave a duplicate');
    expect(all.single.id, 'trip');
    expect(all.single.name, 'Journey');
    expect(all.single.fieldType, CustomFieldType.dropdown);
    expect(all.single.allowedValues, ['Solo', 'Family']);
    expect(
      all.single.displayOrder,
      0,
      reason: 'an edited field keeps its place in the list',
    );
    expect(all.single.createdAt, _t0, reason: 'it is not recreated');

    await _unmountScreen(tester, db);
  });

  testWidgets('turning a dropdown field into plain text drops its old options',
      (tester) async {
    _useTallSurface(tester);
    final db = newTestDatabase();
    final repo = DriftCustomFieldRepository(db);
    await repo.upsert(
      _field(
        'mood',
        'Mood',
        type: CustomFieldType.dropdown,
        allowedValues: const ['Calm', 'Rushed'],
      ),
    );

    await tester.pumpWidget(_host(db));
    await _settle(tester);
    await tester.tap(find.text('Mood'));
    await _settle(tester);
    expect(
      find.text('Calm, Rushed'),
      findsOneWidget,
      reason: 'the existing options come back for editing',
    );

    await _pickType(tester, 'Text');
    expect(
      _input('Allowed values (comma separated)'),
      findsNothing,
      reason: 'a plain text field has no options to offer',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await _settle(tester);

    expect(find.text('Text'), findsOneWidget, reason: 'the row shows the type');
    final saved = (await repo.getAll()).single;
    expect(saved.fieldType, CustomFieldType.text);
    expect(
      saved.allowedValues,
      isEmpty,
      reason: 'options nobody can pick any more must not be kept',
    );

    await _unmountScreen(tester, db);
  });

  testWidgets('a field with a blank name is refused and nothing is stored',
      (tester) async {
    _useTallSurface(tester);
    final db = newTestDatabase();
    final repo = DriftCustomFieldRepository(db);

    await tester.pumpWidget(_host(db));
    await _settle(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await _settle(tester);
    await tester.enterText(_input('Field name'), '   ');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await _settle(tester);

    expect(find.text('Field name is required'), findsOneWidget);
    expect(
      find.text('New field'),
      findsOneWidget,
      reason: 'the sheet stays open so the mistake can be fixed',
    );
    expect(await repo.getAll(), isEmpty);

    await _unmountScreen(tester, db);
  });

  testWidgets('deleting a field removes it from the list and the database',
      (tester) async {
    _useTallSurface(tester);
    final db = newTestDatabase();
    final repo = DriftCustomFieldRepository(db);
    await repo.upsert(_field('mood', 'Mood'));
    await repo.upsert(_field('trip', 'Trip', displayOrder: 1));

    await tester.pumpWidget(_host(db));
    await _settle(tester);
    await tester.tap(find.byTooltip('Delete Mood'));
    await _settle(tester);

    expect(find.text('Mood'), findsNothing);
    expect(find.text('Trip'), findsOneWidget, reason: 'only one field goes');
    expect(
        (await repo.getAll(includeArchived: true)).map((f) => f.id), ['trip']);

    await _unmountScreen(tester, db);
  });
}
