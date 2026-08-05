import 'package:budgetsense/core/constants/reminder_messages.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the reminder copy: enough of it, all non-empty, emoji-carrying, and
/// free of em dashes / spaced-hyphen dashes (a house rule).
void main() {
  test('there are 100+ reminder messages', () {
    expect(reminderMessages.length, greaterThanOrEqualTo(100));
  });

  test('there are several rotating titles', () {
    expect(reminderTitles.length, greaterThanOrEqualTo(10));
  });

  test('every message and title is trimmed and non-empty', () {
    for (final m in [...reminderMessages, ...reminderTitles]) {
      expect(m.trim(), isNotEmpty);
      expect(m, equals(m.trim()));
    }
  });

  test('no em dashes, en dashes, or spaced-hyphen dashes anywhere', () {
    final dashy = RegExp(r'\u2014|\u2013|\S - \S');
    for (final m in [...reminderMessages, ...reminderTitles]) {
      expect(dashy.hasMatch(m), isFalse, reason: 'dash found in: $m');
    }
  });

  test('most messages carry an emoji', () {
    // Emoji live in the astral planes (code point > 0xFFFF) or the misc-symbol
    // ranges. Count messages that contain at least one such rune.
    bool hasEmoji(String s) => s.runes.any(
          (r) =>
              r > 0x1F000 ||
              (r >= 0x2600 && r <= 0x27BF) ||
              (r >= 0x2300 && r <= 0x23FF),
        );
    final withEmoji = reminderMessages.where(hasEmoji).length;
    expect(withEmoji, greaterThanOrEqualTo(reminderMessages.length - 2));
  });

  test('messages are short enough for a lock screen', () {
    for (final m in reminderMessages) {
      expect(m.length, lessThanOrEqualTo(140), reason: 'too long: $m');
    }
  });
}
