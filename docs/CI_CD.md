# Continuous integration and delivery

Six workflows. Each owns a single job, and none of them can trip over another.
This file explains what runs when, and why the boundaries sit where they do.

## The workflows

| Workflow | Fires on | What it does |
|:--|:--|:--|
| `ci.yml` | Every PR to `main`, and callable by others | Format, analyze, test, coverage, unsigned release build |
| `docs.yml` | Push to `main` touching docs or any root Markdown | Rebuilds and deploys the GitHub Pages site |
| `auto-release.yml` | Push to `main` touching shipped code | Rebuilds the APK and publishes it as latest |
| `release.yml` | A real version tag such as `v0.1` | A deliberate, named release |
| `weekly-dependencies.yml` | Mondays at 00:00 IST | Finds safe updates, verifies them, opens a PR |
| `security.yml` | PRs, pushes to `main`, weekly | Secret scanning and vulnerability scanning |

## Documentation is never written twice

Every page under `docs/` that mirrors a root file is a wrapper, not a copy:

```markdown
{%
   include-markdown "../SECURITY.md"
   rewrite-relative-urls=false
%}
```

So `SECURITY.md`, `PRIVACY.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`,
`TERMS_OF_SERVICE.md` and `CHANGELOG.md` live once, at the repository root, and
the site pulls them in at build time. Edit the root file, push, and the page
updates itself. There is no manual step and no second copy to forget.

`docs.yml` watches `docs/**`, `overrides/**`, `mkdocs.yml`,
`requirements-docs.txt` and `*.md`, which is what makes that automatic.

The one deliberate exception is `README.md`. The site's front page is a custom
landing page (`docs/index.md` plus `overrides/home.html`), because a README and
a homepage want to say the same thing in different shapes.

## Releasing without touching anything

Merge to `main`. If the merge touched `lib/`, `android/`, `ios/`, `assets/` or
the pubspec, `auto-release.yml` will:

1. Run the full CI gate. A failure stops everything, so a broken build cannot
   become a release.
2. Read the version from `lib/core/constants/app_info.dart`, the single source
   of truth, and tag the build `v<version>-build.<run number>`.
3. Build the release APK, signing it when the keystore secrets exist and
   labelling it clearly as unsigned when they do not.
4. Write release notes from the matching `CHANGELOG.md` section, falling back
   to grouped commit subjects when the changelog has nothing for this version.
5. Publish, attach `SHA256SUMS`, and mark the release as latest.

Every release includes an APK named exactly `BudgetSense.apk`, which is why the
download button in the README never goes stale.

Docs-only merges are skipped on purpose. Republishing an identical APK because
a typo was fixed in a Markdown file is noise, and `docs.yml` already handles
those.

### Why this does not collide with `release.yml`

The two workflows own different tag shapes, and each ignores the other's:

- `release.yml` handles `v*` but explicitly excludes `v*-build.*`.
- `auto-release.yml` only ever creates `v*-build.*`.
- Before publishing, `auto-release.yml` checks whether a plain version tag
  already points at the current commit. If one does, it stands down, because a
  hand-made release is the authoritative one.

One commit therefore produces exactly one release, from exactly one workflow.

Both use `concurrency: cancel-in-progress: false`. Cancelling a release half
way through is how you end up with a tag that has no APK attached.

## Monday morning dependency care

`weekly-dependencies.yml` runs at 00:00 IST every Monday. The cron reads
`30 18 * * 0`, which is Sunday 18:30 UTC. IST is UTC+5:30 all year with no
daylight saving, so that single expression stays correct.

What it does:

1. Records the current lockfile and scans for known vulnerabilities.
2. Runs `flutter pub upgrade`, which stays inside the constraints already in
   `pubspec.yaml`. That means patch and minor updates only.
3. Stops quietly if nothing changed.
4. Runs the same checks a pull request faces: format, analyze, placeholder
   scan, the full test suite, the coverage gate, the security gate, and a real
   Android release build.
5. Rescans, and fails if the update introduced more vulnerabilities than it
   removed.
6. Opens a PR describing exactly what moved, which updates fixed a
   vulnerability, and which majors were deliberately left alone.

### Why majors are not applied automatically

A major version bump needs a constraint change in `pubspec.yaml`, and it can
change behaviour in ways a green test suite will not notice. The workflow
lists those packages in the PR body instead, so they stay visible without
being taken silently. Deciding on a breaking change is a human's job.

If the verification steps fail, no PR is opened at all. A red automated PR is
worse than none, because it teaches you to merge without looking.

Nothing in this workflow merges anything. You review and merge, and merging is
what triggers the release.

## Signing

Signing material never lives in the repository. Both release workflows read
the keystore from CI secrets, write it outside the checkout, and point Gradle
at it through `BUDGETSENSE_KEYSTORE_PROPERTIES`. The Gradle build rejects a
properties path inside the repository, so signing material cannot be committed
by accident or swept into an artifact upload.

With no secrets configured the build stays **unsigned**, and both the release
notes and the artifact filename say so. It is never debug-signed, because a
debug-signed APK looks installable while being trivially forgeable.

## Helper scripts

| Script | Used by | Purpose |
|:--|:--|:--|
| `tool/release_notes.py` | `auto-release.yml` | Changelog section, or grouped commits as a fallback |
| `tool/dependency_update_report.py` | `weekly-dependencies.yml` | Diffs lockfiles and writes the PR body |
| `tool/coverage_report.py` | `ci.yml` | Enforces the coverage gate |
| `scripts/security_gate.sh` | `ci.yml`, weekly | Asserts the security controls are still in place |
| `scripts/release_preflight.sh` | Both release workflows | Version and packaging sanity checks |
| `scripts/apk_checksum.sh` | Both release workflows | Writes `SHA256SUMS` |

Both Python helpers run offline, take no secrets, and degrade quietly when an
input file is missing.