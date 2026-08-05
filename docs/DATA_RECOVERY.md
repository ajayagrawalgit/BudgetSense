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

- Restoring a snapshot **fully replaces settings** (so theme/icon update
  immediately) and **upserts all data**.
- Import is defensive: corrupted, oversized, partially valid, wrong-format, or
  unknown/future-version files are rejected or handled safely rather than
  corrupting the live database.
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
