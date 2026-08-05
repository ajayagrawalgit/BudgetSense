# Backup and Restore Spec (BACKUP_RESTORE_SPEC.md)

One snapshot system serves all four flows: manual local backup, manual local
restore, (planned) automatic Google Drive backup, and (planned) manual restore
from Google Drive. There is exactly one snapshot format and one restore engine;
local and cloud never diverge.

## Components (shipped)

| Component | File | Role |
|---|---|---|
| `AppSnapshot` (envelope) | `lib/domain/services/snapshot_service.dart` | Format-agnostic model + envelope |
| `SnapshotCodecs` | `lib/data/snapshot/snapshot_codecs.dart` | JSON/CSV/XML encode+decode, lossless |
| `snapshot_tables` | `lib/data/snapshot/snapshot_tables.dart` | Column registry, table read, tolerant + resolved inserts |
| `snapshot_registry` | `lib/data/snapshot/snapshot_registry.dart` | Single source of truth for coverage (completeness guard) |
| `RestoreEngine` | `lib/data/snapshot/restore_engine.dart` | Preflight/plan + append-only transactional execute |
| `AppSnapshotService` | `lib/data/snapshot/app_snapshot_service.dart` | Ties export/import/preview together, settings merge |
| `import_ledger` | `lib/data/database/tables.dart` | Durable restore provenance (device-local) |

## Manual local backup (export)

`AppSnapshotService.export(format)`:
1. Read settings blob and all included tables (a consistent read).
2. Build the envelope with a fresh unique `backupId`.
3. Serialize to the chosen format.
4. Return bytes + filename + counts. The backup screen writes to a temp file and
   shares it.

Atomic-write hardening (write to temp, fsync, re-read, validate, promote) is
tracked for the cloud stage where the target file is long-lived; the current
share-sheet flow writes a throwaway temp file the user saves themselves.

## Manual local restore (import)

`AppSnapshotService.importBytes(bytes, {applySettingKeys})`:
1. Detect format; positively identify a BudgetSense file (reject foreign files).
2. Decode. On any decode failure, throw before touching data.
3. `RestoreEngine.plan(snapshot)`: mutation-free preflight and full plan
   (validates version, ids, money, duplicates; computes insert/skip/remap/version
   decisions and the id map).
4. `RestoreEngine.executeCollections(plan)`: one transaction, append-only.
5. Non-destructive settings merge.
6. Return a detailed `SnapshotImportResult` (inserted/skipped/remapped/versioned
   per table, preferences imported vs preserved, fk rewrites).

`AppSnapshotService.preview(bytes)` runs steps 1 to 3 plus the preference diff
and returns a `RestorePreview` for a confirm screen, with zero mutations.

See `RESTORE_CONFLICT_POLICY.md` for the exact per-record rules and
`SNAPSHOT_SCHEMA.md` for the envelope.

## Guarantees (all test-enforced)

- Existing records are never updated, replaced, or deleted.
- Collections are insert-only.
- Repeated restore is idempotent.
- Identical-looking records with distinct ids are both kept.
- Id collisions are remapped; FKs stay consistent.
- Changed source records are appended as versions, never overwrite.
- Preferences are preserved unless uninitialized or explicitly chosen.
- Any failure rolls back to the exact pre-restore state.
- Corrupt/unsupported/foreign files cause zero mutations.

## Planned (cloud stage)

Google Drive backup, client-side encryption, background sync, remote conflict
handling, and the reconciliation UI are specified in
`CLOUD_SYNC_ARCHITECTURE.md` and `GOOGLE_DRIVE_SETUP.md`. They reuse this exact
engine: cloud restore is just `importBytes` on downloaded, decrypted bytes.
