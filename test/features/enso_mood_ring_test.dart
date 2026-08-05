import 'package:budgetsense/core/theme/app_colors.dart';
import 'package:budgetsense/core/theme/app_theme.dart';
import 'package:budgetsense/features/dashboard/mood_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps a widget in a real theme so the AppColors extension resolves exactly
/// as it does at runtime.
Widget _host(Widget child) {
  final colors = AppColors.light(const Color(0xFFB07C5E));
  return MaterialApp(
    theme: AppThemeBuilder.build(colors, brightness: Brightness.light),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets('EnsoMoodRing shows the saved percentage', (tester) async {
    await tester.pumpWidget(
      _host(const EnsoMoodRing(progress: 0.4, rate: 0.4, complete: false)),
    );
    await tester.pumpAndSettle();
    expect(find.text('40%'), findsOneWidget);
    expect(find.text('saved'), findsOneWidget);
  });

  testWidgets('long-press blooms the ring and then settles back cleanly',
      (tester) async {
    await tester.pumpWidget(
      _host(const EnsoMoodRing(progress: 0.4, rate: 0.4, complete: false)),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.byType(EnsoMoodRing));
    // Part-way through the bloom: nothing should have thrown.
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);

    // Let the bloom (1150ms) and the settle-back tween finish.
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    // The centre label is unchanged: the easter egg is purely visual.
    expect(find.text('40%'), findsOneWidget);
  });

  testWidgets('a complete ring paints without throwing', (tester) async {
    await tester.pumpWidget(
      _host(const EnsoMoodRing(progress: 1, rate: 0.9, complete: true)),
    );
    await tester.pumpAndSettle();
    expect(find.text('90%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
