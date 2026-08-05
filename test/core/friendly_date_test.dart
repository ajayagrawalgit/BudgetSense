import 'package:budgetsense/core/utils/friendly_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A fixed reference so "today/yesterday/tomorrow" are deterministic.
  final now = DateTime(2026, 7, 28, 15, 30);

  group('FriendlyDate.relative', () {
    test('names the days around now', () {
      expect(FriendlyDate.relative(DateTime(2026, 7, 28), now: now), 'Today');
      expect(
        FriendlyDate.relative(DateTime(2026, 7, 27), now: now),
        'Yesterday',
      );
      expect(
        FriendlyDate.relative(DateTime(2026, 7, 29), now: now),
        'Tomorrow',
      );
    });

    test('ignores the time of day when comparing calendar days', () {
      // 00:05 today is still "Today", not "Yesterday", vs an afternoon now.
      expect(
        FriendlyDate.relative(DateTime(2026, 7, 28, 0, 5), now: now),
        'Today',
      );
    });

    test('falls back to the short form for other days', () {
      final label = FriendlyDate.relative(DateTime(2026, 8, 5), now: now);
      expect(label, FriendlyDate.short(DateTime(2026, 8, 5), now: now));
      expect(label, isNot(anyOf('Today', 'Yesterday', 'Tomorrow')));
    });
  });

  group('FriendlyDate.short', () {
    test('omits the year within the current year', () {
      final label = FriendlyDate.short(DateTime(2026, 7, 28), now: now);
      expect(label, contains('28'));
      expect(label, contains('Jul'));
      expect(label, isNot(contains('2026')));
    });

    test('includes the year for other years', () {
      final label = FriendlyDate.short(DateTime(2024, 7, 28), now: now);
      expect(label, contains('28'));
      expect(label, contains('Jul'));
      expect(label, contains('2024'));
    });
  });

  group('grouping-key safety', () {
    test('distinct calendar days never collide', () {
      // Same month/day, different years must differ (year is carried).
      expect(
        FriendlyDate.relative(DateTime(2024, 8, 5), now: now),
        isNot(FriendlyDate.relative(DateTime(2023, 8, 5), now: now)),
      );
      // Different days in the current year differ.
      expect(
        FriendlyDate.relative(DateTime(2026, 8, 5), now: now),
        isNot(FriendlyDate.relative(DateTime(2026, 8, 6), now: now)),
      );
    });
  });

  group('locale safety', () {
    test('an uninitialized locale falls back instead of throwing', () {
      // fr_FR date symbols are not loaded in a plain unit test, so the helper
      // must gracefully fall back to the default locale rather than blow up.
      final date = DateTime(2026, 7, 28);
      late String label;
      expect(
        () => label = FriendlyDate.short(date, locale: 'fr_FR', now: now),
        returnsNormally,
      );
      expect(label, FriendlyDate.short(date, now: now));
    });
  });
}
