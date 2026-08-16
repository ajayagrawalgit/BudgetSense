import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/feature_providers.dart';
import '../../app/providers.dart';
import '../../core/constants/branding.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/category_icons.dart';
import '../../core/theme/theme_resolver.dart';
import '../../core/utils/friendly_date.dart';
import '../../core/utils/greeting.dart';
import '../../core/utils/money.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/services/summary_service.dart';
import '../common/calm_widgets.dart';
import '../common/confetti_overlay.dart';
import '../common/feedback_widgets.dart';
import '../common/ink_flourishes.dart';
import '../common/ink_veil.dart';
import '../quick_add/quick_add_sheet.dart';
import '../settings/settings_controller.dart';
import '../settings/settings_state.dart';
import 'month_calendar.dart';
import 'mood_strip.dart';
import 'quick_add_card.dart';
import '../../core/utils/haptics.dart';

/// The monthly financial overview (Section 10). Deliberately restrained - a
/// balance headline, a compact stat grid, and category usage bars. The month
/// header supports left/right swipe to change month, and tapping it expands a
/// calm calendar for the month.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _calendarOpen = false;

  /// Amounts (Income / Spent / Invested) start hidden behind a blur for calm,
  /// privacy-first glanceability. Only Balance shows by default; tapping the
  /// eye reveals the rest. Session-scoped on purpose (re-hides on relaunch).
  bool _revealValues = false;

  bool _isCurrentMonth(DateTime m) {
    final now = DateTime.now();
    return m.year == now.year && m.month == now.month;
  }

  void _changeMonth(int delta) {
    final current = ref.read(focusedMonthProvider);
    if (delta > 0 && _isCurrentMonth(current)) return; // no future months
    ref.read(focusedMonthProvider.notifier).state =
        DateTime(current.year, current.month + delta);
    Haptics.selection();
  }

  void _resetToday() {
    ref.read(focusedMonthProvider.notifier).state = DateTime.now();
    Haptics.selection();
  }

  @override
  Widget build(BuildContext context) {
    final txnsAsync = ref.watch(monthTransactionsProvider);
    final summary = ref.watch(monthlySummaryProvider);
    final cats = ref.watch(categoriesStreamProvider).valueOrNull ?? const [];
    final settings =
        ref.watch(settingsControllerProvider).valueOrNull.orDefaults;
    final focused = ref.watch(focusedMonthProvider);
    final calendar = ref.watch(financialCalendarProvider);
    final isMonthOpening =
        calendar.monthRangeFor(DateTime.now()).start.day == DateTime.now().day;
    final text = Theme.of(context).textTheme;
    final colors = context.colors;

    String money(Money v) => settings.formatMoney(v);

    final txns = txnsAsync.valueOrNull ?? const [];

    // The balance breathes only when the month is genuinely calm: current
    // month, positive balance, nothing overdue. BreathingPulse itself also
    // stands still under reduce-motion.
    final calm = _isCurrentMonth(focused) &&
        !summary.totalBalance.isNegative &&
        ref.watch(overduePaymentsProvider).isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          if (isMonthOpening)
            IconButton(
              tooltip: 'Last month, in brief',
              onPressed: () => context.push('/month-close'),
              icon: const Icon(Icons.auto_stories_outlined),
            ),
        ],
      ),
      floatingActionButton: CalmFab(
        tooltip: 'Add transaction',
        heroTag: 'fab_dashboard',
        onPressed: () => QuickAddSheet.show(context),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _GreetingHeader(settings: settings),

            // Month area: swipe left/right to change month, tap to expand the
            // calendar. This whole region owns horizontal drags, so the section
            // swipe (shell) only fires on the content below.
            GestureDetector(
              onHorizontalDragEnd: (d) {
                final v = d.primaryVelocity ?? 0;
                if (v > 250) {
                  _changeMonth(-1);
                } else if (v < -250) {
                  _changeMonth(1);
                }
              },
              child: Column(
                children: [
                  _monthHeader(context, focused),
                  ClipRect(
                    child: AnimatedSize(
                      duration: Motion.base,
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: _calendarOpen
                          ? MonthCalendar(
                              month: focused,
                              transactions: txnsAsync.valueOrNull ?? const [],
                              currencySymbol: settings.currencySymbol,
                              locale: settings.localeCode,
                              compact: settings.numberFormatCompact,
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: OverPullRipple(
                child: txnsAsync.isLoading
                    ? const DashboardSkeleton()
                    : txns.isEmpty
                        ? (_isCurrentMonth(focused)
                            // A fresh month still shows the delight (enso, sprig,
                            // weather) so the craft is there from day one, with a
                            // gentle nudge to log the first entry.
                            ? ListView(
                                padding: const EdgeInsets.all(Insets.lg),
                                children: const [
                                  SizedBox(height: Insets.md),
                                  CalmEmptyState(
                                    title: 'A calm, clean slate',
                                    message: 'Tap the + below to log your '
                                        'first income or expense. Your balance '
                                        'and insights grow from here.',
                                    brandAsset: BrandAssets.ensoRing,
                                  ),
                                  SizedBox(height: Insets.lg),
                                  MoodStrip(),
                                  SizedBox(height: Insets.lg),
                                  _PaymentsCard(),
                                ],
                              )
                            : _EmptyDashboard(
                                monthLabel:
                                    FriendlyDate.monthName(focused.month),
                              ))
                        : ListView(
                            padding: const EdgeInsets.all(Insets.lg),
                            children: [
                              // Balance headline. Balance is always visible; the
                              // three sub-figures hide behind a blur until revealed.
                              SealableSummary(
                                closed: !_isCurrentMonth(focused),
                                child: CalmCard(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Balance this month',
                                              style: text.labelMedium,
                                            ),
                                          ),
                                          _EyeToggle(
                                            revealed: _revealValues,
                                            onTap: () {
                                              setState(
                                                () => _revealValues =
                                                    !_revealValues,
                                              );
                                              Haptics.selection();
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: Insets.xs),
                                      InkVeil(
                                        revealed: _revealValues,
                                        child: BreathingPulse(
                                          enabled: calm,
                                          child: AnimatedMoneyText(
                                            minorUnits:
                                                summary.totalBalance.minorUnits,
                                            format: (m) => money(Money(m)),
                                            style: text.displaySmall?.copyWith(
                                              color: colors.textPrimary,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (summary.totalBalance.isNegative) ...[
                                        const SizedBox(height: Insets.xs),
                                        Text(
                                          "You've spent a little more than you earned "
                                          'this month.',
                                          style: text.bodySmall?.copyWith(
                                            color: colors.textSecondary,
                                          ),
                                        ),
                                      ] else if (summary.positiveNote !=
                                          null) ...[
                                        const SizedBox(height: Insets.xs),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.spa_outlined,
                                              size: 14,
                                              color: colors.positive,
                                            ),
                                            const SizedBox(width: Insets.xs),
                                            Expanded(
                                              child: Text(
                                                summary.positiveNote!,
                                                style: text.bodySmall?.copyWith(
                                                  color: colors.textSecondary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      const SizedBox(height: Insets.md),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: StatTile(
                                              label: 'Income',
                                              value: money(summary.totalGains),
                                              icon: Icons.south_west,
                                              valueColor: colors.positive,
                                              revealed: _revealValues,
                                              veilSeed: 1,
                                            ),
                                          ),
                                          Expanded(
                                            child: StatTile(
                                              label: 'Spent',
                                              value: money(summary.totalSpent),
                                              icon: Icons.north_east,
                                              valueColor: colors.negative,
                                              revealed: _revealValues,
                                              veilSeed: 2,
                                            ),
                                          ),
                                          Expanded(
                                            child: StatTile(
                                              label: 'Invested',
                                              value: money(
                                                summary.totalInvestments,
                                              ),
                                              icon: Icons.savings_outlined,
                                              valueColor: colors.info,
                                              revealed: _revealValues,
                                              veilSeed: 3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: Insets.lg),

                              // Fast path: log one expense without leaving home.
                              const QuickAddCard(),
                              const SizedBox(height: Insets.lg),

                              // Purely-for-delight: ensō, sprig and wallet
                              // weather. A feeling for the month, not a metric.
                              const MoodStrip(),
                              const SizedBox(height: Insets.lg),

                              // Secondary sections: collapsed by default to keep the
                              // home screen calm and uncluttered.
                              CollapsibleCard(
                                title: 'Where it went',
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: _whereItWentRows(
                                      context, summary, cats, money),
                                ),
                              ),
                              const SizedBox(height: Insets.lg),

                              CollapsibleCard(
                                title: 'Rates',
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _rateRow(
                                      context,
                                      'Savings rate',
                                      summary.savingsRate,
                                      colors.positive,
                                    ),
                                    const SizedBox(height: Insets.md),
                                    _rateRow(
                                      context,
                                      'Investment rate',
                                      summary.investmentRate,
                                      colors.info,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: Insets.lg),
                              const _PaymentsCard(),
                            ],
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _monthHeader(BuildContext context, DateTime focused) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final isCurrent = _isCurrentMonth(focused);
    final label = FriendlyDate.monthYear(focused);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.lg,
        vertical: Insets.xs,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            iconSize: 22,
            color: colors.textPrimary,
            tooltip: 'Previous month',
            onPressed: () => _changeMonth(-1),
          ),
          Expanded(
            child: InkWell(
              onTap: () {
                setState(() => _calendarOpen = !_calendarOpen);
                Haptics.selection();
              },
              borderRadius: Corners.sm,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Insets.xs),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(label, style: text.titleSmall),
                    const SizedBox(width: Insets.xs),
                    AnimatedRotation(
                      turns: _calendarOpen ? 0.5 : 0,
                      duration: Motion.fast,
                      child: Icon(
                        Icons.expand_more,
                        size: 18,
                        color: colors.textFaint,
                      ),
                    ),
                    if (!isCurrent) ...[
                      const SizedBox(width: Insets.sm),
                      Semantics(
                        button: true,
                        label: 'Back to this month',
                        child: GestureDetector(
                          onTap: _resetToday,
                          child: Icon(
                            Icons.today,
                            size: 14,
                            color: colors.accent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            iconSize: 22,
            color: isCurrent ? colors.textFaint : colors.textPrimary,
            tooltip: 'Next month',
            onPressed: isCurrent ? null : () => _changeMonth(1),
          ),
        ],
      ),
    );
  }

  /// Dynamic "Where it went": the month's categories ranked by spend, using each
  /// category's own name, color and icon. Nothing is hardcoded, so it reflects
  /// exactly the categories the user has created.
  List<Widget> _whereItWentRows(
    BuildContext context,
    MonthlySummary summary,
    List<CategoryEntity> cats,
    String Function(Money) money,
  ) {
    final byId = {for (final c in cats) c.id: c};
    final rows = summary.perCategory.entries
        .where((e) => e.value.minorUnits > 0)
        .toList()
      ..sort((a, b) => b.value.minorUnits.compareTo(a.value.minorUnits));
    if (rows.isEmpty) {
      return [
        Text(
          'No categorised spending yet this month.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ];
    }
    return [
      for (final e in rows.take(6))
        _bucketRow(
          context,
          byId[e.key]?.name ?? 'Other',
          e.value,
          money,
          Color(byId[e.key]?.colorValue ?? 0xFF9E9E9E),
          categoryIcon(
            byId[e.key]?.iconCodePoint ?? kFallbackCategoryIcon.codePoint,
          ),
        ),
    ];
  }

  Widget _bucketRow(
    BuildContext context,
    String label,
    Money amount,
    String Function(Money) money,
    Color color,
    IconData icon,
  ) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: Insets.sm),
          Expanded(child: Text(label, style: text.bodyMedium)),
          Text(money(amount), style: text.titleSmall),
        ],
      ),
    );
  }

  Widget _rateRow(
    BuildContext context,
    String label,
    double fraction,
    Color color,
  ) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: text.bodyMedium),
            Text('${(fraction * 100).round()}%', style: text.titleSmall),
          ],
        ),
        const SizedBox(height: Insets.xs),
        CalmProgressBar(fraction: fraction, color: color),
      ],
    );
  }
}

/// The first-run (or empty-month) home. The single most-seen empty state, so it
/// gets the nicest motif: the enso mark that gives the app its name.
class _EmptyDashboard extends StatelessWidget {
  const _EmptyDashboard({required this.monthLabel});

  final String monthLabel;

  @override
  Widget build(BuildContext context) {
    return CalmEmptyState(
      title: 'Nothing in $monthLabel',
      message: 'No income or expenses were recorded this month.',
      icon: Icons.spa_outlined,
      illustration: CalmIllustration.enso,
    );
  }
}

/// A warm, personal greeting shown at the very top of the dashboard.
class _GreetingHeader extends ConsumerWidget {
  const _GreetingHeader({required this.settings});

  final SettingsState? settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final template = ref.watch(dashboardGreetingProvider);
    final name = resolveDisplayName(settings);
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.lg,
        Insets.md,
        Insets.lg,
        Insets.xs,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        // A quiet easter egg: long-press to hear another hello. The greeting is
        // otherwise fixed for the session, so this is a small way to reshuffle
        // it when a line makes you smile (or does not).
        child: GestureDetector(
          onLongPress: () {
            Haptics.selection();
            ref.invalidate(dashboardGreetingProvider);
          },
          child: Text(
            formatGreeting(template, name),
            style: text.titleLarge,
          ),
        ),
      ),
    );
  }
}

/// Color-independent threshold warnings, now shown on the Insights screen.
/// (Kept out of the dashboard to keep the home screen calm.)

/// This month's dues only (no future window). When nothing is due it becomes a
/// calm all-clear card you can double-tap for a small celebration.
class _PaymentsCard extends ConsumerWidget {
  const _PaymentsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = ref.watch(overduePaymentsProvider);
    final settings =
        ref.watch(settingsControllerProvider).valueOrNull.orDefaults;
    final text = Theme.of(context).textTheme;
    final colors = context.colors;

    // Nothing due this month: a calm all-clear card. Double-tap it for a small
    // celebration that fits the moment (firework when you hit your saving
    // target, coins when a loan is fully paid, autumn leaves in Sep..Nov, else
    // confetti). Always shown, so the delight is always a tap away. Honours
    // reduce-motion inside ConfettiOverlay.
    if (due.isEmpty) {
      final summary = ref.watch(monthlySummaryProvider);
      final lastMonth = ref.watch(previousMonthSummaryProvider);
      final loans = ref.watch(loansStreamProvider).valueOrNull ?? const [];
      final variant = celebrationVariant(
        // Firework only when this month genuinely improves on the last one.
        beatLastMonth: summary.savingsRate > lastMonth.savingsRate,
        loanCleared:
            loans.any((l) => !l.isArchived && l.repaymentProgress >= 1.0),
        month: DateTime.now().month,
      );
      return GestureDetector(
        onDoubleTap: () {
          Haptics.confirm();
          ConfettiOverlay.shower(context, variant: variant);
        },
        child: CalmCard(
          child: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 18,
                color: colors.positive,
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Payments', style: text.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      'Nothing due right now. Breathe easy.',
                      style:
                          text.bodySmall?.copyWith(color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Something is due: a plain list of this month's dues, no future window.
    return CalmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Due this month', style: text.titleMedium)),
              Text(
                '${due.length}',
                style: text.labelMedium?.copyWith(color: colors.critical),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          for (final p in due)
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.xs),
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 15, color: colors.critical),
                  const SizedBox(width: Insets.sm),
                  Expanded(child: Text(p.name, style: text.bodyMedium)),
                  Text(
                    settings.formatMoney(p.amount),
                    style: text.titleSmall,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The eye button that reveals/hides the sensitive amounts on the dashboard.
class _EyeToggle extends StatelessWidget {
  const _EyeToggle({required this.revealed, required this.onTap});

  final bool revealed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: revealed ? 'Hide amounts' : 'Show amounts',
      icon: Icon(
        revealed ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        size: 20,
        color: colors.textFaint,
      ),
      onPressed: onTap,
    );
  }
}
