import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/feature_providers.dart';
import '../../app/providers.dart';
import '../../core/constants/enums.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_resolver.dart';
import '../../core/utils/money.dart';
import '../common/brand_watermark.dart';
import '../common/calm_widgets.dart';
import 'insights_cards.dart';
import '../settings/settings_controller.dart';

/// Insights & reports (Section 14). Every figure is computed locally from the
/// same [monthlySummaryProvider] the dashboard uses - one source of truth, no
/// duplicated math. Tap-through to underlying transactions is the next step.
class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(monthlySummaryProvider);
    final categories =
        ref.watch(categoriesStreamProvider).valueOrNull ?? const [];
    final settings = ref.watch(settingsControllerProvider).valueOrNull;
    final symbol = settings?.currencySymbol ?? '₹';
    final locale = settings?.localeCode;
    final text = Theme.of(context).textTheme;
    final colors = context.colors;

    String money(Money v) => v.format(
        currencySymbol: symbol,
        locale: locale,
        compact: settings?.numberFormatCompact ?? false);

    String categoryName(String id) {
      final match = categories.where((c) => c.id == id).firstOrNull;
      return match?.name ?? 'Uncategorized';
    }

    final highest = summary.perCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final trend = ref.watch(insightsTrendProvider);
    final nothingYet = highest.isEmpty &&
        trend.isEmpty &&
        summary.totalGains.minorUnits == 0 &&
        summary.totalSpent.minorUnits == 0;

    if (nothingYet) {
      return Scaffold(
        appBar: AppBar(title: const Text('Insights')),
        body: const SafeArea(
          child: CalmEmptyState(
            title: 'Insights arrive with your first entries',
            message:
                'Once you log a little income and spending, this is where your '
                'trends, categories and projections take shape.',
            icon: Icons.insights_outlined,
            illustration: CalmIllustration.chart,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: SafeArea(
        child: BrandWatermark(
          child: ListView(
            padding: const EdgeInsets.all(Insets.lg),
            children: [
              const _AttentionCard(),
              CalmCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Income vs expenses', style: text.titleMedium),
                    const SizedBox(height: Insets.md),
                    Row(
                      children: [
                        Expanded(
                          child: StatTile(
                            label: 'Income',
                            value: money(summary.totalGains),
                            valueColor: colors.positive,
                          ),
                        ),
                        Expanded(
                          child: StatTile(
                            label: 'Expenses',
                            value: money(summary.totalSpent),
                            valueColor: colors.negative,
                          ),
                        ),
                        Expanded(
                          child: StatTile(
                            label: 'Savings',
                            value: money(summary.totalSavings),
                            valueColor: colors.info,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Insets.lg),
              const GlanceCard(),
              const SizedBox(height: Insets.lg),
              CalmCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Highest-spending categories',
                      style: text.titleMedium,
                    ),
                    const SizedBox(height: Insets.md),
                    if (highest.isEmpty)
                      Text('No spending recorded yet.', style: text.bodyMedium)
                    else
                      for (final e in highest.take(5))
                        Padding(
                          padding: const EdgeInsets.only(bottom: Insets.sm),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(categoryName(e.key), style: text.bodyMedium),
                              Text(money(e.value), style: text.titleSmall),
                            ],
                          ),
                        ),
                  ],
                ),
              ),
              const SizedBox(height: Insets.lg),
              const SpendingRhythmCard(),
              const SizedBox(height: Insets.lg),
              const IncomeSourcesCard(),
              const SizedBox(height: Insets.lg),
              const _TrendCard(),
              const SizedBox(height: Insets.lg),
              const CommitmentsCard(),
              const SizedBox(height: Insets.lg),
              const _ProjectionCard(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Color-independent threshold warnings (icon + label per status). Moved here
/// from the dashboard to keep the home screen calm. Hidden when all is well.
class _AttentionCard extends ConsumerWidget {
  const _AttentionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warnings = ref.watch(thresholdWarningsProvider);
    if (warnings.isEmpty) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    final colors = context.colors;

    ({IconData icon, Color color}) style(ThresholdStatus s) => switch (s) {
          ThresholdStatus.exceeded => (
              icon: Icons.error_outline,
              color: colors.critical
            ),
          ThresholdStatus.approaching => (
              icon: Icons.warning_amber_outlined,
              color: colors.warning
            ),
          ThresholdStatus.belowTarget => (
              icon: Icons.trending_down,
              color: colors.info
            ),
          _ => (icon: Icons.check_circle_outline, color: colors.positive),
        };

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.lg),
      child: CalmCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Attention', style: text.titleMedium),
            const SizedBox(height: Insets.sm),
            for (final w in warnings)
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.xs),
                child: Row(
                  children: [
                    Icon(
                      style(w.status).icon,
                      size: 16,
                      color: style(w.status).color,
                    ),
                    const SizedBox(width: Insets.sm),
                    Expanded(
                      child: Text(w.rule.label, style: text.bodyMedium),
                    ),
                    Text(w.status.label, style: text.labelSmall),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A minimal 6-month spend trend with month-over-month change.
class _TrendCard extends ConsumerWidget {
  const _TrendCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final points = ref.watch(insightsTrendProvider);
    final settings = ref.watch(settingsControllerProvider).valueOrNull;
    final symbol = settings?.currencySymbol ?? '₹';
    final locale = settings?.localeCode;
    final text = Theme.of(context).textTheme;
    final colors = context.colors;

    if (points.isEmpty) return const SizedBox.shrink();
    final maxSpent = points
        .map((p) => p.spent.minorUnits)
        .fold<int>(1, (a, b) => a > b ? a : b);
    final mom = ref.watch(insightsServiceProvider).momSpendChange(points);

    return CalmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Spending trend', style: text.titleMedium),
              Row(
                children: [
                  Icon(
                    mom > 0 ? Icons.trending_up : Icons.trending_down,
                    size: 15,
                    color: mom > 0 ? colors.negative : colors.positive,
                  ),
                  const SizedBox(width: Insets.xs),
                  Text('${(mom * 100).round()}% MoM', style: text.labelMedium),
                ],
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          for (final p in points)
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(p.monthKey, style: text.bodySmall),
                      Text(
                        p.spent.format(
                            currencySymbol: symbol,
                            locale: locale,
                            compact: settings?.numberFormatCompact ?? false),
                        style: text.labelMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.xs),
                  CalmProgressBar(
                    fraction: p.spent.minorUnits / maxSpent,
                    color: colors.warning,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Average daily spend + projected month-end balance for the focused month.
class _ProjectionCard extends ConsumerWidget {
  const _ProjectionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(monthlySummaryProvider);
    final calendar = ref.watch(financialCalendarProvider);
    final month = ref.watch(focusedMonthProvider);
    final service = ref.watch(insightsServiceProvider);
    final settings = ref.watch(settingsControllerProvider).valueOrNull;
    final symbol = settings?.currencySymbol ?? '₹';
    final locale = settings?.localeCode;
    final text = Theme.of(context).textTheme;
    final colors = context.colors;

    final now = DateTime.now();
    final range = calendar.monthRangeFor(month);
    final avgDaily = service.averageDailySpend(summary.totalSpent, range);
    final projected = service.projectedMonthEndBalance(
      income: summary.totalGains,
      spentSoFar: summary.totalSpent,
      invested: summary.totalInvestments,
      monthRange: range,
      now: now,
    );

    // Early in a live month, one big expense skews the linear projection. Keep
    // the honest figure but caveat it, rather than flashing an alarming number.
    // Past/complete months are exact, so they get no caveat.
    final isCurrentMonth = range.contains(now);
    final elapsedDays = isCurrentMonth
        ? now.difference(range.start).inDays + 1
        : range.inclusiveDays;
    final isEarly = isCurrentMonth && elapsedDays < 5;

    String money(Money v) => v.format(
        currencySymbol: symbol,
        locale: locale,
        compact: settings?.numberFormatCompact ?? false);

    return CalmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Projections', style: text.titleMedium),
          const SizedBox(height: Insets.md),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Avg daily spend',
                  value: money(avgDaily),
                ),
              ),
              Expanded(
                child: StatTile(
                  label: 'Projected balance',
                  value: money(projected),
                  // An estimate, not a verdict - never shown in alarming red.
                  valueColor: colors.textPrimary,
                ),
              ),
            ],
          ),
          if (isEarly) ...[
            const SizedBox(height: Insets.sm),
            Text(
              'This estimate settles after the first few days of the month.',
              style: text.bodySmall?.copyWith(color: colors.textFaint),
            ),
          ] else if (projected.isNegative) ...[
            const SizedBox(height: Insets.sm),
            Text(
              'At your current pace, spending may edge past income this month.',
              style: text.bodySmall?.copyWith(color: colors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
