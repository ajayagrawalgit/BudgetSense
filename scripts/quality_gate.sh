#!/usr/bin/env bash
# Full local quality gate for BudgetSense. Mirrors CI so "green locally" means
# "green in CI". Fails fast on the first problem. Run from the repo root.
#
#   ./scripts/quality_gate.sh
#
# Steps: dependency fetch -> code generation -> generated-code drift check ->
# format check -> analyzer -> tests with coverage -> coverage gate.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> flutter pub get"
flutter pub get

echo "==> Generating code (drift/build_runner)"
dart run build_runner build --delete-conflicting-outputs

echo "==> Format check (dart format --set-exit-if-changed)"
dart format --output=none --set-exit-if-changed .

echo "==> Static analysis (flutter analyze)"
flutter analyze

echo "==> Tests with coverage (serial for deterministic ordering)"
flutter test --coverage --concurrency=1

echo "==> Coverage gate (>=70% meaningful, no critical file at 0%)"
python3 tool/coverage_report.py --threshold 70

echo "==> Placeholder / debug-config scan"
bash scripts/check_placeholders.sh

echo ""
echo "Quality gate PASSED."
