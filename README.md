<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/assets/brand/budgetsense-logo-inverse-on-dark.png" />
  <source media="(prefers-color-scheme: light)" srcset="docs/assets/brand/budgetsense-logo-primary-on-light.png" />
  <img src="docs/budgetsense_logo.png" width="160" alt="BudgetSense logo, an ensō style hand-inked brush circle with a terracotta seal" />
</picture>

# BudgetSense

**Money, minus the anxiety.**

A quiet money journal for people who like keeping track, but hate noisy apps.

<img src="docs/assets/brand/budgetsense-underline-terracotta.webp" width="220" alt="" />

<br />

<a href="https://github.com/ajayagrawalgit/BudgetSense/releases/latest/download/BudgetSense.apk">
  <img src="https://img.shields.io/badge/%E2%AC%87%EF%B8%8F%20Download%20for%20Android-BudgetSense%200.1-B07C5E?style=for-the-badge&logo=android&logoColor=white" alt="Download BudgetSense 0.1 for Android" />
</a>

<br />
<br />

<img src="https://img.shields.io/badge/free-forever-6E8B6A?style=flat-square" alt="Free forever" />
<img src="https://img.shields.io/badge/no%20ads%20%C2%B7%20no%20tracking-5A4A3C?style=flat-square" alt="No ads and no tracking" />
<img src="https://img.shields.io/badge/offline-first-262219?style=flat-square" alt="Offline first" />

<br />

<sub>
  <a href="https://ajayagrawalgit.github.io/BudgetSense/">Website</a>
  &nbsp;·&nbsp;
  <a href="PRIVACY.md">Privacy</a>
  &nbsp;·&nbsp;
  <a href="SECURITY.md">Security</a>
  &nbsp;·&nbsp;
  <a href="CHANGELOG.md">Changelog</a>
</sub>

</div>

## Hello

You know that end-of-month feeling where money is gone, and you are genuinely not sure where it leaked out.

BudgetSense is for that.

It is basically a notebook for your money, but one that stays tidy for you. You open it, log what came in and what went out, and close it. A few weeks later, you are no longer guessing. You can actually see the shape of your month.

If you already note down expenses, track your rent, SIPs, EMIs, subscriptions, or loan payments somewhere, this app fits right into that habit.

## What it is good at

**Fast daily logging**
- Income, expense, investment, transfer
- Categories, accounts, payment methods
- Quick add flow that does not feel like form-filling

**Recurring life stuff**
- Rent, subscriptions, SIPs, EMIs
- Payment schedules that move forward as you record
- Loan tracking with repayment progress

**Calm visibility**
- Monthly trends and category view
- Useful snapshots without dashboard chaos
- Widgets for quick glance and quick add

**Data ownership**
- Local-first by default
- Export and restore in JSON, CSV, XML
- Optional encrypted Google Drive backup

## Install on Android

1. Open [latest APK](https://github.com/ajayagrawalgit/BudgetSense/releases/latest/download/BudgetSense.apk)
2. Download `BudgetSense.apk`
3. Open it on your phone
4. If Android asks, allow installs from this source
5. Install and launch

If you want to verify checksum before install, use [docs/getting-started/verify.md](docs/getting-started/verify.md).

## Privacy in plain language

BudgetSense is a budgeting and organisation tool. It is not a bank, not financial advice, and not a promise of savings.

- Using BudgetSense is optional
- You can stop using it any time
- You remain responsible for your own money decisions
- No financial result is guaranteed

By default, your data stays on your device. Optional cloud backup encrypts the backup file before upload.

Read the full policy in [PRIVACY.md](PRIVACY.md).

## Release identity

This public release line is **BudgetSense 0.1**.

- App name: `BudgetSense`
- Version shown to users: `0.1`
- Android package: `com.budgetsense.budgetsense`

## Documentation

- Product docs: [docs/](docs/)
- Architecture: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- Data recovery: [docs/DATA_RECOVERY.md](docs/DATA_RECOVERY.md)
- Contributing: [CONTRIBUTING.md](CONTRIBUTING.md)
- Security policy: [SECURITY.md](SECURITY.md)
- Terms: [TERMS_OF_SERVICE.md](TERMS_OF_SERVICE.md)

## Build locally

Prerequisites:
- Flutter 3.44.4
- Dart 3.12.x
- Android SDK
- JDK 21

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

Quality checks:

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --concurrency=1
```

## Contributing and support

Bug reports, feature ideas, and PRs are welcome.

- Start with [CONTRIBUTING.md](CONTRIBUTING.md)
- For security issues, follow [SECURITY.md](SECURITY.md)

## License

GNU GPL v3.0, see [LICENSE](LICENSE).
