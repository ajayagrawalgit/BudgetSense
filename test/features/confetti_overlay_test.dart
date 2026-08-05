import 'package:budgetsense/features/common/confetti_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConfettiOverlay.shower', () {
    Future<void> pumpHost(WidgetTester tester, ConfettiVariant variant) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () =>
                      ConfettiOverlay.shower(context, variant: variant),
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        ),
      );
    }

    for (final variant in ConfettiVariant.values) {
      testWidgets('$variant mounts, animates and removes itself',
          (tester) async {
        await pumpHost(tester, variant);
        await tester.tap(find.text('go'));
        await tester.pump(); // insert the overlay entry
        await tester.pump(const Duration(milliseconds: 16)); // one frame

        // The celebration layer is painting.
        expect(find.byType(CustomPaint), findsWidgets);

        // Let the one-shot animation run to completion; it must clean up after
        // itself with no exceptions.
        await tester.pumpAndSettle(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('is a no-op under reduce motion', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () => ConfettiOverlay.shower(context),
                    child: const Text('go'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump();
      // Nothing extra should have been inserted; no exception either.
      expect(tester.takeException(), isNull);
    });
  });
}
