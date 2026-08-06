# Verify your download

This step is completely optional. Most people can skip it. It is here for anyone
who wants to confirm the app file downloaded correctly and was not tampered
with.

## What you are checking

Every release includes a `SHA256SUMS.txt` file next to the APK. It lists a long
fingerprint (a SHA-256 hash) for the app file. You recompute that fingerprint on
your own machine and check it matches. If it matches, the file is exactly what
was published. If it does not match, download it again and do not install it.

## The easy way (compares automatically)

Run this in the folder that holds both the `.apk` and `SHA256SUMS.txt`:

=== "macOS"

    ```bash
    shasum -a 256 -c SHA256SUMS.txt
    ```

=== "Linux"

    ```bash
    sha256sum -c SHA256SUMS.txt
    ```

A match prints `OK` next to the file name.

## Or compute it and compare by eye

=== "Windows"

    ```bat
    certutil -hashfile BudgetSense-0.1.0.apk SHA256
    ```

=== "macOS"

    ```bash
    shasum -a 256 BudgetSense-0.1.0.apk
    ```

=== "Linux"

    ```bash
    sha256sum BudgetSense-0.1.0.apk
    ```

Then compare the printed value to the one in `SHA256SUMS.txt`. They should be
identical, ignoring uppercase or lowercase.

## Verifying on the phone itself

Most people download straight to their phone, where there is no built-in hash
command. Your stronger, automatic protection there is that Android verifies the
app's signature during install using the official BudgetSense release key, which
cannot be faked. So on-phone hash checking is rarely necessary.

If you still want to, a terminal app such as Termux can do it:

```bash
pkg install coreutils
sha256sum BudgetSense.apk
```
