import '../../core/constants/enums.dart';
import '../../core/services/notification_service.dart';
import '../../core/utils/quiet_hours.dart';
import 'threshold_service.dart';

/// The escalation level an alert was fired at.
///
/// Ordered deliberately: a rule may only ever alert *upwards*. Once
/// [breached] has been announced, drifting back to [nearing] must stay silent,
/// otherwise a balance hovering on the boundary would buzz the user forever.
enum AlertLevel {
  /// Approaching a max limit, or still short of a min target.
  nearing,

  /// A max limit is exceeded, or a min target has been achieved.
  breached;

  /// Whether [this] is a genuine escalation beyond [previous].
  bool isEscalationOver(AlertLevel? previous) =>
      previous == null || index > previous.index;
}

/// One alert the planner decided is worth showing, and the receipt needed to
/// guarantee it is never shown again.
class ThresholdAlert {
  const ThresholdAlert({
    required this.ruleId,
    required this.monthKey,
    required this.level,
    required this.alert,
  });

  final String ruleId;
  final String monthKey;
  final AlertLevel level;

  /// The renderable notification. [ScheduledAlert.when] is the moment the
  /// planner ran: these are delivered immediately, never queued for later.
  final ScheduledAlert alert;

  /// The idempotency key. One rule, one month, one level: fire once, forever.
  String get dedupeKey => '$ruleId|$monthKey|${level.name}';
}

/// Decides which threshold breaches deserve to interrupt the user.
///
/// Pure and side-effect free, exactly like [ReminderPlanner]: it is handed the
/// evaluations, the log of what has already been announced, and the clock, and
/// it returns a list. It never touches the plugin, the database or the disk,
/// which is what makes the restraint rules below cheap to test exhaustively.
///
/// The restraint contract, in order of application:
///  1. Only [ThresholdStatus] values that mean something actionable alert at
///     all. A `safe` rule is not news.
///  2. One alert per rule, per financial month, per escalation level. Crossing
///     80% announces once; crossing 100% announces once more; nothing else.
///  3. Levels only ever escalate. Falling back below a limit never re-arms the
///     lower rung within the same month (see [AlertLevel.isEscalationOver]).
///  4. Quiet hours suppress *permanently*, not by deferral. A 2 AM overspend
///     warning delivered at 7 AM is stale advice, and queueing it would risk a
///     morning pile-up of overnight noise.
///
/// Rule 4 is a deliberate trade: the dashboard card still shows the breach the
/// moment the user looks, so the information is never lost, only the interrupt.
class ThresholdAlertPlanner {
  const ThresholdAlertPlanner();

  /// Builds the alerts to fire now.
  ///
  /// [alreadyAlerted] is the set of [ThresholdAlert.dedupeKey]s previously
  /// fired; anything in it is skipped. [monthKey] scopes the whole decision to
  /// the financial month, so every rule naturally re-arms when the month rolls
  /// over without any explicit reset step.
  List<ThresholdAlert> plan(
    List<ThresholdEvaluation> evaluations, {
    required String monthKey,
    required Set<String> alreadyAlerted,
    required DateTime now,
    QuietHours? quietHours,
  }) {
    if (quietHours != null && quietHours.contains(now)) return const [];

    final alerts = <ThresholdAlert>[];
    final seenRuleLevels = <String>{};
    for (final evaluation in evaluations) {
      final rule = evaluation.rule;
      if (!rule.enabled) continue;

      final level = _levelFor(evaluation.status);
      if (level == null) continue;

      final dedupeKey = '${rule.id}|$monthKey|${level.name}';
      // Defend the notification boundary even if a corrupted store feeds two
      // copies of the same rule into the evaluator.
      if (!seenRuleLevels.add(dedupeKey) ||
          alreadyAlerted.contains(dedupeKey)) {
        continue;
      }

      // Respect any louder alert this rule has already made this month, so a
      // value oscillating around a boundary cannot re-trigger the quieter rung.
      final highestSoFar = _highestAlerted(rule.id, monthKey, alreadyAlerted);
      if (!level.isEscalationOver(highestSoFar)) continue;

      alerts.add(
        ThresholdAlert(
          ruleId: rule.id,
          monthKey: monthKey,
          level: level,
          alert: ScheduledAlert(
            id: _stableId('threshold_${rule.id}_${level.name}_$monthKey'),
            title: _titleFor(evaluation, level),
            body: _bodyFor(evaluation),
            when: now,
          ),
        ),
      );
    }
    return alerts;
  }

  /// Maps a status to the level worth announcing, or null to stay silent.
  AlertLevel? _levelFor(ThresholdStatus status) => switch (status) {
        ThresholdStatus.approaching => AlertLevel.nearing,
        ThresholdStatus.exceeded => AlertLevel.breached,
        // Hitting a savings or investment goal is the one piece of genuinely
        // good news the app can deliver, and it is worth exactly one mention.
        ThresholdStatus.targetAchieved => AlertLevel.breached,
        // Merely being below a min target is the normal state for most of the
        // month. Nagging about it daily would be the fastest way to get the
        // whole notification channel muted.
        ThresholdStatus.belowTarget => null,
        ThresholdStatus.safe => null,
      };

  /// The loudest level already fired for this rule this month, if any.
  AlertLevel? _highestAlerted(
    String ruleId,
    String monthKey,
    Set<String> alreadyAlerted,
  ) {
    AlertLevel? highest;
    for (final level in AlertLevel.values) {
      if (alreadyAlerted.contains('$ruleId|$monthKey|${level.name}')) {
        highest = level;
      }
    }
    return highest;
  }

  String _titleFor(ThresholdEvaluation evaluation, AlertLevel level) {
    if (evaluation.status == ThresholdStatus.targetAchieved) {
      return 'Target reached';
    }
    return level == AlertLevel.breached ? 'Limit passed' : 'Nearing a limit';
  }

  /// Deliberately plain, factual copy. No alarm, no exclamation marks: the
  /// user is told what happened and left to decide what it means.
  String _bodyFor(ThresholdEvaluation evaluation) {
    final label = evaluation.rule.label;
    final percent = _percentOf(evaluation.usedFraction);
    return switch (evaluation.status) {
      ThresholdStatus.targetAchieved => '$label: you have reached your target.',
      ThresholdStatus.exceeded => '$label is now past its limit ($percent%).',
      _ => '$label is at $percent% of its limit.',
    };
  }

  /// Formats a fraction as a whole percent, guarding the infinite case a
  /// zero-valued limit produces in [ThresholdService.evaluate].
  String _percentOf(double fraction) {
    if (!fraction.isFinite) return '100+';
    return (fraction * 100).round().toString();
  }

  /// A deterministic small positive id, so re-firing the same logical alert
  /// replaces its predecessor in the tray rather than stacking duplicates.
  int _stableId(String key) => key.hashCode & 0x7fffffff;
}
