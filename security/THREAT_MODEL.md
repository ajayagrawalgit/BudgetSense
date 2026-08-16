# BudgetSense Threat Model

Prepared as part of the security assessment dated 2026-08-16. This document
describes the application as it actually exists in this repository, not an
idealised version of it.

## 1. Application overview

BudgetSense is an offline-first personal finance journal built in Flutter/Dart.
A user records transactions, recurring payments and loans, and the app produces
summaries, insights and reminders. The defining architectural choice is that
the app is local-first: the database lives on the device and the app makes no
network request at all unless the user opts into one of two clearly bounded
features.

| Property | Value |
|---|---|
| Package / bundle id | `com.budgetsense.budgetsense` |
| Public version | 0.1 (versionCode 1) |
| Flutter / Dart | 3.44.4 / 3.12.2 |
| Repository type | Single Flutter application, no monorepo, no flavors |
| Backend owned by this project | None |

## 2. Supported platforms

Android and iOS are the supported targets. There is no `web/`, `macos/`,
`windows/` or `linux/` directory, so the web and desktop sections of a generic
mobile review do not apply. Android is the primary platform: it carries all the
native code (home-screen widgets, haptics, the APK installer bridge, shared
storage access), and it is the only platform with a release build pipeline.

## 3. Primary assets

1. **The transaction database.** Every amount, merchant, note and date the user
   has recorded. This is the crown jewel; it is a complete financial picture.
2. **The cloud backup encryption key material.** The Data Encryption Key (DEK)
   cached in platform secure storage.
3. **The recovery passphrase.** Never persisted, and unrecoverable if lost.
4. **Google OAuth tokens** for the optional Drive backup, held by the
   `google_sign_in` plugin in platform secure storage.
5. **Local backup files** written to shared storage.
6. **The Android release signing key.** Compromise permits shipping a malicious
   update that the in-app updater would accept as genuine.

## 4. Trust boundaries

| Boundary | Description |
|---|---|
| Device storage | App-private storage vs shared storage. Local backups deliberately cross this line. |
| Platform channel | Dart to Kotlin IPC: widgets, haptics, installer, storage permission. |
| Network to GitHub | Update manifest and APK download, when configured. |
| Network to Google Drive | Encrypted backup blobs, only when the user enables it. |
| File import | Backup restore and Paisa import read attacker-supplyable files. |
| Home-screen widgets | Exported Android receivers rendering a data summary. |
| Supply chain | pub.dev packages, Gradle artifacts, GitHub Actions. |

## 5. Data-flow summary

**Normal offline operation.** UI to Riverpod providers to repositories to a
Drift/SQLite database in app-private storage. No network involvement.

**Export.** Transactions to `ExportSchema.row` to CSV or XLSX bytes to a file in
the cache directory to the OS share sheet. The user chooses the destination.

**Local backup.** Whole-app snapshot to JSON/CSV/XML to a file in a top-level
`BudgetSense_Backup` folder in shared storage. Written in plaintext by design so
the user owns a portable copy.

**Cloud backup (opt-in).** Snapshot to AES-256-GCM encryption under a DEK, which
is wrapped by a PBKDF2-HMAC-SHA256 key derived from the recovery passphrase, to
an upload of the encrypted envelope to the user's own Drive. Google receives
only ciphertext.

**Update (sideloaded builds).** GitHub `latest.json` to manifest validation to
APK download with a size ceiling to SHA-256 verification to a FileProvider URI
to the OS package installer, which always requires user confirmation.

## 6. Entry-point inventory

| Entry point | Trust | Notes |
|---|---|---|
| `MainActivity` (exported) | Untrusted | Only reads a launch-action string extra. |
| 11 widget receivers (exported) | Untrusted | Respond to `APPWIDGET_UPDATE`; read-only rendering. |
| `.../widgets` channel | Untrusted | `updateWidgets`, `consumeLaunchAction`, `setScreenSecure`. |
| `.../installer` channel | Untrusted | `canInstall`, `install(path)`. Path now confined to cache dir. |
| `.../storage` channel | Untrusted | Permission query and request only. |
| `.../haptics` channel | Untrusted | Vibration only. |
| Backup restore file picker | Untrusted | Arbitrary user-chosen file. |
| Paisa import file picker | Untrusted | Arbitrary user-chosen file. |
| Update manifest / APK | Untrusted | Remote JSON and binary. |
| Drive backup download | Untrusted | Remote, but authenticated-encrypted. |

Deliberately absent: no deep links, no custom URL schemes, no universal links,
no WebViews, no JavaScript bridges, no push notifications, no FFI, no process
execution. This removes entire vulnerability classes from consideration.

## 7. Attacker models

1. **Remote network attacker.** On-path between the app and GitHub or Google.
   Mitigated by HTTPS with default platform validation, an https-only manifest
   check, and SHA-256 verification of the APK.
2. **Malicious update publisher / compromised GitHub account.** Can serve any
   manifest. This is the most consequential remote model, because its payload
   reaches the package installer. Contained by manifest validation, the size
   ceiling, digest verification, Android's signature-match requirement, and the
   mandatory OS confirmation dialog.
3. **Malicious app on the same device.** Can send intents and broadcasts, and
   read shared storage. Relevant to exported components, the FileProvider, and
   plaintext local backups.
4. **Person with physical access to an unlocked device.** Mitigated by the
   optional app lock and `FLAG_SECURE`.
5. **Forensic attacker with a stolen device.** Depends on platform disk
   encryption plus app lock; the SQLite database itself is not encrypted.
6. **Hostile file supplier.** Sends a crafted backup or Paisa export for the
   user to import.
7. **Supply-chain attacker.** Compromises a dependency or GitHub Action.

## 8. Abuse cases

- A crafted `.bsbak` forces an unbounded PBKDF2 derivation and wedges the app.
  *Addressed this assessment (F-002).*
- A transaction note containing a spreadsheet formula executes when the exported
  CSV is opened by the user or an accountant. *Addressed this assessment (F-001).*
- A manifest `versionName` containing traversal segments writes the downloaded
  APK outside the download directory. *Addressed this assessment (F-003).*
- A malicious app obtains a `content://` URI to the app's database through an
  over-broad FileProvider declaration. *Addressed this assessment (F-004).*
- A crafted path passed over the installer channel hands an arbitrary file to
  the package installer. *Addressed this assessment (F-005).*
- Another app on the device reads the plaintext backup in shared storage.
  *Accepted product trade-off, documented (F-006).*
- A malformed import file crashes the app mid-restore rather than failing
  cleanly. *Partially addressed; snapshot restore plans before writing.*

## 9. Existing security controls

The following were already present before this assessment and were verified:

- AES-256-GCM with a per-payload nonce, PBKDF2-HMAC-SHA256 at 210k iterations,
  envelope metadata bound as AAD, and no hand-rolled cryptography.
- Secure storage (Android Keystore / iOS Keychain) for key material, with
  `encryptedSharedPreferences` enabled on Android.
- `FLAG_SECURE` on by default, blocking screenshots and hiding the app in the
  recent-apps switcher.
- `allowBackup="false"` plus comprehensive `data-extraction-rules`, keeping
  financial data out of cloud backup and device transfer.
- Optional app lock delegating to the device credential, with a 20-second
  re-lock grace period rather than a process-lifetime unlock.
- Release builds are never debug-signed: an absent keystore yields an unsigned
  APK rather than a misleadingly signed one.
- `AppLog` writes nothing in release builds.
- Drift provides parameterized SQL throughout; no string-interpolated queries.
- Update APKs are size-capped and SHA-256 verified before install.
- CI enforces format, analyze, tests, a coverage gate, Gitleaks secret scanning
  and OSV dependency scanning, all fail-closed.

## 10. Assumptions

- The device OS is not rooted or jailbroken.
- Platform disk encryption is enabled and the user has a device lock.
- The developer's GitHub account and signing keystore remain uncompromised.
- Google Drive and GitHub behave per their documented APIs.
- The user chooses a reasonable recovery passphrase (only an 8-character
  minimum is enforced).

## 11. Highest-risk areas

Ranked by consequence, for future review effort:

1. **The in-app update path.** It is the only code that results in executing
   new code. Any weakness here is critical.
2. **Backup import and restore.** Parses untrusted files and writes to the
   database.
3. **The Android release signing key.** Its compromise defeats the update
   integrity model entirely.
4. **Plaintext local backups in shared storage.** The widest-reaching
   at-rest exposure, mitigated only by an OS permission prompt.
5. **The platform channel surface.** IPC input reaching privileged native
   operations.

## 12. Applicable OWASP MASVS categories

| Category | Relevance | Status |
|---|---|---|
| MASVS-STORAGE | High | Secure storage for keys; DB unencrypted; plaintext local backup documented. |
| MASVS-CRYPTO | High | Reviewed; sound. Iteration bounds added. |
| MASVS-AUTH | Low | No user accounts. Device-credential app lock only. |
| MASVS-NETWORK | Medium | HTTPS only, no TLS bypass, no cleartext. |
| MASVS-PLATFORM | High | Exported components, FileProvider, channels reviewed and tightened. |
| MASVS-CODE | High | Update integrity, input validation, dependency currency. |
| MASVS-RESILIENCE | Low | Not a DRM/anti-tamper product. R8 disabled by choice. |
| MASVS-PRIVACY | High | No analytics, no crash reporting, no tracking. Verified. |

## 13. Items requiring verification outside this repository

1. Google Cloud Console OAuth client restrictions (package name plus signing
   certificate) for the Drive integration.
2. GitHub repository settings: branch protection, release-publishing rights,
   and the secrecy of the keystore secrets.
3. Offline custody of the release keystore and its passwords.
4. On-device verification of the update install flow, the biometric app lock,
   and the widget bridge, none of which can run in CI.
