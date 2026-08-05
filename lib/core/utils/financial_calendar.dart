/// Date helpers centred on the concept of a *financial month*, which may not
/// start on the 1st (Section 18: configurable financial month start date).
class FinancialCalendar {
  const FinancialCalendar({this.monthStartDay = 1})
      : assert(
          monthStartDay >= 1 && monthStartDay <= 28,
          'monthStartDay must be 1-28 to exist in every month',
        );

  /// The day-of-month the financial month begins on (1 to 28).
  final int monthStartDay;

  /// Returns the [DateRange] of the financial month containing [date].
  DateRange monthRangeFor(DateTime date) {
    final anchorThisMonth = DateTime(date.year, date.month, monthStartDay);
    final DateTime start;
    if (!date.isBefore(anchorThisMonth)) {
      start = anchorThisMonth;
    } else {
      final prev = DateTime(date.year, date.month - 1, monthStartDay);
      start = prev;
    }
    final end = DateTime(start.year, start.month + 1, start.day)
        .subtract(const Duration(milliseconds: 1));
    return DateRange(start, end);
  }

  /// A stable key like `2026-07` for the financial month containing [date].
  /// Uses the *start* month/year of the financial period.
  String monthKeyFor(DateTime date) {
    final range = monthRangeFor(date);
    return '${range.start.year.toString().padLeft(4, '0')}-'
        '${range.start.month.toString().padLeft(2, '0')}';
  }
}

/// An inclusive date range [start, end].
class DateRange {
  const DateRange(this.start, this.end);

  final DateTime start;
  final DateTime end;

  bool contains(DateTime d) => !d.isBefore(start) && !d.isAfter(end);

  Duration get duration => end.difference(start);

  int get inclusiveDays => duration.inDays + 1;

  @override
  String toString() => 'DateRange($start..$end)';
}

/// Advance [from] by one step of [Frequency]. Used to compute next due dates.
DateTime nextOccurrence(
  DateTime from,
  Object frequency, {
  int customIntervalDays = 30,
}) {
  final name = frequency.toString().split('.').last;
  return switch (name) {
    'daily' => from.add(const Duration(days: 1)),
    'weekly' => from.add(const Duration(days: 7)),
    'biweekly' => from.add(const Duration(days: 14)),
    'monthly' => _addMonths(from, 1),
    'quarterly' => _addMonths(from, 3),
    'halfYearly' => _addMonths(from, 6),
    'yearly' => _addMonths(from, 12),
    _ => from.add(Duration(days: customIntervalDays)),
  };
}

/// Safely adds [months] to [from], clamping the day to the last valid day
/// of the target month (e.g. Jan 31 + 1 month = Feb 28, not Mar 3).
DateTime _addMonths(DateTime from, int months) {
  final targetMonth = from.month + months;
  final year = from.year + (targetMonth - 1) ~/ 12;
  final month = (targetMonth - 1) % 12 + 1;
  final maxDay = DateTime(year, month + 1, 0).day;
  final day = from.day > maxDay ? maxDay : from.day;
  return DateTime(year, month, day, from.hour, from.minute, from.second);
}
