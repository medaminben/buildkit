"""Plan a release from the git history: pick the next tag and write the notes.

Reads the tags of a git repository, applies tools/release/next_version.py and
prints the new tag (nothing for semver:none). With --notes-file the commit
subjects since the previous tag are written there.

Beta to main promotion: a merge from the Beta branch into main releases the
base X.Y.Z of the highest beta tag reachable from the merge commit that is
greater than the latest stable. Without such a beta, or with semver:none, the
normal label rules apply.
"""

import argparse
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from next_version import next_version  # noqa: E402

_STABLE = re.compile(r"v(\d+)\.(\d+)\.(\d+)")
_BETA = re.compile(r"v(\d+)\.(\d+)\.(\d+)-beta\.(\d+)")


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


def _base(tag: str) -> tuple[int, int, int]:
    return tuple(int(p) for p in re.split(r"[.-]", tag[1:])[:3])


def latest_stable(repo: str) -> str | None:
    tags = [t for t in _tags(repo) if _STABLE.fullmatch(t)]
    return max(tags, key=_base) if tags else None


def _highest_beta(tags: list[str], base: tuple[int, int, int] | None = None) -> str | None:
    best = None
    for tag in tags:
        match = _BETA.fullmatch(tag)
        if match is None:
            continue
        numbers = tuple(int(p) for p in match.groups())
        if base is not None and numbers[:3] != base:
            continue
        if best is None or numbers > best[0]:
            best = (numbers, tag)
    return best[1] if best else None


def plan_tag(repo, labels, base_branch, head_branch, sha) -> str | None:
    stable = latest_stable(repo)
    stable_arg = stable[1:] if stable else None
    normal = next_version(stable_arg, labels, "main")  # validates the labels too
    if normal is None:
        return None

    if base_branch == "main":
        if head_branch == "Beta":
            beta = _highest_beta(_tags(repo, "--merged", sha))
            if beta is not None and (stable is None or _base(beta) > _base(stable)):
                return "v%d.%d.%d" % _base(beta)
        return f"v{normal}"

    target = tuple(int(p) for p in normal.split("."))
    beta = _highest_beta(_tags(repo), target)
    result = next_version(stable_arg, labels, "Beta", beta[1:] if beta else None)
    return f"v{result}"


def notes(repo: str, base_branch: str, sha: str) -> str:
    describe = ["describe", "--tags", "--abbrev=0", "--match", "v[0-9]*"]
    if base_branch == "main":
        describe += ["--exclude", "*-beta.*"]
    try:
        previous = _git(repo, *describe, sha).strip()
    except RuntimeError:
        previous = ""
    rev = f"{previous}..{sha}" if previous else sha
    return _git(repo, "log", "--format=- %s", rev)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--repo", default=".")
    parser.add_argument("--labels", default="")
    parser.add_argument("--base", required=True, choices=("main", "Beta"))
    parser.add_argument("--head", default="")
    parser.add_argument("--sha", required=True)
    parser.add_argument("--notes-file")
    args = parser.parse_args(argv)
    labels = [x.strip() for x in args.labels.split(",") if x.strip()]
    try:
        tag = plan_tag(args.repo, labels, args.base, args.head, args.sha)
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
