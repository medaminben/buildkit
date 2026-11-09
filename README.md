# buildkit

<p align="center">
  <a href="https://github.com/medaminben/buildkit/actions/workflows/self-test.yml"><img alt="Self-test" src="https://github.com/medaminben/buildkit/actions/workflows/self-test.yml/badge.svg?branch=main"></a>
  <a href="https://github.com/medaminben/buildkit/tags"><img alt="version" src="https://img.shields.io/github/v/tag/medaminben/buildkit?label=version"></a>
  <img alt="C++20" src="https://img.shields.io/badge/C%2B%2B-20-00599C">
  <img alt="CMake 3.29" src="https://img.shields.io/badge/CMake-3.29-064F8C">
  <img alt="platform: Windows | Linux" src="https://img.shields.io/badge/platform-Windows%20%7C%20Linux-555">
  <a href="LICENSE"><img alt="license: MIT" src="https://img.shields.io/github/license/medaminben/buildkit"></a>
</p>

<p align="center">
  <a href="#quick-start">Quick start</a> ·
  <a href="#documentation">Docs</a> ·
  <a href="docs/CI_CD.md">CI/CD</a> ·
  <a href="https://github.com/medaminben/buildkit/tags">Versions</a>
</p>

A reusable CMake kit for C++20 products: one loader file, a handful of modules
and reusable GitHub workflows. A product keeps its code; buildkit supplies the
build helpers, the dependency rule, versioning from git tags, packaging, CI and
releases.

## Quick start

### A new project

Clone buildkit once, then run the setup script from a new, empty folder. That
folder must be outside the buildkit checkout.

Linux (needs `cmake`, `ninja` and `g++`):

```bash
git clone https://github.com/medaminben/buildkit.git ~/dev/buildkit
mkdir ~/dev/MyApp && cd ~/dev/MyApp
bash ~/dev/buildkit/scripts/new-project.sh
```

Windows (needs `cmake`, `ninja` and `g++` from MSYS2 UCRT64 on `PATH`, e.g.
`C:\msys64\ucrt64\bin`):

```powershell
git clone https://github.com/medaminben/buildkit.git $HOME\dev\buildkit
mkdir $HOME\dev\MyApp; cd $HOME\dev\MyApp
powershell -ExecutionPolicy Bypass -File $HOME\dev\buildkit\scripts\new-project.ps1
```

The script:

1. writes `CMakeLists.txt`, `CMakePresets.json`, `.gitignore` and the loader copy
   `cmake/buildkit.cmake`;
2. writes a git-ignored `CMakeUserPresets.json` with the presets `dev` and
   `dev-release`, which point at your buildkit checkout;
3. writes `.vscode/` files: Ctrl+Shift+B builds, F5 builds and runs the console app;
4. generates `libraries/Core/` and `applications/Core/`, builds, runs the tests
   and starts `Core_Console`.

Arguments, all optional:

| Linux | Windows | Meaning |
|---|---|---|
| `Name` | `Name` | Project name; default: the folder name |
| `Lib...` | `Lib...` | Libraries after the name; default: `Core` |
| `--repo <owner>/<repo>` | `-Repo <owner>/<repo>` | Public product on GitHub: also writes `LICENSE` (MIT), `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md` and the issue and PR templates |

For example, `new-project.sh --repo medaminben/Pong Pong Physics Render`.
Existing files are never overwritten, so running the script again is safe.
Your code goes into `libraries/<Lib>/include/` and `src/`. More in
[docs/ADDING_LIBRARIES.md](docs/ADDING_LIBRARIES.md).

### An existing product

Copy `loader/buildkit.cmake` to `cmake/buildkit.cmake` in your product and
include it before `project()`:

```cmake
cmake_minimum_required(VERSION 3.29)
include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/buildkit.cmake)

buildkit_git_version(${CMAKE_CURRENT_SOURCE_DIR} MYAPP_VERSION MYAPP_VERSION_FULL FALLBACK 0.1.0)
project(MyApp VERSION ${MYAPP_VERSION} LANGUAGES CXX)
# The installer target reads ${PROJECT_NAME}_VERSION_FULL for /DAppVersion.
set(${PROJECT_NAME}_VERSION_FULL "${MYAPP_VERSION_FULL}")
```

A new product can be generated instead: `generate_project(NAME MyApp DESTINATION <dir> LIBRARIES Core)`
writes `CMakeLists.txt`, `CMakePresets.json`, `.gitignore` and the loader copy
(see [docs/ADDING_LIBRARIES.md](docs/ADDING_LIBRARIES.md)); this is what the
setup scripts above call.

The loader finds buildkit in this order:

1. `BUILDKIT_DIR` (cache entry or environment variable) with a `cmake/Buildkit.cmake` inside.
   A wrong path is a fatal error that names it.
2. A sibling checkout `${CMAKE_SOURCE_DIR}/../buildkit`.
3. A git fetch of `BUILDKIT_REPOSITORY` at `BUILDKIT_TAG` (default `v2.0.0`; a tag or a
   branch name, not a commit SHA) into `<binary dir>/_buildkit/src`, with the tag stamped in
   `<binary dir>/_buildkit/tag`. Set `BUILDKIT_TAG` before the include to pin another tag or branch.

It prints `buildkit: using <path> (local working copy | tag vX.Y.Z)`. With
`BUILDKIT_OFFLINE` or `FETCHCONTENT_FULLY_DISCONNECTED` ON (cache, variable or
environment variable) and no local copy it
reuses a copy fetched earlier for the same tag (`tag vX.Y.Z, cached`; the same
applies when the remote does not answer). A cached copy of another tag, or no
copy at all, is an error, because buildkit itself is required; set
`BUILDKIT_DIR` to a local checkout. A changed tag is fetched
again when online. The loader needs no compiler
and is safe to include twice.

## Modules

`cmake/Buildkit.cmake` sets `BUILDKIT_ROOT`, `BUILDKIT_VERSION` and
`BUILDKIT_VERSION_FULL`, extends `CMAKE_MODULE_PATH` and includes:

| Module | What it gives you |
|--------|-------------------|
| `GitVersion` | `buildkit_git_version()`: version from the nearest git tag, usable before `project()` |
| `Dependency` | `dev_dependency()`: installed, else fetched, else without |
| `BuildLocation` | Output folders relative to the binary dir |
| `BuildUtils` | `create_library()`, `create_application()` |
| `CompilerWarnings` | `buildkit_set_warnings(<target>)`, level from `BUILDKIT_STRICT_WARNINGS` |
| `Coverage` | The `coverage` target when `ENABLE_COVERAGE` is ON (needs a compiler: configures after `project()`) |
| `LibraryGenerator` | `generate_libraries()`, `generate_project()` |
| `TestUtils`, `GTestSupport` | `build_gtest_executable()`; GoogleTest through `dev_dependency` on first use |
| `Packaging` | `buildkit_add_stage_target()`, `buildkit_add_inno_installer()` |
| `Manual` | `buildkit_add_manual()`: multilingual Markdown manual to static HTML. It must work offline: any `http://` or `https://` URL in a page fails the check, and a backtick span is always an application label, never inline code |
| `DebugUtils` | Variable dump for debugging |

`InstallConfig` (install and export of `find_package` config) is not included
automatically; a product does `include(InstallConfig)` when it wants it.

## Dependency rule

`dev_dependency(<Name> ...)` uses an installed copy first, else fetches it
(archive with SHA-256, or git tag), else builds without it for `OPTIONAL`
(the default) or stops with an error for `REQUIRED`. Both messages name the cause
(not installed, no network, offline) and say to install it with the system package
manager; `INSTALL_HINT "apt install libfoo-dev"` adds the exact package to both. Offline mode
(`BUILDKIT_OFFLINE` or `FETCHCONTENT_FULLY_DISCONNECTED`, also as environment variables; the
switches are OR'ed, so `-DBUILDKIT_OFFLINE=OFF` cannot undo an environment variable) never touches the
network, and an unreachable host is detected by a 30 second probe instead of a
long hang. Full syntax: header of `cmake/Dependency.cmake`.

## Versioning

The version comes from git tags `vX.Y.Z` (stable) and `vX.Y.Z-beta.N` (Beta
branch). `buildkit_git_version(<dir> <numeric> <full> [FALLBACK x.y.z])` returns:

- numeric: `X.Y.Z`, for `project(VERSION ...)`
- full: `X.Y.Z` or `X.Y.Z-beta.N`, followed by `+<ahead>.g<sha7>` when HEAD is past the tag

Without git, without a matching tag, or when the folder is not the top level of
its own repository, numeric is the fallback (default `0.0.0`) and full is
`<fallback>-dev`, so a development build never looks like a release. Releases
are created by the reusable workflows; see [docs/CI_CD.md](docs/CI_CD.md).

## Build output

All build output goes under `<repo>/build/`: each preset has its own binary dir
`build/<preset>`, and the loader cache (`_buildkit`), the stage folder (`stage`) and
the installer output (`dist`) live inside it, for example `build/default/_buildkit`. The generated presets and `.gitignore` follow this;
never configure into `build-*` folders or into the source tree.

## Tests of buildkit itself

```bash
cmake --preset tests
ctest --preset tests
```

Every module has fixture projects under `tests/`, configured into `build/tests/`.

## Documentation

| Doc | Topic |
|-----|-------|
| [Adding libraries](docs/ADDING_LIBRARIES.md) | Flat and legacy layout, `create_library`, `generate_libraries`, `generate_project` |
| [CI/CD](docs/CI_CD.md) | Reusable workflows, labels, Beta and main flow, Conan profiles, installer |
| [Migration](docs/MIGRATION.md) | Moving a unitpro based product to buildkit |
| [Contributing](docs/CONTRIBUTING.md) | Working on buildkit itself |

## License

MIT, see [LICENSE](LICENSE).
