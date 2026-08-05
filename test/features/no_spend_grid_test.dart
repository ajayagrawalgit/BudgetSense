import 'package:budgetsense/features/widgets/widget_sync.dart';
import 'package:flutter_test/flutter_test.dart';

/// The spend-activity graph builder is pure, so we can pin its exact output.
void main() {
  DateTime d(int y, int m, int day) => DateTime(y, m, day);

  group('buildSpendGrid', () {
    test('string is exactly one char per day for the whole window', () {
      final grid = buildSpendGrid(
        spendCounts: const {},
        today: d(2026, 7, 30),
      );
      expect(grid.states.length, kNoSpendWeeks * 7);
      // No records at all -> every past/today square is level "0", future ".".
      expect(grid.states.split('').toSet().difference({'0', '.'}), isEmpty);
    });

    test('shades days light to dark by number of expense records', () {
      final today = d(2026, 7, 30);
      final grid = buildSpendGrid(
        spendCounts: {
          d(2026, 7, 26): 1, // level 1
          d(2026, 7, 27): 2, // level 2
          d(2026, 7, 28): 4, // level 3 (3-4 records)
          d(2026, 7, 29): 9, // level 4 (5+ records)
        },
        today: today,
      );

      int levelOf(DateTime day) {
        // Recompute the day's index the same way the builder lays out weeks.
        final t = DateTime(today.year, today.month, today.day);
        final daysUntilSat = (DateTime.saturday - t.weekday + 7) % 7;
        final end = t.add(Duration(days: daysUntilSat));
        final start = end.subtract(const Duration(days: kNoSpendWeeks * 7 - 1));
        final offset = day.difference(start).inDays;
        final week = offset ~/ 7;
        final row = offset % 7;
        return int.parse(grid.states[week * 7 + row]);
      }

      expect(levelOf(d(2026, 7, 26)), 1);
      expect(levelOf(d(2026, 7, 27)), 2);
      expect(levelOf(d(2026, 7, 28)), 3);
      expect(levelOf(d(2026, 7, 29)), 4);
      expect(levelOf(d(2026, 7, 25)), 0); // no records that day
    });

    test('future days in the current week are marked "."', () {
      final today = d(2026, 7, 30); // Thursday; Fri/Sat are future
      final grid = buildSpendGrid(spendCounts: const {}, today: today);
      final lastWeek = grid.states.substring((kNoSpendWeeks - 1) * 7);
      expect(lastWeek.contains('.'), isTrue);
      // The last non-future square is today at level 0 (no records).
      final lastReal = lastWeek.replaceAll('.', '');
      expect(lastReal.isNotEmpty, isTrue);
      expect(lastReal[lastReal.length - 1], '0');
    });

    test('emits one month label per week, marking where months begin', () {
      final grid = buildSpendGrid(
        spendCounts: const {},
        today: d(2026, 7, 30),
      );
      expect(grid.months.length, kNoSpendWeeks);
      final labelled = grid.months.where((m) => m.isNotEmpty).toList();
      expect(labelled.length, greaterThanOrEqualTo(11));
      expect(labelled.every((m) => m.length == 3), isTrue);
    });
  });
}
