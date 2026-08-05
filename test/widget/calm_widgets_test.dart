import 'package:budgetsense/core/theme/app_colors.dart';
import 'package:budgetsense/core/theme/app_theme.dart';
import 'package:budgetsense/features/common/brand_watermark.dart';
import 'package:budgetsense/features/common/calm_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Component tests for the shared calm widgets. Wraps them in a real theme so
/// the [AppColors] extension resolves exactly as it does at runtime.
Widget _host(Widget child, {AppThemeVariant variant = AppThemeVariant.light}) {
  final colors = switch (variant) {
    AppThemeVariant.amoled => AppColors.amoled(const Color(0xFFB07C5E)),
    AppThemeVariant.glass =>
      AppColors.glass(const Color(0xFFB07C5E), blurSupported: false),
    AppThemeVariant.dark => AppColors.dark(const Color(0xFFB07C5E)),
    _ => AppColors.light(const Color(0xFFB07C5E)),
  };
  return MaterialApp(
    theme: AppThemeBuilder.build(colors, brightness: Brightness.light),
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('StatTile shows label and value', (tester) async {
    await tester.pumpWidget(
      _host(const StatTile(label: 'Income', value: r'$1,200.00')),
    );
    expect(find.text('Income'), findsOneWidget);
    expect(find.text(r'$1,200.00'), findsOneWidget);
  });

  testWidgets('CalmEmptyState renders title and message', (tester) async {
    await tester.pumpWidget(
      _host(const CalmEmptyState(title: 'Nothing yet', message: 'Add one')),
    );
    expect(find.text('Nothing yet'), findsOneWidget);
    expect(find.text('Add one'), findsOneWidget);
  });

  testWidgets('CalmCard renders its child', (tester) async {
    await tester.pumpWidget(
      _host(const CalmCard(child: Text('inside'))),
    );
    expect(find.text('inside'), findsOneWidget);
  });

  testWidgets('CalmProgressBar clamps overflow without throwing',
      (tester) async {
    await tester.pumpWidget(
      _host(const CalmProgressBar(fraction: 1.8, color: Colors.green)),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('every CalmIllustration motif paints without throwing',
      (tester) async {
    for (final motif in CalmIllustration.values) {
      await tester.pumpWidget(
        _host(
          CalmEmptyState(
            title: 'Empty',
            message: motif.name,
            illustration: motif,
          ),
        ),
      );
      expect(find.text(motif.name), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'motif ${motif.name}');
    }
  });

  testWidgets('BrandWatermark shows its child and never blocks taps',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        BrandWatermark(
          child: Center(
            child: ElevatedButton(
              onPressed: () => taps++,
              child: const Text('press'),
            ),
          ),
        ),
      ),
    );
    expect(find.text('press'), findsOneWidget);
    await tester.tap(find.text('press'));
    expect(taps, 1); // the faint watermark sits behind, not in the way
    expect(tester.takeException(), isNull);
  });
}
