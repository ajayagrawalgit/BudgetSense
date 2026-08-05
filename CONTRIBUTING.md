# Contributing to BudgetSense

Thanks for helping improve BudgetSense, a calm, offline-first personal finance
journal. This guide keeps the codebase consistent and releasable.

## Prerequisites

- Flutter 3.44.4 (stable), Dart 3.12.x
- JDK 21 (`JAVA_HOME` set) for Android builds
- Android SDK (build-tools 36.x) if you build/verify APKs

## Setup

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # generates *.g.dart
```

Generated files (`*.g.dart`, `*.freezed.dart`) are gitignored and regenerated;
never edit them by hand. `pubspec.lock` **is** committed for reproducible builds.

## Everyday commands

```bash
dart format .                                  # format
flutter analyze                                # static analysis (must be clean)
flutter test --concurrency=1                   # run tests serially/deterministically
flutter test --coverage --concurrency=1        # with coverage
python3 tool/coverage_report.py --threshold 70 # enforce coverage locally
./scripts/quality_gate.sh                      # everything CI runs, in one shot
```

## Architecture and conventions

- Layered: UI (features) -> providers (Riverpod DI) -> services (domain) ->
  repositories -> Drift/SQLite. Nothing constructs its own dependencies; wire
  through providers. See `docs/ARCHITECTURE.md`.
- Keep files focused and reasonably small; split when cohesion allows.
- Money is stored/handled via the `Money` value type (minor units), never raw
  doubles, to avoid floating-point corruption.
- Dates use explicit boundaries; inject clocks/`DateTime`s in tests.
- No `print` in shipping code (`avoid_print` is enforced). No hard-coded strings
  where localization is expected.
- **No em-dashes or en-dashes** anywhere (code, comments, docs, strings). Use
  commas, colons, periods, or parentheses.

## Tests

- Add tests for every behaviour change and a regression test for every bug fix.
- Use isolated in-memory databases (`test/support/test_database.dart`); close
  them in `tearDown`/`addTearDown`. No shared mutable global DB, no `sleep`.
- Coverage must stay >= 70% meaningful, and no critical infrastructure file may
  drop to 0%.

## Before opening a PR

1. `./scripts/quality_gate.sh` passes.
2. If you touched a public API, update all call sites, tests, and docs.
3. Update `CHANGELOG.md` under "Unreleased".
4. Do not commit secrets, keystores, `key.properties`, or PII files.

CI (fail-closed) will run format, analyze, generated-code drift, tests +
coverage gate, secret scanning (Gitleaks), dependency vulnerability scanning
(OSV), dependency review, and a release-build validation. Green locally should
mean green in CI.

## License of contributions

BudgetSense is licensed under the GNU General Public License v3.0. By
contributing, you agree that your contributions are licensed under the same
terms. Please also follow our [Code of Conduct](CODE_OF_CONDUCT.md).
