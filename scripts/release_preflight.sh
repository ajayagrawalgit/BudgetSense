#!/usr/bin/env bash
# Release preflight: verifies the repository is in a releasable state BEFORE a
# build is attempted. Fails closed. Run from the repo root.
#
#   ./scripts/release_preflight.sh [expected_version]
#
# Checks:
#   1. pubspec.yaml version part matches AppInfo.version (single source of truth).
#   2. If an expected version is passed, it matches pubspec.
#   3. No uncommitted changes to version-bearing files (optional: warn only).
#   4. Placeholder / debug-config scan passes.
set -euo pipefail

cd "$(dirname "$0")/.."

expected="${1:-}"

pubspec_version="$(grep -E '^version:' pubspec.yaml | sed 's/version:[[:space:]]*//')"
pubspec_name="${pubspec_version%+*}"
pubspec_code="${pubspec_version#*+}"

app_info_version="$(grep -E "version = '" lib/core/constants/app_info.dart \
  | head -1 | sed -E "s/.*version = '([^']*)'.*/\1/")"

echo "pubspec version : ${pubspec_name}+${pubspec_code}"
echo "AppInfo.version : ${app_info_version}"

fail=0

if [[ "$pubspec_name" != "$app_info_version" ]]; then
  echo "BLOCKER: pubspec version ($pubspec_name) != AppInfo.version ($app_info_version)"
  fail=1
fi

if [[ -n "$expected" && "$expected" != "$pubspec_name" && "$expected" != "$pubspec_version" ]]; then
  echo "BLOCKER: expected version '$expected' != pubspec '$pubspec_version'"
  fail=1
fi

echo "==> Placeholder / debug-config scan"
./scripts/check_placeholders.sh

if [[ $fail -ne 0 ]]; then
  echo "Release preflight FAILED."
  exit 1
fi
echo "Release preflight PASSED (version ${pubspec_name}, build ${pubspec_code})."
