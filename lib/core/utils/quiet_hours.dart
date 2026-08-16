/// A nightly window during which the app must stay silent.
///
/// Stored as minutes-since-midnight so it survives timezone changes and needs
/// no date context. The window may wrap past midnight (the common case: 22:00
/// to 07:00), which is why [contains] cannot be a naive range check.
class QuietHours {
  const QuietHours({
    required this.startMinute,
    required this.endMinute,
  })  : assert(startMinute >= 0 && startMinute < 24 * 60),
        assert(endMinute >= 0 && endMinute < 24 * 60);

  /// Minutes since midnight, 0 to 1439.
  final int startMinute;
  final int endMinute;

  /// A zero-length window silences nothing, so treat it as "off" rather than
  /// silently swallowing every alert.
  bool get isEmpty => startMinute == endMinute;

  /// Whether [when]'s wall-clock time falls inside the quiet window.
  ///
  /// The window is inclusive of its start and exclusive of its end, so a
  /// 22:00-07:00 window silences 22:00 but lets a 07:00 alert through.
  bool contains(DateTime when) {
    if (isEmpty) return false;
    final minute = when.hour * 60 + when.minute;
    // A window that wraps midnight (start > end) is the union of two ranges.
    if (startMinute > endMinute) {
      return minute >= startMinute || minute < endMinute;
    }
    return minute >= startMinute && minute < endMinute;
  }

  /// Formats a minutes-since-midnight value as 24-hour "HH:mm".
  static String formatMinute(int minuteOfDay) {
    final h = (minuteOfDay ~/ 60) % 24;
    final m = minuteOfDay % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  @override
  bool operator ==(Object other) =>
      other is QuietHours &&
      other.startMinute == startMinute &&
      other.endMinute == endMinute;

  @override
  int get hashCode => Object.hash(startMinute, endMinute);

  @override
  String toString() =>
      'QuietHours(${formatMinute(startMinute)}-${formatMinute(endMinute)})';
}
