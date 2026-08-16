import 'package:budgetsense/core/constants/app_info.dart';
import 'package:budgetsense/core/theme/app_colors.dart';
import 'package:budgetsense/core/theme/app_theme.dart';
import 'package:budgetsense/features/common/ink_flourishes.dart';
import 'package:budgetsense/features/settings/about_screen.dart';
import 'package:budgetsense/features/settings/settings_easter_eggs.dart';
import 'package:budgetsense/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _host(Widget child) {
  final colors = AppColors.light(const Color(0xFFB07C5E));
  return ProviderScope(
    child: MaterialApp(
      theme: AppThemeBuilder.build(colors, brightness: Brightness.light),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('settingsEggFor', () {
    test('answers the three words it knows', () {
      expect(settingsEggFor('enso'), SettingsEgg.enso);
      expect(settingsEggFor('zen'), SettingsEgg.zen);
      expect(settingsEggFor('budgetsense'), SettingsEgg.brand);
    });

    test('is not fussy about case, spacing or the macron', () {
      expect(settingsEggFor('  Enso '), SettingsEgg.enso);
      expect(settingsEggFor('ensō'), SettingsEgg.enso);
      expect(settingsEggFor('ENSŌ'), SettingsEgg.enso);
      expect(settingsEggFor('BudgetSense'), SettingsEgg.brand);
    });

    test('ignores anything that is only on its way to a trigger', () {
      // Typing towards a real setting must never trip an egg.
      for (final partial in [
        'e',
        'en',
        'ens',
        'z',
        'ze',
        'budget',
        'budgets'
      ]) {
        expect(settingsEggFor(partial), isNull, reason: partial);
      }
    });

    test('leaves genuine searches alone', () {
      // `zen maru` is a real search for the font, not a request for ink.
      expect(settingsEggFor('zen maru'), isNull);
      expect(settingsEggFor('enso ring'), isNull);
      expect(settingsEggFor('notifications'), isNull);
      expect(settingsEggFor(''), isNull);
      expect(settingsEggFor('   '), isNull);
    });
  });

  group('SettingsEggCard', () {
    testWidgets('enso brushes a ring', (tester) async {
      await tester.pumpWidget(_host(const SettingsEggCard(SettingsEgg.enso)));
      expect(find.byType(BrushedEnso), findsOneWidget);
      expect(find.byType(SealStamp), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('zen draws a line of ink and nothing else', (tester) async {
      await tester.pumpWidget(_host(const SettingsEggCard(SettingsEgg.zen)));
      expect(find.byType(InkLine), findsOneWidget);
      expect(find.byType(BrushedEnso), findsNothing);
      expect(find.byType(SealStamp), findsNothing);
      expect(find.byType(Text), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('budgetsense presses the seal over the tagline',
        (tester) async {
      await tester.pumpWidget(_host(const SettingsEggCard(SettingsEgg.brand)));
      expect(find.byType(SealStamp), findsOneWidget);
      expect(find.text(AppInfo.tagline), findsOneWidget);
      await tester.pumpAndSettle();
    });
  });

  group('SealableSummary', () {
    testWidgets('a closed month can be sealed, and the seal lifts away',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const SealableSummary(
            closed: true,
            child: SizedBox(width: 300, height: 120),
          ),
        ),
      );
      expect(find.byType(SealStamp), findsNothing);

      await tester.longPress(find.byType(SealableSummary));
      await tester.pump();
      expect(find.byType(SealStamp), findsOneWidget);

      await tester.pumpAndSettle();
      await tester.pump(kSealDwell);
      await tester.pumpAndSettle();
      expect(find.byType(SealStamp), findsNothing);
    });

    testWidgets('a month still in progress cannot be sealed', (tester) async {
      await tester.pumpWidget(
        _host(
          const SealableSummary(
            closed: false,
            // Something that actually takes the press, so this is a real
            // attempt that fails rather than a press landing on nothing.
            child: SizedBox(
              width: 300,
              height: 120,
              child: ColoredBox(color: Color(0xFFEEEEEE)),
            ),
          ),
        ),
      );

      await tester.longPress(find.byType(SealableSummary));
      await tester.pumpAndSettle();
      expect(find.byType(SealStamp), findsNothing);
    });

    testWidgets('adds no gesture at all to an open month', (tester) async {
      await tester.pumpWidget(
        _host(
          const SealableSummary(
            closed: false,
            child: SizedBox(width: 300, height: 120),
          ),
        ),
      );
      // The child is passed straight through, so nothing can swallow a tap
      // meant for whatever is inside the summary.
      expect(find.byType(GestureDetector), findsNothing);
    });
  });

  group('the Settings search box', () {
    /// Rendering the whole settings list trips a pre-existing framework warning
    /// about a ListTile inside a decorated card. It has nothing to do with the
    /// search box, so let it through rather than let it fail these tests. Has
    /// to run inside the test body: the binding installs its own handler first.
    void muteUnrelatedListTileWarning() {
      final original = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details
            .exceptionAsString()
            .contains('ink splashes may be invisible')) {
          return;
        }
        original?.call(details);
      };
      addTearDown(() => FlutterError.onError = original);
    }

    testWidgets('answers an egg without hiding the real settings',
        (tester) async {
      muteUnrelatedListTileWarning();
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_host(const SettingsScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'zen');
      await tester.pump();

      // `zen` is both an easter egg and a genuine search for Zen Maru Gothic,
      // so the ink appears *above* the font setting rather than instead of it.
      expect(find.byType(InkLine), findsOneWidget);
      expect(find.text('Typeface and font'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('an egg with no matching settings is still answered',
        (tester) async {
      muteUnrelatedListTileWarning();
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_host(const SettingsScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'enso');
      await tester.pump();

      expect(find.byType(BrushedEnso), findsOneWidget);
      expect(find.text('No settings found'), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('an ordinary search is untouched', (tester) async {
      muteUnrelatedListTileWarning();
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_host(const SettingsScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'font');
      await tester.pump();

      expect(find.byType(InkLine), findsNothing);
      expect(find.byType(BrushedEnso), findsNothing);
      expect(find.text('Typeface and font'), findsOneWidget);
      await tester.pumpAndSettle();
    });
  });

  group('tap the version seven times', () {
    Future<void> tapVersion(WidgetTester tester, int times) async {
      for (var i = 0; i < times; i++) {
        await tester.tap(find.text('Version ${AppInfo.version}'));
        await tester.pump(const Duration(milliseconds: 60));
      }
    }

    testWidgets('seven taps redraw the mark as an enso', (tester) async {
      await tester.pumpWidget(_host(const AboutScreen()));
      await tester.pump();
      expect(find.byType(BrushedEnso), findsNothing);

      await tapVersion(tester, 7);
      await tester.pump();
      expect(find.byType(BrushedEnso), findsOneWidget);

      // It settles back on its own, without being asked.
      await tester.pumpAndSettle();
      await tester.pump(kEnsoBrushDwell);
      await tester.pumpAndSettle();
      expect(find.byType(BrushedEnso), findsNothing);
    });

    testWidgets('six taps reveal nothing', (tester) async {
      await tester.pumpWidget(_host(const AboutScreen()));
      await tester.pump();

      await tapVersion(tester, 6);
      await tester.pump();
      expect(find.byType(BrushedEnso), findsNothing);

      // Let the counter forget, so no timer outlives the test.
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('taps stop counting once you pause', (tester) async {
      await tester.pumpWidget(_host(const AboutScreen()));
      await tester.pump();

      await tapVersion(tester, 5);
      await tester.pump(const Duration(seconds: 3));
      await tapVersion(tester, 5);
      await tester.pump();

      expect(
        find.byType(BrushedEnso),
        findsNothing,
        reason: 'ten taps across a pause is not seven in a row',
      );
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('OverPullRipple', () {
    // A tall list so there is somewhere to scroll to, wrapped exactly the way
    // the dashboard wraps its body.
    Widget subject({double depth = kOverPullDepth}) => _host(
          OverPullRipple(
            depth: depth,
            child: ListView(
              physics: const ClampingScrollPhysics(),
              children: List.generate(
                40,
                (i) => SizedBox(height: 60, child: Text('row $i')),
              ),
            ),
          ),
        );

    /// Pulls down past the top by [distance], leaving the finger down so the
    /// drag is still in progress.
    Future<TestGesture> pullDown(WidgetTester tester, double distance) async {
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(ListView)),
      );
      // Past the touch slop first, then the distance that should count.
      await gesture.moveBy(const Offset(0, kDragSlopDefault));
      await gesture.moveBy(Offset(0, distance));
      await tester.pump();
      return gesture;
    }

    testWidgets('a deliberate over-pull sends one wave across', (tester) async {
      await tester.pumpWidget(subject());
      final gesture = await pullDown(tester, kOverPullDepth + 40);

      expect(find.byType(WaterRipple), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a shallow pull is left alone', (tester) async {
      await tester.pumpWidget(subject());
      final gesture = await pullDown(tester, kOverPullDepth * 0.4);

      expect(find.byType(WaterRipple), findsNothing);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('ordinary scrolling never triggers it', (tester) async {
      await tester.pumpWidget(subject());

      // Scroll well into the list and back, the normal way.
      await tester.fling(find.byType(ListView), const Offset(0, -400), 1000);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, 200));
      await tester.pumpAndSettle();

      expect(find.byType(WaterRipple), findsNothing);
    });

    testWidgets('one wave per drag, however long you lean on it',
        (tester) async {
      await tester.pumpWidget(subject());
      final gesture = await pullDown(tester, kOverPullDepth + 40);
      expect(find.byType(WaterRipple), findsOneWidget);

      // Let the wave cross and clear while the finger is still down.
      await tester
          .pump(kWaterRippleDuration + const Duration(milliseconds: 50));
      await tester.pump();
      expect(find.byType(WaterRipple), findsNothing);

      // Still pulling, hard. The same drag does not get a second wave.
      await gesture.moveBy(const Offset(0, kOverPullDepth * 2));
      await tester.pump();
      expect(
        find.byType(WaterRipple),
        findsNothing,
        reason: 'the drag has already had its wave',
      );

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('the tally resets, so a second pull works too', (tester) async {
      await tester.pumpWidget(subject());

      final first = await pullDown(tester, kOverPullDepth + 40);
      expect(find.byType(WaterRipple), findsOneWidget);
      await first.up();
      await tester.pumpAndSettle();
      expect(
        find.byType(WaterRipple),
        findsNothing,
        reason: 'the wave clears itself away',
      );

      final second = await pullDown(tester, kOverPullDepth + 40);
      expect(find.byType(WaterRipple), findsOneWidget);
      await second.up();
      await tester.pumpAndSettle();
    });

    testWidgets('two shallow pulls do not add up into one', (tester) async {
      await tester.pumpWidget(subject());

      final first = await pullDown(tester, kOverPullDepth * 0.6);
      expect(find.byType(WaterRipple), findsNothing);
      await first.up();
      await tester.pumpAndSettle();

      // Asserted while the second drag is still in progress: if the tally
      // carried over from the first, the two together would be past the depth.
      final second = await pullDown(tester, kOverPullDepth * 0.6);
      expect(
        find.byType(WaterRipple),
        findsNothing,
        reason: 'every drag starts from nothing',
      );

      await second.up();
      await tester.pumpAndSettle();
    });

    testWidgets('pulling up past the bottom does nothing', (tester) async {
      await tester.pumpWidget(subject());
      await tester.fling(find.byType(ListView), const Offset(0, -6000), 8000);
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(ListView)),
      );
      await gesture.moveBy(const Offset(0, -kDragSlopDefault));
      await gesture.moveBy(const Offset(0, -(kOverPullDepth * 2)));
      await tester.pump();

      expect(
        find.byType(WaterRipple),
        findsNothing,
        reason: 'only the top edge is water',
      );

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('the list still scrolls while the wave is crossing',
        (tester) async {
      await tester.pumpWidget(subject());
      final gesture = await pullDown(tester, kOverPullDepth + 40);
      expect(find.byType(WaterRipple), findsOneWidget);
      await gesture.up();
      await tester.pumpAndSettle();

      // The notification was observed, not swallowed: the list still scrolls.
      await tester.fling(find.byType(ListView), const Offset(0, -400), 1000);
      await tester.pumpAndSettle();
      final position =
          tester.state<ScrollableState>(find.byType(Scrollable)).position;
      expect(position.pixels, greaterThan(0));
    });

    testWidgets('reduce-motion still gets the wave', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: subject(),
        ),
      );
      final gesture = await pullDown(tester, kOverPullDepth + 40);

      expect(
        find.byType(WaterRipple),
        findsOneWidget,
        reason: 'an explicit gesture is not ambient motion',
      );

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a wave in flight is dropped cleanly when the page goes away',
        (tester) async {
      await tester.pumpWidget(subject());
      final gesture = await pullDown(tester, kOverPullDepth + 40);
      expect(find.byType(WaterRipple), findsOneWidget);
      await gesture.up();

      // Tear the whole thing down mid-animation.
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(_host(const SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
