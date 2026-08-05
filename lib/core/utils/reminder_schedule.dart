import '../constants/enums.dart';

/// A plain, immutable description of when the "record your expenses" reminder
/// should fire. This is deliberately free of any plugin or Flutter code so the
/// occurrence maths can be unit tested on their own.
class ReminderSchedule {
  const ReminderSchedule({
    this.frequency = ReminderFrequency.daily,
    this.hour = 22,
    this.minute = 0,
    this.weekday = DateTime.monday,
    this.dayOfMonth = 1,
  });

  /// Daily, weekly, or monthly.
  final ReminderFrequency frequency;

  /// 0 to 23, wall-clock hour the reminder fires at.
  final int hour;

  /// 0 to 59.
  final int minute;

  /// 1 (Monday) to 7 (Sunday). Only used when [frequency] is weekly.
  final int weekday;

  /// 1 to 28, the day of the month. Capped at 28 so it exists in every month.
  /// Only used when [frequency] is monthly.
  final int dayOfMonth;

  ReminderSchedule copyWith({
    ReminderFrequency? frequency,
    int? hour,
    int? minute,
    int? weekday,
    int? dayOfMonth,
  }) {
    return ReminderSchedule(
      frequency: frequency ?? this.frequency,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      weekday: weekday ?? this.weekday,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
    );
  }

  /// A short, human sentence describing the schedule, e.g.
  /// "Every day at 10:00 PM" or "Every month on the 1st at 9:00 AM".
  String describe() {
    final t = _formatTime(hour, minute);
    switch (frequency) {
      case ReminderFrequency.daily:
        return 'Every day at $t';
      case ReminderFrequency.weekly:
        return 'Every ${_weekdayName(weekday)} at $t';
      case ReminderFrequency.monthly:
        return 'Every month on the ${_ordinal(dayOfMonth)} at $t';
    }
  }

  /// The next [count] fire-times strictly after [from], in ascending order.
  /// Used by the notification service to lay down a rolling window of alerts.
  List<DateTime> occurrences({required DateTime from, required int count}) {
    final result = <DateTime>[];
    switch (frequency) {
      case ReminderFrequency.daily:
        var day = DateTime(from.year, from.month, from.day, hour, minute);
        if (!day.isAfter(from)) day = day.add(const Duration(days: 1));
        for (var i = 0; i < count; i++) {
          result.add(day);
          day = day.add(const Duration(days: 1));
        }
      case ReminderFrequency.weekly:
        // Walk forward to the next matching weekday at the right time.
        var day = DateTime(from.year, from.month, from.day, hour, minute);
        var guard = 0;
        while ((day.weekday != weekday || !day.isAfter(from)) && guard < 8) {
          day = day.add(const Duration(days: 1));
          day = DateTime(day.year, day.month, day.day, hour, minute);
          guard++;
        }
        for (var i = 0; i < count; i++) {
          result.add(day);
          day = day.add(const Duration(days: 7));
        }
      case ReminderFrequency.monthly:
        final d = dayOfMonth.clamp(1, 28);
        var y = from.year;
        var m = from.month;
        var day = DateTime(y, m, d, hour, minute);
        if (!day.isAfter(from)) {
          m += 1;
          if (m > 12) {
            m = 1;
            y += 1;
          }
          day = DateTime(y, m, d, hour, minute);
        }
        for (var i = 0; i < count; i++) {
          result.add(day);
          m += 1;
          if (m > 12) {
            m = 1;
            y += 1;
          }
          day = DateTime(y, m, d, hour, minute);
        }
    }
    return result;
  }

  static String _formatTime(int h, int m) {
    final period = h < 12 ? 'AM' : 'PM';
    var hour12 = h % 12;
    if (hour12 == 0) hour12 = 12;
    final mm = m.toString().padLeft(2, '0');
    return '$hour12:$mm $period';
  }

  static String _weekdayName(int w) => switch (w) {
        DateTime.monday => 'Monday',
        DateTime.tuesday => 'Tuesday',
        DateTime.wednesday => 'Wednesday',
        DateTime.thursday => 'Thursday',
        DateTime.friday => 'Friday',
        DateTime.saturday => 'Saturday',
        DateTime.sunday => 'Sunday',
        _ => 'Monday',
      };

  static String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    return switch (n % 10) {
      1 => '${n}st',
      2 => '${n}nd',
      3 => '${n}rd',
      _ => '${n}th',
    };
  }
}
