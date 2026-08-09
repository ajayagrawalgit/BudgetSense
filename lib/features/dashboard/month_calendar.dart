import 'package:flutter/material.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_resolver.dart';
import '../../core/utils/money.dart';
import '../../domain/entities/transaction_entity.dart';

/// A calm, paper-styled month calendar shown when the dashboard month header is
/// expanded. Days with activity carry a small dot (sage for a net-positive day,
/// clay for a net-outflow day); today wears an accent ring; tapping a day shows
/// its little summary underneath.
class MonthCalendar extends StatefulWidget {
  const MonthCalendar({
    required this.month,
    required this.transactions,
    required this.currencySymbol,
    this.locale,
    this.compact = false,
    super.key,
  });

  final DateTime month;
  final List<TransactionEntity> transactions;
  final String currencySymbol;
  final String? locale;
  final bool compact;

  @override
  State<MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends State<MonthCalendar> {
  int? _selectedDay;

  static const _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _monthNames = [
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

  @override
  void didUpdateWidget(MonthCalendar old) {
    super.didUpdateWidget(old);
    // Clear the selection when the month changes.
    if (old.month.year != widget.month.year ||
        old.month.month != widget.month.month) {
      _selectedDay = null;
    }
  }

  /// Per-day totals for the visible month: (count, netMinorUnits).
  Map<int, ({int count, int net})> _byDay() {
    final result = <int, ({int count, int net})>{};
    for (final t in widget.transactions) {
      final d = t.occurredAt;
      if (d.year != widget.month.year || d.month != widget.month.month) {
        continue;
      }
      final prev = result[d.day] ?? (count: 0, net: 0);
      final signed =
          t.type.isOutflow ? -t.amount.minorUnits : t.amount.minorUnits;
      result[d.day] = (count: prev.count + 1, net: prev.net + signed);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    final year = widget.month.year;
    final month = widget.month.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = DateTime(year, month, 1).weekday; // Mon=1..Sun=7
    final leadingBlanks = firstWeekday - 1;
    final byDay = _byDay();

    final cells = <Widget>[];
    for (var i = 0; i < leadingBlanks; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var day = 1; day <= daysInMonth; day++) {
      final info = byDay[day];
      final isToday = now.year == year && now.month == month && now.day == day;
      final isSelected = _selectedDay == day;
      cells.add(
        _DayCell(
          day: day,
          hasActivity: info != null,
          positive: info != null && info.net >= 0,
          isToday: isToday,
          isSelected: isSelected,
          onTap: () => setState(
            () => _selectedDay = isSelected ? null : day,
          ),
        ),
      );
    }
    // Pad the final row so the grid stays rectangular.
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox.shrink());
    }

    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += 7) {
      rows.add(
        Row(
          children: [
            for (var j = 0; j < 7; j++)
              Expanded(child: AspectRatio(aspectRatio: 1, child: cells[i + j])),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.sm),
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: Corners.md,
        border: Border.all(color: colors.border, width: Strokes.hairline),
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (final w in _weekdays)
                Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: text.labelSmall?.copyWith(color: colors.textFaint),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Insets.xs),
          ...rows,
          if (_selectedDay != null) ...[
            const Divider(height: Insets.lg),
            _DaySummary(
              label: '${_monthNames[month - 1]} $_selectedDay',
              info: byDay[_selectedDay],
              currencySymbol: widget.currencySymbol,
              locale: widget.locale,
              compact: widget.compact,
            ),
          ],
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.hasActivity,
    required this.positive,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final int day;
  final bool hasActivity;
  final bool positive;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final Color? fill = isToday
        ? colors.accent
        : isSelected
            ? colors.accent.withValues(alpha: 0.16)
            : null;
    final Color fg = isToday ? colors.onAccent : colors.textPrimary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text('$day', style: text.bodySmall?.copyWith(color: fg)),
            ),
            const SizedBox(height: 2),
            SizedBox(
              height: 5,
              child: hasActivity
                  ? Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: positive ? colors.positive : colors.negative,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _DaySummary extends StatelessWidget {
  const _DaySummary({
    required this.label,
    required this.info,
    required this.currencySymbol,
    required this.locale,
    this.compact = false,
  });

  final String label;
  final ({int count, int net})? info;
  final String currencySymbol;
  final String? locale;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    if (info == null) {
      return Row(
        children: [
          Text(label, style: text.titleSmall),
          const Spacer(),
          Text(
            'Nothing recorded',
            style: text.bodySmall?.copyWith(color: colors.textFaint),
          ),
        ],
      );
    }
    final net = Money(info!.net.abs());
    final positive = info!.net >= 0;
    return Row(
      children: [
        Text(label, style: text.titleSmall),
        const SizedBox(width: Insets.sm),
        Text(
          '${info!.count} item${info!.count == 1 ? '' : 's'}',
          style: text.bodySmall?.copyWith(color: colors.textFaint),
        ),
        const Spacer(),
        Text(
          '${positive ? '+' : '-'}'
          '${net.format(currencySymbol: currencySymbol, locale: locale, compact: compact)}',
          style: text.titleSmall?.copyWith(
            color: positive ? colors.positive : colors.negative,
          ),
        ),
      ],
    );
  }
}
