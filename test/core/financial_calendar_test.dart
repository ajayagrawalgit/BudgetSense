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
