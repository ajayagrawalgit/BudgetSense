import 'package:budgetsense/core/theme/app_colors.dart';
import 'package:budgetsense/core/theme/app_theme.dart';
import 'package:budgetsense/features/dashboard/mood_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps a widget in a real theme so the AppColors extension resolves exactly
/// as it does at runtime.
///
/// [disableAnimations] mirrors what Android reports when "Remove animations" is
/// switched on, or when Developer Options has the animator duration scale at
/// zero.
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

/// The ring's painter, as a [CustomPainter] so its private type stays private.
CustomPainter _painter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((p) => p.painter)
    .whereType<CustomPainter>()
    .firstWhere((p) => p.runtimeType.toString().contains('Enso'));

void main() {
  group('ensoRingDuration', () {
    test('an ordinary change respects reduce-motion', () {
      expect(
        ensoRingDuration(reduceMotion: true, bloomPlaying: false),
        Duration.zero,
      );
    });

    test('the long-press bloom animates even under reduce-motion', () {
      // Regression: the bloom used to be gated on reduce-motion like every
      // ambient animation, so on a device with animations switched off the
      // ring snapped to full and back and the gesture appeared to do nothing.
      expect(
        ensoRingDuration(reduceMotion: true, bloomPlaying: true),
        kEnsoRingStroke,
      );
    });

    test('normal settings animate', () {
      expect(
        ensoRingDuration(reduceMotion: false, bloomPlaying: false),
        kEnsoRingStroke,
      );
    });
  });

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
    final atRest = _painter(tester);

    await tester.longPress(find.byType(EnsoMoodRing));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // Mid-stroke the ring sits somewhere between 40% and full.
    expect(atRest.shouldRepaint(_painter(tester)), isTrue);

    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
    // It ends up back where the user actually is, and the centre label never
    // moved: the easter egg is purely visual.
    expect(atRest.shouldRepaint(_painter(tester)), isFalse);
    expect(find.text('40%'), findsOneWidget);
  });

  testWidgets('the bloom still brushes when animations are disabled',
      (tester) async {
    await tester.pumpWidget(
      _host(
        const EnsoMoodRing(progress: 0.4, rate: 0.4, complete: false),
        disableAnimations: true,
      ),
    );
    await tester.pumpAndSettle();
    final atRest = _painter(tester);

    await tester.longPress(find.byType(EnsoMoodRing));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      atRest.shouldRepaint(_painter(tester)),
      isTrue,
      reason: 'the whole point of the gesture is the stroke',
    );
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });

  testWidgets('a second long-press mid-bloom is ignored', (tester) async {
    await tester.pumpWidget(
      _host(const EnsoMoodRing(progress: 0.4, rate: 0.4, complete: false)),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.byType(EnsoMoodRing));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.longPress(find.byType(EnsoMoodRing));
    await tester.pumpAndSettle(const Duration(seconds: 4));

    expect(tester.takeException(), isNull);
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
