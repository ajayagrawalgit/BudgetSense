# Snapshot Schema (SNAPSHOT_SCHEMA.md)

The canonical BudgetSense snapshot is one format-agnostic model serialized to
JSON (canonical/lossless), sectioned CSV, or XML. All three carry the identical
model. JSON is the recommended form and the one cloud backup will use.

## Envelope

| Field | Type | Notes |
|---|---|---|
| `app` | string | Always `"BudgetSense"`. Positive file identification. |
| `snapshot` | int | Envelope format version. Current: **4**. |
| `backupId` | string | Stable, unique, non-identifying id for this file. Drives the import ledger (idempotency + provenance). Legacy files without it get a deterministic derived id. |
| `exportedAt` | string | ISO-8601 UTC creation time. |
| `appVersion` | string | BudgetSense version that produced the file. |
| `schemaVersion` | int | Drift DB schema version at export time. |
| `settings` | object | `SettingsState.toMap()` blob (see inventory). |
| `data` | object | Map of table name to array of row objects. |

Version history:
- v3: first full snapshot (settings + profile + theme + icon + all tables).
- v4: adds `backupId`. Backward compatible. Older files decode fine and receive
  a derived, deterministic `backupId` so re-imports stay idempotent.

## Row encoding

Each row is the Drift `toJson()` map. Key rules:
- Money is stored as INTEGER minor units (for example `amountMinor`,
  `emiMinor`). Never floating point. This is lossless by construction.
- Dates are encoded via Drift's default serializer (integer), and decoded with
  the same serializer, so export and import are perfectly symmetric. ISO strings
  are also accepted on import as a fallback for hand-edited files.
- Nulls, empty strings, unicode, embedded quotes/commas/newlines all round-trip
  losslessly (CSV/XML wrap every cell in `jsonEncode`).
- Stable text UUID `id` on every record is preserved.
- Enum values are stored as their integer index (matching the DB).

## Forward and backward compatibility

- Restoring an OLDER file (missing a newly added column): the tolerant companion
  builder leaves the column absent and the DB default fills it. No throw.
- Restoring a NEWER file's extra column: the unknown key is ignored. No throw.
- An unsupported FUTURE envelope version (`snapshot` greater than current) is
  rejected before any mutation.
- Unknown top-level table sections are skipped with a warning, never imported.

## Included vs excluded

See `BACKUP_STATE_INVENTORY.md` for the authoritative, test-enforced list. In
short: all 11 user-data tables and every registered settings key are included;
`import_ledger` and all secrets / device-specific / derived state are excluded.

## Completeness guarantee

`lib/data/snapshot/snapshot_registry.dart` is the single source of truth for
coverage, and `test/data/snapshot_completeness_test.dart` fails the build if the
live schema or settings keys drift from it. You cannot add persistent state and
silently forget to give it a backup policy.
