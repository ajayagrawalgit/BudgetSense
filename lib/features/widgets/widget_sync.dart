import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/feature_providers.dart';
import '../../app/providers.dart';
import '../../core/constants/enums.dart';
import '../../core/services/widget_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/financial_calendar.dart';
import '../../core/utils/friendly_date.dart';
import '../../core/utils/money.dart';
import '../../domain/entities/commitment_entities.dart';
import '../settings/settings_controller.dart';
import 'spend_graph_footer.dart';

/// Live transactions for the *current* financial month (independent of the
/// dashboard's focused month), so widgets always reflect today.
final _currentMonthTransactionsProvider = StreamProvider.autoDispose((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  final calendar = ref.watch(financialCalendarProvider);
  return repo.watchForMonth(DateTime.now(), calendar: calendar);
});

/// Number of weeks in the no-spend graph (a GitHub-style year of history). The
/// widget renders however many trailing weeks fit its current width.
const kNoSpendWeeks = 53;

/// Live transactions across the whole no-spend window (~53 weeks), so the graph
/// can shade every day back to your first entry.
final _noSpendWindowProvider = StreamProvider.autoDispose((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final start = today.subtract(const Duration(days: kNoSpendWeeks * 7));
  final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
  return repo.watchInRange(DateRange(start, end));
});

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// The soonest unpaid commitment across recurring payments and loans, or null
/// when nothing is scheduled. Pure so it can be unit-tested. Overdue items sort
/// first (their date is in the past), which is exactly what we want to surface.
({String name, Money amount, DateTime due})? soonestDue(
  List<RecurringPaymentEntity> payments,
  List<LoanEntity> loans,
) {
  ({String name, Money amount, DateTime due})? best;
  void consider(String name, Money amount, DateTime due) {
    if (best == null || due.isBefore(best!.due)) {
      best = (name: name, amount: amount, due: due);
    }
  }

  for (final p in payments) {
    if (p.isArchived) continue;
    consider(p.name, p.amount, p.nextDueDate);
  }
  for (final l in loans) {
    final due = l.nextPaymentDate;
    if (l.isArchived || due == null) continue;
    consider(l.name, l.emi, due);
  }
  return best;
}

/// Scales a list of amounts to 0..100 percentages relative to the largest one,
/// so a set of bars fills proportionally (the biggest bucket fills the bar).
/// Returns all zeros when every value is zero. Pure and unit-tested.
List<int> relativePercents(List<int> values) {
  final max = values.fold<int>(0, (a, b) => a > b ? a : b);
  if (max <= 0) return [for (final _ in values) 0];
  return [for (final v in values) ((v / max) * 100).round().clamp(0, 100)];
}

/// Intensity level for a single day in the spend-activity graph, GitHub style:
///   '.' future day (skipped in the render),
///   '0' no expenses that day (empty cell),
///   '1'..'4' increasing number of expense records that day (light to dark).
///
/// The mapping favours "less to more": one record is the lightest shade, five or
/// more is the darkest. Days before any data simply have a zero count, so they
/// read as empty, exactly like a fresh contribution calendar.
String _dayLevel(DateTime day, DateTime today, Map<DateTime, int> counts) {
  if (day.isAfter(today)) return '.';
  final n = counts[day] ?? 0;
  if (n <= 0) return '0';
  if (n == 1) return '1';
  if (n == 2) return '2';
  if (n <= 4) return '3';
  return '4';
}

/// Builds the GitHub-style spend-activity graph as a column-major string of day
/// levels (week by week, each week 7 days Sun..Sat, ending with the current
/// week) and a per-column month label (empty except the column where a new
/// month begins). The native widget slices trailing weeks off [states]/[months]
/// to fit its width. Pure so it can be unit-tested.
///
/// [spendCounts] keys must be normalised to midnight (y/m/d) and hold the number
/// of expense records on that day.
({String states, List<String> months}) buildSpendGrid({
  required Map<DateTime, int> spendCounts,
  required DateTime today,
}) {
  final t = DateTime(today.year, today.month, today.day);
  // GitHub weeks run Sunday..Saturday; end on this week's Saturday.
  final daysUntilSat = (DateTime.saturday - t.weekday + 7) % 7;
  final end = t.add(Duration(days: daysUntilSat));
  final start = end.subtract(const Duration(days: kNoSpendWeeks * 7 - 1));

  final sb = StringBuffer();
  final months = <String>[];
  var lastMonth = -1;
  for (var week = 0; week < kNoSpendWeeks; week++) {
    for (var row = 0; row < 7; row++) {
      final day = start.add(Duration(days: week * 7 + row));
      sb.write(_dayLevel(day, t, spendCounts));
    }
    // Month label sits above the column whose Sunday opens a new month.
    final sunday = start.add(Duration(days: week * 7));
    if (sunday.month != lastMonth) {
      months.add(_monthAbbr[sunday.month - 1]);
      lastMonth = sunday.month;
    } else {
      months.add('');
    }
  }

  return (states: sb.toString(), months: months);
}

const _monthAbbr = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// A short human label for when a commitment is due, relative to [now].
String _dueLabel(DateTime due, DateTime now, String? locale) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(due.year, due.month, due.day);
  if (day.isBefore(today)) return 'Overdue';
  return 'Due ${FriendlyDate.relative(due, locale: locale, now: now)}';
}

/// Widget payload keys that reveal financial figures. These are masked when
/// app-lock is on, since the widget's backing SharedPreferences are readable
/// plaintext on the home screen.
const kSensitiveWidgetKeys = <String>{
  'balance', 'income', 'spend', 'invested', 'savingsRate', 'investmentRate',
  'avgDailySpend', 'projectedBalance',
  // Dynamic top-category bars: values and percentages reveal figures. Labels
  // (category names) are not figures, so they stay visible.
  'cat1Value', 'cat2Value', 'cat3Value', 'cat4Value',
  'cat1Pct', 'cat2Pct', 'cat3Pct', 'cat4Pct',
  // Extended widgets: figures and anything that leaks a figure.
  'savingsRateNum', 'investmentRateNum', 'runwayNote', 'nextDueAmount',
  'expenseAverage', 'biggestAmount',
  // The spend-activity graph reveals your day-by-day spending shape.
  'spendGrid',
};

const _maskedValue = '••••';

/// Masks the financial figures in a widget payload, leaving metadata
/// (currencySymbol, monthLabel, updatedAt) intact so the widget still shows it
/// belongs to BudgetSense.
Map<String, String> maskSensitive(Map<String, String> payload) => {
      for (final e in payload.entries)
        e.key: kSensitiveWidgetKeys.contains(e.key) ? _maskedValue : e.value,
    };

/// Computes the pre-formatted strings the home-screen widgets display. Recreated
/// whenever the underlying data, categories, or relevant settings change.
final widgetPayloadProvider = Provider.autoDispose<Map<String, String>>((ref) {
  final txns =
      ref.watch(_currentMonthTransactionsProvider).valueOrNull ?? const [];
  final cats = ref.watch(categoriesStreamProvider).valueOrNull ?? const [];
  final settings = ref.watch(settingsControllerProvider).valueOrNull;
  final summaryService = ref.watch(summaryServiceProvider);
  final insights = ref.watch(insightsServiceProvider);
  final calendar = ref.watch(financialCalendarProvider);
  final payments =
      ref.watch(recurringPaymentsStreamProvider).valueOrNull ?? const [];
  final loans = ref.watch(loansStreamProvider).valueOrNull ?? const [];
  final windowTxns = ref.watch(_noSpendWindowProvider).valueOrNull ?? const [];

  final symbol = settings?.currencySymbol ?? '₹';
  final locale = settings?.localeCode;

  final summary = summaryService.summarize(
    txns,
    investmentTreatment:
        settings?.investmentTreatment ?? InvestmentTreatment.separate,
  );

  final now = DateTime.now();
  final range = calendar.monthRangeFor(now);
  final avgDaily = insights.averageDailySpend(summary.totalSpent, range);
  final projected = insights.projectedMonthEndBalance(
    income: summary.totalGains,
    spentSoFar: summary.totalSpent,
    invested: summary.totalInvestments,
    monthRange: range,
    now: now,
  );

  String fmt(Money m) => m.format(currencySymbol: symbol, locale: locale);
  String pct(double f) => '${(f * 100).round()}%';

  // Top spending categories this month (fully dynamic - whatever the user has
  // created). Sorted by spend, capped at four, bars scaled to the biggest.
  final catById = {for (final c in cats) c.id: c};
  final catSpends = summary.perCategory.entries
      .where((e) => e.value.minorUnits > 0)
      .map(
        (e) => (
          name: catById[e.key]?.name ?? 'Other',
          amount: e.value,
        ),
      )
      .toList()
    ..sort((a, b) => b.amount.minorUnits.compareTo(a.amount.minorUnits));
  final topCats = catSpends.take(4).toList();
  final catBars =
      relativePercents([for (final c in topCats) c.amount.minorUnits]);
  final next = soonestDue(payments, loans);
  final stats = insights.expenseStats(txns);
  final monthName = _monthNames[now.month - 1];

  // Spend-activity graph: count expense records per day, then shade light to
  // dark by how many records fell on that day.
  final today = DateTime(now.year, now.month, now.day);
  final spendCounts = <DateTime, int>{};
  for (final t in windowTxns) {
    if (t.type != TransactionType.expense) continue;
    final d = DateTime(t.occurredAt.year, t.occurredAt.month, t.occurredAt.day);
    spendCounts[d] = (spendCounts[d] ?? 0) + 1;
  }
  final spendGraph = buildSpendGrid(spendCounts: spendCounts, today: today);
  // Footer line: motivating, name-aware (nickname preferred), rotates daily.
  final footerName = (settings?.userNickname.trim().isNotEmpty ?? false)
      ? settings!.userNickname.trim()
      : (settings?.userName.trim() ?? '');
  final footerText = spendFooterMessage(footerName, today);

  final balancePositive = !summary.totalBalance.isNegative;
  final balanceNote = balancePositive
      ? 'You are keeping more than you spend this month.'
      : 'You have spent a little more than you earned this month.';
  final runwayNote =
      'At this pace you will end $monthName around ${fmt(projected)}.';

  // Flatten the top categories into stable, indexed payload keys the native
  // widgets can read without knowing any category names in advance.
  final catPayload = <String, String>{'catCount': topCats.length.toString()};
  for (var i = 0; i < 4; i++) {
    final has = i < topCats.length;
    catPayload['cat${i + 1}Label'] = has ? topCats[i].name : '';
    catPayload['cat${i + 1}Value'] = has ? fmt(topCats[i].amount) : '';
    catPayload['cat${i + 1}Pct'] = has ? catBars[i].toString() : '0';
  }

  final payload = {
    'currencySymbol': symbol,
    'monthLabel': '$monthName ${now.year}',
    'balance': fmt(summary.totalBalance),
    'balanceNote': balanceNote,
    'balancePositive': balancePositive.toString(),
    'income': fmt(summary.totalGains),
    'spend': fmt(summary.totalSpent),
    'invested': fmt(summary.totalInvestments),
    ...catPayload,
    'savingsRate': pct(summary.savingsRate),
    'investmentRate': pct(summary.investmentRate),
    'savingsRateNum':
        (summary.savingsRate * 100).round().clamp(0, 100).toString(),
    'investmentRateNum':
        (summary.investmentRate * 100).round().clamp(0, 100).toString(),
    'avgDailySpend': fmt(avgDaily),
    'projectedBalance': fmt(projected),
    'runwayNote': runwayNote,
    'nextDueName': next?.name ?? 'Nothing due',
    'nextDueAmount': next == null ? '' : fmt(next.amount),
    'nextDueWhen': next == null
        ? 'You are all caught up'
        : _dueLabel(next.due, now, locale),
    'expenseCount': stats.count.toString(),
    'expenseAverage': fmt(stats.average),
    'biggestName': stats.biggest?.name ?? 'None yet',
    'biggestAmount': stats.biggest == null ? '' : fmt(stats.biggest!.amount),
    'updatedAt': now.toIso8601String(),
    'spendGrid': spendGraph.states,
    // Month labels for the calendar header (metadata, not a figure).
    'spendMonths': spendGraph.months.join('|'),
    // Motivating footer line (metadata, not a figure, so it stays visible).
    'footerText': footerText,
    // Metadata: mirror the app's transparent (glass) theme on the widgets.
    'widgetTransparent':
        (settings?.themeVariant == AppThemeVariant.glass).toString(),
  };

  // Keep monetary figures off the home screen when the user has enabled the
  // app lock. Metadata stays so the widget still shows the month.
  final locked = settings?.appLockEnabled ?? false;
  return locked ? maskSensitive(payload) : payload;
});

/// Invisible scope that keeps [widgetPayloadProvider] alive and pushes every
/// change to the native widgets. Place high in the tree (wrapping the router).
class WidgetSyncScope extends ConsumerStatefulWidget {
  const WidgetSyncScope({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<WidgetSyncScope> createState() => _WidgetSyncScopeState();
}

class _WidgetSyncScopeState extends ConsumerState<WidgetSyncScope> {
  @override
  void initState() {
    super.initState();
    // Push whatever we can compute right now, once the first frame settles.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      WidgetService.updateData(ref.read(widgetPayloadProvider));
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<Map<String, String>>(
      widgetPayloadProvider,
      (_, next) => WidgetService.updateData(next),
    );
    return widget.child;
  }
}
