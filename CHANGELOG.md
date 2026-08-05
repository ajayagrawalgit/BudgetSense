# Changelog

All notable changes to BudgetSense are documented here. The format is loosely
based on Keep a Changelog, and the project uses semantic versioning
(`MAJOR.MINOR.PATCH+BUILD`).

## [Unreleased]

### Added (in-app updates for sideloaded builds)
- Optional self-update for non-Play (sideloaded) installs. On launch the app
  quietly checks a `latest.json` on GitHub Releases and, if a newer versionCode
  exists, shows a gentle, dismissible banner. Never forces: the user can tap
  "Maybe later" and a dismissed version is not nagged again.
- On "Update now": downloads the APK, verifies its SHA-256, and hands it to the
  Android system installer (the user still confirms in the OS dialog). A
  corrupt/tampered or oversized download is discarded and never installed.
- Network and native install are behind interfaces (`UpdateGateway`,
  `ApkInstaller`) so CI tests the whole flow with fakes; added a `FileProvider`,
  `REQUEST_INSTALL_PACKAGES`, and an installer MethodChannel (Android-only).
- Configure with `--dart-define=UPDATE_REPO_SLUG=owner/repo`; dormant (no checks,
  no crashes) when unset. Docs: `docs/updates/AUTO_UPDATE.md`.
- 11 new tests (manifest validation, version compare, dismissal, offline safety,
  SHA-256 verify, corrupt-download-never-installs, permission routing, banner).

### Fixed
- Restored `USE_BIOMETRIC` and `INTERNET`/`ACCESS_NETWORK_STATE` explicit entries
  in `AndroidManifest.xml` and removed a stray malformed line introduced during
  the cloud stage (permissions had still worked via plugin manifest merging).

### Changed (backup safety, Phase 1 to 4)
- Restore is now NON-DESTRUCTIVE and append-only. It never updates, replaces, or
  deletes an existing local record. The previous behavior overwrote records with
  matching ids and replaced all settings; that was a data-loss defect and is
  fixed. See `docs/backup/RESTORE_CONFLICT_POLICY.md`.
- Backup screen copy and result summary are now honest: existing data is kept,
  new records are added, already-imported records are skipped, id conflicts are
  appended as new records, and preferences are preserved unless unset.

### Added
- Durable import provenance (`import_ledger` table, schema v4) making restore
  idempotent and auditable; re-restoring the same backup never duplicates data.
- Id-collision remapping with consistent foreign-key rewriting, and versioned
  append for changed source records.
- Non-destructive preference merge (existing values win unless uninitialized or
  explicitly chosen) plus a mutation-free `preview` for a confirm screen.
- Snapshot completeness guard (`snapshot_registry.dart` +
  `snapshot_completeness_test.dart`): the build fails if a new persistent table
  or settings key is added without a backup policy.
- Snapshot envelope `backupId` (envelope v4), backward compatible with older
  files via a deterministic derived id.

### Added (Google Drive cloud backup, Phases 5 to 11)
- Optional, strictly opt-in "Backup and Sync to Cloud" (default OFF). No
  authentication or network happens until the user enables it and completes
  setup; enforced in `CloudSyncController`.
- Client-side encryption before every upload: AES-256-GCM with a random DEK
  wrapped by a PBKDF2-HMAC-SHA256 key from a user recovery passphrase. Only
  ciphertext reaches Google Drive. Passwords/keys live only in Keystore/Keychain.
- Narrow `drive.file` OAuth scope; a visible `BudgetSense_Backup` folder and one
  canonical `budgetsense_backup.bsbak` file, discovered by application markers
  (never by name alone), reused by id, with conditional-update remote-conflict
  safety.
- Same append-only restore engine for local and cloud, with a reconciliation
  flow (import / use-this-device / cancel) when a cloud backup already exists.
- Persistent mutation tracking wired at the Drift persistence boundary so every
  committed change marks the backup pending; debounced, coalesced, non-
  overlapping foreground uploads with retry on start/resume/manual/reauth.
- Typed cloud failure taxonomy and user-safe messages that never leak payloads,
  tokens, file ids, or crypto material.
- Added `INTERNET`/`ACCESS_NETWORK_STATE` to the Android manifest for this
  optional feature only.
- Cloud docs: `CLOUD_SYNC_ARCHITECTURE.md`, `GOOGLE_DRIVE_SETUP.md`,
  `MANUAL_TEST_PLAN.md`; updated PRIVACY, SECURITY, DATA_RECOVERY, and the
  release checklist to the accurate network/privacy posture.
- 57 new tests since 0.1 (304 total): restore invariants, completeness guards,
  settings merge/preview, encryption/tamper, and the full cloud controller with
  in-memory Google/Drive fakes.

### Note
- Google Drive cloud backup is IMPLEMENTED in the repository (opt-in, encrypted,
  append-only) and the release APK builds, but real-device production OAuth and
  release signing are external steps that cannot be performed from the repo. Do
  not claim real-device production OAuth has been verified until the checklist in
  `docs/backup/GOOGLE_DRIVE_SETUP.md` (section 7) passes on hardware. OS-scheduled
  background upload defaults to no-op (foreground sync works); see the WorkManager
  reference in `docs/backup/reference/background/`.

## [0.1.0] - BudgetSense 0.1

First production-readiness release of BudgetSense: a calm, offline-first,
privacy-focused personal finance journal for Android (iOS supported, with fewer
platform automations).

### Highlights
- Offline-first: all data stays on-device; the production Android build ships
  with no `INTERNET` permission.
- Transactions, dynamic categories, accounts, payment methods, recurring
  payments and investments, loans, custom fields, and spending thresholds.
- Full-snapshot backup/restore (JSON/CSV/XML) and import from other apps.
- Local reminders, home-screen widgets (Android), optional biometric app lock.

### Production-readiness work in this release
- Set canonical version to `0.1.0+1`; in-app version mirrors pubspec and is
  verified by release preflight.
- Raised meaningful line coverage from ~46% to **74.75%** (247 tests) with
  behavioural tests for repositories, the DI graph, database logic (foreign
  keys, wipe, indexes), settings persistence, the widget platform channel, and
  domain entities. No critical infrastructure file remains at 0%.
- Fixed a misleading in-code security comment that implied SQLCipher at-rest
  encryption; documented the real threat model in `docs/SECURITY.md`.
- Release builds no longer fall back to debug signing; without a keystore the
  APK is left honestly unsigned.
- Committed `pubspec.lock` for reproducible builds.
- Added fail-closed CI: format, analyzer, generated-code drift, tests +
  coverage gate, Gitleaks secret scanning, OSV-Scanner, dependency review, and
  release-build validation, plus Dependabot.
- Added reusable scripts (`scripts/quality_gate.sh`,
  `scripts/release_preflight.sh`, `scripts/check_placeholders.sh`,
  `scripts/apk_checksum.sh`) and a coverage gate (`tool/coverage_report.py`).
- Resolved the formatting gate and a formatter/lint incompatibility
  (`require_trailing_commas`), and fixed a real missing-braces lint.
- Removed the unused `fl_chart` dependency; took safe in-constraint dependency
  upgrades. Major upgrades are risk-accepted and tracked.
- Added documentation: SECURITY, PRIVACY, CONTRIBUTING, RELEASE_CHECKLIST,
  and DATA_RECOVERY.

### Known limitations
- No app-layer database encryption (SQLCipher) yet; see `docs/SECURITY.md`.
- The 0.1 production APK is unsigned pending an organization-owned keystore; see
  `docs/RELEASE_CHECKLIST.md`.
- R8 code/resource shrinking is disabled pending an on-device smoke test.
