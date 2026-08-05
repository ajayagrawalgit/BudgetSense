# Restore Conflict Policy (RESTORE_CONFLICT_POLICY.md)

BudgetSense restore is NON-DESTRUCTIVE and APPEND-ONLY. It never updates,
replaces, or deletes an existing local record. This document defines exactly
what happens in every case. The word "merge" is avoided for collection data
because it implies overwriting; nothing is overwritten.

The engine lives in `lib/data/snapshot/restore_engine.dart` and every rule below
is proven by `test/data/restore_engine_test.dart`.

## Identity, not guesswork

Two expenses with the same name, date, category, and amount are NOT assumed to
be duplicates. Identity is decided by:
1. The record's stable source `id`.
2. A canonical content hash (FNV-1a/64 over a key-sorted JSON encoding, ignoring
   the `id`).
3. The durable `import_ledger`, which records for each imported record: backup
   id, source entity type, source record id, source content hash, resolved local
   id, import time, and conflict status.

## Collection records (expenses, payments, budgets, categories, and so on)

Per source row, in FK-safe order:

### New source record (never imported, id does not collide)
Insert it, PRESERVING the source id. Record it in the ledger as `inserted`.

### Exact record already present (idempotent re-import)
If the ledger shows this source record was imported with the same content and the
local record still exists, SKIP it. Restoring the same file twice therefore
produces the same result as once.

### Id collision with different content
The source id matches an existing local record, but the content differs (and the
ledger has no matching prior import). Do NOT touch the local record. Mint a NEW
local id, insert the imported record under it, and record the source-to-local
mapping. Every foreign key that pointed at the source id is rewritten to the new
local id, consistently. Status: `remapped`. Reported to the user.

### Previously imported source record changed in a newer snapshot
The ledger shows this source id was imported before, but the new snapshot's
content hash differs (or the local copy was deleted). Do NOT overwrite the older
local record. Append the newer version under a fresh local id. Status:
`version`. Reported to the user. Neither version is discarded.

## Foreign key remapping

After the full id map is built, every FK is rewritten so appended records point
at the right rows:
- Hard FKs (`categoryId`, `accountId`, `paymentMethodId`) that resolve to a
  record present in neither the snapshot nor the local DB are set to null rather
  than failing the whole restore.
- Soft/link FKs (`linkedPaymentId`, `linkedLoanId`) are remapped when possible.
- The polymorphic `customFieldValues.ownerId` is remapped by `ownerType`.

## Preferences and profile (singletons)

Cannot be appended, so a non-destructive MERGE applies:
- Existing local values are kept by default.
- A backed-up value is applied automatically only when the local value is
  uninitialized (absent, empty, or still at its default).
- Differing values are surfaced in the restore preview; the user can explicitly
  select preference groups to apply.
- Device secrets and biometric trust are never restored.

## Atomicity and rollback

All collection inserts happen in ONE Drift transaction. On any failure the
transaction rolls back, leaving zero inserted rows and zero ledger entries.
Settings are only written after the collection transaction succeeds, and only if
the merge produced changes. A corrupt snapshot, wrong version, duplicate source
ids, or non-finite money all cause ZERO mutations because they are caught in the
mutation-free preflight (`RestoreEngine.plan`).

## Rejected safely (zero mutations)

Empty/whitespace-only backups, unrecognized files, foreign apps' files (for
example Paisa), unsupported future envelope versions, missing record ids,
duplicate source ids within one backup, and non-finite monetary values.
