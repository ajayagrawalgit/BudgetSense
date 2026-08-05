import 'package:budgetsense/features/common/feedback_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String _money(int minor) => '\$${(minor / 100).toStringAsFixed(2)}';

class _Host extends StatefulWidget {
  const _Host({required this.initial});
  final int initial;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late int _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            AnimatedMoneyText(minorUnits: _value, format: _money),
            TextButton(
              onPressed: () => setState(() => _value = 200000),
              child: const Text('bump'),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  group('AnimatedMoneyText', () {
    testWidgets('shows the value immediately on first build', (tester) async {
      await tester.pumpWidget(const _Host(initial: 12345));
      // No count-up from zero on first render.
      expect(find.text('\$123.45'), findsOneWidget);
    });

    testWidgets('animates to and lands on the new value', (tester) async {
      await tester.pumpWidget(const _Host(initial: 12345));
      await tester.tap(find.text('bump'));
      await tester.pump(); // start the tween
      await tester.pumpAndSettle();
      expect(find.text('\$2000.00'), findsOneWidget);
      expect(find.text('\$123.45'), findsNothing);
    });
  });

  group('SuccessCheck', () {
    testWidgets('draws and then reports completion once', (tester) async {
      var completions = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SuccessCheck(onCompleted: () => completions++),
            ),
          ),
        ),
      );
      expect(completions, 0); // not done on first frame
      await tester.pumpAndSettle();
      expect(completions, 1); // fired exactly once when the draw finishes
    });
  });
}
