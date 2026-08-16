import 'package:budgetsense/core/constants/enums.dart';
import 'package:budgetsense/core/utils/financial_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FinancialCalendar (start day 1)', () {
    const cal = FinancialCalendar(monthStartDay: 1);

    test('month range spans the whole calendar month', () {
      final range = cal.monthRangeFor(DateTime(2026, 7, 15));
      expect(range.start, DateTime(2026, 7, 1));
      expect(range.end.month, 7);
      expect(range.end.day, 31);
    });

    test('monthKey is stable', () {
      expect(cal.monthKeyFor(DateTime(2026, 7, 20)), '2026-07');
    });
  });

  group('FinancialCalendar (start day 15)', () {
    const cal = FinancialCalendar(monthStartDay: 15);

    test('date after anchor belongs to current financial month', () {
      final range = cal.monthRangeFor(DateTime(2026, 7, 20));
      expect(range.start, DateTime(2026, 7, 15));
    });

    test('date before anchor rolls into previous financial month', () {
      final range = cal.monthRangeFor(DateTime(2026, 7, 10));
      expect(range.start, DateTime(2026, 6, 15));
    });
  });

  group('nextOccurrence anchoring (schedule drift)', () {
    // Regression guard. Without an anchor, one short month permanently drags
    // a schedule earlier: Jan 31 -> Feb 28 -> Mar 28 -> Apr 28 forever, so a
    // rent or SIP silently moves three days early for the rest of its life.
    test('a payment on the 31st returns to the 31st after February', () {
      var d = DateTime(2026, 1, 31);
      final days = <int>[];
      for (var i = 0; i < 7; i++) {
        days.add(d.day);
        d = nextOccurrence(d, Frequency.monthly, anchorDay: 31);
      }
      // Feb and the 30-day months clamp, every 31-day month recovers.
      expect(days, [31, 28, 31, 30, 31, 30, 31]);
    });

    test('a payment on the 30th survives February', () {
      var d = DateTime(2026, 1, 30);
      final days = <int>[];
      for (var i = 0; i < 4; i++) {
        days.add(d.day);
        d = nextOccurrence(d, Frequency.monthly, anchorDay: 30);
      }
      expect(days, [30, 28, 30, 30]);
    });

    test('quarterly and yearly anchor too', () {
      expect(
        nextOccurrence(DateTime(2026, 11, 30), Frequency.quarterly,
            anchorDay: 31),
        DateTime(2027, 2, 28),
      );
      // Leap day yearly: clamps to the 28th, recovers on the next leap year.
      expect(
        nextOccurrence(DateTime(2028, 2, 29), Frequency.yearly, anchorDay: 29),
        DateTime(2029, 2, 28),
      );
    });

    test('without an anchor the old clamped day is kept (no surprise jumps)',
        () {
      // Callers that pass no anchor keep the previous behaviour exactly.
      expect(
        nextOccurrence(DateTime(2026, 2, 28), Frequency.monthly),
        DateTime(2026, 3, 28),
      );
    });
  });

  group('nextOccurrence', () {
    test('advances by frequency', () {
      final base = DateTime(2026, 1, 31);
      expect(nextOccurrence(base, Frequency.daily), DateTime(2026, 2, 1));
      expect(nextOccurrence(base, Frequency.weekly), DateTime(2026, 2, 7));
      expect(
        nextOccurrence(DateTime(2026, 1, 15), Frequency.monthly),
        DateTime(2026, 2, 15),
      );
      expect(
        nextOccurrence(DateTime(2026, 1, 15), Frequency.yearly),
        DateTime(2027, 1, 15),
      );
    });

    test('custom interval uses provided days', () {
      expect(
        nextOccurrence(
          DateTime(2026, 1, 1),
          Frequency.custom,
          customIntervalDays: 10,
        ),
        DateTime(2026, 1, 11),
      );
    });
  });
}
