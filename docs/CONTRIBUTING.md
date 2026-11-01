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
- [ ] A `semver:major`, `semver:minor`, `semver:patch` or `semver:none` label is set

Do not commit secrets or machine-local paths.
