# Privacy Policy

**App:** BudgetSense
**Publisher / data controller:** Ajay Agrawal (an individual developer)
**Effective date:** 5 August 2026
**Last updated:** 5 August 2026

> Plain-language summary (this is a convenience, the full text below governs):
> BudgetSense is offline-first. Your financial data stays on your device. There
> is no BudgetSense account, no server, no analytics, no ads, and no tracking.
> The only time anything leaves your phone is if you deliberately export a file
> yourself, or you deliberately turn on the optional Google Drive backup, and in
> that case your data is encrypted on your device before it is uploaded.

This Privacy Policy explains what BudgetSense does and does not do with your
information. Please read it alongside the [Terms of Service](TERMS_OF_SERVICE.md)
and the [Security Policy](SECURITY.md).

## 1. Who is responsible

BudgetSense is developed and published by Ajay Agrawal as an individual. Because
the app is offline-first and there is no BudgetSense server, the developer does
not receive, store, or have any access to your financial data. For the optional
Google Drive backup, you are storing your own encrypted data in your own Google
account, so you remain in control of it.

## 2. The short version of what we collect

Nothing is collected by us. There is no analytics SDK, no crash-reporting
service, no advertising identifier, and no BudgetSense account system. The app
never sends your data to any BudgetSense server, because there isn't one.

The Android app declares the `INTERNET` permission solely for the optional
Google Drive backup. No network request is made until you explicitly enable
cloud backup and complete setup. This is enforced in code, not just by policy.
With cloud backup off, BudgetSense behaves exactly as an offline app.

## 3. Information stored locally on your device only

BudgetSense stores the following inside a private database in the app's own
sandbox on your device:

- Your transactions, categories, accounts, payment methods, recurring payments,
  loans, custom fields, thresholds, budgets, and notification preferences.
- Your settings and profile (for example: display name, theme, accent color,
  font, month-start day).

This information is created and controlled entirely by you. It is not
transmitted to the developer or to any third party unless you take a deliberate
action to export or back it up.

## 4. Information we never collect

- No personal data is transmitted off-device by default.
- No background telemetry, usage tracking, or remote logging.
- No financial values or personal descriptions are written to any remote system
  operated by the developer (there is no such system).
- No advertising identifiers and no sale of personal information. We do not sell
  or rent your data to anyone, ever.

## 5. Google user data and the optional cloud backup

The cloud backup feature is off by default and is entirely opt-in. If you choose
to turn on "Backup and Sync to Cloud":

- You sign in with a Google account that you choose, and you grant only the
  `drive.file` scope. Under this scope, BudgetSense can only see and manage
  files that BudgetSense itself creates. It cannot read the rest of your Google
  Drive, your other files, your email, your contacts, or your photos.
- BudgetSense creates or reuses one folder named `BudgetSense_Backup` and one
  encrypted backup file inside the Google account you selected.
- The data placed in that file is the same snapshot as a local backup
  (transactions, categories, accounts, payment methods, recurring payments,
  loans, custom fields, thresholds, budgets, and your preferences or profile).
  It is **encrypted on your device before it is uploaded** using AES-256-GCM.
  Google Drive only ever receives an encrypted blob.
- You set a **recovery passphrase**. It is required to restore your backup after
  reinstalling the app or on another device. The passphrase is used only on your
  device to derive an encryption key. It is never uploaded, never logged, and
  the developer cannot recover it for you. If you lose it, the encrypted backup
  cannot be decrypted, by design.
- OAuth tokens and the cached encryption key are stored only in platform secure
  storage (Android Keystore or iOS Keychain). They are never written to ordinary
  app preferences, to logs, or into the backup snapshot.

**Google API Services Limited Use disclosure.** BudgetSense's use and transfer
of information received from Google APIs adheres to the
[Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy),
including its Limited Use requirements. Specifically: BudgetSense accesses your
Google Drive only through the narrow `drive.file` scope, uses that access only to
create, read, and manage your own encrypted BudgetSense backup file, does not
transfer that data to anyone except as needed to provide the backup feature you
requested, does not use it for advertising, and does not allow humans to read it
(it is encrypted on your device and the developer has no server that could read
it).

## 6. Permissions the app uses and why

- **Internet:** only for the optional Google Drive backup. Unused when cloud
  backup is off.
- **Biometric / device credential (app lock):** an optional lock that reuses your
  device's own fingerprint, face, or PIN via the operating system. BudgetSense
  never stores raw biometric data and never keeps a PIN of its own.
- **Notifications:** reminders are scheduled locally on your device by the
  operating system and re-registered after a reboot. They do not involve any
  server.
- **Storage / file access:** used only when you choose to export a local backup
  or import one that you selected.

## 7. Local backups and exports

- Exporting a **local** backup (JSON, CSV, or XML) creates an **unencrypted**
  file containing your full financial history. You choose where it goes. Please
  treat these files like sensitive financial documents and store them somewhere
  you trust.
- The optional **Google Drive cloud backup** is different: every snapshot is
  encrypted on your device before it is uploaded, so only an encrypted blob is
  stored in your Drive.

## 8. Local diagnostics

BudgetSense does not run background remote telemetry. Any diagnostic information
stays on your device and is only ever shared if you deliberately export your
data. App logs do not contain financial values or personal descriptions.

## 9. Data retention and deletion

- You can wipe all local data from within the app (Settings). This clears every
  table in a single operation.
- Deleting the app from your device also removes its private database.
- Any local backup files you exported are under your control and are not touched
  by uninstalling the app. Delete them yourself if you no longer want them.
- For the optional cloud backup, you can disconnect the Google account and,
  separately, delete the cloud backup file at any time from Settings. Disabling
  cloud backup keeps both your local data and any existing cloud file until you
  delete them. You can also delete the `BudgetSense_Backup` file directly from
  your own Google Drive.

## 10. Children's privacy

BudgetSense is a general-purpose personal finance tool and is not directed at
children. It does not knowingly collect personal information from children. If
you believe a child has used the app in a way that raises a concern, note that
all data stays on that child's device and can be removed by clearing the app
data or uninstalling.

## 11. Your rights

Because BudgetSense keeps your data on your own device (and, if you opt in, in
your own Google account), you already hold direct control over it: you can view,
edit, export, and delete it at any time from within the app.

Depending on where you live, data protection laws may give you additional rights
regarding personal data, for example rights to access, correct, delete, or port
your data, and to object to certain processing. These may include the EU and UK
General Data Protection Regulation (GDPR), the California Consumer Privacy Act as
amended by the CPRA (CCPA/CPRA), and India's Digital Personal Data Protection
Act, 2023 (DPDP Act). Since the developer does not hold or have access to your
data, most of these rights are exercised by you directly through the app and your
device. If you have a request that the app itself cannot satisfy, contact the
developer using Section 13.

## 12. International data transfers

BudgetSense does not transfer your data internationally, because it does not send
your data to the developer at all. If you enable the optional cloud backup, your
encrypted backup is stored in your own Google account, and Google's own storage
and transfer practices apply to that account. Please refer to Google's privacy
documentation for how Google handles data in your region.

## 13. How to contact us

The preferred way to raise a privacy question or request is to open an issue on
the project's GitHub Issues page: `[GITHUB_REPO_URL]/issues`.

If you do not have a GitHub account or are unable to submit an issue, you may
contact the developer by email at `[YOUR_CONTACT_EMAIL]`.

Please do not include sensitive financial figures or your recovery passphrase in
any message. We will never ask for your passphrase.

## 14. Changes to this policy

We may update this Privacy Policy from time to time, for example to reflect new
features or legal requirements. When we do, we will update the "Last updated"
date at the top. Significant changes may also be noted in the app's release notes
or CHANGELOG. Your continued use of BudgetSense after an update means you accept
the revised policy.
