# Release Checklist - BudgetSense

A reproducible, fail-closed Android release process. Do these in order.

## 0. Prerequisites

- Flutter 3.44.4 (stable), Dart 3.12.x
- JDK 21 (set `JAVA_HOME`)
- Android SDK with build-tools 36.x (for `apksigner`/`aapt` verification)
- A production **upload keystore** available as a gitignored
  `android/key.properties` (+ .jks) OR as CI secrets. Copy
  `android/key.properties.example` to get started.

## 1. Set the version (single source of truth: pubspec)

```yaml
# pubspec.yaml
version: 0.1.0+1        # versionName 0.1.0, versionCode 1
```

Keep `lib/core/constants/app_info.dart` `version` equal to the pubspec version
part. `scripts/release_preflight.sh` fails the release if they diverge.

## 2. Run the full local quality gate

```bash
./scripts/quality_gate.sh
```

This runs: pub get, code generation, generated-code drift check, format check,
analyzer, tests with coverage, the coverage gate (>=70%, no critical file at
0%), and the placeholder/debug-config scan. It must pass with no failures.

## 3. Release preflight

```bash
./scripts/release_preflight.sh 0.1.0
```

Verifies version parity and that no signing material is tracked.

## 4. Clean build

```bash
export JAVA_HOME=/path/to/jdk-21
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build apk --release --build-name=0.1.0 --build-number=1
```

- With a valid `android/key.properties`, the APK is **signed** with your key.
- Without it, the APK is left **unsigned** (never debug-signed).

## 5. Stage and checksum the artifact

```bash
mkdir -p release-artifacts
# Signed:
cp build/app/outputs/flutter-apk/app-release.apk \
  release-artifacts/BudgetSense-0.1-production.apk
# OR unsigned:
cp build/app/outputs/flutter-apk/app-release.apk \
  release-artifacts/BudgetSense-0.1-release-unsigned.apk
./scripts/apk_checksum.sh
```

## 6. Verify the APK

```bash
BT=$ANDROID_HOME/build-tools/36.0.0
"$BT/apksigner" verify --print-certs release-artifacts/BudgetSense-0.1-*.apk
"$BT/aapt" dump badging release-artifacts/BudgetSense-0.1-*.apk | \
  grep -E "package:|application-label:|sdkVersion|targetSdkVersion|native-code"
```

Confirm: package `com.budgetsense.budgetsense`, versionName `0.1.0`,
versionCode `1`, label `BudgetSense`, not debuggable, expected permissions.
Note: the manifest now includes `INTERNET` (and `ACCESS_NETWORK_STATE`) for the
optional Google Drive backup only; no network happens until the user opts in.
Record results in `release-artifacts/BUILD_EVIDENCE.md`.

## Cloud backup release gate

Before advertising Google Drive cloud backup as available, complete the
on-device checklist in `docs/backup/GOOGLE_DRIVE_SETUP.md` (section 7) with real
production OAuth and the release signing key. Until then, treat the cloud
feature as implemented-but-unverified: do NOT claim real-device production OAuth
has been validated.

## 7. Tag and publish (CI)

```bash
git tag v0.1.0
git push origin v0.1.0
```

The `Release` workflow re-runs the full gate, verifies the tag matches pubspec,
signs (if secrets present), builds, checksums, and publishes the GitHub Release
with notes from `CHANGELOG.md`. It never releases from a dirty/mismatched
version and never debug-signs.

## Never

- Commit a keystore, `key.properties`, or signing passwords.
- Reuse the debug keystore for a production artifact.
- Label a debug-signed or unsigned APK as production-signed.
- Weaken a quality/security gate to make a release pass.
