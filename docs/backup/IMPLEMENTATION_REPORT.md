# Backup Implementation Report (IMPLEMENTATION_REPORT.md)

Status date: cloud stage. Author: engineering (Flutter / mobile-security / data
integrity / QA / release). This report covers BOTH stages:

- Stage 1: safe, CI-verifiable non-destructive local restore foundation.
- Stage 2: opt-in, client-side-encrypted Google Drive cloud backup.

## Initial architecture discovered

- Export was solid: `AppSnapshot` + `SnapshotCodecs` (JSON/CSV/XML, lossless),
  `readAllTables` via Drift `toJson()`, tolerant companion builders, money as
  integer minor units.
- Restore was a RELEASE-BLOCKING DEFECT: `insertOnConflictUpdate` for every
  table plus a full settings replace. That overwrote and deleted user data on id
  collision and clobbered all preferences. The UI even told users "records with
  the same id are overwritten... settings are replaced."
- No import provenance, idempotency, conflict handling, preflight, completeness
  guard, cloud, or encryption.

## Files changed

Stage 1 (local restore):
- New: `snapshot_registry.dart`, `restore_engine.dart`,
  `test/data/restore_engine_test.dart`, `snapshot_completeness_test.dart`,
  `settings_merge_test.dart`.
- Modified: `tables.dart` (+`import_ledger`), `app_database.dart` (schema v3→v4,
  migration, wipe), `snapshot_tables.dart` (+`insertResolvedRow`),
  `snapshot_codecs.dart` (+`backupId`), `snapshot_service.dart` (envelope
  `backupId`, enriched result, `preview`), `app_snapshot_service.dart` (engine +
  merge), `backup_screen.dart` (honest copy).

Stage 2 (cloud), all under `lib/data/cloud/` unless noted:
- `cloud_constants.dart`, `cloud_failure.dart`, `encryption_service.dart`,
  `cloud_gateway.dart` (interfaces + models), `cloud_stores.dart`,
  `cloud_metadata_store.dart`, `mutation_tracker.dart`, `cloud_sync_state.dart`,
  `cloud_sync_controller.dart`, `google_drive_gateway.dart` (real Google impl).
- `lib/app/cloud_providers.dart` (DI + Drift `tableUpdates()` mutation wiring),
  `lib/main.dart` (prefs override), `lib/app/app.dart` (loadOnStart + resume
  retry), `lib/features/settings/cloud_backup_section.dart` (opt-in UI),
  `backup_screen.dart` (embeds the section).
- Android `AndroidManifest.xml`: added `INTERNET` + `ACCESS_NETWORK_STATE` (used
  only after opt-in).
- Tests: `cloud_sync_controller_test.dart` (22), `encryption_service_test.dart`
  (10), `cloud_stores_test.dart` (7), `test/features/cloud_backup_section_test.dart`
  (2), `test/support/fake_cloud.dart` (in-memory fakes).
- Reference (not compiled): `docs/backup/reference/background/*.dart.txt`.

## Snapshot coverage matrix

11 user-data tables INCLUDED (append-only). All registered settings keys
INCLUDED/MERGED. `import_ledger` EXCLUDED (device-local). Secrets, device/account
cloud metadata, derived state EXCLUDED. Enforced by the completeness guard.

## Data included / excluded

Included: categories, accounts, payment methods, transactions, recurring
payments, loans, custom fields + values, thresholds, notification preferences,
export records, and every preference in `SettingsState`.

Excluded and why: `import_ledger` (device-local provenance); OAuth tokens,
cached DEK/wrapped key, recovery passphrase (secrets, secure storage only);
Drive folder/file ids, versions, pending generation, last error (device/account
metadata); notification handles, temp files, derived summaries.

## Snapshot schema version

Envelope v4 (adds `backupId`). DB schema v4 (adds `import_ledger`). Legacy
v1/v2/v3 files still import through the same engine.

## Historical migration support

Legacy DB-only JSON backups and v3 full snapshots import through the one engine.
Files without `backupId` get a deterministic derived id so re-imports stay
idempotent.

## Encryption design

AES-256-GCM authenticated encryption (`cryptography` package, no hand-rolled
primitives). A random 256-bit data-encryption key (DEK) encrypts the payload
with a unique 96-bit nonce per upload. The DEK is wrapped by a KEK derived from
the recovery passphrase via PBKDF2-HMAC-SHA256 (210k iterations default). Salt
and KDF params live in the envelope; critical envelope metadata (product,
version, backupId, KDF params) is authenticated as AAD. Envelope format v1
(`.bsbak` JSON). Covered by 10 tests including wrong-passphrase, tampered
ciphertext, tampered AAD metadata, unique-nonce, and cached-DEK decrypt.

## Key-recovery design

The recovery passphrase is the only recovery secret and is never persisted,
uploaded, or logged. The DEK/wrapped key is cached only in Android Keystore /
iOS Keychain via `flutter_secure_storage` for automatic future uploads. A device
joining an existing backup recovers the SAME key lineage from the envelope using
the passphrase (`recoverKeyMaterial`). Passphrase change re-wraps the DEK and
re-uploads the latest validated snapshot; the DEK is never silently reset.

## Restore identity and idempotency design

Stable source id + canonical content hash (FNV-1a/64) + durable `import_ledger`.
Re-importing the same file skips already-imported records. Same engine for local
files, Drive files, and historical migrations.

## Append-only guarantees

Insert-only for collections; existing records never updated/deleted/replaced; id
collisions remapped; changed records appended as versions; FKs remapped
consistently. Proven in `restore_engine_test.dart` incl. a full pre-restore
invariant-capture test. Cloud restore uses the same engine (proven idempotent in
`cloud_sync_controller_test.dart`).

## Preference merge behavior

Existing local values preserved by default; backed-up values applied only when
local is uninitialized or the user explicitly selects the key. `preview` reports
without mutating.

## Restore rollback design

Single Drift transaction for all inserts; settings applied only after commit.
Mutation-free preflight rejects corrupt/unsupported/duplicate/non-finite input
before any write. Rollback proven by the mid-restore-failure test.

## Google Drive scope / folder / discovery / conflict behavior

- Scope: `drive.file` only (never broad `drive`).
- Folder `BudgetSense_Backup` and one canonical file `budgetsense_backup.bsbak`
  (single constants), matched by `appProperties` marker + name + mime, not name
  alone. Cached ids validated against the linked account; stale ids fall back to
  marker-based discovery; duplicates resolved oldest-wins; never hijacks an
  arbitrary same-name folder or another account's ids.
- One file reused by id for the backup lifecycle (not recreated per mutation).
- Uploads set `appProperties` (digest, generation, format version) and are
  validated (returned digest) before the local generation is marked uploaded.
- Remote concurrency: optimistic `expectedVersion` check blocks overwrite of a
  file changed by another device → `remoteConflict` requiring reconciliation.

## Background-sync behavior

Foreground: debounced, coalesced, non-overlapping uploads after any committed
mutation (wired via Drift `tableUpdates()` at the persistence boundary, no-op
when disabled). Retry on app start, resume, manual "Back up now", and after
reauth. Mutations during an upload keep state pending and trigger another sync.

OS-scheduled background upload defaults to no-op. A WorkManager reference
implementation is kept in `docs/backup/reference/background/` but is NOT a hard
dependency: `workmanager` 0.5.2 uses removed Flutter-v1 embedding APIs and the
0.9.x federated plugin failed to resolve its Android module onto the app
classpath in this toolchain, breaking the release build. Shipping a broken or
unverifiable native dependency was rejected in favor of the abstraction default.
See CLOUD_SYNC_ARCHITECTURE.md for how to enable and verify it on device.

## Remote conflict behavior

`remoteConflict` state; the user reconciles (download + append-import + review +
upload merged) before any overwrite. Never silently overwrites another device.

## Test counts and results

- Total: 304 tests, all passing (was 247 → 266 after Stage 1 → 304 after cloud).
- Cloud additions: 22 controller, 10 encryption, 7 stores/tracker/metadata, 2
  widget, plus in-memory fakes for every Drive/auth scenario.
- Analyzer: `flutter analyze` clean.
- Formatting: `dart format` clean.

## Coverage

Meaningful line coverage 70.44% (gate 70%, PASS). New critical modules:
encryption_service 99.3%, restore_engine 93.5%, snapshot_registry 100%,
mutation_tracker 100%, cloud_metadata_store 92.9%, cloud_sync_controller 91.8%,
app_snapshot_service 96.3%. Device-only files excluded from CI coverage:
`google_drive_gateway.dart` and the WorkManager reference (cannot run without
Google/native plugins); their behavior is covered via the interfaces + fakes.

## Android build result

`flutter build apk --release` PASS →
`build/app/outputs/flutter-apk/app-release.apk` (83.1MB). UNSIGNED (no release
keystore in this environment; the build honestly does not fall back to debug
signing).

## iOS build result

Not built (no iOS toolchain/signing in this environment). iOS OAuth/URL-scheme
steps documented in GOOGLE_DRIVE_SETUP.md.

## Real-device tests completed

None. Real Google OAuth and on-device verification cannot be performed from the
repository. Checklist in GOOGLE_DRIVE_SETUP.md section 7.

## External blockers

- Google Cloud Console: project, Drive API, OAuth consent (`drive.file`),
  Android debug + release OAuth clients (SHA-1/-256), iOS client + reversed URL
  scheme, test users, production verification.
- Release signing identity for the production OAuth binding.
- A Flutter-3.44-compatible background-work plugin if OS-scheduled background
  upload is required (foreground sync works today).

## Remaining risks

- Restoring onto a device that already holds DIFFERENT records with the same ids
  appends remapped copies (by design, never overwrite). Explained in the restore
  result and RESTORE_CONFLICT_POLICY.md.
- Google gateway and background-isolate paths are implemented but unverified on
  real hardware.

## Final recommendation

- GO: non-destructive local backup/restore (release-blocking data-loss defect
  removed, fully covered) and the repository-controlled cloud implementation
  (opt-in, encrypted, append-only, tested with fakes, release APK builds).
- NO-GO on claiming real-device production OAuth has been verified until the
  external Google Cloud + release-signing steps are completed and the on-device
  checklist passes. Do not call the APK production-ready until signed and OAuth
  is validated.

## Terminal summary

- Implementation status: local restore COMPLETE; cloud IMPLEMENTED (repo-side),
  pending external OAuth + on-device verification.
- Analyzer: clean.
- Tests: 304 passing.
- Coverage: 70.44% overall (gate 70%); new critical modules 91.8%–100%.
- Snapshot sections covered: 11 tables + all settings; ledger + cloud metadata
  excluded.
- Append-only invariant: PASS.
- Repeated-restore idempotency: PASS (local and cloud).
- Rollback test: PASS.
- Encryption/tamper test: PASS (wrong passphrase, tampered ciphertext + AAD).
- Google Drive gateway test: PASS via interfaces + in-memory fakes (all
  scenarios); real Google impl not run in CI by design.
- Android release build: PASS (unsigned).
- External OAuth/signing blockers: Google Cloud Console + release signing.
- Report path: docs/backup/IMPLEMENTATION_REPORT.md
