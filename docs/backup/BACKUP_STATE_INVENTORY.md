# BudgetSense Backup State Inventory (Phase 1)

This is the audit output: every source of persistent, user-affecting state in
BudgetSense, and exactly how the snapshot subsystem treats it. The machine
readable version of this table lives in
`lib/data/snapshot/snapshot_registry.dart` and is enforced by
`test/data/snapshot_completeness_test.dart`, which fails the build if a new
table or settings key is added without a policy here.

Classification legend:
- INCLUDED: serialized into the snapshot and restored (append-only for tables).
- INCLUDED (informational): serialized, but restoring it never re-establishes
  device trust (see app-lock note).
- MERGED: singleton settings merged non-destructively (existing local value
  wins unless uninitialized or explicitly chosen).
- EXCLUDED (device-local): describes this device, must not travel.
- EXCLUDED (secret): a credential or key. Never serialized, ever.
- EXCLUDED (derived/temporary): can be recomputed, no need to carry.

## Drift database tables (SQLite)

| Table (SQL name) | Holds | Policy |
|---|---|---|
| `categories` | User categories | INCLUDED (append-only) |
| `accounts` | Wallets/accounts | INCLUDED (append-only) |
| `payment_methods` | Payment methods | INCLUDED (append-only) |
| `transactions` | Expenses + income | INCLUDED (append-only) |
| `recurring_payments` | Subscriptions / recurring | INCLUDED (append-only) |
| `loans` | Loans / EMIs | INCLUDED (append-only) |
| `custom_fields` | User-defined field definitions | INCLUDED (append-only) |
| `custom_field_values` | Values of custom fields | INCLUDED (append-only) |
| `thresholds` | Budget threshold rules | INCLUDED (append-only) |
| `notification_preferences` | Per-kind notification prefs | INCLUDED (append-only) |
| `export_records` | History of exports made | INCLUDED (append-only) |
| `import_ledger` | Restore provenance (this device) | EXCLUDED (device-local) |

Why `import_ledger` is excluded: it records which backup/source record produced
which LOCAL record on THIS device, plus a content hash. Carrying it to another
device would corrupt that device's idempotency and conflict detection. It is
provenance metadata about imports, not user-owned financial data.

## Settings / preferences (SharedPreferences, key `budgetsense.settings.v1`)

Stored as one JSON blob via `SettingsState.toMap()`. Every key below is
serialized and eligible for the non-destructive preference merge.

| Key | Meaning | Policy |
|---|---|---|
| `onboardingComplete` | Onboarding done | MERGED |
| `userName`, `userNickname`, `userAge`, `userPhone`, `userEmail` | Profile | MERGED |
| `cloudSyncEnabled` | Cloud backup preference | MERGED |
| `currencyCode`, `currencySymbol` | Currency | MERGED |
| `localeCode`, `dateFormat`, `numberFormatCompact` | Formatting | MERGED |
| `financialMonthStartDay` | Financial calendar | MERGED |
| `themeVariant`, `accent`, `fontChoice` | Theme | MERGED |
| `investmentTreatment`, `investmentTreatmentCustomLabel` | Investment handling | MERGED |
| `reduceMotion`, `hapticsEnabled` | Accessibility | MERGED |
| `appLockEnabled`, `biometricEnabled`, `screenSecurityEnabled` | Security prefs | INCLUDED (informational) |
| `notificationsEnabled`, `paymentRemindersEnabled`, `thresholdAlertsEnabled`, `dailyRecordRemindersEnabled` | Notification toggles | MERGED |
| `reminderFrequency`, `reminderHour`, `reminderMinute`, `reminderWeekday`, `reminderDayOfMonth` | Reminder schedule | MERGED |

App-lock note: `appLockEnabled` / `biometricEnabled` are only PREFERENCES. No
PIN, biometric material, or key is stored in settings. Restoring a snapshot
records the preference for the user's review, but device authentication must be
configured again on the new device. Restore never silently re-establishes
biometric trust.

## State that is deliberately NOT in the snapshot

| Item | Where it lives | Why excluded |
|---|---|---|
| `import_ledger` rows | SQLite | Device-local provenance |
| Google OAuth access/refresh tokens | (cloud stage) secure storage | Secret. Never serialized |
| Cloud encryption key / wrapped key | (cloud stage) Keystore/Keychain | Secret |
| Recovery passphrase | Never stored | Secret, only held transiently for KDF |
| Drive folder id / file id / sync metadata | (cloud stage) separate prefs namespace | Device/account-specific, not user data |
| Cloud pending/retry/generation state | (cloud stage) | Device-local sync bookkeeping |
| Notification schedule handles / OS ids | OS / flutter_local_notifications | Device-specific, recreated on demand |
| Temporary export files | app temp dir | Temporary |
| Derived summaries, insights, threshold evals | computed in memory | Derived, recalculated |
| App icon runtime state | OS | Device-specific |

The "(cloud stage)" rows are storage locations that will be introduced when the
Google Drive feature lands. They are listed now so the exclusion policy is fixed
up front and cannot drift.

## Proof, not assumption

The completeness guard (`test/data/snapshot_completeness_test.dart`) compares
this inventory against the live schema and the live settings keys at build time.
If they diverge, CI fails with a message telling you exactly which table or key
needs a policy. That is how we guarantee this document stays true.
