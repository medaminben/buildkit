# Contributing to buildkit

## Setup and tests

```bash
cmake --preset tests
ctest --preset tests
```

Each module has fixtures under `tests/<module>/`; write the fixture first, see it
fail, then implement. Build output goes only under `build/`.

Git hooks (format and commit lint) need Node: `npm install`.

## Style

- CMake 3.29, C++20, no compiler extensions.
- Format C++ with clang-format; `node scripts/check-cmake-style.mjs` checks CMake files.
- Documentation is written in English and uses only names that exist in the code.

## Commits

Conventional Commits: `<type>(optional-scope): <description>` with the types
`feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`,
`chore`, `revert`.

## Pull requests

- [ ] `ctest --preset tests` passes
- [ ] New behavior has a fixture
- [ ] Docs updated when behavior changes
- [ ] The buildkit version pins still agree (`ctest --preset tests -R release_pins`)

## Releasing buildkit

buildkit has its own flow: the default branch is `master` and the flow is direct,
so a feature branch goes to `master` by pull request. `release.yml` is the
reusable workflow for products and does not run for buildkit itself, so the
`semver:*` labels do not apply here. A release is a tag `vX.Y.Z`, created by hand
on `master` after the merge.

Before tagging, bump every pin to the new version (the `release_pins` test fails
when they disagree):

- `.github/workflows/ci.yml`: both `buildkit-ref || 'vX.Y.Z'` fallbacks (lint and
  the clang-tidy config of `analysis`), the `@vX.Y.Z` example and the prose that
  names the version
- `.github/workflows/release.yml`: the `buildkit-ref` input default and the example
- `.github/workflows/codeql.yml`: the example
- `loader/buildkit.cmake`: the `BUILDKIT_TAG` default
- `cmake/Buildkit.cmake`: `FALLBACK X.Y.Z` of `buildkit_git_version`
- `README.md`, `docs/CI_CD.md`, `docs/MIGRATION.md`: every mention of the pinned tag

Then run `ctest --preset tests`, merge, and tag:

```bash
git tag -a vX.Y.Z -m "buildkit vX.Y.Z"
git push origin vX.Y.Z
```

Do not commit secrets or machine-local paths.
