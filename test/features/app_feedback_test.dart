import 'package:budgetsense/features/common/app_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hosts a single button so a test can trigger feedback from a context that
/// really sits under a Scaffold, the way every call site does.
Widget _host(void Function(BuildContext context) onTap) => MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => onTap(context),
            child: const Text('go'),
          ),
        ),
      ),
    );

Future<void> _tapGo(WidgetTester tester) async {
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
}

void main() {
  group('showMessage', () {
    testWidgets('puts the message on screen', (tester) async {
      await tester.pumpWidget(_host((c) => c.showMessage('Saved that one')));
      await _tapGo(tester);

      expect(find.text('Saved that one'), findsOneWidget);
    });

    testWidgets('replaces the previous message instead of queueing behind it',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host((c) => c.showMessage(taps++ == 0 ? 'first' : 'second')),
      );

      await tester.tap(find.text('go'));
      await tester.pump();
      expect(find.text('first'), findsOneWidget);

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      // The reader sees the newest line, not a backlog they have to wait out.
      expect(find.text('second'), findsOneWidget);
      expect(find.text('first'), findsNothing);
    });

    testWidgets('runs the action when its label is tapped', (tester) async {
      var ran = false;
      await tester.pumpWidget(
        _host(
          (c) => c.showMessage(
            'Sent',
            actionLabel: 'Retry',
            onAction: () => ran = true,
          ),
        ),
      );
      await _tapGo(tester);

      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(ran, isTrue);
    });
  });

  group('showUndoMessage', () {
    testWidgets('offers Undo and hands the caller back control',
        (tester) async {
      var undone = false;
      await tester.pumpWidget(
        _host(
          (c) => c.showUndoMessage(
            'Moved "Chai" to Trash',
            onUndo: () => undone = true,
          ),
        ),
      );
      await _tapGo(tester);

      expect(find.text('Moved "Chai" to Trash'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pump();

      expect(undone, isTrue);
    });

    testWidgets('stays up for the full undo window', (tester) async {
      await tester.pumpWidget(
        _host((c) => c.showUndoMessage('Gone in a moment', onUndo: () {})),
      );
      await _tapGo(tester);

      // Ten seconds, not the Material default of four: an Undo the reader
      // cannot reach in time is worse than no Undo at all.
      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(bar.duration, kUndoWindow);
    });
  });

  group('confirm', () {
    testWidgets('resolves true only when the confirm button is pressed',
        (tester) async {
      bool? answer;
      await tester.pumpWidget(
        _host((c) async {
          answer = await c.confirm(
            title: 'Delete forever?',
            message: 'This cannot be undone.',
            confirmLabel: 'Delete forever',
            destructive: true,
          );
        }),
      );
      await _tapGo(tester);

      expect(find.text('Delete forever?'), findsOneWidget);
      expect(find.text('This cannot be undone.'), findsOneWidget);

      await tester.tap(find.text('Delete forever'));
      await tester.pumpAndSettle();

      expect(answer, isTrue);
    });

    testWidgets('resolves false when cancelled', (tester) async {
      bool? answer;
      await tester.pumpWidget(
        _host((c) async {
          answer = await c.confirm(
            title: 'Empty Trash?',
            message: 'Everything goes.',
            confirmLabel: 'Empty Trash',
          );
        }),
      );
      await _tapGo(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(answer, isFalse);
    });

    testWidgets('treats a dismissed dialog as a no', (tester) async {
      bool? answer;
      await tester.pumpWidget(
        _host((c) async {
          answer = await c.confirm(
            title: 'Restore from a backup?',
            message: 'Nothing existing is changed.',
            confirmLabel: 'Restore',
          );
        }),
      );
      await _tapGo(tester);

      // Tapping the barrier is the accidental way out, and must not confirm.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(answer, isFalse);
    });

    testWidgets('renders a rich body when one is given instead of prose',
        (tester) async {
      await tester.pumpWidget(
        _host(
          (c) => c.confirm(
            title: 'Import profile details too?',
            confirmLabel: 'Yes, import profile',
            cancelLabel: 'No, keep mine',
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [Text('Change name'), Text('Change currency')],
            ),
          ),
        ),
      );
      await _tapGo(tester);

      expect(find.text('Change name'), findsOneWidget);
      expect(find.text('Change currency'), findsOneWidget);
      expect(find.text('No, keep mine'), findsOneWidget);
    });
  });
}
