# Release Security Checklist

Status as of the 2026-08-16 assessment. `[x]` verified with evidence, `[ ]` not
verified. An unchecked box is a statement that something was *not tested*, not a
claim that it failed.

## Secrets and signing

- [x] No secret in source (`lib/`, `android/`, `ios/`, `test/`, `tool/`, `scripts/`, `.github/`)
- [x] No secret in the built release APK (assets, resources, dex swept)
- [x] No `.env`, `google-services.json` or service-account file packaged
- [x] Keystores and `key.properties` are gitignored and untracked
- [x] Release APK signed with the release certificate, not the debug key
- [x] Gradle falls back to unsigned, never debug-signed, when no keystore exists
- [ ] Secret scan of Git history — **impossible, project is not under Git**
- [ ] Release keystore offline backup confirmed — **external action**

## Dependencies and supply chain

- [x] All Dart dependencies resolve from pub.dev
- [x] No Git, path or override dependencies in `pubspec.yaml`
- [x] Lockfile present and committed
- [ ] Automated vulnerability scan — **osv-scanner not installed locally** (CI runs it)
- [ ] Dependencies current — **many majors behind, one EOL (F-007, deferred)**
- [ ] CI actions pinned by commit SHA — **pinned by tag (F-008)**

## Code quality gates

- [x] `dart format --set-exit-if-changed` passes (212 files)
- [x] `flutter analyze` passes with no issues
- [x] Unit and widget tests pass (516 tests, `flutter test --concurrency=1`, "All tests passed!")
- [x] Security regression tests pass (22)
- [x] `scripts/security_gate.sh` passes, and was verified to fail when a control is removed
- [x] Full `test/features/` suite — **F-010 fixed**, the Drift teardown hang is resolved
- [ ] Integration tests — **none exist**

## Builds

- [x] Android release APK builds (exit 0, 85.1 MB)
- [ ] iOS release build — **no Xcode on host**
- [ ] Web release build — **not applicable, no web target**
- [ ] Desktop builds — **not applicable**

## Android configuration

- [x] Merged release manifest inspected
- [x] No `android:debuggable`
- [x] `android:usesCleartextTraffic` not enabled
- [x] `allowBackup="false"` with comprehensive data-extraction rules
- [x] All 14 exported components reviewed and justified
- [x] Widget PendingIntents use `FLAG_IMMUTABLE`
- [x] FileProvider scoped to cache directory only (F-004 fixed, verified in binary)
- [x] Installer channel path confined to cache directory (F-005 fixed)
- [x] Permissions reviewed; each maps to a real feature
- [ ] On-device verification of the update install flow — **external action**

## iOS configuration

- [x] `Info.plist` reviewed: no ATS exceptions, Face ID usage string present
- [x] No custom URL schemes, no associated domains
- [ ] Entitlements inspected — **no macOS build host**
- [ ] Privacy manifest verified — **no macOS build host**
- [ ] `get-task-allow` absent from release — **no macOS build host**

## Network and transport

- [x] No certificate validation bypass anywhere in `lib/`
- [x] No cleartext `http://` endpoint in `lib/`
- [x] Update manifest and APK URLs enforced https with real URI parsing (F-003 fixed)
- [x] No tokens in URLs
- [ ] Live traffic inspection — **not run, not authorized**

## Storage and cryptography

- [x] Key material in platform secure storage (Keystore / Keychain)
- [x] AES-256-GCM with per-payload nonces and AAD-bound metadata
- [x] PBKDF2-HMAC-SHA256 at 210k iterations, now bounded on read and write (F-002 fixed)
- [x] Recovery passphrase never persisted
- [x] No home-rolled cryptography
- [x] Malformed backup files fail as typed errors, not crashes (F-002 fixed)
- [x] Plaintext local backup behaviour documented and accepted (F-006)
- [ ] Transaction database encrypted at rest — **no, relies on platform disk encryption**

## Input validation

- [x] Export escapes spreadsheet formula injection (F-001 fixed)
- [x] Update manifest fields strictly validated (F-003 fixed)
- [x] SQL parameterized throughout via Drift; `customStatement` uses only hardcoded strings
- [x] Backup restore validates a BudgetSense marker before touching data
- [x] Paisa import is strictly append-only (`insertOrIgnore`)

## Attack surface not present

- [x] No WebView, no JavaScript bridge
- [x] No deep links, no custom URL schemes, no universal links
- [x] No FFI, no process execution
- [x] No push notifications

## Logging and privacy

- [x] `AppLog` disabled in release (`!kDebugMode` early return)
- [x] No stray `print` / `debugPrint`
- [x] No analytics SDK, no crash reporter, no tracking
- [x] Google Drive scope limited to `drive.file`, no embedded client secret
- [x] `FLAG_SECURE` on by default; optional app lock with re-lock grace

## Backend

- [x] Not applicable — no backend owned by this project, no server-side
      authorization surface, so no `BACKEND_SECURITY_ACTIONS.md` was needed

## Dynamic testing

- [ ] Emulator or device testing — **not run**
- [ ] Authorized staging testing — **not authorized, env vars unset**
- [ ] Runtime instrumentation — **not run**

## Sign-off

- [x] No Critical or High vulnerability open
- [x] All five Medium findings fixed and verified
- [x] Residual risk documented in `SECURITY_ASSESSMENT.md` section 10
- [ ] Residual-risk approval by the release owner — **pending**
