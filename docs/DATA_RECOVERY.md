# Data Recovery, Backup, Import & Export

BudgetSense keeps everything on-device. Backups are the way you move data
between devices or protect against loss. This document describes how they work
and how to recover.

## Backup (full snapshot)

The app can export a complete snapshot in JSON, CSV, or XML. A snapshot
contains **every table** (transactions, categories, accounts, payment methods,
recurring payments, loans, custom fields, custom-field values, thresholds,
notification preferences, export records) **plus all settings and profile**
(theme, accent, font, app icon, month-start day, etc.).

- Snapshots are stamped with the app version (canonical `AppInfo.version`) so
  they are forward-identifiable.
- The exported file is **unencrypted**. Treat it as a sensitive financial
  document and store it somewhere you trust.

## Restore (import a snapshot)

- Restore is **non-destructive and append-only**. It never updates, replaces,
  or deletes an existing local record. New records are inserted, an id
  collision with different content is remapped to a new local record instead of
  overwriting, and a changed source record is appended as a new version. See
  `backup/RESTORE_CONFLICT_POLICY.md` for the exact rules.
- Settings and profile are **merged, not replaced**: an existing local value is
  kept by default, and a backed-up value is only applied automatically when the
  local value is uninitialized. You can explicitly choose to apply other values
  from the restore preview.
- Import is defensive: corrupted, oversized, partially valid, wrong-format, or
  unknown/future-version files are rejected before any write, causing zero
  mutations rather than corrupting the live database.
- After a restore, all data providers are invalidated in one shot so every
  screen reflects the restored data without an app restart.

## Importing from other apps

BudgetSense can import data exported from other budgeting apps (currently
Paisa). The importer validates and maps rows defensively; malformed rows are
skipped rather than aborting the whole import or corrupting existing data.

## Trash / soft-delete recovery

Deleting a transaction soft-deletes it (moves it to Trash) rather than
destroying it. You can restore items from Trash, or empty the Trash to
permanently remove them. Emptying the Trash only deletes archived rows; live
data is untouched.

## Full data deletion

Settings offers a "delete all data" action that clears every table in a single
transaction, respecting foreign-key order. Uninstalling the app also removes its
private database. Backup files you exported are under your control and are not
removed by uninstall.

## Recovery scenarios

| Situation | Recovery |
|---|---|
| New device | Export a snapshot on the old device, transfer the file, import it on the new device |
| Accidental single delete | Restore from Trash |
| Accidental bulk change | Import your most recent snapshot backup |
| App reinstalled without a backup | Data is gone (local-only, by design) - keep regular snapshots |

## Recommendation

Export a snapshot periodically (and before any major change or app update) and
keep it somewhere safe. BudgetSense is offline-first: local backups are always
available. You can also enable the optional, client-side-encrypted Google Drive
backup (Settings → Backup and Sync to Cloud) for an automatic off-device copy;
remember its recovery passphrase, which is required to restore. Either way, your
backup discipline is your recovery guarantee.
