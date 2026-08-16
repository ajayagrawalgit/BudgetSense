/// Single source of truth for what the snapshot subsystem covers.
///
/// The completeness guard test (`test/data/snapshot_completeness_test.dart`)
/// compares this registry against the LIVE Drift schema and the LIVE
/// [SettingsState] keys, and FAILS if a new persistent table or restorable
/// settings key is added without an explicit policy here. That is how we stop
/// silent snapshot gaps: you cannot add persistent state and forget backup.
///
/// See docs/backup/BACKUP_STATE_INVENTORY.md for the human-readable inventory
/// and the justification for every exclusion.
library;

import '../../features/settings/settings_state.dart';

/// How a persistent database table is treated by the snapshot subsystem.
enum TablePolicy {
  /// Serialized into the snapshot and restored (append-only).
  included,

  /// Deliberately NOT serialized. Device-local, derived, or a secret.
  excluded,
}

/// How a settings key is treated by the snapshot subsystem.
enum SettingPolicy {
  /// Serialized and eligible for the non-destructive preference merge.
  included,

  /// Serialized for informational recovery only; never silently re-establishes
  /// device trust on restore (see app-lock/biometric semantics).
  includedInformational,

  /// Deliberately NOT serialized (device-specific or a secret).
  excluded,
}

/// Every Drift table name (matching `AppDatabase.allTables` entityName) mapped
/// to its policy. The guard asserts this set equals the live schema exactly.
const Map<String, TablePolicy> kTablePolicies = <String, TablePolicy>{
  'categories': TablePolicy.included,
  'accounts': TablePolicy.included,
  'payment_methods': TablePolicy.included,
  'transactions': TablePolicy.included,
  'recurring_payments': TablePolicy.included,
  'loans': TablePolicy.included,
  'custom_fields': TablePolicy.included,
  'custom_field_values': TablePolicy.included,
  'thresholds': TablePolicy.included,
  'notification_preferences': TablePolicy.included,
  'export_records': TablePolicy.included,

  // EXCLUDED: device-local restore provenance. Describes THIS device's import
  // history, not user-owned financial data, and must never travel between
  // devices (doing so would corrupt idempotency on the receiving device).
  'import_ledger': TablePolicy.excluded,
};

/// Every [SettingsState] key mapped to its policy. The guard asserts this set
/// equals `SettingsState().toMap().keys` exactly.
const Map<String, SettingPolicy> kSettingPolicies = <String, SettingPolicy>{
  'onboardingComplete': SettingPolicy.included,
  'userName': SettingPolicy.included,
  'userNickname': SettingPolicy.included,
  'userAge': SettingPolicy.included,
  'userPhone': SettingPolicy.included,
  'userEmail': SettingPolicy.included,

  // Preference for a future cloud backend. Not a secret; safe to carry.
  'cloudSyncEnabled': SettingPolicy.included,

  'currencyCode': SettingPolicy.included,
  'currencySymbol': SettingPolicy.included,
  'localeCode': SettingPolicy.included,
  'dateFormat': SettingPolicy.included,
  'financialMonthStartDay': SettingPolicy.included,
  'themeVariant': SettingPolicy.included,
  'accent': SettingPolicy.included,
  'fontChoice': SettingPolicy.included,
  'investmentTreatment': SettingPolicy.included,
  'investmentTreatmentCustomLabel': SettingPolicy.included,
  'reduceMotion': SettingPolicy.included,
  'hapticsEnabled': SettingPolicy.included,

  // App-lock / screen-security PREFERENCES are informational only. Restoring a
  // snapshot records the preference, but never re-establishes biometric trust
  // on a new device - device authentication must be configured again there.
  // Note: no biometric material, PIN, or key is ever stored in settings.
  'appLockEnabled': SettingPolicy.includedInformational,
  'biometricEnabled': SettingPolicy.includedInformational,
  'screenSecurityEnabled': SettingPolicy.includedInformational,

  'notificationsEnabled': SettingPolicy.included,
  'paymentRemindersEnabled': SettingPolicy.included,
  'thresholdAlertsEnabled': SettingPolicy.included,
  'thresholdQuietStartMinute': SettingPolicy.included,
  'thresholdQuietEndMinute': SettingPolicy.included,
  'dailyRecordRemindersEnabled': SettingPolicy.included,
  'reminderFrequency': SettingPolicy.included,
  'reminderHour': SettingPolicy.included,
  'reminderMinute': SettingPolicy.included,
  'reminderWeekday': SettingPolicy.included,
  'reminderDayOfMonth': SettingPolicy.included,
  'numberFormatCompact': SettingPolicy.included,
};

/// The keys eligible for the non-destructive preference merge (everything that
/// is not fully excluded). Informational keys are still merged, but the merge
/// itself never touches device secrets because none are stored in settings.
Set<String> mergeableSettingKeys() => kSettingPolicies.entries
    .where((e) => e.value != SettingPolicy.excluded)
    .map((e) => e.key)
    .toSet();

/// Convenience: the live settings keys, so tests and callers do not duplicate
/// the literal set.
Set<String> liveSettingKeys() => const SettingsState().toMap().keys.toSet();
