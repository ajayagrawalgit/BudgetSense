import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Toggles Android's `FLAG_SECURE` (blocks screenshots and screen recording,
/// and hides app contents in the recent-apps switcher) at runtime.
///
/// Secure by default to protect financial data; the user can turn it off in
/// Settings > Privacy & security to capture screenshots or record the app.
/// Non-Android platforms and test environments simply no-op.
class ScreenSecurityService {
  ScreenSecurityService._();

  // Shares the existing platform channel with the widget bridge.
  static const MethodChannel _channel =
      MethodChannel('com.budgetsense.budgetsense/widgets');

  static bool get _supported => !kIsWeb && Platform.isAndroid;

  /// Apply the protection preference. `true` blocks capture; `false` allows it.
  static Future<void> setSecure(bool enabled) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('setScreenSecure', enabled);
    } catch (_) {
      // A window flag should never crash the app.
    }
  }
}
