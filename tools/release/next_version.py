"""Compute the next release tag from PR labels.

Stable release tags are X.Y.Z; beta tags on the Beta branch are X.Y.Z-beta.N.
The bump comes from the semver:* label of the PR being released. Without a
label the bump is a patch.
"""

import argparse
import re
import sys

BRANCHES = ("main", "Beta")
SEMVER_LABELS = {
    "semver:major": "major",
    "semver:minor": "minor",
    "semver:patch": "patch",
    "semver:none": "none",
}

_VERSION_RE = re.compile(r"(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)")
_BETA_RE = re.compile(r"(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)-beta\.(0|[1-9]\d*)")


def _parse_version(version: str) -> tuple[int, int, int]:
    match = _VERSION_RE.fullmatch(version)
    if match is None:
        raise ValueError(f"malformed version: {version!r} (expected X.Y.Z)")
    return tuple(int(part) for part in match.groups())


def _parse_beta(tag: str) -> tuple[tuple[int, int, int], int]:
    match = _BETA_RE.fullmatch(tag)
    if match is None:
        raise ValueError(f"malformed beta version: {tag!r} (expected X.Y.Z-beta.N)")
    x, y, z, n = (int(part) for part in match.groups())
    return (x, y, z), n


def _bump(base: tuple[int, int, int], kind: str) -> tuple[int, int, int]:
    x, y, z = base
    if kind == "major":
        return x + 1, 0, 0
    if kind == "minor":
        return x, y + 1, 0
    return x, y, z + 1


def next_version(
    latest_stable: str | None,
    labels: list[str],
    target_branch: str,
    latest_beta: str | None = None,
) -> str | None:
    """Return the next tag without the leading 'v', or None for semver:none."""
    if target_branch not in BRANCHES:
        raise ValueError(f"unknown target branch: {target_branch!r} (expected main or Beta)")

    bumps = {SEMVER_LABELS[label] for label in labels if label in SEMVER_LABELS}
    if len(bumps) > 1:
        raise ValueError(f"conflicting semver labels: {sorted(bumps)}")

    if bumps == {"none"}:
        return None

    if latest_stable is None:
        # First release: 0.1.0 regardless of the bump label.
        target = (0, 1, 0)
    else:
        base = _parse_version(latest_stable)
        kind = bumps.pop() if bumps else "patch"
        target = _bump(base, kind)

    x, y, z = target
    target_str = f"{x}.{y}.{z}"
    if target_branch == "main":
        return target_str

    beta = _parse_beta(latest_beta) if latest_beta is not None else None
    if beta is not None and beta[0] == target:
        return f"{target_str}-beta.{beta[1] + 1}"
    return f"{target_str}-beta.1"


def _strip_v(tag: str) -> str | None:
    if not tag:
        return None
    return tag[1:] if tag.startswith("v") else tag


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--latest-stable", default="", help="latest stable tag, e.g. v1.5.4")
    parser.add_argument("--latest-beta", default="", help="latest beta tag, e.g. v1.6.0-beta.2")
    parser.add_argument("--labels", default="", help="comma-separated PR labels")
    parser.add_argument("--branch", required=True, choices=BRANCHES)
    args = parser.parse_args(argv)

    labels = [label.strip() for label in args.labels.split(",") if label.strip()]
    try:
        tag = next_version(
            _strip_v(args.latest_stable),
            labels,
            args.branch,
            _strip_v(args.latest_beta),
        )
    except ValueError as error:
        print(error, file=sys.stderr)
        return 2

    if tag is not None:
        print(f"v{tag}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
