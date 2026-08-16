# BudgetSense Security Assessment

**Date:** 2026-08-16
**Application:** BudgetSense 0.1 (versionCode 1), `com.budgetsense.budgetsense`
**Assessed by:** Automated white-box security review of this repository
**Decision:** **CONDITIONAL RELEASE**

---

## 1. Executive summary

BudgetSense is an offline-first personal finance journal. Reviewed against a
mobile application security baseline, it is in **materially better shape than a
typical Flutter application at this stage**. The most consequential
vulnerability classes in mobile apps are absent here by design rather than by
mitigation: there is no WebView, no JavaScript bridge, no deep-link handler, no
custom URL scheme, no FFI, no process execution, no analytics SDK and no crash
reporter. The app makes no network request at all unless the user opts into
Google Drive backup or a sideloaded update check.

**No Critical or High vulnerability was found.** No embedded secret was found in
source or in the built release binary. There is no TLS bypass, no cleartext
traffic, and the release APK is signed with the genuine release certificate
rather than a debug key.

Five Medium-severity issues were identified and **all five were fixed** in this
repository, each with regression coverage or an automated gate:

1. Spreadsheet formula injection in CSV/XLSX export.
2. An unbounded, attacker-controlled PBKDF2 iteration count in the encrypted
   backup parser, plus unchecked casts that turned malformed files into crashes.
3. Path injection through the update manifest `versionName`, plus a weak
   `apkUrl` prefix check bypassable via userinfo.
4. A FileProvider declaration broad enough to expose the entire transaction
   database as a `content://` URI.
5. An installer platform channel that accepted an arbitrary filesystem path.

The decision is **CONDITIONAL** rather than **RELEASE** purely because of
environment limits, not unresolved vulnerabilities: no iOS build host was
available, no vulnerability or secret scanner is installed on this machine, the
project is **not a Git repository** so history-based secret scanning was
impossible, and a pre-existing test hang blocks a clean full-suite run.

## 2. Scope and authorization

**In scope and examined:** all source in this repository, build and CI
configuration, Android and iOS platform configuration, and the release APK built
from this source.

**Not authorized and not performed:** no remote testing of any kind.
`AUTHORIZED_SECURITY_BASE_URL` and `AUTHORIZED_SECURITY_ALLOWED_HOSTS` were not
set, so no request was issued to GitHub, Google, or any other host. Endpoints
found in source were treated as out of scope, which is the correct default.

**Not applicable:** this app has no backend owned by the project, so there is no
server-side authorization surface to test. No `security/BACKEND_SECURITY_ACTIONS.md`
was produced because no server-side work is required.

## 3. Environment

| Component | Version / status |
|---|---|
| Flutter / Dart | 3.44.4 stable / 3.12.2 |
| Host OS | macOS 26.6.1, arm64 |
| JDK | OpenJDK 21 (Homebrew) |
| Android build-tools | 37.0.0 (`apksigner`, `aapt2` available) |
| Xcode / CocoaPods | **Not installed** (CLI tools only) |
| osv-scanner / gitleaks / trufflehog / semgrep | **Not installed** |
| Git | **Repository is not under Git version control** |

## 4. Methodology

Static review of all 131 Dart source files, 11 Kotlin files, Android and iOS
platform configuration and CI workflows; targeted structural searches for
security-sensitive constructs; a release APK build followed by binary
inspection (merged manifest, exported components, permissions, signing
certificate, decoded resources, asset and dex secret sweeps); and authoring of
security regression tests plus an automated gate script.

Dynamic testing, emulator testing and remote testing were **not performed**.

## 5. Findings

| ID | Title | Severity | Confidence | Status |
|---|---|---|---|---|
| F-001 | CSV/XLSX formula injection in export | Medium | Confirmed | **Fixed** |
| F-002 | Unbounded attacker-controlled PBKDF2 iterations + unchecked casts | Medium | Confirmed | **Fixed** |
| F-003 | Path injection via update manifest `versionName` | Medium | Confirmed | **Fixed** |
| F-004 | FileProvider exposed the app files directory | Medium | Confirmed | **Fixed** |
| F-005 | Installer channel accepted an arbitrary path | Medium | Confirmed | **Fixed** |
| F-006 | Plaintext local backups in shared storage | Low | Confirmed | Accepted (documented) |
| F-007 | Dependencies significantly outdated, one EOL | Low | Needs external validation | Open (deferred) |
| F-008 | CI actions pinned by tag, not commit SHA | Low | Confirmed | Open (accepted) |
| F-009 | R8 / minification disabled in release | Informational | Confirmed | Accepted |
| F-010 | Pre-existing widget test hang blocks a clean full run | Informational | Confirmed | Open (pre-existing) |

Full technical detail and fix rationale for F-001 through F-005 is in
`security/REMEDIATION_LOG.md`.

### F-001 — Spreadsheet formula injection (Medium, CWE-1236, MASVS-CODE)

`lib/domain/services/export_service.dart`. User-controlled fields were written
into CSV/XLSX cells with no neutralisation. A note beginning `=`, `+`, `-` or
`@` is executed as a formula by every mainstream spreadsheet, and formulas such
as `WEBSERVICE` or `IMPORTXML` can transmit sheet contents to a remote host.
Realistically exploitable because the victim is often a third party, such as an
accountant, opening a shared export. **Fixed** with a shared escaping helper
applied at the single projection point, plus unit and end-to-end tests.

### F-002 — Unbounded PBKDF2 iterations and unchecked casts (Medium, CWE-1284/CWE-400, MASVS-CRYPTO)

`lib/data/cloud/encryption_service.dart`. The iteration count was read from the
untrusted backup file with no bounds, allowing a hostile `.bsbak` to force an
effectively infinite key derivation on the restore path; a downgraded count
would weaken the wrapped key. Envelope fields were also cast unchecked, so a
malformed file crashed rather than failing as a typed `CloudFailure`.
**Fixed** with enforced bounds on both read and write paths and full field
validation. Note the underlying cryptography was already sound: AES-256-GCM,
random per-payload nonces, 210k iterations, AAD-bound metadata, no home-rolled
primitives.

### F-003 — Path injection via `versionName` (Medium, CWE-22, MASVS-CODE)

`lib/data/updates/update_manifest.dart`. A remotely supplied `versionName` was
interpolated into the APK download path unvalidated, and `apkUrl` was checked
with a prefix match bypassable by `https://github.com@evil.example/...`.
**Fixed** with a strict character allowlist and real URI parsing. Reachable only
when `UPDATE_REPO_SLUG` is set at build time, and still gated by SHA-256
verification, an Android signature match and a mandatory user confirmation, so
impact was bounded, but this is the app's only code-execution pathway and
deserves strict input handling.

### F-004 — Over-broad FileProvider (Medium, CWE-926, MASVS-PLATFORM)

`android/app/src/main/res/xml/provider_paths.xml` declared `files-path` with
`path="."`, covering the directory holding the SQLite database of every
transaction. **Fixed** by scoping to `cache-path` only, the sole directory the
one consumer actually uses. Verified in the built APK by decoding the resource.

### F-005 — Installer channel accepted an arbitrary path (Medium, CWE-20, MASVS-PLATFORM)

`MainActivity.kt` passed any channel-supplied path to the package installer
after only an existence check. **Fixed** with canonical-path confinement to the
cache directory.

### F-006 — Plaintext local backups (Low, accepted)

Local backups are written unencrypted to shared storage and survive uninstall.
This is an intentional, disclosed product decision so users retain a portable
copy. Documented rather than silently changed.

### F-007 — Outdated dependencies (Low, open)

Many packages are one or more majors behind (drift 2.19→2.34, riverpod 2→3,
file_picker 8→12, flutter_local_notifications 17→22, others), and
`sqlite3_flutter_libs` is flagged EOL at 0.6.0. **No specific reachable advisory
was confirmed**, and no scanner is installed here to confirm one either way. All
dependencies resolve from pub.dev with no Git, path or override dependencies,
which is a good supply-chain posture. Deferred deliberately: bundling risky
major upgrades into a security patch is worse engineering than scheduling them
separately. CI runs OSV-Scanner as a blocking gate.

### F-008 — CI actions pinned by tag (Low, open)

Workflows reference third-party actions by tag rather than commit SHA, which is
mutable. Already acknowledged in comments in `ci.yml`. Low risk for a project of
this size; worth tightening.

## 6. What was verified as already secure

These were confirmed working, not assumed:

- **No TLS bypass.** Zero matches for `badCertificateCallback`,
  `HttpOverrides.global` or custom `SecurityContext` anywhere in `lib/`.
- **No cleartext.** Zero `http://` URLs in `lib/`; no `usesCleartextTraffic`; no
  iOS ATS exceptions in `Info.plist`.
- **No secrets.** Clean sweep of source, and of the built APK's assets and dex
  for Google API keys, PEM keys, AWS keys, GitHub tokens and JWTs. The one dex
  match was a bare `-----BEGIN ` parser format string with no key body: a
  confirmed false positive. No `.env`, no `google-services.json`, no
  service-account file is packaged.
- **Release signing is correct.** `apksigner` confirms the APK is v2-signed with
  `CN=BudgetSense` and **not** the Android debug key. The Gradle config falls
  back to *unsigned* rather than debug-signed when no keystore is present, which
  is the right fail-safe. Keystores exist on disk but are gitignored.
- **Release manifest is clean.** No `android:debuggable`, no cleartext flag,
  `allowBackup="false"`. All 14 exported components are legitimate: the launcher
  activity, 11 home-screen widget receivers (read-only rendering, all
  PendingIntents `FLAG_IMMUTABLE`), a Google Play Services service with a
  signature permission, and the profile installer guarded by
  `android.permission.DUMP`.
- **No logging in release.** `AppLog` returns early when `!kDebugMode`; no stray
  `print`/`debugPrint` calls.
- **No SQL injection.** Drift parameterizes throughout; the only
  `customStatement` calls use hardcoded PRAGMA and CREATE INDEX strings.
- **Privacy posture is genuine.** No analytics, no crash reporting, no tracking
  SDK. Drive integration requests `drive.file` scope only and embeds no client
  secret.
- **Screen protection.** `FLAG_SECURE` on by default; optional device-credential
  app lock with a 20-second re-lock grace period.

## 7. Validation results

| Check | Result |
|---|---|
| `dart format --set-exit-if-changed` | **Pass** (212 files clean) |
| `flutter analyze` | **Pass** — no issues found |
| Unit/widget tests (`core`, `domain`, `data`, `app`, `security`, `widget`) | **Pass** — 363 tests |
| Security regression tests | **Pass** — 22 tests |
| `test/features/` full run | **Blocked** — pre-existing hang (F-010) |
| Integration tests | **Not run** — none present |
| Android release APK build | **Pass** — exit 0, 85.1 MB, signed |
| Merged release manifest inspection | **Pass** |
| APK signing verification (`apksigner`) | **Pass** — v2, release cert |
| APK resource/asset/dex secret sweep | **Pass** — no secrets |
| `scripts/security_gate.sh` | **Pass** — 10/10, fail-behaviour verified |
| iOS release build | **Not run** — no Xcode on host |
| Web release build | **Not applicable** — no web target |
| Automated dependency scan | **Not run** — no scanner installed |
| Automated secret scan (history) | **Not run** — not a Git repository |
| Dynamic / emulator / remote testing | **Not run** — not authorized, not configured |

Regarding F-010: `test/features/` stalls at
`custom_field_manager_screen_test.dart` with repeated `Bad state: Cannot add
event while adding stream`. This matches the previously documented Drift
teardown hang under Flutter's fake-async environment and is **pre-existing, not
introduced by this work**. Confirmed by running the feature tests touching the
changed code (`update_banner_test.dart`, `cloud_backup_section_test.dart`,
`widget_payload_test.dart`), all of which pass.

Two pre-existing tests began failing against the new PBKDF2 floor because they
used `iterations: 1000` for speed. They were updated to use the real minimum
rather than weakening the control; the suite still completes in seconds.

## 8. Release decision: CONDITIONAL RELEASE

No Critical or High vulnerability remains open. All five Medium findings are
fixed and verified. No secret is embedded in the client, no release build trusts
arbitrary certificates, no cleartext is permitted, and the release is not
debug-signed.

The condition is evidence coverage, not known risk. Before an iOS release,
build and inspect on a macOS host with Xcode. Before either store release,
complete the external items in section 9 and the on-device checks in section 10.
For an **Android-only sideloaded release, the security gates are met.**

## 9. Required external actions

1. **Verify Google OAuth client restrictions** in Google Cloud Console: the
   client should be restricted to package `com.budgetsense.budgetsense` plus the
   release signing certificate fingerprint, and limited to `drive.file`.
2. **Confirm release keystore custody.** Two keystores sit in
   `android/app/`. They are gitignored and were not exposed, but they need a
   documented offline backup. Their loss is unrecoverable; their compromise
   defeats update integrity entirely.
3. **Put this project under Git version control.** It currently is not, which
   means no history, no revert path, and no possibility of historical secret
   scanning. This is the single highest-value operational fix.
4. **Install and run a vulnerability scanner** (osv-scanner) and a secret
   scanner (gitleaks) locally, matching what CI already enforces.
5. **Schedule the dependency upgrade** (F-007) as separately tested work.
6. Optionally pin CI actions by commit SHA (F-008).

## 10. Residual risk

Stated plainly, this assessment does **not** establish that the application is
free of vulnerabilities. It establishes what was tested and what was found.

- **iOS is reviewed by source only.** `Info.plist` shows no ATS exceptions and a
  correct Face ID usage string, but no build, entitlement inspection or device
  test was performed. Entitlements and privacy manifest remain unverified.
- **No runtime testing was done.** No emulator, no device, no traffic
  inspection, no instrumentation. Runtime-only defects would not be caught.
- **No remote testing was done or authorized.** The real behaviour of the GitHub
  update endpoint and the Drive integration is unverified.
- **Dependency vulnerabilities are unconfirmed either way** (F-007).
- **No historical secret scan was possible** because there is no Git history.
  Secrets are absent from the current tree and the built binary; nothing can be
  said about the past.
- **F-005 is unverified on-device.** The cache-directory confinement is a
  source-level review conclusion; `Context.cacheDir` resolution should be
  confirmed on a real device alongside the full update flow.
- **The transaction database is not encrypted at rest**, relying on platform
  disk encryption plus the app lock. Reasonable for this threat model, but a
  forensic attacker with an unlocked device reads it.
- **F-010 means a fraction of the widget test suite never executed.**

---

## 2026-08-16 remediation addendum

### Release decision supersession: BLOCK RELEASE

This addendum supersedes the prior conditional decision. The current source has
an unresolved Medium finding that materially affects locally stored financial
records: the Drift database remains plaintext while the SQLCipher migration is
blocked by a broken local Flutter code-generation host. The widget test
`test/features/settings/custom_field_manager_screen_test.dart` also still hangs
beyond the requested timeout, so the full test gate cannot be evidenced.

The custom APK self-updater, its installer permission, app-owned FileProvider,
and native installer channel were removed. Release signing material was removed
from the checkout only after hash-verified private copies were created outside
it. No Git history exists, so historical scanning and a public-tree guarantee
remain impossible until initialization and the supplied verifier are run.

Scans recorded in this pass: offline OSV scan, no known issues; current-tree
Gitleaks, zero findings; TruffleHog detector results were limited to generated
or local virtual-environment artifacts. Remote dynamic testing was not run: no
explicitly authorized non-production host and synthetic credentials were
provided.
