#!/usr/bin/env bash
# Scans for release blockers that static analysis does not catch: leftover
# TODO/FIXME markers in shipping code, and debug-only Android configuration that
# must never reach a release build. Exit non-zero if any blocker is found.
#
# Advisory markers (TODO/FIXME/etc.) are reported but do NOT fail the build;
# hard release blockers (android:debuggable="true", usesCleartextTraffic="true"
# in the main manifest) DO fail it.
set -euo pipefail

cd "$(dirname "$0")/.."

fail=0

echo "==> Scanning lib/ for advisory markers (TODO/FIXME/TBD/XXX/HACK)"
if grep -rInE "\b(TODO|FIXME|TBD|XXX|HACK)\b" lib/ 2>/dev/null; then
  echo "  (advisory only: the markers above do not fail the build)"
else
  echo "  none found."
fi

echo "==> Checking for hard release blockers in AndroidManifest"
MANIFEST=android/app/src/main/AndroidManifest.xml
if [[ -f "$MANIFEST" ]]; then
  if grep -qE 'android:debuggable="true"' "$MANIFEST"; then
    echo "  BLOCKER: android:debuggable=\"true\" in $MANIFEST"
    fail=1
  fi
  if grep -qE 'android:usesCleartextTraffic="true"' "$MANIFEST"; then
    echo "  BLOCKER: usesCleartextTraffic=\"true\" in $MANIFEST"
    fail=1
  fi
  [[ $fail -eq 0 ]] && echo "  clean."
fi

echo "==> Checking no signing secrets are committed"
for pattern in "key.properties" "*.jks" "*.keystore"; do
  # git ls-files respects .gitignore; anything tracked here is a real leak.
  if git ls-files --error-unmatch $pattern >/dev/null 2>&1; then
    echo "  BLOCKER: tracked signing material matching '$pattern'"
    fail=1
  fi
done
[[ $fail -eq 0 ]] && echo "  clean."

if [[ $fail -ne 0 ]]; then
  echo "Placeholder/debug scan FAILED."
  exit 1
fi
echo "Placeholder/debug scan PASSED."
