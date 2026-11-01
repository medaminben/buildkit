# CI / CD

buildkit ships three reusable workflows. A product calls them from short
workflow files and pins them to a buildkit tag, for example `@v2.0.0`. Each
workflow header in `.github/workflows/` is the reference for its inputs.

## `ci.yml`

Jobs: `lint` (clang-format, CMake style, commitlint on PR commits), `build`
(every compiler runs every preset: configure, build, `ctest --preset`) and
`analysis` (clang-tidy and cppcheck, report only).

`buildkit-ref` is empty by default. Then `build`, `analysis` and `codeql.yml` do not export
`BUILDKIT_DIR`: the product's loader pin (`BUILDKIT_TAG`) is honoured, as on a developer
machine. `lint` and the clang-tidy config of `analysis` use buildkit `v2.0.0`. When `buildkit-ref` is set, all
jobs check buildkit out at that ref into `.buildkit` and `build`, `analysis` and CodeQL export
`BUILDKIT_DIR` for the configure, so a product needs no `BUILDKIT_TAG` default to build against
an unreleased buildkit.

`.buildkit` is a checkout inside the product tree. A product must not `file(GLOB_RECURSE)`
over `CMAKE_SOURCE_DIR` (or must exclude `.buildkit`).

`format-exclude` and `configure-args` may span several lines; newlines count as spaces.

| Input | Default | Meaning |
|-------|---------|---------|
| `presets` | `ci` | Presets to build and test, space or comma separated |
| `compilers` | `gcc clang` | Compilers to run every preset with |
| `apt-packages` | empty | Extra apt packages |
| `lint` | `true` | Master switch: `false` turns off all three lint checks, `true` lets the next three decide |
| `lint-format`, `lint-cmake`, `lint-commits` | `true` | clang-format, CMake style, commitlint on PR commits. Only used when `lint` is `true` |
| `format-exclude` | empty | Git pathspec globs that clang-format skips, separated by spaces or newlines, e.g. `3rdparty/**`. Applied as `':(exclude)<glob>'` on `git ls-files` |
| `xvfb` | `false` | Install `xvfb` and run ctest under `xvfb-run -a` (GUI tests) |
| `configure-args` | empty | Arguments for `cmake --preset <preset>`, after the preset. Split at whitespace on purpose, so an argument cannot contain a space and quotes are not interpreted |
| `static-analysis` | `true` | clang-tidy and cppcheck |
| `coverage` | `false` | Also run the `coverage` preset (gcc) and upload the report |
| `sanitizers` | `false` | Also run the `asan` preset (ASan and UBSan, gcc) |
| `buildkit-repository`, `buildkit-ref` | `medaminben/buildkit`, empty | Source of buildkit. Empty: the product's pin is used (lint and the clang-tidy config fall back to `v2.0.0`). Set: checked out for lint, build and analysis, and exported as `BUILDKIT_DIR` |

Precedence of the lint switches: `lint: false` wins and disables everything, whatever
`lint-format`, `lint-cmake` and `lint-commits` say. With `lint: true` each single input
decides, and the job is skipped when all three are `false`.

There is no hook for extra steps. A check such as an install smoke test belongs into the
product as a ctest test (label it, for example, `install`), so that every preset and
every compiler runs it:

```cmake
add_test(NAME install_smoke COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/ci/install-smoke.sh ${CMAKE_BINARY_DIR})
set_tests_properties(install_smoke PROPERTIES LABELS install)
```

```yaml
# .github/workflows/ci.yml in the product
name: CI
on:
  push:
    branches: [main, Beta]
  pull_request:
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true
jobs:
  ci:
    uses: medaminben/buildkit/.github/workflows/ci.yml@v2.0.0
    permissions:
      contents: read
    with:
      presets: "ci"
      apt-packages: "libwxgtk3.2-dev"
      coverage: true
      sanitizers: true
      xvfb: true
      format-exclude: "3rdparty/**"
```

Concurrency is set by the caller, not by the reusable workflow.

## `codeql.yml`

C++ analysis with a manual build. Kept separate so that `ci.yml` does not need
`security-events: write` from its caller. Private repositories need code
scanning enabled.

| Input | Default | Meaning |
|-------|---------|---------|
| `preset` | `default` | Preset built for the analysis |
| `apt-packages` | empty | Extra apt packages |
| `configure-args` | empty | Arguments for `cmake --preset`, split at whitespace |
| `buildkit-repository`, `buildkit-ref` | `medaminben/buildkit`, empty | Set: buildkit is checked out into `.buildkit` and exported as `BUILDKIT_DIR`; empty: the product's pin is used |

```yaml
jobs:
  codeql:
    uses: medaminben/buildkit/.github/workflows/codeql.yml@v2.0.0
    permissions:
      security-events: write
      actions: read
      contents: read
    with:
      preset: default
```

## `release.yml`

Runs when a pull request is closed and was merged into `main` or `Beta`. It
tags the merge commit, creates the GitHub release (a pre-release on `Beta`)
with the commit subjects since the previous tag as notes and, if given, starts
the installer workflow on the new tag.

| Input | Default | Meaning |
|-------|---------|---------|
| `installer-workflow` | empty | Workflow file of the caller, started with `gh workflow run <file> --ref <tag>` |
| `buildkit-repository`, `buildkit-ref` | `medaminben/buildkit`, `v2.0.0` | Source of `tools/release` |

```yaml
# .github/workflows/release.yml in the product
name: Release
on:
  pull_request:
    types: [closed]
jobs:
  release:
    uses: medaminben/buildkit/.github/workflows/release.yml@v2.0.0
    permissions:
      contents: write
      actions: write
    with:
      installer-workflow: windows-installer.yml   # optional
```

The installer workflow must declare `on: workflow_dispatch` in the product's repository.

### Labels

The bump comes from the label of the merged PR: `semver:major`, `semver:minor`,
`semver:patch` (also the default without a label) or `semver:none` (no release).

### Beta and main flow

Features merge into `Beta` through pull requests, `Beta` is promoted to `main`
when the owner asks.

- `Beta` gets `vX.Y.Z-beta.N` pre-releases. An open series (the highest beta
  base is greater than the latest stable) is continued, as long as its base is
  at least the one the labels ask for; otherwise `-beta.1` of the new base starts.
- `main` gets `vX.Y.Z`. A merge of `Beta` into `main` (promotion) releases the
  base version of the open beta, so `v1.3.0-beta.4` is promoted as `v1.3.0`.
  Without an open beta the labels decide as usual; `semver:none` still means no release.
- Promote with a merge commit. A squash merge hides the beta tags from the
  merge commit, so the release falls back to the label bump.
- Tags that are not strictly `vX.Y.Z` or `vX.Y.Z-beta.N` are ignored. The tags
  are also what `buildkit_git_version` reads, so the binary version follows the release.

## Installer flow

`Packaging.cmake` stages the install tree and builds a Windows installer with
Inno Setup, on Windows or through wine on Linux.

```cmake
buildkit_add_stage_target(MyApp INSTALL_SCRIPTS cmake/install_license.cmake)
buildkit_add_inno_installer(MyApp ISS installer/MyApp.iss
    DEFINES AppPublisher=Example)
```

- `MyApp_stage` runs `cmake --install` into `<binary dir>/stage`; product specific
  pieces (for example a `LICENSE` copy for WIN32) go into the `INSTALL_SCRIPTS`.
- `MyApp_installer` runs `ISCC` with `/DAppVersion=<full version>`, `/DStageDir`
  and the output folder `<binary dir>/dist`. `ISCC.exe` is searched natively on
  Windows; on Linux set `BUILDKIT_ISCC` (path to `ISCC.exe`, run as `wine ISCC.exe`)
  and optionally `BUILDKIT_ISCC_HINTS`. Without ISCC (or wine) no installer target
  is created and a status message says so.
- In CI the product's installer workflow (`on: workflow_dispatch`, run by
  `release.yml` through `installer-workflow`) builds the installer on the new tag
  and attaches it to the release.

## Conan profiles

`conan/profiles/` holds Conan 2 profiles for third-party packages:

| Profile | Use |
|---------|-----|
| `linux-gcc` | Build and native host: GCC 14, `libstdc++11`, C++20, Release |
| `windows-mingw` | Cross host: mingw-w64 GCC 14 (posix threads, SEH), C++20, compilers from `x86_64-w64-mingw32-*-posix` |

```bash
conan profile show -pr:h conan/profiles/windows-mingw -pr:b conan/profiles/linux-gcc
conan install --requires=zlib/1.3.1 -pr:h conan/profiles/windows-mingw \
    -pr:b conan/profiles/linux-gcc --build=missing -of build/conan-smoke
```

The cross toolchain comes from `bootstrap.sh --with cross`. Conan is installed
with `uv tool install conan`.

Verification: `conan profile show` with both profiles succeeds (Conan 2.34.0).
The zlib smoke test is **skipped: mingw-w64 not installed** on the machine
where the profiles were written; run it after installing the cross toolchain.

## Local parity

```bash
cmake --preset ci
cmake --build --preset ci --parallel
ctest --preset ci
```

Format and commit checks need Node: `npm install`, `npm run format:check`,
`npx commitlint --from origin/main --to HEAD`.
