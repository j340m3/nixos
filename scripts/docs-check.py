#!/usr/bin/env python3
"""Check that relative Markdown links point at files that exist.

Only local links are checked; http(s), mailto, anchors and absolute paths are
ignored. Missing targets listed in PENDING are tolerated because those wiki
pages are written but not committed yet (the vault owner commits them later).
"""

from __future__ import annotations

import re
import sys
from pathlib import Path
from urllib.parse import unquote, urlparse

ROOT = Path(__file__).resolve().parents[1]

# Wiki pages that are intentionally not committed yet. Remove an entry once the
# page lands, so a future break of the same path is reported again.
PENDING = {
    "docs/wiki/sources/mptcp-cves-2025.md",
    "docs/wiki/concepts/mptcp-defaults-check-disable.md",
    "docs/wiki/syntheses/mptcp-repo-assessment.md",
    "docs/wiki/syntheses/rnsh-retirement-audit.md",
    "docs/wiki/concepts/rnsh-listener-security.md",
    "docs/wiki/sources/rnsh-bundled-rnsh.md",
    "docs/wiki/sources/rns-shared-instance-rpc.md",
    "docs/wiki/sources/rust-reticulum-implementations.md",
    "docs/wiki/sources/rns-advisories-and-threat-model.md",
    # referenced by concepts/php-serving-modes-risk.md; not committed yet
    "docs/wiki/sources/nixpkgs-nextcloud-module.md",
}

LINK_RE = re.compile(r"\[[^\]]*\]\(\s*(<[^>]+>|[^)\s]+)")
FENCE_RE = re.compile(r"^\s*(```|~~~)")


def markdown_files() -> list[Path]:
    files = [ROOT / "README.md", ROOT / "HOSTS.md", ROOT / "GLOSSARY.md"]
    files += sorted((ROOT / "docs").rglob("*.md"))
    return [f for f in files if f.is_file()]


def links(path: Path) -> list[tuple[int, str]]:
    found: list[tuple[int, str]] = []
    in_fence = False
    for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if FENCE_RE.match(line):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        for match in LINK_RE.finditer(line):
            target = match.group(1)
            if target.startswith("<") and target.endswith(">"):
                target = target[1:-1]
            found.append((lineno, target))
    return found


def main() -> int:
    broken: list[tuple[str, int, str]] = []
    stale_allowlist: set[str] = set()

    for path in markdown_files():
        for lineno, raw in links(path):
            parsed = urlparse(raw)
            if parsed.scheme or raw.startswith(("#", "/")):
                continue
            target = unquote(parsed.path)
            if not target:
                continue
            resolved = (path.parent / target).resolve()
            try:
                rel = resolved.relative_to(ROOT).as_posix()
            except ValueError:
                rel = str(resolved)
            if resolved.exists():
                if rel in PENDING:
                    stale_allowlist.add(rel)
                continue
            if rel in PENDING:
                continue
            broken.append((path.relative_to(ROOT).as_posix(), lineno, raw))

    for where, lineno, target in broken:
        print(f"{where}:{lineno}: missing link target: {target}")

    for rel in sorted(stale_allowlist):
        print(f"note: allowlisted page now exists, drop it from PENDING: {rel}")

    if broken:
        print(f"\n{len(broken)} broken relative link(s).", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
