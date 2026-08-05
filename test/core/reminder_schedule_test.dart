import 'package:budgetsense/core/constants/enums.dart';
import 'package:budgetsense/core/utils/reminder_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

/// The pure occurrence maths behind the configurable "record your expenses"
/// reminder. No plugin, no Flutter, just dates.
void main() {
  group('daily', () {
    test('first occurrence is today when the time is still ahead', () {
      const s = ReminderSchedule(hour: 22, minute: 0);
      final from = DateTime(2026, 6, 1, 9, 0); // 9am, before 10pm
      final occ = s.occurrences(from: from, count: 3);
      expect(occ.first, DateTime(2026, 6, 1, 22, 0));
      expect(occ[1], DateTime(2026, 6, 2, 22, 0));
      expect(occ[2], DateTime(2026, 6, 3, 22, 0));
    });

    test('first occurrence rolls to tomorrow when the time has passed', () {
      const s = ReminderSchedule(hour: 22, minute: 0);
      final from = DateTime(2026, 6, 1, 23, 0); // 11pm, after 10pm
      final occ = s.occurrences(from: from, count: 1);
      expect(occ.single, DateTime(2026, 6, 2, 22, 0));
    });

    test('returns exactly count occurrences, strictly increasing', () {
      const s = ReminderSchedule(hour: 8, minute: 30);
      final occ = s.occurrences(from: DateTime(2026, 1, 1, 0, 0), count: 30);
      expect(occ.length, 30);
      for (var i = 1; i < occ.length; i++) {
        expect(occ[i].isAfter(occ[i - 1]), isTrue);
      }
    });
  });

  group('weekly', () {
    test('all occurrences fall on the chosen weekday, 7 days apart', () {
      const s = ReminderSchedule(
        frequency: ReminderFrequency.weekly,
        weekday: DateTime.wednesday,
        hour: 20,
      );
      final occ = s.occurrences(from: DateTime(2026, 6, 1, 12), count: 4);
      for (final d in occ) {
        expect(d.weekday, DateTime.wednesday);
        expect(d.hour, 20);
      }
      expect(occ[1].difference(occ[0]).inDays, 7);
      expect(occ.first.isAfter(DateTime(2026, 6, 1, 12)), isTrue);
    });
  });

  group('monthly', () {
    test('fires on the chosen day each month, advancing the month', () {
      const s = ReminderSchedule(
        frequency: ReminderFrequency.monthly,
        dayOfMonth: 15,
        hour: 9,
      );
      final occ = s.occurrences(from: DateTime(2026, 1, 20), count: 3);
      // Jan 15 already passed on the 20th, so start in February.
      expect(occ[0], DateTime(2026, 2, 15, 9));
      expect(occ[1], DateTime(2026, 3, 15, 9));
      expect(occ[2], DateTime(2026, 4, 15, 9));
    });

    test('day is clamped to 28 so it exists in February', () {
      const s = ReminderSchedule(
        frequency: ReminderFrequency.monthly,
        dayOfMonth: 31,
      );
      final occ = s.occurrences(from: DateTime(2026, 2, 1), count: 1);
      expect(occ.single.day, 28);
    });

    test('rolls across a year boundary', () {
      const s = ReminderSchedule(
        frequency: ReminderFrequency.monthly,
        dayOfMonth: 1,
      );
      final occ = s.occurrences(from: DateTime(2026, 12, 5), count: 2);
      expect(occ[0], DateTime(2027, 1, 1, 22));
      expect(occ[1], DateTime(2027, 2, 1, 22));
    });
  });

  group('describe', () {
    test('reads like a human sentence', () {
      expect(
        const ReminderSchedule(hour: 22, minute: 0).describe(),
        'Every day at 10:00 PM',
      );
      expect(
        const ReminderSchedule(
          frequency: ReminderFrequency.weekly,
          weekday: DateTime.friday,
          hour: 9,
          minute: 5,
        ).describe(),
        'Every Friday at 9:05 AM',
      );
      expect(
        const ReminderSchedule(
          frequency: ReminderFrequency.monthly,
          dayOfMonth: 3,
          hour: 0,
        ).describe(),
        'Every month on the 3rd at 12:00 AM',
      );
    });
  });
}
