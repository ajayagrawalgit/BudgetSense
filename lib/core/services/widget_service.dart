import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridges the Flutter app and the native Android home-screen widgets.
///
/// Data flows one way for display (Flutter computes figures -> writes them to
/// native SharedPreferences -> triggers a widget redraw), and actions flow the
/// other way (tapping the quick-add widget launches the app, which asks us
/// whether it was opened to add an expense).
///
/// Everything is guarded so non-Android platforms and test environments simply
/// no-op instead of throwing.
class WidgetService {
  WidgetService._();

  static const MethodChannel _channel =
      MethodChannel('com.budgetsense.budgetsense/widgets');

  static bool get _supported => !kIsWeb && Platform.isAndroid;

  /// Push the latest figures to the widgets. All values are pre-formatted
  /// strings so the native side only has to display them.
  static Future<void> updateData(Map<String, String> data) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('updateWidgets', data);
    } catch (_) {
      // Widgets are a best-effort enhancement; never let them break the app.
    }
  }

  /// Returns a pending launch action (e.g. 'quick_add') if the app was opened
  /// by tapping a widget, else null. Consuming it clears it natively.
  static Future<String?> consumeLaunchAction() async {
    if (!_supported) return null;
    try {
      return await _channel.invokeMethod<String>('consumeLaunchAction');
    } catch (_) {
      return null;
    }
  }

  /// Registers a callback invoked when a widget action arrives while the app is
  /// already running (native -> Flutter). Pass null to clear.
  static void setActionListener(void Function(String action)? listener) {
    if (!_supported) return;
    if (listener == null) {
      _channel.setMethodCallHandler(null);
      return;
    }
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onWidgetAction' && call.arguments is String) {
        listener(call.arguments as String);
      }
      return null;
    });
  }
}
