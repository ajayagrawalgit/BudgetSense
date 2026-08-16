#!/usr/bin/env bash
# Validates the public-tree ignore policy without requiring Git.
set -euo pipefail
cd "$(dirname "$0")/../.."

required=(
  '.dart_tool/' 'build/' '*.jks' '*.keystore' 'key.properties'
  '*.sqlite' '*.db' '*.db-wal' '*.db-shm' '*.db-journal' '*.bsbak'
  '*.apk' '*.aab' '.env' '.env.*' 'coverage/'
)
for pattern in "${required[@]}"; do
  grep -Fqx "$pattern" .gitignore || {
    echo "FAIL: .gitignore lacks required policy pattern: $pattern" >&2
    exit 1
  }
done

for required_public in pubspec.lock gradle/wrapper/gradle-wrapper.properties .github security; do
  if git check-ignore -q "$required_public" 2>/dev/null; then
    echo "FAIL: required public path is ignored: $required_public" >&2
    exit 1
  fi
done

echo ".gitignore public-release policy passed."
