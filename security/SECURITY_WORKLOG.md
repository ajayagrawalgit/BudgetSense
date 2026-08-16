# Security Worklog

Chronological record of the 2026-08-16 assessment. Sanitized: no secret values,
credentials or personal data appear here.

## Environment

| Item | Value |
|---|---|
| Repository root | `<REPO_ROOT>` |
| Version control | **None** — `git status` returns "not a git repository" |
| Flutter / Dart | 3.44.4 stable / 3.12.2 |
| Host | macOS 26.6.1, arm64 |
| JDK | OpenJDK 21 (Homebrew) at `/opt/homebrew/opt/openjdk@21` |
| Android build-tools | 37.0.0 |

## Initial state

The project is **not under Git version control**, so there was no baseline
`git status`, no pre-existing modified/untracked file list to preserve, and no
history to scan for secrets. Every file changed during this assessment is listed
in `REMEDIATION_LOG.md`, which serves as the diff record in the absence of Git.

Recommending version control is itself an assessment finding (section 9, item 3
of `SECURITY_ASSESSMENT.md`).

## Tools

**Available and used:** Flutter analyzer, `dart format`, `flutter test`,
`flutter build apk`, `apksigner` 37.0.0, `aapt2` 37.0.0, `unzip`, `strings`,
`grep`, Python 3 (manifest XML parsing).

**Unavailable, so the corresponding checks were not run:** `osv-scanner`,
`gitleaks`, `trufflehog`, `semgrep`, Xcode, CocoaPods, `jadx`, `apktool`,
`mobsf`, `fvm`, `melos`. Per the engagement rules these were **not** installed
via unsafe bootstrap commands. Their absence is recorded as reduced coverage
rather than papered over; CI already runs Gitleaks and OSV-Scanner as blocking
gates.

## Sequence of work

1. **Orientation.** Confirmed repository root, discovered the absence of Git,
   inventoried the tree, probed the toolchain, read `pubspec.yaml`.
2. **Architecture inventory.** Read 131 Dart files across the update, cloud
   backup, export, import, snapshot, database, notification, security and
   settings layers; all 11 Kotlin widget providers and `MainActivity`; the
   Android manifests, Gradle config and XML resources; `ios/Runner/Info.plist`;
   and the three CI workflows.
3. **Baseline.** `flutter analyze` clean. A full `flutter test` run stalled at
   142 tests; isolated the cause to a pre-existing Drift teardown hang under
   fake-async, unrelated to any change made here.
4. **Targeted searches.** TLS bypass constructs, `http://`, WebView, FFI,
   process execution, `launchUrl`, raw SQL, logging calls, clipboard, file and
   storage APIs, and high-signal secret patterns. Results in
   `SECURITY_ASSESSMENT.md` section 6.
5. **Remediation.** Five Medium findings fixed; see `REMEDIATION_LOG.md`.
6. **Regression tests.** Four new test files, 22 tests. One of them caught a
   genuine gap in the first draft of the F-002 fix, where a non-numeric
   `iterations` value still escaped as a raw cast error.
7. **Release build and binary analysis.** Built the release APK with JDK 21;
   inspected the merged manifest, exported components, permissions, signing
   certificate, decoded `provider_paths` resource, and swept assets and dex for
   secrets.
8. **Gate script.** Wrote `scripts/security_gate.sh` and verified it fails
   closed by temporarily reintroducing an over-broad FileProvider path,
   confirming the failure, then restoring the file.
9. **Final validation.** Re-ran format, analyze, the full supported test set and
   the gate.

## Notable observations

- The single dex secret-pattern match was a bare `-----BEGIN ` PEM parser format
  string with no key body: a confirmed false positive, verified by extracting
  the surrounding strings.
- The release APK carries no v1 signature block, which initially looked like an
  unsigned build. `apksigner` confirmed a valid v2 signature with the real
  release certificate; v1 JAR signing is simply disabled, which is expected for
  a modern `minSdk`.
- Two pre-existing encryption tests used `iterations: 1000` for speed and began
  failing against the new PBKDF2 floor. They were raised to the real minimum
  rather than lowering the security control, after confirming the runtime cost
  was negligible.

## Assumptions

- The build host is trusted and uncompromised.
- The keystores present in `android/app/` are the developer's legitimate signing
  keys.
- CI executes the workflows as written in `.github/workflows/`.

## Testing limitations

No dynamic testing, no emulator or device testing, no network traffic
inspection, no remote testing (unauthorized and unconfigured), no iOS build or
entitlement inspection, no automated dependency or secret scanning, and no
Git history analysis. Enumerated in `SECURITY_ASSESSMENT.md` section 10.
