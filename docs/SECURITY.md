# Security Policy

## Supported versions

| Version | Supported |
|---|---|
| 0.1.x | Yes (current) |
| < 0.1 | No (pre-release) |

## Reporting a vulnerability

Please report security issues privately to the maintainer rather than opening a
public issue. Include reproduction steps and impact. You can expect an initial
acknowledgement within a few business days. Do not disclose publicly until a
fix is available.

## Security architecture (offline-first, optional cloud backup)

BudgetSense is a local-first, single-user personal finance journal. All data is
stored on-device in a private SQLite database. There is no BudgetSense backend
and no BudgetSense account system. The app makes no network request until the
user explicitly enables the optional Google Drive backup; this is enforced in
code (`CloudSyncController`), so with cloud backup off the app behaves as if it
had no network access.

- Persistence: Drift/SQLite in the app's private sandbox directory.
- Referential integrity: SQLite foreign keys are enforced on every connection.
- App lock: optional device biometric/credential prompt via `local_auth`. No
  custom cryptography; no raw biometric data is stored.
- Local backups: user-initiated exports (JSON/CSV/XML) that the user controls.
- Cloud backup: opt-in, client-side encrypted (AES-256-GCM) before upload to
  the user's own Google Drive under the narrow `drive.file` scope.

## Cloud backup security

- Every snapshot is encrypted on-device with AES-256-GCM using a random
  data-encryption key (DEK). The DEK is wrapped by a key derived from the user's
  recovery passphrase via PBKDF2-HMAC-SHA256; salt and KDF parameters live in
  the encrypted envelope. Critical envelope metadata is authenticated as AAD.
- Only ciphertext is uploaded. Google Drive never receives plaintext financial
  data.
- OAuth tokens and the cached DEK are kept only in Android Keystore / iOS
  Keychain via `flutter_secure_storage`. They are never written to
  SharedPreferences, source, logs, or the snapshot.
- The recovery passphrase is never uploaded or logged; it is used locally only
  for key derivation. Losing it means the cloud backup cannot be decrypted, by
  design.
- The OAuth scope is `drive.file` only (per-file access), never full-Drive.

## Offline-first threat model

In scope:
- A malicious app on the same device attempting to read BudgetSense data ->
  mitigated by the OS app-sandbox and (on modern devices) file-based/full-disk
  encryption tied to the device lock.
- Accidental data exposure via backups -> mitigated by making export explicit
  and user-directed, with privacy guidance in `docs/PRIVACY.md`.
- Data-integrity corruption -> mitigated by enforced foreign keys, transactional
  multi-step writes, and idempotent, forward-only migrations.

Out of scope / documented limitations:
- **At-rest application-layer encryption (SQLCipher) is NOT implemented in
  0.1.** The database file is plain SQLite. Confidentiality relies on the OS
  sandbox and device disk encryption. On a rooted/jailbroken device, or one
  without a device lock, the data is readable. See "Local-data risks".
- A physically present attacker with an unlocked device and file access.

## Local-data risks

Because the data is unencrypted at the application layer:
- Users should keep a device lock (PIN/biometric) enabled so OS disk encryption
  protects the file at rest.
- Exported backup files are unencrypted and should be stored somewhere the user
  trusts. Treat them as sensitive financial documents.

**SQLCipher upgrade path (recommended for a future release):** switch
`connection.dart` to an encrypted SQLite build (e.g. sqlcipher_flutter_libs)
with the key stored only in platform-secure storage (Android Keystore / iOS
Keychain), never hard-coded. This is a high-touch migration (re-key existing
databases, recovery story) and is intentionally deferred, not silently claimed
as done.

## Backup / export risks

- Exports contain your full financial history in clear text.
- Import replaces/merges data; corrupt, oversized, or wrong-version files are
  rejected or handled safely rather than corrupting the live database.

## Authentication limitations

- App lock depends on the device's biometric/credential hardware and OS
  behaviour. Edge cases (lockout, cancellation, process death, route
  restoration) are handled via the OS prompt; deeper hardening with on-device
  tests is planned.

## Build and signing security

- No keystores, passwords, or `key.properties` are committed (enforced by
  `.gitignore` + Gitleaks + a preflight check).
- Release builds never fall back to debug signing; without a real key the build
  is left unsigned and labelled as such.
- Signing secrets are supplied only via CI secret storage or a local,
  gitignored `key.properties`.

## Dependency scanning

- OSV-Scanner runs on every PR/push and weekly against the committed
  `pubspec.lock`.
- Dependency Review blocks PRs that add vulnerable or badly-licensed deps.
- Dependabot proposes updates for GitHub Actions, pub, and Gradle.

## Security update expectations

Security-relevant dependency updates are triaged as they are surfaced by the
scanners above. Fixes ship in patch releases of the supported version line.
