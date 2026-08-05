import 'dart:convert';

import 'package:budgetsense/data/database/app_database.dart';
import 'package:budgetsense/data/snapshot/app_snapshot_service.dart';
import 'package:budgetsense/core/theme/app_colors.dart';
import 'package:budgetsense/features/settings/settings_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_database.dart';

/// Non-destructive preference merge (Phase 4).

List<int> _jsonSnapshot(Map<String, Object?> settings) => utf8.encode(
      jsonEncode({
        'app': 'BudgetSense',
        'snapshot': 4,
        'backupId': 'b1',
        'exportedAt': DateTime.utc(2026).toIso8601String(),
        'settings': settings,
        'data': const <String, Object?>{},
      }),
    );

AppSnapshotService _service(
  AppDatabase db,
  Map<String, Object?> local,
  void Function(Map<String, Object?>) onWrite,
) =>
    AppSnapshotService(
      db,
      readSettings: () async => local,
      writeSettings: (s) async => onWrite(s),
    );

void main() {
  late AppDatabase db;
  setUp(() => db = newTestDatabase());
  tearDown(() => db.close());

  test('existing preferences are PRESERVED; uninitialized ones are filled',
      () async {
    // Local user already picked a name and a dark theme; locale is untouched.
    final local = const SettingsState()
        .copyWith(userName: 'Mickey', themeVariant: AppThemeVariant.dark)
        .toMap();
    // Backup carries a different name and theme, plus a locale + currency.
    final backup = const SettingsState()
        .copyWith(
          userName: 'SomeoneElse',
          themeVariant: AppThemeVariant.light,
          localeCode: 'fr',
          currencyCode: 'EUR',
          currencySymbol: '€',
        )
        .toMap();

    Map<String, Object?>? written;
    final svc = _service(db, local, (s) => written = s);
    final res = await svc.importBytes(_jsonSnapshot(backup));

    // Preserved: userName and theme (local was already initialized/differs).
    expect(res.preferencesPreserved, contains('userName'));
    expect(res.preferencesPreserved, contains('themeVariant'));
    // Imported: locale + currency (local was at default / uninitialized).
    expect(res.preferencesImported, contains('localeCode'));
    expect(res.preferencesImported, contains('currencyCode'));

    final merged = SettingsState.fromMap(written!);
    expect(merged.userName, 'Mickey'); // preserved
    expect(merged.themeVariant, AppThemeVariant.dark); // preserved
    expect(merged.localeCode, 'fr'); // filled
    expect(merged.currencyCode, 'EUR'); // filled
  });

  test('explicit applySettingKeys applies ONLY the chosen keys', () async {
    final local = const SettingsState().copyWith(userName: 'Mickey').toMap();
    final backup = const SettingsState()
        .copyWith(userName: 'Other', currencyCode: 'JPY', currencySymbol: '¥')
        .toMap();

    Map<String, Object?>? written;
    final svc = AppSnapshotService(
      db,
      readSettings: () async => local,
      writeSettings: (s) async => written = s,
    );
    // User explicitly chooses to apply ONLY userName (overriding preservation).
    final res = await svc
        .importBytes(_jsonSnapshot(backup), applySettingKeys: {'userName'});

    expect(res.preferencesImported, ['userName']);
    final merged = SettingsState.fromMap(written!);
    expect(merged.userName, 'Other'); // explicitly applied
    expect(merged.currencyCode, 'INR'); // NOT chosen -> stays local default
  });

  test('preview reports available preferences without mutating', () async {
    final local = const SettingsState().copyWith(userName: 'Mickey').toMap();
    final backup = const SettingsState()
        .copyWith(userName: 'Other', localeCode: 'de')
        .toMap();
    var wrote = false;
    final svc = _service(db, local, (_) => wrote = true);
    final preview = await svc.preview(_jsonSnapshot(backup));
    expect(preview.preferenceKeysAvailable, contains('userName'));
    expect(preview.preferenceKeysAvailable, contains('localeCode'));
    expect(preview.preferenceKeysWouldPreserve, contains('userName'));
    expect(wrote, isFalse); // preview never writes
  });
}
