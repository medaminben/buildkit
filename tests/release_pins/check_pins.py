"""Fail when the buildkit version pins disagree with each other.

Run as: python3 -B -I tests/release_pins/check_pins.py <buildkit root>

Named pins (each must be found exactly as many times as listed):
  ci.yml       `buildkit-ref || 'vX.Y.Z'` (lint, analysis clang-tidy config)
  release.yml  the buildkit-ref input default
  loader       the BUILDKIT_TAG default
  Buildkit.cmake  `FALLBACK X.Y.Z` of buildkit_git_version
Every other vX.Y.Z mention in workflows, README, docs and template must agree too.
"""

import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
found = []  # (description, version)


def scan(rel, pattern, description, expected=None):
    text = (root / rel).read_text(encoding="utf-8")
    versions = re.findall(pattern, text)
    if expected is not None and len(versions) != expected:
        print(f"FAIL: {rel}: expected {expected} x {description}, found {len(versions)}")
        sys.exit(1)
    found.extend((f"{rel} ({description})", v) for v in versions)


scan(".github/workflows/ci.yml", r"buildkit-ref \|\| 'v(\d+\.\d+\.\d+)'", "buildkit-ref fallback", 2)
scan(".github/workflows/release.yml",
     r"buildkit-ref:\n(?:[ ]+(?:description|type):.*\n)*[ ]+default: \"v(\d+\.\d+\.\d+)\"",
     "buildkit-ref default", 1)
scan("loader/buildkit.cmake", r"set\(BUILDKIT_TAG \"v(\d+\.\d+\.\d+)\"\)", "BUILDKIT_TAG default", 1)
scan("cmake/Buildkit.cmake", r"FALLBACK (\d+\.\d+\.\d+)", "FALLBACK", 1)

others = [p.relative_to(root).as_posix() for p in
          [*(root / ".github/workflows").glob("*.yml"), root / "README.md",
           *(root / "docs").glob("*.md"), *(root / "template").rglob("*")] if p.is_file()]
for rel in sorted(set(others)):
    if rel == "docs/CONTRIBUTING.md":
        continue  # describes the release procedure with placeholders
    text = "\n".join(  # lines that show beta/promotion examples are not pins
        line for line in (root / rel).read_text(encoding="utf-8", errors="replace").splitlines()
        if "beta" not in line)
    found.extend((f"{rel} (v-pin)", v)
                 for v in re.findall(r"(?<![\w.])v(\d+\.\d+\.\d+)(?![\w.-])", text))

versions = {v for _, v in found}
for what, v in found:
    print(f"{v}  {what}")
if len(versions) != 1:
    print(f"FAIL: pins disagree: {sorted(versions)}")
    sys.exit(1)
print(f"release_pins OK: {versions.pop()} ({len(found)} pins)")
