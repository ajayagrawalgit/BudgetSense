import 'package:budgetsense/core/utils/haptics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The global haptics gate: when the user's setting is off, nothing should
/// reach the platform; when on, the right feedback call goes through.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <String?>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        calls.add(call.arguments as String?);
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    Haptics.enabled = true;
  });

  test('disabled: no haptic reaches the platform', () async {
    Haptics.enabled = false;
    Haptics.selection();
    Haptics.confirm();
    Haptics.impact();
    Haptics.warning();
    await Future<void>.delayed(Duration.zero);
    expect(calls, isEmpty);
  });

  test('enabled: each semantic call fires exactly one platform vibrate',
      () async {
    Haptics.enabled = true;
    Haptics.selection();
    await Future<void>.delayed(Duration.zero);
    expect(calls.length, 1);
    expect(calls.single, 'HapticFeedbackType.selectionClick');

    calls.clear();
    Haptics.confirm();
    await Future<void>.delayed(Duration.zero);
    expect(calls.single, 'HapticFeedbackType.lightImpact');

    calls.clear();
    Haptics.impact();
    await Future<void>.delayed(Duration.zero);
    expect(calls.single, 'HapticFeedbackType.mediumImpact');

    calls.clear();
    Haptics.warning();
    await Future<void>.delayed(Duration.zero);
    expect(calls.single, 'HapticFeedbackType.heavyImpact');
  });
}
