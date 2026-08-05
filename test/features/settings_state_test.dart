import 'package:budgetsense/core/constants/enums.dart';
import 'package:budgetsense/features/settings/settings_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// The new haptics + reminder-schedule preferences must survive the
/// toMap/fromMap round-trip that both SharedPreferences and the backup snapshot
/// rely on, and must have the defaults the product asks for.
void main() {
  test('defaults: haptics on, daily reminder at 10:00 PM', () {
    const s = SettingsState();
    expect(s.hapticsEnabled, isTrue);
    expect(s.dailyRecordRemindersEnabled, isTrue);
    expect(s.reminderFrequency, ReminderFrequency.daily);
    expect(s.reminderHour, 22);
    expect(s.reminderMinute, 0);
    expect(s.reminderSchedule.describe(), 'Every day at 10:00 PM');
  });

  test('round-trips the new fields through toMap/fromMap', () {
    const s = SettingsState(
      hapticsEnabled: false,
      reminderFrequency: ReminderFrequency.weekly,
      reminderHour: 8,
      reminderMinute: 45,
      reminderWeekday: DateTime.friday,
      reminderDayOfMonth: 12,
    );
    final restored = SettingsState.fromMap(s.toMap());
    expect(restored.hapticsEnabled, isFalse);
    expect(restored.reminderFrequency, ReminderFrequency.weekly);
    expect(restored.reminderHour, 8);
    expect(restored.reminderMinute, 45);
    expect(restored.reminderWeekday, DateTime.friday);
    expect(restored.reminderDayOfMonth, 12);
  });

  test('missing keys fall back to sensible defaults (old backups)', () {
    // Simulate a backup made before these fields existed.
    final legacy = SettingsState.fromMap({'userName': 'Ajay'});
    expect(legacy.userName, 'Ajay');
    expect(legacy.hapticsEnabled, isTrue);
    expect(legacy.reminderFrequency, ReminderFrequency.daily);
    expect(legacy.reminderHour, 22);
  });

  test('copyWith updates only what is asked', () {
    const s = SettingsState();
    final next = s.copyWith(hapticsEnabled: false, reminderHour: 7);
    expect(next.hapticsEnabled, isFalse);
    expect(next.reminderHour, 7);
    // Untouched.
    expect(next.reminderFrequency, ReminderFrequency.daily);
    expect(next.dailyRecordRemindersEnabled, isTrue);
  });
}
