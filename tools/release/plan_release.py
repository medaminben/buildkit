"""Plan a release from the git history: pick the next tag and write the notes.

Reads the tags of a git repository, applies tools/release/next_version.py and
prints the new tag (nothing for semver:none). With --notes-file the commit
subjects since the previous tag are written there.

Tags that do not match the strict vX.Y.Z or vX.Y.Z-beta.N patterns are ignored.

Beta: an open series (highest beta base greater than the latest stable) is
continued when its base is at least the base the labels ask for; otherwise a
new series target-beta.1 starts.

Re-run: when the merge commit already carries a tag of the planned kind (a stable
tag for main, a beta tag for Beta), that tag is returned again instead of a new
one, so re-running a failed release job does not create a second release.

Beta to main promotion: a merge from the Beta branch of the same repository
into main releases the base X.Y.Z of the highest beta tag reachable from the
merge commit that is greater than the latest stable. Without such a beta (a
squash merge makes the betas unreachable), or with semver:none, the normal
label rules apply.
"""

import argparse
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from next_version import BETA_RE, VERSION_RE, next_version  # noqa: E402


def _git(repo: str, *args: str) -> str:
    result = subprocess.run(
        ["git", "-C", repo, *args], capture_output=True, text=True, check=False
    )
    if result.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)} failed: {result.stderr.strip()}")
    return result.stdout


def _tags(repo: str, *extra: str) -> list[str]:
    out = _git(repo, "tag", "--list", "v[0-9]*", *extra)
    return [line for line in out.splitlines() if line]


def _stable_key(tag: str):
    """(x, y, z) of a strict vX.Y.Z tag, else None."""
    if tag.startswith("v") and VERSION_RE.fullmatch(tag[1:]):
        return tuple(int(p) for p in tag[1:].split("."))
    return None


def _beta_key(tag: str):
    """(x, y, z, n) of a strict vX.Y.Z-beta.N tag, else None."""
    match = BETA_RE.fullmatch(tag[1:]) if tag.startswith("v") else None
    return tuple(int(p) for p in match.groups()) if match else None


def _highest(tags, key):
    keyed = [(key(t), t) for t in tags if key(t) is not None]
    return max(keyed)[1] if keyed else None


def latest_stable(repo: str) -> str | None:
    return _highest(_tags(repo), _stable_key)


def existing_tag(repo: str, base_branch: str, sha: str) -> str | None:
    """The tag of the planned kind that already points at sha, if any."""
    key = _stable_key if base_branch == "main" else _beta_key
    return _highest(_tags(repo, "--points-at", sha), key)


def plan_tag(repo, labels, base_branch, head_branch, sha, from_fork=False) -> str | None:
    """Return the next tag, or None for no release.

    A tag of the planned kind that already points at sha is returned as it is
    (the release is being re-run).

    head_branch is only a promotion when it is Beta of the same repository
    (from_fork False).
    """
    already = existing_tag(repo, base_branch, sha)
    if already is not None:
        return already
    stable = latest_stable(repo)
    stable_arg = stable[1:] if stable else None
    normal = next_version(stable_arg, labels, "main")  # validates the labels too
    if normal is None:
        return None

    if base_branch == "main":
        if head_branch == "Beta" and not from_fork:
            beta = _highest(_tags(repo, "--merged", sha), _beta_key)
            if beta is not None and (stable is None or _beta_key(beta)[:3] > _stable_key(stable)):
                return "v%d.%d.%d" % _beta_key(beta)[:3]
        return f"v{normal}"

    target = tuple(int(p) for p in normal.split("."))
    betas = [t for t in _tags(repo) if _beta_key(t) is not None]
    open_series = [
        t for t in betas if stable is None or _beta_key(t)[:3] > _stable_key(stable)
    ]
    series = max((_beta_key(t)[:3] for t in open_series), default=None)
    if series is not None and series >= target:
        # Continue the open beta series.
        latest = max((_beta_key(t), t) for t in open_series if _beta_key(t)[:3] == series)[1]
        return "v%d.%d.%d-beta.%d" % (*series, _beta_key(latest)[3] + 1)
    result = next_version(stable_arg, labels, "Beta", None)
    return f"v{result}"


def notes(repo: str, base_branch: str, sha: str) -> str:
    at_sha = set(_tags(repo, "--points-at", sha))  # a re-run: not its own previous tag
    reachable = [t for t in _tags(repo, "--merged", sha) if t not in at_sha]
    previous = _highest(reachable, _stable_key)
    if base_branch == "Beta":
        both = [t for t in reachable if _stable_key(t) or _beta_key(t)]
        previous = (
            max((_stable_key(t) + (10**9,) if _stable_key(t) else _beta_key(t), t) for t in both)[1]
            if both
            else None
        )
    rev = f"{previous}..{sha}" if previous else sha
    return _git(repo, "log", "--format=- %s", rev)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--repo", default=".")
    parser.add_argument("--labels", default="")
    parser.add_argument("--base", required=True, choices=("main", "Beta"))
    parser.add_argument("--head", default="")
    parser.add_argument("--from-fork", action="store_true",
                        help="the PR head is in another repository: never a promotion")
    parser.add_argument("--sha", required=True)
    parser.add_argument("--notes-file")
    args = parser.parse_args(argv)
    labels = [x.strip() for x in args.labels.split(",") if x.strip()]
    try:
        tag = plan_tag(args.repo, labels, args.base, args.head, args.sha, args.from_fork)
        if tag and args.notes_file:
            with open(args.notes_file, "w", encoding="utf-8") as handle:
                handle.write(notes(args.repo, args.base, args.sha))
    except (ValueError, RuntimeError) as error:
        print(error, file=sys.stderr)
        return 2
    if tag:
        print(tag)
    return 0


if __name__ == "__main__":
    sys.exit(main())
