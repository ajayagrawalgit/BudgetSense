import '../../core/services/notification_service.dart';
import '../../core/utils/app_log.dart';
import '../../core/utils/quiet_hours.dart';
import '../../data/local/threshold_alert_log.dart';
import '../services/threshold_alert_planner.dart';
import '../services/threshold_service.dart';

/// Turns threshold evaluations into delivered notifications, exactly once each.
///
/// The planner is pure policy; this is the narrow impure edge that obtains
/// permission, serializes dispatches, asks the OS to show an alert, then stores
/// its receipt. Keeping that sequence here makes the app's no-nag guarantee
/// auditable rather than an accident of widget rebuild timing.
class ThresholdAlertDispatcher {
  ThresholdAlertDispatcher({
    required ThresholdAlertPlanner planner,
    required ThresholdAlertLog log,
    required NotificationService notifications,
  })  : _planner = planner,
        _log = log,
        _notifications = notifications;

  final ThresholdAlertPlanner _planner;
  final ThresholdAlertLog _log;
  final NotificationService _notifications;

  /// Serializes all dispatches in this process. Threshold evaluations are
  /// reactive and can update from settings, rules and transactions together;
  /// without this small queue, two rebuilds could both read an empty receipt
  /// log and buzz for the same event.
  Future<void> _tail = Future<void>.value();

  /// Evaluates, delivers and records. Returns alerts accepted by the platform.
  ///
  /// A quiet-hour event is deliberately consumed, rather than deferred. Advice
  /// about a breach at 02:00 is stale by breakfast, and delivering a pile of
  /// overnight warnings at 07:00 is exactly the nagging this feature avoids.
  /// The dashboard still shows the live status whenever the user opens it.
  Future<List<ThresholdAlert>> dispatch(
    List<ThresholdEvaluation> evaluations, {
    required String monthKey,
    required bool enabled,
    required DateTime now,
    QuietHours? quietHours,
  }) {
    final result = <ThresholdAlert>[];
    final next = _tail.then((_) async {
      result.addAll(
        await _dispatchOne(
          evaluations,
          monthKey: monthKey,
          enabled: enabled,
          now: now,
          quietHours: quietHours,
        ),
      );
    });
    // Keep the queue alive after an unexpected implementation error while
    // still returning that error to the current caller.
    _tail = next.catchError((Object error, StackTrace stackTrace) {
      AppLog.error('Threshold alert dispatch failed',
          error: error, stackTrace: stackTrace);
    });
    return next.then((_) => result);
  }

  Future<List<ThresholdAlert>> _dispatchOne(
    List<ThresholdEvaluation> evaluations, {
    required String monthKey,
    required bool enabled,
    required DateTime now,
    QuietHours? quietHours,
  }) async {
    if (!enabled || evaluations.isEmpty) return const [];

    final alreadyAlerted = await _log.read();
    // Plan without quiet hours first. This gives us the exact receipts to burn
    // when a notification would have landed during the user's quiet window.
    final planned = _planner.plan(
      evaluations,
      monthKey: monthKey,
      alreadyAlerted: alreadyAlerted,
      now: now,
    );
    if (planned.isEmpty) return const [];

    if (quietHours != null && quietHours.contains(now)) {
      await _log.add(
        planned.map((a) => a.dedupeKey).toSet(),
        currentMonthKey: monthKey,
      );
      return const [];
    }

    // Do not mark an alert as delivered when Android/iOS has denied it. The
    // next eligible app evaluation may try again after the user grants access.
    final permitted = await _notifications.ensurePermission();
    if (!permitted) return const [];

    final shown = <ThresholdAlert>[];
    for (final candidate in planned) {
      try {
        await _notifications.showNow(
          candidate.alert.id,
          candidate.alert.title,
          candidate.alert.body,
        );
        // Receipt follows successful plugin acceptance. The serialized queue
        // closes the only in-process window for duplicates.
        await _log.add(
          {candidate.dedupeKey},
          currentMonthKey: monthKey,
        );
        shown.add(candidate);
      } catch (error, stackTrace) {
        // A single OS failure must not stop other independent rules. We leave
        // this key unrecorded so it may be retried on a later app evaluation.
        AppLog.error('Threshold notification could not be shown',
            error: error, stackTrace: stackTrace);
      }
    }
    return shown;
  }
}
