import '../../core/constants/enums.dart';
import '../../core/utils/money.dart';

/// A user-defined limit rule (Section 11). Fully configurable - no threshold
/// value is hard-coded anywhere in the app; these are seeded as *suggestions*
/// and stored in the database.
class ThresholdRule {
  const ThresholdRule({
    required this.id,
    required this.label,
    required this.type,
    required this.value,
    required this.warningPercent,
    required this.criticalPercent,
    this.scopeKey,
    this.enabled = true,
  });

  final String id;
  final String label;
  final ThresholdType type;

  /// For percentage types: the target percent (0 to 100).
  /// For amount types: the limit in **minor units** (wrapped as [Money]).
  final double value;

  /// At what fraction of the limit we start warning (e.g. 0.8 = 80%).
  final double warningPercent;

  /// At what fraction we flag critical (e.g. 0.95 = 95%).
  final double criticalPercent;

  /// Identifies what this rule applies to. Valid values are:
  ///   * `null` / empty  - the whole month (no per-scope filter)
  ///   * `'investments'` - app-level: total investments this month
  ///   * `'unallocated'` - app-level: what is left after spend + invest
  ///   * any category id - the live per-category spend for that category
  ///
  /// Category ids are fully dynamic (users create/rename/delete categories),
  /// so no category name is ever hard-coded here. Starter categories like
  /// "Needs", "Wants" or "Responsibilities" are just seed suggestions - if the
  /// user removes or renames them the threshold still works via its stored id.
  final String? scopeKey;

  /// Whether this rule participates in evaluation and notifications.
  final bool enabled;

  Money get amountLimit => Money(value.round());

  static const _unset = Object();

  ThresholdRule copyWith({
    String? label,
    ThresholdType? type,
    double? value,
    double? warningPercent,
    double? criticalPercent,
    Object? scopeKey = _unset,
    bool? enabled,
  }) {
    return ThresholdRule(
      id: id,
      label: label ?? this.label,
      type: type ?? this.type,
      value: value ?? this.value,
      warningPercent: warningPercent ?? this.warningPercent,
      criticalPercent: criticalPercent ?? this.criticalPercent,
      scopeKey:
          identical(scopeKey, _unset) ? this.scopeKey : scopeKey as String?,
      enabled: enabled ?? this.enabled,
    );
  }
}

/// The evaluated outcome of a rule for a given period.
class ThresholdEvaluation {
  const ThresholdEvaluation({
    required this.rule,
    required this.status,
    required this.actual,
    required this.limit,
    required this.usedFraction,
  });

  final ThresholdRule rule;
  final ThresholdStatus status;

  /// The measured amount (spend/invest) this rule evaluated against.
  final Money actual;

  /// The resolved limit as money (for percentage rules this is derived from
  /// income at evaluation time).
  final Money limit;

  /// actual / limit as a fraction. May exceed 1.0.
  final double usedFraction;
}

/// Pure evaluator. Feed it the actual amount, the income (for percentage
/// rules), and it returns a calm, color-independent status.
class ThresholdService {
  const ThresholdService();

  ThresholdEvaluation evaluate(
    ThresholdRule rule, {
    required Money actual,
    required Money monthlyIncome,
  }) {
    final limit = _resolveLimit(rule, monthlyIncome);
    final fraction = limit.minorUnits == 0
        ? (actual.isZero ? 0.0 : double.infinity)
        : actual.ratioOf(limit);

    final status = _statusFor(rule, fraction);
    return ThresholdEvaluation(
      rule: rule,
      status: status,
      actual: actual,
      limit: limit,
      usedFraction: fraction,
    );
  }

  Money _resolveLimit(ThresholdRule rule, Money income) {
    if (rule.type.isPercentage) {
      return Money((income.minorUnits * rule.value / 100).round());
    }
    return rule.amountLimit;
  }

  ThresholdStatus _statusFor(ThresholdRule rule, double fraction) {
    // MIN rules invert the meaning: you *want* to reach/exceed the target.
    if (!rule.type.isMax) {
      if (fraction >= 1.0) return ThresholdStatus.targetAchieved;
      if (fraction >= rule.warningPercent) return ThresholdStatus.approaching;
      return ThresholdStatus.belowTarget;
    }

    // MAX rules: staying under is good.
    if (fraction >= 1.0) return ThresholdStatus.exceeded;
    if (fraction >= rule.criticalPercent) return ThresholdStatus.approaching;
    if (fraction >= rule.warningPercent) return ThresholdStatus.approaching;
    return ThresholdStatus.safe;
  }
}

/// Suggested starting thresholds (Section 11). Presented during onboarding and
/// fully editable afterwards - never treated as immutable law.
///
/// These are deliberately calm, generous, and category-agnostic: they only use
/// app-level scopes (investments, unallocated) so they make sense for everyone
/// regardless of which categories a user creates. Users add their own
/// per-category limits from the threshold editor whenever they like.
abstract final class SuggestedThresholds {
  static List<ThresholdRule> defaults() => const [
        ThresholdRule(
          id: 'suggest_investments',
          label: 'Invest at least 15%',
          type: ThresholdType.minPercentage,
          value: 15,
          warningPercent: 0.85,
          criticalPercent: 1.0,
          scopeKey: 'investments',
        ),
        ThresholdRule(
          id: 'suggest_unallocated',
          label: 'Unallocated within 20%',
          type: ThresholdType.maxPercentage,
          value: 20,
          warningPercent: 0.8,
          criticalPercent: 0.95,
          scopeKey: 'unallocated',
        ),
      ];
}
