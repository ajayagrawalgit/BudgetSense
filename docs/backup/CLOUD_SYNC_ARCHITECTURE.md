# Cloud Sync Architecture

BudgetSense cloud backup is an **optional, opt-in, offline-first** feature. It
uses the user's own Google Drive as an encrypted backup destination, not as a
generic multi-user backend. This document describes the architecture, the state
machine, and the safety guarantees.

## Design principles

1. One snapshot format for local AND cloud (see `SNAPSHOT_SCHEMA.md`). There is
   no separate cloud format that can drift.
2. One restore engine for local files, Drive files, and historical migrations
   (see `BACKUP_RESTORE_SPEC.md` and `RESTORE_CONFLICT_POLICY.md`). Restore is
   append-only and non-destructive.
3. Strictly opt-in. No authentication, file lookup, upload, or background work
   happens before the user enables the feature. Enforced in `CloudSyncController`
   (every entry point checks `metadata.enabled`) and by the background worker's
   cheap early-exit.
4. Google is isolated behind interfaces. The core backup/restore/domain layers
   never import Google API classes.

## Layers

```
UI (CloudBackupSection)
        |
CloudSyncController  ── ChangeNotifier state machine (framework-free, tested)
   |          |            |            |            |
Snapshot  Encryption   Auth Gateway  Backup Gateway  Metadata + Tracker
Service   Service      (interface)   (interface)     Stores
                          |             |
                 GoogleDriveAuthGateway GoogleDriveBackupGateway  (google_sign_in / googleapis)
```

- `CloudBackupAuthGateway` / `CloudBackupGateway` are pure interfaces. CI uses
  in-memory fakes (`test/support/fake_cloud.dart`); production uses the Google
  implementations in `google_drive_gateway.dart`.
- `SnapshotEncryptionService` handles AES-256-GCM + PBKDF2 key wrap.
- `CloudSyncMetadataStore` holds device/account-specific metadata (linked
  account, folder id, file id, last remote version, last digest, last uploaded
  generation, last sync time, last error). This is NEVER inside the snapshot.
- `BackupMutationTracker` holds a persistent monotonic generation and the last
  uploaded generation. `isPending == currentGeneration > lastUploadedGeneration`.

## State machine

`CloudSyncState.status`:

- `disabled`: off. No auth, no network, nothing scheduled.
- `linking`: setup in progress (auth + folder/file + first backup).
- `idle`: enabled, everything uploaded.
- `pending`: enabled, committed changes waiting to upload.
- `syncing`: an upload is in flight.
- `remoteConflict`: the remote file changed unexpectedly (another device).
- `requiresSignIn`: authorization lost/revoked.
- `error`: a non-transient error the user should see.

## Enabling / reconciliation

`beginLink(passphrase)`:
1. Interactive `authenticate` (drive.file scope). Records account id + email.
2. `ensureFolder()` finds or creates `BudgetSense_Backup` (matched by
   `appProperties` marker + name + mime, not name alone).
3. `findBackupFile()` inside the folder.
   - No existing file → derive new key material, upload the first validated
     backup, enable. Outcome `linkedFresh`.
   - Existing file → outcome `needsReconcile` with the (unauthenticated)
     envelope header for the UI. Nothing is overwritten yet.

Reconciliation (Phase 6):
- **Import** (`reconcileImport`): recover the key lineage from the existing
  file using the passphrase (validates it before any write), decrypt, run the
  append-only restore, then re-upload the merged local state on the SAME file
  and key.
- **Overwrite** (`reconcileOverwrite`): derive a fresh key, replace the cloud
  file content (a prior Drive revision remains recoverable). Local data
  untouched.
- **Cancel** (`reconcileCancel`): sign out, clear the link, stay disabled.

Selection never uses timestamps alone, and never restores automatically.

## Change tracking and sync (Phases 7 to 8)

- Mutation tracking is wired at the persistence boundary: `cloud_providers`
  subscribes to Drift `tableUpdates()` for the snapshot-included tables and
  calls `markDirty()`. No UI write path can bypass it, and it is a no-op while
  cloud backup is disabled.
- `markDirty()` persists the new generation immediately and debounces a
  coalesced upload (default 8s).
- `syncNow()` never overlaps (`_syncing` guard). It exports → encrypts →
  digests → creates/updates the file with a conditional `expectedVersion`
  check, validates the returned metadata digest, then records the upload and
  marks only that generation uploaded. A mutation during upload keeps the state
  pending and triggers another sync.
- Remote concurrency: before replacing the remote file, the gateway confirms the
  remote `version` still equals the one this device last saw. A mismatch raises
  `remoteConflict` instead of overwriting another device's backup.

## Background execution (Phase 7)

The scheduler is abstracted behind `BackgroundSyncScheduler`. The DEFAULT wired
implementation is `NoopBackgroundSyncScheduler`: foreground sync is fully
functional and covers the common cases:

- debounced, coalesced upload after any committed mutation while the app is
  active;
- retry on app start (`loadOnStart`), on app resume, on manual "Back up now",
  and after reauthentication.

A full WorkManager implementation (`WorkManagerBackgroundSyncScheduler`) and the
background isolate entry point (`cloudSyncCallbackDispatcher`) are provided as a
REFERENCE in `docs/backup/reference/background/`. They are intentionally NOT a
hard dependency of the shipped build: `workmanager` 0.5.2 uses removed v1
embedding APIs (incompatible with Flutter 3.44) and the 0.9.x federated plugin
did not resolve its Android module onto the app classpath in this toolchain,
which broke the release build. Rather than ship a broken or unverifiable native
dependency, the abstraction defaults to no-op and the reference code is kept for
teams that add a Flutter-3.44-compatible WorkManager and verify it on device.

To enable true OS-scheduled background upload:
1. Add a compatible `workmanager` (or equivalent) plugin and confirm the release
   build still compiles.
2. Restore the two files from `docs/backup/reference/background/` into
   `lib/data/cloud/`.
3. Point `backgroundSyncSchedulerProvider` at
   `WorkManagerBackgroundSyncScheduler` and call
   `Workmanager().initialize(cloudSyncCallbackDispatcher)` in `main()` (Android),
   guarded so a failure never blocks startup.
4. Verify on a real device (docs/backup/GOOGLE_DRIVE_SETUP.md, section 7).

Rules the isolate must keep: silent auth only, exit with no network when
disabled/not pending, return retry on transient failure, never prompt, never log
snapshot contents.

- iOS: background execution timing is OS-controlled. BudgetSense does not
  promise immediate closed-app sync.
- **DEVICE-ONLY VERIFICATION REQUIRED** for any background path.

## Failure taxonomy (Phase 9)

`CloudFailureKind` covers offline, timeout, auth canceled/required, authorization
revoked, insufficient scope, wrong account, folder/file missing, trashed, quota,
rate limited, transient server, remote conflict, snapshot/validation/encryption
failures, wrong passphrase, upload/download integrity mismatch, unsupported
version, local storage failure, and restore rollback failure. Transient kinds
retry with backoff; auth kinds move to `requiresSignIn`; integrity failures keep
the previous known-good backup. User messages never expose payloads, tokens,
file ids, or crypto material.

## What is stored where

| Data | Location | In snapshot? |
|---|---|---|
| Financial + preference data | Drift DB (local) / encrypted blob (Drive) | Yes (encrypted for cloud) |
| Linked account id + email | `CloudSyncMetadataStore` (prefs) | No (device-specific) |
| Folder id / file id / versions | `CloudSyncMetadataStore` (prefs) | No |
| OAuth tokens | google_sign_in secure storage | No |
| Cached DEK / wrapped key | Keystore/Keychain via secure storage | No |
| Recovery passphrase | Nowhere persisted | No |
| Pending generation | `BackupMutationTracker` (prefs) | No |
