# In-App Updates (Sideloaded / Non-Play Builds)

BudgetSense can update itself without the Play Store. Because Android does not
allow a sideloaded app to replace itself silently, the flow is:

1. On launch (and via a manual check) the app quietly reads a small `latest.json`
   from your GitHub Releases.
2. If a newer `versionCode` exists, a **gentle, dismissible banner** appears on
   the dashboard. It never blocks anything and the user can tap "Maybe later".
3. On "Update now": the app downloads the APK, **verifies its SHA-256**, then
   hands it to Android's installer. The user confirms in the OS dialog.

Nothing installs silently, and a failed/tampered download is discarded without
touching the installed app.

## The one hard rule

Every update APK **must be signed with the same keystore** as the installed
build (`android/app/budgetsense-upload.jks`). A different key makes Android
reject the update with "signatures do not match". Keep and reuse that keystore.

## One-time setup

Point the app at your repo by building with the repo slug defined:

```bash
flutter build apk --release \
  --dart-define=UPDATE_REPO_SLUG=YOUR_GH_USER/BudgetSense
```

If you omit `UPDATE_REPO_SLUG`, the update feature stays dormant (no checks, no
banner, no crashes). You can also bake it into your release script.

## Publishing an update (each new version)

1. Bump the version in `pubspec.yaml`, e.g. `version: 0.2.0+2`. The `+2` is the
   `versionCode` and MUST increase every release (it is what the app compares).
2. Build the signed APK:
   ```bash
   flutter build apk --release --dart-define=UPDATE_REPO_SLUG=YOUR_GH_USER/BudgetSense
   ```
3. Get its SHA-256:
   ```bash
   shasum -a 256 build/app/outputs/flutter-apk/app-release.apk
   ```
4. Rename the APK to a **stable** asset name (so the download URL never changes):
   `BudgetSense-release.apk`.
5. Create a **GitHub Release** (tag e.g. `v0.2.0`) and upload TWO assets:
   - `BudgetSense-release.apk`
   - `latest.json` (below)
6. Fill `latest.json`:
   ```json
   {
     "versionCode": 2,
     "versionName": "0.2.0",
     "apkUrl": "https://github.com/YOUR_GH_USER/BudgetSense/releases/latest/download/BudgetSense-release.apk",
     "sha256": "PASTE_THE_SHA256_FROM_STEP_3",
     "notes": "What changed in this version.",
     "mandatory": false
   }
   ```

That's it. Existing installs will see the banner on their next launch.

### Why the "latest/download" URLs

GitHub gives every release a stable alias:
`https://github.com/<slug>/releases/latest/download/<asset>`
always points at the newest release's asset. So the app's manifest URL and the
APK URL never need to change between versions.

## Field reference (`latest.json`)

| Field | Type | Required | Meaning |
|---|---|---|---|
| `versionCode` | int | yes | Must be greater than the installed build's versionCode |
| `versionName` | string | yes | Shown to the user (e.g. "0.2.0") |
| `apkUrl` | https string | yes | Direct download of the signed APK |
| `sha256` | 64 hex chars | yes | Verified before install; mismatch aborts safely |
| `notes` | string | no | Short "what's new" line |
| `mandatory` | bool | no | Advisory only; the app still never forces |

## Safety properties (enforced in code + tests)

- Update checks never throw or disrupt the app (offline is fine).
- A dismissed version is remembered and not re-nagged.
- The APK is size-capped and SHA-256-verified before any install.
- A corrupt/tampered download is deleted and never installed.
- The install still requires the user's OS-level confirmation.

## Limitations

- Fully-silent background updates are not possible for sideloaded apps by
  Android design. This is "auto-check + one confirmation tap".
- The user may need to grant "install unknown apps" once; the app routes them to
  that setting and they retry.
- iOS is not supported for this flow (no sideload-install path); the feature is
  Android-only.
