# Manual Test Plan: Backup, Restore, and Google Drive

Automated tests cover the engines and the cloud controller with fakes. This plan
covers what must be checked by hand, especially the Google-dependent paths that
CI cannot run. Run on a real Android device with a real (test) Google account.

## A. Local backup and restore

1. Export a local backup (JSON) with data present. Confirm a file is produced.
2. Interrupt an export (e.g. kill the app mid-export). Confirm no partial file
   is presented as a valid backup on next launch.
3. Restore the exported file into the SAME database. Confirm the result summary
   shows records skipped (idempotent) and NOTHING deleted or changed.
4. Restore into a DIFFERENT database that has its own records. Confirm existing
   records are untouched and new ones are appended.
5. Restore a corrupt/truncated file. Confirm it is rejected with a clear message
   and zero mutations.

## B. Cloud enable (first time)

1. Settings → Backup and Sync to Cloud is OFF by default.
2. Toggle on. Confirm the explainer names Google Drive and the
   `BudgetSense_Backup` folder, and that local use works without cloud.
3. Set a recovery passphrase (min 8, confirm match).
4. Sign in with the test Google account; grant `drive.file` only.
5. Confirm the `BudgetSense_Backup` folder and one backup file appear in Drive.
6. Confirm status shows the linked email, "Backed up", and a last-backup time.

## C. Reconciliation (existing cloud backup)

1. With a backup already in Drive, enable on a second install.
2. Choose "Import" → confirm append-only counts, no local overwrite, then a
   merged upload.
3. Repeat and choose "Use this device" → confirm the cloud file is replaced and
   a prior Drive revision remains; local data untouched.
4. Choose "Cancel" → confirm nothing is enabled or changed.

## D. Change tracking and sync

1. Add an expense. Confirm status becomes "Waiting to back up", then uploads
   after the debounce.
2. Make several rapid edits. Confirm they coalesce into ONE upload.
3. Turn off wifi, edit, turn wifi back on / resume the app. Confirm the pending
   upload retries and clears.

## E. Restore from Google Drive

1. Reinstall the app (or use a fresh device). Enable cloud, sign in.
2. Restore from Drive using the recovery passphrase. Confirm the preview shows
   counts and the "nothing deleted/overwritten" language.
3. Confirm the result summary shows inserted/skipped/conflict counts.
4. Enter a WRONG passphrase. Confirm it fails before any local change.

## F. Failure and security

1. Revoke BudgetSense access in the Google account. Confirm the app moves to
   "Requires sign-in" and does not crash.
2. Delete the backup file in Drive manually. Confirm the app reports it and does
   not silently recreate deleted data without informing you.
3. Fill Drive storage (or simulate). Confirm quota guidance and no retry storm.
4. Edit the backup from a second device. Confirm this device enters
   "Needs attention" (remote conflict) instead of overwriting.
5. Inspect the Drive file bytes. Confirm it is ciphertext (no readable names,
   amounts, or descriptions).
6. Inspect logs. Confirm no snapshot contents, amounts, descriptions, tokens, or
   passphrase appear.

## G. Disable / disconnect / delete

1. Disable cloud backup. Confirm local data AND the cloud file are preserved and
   scheduling stops.
2. Disconnect Google Drive. Confirm the account link clears; local data stays.
3. Delete cloud backup (separate, confirmed action). Confirm the Drive file is
   removed and local data is untouched.

## H. Accessibility

1. Set the system font scale to maximum. Confirm the section remains usable.
2. With a screen reader, confirm the toggle, status, and every action button are
   labelled and announced.
