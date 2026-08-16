import 'package:budgetsense/core/theme/app_colors.dart';
import 'package:budgetsense/core/theme/app_theme.dart';
import 'package:budgetsense/domain/services/import_service.dart';
import 'package:budgetsense/features/settings/import/import_hub_screen.dart';
import 'package:budgetsense/features/settings/import/paisa_import_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Behavioural tests for the list of apps BudgetSense can import from.
///
/// The hub's whole job is routing: every source it lists has to open that
/// source's own import screen, and it has to still be there when the reader
/// backs out. A [ProviderScope] wraps it because the screen it pushes is a
/// consumer, exactly as in the app.

Widget _host() => ProviderScope(
      child: MaterialApp(
        theme: AppThemeBuilder.build(
          AppColors.light(const Color(0xFFB07C5E)),
          brightness: Brightness.light,
        ),
        home: const ImportHubScreen(),
      ),
    );

Future<void> _tapSource(WidgetTester tester, ImportSource source) async {
  await tester.tap(find.text(source.label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('every available source opens its own import screen',
      (tester) async {
    final available = ImportSource.values.where((s) => s.available);
    expect(available, isNotEmpty, reason: 'the hub would be a dead end');

    for (final source in available) {
      await tester.pumpWidget(_host());
      expect(find.text('Available sources'), findsOneWidget);

      await _tapSource(tester, source);

      // Landed on that source's screen, carrying that source's identity: the
      // title and the how-to instructions both come from the tapped source.
      expect(find.byType(PaisaImportScreen), findsOneWidget);
      expect(
        tester.widget<PaisaImportScreen>(find.byType(PaisaImportScreen)).source,
        source,
      );
      expect(find.text('Import from ${source.label}'), findsOneWidget);
      expect(find.text(source.howTo), findsOneWidget);
      expect(find.text('Choose ${source.label} backup file'), findsOneWidget);

      // And the hub itself is out of the way.
      expect(find.text('Available sources'), findsNothing);
    }
  });

  testWidgets('the hub is still there after backing out of a source',
      (tester) async {
    await tester.pumpWidget(_host());

    await _tapSource(tester, ImportSource.paisa);
    expect(find.byType(PaisaImportScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    // Tapping the wrong app is not a one-way door: the list of sources is back
    // and can be used again.
    expect(find.byType(PaisaImportScreen), findsNothing);
    expect(find.text('Available sources'), findsOneWidget);
    expect(find.text('Import from another app'), findsOneWidget);

    await _tapSource(tester, ImportSource.paisa);
    expect(find.byType(PaisaImportScreen), findsOneWidget);
  });

  testWidgets('each source is described by its own tagline', (tester) async {
    await tester.pumpWidget(_host());

    // A reader scanning the list has to be able to tell the entries apart, so
    // each tagline must sit in the row of the app it belongs to.
    for (final source in ImportSource.values) {
      final tile = find
          .ancestor(of: find.text(source.label), matching: find.byType(Row))
          .first;
      expect(
        find.descendant(of: tile, matching: find.text(source.tagline)),
        findsOneWidget,
        reason: '${source.label} must show its own tagline',
      );
    }
  });
}
