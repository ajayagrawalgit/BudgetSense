#!/usr/bin/env bash
#
# defluff - shake the fluff out of a Flutter/Dart repo.
#
# Removes generated caches, build output, tool caches, coverage, platform glue,
# and OS junk so you can start fresh before a new feature, a test run, or a git
# push. It only ever touches known-regenerable "fluff". Your source code,
# pubspec.lock, signing keystores (*.jks), key.properties and .git are never
# touched, even though some of them are gitignored.
#
# Usage:
#   scripts/defluff.sh            clean the fluff
#   scripts/defluff.sh --dry-run  show what would go, delete nothing
#   scripts/defluff.sh --deep     also delete generated *.g.dart / freezed / mocks
#   scripts/defluff.sh --regen    after cleaning, restore a buildable state
#   scripts/defluff.sh --help
#
set -euo pipefail

DRY_RUN=0
DEEP=0
REGEN=0

for arg in "$@"; do
  case "$arg" in
    --dry-run|-n) DRY_RUN=1 ;;
    --deep)       DEEP=1 ;;
    --regen)      REGEN=1 ;;
    -h|--help)
      sed -n '2,20p' "$0" | sed 's/^#\{1,\} \{0,1\}//'
      exit 0 ;;
    *) echo "Unknown option: $arg (try --help)"; exit 2 ;;
  esac
done

# Repo root is the parent of this script's directory. Confirm it is a Flutter
# project before we delete a single thing.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ ! -f "$ROOT/pubspec.yaml" ]]; then
  echo "This does not look like a Flutter repo (no pubspec.yaml at $ROOT). Aborting."
  exit 1
fi
cd "$ROOT"

# Colors, but only when writing to a real terminal.
if [[ -t 1 ]]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; CYAN=$'\033[36m'; RESET=$'\033[0m'
else
  BOLD=""; DIM=""; GREEN=""; YELLOW=""; CYAN=""; RESET=""
fi

total_kb=0

size_kb() { if [[ -e "$1" ]]; then du -sk "$1" 2>/dev/null | awk '{print $1}'; else echo 0; fi; }

human() { awk -v k="$1" 'BEGIN{ split("KB MB GB TB",u," "); s=k; i=1; while(s>=1024 && i<4){s/=1024;i++}; printf("%.1f %s", s, u[i]) }'; }

zap() {
  local path="$1" label="${2:-$1}" kb
  if [[ -e "$path" ]]; then
    kb="$(size_kb "$path")"
    total_kb=$((total_kb + kb))
    if [[ $DRY_RUN -eq 1 ]]; then
      printf "  ${YELLOW}would remove${RESET} %-46s ${DIM}(%s)${RESET}\n" "$label" "$(human "$kb")"
    else
      rm -rf "$path"
      printf "  ${GREEN}removed${RESET}      %-46s ${DIM}(%s)${RESET}\n" "$label" "$(human "$kb")"
    fi
  fi
}

echo "${BOLD}${CYAN}defluff${RESET} ${DIM}(shaking the fluff out of ${ROOT##*/})${RESET}"
[[ $DRY_RUN -eq 1 ]] && echo "${YELLOW}dry run: nothing will actually be deleted${RESET}"
echo

echo "${BOLD}Caches and build output${RESET}"
zap ".dart_tool"                    ".dart_tool/ (pub + build cache)"
zap "build"                         "build/ (compiled output)"
zap "coverage"                      "coverage/ (test coverage)"
zap "dist"                          "dist/ (staged distributables)"
zap ".flutter-plugins"              ".flutter-plugins"
zap ".flutter-plugins-dependencies" ".flutter-plugins-dependencies"

echo
echo "${BOLD}Android${RESET}"
zap "android/.gradle"    "android/.gradle/ (Gradle cache)"
zap "android/build"      "android/build/"
zap "android/app/build"  "android/app/build/"

echo
echo "${BOLD}iOS platform glue${RESET}"
zap "ios/Pods"                                  "ios/Pods/"
zap "ios/.symlinks"                             "ios/.symlinks/"
zap "ios/Flutter/ephemeral"                     "ios/Flutter/ephemeral/"
zap "ios/Flutter/Generated.xcconfig"            "ios/Flutter/Generated.xcconfig"
zap "ios/Flutter/flutter_export_environment.sh" "ios/Flutter/flutter_export_environment.sh"

echo
echo "${BOLD}OS junk${RESET}"
while IFS= read -r -d '' f; do
  zap "$f" "${f#./}"
done < <(find . -path ./.git -prune -o \( -name '.DS_Store' -o -name 'Thumbs.db' \) -print0 2>/dev/null)

if [[ $DEEP -eq 1 ]]; then
  echo
  echo "${BOLD}Generated Dart code (--deep)${RESET}"
  while IFS= read -r -d '' f; do
    zap "$f" "${f#./}"
  done < <(find lib test -type f \( -name '*.g.dart' -o -name '*.freezed.dart' -o -name '*.mocks.dart' \) -print0 2>/dev/null)
fi

echo
if [[ $DRY_RUN -eq 1 ]]; then
  echo "${BOLD}${YELLOW}Would reclaim about $(human "$total_kb").${RESET}"
else
  echo "${BOLD}${GREEN}All fluffed out. Reclaimed about $(human "$total_kb").${RESET}"
fi

if [[ $REGEN -eq 1 && $DRY_RUN -eq 0 ]]; then
  echo
  echo "${BOLD}${CYAN}Restoring a buildable state...${RESET}"
  if command -v flutter >/dev/null 2>&1; then
    flutter pub get
    dart run build_runner build --delete-conflicting-outputs
    echo "${GREEN}Ready. Fresh as a daisy.${RESET}"
  else
    echo "${YELLOW}flutter not found on PATH; skipped pub get / build_runner.${RESET}"
  fi
elif [[ $DRY_RUN -eq 0 ]]; then
  echo "${DIM}Tip: run 'flutter pub get' (and build_runner) before building, or use --regen.${RESET}"
fi
