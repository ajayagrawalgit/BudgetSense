import 'package:intl/intl.dart';

/// Human-friendly, locale-aware date formatting for the whole app.
///
/// One home for every user-facing date so screens speak the same warm language
/// ("Today", "Yesterday", "Tue, 28 Jul") instead of the database dialect
/// (2026-07-28). Locale flows in from settings (`localeCode`), mirroring how
/// [Money] already localizes numbers.
///
/// All formatting is guarded: if the requested locale's date symbols are not
/// loaded, it falls back to the always-available default locale rather than
/// throwing.
abstract final class FriendlyDate {
  /// A conversational label: "Today", "Yesterday" or "Tomorrow" for the days
  /// around [now], otherwise the [short] form. Great for lists and any date the
  /// user reads in the flow of using the app.
  ///
  /// Each calendar day maps to a unique string (the [short] fallback always
  /// carries the year when it differs from the current one), so this is safe to
  /// use as a per-day grouping key as well as a header label.
  static String relative(DateTime date, {String? locale, DateTime? now}) {
    final reference = _dateOnly(now ?? DateTime.now());
    final day = _dateOnly(date);
    final diff = day.difference(reference).inDays;
    if (diff == 0) return 'Today';
    if (diff == -1) return 'Yesterday';
    if (diff == 1) return 'Tomorrow';
    return short(date, locale: locale, now: now);
  }

  /// An absolute short date with no relative words: "Tue, 28 Jul" within the
  /// current year, or "28 Jul 2025" for any other year. Use this where the date
  /// is read later than it is composed (e.g. a scheduled notification body) so
  /// it never says a stale "Today".
  static String short(DateTime date, {String? locale, DateTime? now}) {
    final currentYear = (now ?? DateTime.now()).year;
    final pattern = date.year == currentYear ? 'EEE, d MMM' : 'd MMM yyyy';
    return _format(date, pattern, locale);
  }

  static String _format(DateTime date, String pattern, String? locale) {
    try {
      return DateFormat(pattern, locale).format(date);
    } catch (_) {
      // Requested locale's date symbols aren't initialized; the default locale
      // is always available.
      return DateFormat(pattern).format(date);
    }
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
