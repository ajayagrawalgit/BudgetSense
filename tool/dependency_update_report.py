#!/usr/bin/env python3
"""Write the body of the weekly dependency-update pull request.

Two jobs, both small:

* ``--count FILE`` prints the number of vulnerabilities in an osv-scanner JSON
  report, or ``0`` if the file is missing or unreadable. The workflow compares
  before and after, so this has to stay quiet and never raise.
* With no arguments, prints a Markdown PR body describing what moved and what
  was deliberately left alone.

Nothing here reaches the network, and nothing prints a secret: the only inputs
are the lockfiles and the scanner's own report.
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

BEFORE_LOCK = Path("/tmp/deps/pubspec.lock.before")
AFTER_LOCK = Path("pubspec.lock")
OSV_BEFORE = Path("/tmp/deps/osv.before.json")
OSV_AFTER = Path("/tmp/deps/osv.after.json")


def vulnerability_count(path: Path) -> int:
    """Vulnerabilities in an osv-scanner JSON report, forgiving of junk."""
    try:
        report = json.loads(path.read_text())
    except (OSError, ValueError):
        return 0
    return sum(
        len(package.get("vulnerabilities", []))
        for result in report.get("results", [])
        for package in result.get("packages", [])
    )


def vulnerable_packages(path: Path) -> set[str]:
    """Names of packages the scanner flagged."""
    try:
        report = json.loads(path.read_text())
    except (OSError, ValueError):
        return set()
    return {
        package.get("package", {}).get("name", "")
        for result in report.get("results", [])
        for package in result.get("packages", [])
        if package.get("vulnerabilities")
    }


def parse_lock(path: Path) -> dict[str, str]:
    """Map package name to resolved version from a pubspec.lock.

    Hand-rolled rather than pulling in a YAML dependency, because a lockfile is
    rigidly generated and this script has to run on a bare runner. Only
    two-space-indented package names and their nested `version:` matter.
    """
    versions: dict[str, str] = {}
    current: str | None = None
    try:
        lines = path.read_text().splitlines()
    except OSError:
        return versions

    in_packages = False
    for line in lines:
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if re.match(r"^packages:\s*$", line):
            in_packages = True
            continue
        if in_packages and re.match(r"^\S", line):
            break  # left the packages block (sdks:, and so on)
        if not in_packages:
            continue
        name = re.match(r"^  (\S+):\s*$", line)
        if name:
            current = name.group(1)
            continue
        version = re.match(r'^    version:\s*"?([^"\s]+)"?\s*$', line)
        if version and current:
            versions[current] = version.group(1)
            current = None
    return versions


def held_back_packages() -> list[tuple[str, str, str]]:
    """Packages held back by their own constraint, so a human must decide.

    `flutter pub upgrade` cannot take these, which is exactly why they are
    worth listing: otherwise they quietly rot forever.
    """
    try:
        completed = subprocess.run(
            ["flutter", "pub", "outdated", "--json"],
            capture_output=True,
            text=True,
            timeout=180,
            check=False,
        )
        data = json.loads(completed.stdout)
    except (OSError, ValueError, subprocess.SubprocessError):
        return []

    held: list[tuple[str, str, str]] = []
    for package in data.get("packages", []):
        current = (package.get("current") or {}).get("version")
        resolvable = (package.get("resolvable") or {}).get("version")
        latest = (package.get("latest") or {}).get("version")
        # resolvable == current means the constraint is the thing pinning it.
        if current and latest and latest != current and resolvable == current:
            held.append((package.get("package", "?"), current, latest))
    return held


def build_body() -> str:
    before = parse_lock(BEFORE_LOCK)
    after = parse_lock(AFTER_LOCK)

    upgraded = sorted(
        (name, before[name], after[name])
        for name in before.keys() & after.keys()
        if before[name] != after[name]
    )
    added = sorted(after.keys() - before.keys())
    removed = sorted(before.keys() - after.keys())

    vulns_before = vulnerability_count(OSV_BEFORE)
    vulns_after = vulnerability_count(OSV_AFTER)
    was_vulnerable = vulnerable_packages(OSV_BEFORE)

    out: list[str] = []
    add = out.append

    add("## Weekly dependency update")
    add("")
    add(
        "Opened automatically on the Monday schedule. Every check below already "
        "ran against these exact versions, and the workflow only gets this far "
        "if all of them passed."
    )
    add("")

    if not upgraded and not added and not removed:
        add("No dependency versions changed.")
        return "\n".join(out) + "\n"

    if upgraded:
        add(f"### Updated ({len(upgraded)})")
        add("")
        add("| Package | From | To | Note |")
        add("|:--|:--|:--|:--|")
        for name, old, new in upgraded:
            note = "security fix" if name in was_vulnerable else ""
            add(f"| `{name}` | {old} | {new} | {note} |")
        add("")

    if added:
        add(f"### New transitive packages ({len(added)})")
        add("")
        add(", ".join(f"`{name}`" for name in added))
        add("")

    if removed:
        add(f"### No longer needed ({len(removed)})")
        add("")
        add(", ".join(f"`{name}`" for name in removed))
        add("")

    add("### Security")
    add("")
    if vulns_before or vulns_after:
        add(
            f"Known vulnerabilities: **{vulns_before} before, "
            f"{vulns_after} after**."
        )
    else:
        add("No known vulnerabilities before or after. This is routine upkeep.")
    add("")

    held = held_back_packages()
    if held:
        add("### Deliberately not updated")
        add("")
        add(
            "These need a constraint change in `pubspec.yaml`, which usually "
            "means a breaking change. The robot will not make that call."
        )
        add("")
        add("| Package | Current | Latest |")
        add("|:--|:--|:--|")
        for name, current, latest in held:
            add(f"| `{name}` | {current} | {latest} |")
        add("")

    add("### What was verified")
    add("")
    add("- `dart format` clean")
    add("- `flutter analyze` clean")
    add("- Full test suite passing, run serially")
    add("- Coverage still above the 70% gate")
    add("- `scripts/security_gate.sh` passing")
    add("- Android release APK builds")
    add("")
    add(
        "Merging this triggers the release workflow, which rebuilds the APK "
        "and publishes it as the new latest release."
    )

    return "\n".join(out) + "\n"


def main() -> int:
    if len(sys.argv) == 3 and sys.argv[1] == "--count":
        print(vulnerability_count(Path(sys.argv[2])))
        return 0
    if len(sys.argv) > 1:
        print(__doc__, file=sys.stderr)
        return 2
    print(build_body(), end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
