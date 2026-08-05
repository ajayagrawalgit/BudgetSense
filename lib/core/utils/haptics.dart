import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A single, deliberate home for haptic feedback across BudgetSense.
///
/// The goal (following Android's haptics principles) is restraint: feedback
/// should confirm a *meaningful, discrete* moment, reinforce a state change the
/// user caused, and otherwise stay silent. We do not buzz on scroll, on every
/// tap, or to decorate. Each call site picks the semantic method that matches
/// what just happened, not a raw impact strength, so the "vocabulary" stays
/// consistent app-wide and easy to tune from one place.
///
/// On Android we drive the platform [Vibrator] directly through a tiny native
/// channel, because Flutter's built-in [HapticFeedback] routes through
/// `View.performHapticFeedback`, which many devices render as *nothing* (or
/// ignore entirely when the system "touch vibration" toggle is off). The native
/// path uses tuned predefined effects and actually fires. Every other platform
/// (and any failure) falls back to [HapticFeedback], which is great on iOS.
///
/// Everything is gated by [enabled], which mirrors the user's "Haptic feedback"
/// setting. When it's off, every method is a no-op.
abstract final class Haptics {
  /// Mirrors the user's setting. Kept as a plain static (not a provider) so any
  /// widget, including stateless ones deep in the tree, can trigger feedback
  /// without plumbing a `ref` through. The app keeps this in sync with settings.
  static bool enabled = true;

  static const MethodChannel _channel =
      MethodChannel('com.budgetsense.budgetsense/haptics');

  static final bool _useNative = !kIsWeb && Platform.isAndroid;

  /// A light tick for moving between discrete choices: switching a tab, picking
  /// a chip, toggling a switch, stepping a slider, opening/closing a section.
  /// This is the workhorse and by far the most common call.
  static void selection() => _fire('selection', HapticFeedback.selectionClick);

  /// A soft confirmation that a small action landed: a transaction saved, an
  /// item restored, a swipe committed. Gentle, not celebratory.
  static void confirm() => _fire('confirm', HapticFeedback.lightImpact);

  /// A slightly firmer pulse for a weightier or destructive commit: moving an
  /// item to trash, emptying the trash, deleting for good. Used sparingly.
  static void impact() => _fire('impact', HapticFeedback.mediumImpact);

  /// The strongest cue, reserved for genuine errors or hard stops. Rare on
  /// purpose; overusing it would make the whole app feel anxious.
  static void warning() => _fire('warning', HapticFeedback.heavyImpact);

  /// Routes to the reliable native vibrator on Android, and to Flutter's
  /// [HapticFeedback] elsewhere. If the native channel is missing (e.g. an
  /// older build or a test host) it falls back so feedback still happens where
  /// it can.
  static void _fire(String kind, Future<void> Function() fallback) {
    if (!enabled) return;
    if (_useNative) {
      _channel.invokeMethod<void>('haptic', kind).catchError((_) => fallback());
    } else {
      fallback();
    }
  }
}
