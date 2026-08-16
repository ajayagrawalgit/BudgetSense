import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/feature_providers.dart';
import '../../app/providers.dart';
import '../../core/constants/enums.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_resolver.dart';
import '../../core/utils/friendly_date.dart';
import '../../core/utils/money.dart';
import '../../data/seed/default_data.dart';
import '../../domain/entities/commitment_entities.dart';
import '../../domain/services/due_items.dart';
import '../common/app_feedback.dart';
import '../common/calm_widgets.dart';
import '../settings/settings_controller.dart';
import 'emi_record_sheet.dart';
import 'loan_editor_sheet.dart';
import 'payment_editor_sheet.dart';
import '../../core/utils/haptics.dart';

/// Recurring commitments & loans (Sections 7 & 9). Two calm tabs; each item can
/// be completed/paid, which optionally spawns a transaction and advances the
/// schedule via the pure [RecurrenceService].
class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Payments'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Recurring'), Tab(text: 'Loans')],
          ),
        ),
        body: const SafeArea(
          child: TabBarView(
            children: [_RecurringTab(), _LoansTab()],
          ),
        ),
      ),
    );
  }
}

class _RecurringTab extends ConsumerWidget {
  const _RecurringTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recurringPaymentsStreamProvider);
    // Loans that opted in are listed here too. They are merged as views, never
    // copied into recurring payments, so an EMI is still settled (and counted)
    // exactly once. See [buildDueItems].
    final loans = ref.watch(loansStreamProvider).valueOrNull ?? const [];
    final settings = ref.watch(settingsControllerProvider).valueOrNull;
    final symbol = settings?.currencySymbol ?? Money.defaultCurrencySymbol;
    final locale = settings?.localeCode;

    return Stack(
      children: [
        async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => CalmEmptyState(
            title: 'Could not load',
            message: '$e',
            icon: Icons.error_outline,
          ),
          data: (payments) {
            final items = buildDueItems(payments: payments, loans: loans);
            if (items.isEmpty) {
              return const CalmEmptyState(
                title: 'No recurring payments yet',
                message: 'Add SIPs, subscriptions, rent, EMIs and more. '
                    'Auto-add and reminders are supported.',
                icon: Icons.event_repeat_outlined,
                illustration: CalmIllustration.calendar,
              );
            }
            // Split into what is due through the end of THIS month (the working
            // list that shrinks as you settle things) and everything later (the
            // collapsible Upcoming section). Settling an item advances its due
            // date past month-end, so it slides out of the list.
            final calendar = ref.watch(financialCalendarProvider);
            final now = DateTime.now();
            final monthEnd = calendar.monthRangeFor(now).end;
            final due = [
              for (final i in items)
                if (!i.dueDate.isAfter(monthEnd)) i,
            ];
            final upcoming = [
              for (final i in items)
                if (i.dueDate.isAfter(monthEnd)) i,
            ];

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                Insets.lg,
                Insets.lg,
                Insets.lg,
                96,
              ),
              children: [
                if (due.isEmpty)
                  _AllCaughtUpCard(month: FriendlyDate.monthName(now.month))
                else
                  for (final i in due) ...[
                    _DueRow(item: i, symbol: symbol, locale: locale),
                    const SizedBox(height: Insets.sm),
                  ],
                if (upcoming.isNotEmpty) ...[
                  const SizedBox(height: Insets.sm),
                  _UpcomingSection(
                    items: upcoming,
                    symbol: symbol,
                    locale: locale,
                  ),
                ],
              ],
            );
          },
        ),
        Positioned(
          right: Insets.lg,
          bottom: Insets.lg,
          child: FloatingActionButton.extended(
            heroTag: 'add_recurring',
            onPressed: () => PaymentEditorSheet.show(context),
            icon: const Icon(Icons.add),
            label: const Text('Payment'),
          ),
        ),
      ],
    );
  }
}

/// Calm state shown in the Recurring tab once everything due this month has been
/// paid: the working list is empty, but upcoming commitments still wait below.
class _AllCaughtUpCard extends StatelessWidget {
  const _AllCaughtUpCard({required this.month});

  final String month;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.colors;
    return CalmCard(
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, size: 18, color: colors.positive),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('All paid for $month', style: text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  'Nothing else is due this month. Upcoming commitments are '
                  'below when you want to peek.',
                  style: text.bodySmall?.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A collapsed, aesthetic reveal of everything due after this month, grouped by
/// the month it falls in. Read-only glances: tap a row to edit that payment.
class _UpcomingSection extends StatelessWidget {
  const _UpcomingSection({
    required this.items,
    required this.symbol,
    required this.locale,
  });

  final List<DueItem> items;
  final String symbol;
  final String? locale;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.colors;

    // Group by "Month Year" while preserving the sorted (soonest-first) order.
    final groups = <String, List<DueItem>>{};
    for (final i in items) {
      final key = FriendlyDate.monthYear(i.dueDate);
      groups.putIfAbsent(key, () => []).add(i);
    }

    return CollapsibleCard(
      title: 'Upcoming',
      subtitle: Text(
        '${items.length}',
        style: text.labelLarge?.copyWith(color: colors.textFaint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in groups.entries) ...[
            Padding(
              padding: const EdgeInsets.only(top: Insets.sm, bottom: Insets.xs),
              child: Text(
                entry.key,
                style: text.labelMedium?.copyWith(color: colors.textFaint),
              ),
            ),
            for (final i in entry.value)
              _UpcomingRow(item: i, symbol: symbol, locale: locale),
          ],
        ],
      ),
    );
  }
}

/// A quiet, read-only glance at a future commitment (payment or loan EMI).
class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({
    required this.item,
    required this.symbol,
    required this.locale,
  });

  final DueItem item;
  final String symbol;
  final String? locale;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.colors;

    // Future items are read-only here: tapping opens the right editor rather
    // than settling anything. Nothing is ever recorded from this list.
    final (cadence, amount, onTap) = switch (item) {
      PaymentDueItem(:final payment) => (
          payment.frequency.label,
          payment.amount,
          () => PaymentEditorSheet.show(context, existing: payment),
        ),
      LoanDueItem(:final loan) => (
          'EMI \u00b7 ${loan.frequency.label}',
          loan.emi,
          () => LoanEditorSheet.show(context, existing: loan),
        ),
    };

    return InkWell(
      onTap: onTap,
      borderRadius: Corners.sm,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.sm),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: text.bodyMedium),
                  const SizedBox(height: 1),
                  Text(
                    '$cadence \u00b7 due '
                    '${FriendlyDate.relative(item.dueDate, locale: locale)}',
                    style: text.bodySmall?.copyWith(color: colors.textFaint),
                  ),
                ],
              ),
            ),
            Text(
              amount.format(currencySymbol: symbol, locale: locale),
              style: text.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// A due item, rendered for whichever source it came from.
///
/// Keeps the branch in exactly one place: a recurring payment offers
/// "Mark paid", a loan offers "Record EMI" and opens the same sheet the Loans
/// tab uses, so outstanding balance and repayment progress update identically
/// wherever it was tapped.
class _DueRow extends StatelessWidget {
  const _DueRow({
    required this.item,
    required this.symbol,
    required this.locale,
  });

  final DueItem item;
  final String symbol;
  final String? locale;

  @override
  Widget build(BuildContext context) {
    return switch (item) {
      PaymentDueItem(:final payment) =>
        _RecurringRow(payment: payment, symbol: symbol, locale: locale),
      LoanDueItem(:final loan) =>
        _LoanDueRow(loan: loan, symbol: symbol, locale: locale),
    };
  }
}

/// A loan EMI listed among the recurring commitments. Deliberately mirrors
/// [_RecurringRow]'s shape so the list reads as one thing, with the loan's own
/// affordances: it opens the loan editor, and settles via the EMI sheet.
class _LoanDueRow extends StatelessWidget {
  const _LoanDueRow({
    required this.loan,
    required this.symbol,
    required this.locale,
  });

  final LoanEntity loan;
  final String symbol;
  final String? locale;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.colors;
    final due = loan.nextPaymentDate!;
    final overdue = due.isBefore(DateTime.now());

    return CalmCard(
      onTap: () => LoanEditorSheet.show(context, existing: loan),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loan.name, style: text.titleSmall),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      overdue ? Icons.error_outline : Icons.account_balance,
                      size: 13,
                      color: overdue ? colors.critical : colors.textFaint,
                    ),
                    const SizedBox(width: Insets.xs),
                    Text(
                      'EMI · ${loan.frequency.label}',
                      style: text.bodySmall,
                    ),
                  ],
                ),
                Text(
                  '${overdue ? 'Overdue' : 'Due'} '
                  '${FriendlyDate.relative(due, locale: locale)}',
                  style: text.bodySmall?.copyWith(
                    color: overdue ? colors.critical : colors.textFaint,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                loan.emi.format(currencySymbol: symbol, locale: locale),
                style: text.titleSmall,
              ),
              const SizedBox(height: Insets.xs),
              TextButton(
                onPressed: () => EmiRecordSheet.show(context, loan: loan),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
                  minimumSize: const Size(0, 32),
                ),
                child: const Text('Record EMI'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecurringRow extends ConsumerWidget {
  const _RecurringRow({
    required this.payment,
    required this.symbol,
    required this.locale,
  });

  final RecurringPaymentEntity payment;
  final String symbol;
  final String? locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final colors = context.colors;
    final now = DateTime.now();
    final overdue = payment.isOverdue(now);
    final due = payment.nextDueDate;

    return CalmCard(
      onTap: () => PaymentEditorSheet.show(context, existing: payment),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(payment.name, style: text.titleSmall),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      overdue ? Icons.error_outline : Icons.schedule,
                      size: 13,
                      color: overdue ? colors.critical : colors.textFaint,
                    ),
                    const SizedBox(width: Insets.xs),
                    Text(
                      '${payment.kind.label} · ${payment.frequency.label}',
                      style: text.bodySmall,
                    ),
                  ],
                ),
                Text(
                  '${overdue ? 'Overdue' : 'Due'} '
                  '${FriendlyDate.relative(due, locale: locale)}',
                  style: text.bodySmall?.copyWith(
                    color: overdue ? colors.critical : colors.textFaint,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                payment.amount.format(currencySymbol: symbol, locale: locale),
                style: text.titleSmall,
              ),
              const SizedBox(height: Insets.xs),
              TextButton(
                onPressed: () => _markComplete(context, ref),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
                  minimumSize: const Size(0, 32),
                ),
                child: const Text('Mark paid'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _markComplete(BuildContext context, WidgetRef ref) async {
    final service = ref.read(recurrenceServiceProvider);
    // Record the payment/investment against the day the user actually marks it
    // paid, not its scheduled due date. This is correct whether they pay early
    // or clear an overdue one. The schedule's next due date still advances on
    // its planned cadence (handled inside complete()).
    final result = service.complete(
      payment,
      newTransactionId: DefaultDataSeeder.newId(),
      paidAt: DateTime.now(),
    );
    if (result.transaction != null) {
      await ref.read(transactionRepositoryProvider).upsert(result.transaction!);
    }
    await ref.read(recurringPaymentRepositoryProvider).upsert(result.updated);
    Haptics.confirm();
    if (!context.mounted) return;
    context.showMessage(
      result.transaction != null
          ? '${payment.name} paid & recorded'
          : '${payment.name} marked paid',
    );
  }
}

class _LoansTab extends ConsumerWidget {
  const _LoansTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(loansStreamProvider);
    final settings = ref.watch(settingsControllerProvider).valueOrNull;
    final symbol = settings?.currencySymbol ?? Money.defaultCurrencySymbol;
    final locale = settings?.localeCode;

    return Stack(
      children: [
        async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => CalmEmptyState(
            title: 'Could not load',
            message: '$e',
            icon: Icons.error_outline,
          ),
          data: (items) {
            if (items.isEmpty) {
              return const CalmEmptyState(
                title: 'No loans tracked',
                message: 'Add a loan to track EMIs, outstanding balance and '
                    'repayment progress.',
                icon: Icons.account_balance_outlined,
                illustration: CalmIllustration.sprig,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                Insets.lg,
                Insets.lg,
                Insets.lg,
                96,
              ),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: Insets.sm),
              itemBuilder: (context, i) =>
                  _LoanRow(loan: items[i], symbol: symbol, locale: locale),
            );
          },
        ),
        Positioned(
          right: Insets.lg,
          bottom: Insets.lg,
          child: FloatingActionButton.extended(
            heroTag: 'add_loan',
            onPressed: () => LoanEditorSheet.show(context),
            icon: const Icon(Icons.add),
            label: const Text('Loan'),
          ),
        ),
      ],
    );
  }
}

class _LoanRow extends ConsumerStatefulWidget {
  const _LoanRow({
    required this.loan,
    required this.symbol,
    required this.locale,
  });

  final LoanEntity loan;
  final String symbol;
  final String? locale;

  @override
  ConsumerState<_LoanRow> createState() => _LoanRowState();
}

class _LoanRowState extends ConsumerState<_LoanRow> {
  bool _expanded = false;

  LoanEntity get loan => widget.loan;
  String get symbol => widget.symbol;
  String? get locale => widget.locale;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.colors;

    return CalmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: whole row toggles the expandable panel.
          InkWell(
            onTap: () {
              setState(() => _expanded = !_expanded);
              Haptics.selection();
            },
            borderRadius: Corners.sm,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(loan.name, style: text.titleSmall)),
                    Text(
                      'EMI ${loan.emi.format(currencySymbol: symbol, locale: locale)}',
                      style: text.titleSmall,
                    ),
                    const SizedBox(width: Insets.sm),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: Motion.fast,
                      child: Icon(
                        Icons.expand_more,
                        size: 20,
                        color: colors.textFaint,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Outstanding '
                  '${loan.outstandingPrincipal.format(currencySymbol: symbol, locale: locale)}'
                  ' of '
                  '${loan.originalPrincipal.format(currencySymbol: symbol, locale: locale)}',
                  style: text.bodySmall,
                ),
                const SizedBox(height: Insets.sm),
                CalmProgressBar(
                  fraction: loan.repaymentProgress,
                  color: colors.info,
                ),
                const SizedBox(height: Insets.xs),
                Text(
                  '${(loan.repaymentProgress * 100).round()}% repaid',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          ClipRect(
            child: AnimatedSize(
              duration: Motion.base,
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? _panel(context, text, colors)
                  : const SizedBox(width: double.infinity),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel(BuildContext context, TextTheme text, AppColors colors) {
    final lastEmi = ref.watch(lastLoanPaymentProvider(loan.id));

    return Padding(
      padding: const EdgeInsets.only(top: Insets.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(height: 1, color: colors.border),
          const SizedBox(height: Insets.md),

          // Last EMI recorded (date + time + amount).
          Row(
            children: [
              Icon(Icons.history, size: 15, color: colors.textFaint),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: lastEmi.when(
                  loading: () =>
                      Text('Loading last EMI…', style: text.bodySmall),
                  error: (_, __) =>
                      Text('Last EMI unavailable', style: text.bodySmall),
                  data: (txn) => txn == null
                      ? Text(
                          'No EMIs recorded yet.',
                          style: text.bodySmall
                              ?.copyWith(color: colors.textSecondary),
                        )
                      : Text(
                          'Last EMI: '
                          '${txn.amount.format(currencySymbol: symbol, locale: locale)}'
                          ' on ${FriendlyDate.short(txn.occurredAt, locale: locale)}'
                          ' at ${TimeOfDay.fromDateTime(txn.occurredAt).format(context)}',
                          style: text.bodySmall
                              ?.copyWith(color: colors.textSecondary),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),

          // Settling happens in the shared EMI sheet, the same one the
          // recurring due list opens, so there is exactly one way to record an
          // EMI no matter where you started from.
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => EmiRecordSheet.show(context, loan: loan),
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Record EMI'),
            ),
          ),
          const SizedBox(height: Insets.xs),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => LoanEditorSheet.show(context, existing: loan),
              child: const Text('Edit loan'),
            ),
          ),
        ],
      ),
    );
  }
}
