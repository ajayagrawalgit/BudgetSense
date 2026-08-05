<p align="center">
  <img src="docs/budgetsense_logo.png" width="168" alt="BudgetSense logo: a hand-inked ensō brush circle with a single clay dot" />
</p>

<h1 align="center">BudgetSense</h1>

<p align="center"><strong>Money, minus the anxiety.</strong></p>

<p align="center">
  A quiet, private money journal for your phone. It feels like writing in a
  paper notebook, not logging into a bank.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-Android%20%7C%20iOS-262219?style=flat-square" alt="platform" />
  <img src="https://img.shields.io/badge/100%25-offline-6E8B6A?style=flat-square" alt="offline" />
  <img src="https://img.shields.io/badge/data-stays%20on%20your%20phone-6E8B6A?style=flat-square" alt="privacy" />
  <img src="https://img.shields.io/badge/no-ads%20%C2%B7%20no%20accounts%20%C2%B7%20no%20tracking-B07C5E?style=flat-square" alt="no tracking" />
</p>

<p align="center">
  <!-- DOWNLOAD:START -->
  <a href="../../releases/latest"><img src="https://img.shields.io/badge/%E2%AC%87%EF%B8%8F%20Download%20for%20Android-free%20forever-6E8B6A?style=for-the-badge&logo=android&logoColor=white" alt="Download BudgetSense for Android, free" /></a>
  <!-- DOWNLOAD:END -->
</p>

<p align="center"><em>Free. No account, no ads, no tracking. Works fully offline.</em></p>

<p align="center">
  <a href="docs/">Docs</a>
  &nbsp;&middot;&nbsp;
  <a href="docs/ARCHITECTURE.md">Architecture</a>
  &nbsp;&middot;&nbsp;
  <a href="docs/SECURITY.md">Security</a>
</p>

---

## Get BudgetSense (about 2 minutes)

BudgetSense is a free Android app. It is not on the Play Store yet, so you
install it directly from here. The whole thing, done on your phone:

1. **Tap the green "Download for Android" button above.** It opens the download
   page.
2. **Tap the file that ends in `.apk`** (you will see it under a heading called
   "Assets"). It downloads in a few seconds.
3. **Open it** from the download notification, or from your Files app.
4. Android may say *"For your security, your phone can't install unknown apps
   from this source."* That is normal for any app installed outside the Play
   Store. Tap **Settings**, switch on **Allow from this source**, tap **Back**,
   then tap **Install**.
5. Open BudgetSense. That is it. There is nothing to sign up for.

> **Is this safe?** Yes. Everything you enter stays on your own phone. No
> account, no ads, no tracking, and the complete source code is right here in
> this repository for anyone to read. The Android warning shows up for every
> app installed outside the Play Store; it does not mean anything is wrong.

**On an iPhone?** iOS builds run from source, but there is no App Store download
yet. If you are comfortable with developer tools, see [the docs](docs/) to build
it yourself.

## The short version

I got tired of finance apps that treat you like a suspect. They flash red
numbers, guilt-trip you with notifications, push upsells, and quietly ship your
spending habits off to who-knows-where.

BudgetSense is the calm opposite. It's a warm, paper-textured place to jot down
where your money went, glance at the shape of your month, and then go live your
life. Nothing leaves your phone. There's nothing to sign up for. There are no
ads and no one watching.

That's really the whole pitch. If that sounds like your kind of thing, grab the
APK below.

## A few things I'm proud of

**It's actually private.** Your data lives in one file on your phone. No cloud,
no account, no analytics. I can't see your numbers, and neither can anyone else.

**It stays calm.** Warm cream paper, soft ink-brown text, gentle notes instead
of angry red warnings. Your balance is just a number. It isn't a scolding.

**Peeking is safe.** Tap the eye and your income, spending, and investments blur
out instantly. Handy when you want to check your balance on a packed train and
the person next to you is a little too curious.

**Logging is quick.** Type "coffee" and it already guessed the coffee icon. Hit
save and you're done. There's a library of 150-plus icons, and if the guess is
wrong you just pick a better one.

**Mistakes are undoable.** Swipe to delete drops things into a Trash. You get a
ten-second undo, and even after that you can dig anything back out from Settings.

**Your data comes with you.** One tap makes a single backup file (JSON, CSV, or
XML) with everything in it, right down to your trash and your theme. Restoring
it on a new phone takes seconds.

## What you get

- A dashboard that keeps quiet. Your balance sits up top; the rest folds away
  into tidy sections you open only when you feel like it.
- One little sheet for logging income, expenses, investments, and transfers,
  with a smart icon guess as you type.
- Recurring bills and loans that mostly look after themselves. Mark one paid and
  BudgetSense writes the transaction and moves the schedule along.
- Gentle insights: spending trends, your top categories, savings and investment
  rates, and a soft month-end estimate. Guidance, never nagging.
- Themes to suit your eyes (light, dark, true-black AMOLED, frosted glass), six
  warm accent colors, six typefaces including some lovely handwritten ones, and
  five launcher icons.
- A proper lock. It reuses your phone's fingerprint, face, or PIN, blocks
  screenshots by default, and hides every figure on home-screen widgets while
  it's locked.
- Home-screen widgets on Android: your dashboard, your insights, or a one-tap
  quick add, right where you can see them.

## Getting it

<!-- GETTING:START -->
1. Download the latest APK from the [Releases](../../releases) page (BudgetSense 0.1).
<!-- GETTING:END -->
2. Copy it over to your Android phone and tap to install. You might have to okay
   "install from this source" the first time.
3. Open it, say hi, and start jotting. No sign-up, no setup wizard. That's it.

Want to build it yourself? The [developer docs](docs/SPEC.md#21-build-and-run)
walk you through it.

## The look

The whole app is built around one small mark: an *ensō*, the hand-inked brush
circle, with a single clay dot where the brush lifts off. It feels calm and
whole, and it hints at a coin without ever looking like a bank logo.

| | |
|---|---|
| **Paper** | warm cream `#F3ECDE`, never a harsh white |
| **Ink** | deep espresso `#262219`, never pure black |
| **Clay** | one warm accent, `#B07C5E` |

If you care about the details, the full visual system is in
[DESIGN.md](docs/DESIGN.md).

## About your privacy, plainly

- Everything sits in a local database on your phone. Nothing is uploaded, because
  there are no servers to upload to.
- No accounts to make, and nothing tracking what you tap.
- App lock borrows your device's own unlock, so BudgetSense never keeps a PIN of
  its own. Your backup file stays put unless you decide to share it.

## For the curious (and the developers)

The technical writing all lives in [`docs/`](docs/):

- **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** is the map: how the layers fit
  together, how data moves, and what the database looks like, with diagrams.
- **[SPEC.md](docs/SPEC.md)** is the deep, rebuild-it-from-scratch specification.
- **[DESIGN.md](docs/DESIGN.md)** covers the visual system: color, type, spacing,
  motion, and components.

Under the hood it's Flutter (one codebase for Android and iOS), a pure and
well-tested logic core, Drift over SQLite for storage, and Riverpod holding it
together. Offline-first, private by default, and set up so cloud sync could be
added later without tearing things apart.

## Build, test, and release

**Supported platforms:** Android (production target; universal APK, minSdk 24,
targetSdk 36) and iOS (supported, with fewer platform automations; home-screen
widgets are Android-only).

**Prerequisites:** Flutter 3.44.4 (stable), Dart 3.12.x, JDK 21
(`JAVA_HOME` set), and the Android SDK (build-tools 36.x) for building/verifying
APKs.

```bash
# Setup
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # generates *.g.dart

# Quality (also bundled as ./scripts/quality_gate.sh)
dart format .
flutter analyze
flutter test --concurrency=1
flutter test --coverage --concurrency=1
python3 tool/coverage_report.py --threshold 70              # coverage gate

# Debug build / run
flutter run

# Release build (version comes from pubspec: 0.1.0+1)
export JAVA_HOME=/path/to/jdk-21
flutter build apk --release --build-name=0.1.0 --build-number=1
```

**Signing:** release builds sign with a real key only when a gitignored
`android/key.properties` (+ keystore) or CI signing secrets are present;
otherwise the APK is left unsigned (never debug-signed). Copy
`android/key.properties.example` to `android/key.properties` to set up your own
key, and see [docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md).

**Artifacts:** `flutter build apk` writes to
`build/app/outputs/flutter-apk/`. Release binaries and checksums are published
on the GitHub Releases page, not committed to the repository.

**Backup/restore:** full on-device snapshots (JSON/CSV/XML) of all data and
settings; see [docs/DATA_RECOVERY.md](docs/DATA_RECOVERY.md).

**Version:** BudgetSense 0.1 (`0.1.0+1`).

**Known limitations:** no app-layer database encryption yet (see
[docs/SECURITY.md](docs/SECURITY.md)); the 0.1 APK is unsigned pending an
organization keystore; R8 shrinking is disabled pending an on-device smoke test.

## Credits

Made by **Ajay Agrawal**.

- GitHub: [@ajayagrawalgit](https://www.github.com/ajayagrawalgit)
- LinkedIn: [theajayagrawal](https://www.linkedin.com/in/theajayagrawal)

## License

BudgetSense is free software, released under the GNU General Public License v3.0.
You can redistribute it and modify it under the terms of that license, and it
comes with no warranty. See the [LICENSE](LICENSE) file for the full text.

Copyright (c) 2026 Ajay Agrawal.
