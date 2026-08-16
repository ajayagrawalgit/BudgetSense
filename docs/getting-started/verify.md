# Verify your download

This step is completely optional. Most people can skip it. It is here for anyone
who wants to confirm the app file downloaded correctly and was not tampered
with.

## What you are checking

Every release includes a `SHA256SUMS` file next to the APK. It lists a long
fingerprint (a SHA-256 hash) for the app file. You recompute that fingerprint on
your own machine and check it matches. If it matches, the file is exactly what
was published. If it does not match, download it again and do not install it.

## The easy way (compares automatically)

Run this in the folder that holds both the `.apk` and `SHA256SUMS`:

=== "macOS"

    ```bash
    shasum -a 256 -c SHA256SUMS
    ```

=== "Linux"

    ```bash
    sha256sum -c SHA256SUMS
    ```

A match prints `OK` next to the file name.

## Or compute it and compare by eye

=== "Windows"

    ```bat
    certutil -hashfile BudgetSense.apk SHA256
    ```

=== "macOS"

    ```bash
    shasum -a 256 BudgetSense.apk
    ```

=== "Linux"

    ```bash
    sha256sum BudgetSense.apk
    ```

Then compare the printed value to the one in `SHA256SUMS`. They should be
identical, ignoring uppercase or lowercase. If a release also ships a
versioned filename, check that one the same way.

## Verifying on the phone itself

Most people download straight to their phone, where there is no built-in hash
command.

Android does give you some protection here on its own. Once BudgetSense is
installed, Android records the certificate the APK was signed with and refuses
any later update signed with a different key, so an update can't quietly come
from somewhere else. That check only helps after the first install though: it
says an update matches what you already have, not that the first copy you
downloaded was the right one. Comparing the checksum is what covers that.

A terminal app such as Termux can compute it on the phone:

```bash
pkg install coreutils
sha256sum BudgetSense.apk
```
