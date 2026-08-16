#!/usr/bin/env python3
"""Compose GitHub release notes for an automated build.

Preference order, best first:

1. The section in ``CHANGELOG.md`` matching this version. Hand-written, aimed
   at a person, and the whole reason a changelog exists.
2. Commit subjects since the previous release tag, tidied and grouped. Used
   only when the changelog has nothing to say about this version yet.

Always appends install and verification guidance, plus an honest note when the
APK is unsigned, because a reader deserves to know what they are downloading.
"""

from __future__ import annotations

import argparse
import re
import subprocess
from pathlib import Path

CHANGELOG = Path("CHANGELOG.md")

# Conventional-commit prefix mapped to the heading a human would want to read.
GROUPS: list[tuple[str, str]] = [
    ("feat", "New"),
    ("fix", "Fixed"),
    ("perf", "Faster"),
    ("security", "Security"),
    ("refactor", "Under the hood"),
    ("docs", "Documentation"),
    ("chore", "Housekeeping"),
    ("build", "Housekeeping"),
    ("ci", "Housekeeping"),
    ("test", "Tests"),
]

SKIP_PATTERNS = (
    re.compile(r"^merge ", re.IGNORECASE),
    re.compile(r"^bump version", re.IGNORECASE),
)


def changelog_section(version: str) -> str:
    """The body of the `## <version>` section, if there is one."""
    if not CHANGELOG.exists():
        return ""
    text = CHANGELOG.read_text()
    # Match `## 0.1` (and `## [0.1]`, and a trailing date) up to the next `## `.
    pattern = re.compile(
        r"^##\s+\[?" + re.escape(version) + r"\]?[^\n]*\n(.*?)(?=^##\s|\Z)",
        re.MULTILINE | re.DOTALL,
    )
    found = pattern.search(text)
    return found.group(1).strip() if found else ""


def run(args: list[str]) -> str:
    try:
        return subprocess.run(
            args, capture_output=True, text=True, timeout=60, check=False
        ).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return ""


def previous_tag() -> str:
    """Most recent tag reachable from HEAD, excluding the one just created."""
    return run(["git", "describe", "--tags", "--abbrev=0", "HEAD^"])


def commit_notes() -> str:
    """Group commit subjects since the last tag under readable headings."""
    since = previous_tag()
    span = f"{since}..HEAD" if since else "HEAD"
    raw = run(["git", "log", span, "--no-merges", "--pretty=format:%s"])
    if not raw:
        return ""

    buckets: dict[str, list[str]] = {}
    for line in raw.splitlines():
        subject = line.strip()
        if not subject or any(p.match(subject) for p in SKIP_PATTERNS):
            continue

        heading = "Other"
        match = re.match(r"^(\w+)(?:\([^)]*\))?!?:\s*(.+)$", subject)
        if match:
            prefix, rest = match.group(1).lower(), match.group(2)
            for key, label in GROUPS:
                if prefix == key:
                    heading, subject = label, rest
                    break
            else:
                subject = rest
        buckets.setdefault(heading, []).append(subject[:1].upper() + subject[1:])

    order = [label for _, label in GROUPS]
    seen: list[str] = []
    for label in order + ["Other"]:
        if label in buckets and label not in seen:
            seen.append(label)

    out: list[str] = []
    for heading in seen:
        out.append(f"**{heading}**")
        out.append("")
        out.extend(f"- {item}" for item in buckets[heading])
        out.append("")
    return "\n".join(out).strip()


def build_notes(version: str, build: str, signed: bool) -> str:
    out: list[str] = []
    add = out.append

    body = changelog_section(version)
    source = "changelog"
    if not body:
        body = commit_notes()
        source = "commits"
    if not body:
        body = "Routine maintenance build. No user-facing changes recorded."
        source = "none"

    add("### What changed")
    add("")
    add(body)
    add("")

    if source == "commits":
        add(
            "<sub>Generated from commit history, because `CHANGELOG.md` has no "
            f"section for {version} yet.</sub>"
        )
        add("")

    add("---")
    add("")
    add("### Install it")
    add("")
    add(
        "Download **BudgetSense.apk** below and open it on your Android phone. "
        "Android will ask you to allow installs from this source, which is "
        "normal for anything that does not come from the Play Store."
    )
    add("")

    if not signed:
        add(
            "> **Heads up:** this build is **unsigned**, because no signing key "
            "was available to the build. Android may refuse to install it "
            "directly. Prefer a signed release if one is available."
        )
        add("")

    add("### Check what you downloaded")
    add("")
    add(
        "`SHA256SUMS` is attached. Compare it against your download before "
        "installing:"
    )
    add("")
    add("```bash")
    add("sha256sum -c SHA256SUMS")
    add("```")
    add("")
    add(
        f"<sub>Build {build}, published automatically from `main`. "
        "Free and open source under the GNU GPL v3.0. A budgeting tool, "
        "not financial advice.</sub>"
    )

    return "\n".join(out) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True)
    parser.add_argument("--build", default="")
    parser.add_argument("--signed", default="false")
    args = parser.parse_args()

    print(
        build_notes(
            args.version,
            args.build,
            signed=args.signed.strip().lower() == "true",
        ),
        end="",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
