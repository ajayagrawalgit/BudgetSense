import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/feature_providers.dart';
import '../../app/providers.dart';
import '../../core/constants/enums.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_resolver.dart';
import '../../core/utils/money.dart';
import '../common/calm_widgets.dart';
import '../settings/settings_controller.dart';

/// Extra, deeper Insights cards (Section 14). Each is a small [ConsumerWidget]
/// that reads the same providers the dashboard uses, so numbers never diverge.
/// Kept in their own file so `insights_screen.dart` stays focused and short.

String _fmt(WidgetRef ref, Money v) {
  final s = ref.read(settingsControllerProvider).valueOrNull;
  return v.format(
    currencySymbol: s?.currencySymbol ?? '₹',
    locale: s?.localeCode,
  );
}

/// "This month at a glance": how many expenses, the average size, and the
/// single biggest one. A quick gut-check before the detailed cards.
class GlanceCard extends ConsumerWidget {
  const GlanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txns = ref.watch(monthTransactionsProvider).valueOrNull ?? const [];
    final stats = ref.watch(insightsServiceProvider).expenseStats(txns);
    final text = Theme.of(context).textTheme;
    final colors = context.colors;

    if (stats.count == 0) return const SizedBox.shrink();

    return CalmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('This month at a glance', style: text.titleMedium),
          const SizedBox(height: Insets.md),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Expenses logged',
                  value: '${stats.count}',
                ),
              ),
              Expanded(
                child: StatTile(
                  label: 'Average size',
                  value: _fmt(ref, stats.average),
                ),
              ),
            ],
          ),
          if (stats.biggest != null) ...[
            const SizedBox(height: Insets.md),
            Row(
              children: [
                Icon(Icons.trending_up, size: 15, color: colors.textFaint),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Text(
                    'Biggest: ${stats.biggest!.name}',
                    style: text.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(_fmt(ref, stats.biggest!.amount), style: text.titleSmall),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// "Spending rhythm": total spend per weekday (Mon..Sun) as gentle bars, so the
/// user can spot which days money tends to leave.
class SpendingRhythmCard extends ConsumerWidget {
  const SpendingRhythmCard({super.key});

  static const _labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txns = ref.watch(monthTransactionsProvider).valueOrNull ?? const [];
    final byDay = ref.watch(insightsServiceProvider).spendByWeekday(txns);
    final text = Theme.of(context).textTheme;
    final colors = context.colors;

    if (byDay.isEmpty) return const SizedBox.shrink();

    final maxDay = byDay.values
        .map((m) => m.minorUnits)
        .fold<int>(1, (a, b) => a > b ? a : b);
    final busiest = byDay.entries
        .reduce((a, b) => a.value.minorUnits >= b.value.minorUnits ? a : b);

    return CalmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Spending rhythm', style: text.titleMedium),
          const SizedBox(height: 2),
          Text(
            '${_labels[busiest.key - 1]} is your busiest day so far.',
            style: text.bodySmall?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: Insets.md),
          for (var day = DateTime.monday; day <= DateTime.sunday; day++)
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.sm),
              child: Row(
                children: [
                  SizedBox(
                    width: 34,
                    child: Text(_labels[day - 1], style: text.bodySmall),
                  ),
                  Expanded(
                    child: CalmProgressBar(
                      fraction: (byDay[day]?.minorUnits ?? 0) / maxDay,
                      color: colors.info,
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  SizedBox(
                    width: 76,
                    child: Text(
                      _fmt(ref, byDay[day] ?? Money.zero),
                      style: text.labelMedium,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// "Where income came from": income grouped by source. Hidden when there is no
/// income recorded this month.
class IncomeSourcesCard extends ConsumerWidget {
  const IncomeSourcesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txns = ref.watch(monthTransactionsProvider).valueOrNull ?? const [];
    final byType = ref.watch(insightsServiceProvider).incomeByType(txns);
    final text = Theme.of(context).textTheme;
    final colors = context.colors;

    if (byType.isEmpty) return const SizedBox.shrink();

    final entries = byType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return CalmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Where income came from', style: text.titleMedium),
          const SizedBox(height: Insets.md),
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.south_west,
                        size: 14,
                        color: colors.positive,
                      ),
                      const SizedBox(width: Insets.sm),
                      Text(e.key.label, style: text.bodyMedium),
                    ],
                  ),
                  Text(_fmt(ref, e.value), style: text.titleSmall),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// "Money you've committed": a calm summary of ongoing obligations, so the user
/// sees future pull on their income, not just this month's spend. Combines
/// active recurring payments with outstanding loan balances.
class CommitmentsCard extends ConsumerWidget {
  const CommitmentsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payments =
        ref.watch(recurringPaymentsStreamProvider).valueOrNull ?? const [];
    final loans = ref.watch(loansStreamProvider).valueOrNull ?? const [];
    final text = Theme.of(context).textTheme;
    final colors = context.colors;

    final activePayments = payments.where((p) => !p.isArchived).toList();
    final activeLoans = loans.where((l) => !l.isArchived).toList();
    if (activePayments.isEmpty && activeLoans.isEmpty) {
      return const SizedBox.shrink();
    }

    final recurringTotal = sumMoney(activePayments.map((p) => p.amount));
    final outstanding =
        sumMoney(activeLoans.map((l) => l.outstandingPrincipal));
    final emiTotal = sumMoney(activeLoans.map((l) => l.emi));

    return CalmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Money you've committed", style: text.titleMedium),
          const SizedBox(height: Insets.md),
          if (activePayments.isNotEmpty)
            _line(
              context,
              icon: Icons.event_repeat_outlined,
              label: '${activePayments.length} recurring '
                  '${activePayments.length == 1 ? 'payment' : 'payments'}',
              value: _fmt(ref, recurringTotal),
              color: colors.warning,
            ),
          if (activeLoans.isNotEmpty) ...[
            const SizedBox(height: Insets.sm),
            _line(
              context,
              icon: Icons.account_balance_outlined,
              label: '${activeLoans.length} '
                  '${activeLoans.length == 1 ? 'loan' : 'loans'} outstanding',
              value: _fmt(ref, outstanding),
              color: colors.critical,
            ),
            const SizedBox(height: Insets.sm),
            _line(
              context,
              icon: Icons.payments_outlined,
              label: 'Combined EMI per cycle',
              value: _fmt(ref, emiTotal),
              color: colors.info,
            ),
          ],
        ],
      ),
    );
  }

  Widget _line(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: Insets.sm),
        Expanded(child: Text(label, style: text.bodyMedium)),
        Text(value, style: text.titleSmall),
      ],
    );
  }
}
