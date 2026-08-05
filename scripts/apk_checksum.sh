#!/usr/bin/env bash
# Generates SHA-256 checksums for release artifacts and writes them to
# release-artifacts/SHA256SUMS. Run from the repo root after a build.
#
#   ./scripts/apk_checksum.sh
set -euo pipefail

cd "$(dirname "$0")/.."

DIR=release-artifacts
if [[ ! -d "$DIR" ]]; then
  echo "No $DIR directory; nothing to checksum."
  exit 1
fi

cd "$DIR"
shopt -s nullglob
artifacts=(*.apk *.aab)
if [[ ${#artifacts[@]} -eq 0 ]]; then
  echo "No .apk/.aab artifacts in $DIR."
  exit 1
fi

# Prefer sha256sum; fall back to shasum -a 256 (macOS).
if command -v sha256sum >/dev/null 2>&1; then
  sha256sum "${artifacts[@]}" | tee SHA256SUMS
else
  shasum -a 256 "${artifacts[@]}" | tee SHA256SUMS
fi

echo "Wrote $DIR/SHA256SUMS"
