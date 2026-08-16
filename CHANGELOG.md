# Changelog

Notable changes to BudgetSense, loosely following Keep a Changelog.

BudgetSense 0.1 is the first public release, so everything below is the starting
point rather than a list of differences from an earlier version. Entries for
later releases will be added above this one.

## 0.1

The first public release: a calm, offline-first personal budgeting app for
Android, with iOS buildable from source.

### What's in it

- **Transactions** for income, expenses, investments, and transfers, with
  dynamic categories, accounts, payment methods, and user-defined custom fields.
- **Recurring payments and loans** with schedules that roll forward on their own
  and record an expense when you mark one paid.
- **Spending thresholds** with quiet warnings as you approach them.
- **Insights**: monthly trends, top categories, savings and investment rates,
  and a month-end estimate based on the pace so far.
- **Full backup and restore** as a single snapshot file (JSON, CSV, or XML)
  covering every table and setting, including trash and theme choices. Import
  from Paisa is supported.
- **Optional Google Drive backup**, off by default. When you turn it on, the
  snapshot is encrypted on-device with AES-256-GCM (a random data key wrapped by
  PBKDF2-HMAC-SHA256 from your passphrase) and only ciphertext is uploaded, into
  a `BudgetSense_Backup` folder under the narrow `drive.file` OAuth scope.
- **Local reminders** for recurring payments and daily logging, scheduled
  on-device with no server involved.
- **Home-screen widgets** on Android: dashboard, insights, balance, buckets,
  rates, runway, next due, no-spend graph, glance, quick add, and quick actions.
- **App lock** reusing the device biometric or PIN prompt, screenshot blocking
  on by default, and widget figures masked while locked.
- **Themes**: light, dark, true-black AMOLED, and transparent glass, with six
  accent colours and six typefaces, including several handwritten ones.

### Corrections made before this release

These were real defects found and fixed while getting 0.1 ready. They never
shipped to anyone, but they are worth recording because they affected money.

- **Nothing posts itself.** A recurring payment is recorded only when you tap
  "Mark paid". A previous catch-up routine silently created a transaction for
  every period that had come due while the app was closed, so reopening after
  three months could invent three expenses nobody confirmed.
  `RecurrenceService.catchUp` was removed rather than disabled, and replaced by
  `rollScheduleForward`, which only moves the due date.
- **Recurring schedules no longer drift earlier.** A payment due on the 31st
  went 31 Jan, 28 Feb, then stuck on the 28th forever, because February's
  clamped date became the new anchor. Monthly and longer cadences now anchor to
  the intended billing day and recover it as soon as a long enough month
  arrives. The same fix applies to loan EMI dates.
- **Over-precise amounts are rejected instead of rounded.** Typing "10.999" was
  stored as 11.00, inventing money that was never entered and skewing every
  total built on it. `Money.tryParse` now returns null for input carrying more
  decimals than the currency has.
- **Restore is append-only.** It never updates, replaces, or deletes an existing
  local record. The earlier behaviour overwrote records with matching ids and
  replaced all settings, which was a data-loss defect. An `import_ledger` table
  makes restoring the same backup twice a no-op, and id collisions are appended
  as new records with foreign keys rewritten consistently. See
  `docs/backup/RESTORE_CONFLICT_POLICY.md`.
- **Honest release signing.** Release builds no longer fall back to debug
  signing. Without a keystore the APK is left unsigned, so an unsigned build is
  never mistaken for a production one.
- Removed an in-code comment that implied SQLCipher at-rest encryption, which
  the app does not have. The real threat model is written down in
  `SECURITY.md`.

### Project setup

- 336 automated tests with a 70% meaningful-coverage gate.
- Fail-closed CI: formatting, analyzer, generated-code drift, tests and
  coverage, Gitleaks secret scanning, OSV-Scanner, dependency review, and a
  release-build check, plus Dependabot.
- `pubspec.lock` is committed for reproducible builds.
- A snapshot completeness guard fails the build if a new persistent table or
  settings key is added without a backup policy.

### Known limitations

- The SQLite database is not encrypted at rest. It relies on the Android app
  sandbox and your device lock. See `SECURITY.md`.
- R8 code and resource shrinking is off pending an on-device smoke test, so the
  APK is larger than it needs to be.
- Background upload for cloud backup is a no-op. Sync runs in the foreground on
  launch, resume, and manual trigger.
- Google Drive OAuth has been exercised against fakes in tests. Production OAuth
  on real hardware is an external step, tracked in
  `docs/backup/GOOGLE_DRIVE_SETUP.md`.
