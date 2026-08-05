import 'package:budgetsense/core/services/widget_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // These tests run on the Flutter test host (not Android), so WidgetService
  // must take its "unsupported platform" path and no-op gracefully rather than
  // touching a method channel that has no native peer. This guards the promise
  // that home-screen widgets can never crash or block the app off Android.
  test('updateData no-ops off Android without throwing', () async {
    await expectLater(
      WidgetService.updateData({'balance': 'INR 1,000'}),
      completes,
    );
  });

  test('consumeLaunchAction returns null off Android', () async {
    expect(await WidgetService.consumeLaunchAction(), isNull);
  });

  test('setActionListener is a safe no-op off Android', () {
    // Neither registering nor clearing a listener should throw.
    expect(() => WidgetService.setActionListener((_) {}), returnsNormally);
    expect(() => WidgetService.setActionListener(null), returnsNormally);
  });
}
