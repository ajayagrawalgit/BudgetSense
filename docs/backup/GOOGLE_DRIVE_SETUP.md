# Google Drive Setup (External Configuration)

Cloud backup needs a Google Cloud OAuth configuration that CANNOT be created
from this repository. This document is the exact checklist. No secrets are ever
committed: a public mobile OAuth client id is configured via platform files; a
client SECRET is never embedded in the app.

## 1. Google Cloud project

1. Create (or reuse) a project at <https://console.cloud.google.com/>.
2. APIs & Services → Library → enable **Google Drive API**.

## 2. OAuth consent screen

1. APIs & Services → OAuth consent screen.
2. User type: External (or Internal for a Workspace-only release).
3. App name, support email, developer contact.
4. Scopes: add **only** `.../auth/drive.file`. Do NOT add `drive`,
   `drive.readonly`, or `drive.metadata`. BudgetSense only needs per-file access
   to files it creates.
5. Add test users while the app is unverified (see step 6).

## 3. Android OAuth clients

You need the SHA-1 of each signing certificate registered against an Android
OAuth client (same package name `com.example.budgetsense` — confirm the actual
`applicationId` in `android/app/build.gradle.kts`).

Get fingerprints:

```bash
# Debug (development)
keytool -list -v -alias androiddebugkey \
  -keystore ~/.android/debug.keystore \
  -storepass android -keypass android

# Release (your production keystore)
keytool -list -v -alias <your-release-alias> \
  -keystore <path-to-release.keystore>
```

For each certificate (debug AND release):
1. APIs & Services → Credentials → Create credentials → OAuth client ID.
2. Application type: Android.
3. Package name + SHA-1 fingerprint.

Register both the debug and the release SHA-1 so sign-in works in development
and production. The release certificate must match the key that signs the
uploaded artifact.

## 4. iOS OAuth client (if shipping iOS)

1. Create an OAuth client ID of type iOS with the app's bundle id.
2. Add the client id and its **reversed** client id URL scheme to
   `ios/Runner/Info.plist` under `CFBundleURLTypes`.
3. Add the GoogleSignIn config as required by the installed `google_sign_in_ios`
   version (see its README for the current keys).

## 5. Build-time configuration

- The `applicationId` is `com.budgetsense.budgetsense`. Register the OAuth
  Android client with THIS package name and your signing SHA-1.
- The current release keystore's SHA-1 (from `budgetsense-upload.jks`) is:
  `51:6C:87:60:5E:13:DB:38:C7:AF:B2:3D:33:3F:3E:1A:D6:13:2B:6E`
  Register this exact fingerprint (colons optional in the console). If you ever
  regenerate the keystore, register the new SHA-1 too.
- Create a **Web application** OAuth client as well and pass its id at build time
  so Drive scope authorization returns a usable access token on Android:
  ```bash
  flutter build apk --release \
    --dart-define=GOOGLE_SERVER_CLIENT_ID=XXXX.apps.googleusercontent.com
  ```
  (Optionally also `--dart-define=GOOGLE_OAUTH_CLIENT_ID=...` for an explicit
  Android/iOS client id.) These are PUBLIC client ids, never secrets.
- Until a matching OAuth client + SHA is registered, tapping "Backup and Sync
  to Cloud" opens the Google sheet and then fails with a clear
  "not set up for this build yet" message. That is the expected pre-setup state.
- Do NOT commit any client secret, `key.properties`, keystore, or token.

## 6. Verification / release

- While unverified, only listed test users can sign in. Add testers on the
  consent screen.
- For public release with a sensitive/restricted scope, complete Google's OAuth
  verification. `drive.file` is a non-sensitive per-file scope, which keeps
  verification lighter than full-Drive scopes, but confirm current Google
  requirements before launch.

## 7. Real-device verification checklist (cannot be done in CI)

- [ ] First-time enable: sign-in, passphrase creation, folder + file created.
- [ ] `BudgetSense_Backup` folder is visible in the user's Drive.
- [ ] Existing-backup reconciliation (import vs overwrite vs cancel).
- [ ] A committed change marks "Waiting to back up" and uploads after debounce.
- [ ] Background upload runs under WorkManager with network available.
- [ ] Restore from Drive on a fresh install using the recovery passphrase.
- [ ] Revoke access in the Google account → app shows "Requires sign-in".
- [ ] Remote conflict (edit from a second device) blocks overwrite.

## 8. Troubleshooting

- `sign_in_failed` / `10:`: SHA-1 or package name mismatch, or the OAuth client
  is missing for this certificate. Re-check step 3 for the exact signing key.
- Silent sign-in returns null: expected when consent was revoked or never
  granted; the user must sign in interactively.
- 403 with "insufficient permissions": the granted scope is missing
  `drive.file`; re-authorize.
- 403 quota/storage: the user's Drive is full; automatic retries stop and the UI
  shows actionable guidance.
- 404 on the backup file: it was deleted/moved in Drive; BudgetSense will not
  silently recreate deleted data without informing the user.

## Security reminders

- OAuth tokens and the cached encryption key live only in secure storage
  (Keystore/Keychain), never in SharedPreferences, logs, source, or snapshots.
- Never commit secrets. A public mobile client id is fine; a client secret is
  not and must never be embedded in a mobile app.
