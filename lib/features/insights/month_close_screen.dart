import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/feature_providers.dart';
import '../../app/providers.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_resolver.dart';
import '../../core/utils/friendly_date.dart';
import '../../core/utils/money.dart';
import '../../domain/services/month_close_service.dart';
import '../common/calm_widgets.dart';
import '../settings/settings_controller.dart';
import '../settings/settings_state.dart';

/// A quiet reflection on the most recently completed financial month.
///
/// This is deliberately a page, not a first-launch modal. A financial close is
/// personal and deserves an unhurried moment, not a dialog that blocks someone
/// trying to log a taxi at 8 AM on the first.
class MonthCloseScreen extends ConsumerWidget {
  const MonthCloseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(lastCompletedMonthCloseProvider);
    final settings =
        ref.watch(settingsControllerProvider).valueOrNull.orDefaults;
    final calendar = ref.watch(financialCalendarProvider);
    final range = calendar.monthRangeFor(
      calendar.monthRangeFor(DateTime.now()).start.subtract(
            const Duration(days: 1),
          ),
    );
    final text = Theme.of(context).textTheme;
    final colors = context.colors;

    String money(Money value) => settings.formatMoney(value);

    return Scaffold(
      appBar: AppBar(title: const Text('Month close')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Insets.lg,
            Insets.lg,
            Insets.lg,
            Insets.xl,
          ),
          children: [
            Text(
              '${FriendlyDate.monthName(range.start.month)}, in brief',
              style: text.headlineSmall,
            ),
            const SizedBox(height: Insets.xs),
            Text(
              '${FriendlyDate.short(range.start, locale: settings.localeCode)} '
              'to ${FriendlyDate.short(range.end, locale: settings.localeCode)}',
              style: text.bodySmall?.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: Insets.lg),
            if (!report.hasActivity)
              const CalmEmptyState(
                title: 'A quiet month',
                message: 'There were no entries to reflect on yet.',
                icon: Icons.auto_stories_outlined,
                illustration: CalmIllustration.journal,
              )
            else ...[
              _OpeningNote(report: report, money: money),
              const SizedBox(height: Insets.md),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      label: 'Came in',
                      value: money(report.summary.totalGains),
                      icon: Icons.south_west_outlined,
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: StatTile(
                      label: 'Went out',
                      value: money(report.summary.totalSpent),
                      icon: Icons.north_east_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.sm),
              StatTile(
                label: 'Left for you',
                value: money(report.summary.totalSavings),
                icon: Icons.account_balance_outlined,
              ),
              const SizedBox(height: Insets.lg),
              const SectionLabel('What stood out'),
              const SizedBox(height: Insets.sm),
              _DetailCard(report: report, settings: settings, money: money),
              const SizedBox(height: Insets.lg),
              const SectionLabel('Promises you set'),
              const SizedBox(height: Insets.sm),
              _ThresholdCard(report: report),
            ],
          ],
        ),
      ),
    );
  }
}

class _OpeningNote extends StatelessWidget {
  const _OpeningNote({required this.report, required this.money});

  final MonthCloseReport report;
  final String Function(Money) money;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.colors;
    final direction = report.spendChange == 0
        ? 'matched the month before'
        : report.spendChange > 0
            ? '${(report.spendChange * 100).round()}% more than the month before'
            : '${(-report.spendChange * 100).round()}% less than the month before';
    return CalmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('A page turned', style: text.titleMedium),
          const SizedBox(height: Insets.xs),
          Text(
            'You spent ${money(report.summary.totalSpent)}, $direction.',
            style: text.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.report,
    required this.settings,
    required this.money,
  });

  final MonthCloseReport report;
  final SettingsState settings;
  final String Function(Money) money;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.colors;
    final biggest = report.biggestExpense;
    final weekday =
        report.busiestWeekday == null ? null : _weekday(report.busiestWeekday!);

    return CalmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${report.expenseCount} expenses, averaging '
            '${money(report.averageExpense)}.',
            style: text.bodyMedium,
          ),
          if (biggest != null) ...[
            const SizedBox(height: Insets.sm),
            Text(
              'The biggest was ${biggest.name} at '
              '${money(biggest.amount)}.',
              style: text.bodyMedium?.copyWith(color: colors.textSecondary),
            ),
          ],
          if (weekday != null) ...[
            const SizedBox(height: Insets.sm),
            Text(
              '$weekday carried the most spending.',
              style: text.bodyMedium?.copyWith(color: colors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  static String _weekday(int value) => switch (value) {
        DateTime.monday => 'Monday',
        DateTime.tuesday => 'Tuesday',
        DateTime.wednesday => 'Wednesday',
        DateTime.thursday => 'Thursday',
        DateTime.friday => 'Friday',
        DateTime.saturday => 'Saturday',
        DateTime.sunday => 'Sunday',
        _ => 'That day',
      };
}

class _ThresholdCard extends StatelessWidget {
  const _ThresholdCard({required this.report});

  final MonthCloseReport report;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.colors;
    final line = report.thresholdsKept == 0 && report.thresholdsBreached == 0
        ? 'No thresholds were set for this month.'
        : '${report.thresholdsKept} kept, ${report.thresholdsBreached} needing attention.';
    return CalmCard(
      child: Row(
        children: [
          Icon(Icons.spa_outlined, color: colors.accent),
          const SizedBox(width: Insets.sm),
          Expanded(child: Text(line, style: text.bodyMedium)),
        ],
      ),
    );
  }
}
