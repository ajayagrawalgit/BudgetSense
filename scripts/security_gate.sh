#!/usr/bin/env bash
#
# Security regression gate for BudgetSense.
#
# Fails closed on the specific misconfigurations this codebase must never
# regress into. Each check exists because of a real finding or a real control
# verified during the 2026-08-16 security assessment; see
# security/SECURITY_ASSESSMENT.md for the reasoning behind each one.
#
# Runs entirely offline and needs no secrets, so it is safe in CI and locally.
#
# Usage: ./scripts/security_gate.sh

set -uo pipefail

cd "$(dirname "$0")/.."

FAILURES=0
fail() { echo "  FAIL: $1"; FAILURES=$((FAILURES + 1)); }
pass() { echo "  ok:   $1"; }

MANIFEST=android/app/src/main/AndroidManifest.xml
PATHS=android/app/src/main/res/xml/provider_paths.xml

echo "==> 1. No TLS verification bypass"
# A single one of these in shipping code defeats HTTPS entirely.
if grep -rInE 'badCertificateCallback|HttpOverrides\.global' lib/ >/dev/null 2>&1; then
  fail "certificate validation bypass found in lib/"
else
  pass "no certificate bypass"
fi

echo "==> 2. No cleartext HTTP endpoints"
# XML namespace URIs are identifiers, not network calls, so they are excluded.
if grep -rInE 'http://' lib/ 2>/dev/null \
    | grep -vE 'schemas\.|www\.w3\.org|localhost|127\.0\.0\.1' >/dev/null; then
  fail "cleartext http:// URL found in lib/"
else
  pass "no cleartext endpoints"
fi

echo "==> 3. Android release flags"
if grep -qE 'android:debuggable="true"' "$MANIFEST"; then
  fail "android:debuggable=true in main manifest"
else
  pass "not debuggable"
fi
if grep -qE 'android:usesCleartextTraffic="true"' "$MANIFEST"; then
  fail "cleartext traffic enabled in main manifest"
else
  pass "cleartext traffic not enabled"
fi
if grep -qE 'android:allowBackup="false"' "$MANIFEST"; then
  pass "allowBackup=false"
else
  fail "allowBackup is not explicitly false"
fi

echo "==> 4. FileProvider stays scoped to the cache directory"
# A files-path or external-path with path="." would make the SQLite database
# holding every transaction eligible to be handed out as a content:// URI.
#
# This app currently has no FileProvider at all. That is the safest state for
# now, and this check keeps both futures covered:
#   - if none exists, stay none
#   - if one is added later, it must stay cache-scoped
if ! grep -qE 'FileProvider|androidx\.core\.content\.FileProvider' "$MANIFEST" 2>/dev/null; then
  pass "no FileProvider declared"
elif [ ! -f "$PATHS" ]; then
  fail "FileProvider is declared but provider_paths.xml is missing"
elif grep -qE '<(files-path|external-path|root-path)' "$PATHS"; then
  fail "provider_paths.xml exposes more than the cache directory"
else
  pass "provider_paths scoped to cache only"
fi

echo "==> 5. No signing material tracked by git"
if git ls-files 2>/dev/null | grep -qE '\.jks$|\.keystore$|key\.properties$'; then
  fail "signing material is tracked by git"
else
  pass "no tracked keystores or key.properties"
fi

echo "==> 6. No obvious hardcoded credentials"
SECRET_RE='AIza[0-9A-Za-z_-]{35}|ya29\.[0-9A-Za-z_-]{20}|AKIA[0-9A-Z]{16}'
SECRET_RE="$SECRET_RE"'|ghp_[0-9A-Za-z]{36}|BEGIN (RSA|EC|OPENSSH) PRIVATE KEY'
if grep -rInE "$SECRET_RE" lib/ android/app/src/ ios/Runner/ test/ 2>/dev/null \
    | grep -v Binary >/dev/null; then
  fail "possible hardcoded credential found"
else
  pass "no hardcoded credential patterns"
fi

echo "==> 7. Release logging stays disabled"
if grep -q 'kDebugMode' lib/core/utils/app_log.dart; then
  pass "AppLog is gated on kDebugMode"
else
  fail "AppLog is no longer gated on kDebugMode"
fi

echo "==> 8. Export escaping is still wired in"
# Guards the CSV/XLSX formula-injection fix against a refactor silently
# dropping the call.
if grep -q 'SpreadsheetSafety' lib/domain/services/export_service.dart; then
  pass "export path applies SpreadsheetSafety"
else
  fail "export path no longer applies SpreadsheetSafety"
fi

echo "==> 9. KDF iteration bounds are still enforced"
if grep -q 'minAcceptedIterations' lib/data/cloud/encryption_service.dart; then
  pass "PBKDF2 iteration bounds present"
else
  fail "PBKDF2 iteration bounds removed"
fi

echo "==> 10. Security regression tests pass"
if flutter test test/security/ >/dev/null 2>&1; then
  pass "test/security/ passes"
else
  fail "test/security/ failed"
fi

echo
if [ "$FAILURES" -gt 0 ]; then
  echo "SECURITY GATE FAILED: $FAILURES check(s)"
  exit 1
fi
echo "SECURITY GATE PASSED"
