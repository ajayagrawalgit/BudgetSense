# Sanitized Evidence Summary

Redacted artifacts from the 2026-08-16 assessment. No secrets, credentials,
private keys, full binary string dumps or personal data are stored here.

## Release APK

```
Path:  build/app/outputs/flutter-apk/app-release.apk
Size:  85.1 MB
Build: flutter build apk --release  (exit 0, JDK 21)
```

## Signing verification (apksigner 37.0.0)

```
Verified using v1 scheme (JAR signing):            false
Verified using v2 scheme (APK Signature Scheme v2): true
Verified using v3 scheme:                          false

V2 Signer certificate DN:
  CN=BudgetSense, OU=Mobile, O=BudgetSense, L=Bangalore, ST=Karnataka, C=IN
V2 Signer certificate SHA-256 digest: b418f347259f...<redacted>
```

Signed with the genuine release certificate, **not** the Android debug key. The
absent v1 block is expected for a modern `minSdk`, not an unsigned build.

## Merged release manifest

```
android:allowBackup="false"
android:debuggable            -> ABSENT (correct)
android:usesCleartextTraffic  -> ABSENT (correct)
networkSecurityConfig         -> ABSENT (platform defaults, correct)
exported="false" x12   exported="true" x14
```

### Exported components (all 14 reviewed and justified)

```
activity  MainActivity                                  perm=None
service   com.google.android.gms...RevocationBoundService
                                perm=...permission.REVOCATION_NOTIFICATION
receiver  DashboardWidgetProvider ... GlanceWidgetProvider  (11 total, perm=None)
receiver  androidx.profileinstaller.ProfileInstallReceiver
                                perm=android.permission.DUMP
```

Widget receivers respond to `APPWIDGET_UPDATE` and render a read-only summary;
all their PendingIntents use `FLAG_IMMUTABLE`.

### Permissions

```
ACCESS_NETWORK_STATE      INTERNET
MANAGE_EXTERNAL_STORAGE   POST_NOTIFICATIONS
RECEIVE_BOOT_COMPLETED    REQUEST_INSTALL_PACKAGES
USE_BIOMETRIC             USE_FINGERPRINT
VIBRATE                   <app>.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION
```

Each maps to a real feature. `REQUEST_INSTALL_PACKAGES` and
`MANAGE_EXTERNAL_STORAGE` are the two broad ones: the in-app updater and the
user-facing local backup folder respectively.

### FileProvider paths, decoded from the built APK (F-004 fix verified)

```
$ aapt2 dump xmltree app-release.apk --file res/zz.xml
  E: paths
      E: cache-path
        A: name="update_cache"
        A: path="."
```

Only `cache-path` remains. The previous `files-path path="."`, which covered the
directory holding the transaction database, is gone.

## Secret sweep of the built APK

```
assets/flutter_assets/assets/  -> branding, fonts  (no config, no .env)
find -name "*.env" -o -name "*secret*" -o -name "google-services*"  -> none

Patterns searched across assets/ and classes*.dex:
  AIza[0-9A-Za-z_-]{35}   ya29\.        AKIA[0-9A-Z]{16}
  ghp_[0-9A-Za-z]{36}     sk_live_      -----BEGIN ... PRIVATE KEY
  eyJ...\....\....        (JWT)

Result: one match in classes4.dex -> the literal string "-----BEGIN " with no
key body. A PEM parser format string. CONFIRMED FALSE POSITIVE.
```

## Source secret sweep

```
Scanned: lib/ android/app/src/ ios/Runner/ test/ tool/ scripts/ .github/
High-signal credential patterns:        no matches
password/secret/apiKey/token literals:  no matches
```

## Static analysis and tests

```
dart format --output=none --set-exit-if-changed .   212 files, 0 changed
flutter analyze                                     No issues found!
flutter test core domain data app security widget   363 passed
flutter test test/security/                         22 passed
scripts/security_gate.sh                            10/10 passed
```

Gate fail-behaviour verified: temporarily reintroducing `files-path` into
`provider_paths.xml` produced
`FAIL: provider_paths.xml exposes more than the cache directory` and a non-zero
exit. File restored immediately afterwards.

## Not collected

No network captures (no dynamic testing performed), no iOS artifacts (no Xcode
on host), no dependency or secret scanner output (tools not installed), no Git
history analysis (project is not under version control).
