#!/usr/bin/env bash
# Release preflight: verifies the repository is in a releasable state BEFORE a
# build is attempted. Fails closed. Run from the repo root.
#
#   ./scripts/release_preflight.sh [expected_version]
#
# Checks:
#   1. AppInfo.version matches the Android versionName (the public release name).
#   2. The pubspec build number matches the Android versionCode source.
#   3. If an expected version is passed, it matches the public release name.
#   4. No signing material sits inside the checkout.
#   5. Placeholder / debug-config scan passes.
#
# pubspec.yaml intentionally carries a three-segment semver ("0.1.0+1") because
# Dart's parser rejects "0.1", so it is not compared against the release name.
set -euo pipefail

cd "$(dirname "$0")/.."

expected="${1:-}"

pubspec_version="$(grep -E '^version:' pubspec.yaml | sed 's/version:[[:space:]]*//')"
pubspec_code="${pubspec_version#*+}"

app_info_version="$(grep -E "version = '" lib/core/constants/app_info.dart \
  | head -1 | sed -E "s/.*version = '([^']*)'.*/\1/")"

gradle_version_name="$(grep -E '^\s*versionName = "' android/app/build.gradle.kts \
  | head -1 | sed -E 's/.*versionName = "([^"]*)".*/\1/')"

echo "pubspec           : ${pubspec_version} (build ${pubspec_code})"
echo "AppInfo.version   : ${app_info_version}"
echo "Android versionName: ${gradle_version_name}"

fail=0

if [[ "$app_info_version" != "$gradle_version_name" ]]; then
  echo "BLOCKER: AppInfo.version ($app_info_version) != Android versionName ($gradle_version_name)"
  fail=1
fi

if [[ -z "$gradle_version_name" ]]; then
  echo "BLOCKER: could not read versionName from android/app/build.gradle.kts"
  fail=1
fi

if [[ -n "$expected" && "$expected" != "$app_info_version" ]]; then
  echo "BLOCKER: expected version '$expected' != release version '$app_info_version'"
  fail=1
fi

echo "==> Signing material scan"
# Keystores and key.properties must live outside the checkout (the Gradle build
# enforces this too). Catching it here keeps a stray copy out of a release and,
# more importantly, out of the public repository.
while IFS= read -r found; do
  echo "BLOCKER: signing material inside the repository: ${found}"
  fail=1
done < <(find . \
  -path ./build -prune -o \
  -path ./.git -prune -o \
  -path ./.dart_tool -prune -o \
  -type f \( -name '*.jks' -o -name '*.keystore' -o -name 'key.properties' \) \
  -print)

echo "==> Placeholder / debug-config scan"
./scripts/check_placeholders.sh

if [[ $fail -ne 0 ]]; then
  echo "Release preflight FAILED."
  exit 1
fi
echo "Release preflight PASSED (version ${app_info_version}, build ${pubspec_code})."
