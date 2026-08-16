#!/usr/bin/env bash
# Run immediately after `git init` and before the first public commit.
# This is intentionally Git-specific. It does nothing until the owner creates
# the repository, as requested in the public-release procedure.
set -euo pipefail
cd "$(dirname "$0")/../.."

fail=0
bad_tracked='(\.jks$|\.keystore$|key\.properties$|\.pem$|\.p12$|\.pfx$|\.key$|\.mobileprovision$|(^|/)\.env($|\.)|\.(db|sqlite|sqlite3|bsbak|apk|aab)$|(^|/)(build|coverage|\.dart_tool|logs?)(/|$)|mapping\.txt$|\.symbols$)'

require() { if ! "$@"; then echo "FAIL: $*"; fail=1; fi; }

git rev-parse --is-inside-work-tree >/dev/null

if git ls-files | grep -E "$bad_tracked" >/dev/null; then
  echo "FAIL: forbidden sensitive/generated file is tracked"
  git ls-files | grep -E "$bad_tracked" | sed 's/^/  /'
  fail=1
fi

git ls-files --error-unmatch pubspec.lock >/dev/null 2>&1 || {
  echo "FAIL: pubspec.lock must be tracked"; fail=1; }

# Every workflow action must be full-SHA pinned with a reviewed version comment.
if grep -RInE '^\s*uses:\s*[^@[:space:]]+@[0-9A-Fa-f]{0,39}([^0-9A-Fa-f]|$)' .github/workflows 2>/dev/null; then
  echo "FAIL: workflow action is not pinned to a complete immutable SHA"
  fail=1
fi

./scripts/security/validate_gitignore_policy.sh

if command -v gitleaks >/dev/null; then
  gitleaks git --redact --no-banner
else
  echo "FAIL: gitleaks is required for full-history scan"; fail=1
fi

# The initial public commit must contain the expected policy/build inputs.
for file in pubspec.yaml pubspec.lock .gitignore SECURITY.md CONTRIBUTING.md \
  security/PUBLIC_TREE_POLICY.md scripts/security/validate_gitignore_policy.sh; do
  git ls-files --error-unmatch "$file" >/dev/null 2>&1 || {
    echo "FAIL: required public file not tracked: $file"; fail=1; }
done

if (( fail )); then
  exit 1
fi
echo "Post-Git-initialization verification passed."
