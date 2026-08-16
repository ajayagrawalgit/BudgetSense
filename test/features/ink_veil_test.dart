import 'package:budgetsense/core/theme/app_colors.dart';
import 'package:budgetsense/core/theme/app_theme.dart';
import 'package:budgetsense/features/common/calm_widgets.dart';
import 'package:budgetsense/features/common/ink_veil.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {bool disableAnimations = false}) {
  final colors = AppColors.light(const Color(0xFFB07C5E));
  return MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: MaterialApp(
      theme: AppThemeBuilder.build(colors, brightness: Brightness.light),
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  group('InkVeil', () {
    testWidgets('hides the figure from screen readers until revealed',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(const InkVeil(revealed: false, child: Text('12,345'))),
      );
      await tester.pumpAndSettle();

      // The concealed amount must never reach assistive tech, otherwise the
      // eye toggle is theatre.
      expect(find.bySemanticsLabel('12,345'), findsNothing);
      expect(
        find.bySemanticsLabel('Amount hidden. Tap the eye icon to reveal.'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('paints no brushwork once revealed', (tester) async {
      await tester.pumpWidget(
        _host(const InkVeil(revealed: true, child: Text('12,345'))),
      );
      await tester.pumpAndSettle();

      final veils = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .where((p) => p.painter is InkVeilPainter);
      expect(veils, isEmpty);
    });

    testWidgets('keeps the child in the tree so layout does not jump',
        (tester) async {
      // The figure is faded out rather than removed: swapping it for a
      // SizedBox would resize the card every time the eye is tapped.
      await tester.pumpWidget(
        _host(const InkVeil(revealed: false, child: Text('12,345'))),
      );
      await tester.pumpAndSettle();
      expect(find.text('12,345'), findsOneWidget);
      expect(tester.getSize(find.text('12,345')).width, greaterThan(0));
    });

    test('different seeds produce different brushwork', () {
      const ink = Color(0xFF2B2A27);
      const accent = Color(0xFFB07C5E);
      final a = InkVeilPainter(ink: ink, accent: accent, seed: 1);
      final b = InkVeilPainter(ink: ink, accent: accent, seed: 2);
      expect(a.shouldRepaint(b), isTrue);
      expect(
        a.shouldRepaint(InkVeilPainter(ink: ink, accent: accent, seed: 1)),
        isFalse,
      );
    });
  });

  group('StatTile', () {
    testWidgets('keeps its label readable while the amount is veiled',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          const StatTile(label: 'Income', value: '98,000', revealed: false),
        ),
      );
      await tester.pumpAndSettle();

      // You should still know what the tile measures, just not how much.
      expect(find.text('Income'), findsOneWidget);

      final label = tester.getSemantics(find.byType(StatTile)).label;
      expect(label, contains('Income'));
      expect(label, contains('hidden'));
      expect(
        label,
        isNot(contains('98,000')),
        reason: 'a concealed amount must never reach assistive tech',
      );
      handle.dispose();
    });

    testWidgets('announces the amount normally when revealed', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(const StatTile(label: 'Income', value: '98,000')),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.byType(StatTile)).label,
        contains('Income: 98,000'),
      );
      handle.dispose();
    });
  });
}
