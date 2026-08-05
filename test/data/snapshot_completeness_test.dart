import 'package:budgetsense/data/snapshot/snapshot_registry.dart';
import 'package:budgetsense/data/snapshot/snapshot_tables.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_database.dart';

/// The completeness GUARD (Phase 2).
///
/// These tests FAIL the build if a new persistent table or a new restorable
/// settings key is added without an explicit snapshot policy. That is the
/// mechanism that stops silent backup gaps: you literally cannot add persistent
/// state and forget to decide how backup treats it.
void main() {
  test('every live Drift table has an explicit snapshot policy', () {
    final db = newTestDatabase();
    addTearDown(db.close);
    final liveTables = db.allTables.map((t) => t.actualTableName).toSet();
    final registered = kTablePolicies.keys.toSet();

    final missing = liveTables.difference(registered);
    final stale = registered.difference(liveTables);
    expect(
      missing,
      isEmpty,
      reason:
          'These DB tables have no snapshot policy in snapshot_registry.dart. '
          'Add each to kTablePolicies (included or excluded) and update the '
          'inventory doc: $missing',
    );
    expect(stale, isEmpty,
        reason: 'Stale policies for non-existent tables: $stale');
  });

  test('every INCLUDED table is present in the FK-safe snapshot order', () {
    final included = kTablePolicies.entries
        .where((e) => e.value == TablePolicy.included)
        .map((e) => e.key)
        .toSet();
    // kSnapshotTableOrder uses drift getter names (camelCase); map them to the
    // actual snake_case table names for comparison.
    const camelToSnake = <String, String>{
      'categories': 'categories',
      'accounts': 'accounts',
      'paymentMethods': 'payment_methods',
      'transactions': 'transactions',
      'recurringPayments': 'recurring_payments',
      'loans': 'loans',
      'customFields': 'custom_fields',
      'customFieldValues': 'custom_field_values',
      'thresholds': 'thresholds',
      'notificationPreferences': 'notification_preferences',
      'exportRecords': 'export_records',
    };
    final orderedSnake =
        kSnapshotTableOrder.map((c) => camelToSnake[c] ?? c).toSet();
    expect(
      orderedSnake,
      equals(included),
      reason:
          'Every included table must appear in kSnapshotTableOrder so it is '
          'actually serialized and restored.',
    );
  });

  test('device-local / secret tables are EXCLUDED and never serialized', () {
    // import_ledger is device-local provenance and must never travel.
    expect(kTablePolicies['import_ledger'], TablePolicy.excluded);
    expect(
      kSnapshotTableOrder.contains('importLedger'),
      isFalse,
      reason: 'import_ledger must not be in the serialized snapshot order.',
    );
  });

  test('every live settings key has an explicit snapshot policy', () {
    final live = liveSettingKeys();
    final registered = kSettingPolicies.keys.toSet();
    final missing = live.difference(registered);
    final stale = registered.difference(live);
    expect(
      missing,
      isEmpty,
      reason: 'These SettingsState keys have no snapshot policy. Add each to '
          'kSettingPolicies and update the inventory doc: $missing',
    );
    expect(stale, isEmpty, reason: 'Stale settings policies: $stale');
  });
}
