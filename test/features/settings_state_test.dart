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

  test('product defaults: notifications on, compact numbers and motion off',
      () {
    const s = SettingsState();
    // Reminders are the point of the app, so they start on.
    expect(s.notificationsEnabled, isTrue);
    // Full figures by default: money should read exactly, not as "12.3K".
    expect(s.numberFormatCompact, isFalse);
    // Animation stays on unless the user (or the OS) asks otherwise.
    expect(s.reduceMotion, isFalse);
  });

  test('a fresh install with no stored values gets those same defaults', () {
    // fromMap is what actually runs on first launch, so its fallbacks must
    // agree with the constructor defaults. They drifted apart before.
    final fresh = SettingsState.fromMap(const {});
    expect(fresh.notificationsEnabled, isTrue);
    expect(fresh.numberFormatCompact, isFalse);
    expect(fresh.reduceMotion, isFalse);
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
