# Migrating a unitpro based product to buildkit

This guide is for a product that copied unitpro's `cmake/` folder and sets
`CMAKE_ROOT_NAME` (the legacy layout). Bowlingbox is the first adopter. The legacy
layout keeps working: targets, aliases, headers and namespaces do not change.

## 1. Add the loader

Copy `loader/buildkit.cmake` from buildkit to `cmake/buildkit.cmake` and include
it as the first thing after `cmake_minimum_required`, before `project()`:

```cmake
cmake_minimum_required(VERSION 3.29)
include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/buildkit.cmake)
```

Then put the product's own `cmake/` folder first on the module path, after the
loader and before the first `include()` of a module:

```cmake
list(PREPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
```

The loader appends buildkit's folders, so a module of the same name in the product
wins with `PREPEND`. Without it, the product's copy of `GitVersion`, `InstallConfig` or
`Coverage` would shadow buildkit's (delete them in step 2 instead), and a product
`Common.cmake` is only found if no buildkit module has that name (buildkit has none).

On your machine set `BUILDKIT_DIR` to the buildkit checkout (or keep a sibling
folder `../buildkit`). CI and fresh clones fetch the pinned tag; set
`BUILDKIT_TAG` before the include to choose another (a tag or a branch name, not a
commit SHA). The reusable `ci.yml` checks buildkit out at `buildkit-ref` and sets
`BUILDKIT_DIR` itself, so a product needs no `BUILDKIT_TAG` default to use a
pre-release buildkit in CI.

## 2. Delete the old copies

Remove these from the product's `cmake/` (buildkit provides them; the loader puts
its folders on `CMAKE_MODULE_PATH`):

- `BuildUtils.cmake`, `BuildLocation.cmake`, `DebugUtils.cmake`
- `TestUtils.cmake`, GoogleTest support (`GTestSupport.cmake`)
- `GitVersion.cmake` (replaced by `buildkit_git_version`, step 3)
- `modules/CompilerWarnings.cmake`, `modules/Coverage.cmake`, `modules/LibraryGenerator.cmake`,
  `modules/InstallConfig.cmake` (buildkit's `InstallConfig` takes over and uses
  `cmake/<Root>Config.cmake.in`)
- the project templates (`template/` or `cmake/template/`) if they are copies of the
  pre-buildkit ones: buildkit's `template/` is the default, so also drop a
  `TEMPLATE_LOCATION` argument. Keep a template only if you changed it on purpose.
- scripts that parse the removed files, for example a release script that read the
  fallback version from `GitVersion.cmake`; point them at the `FALLBACK` line of the root
  `CMakeLists.txt`
- any hand written `FetchContent` blocks for third-party code (see step 5)

Keep product specific files: `cmake/<Root>Config.cmake.in` (`InstallConfig` prefers it
over buildkit's template), `cmake/configs/`, a product `Common.cmake` with product
options, and templates that differ on purpose. A product `Common.cmake` no longer
includes the generic modules: the loader does that.

Same-named copies matter: a product copy of `GitVersion`, `InstallConfig` or `Coverage`
that stays in `cmake/` shadows buildkit's as soon as `cmake/` is first on the module path
(step 1), and then you get the old behaviour without any message. Delete them.

`Coverage` must be included again after `project()`: the loader includes it before
`project()`, where it has no compiler to look at and does nothing. Put `include(Coverage)`
in the product (usually at the end of its `Common.cmake`, which is included after `project()`).

## 3. Rename

- `<x>_set_warnings(target)` becomes `buildkit_set_warnings(target)`. The legacy layout keeps
  the base warning level; set `BUILDKIT_STRICT_WARNINGS ON` to opt in to strict.
- Version: replace the hand written version with
  `buildkit_git_version(${CMAKE_CURRENT_SOURCE_DIR} <ROOT>_VERSION <ROOT>_VERSION_FULL FALLBACK <x.y.z>)`
  before `project()`, and tag releases `vX.Y.Z`. The function prints nothing and has no
  `-D<ROOT>_VERSION` override. Keep an override and print the line yourself:

  ```cmake
  if(NOT <ROOT>_VERSION)
      buildkit_git_version(${CMAKE_CURRENT_SOURCE_DIR} <ROOT>_VERSION <ROOT>_VERSION_FULL FALLBACK <x.y.z>)
  endif()
  # after project(), if the product printed a version before:
  message(STATUS "<Product> version: ${<ROOT>_VERSION_FULL}")
  ```
- `include(InstallConfig)` stays an explicit include after the libraries are added.
- Keep `CMAKE_ROOT_NAME` and `<ROOT>_RUNTIME_COMPONENT`; they select the legacy layout
  and the install component.

## 4. Presets

Use the presets of `template/project/CMakePresets.json.in` (`default`, `debug`,
`coverage`, `asan`, `ci`) with `binaryDir` `${sourceDir}/build/<name>`. Remove any
`build-*` folder or in-tree build from the product and ignore `build/` in its `.gitignore`.

## 5. Dependencies

Replace direct `find_package` plus `FetchContent` code with `dev_dependency()`:
installed first, then fetched, then built without (`OPTIONAL`) or an error
(`REQUIRED`). `-DBUILDKIT_OFFLINE=ON` (or `BUILDKIT_OFFLINE=1` in the environment) forbids
any download. The `REQUIRED` error names the CMake package; add
`INSTALL_HINT "apt install libfoo-dev"` to name the distribution package too. The old
`FETCHCONTENT_FULLY_DISCONNECTED` environment variable is honoured by `dev_dependency`
and the loader, so a product no longer needs its own code for it.

## 6. CI

Replace the product's own workflows with callers of `ci.yml`, `codeql.yml` and
`release.yml` (examples with permissions in [CI_CD.md](CI_CD.md)). Create the
labels `semver:major`, `semver:minor`, `semver:patch` and `semver:none`, and
a `Beta` branch if you use the beta flow. The installer workflow, if any, needs
`on: workflow_dispatch`.

Check what the old workflows did that the reusable one cannot do as a step, and move it:

- GUI tests that needed `xvfb-run`: set `xvfb: true`.
- Vendored code that clang-format must skip: `format-exclude: "3rdparty/**"`.
- An install smoke test (or any other extra check): register it as a ctest test in the
  product with a label such as `install`, so that every preset runs it. There is no step hook.
- Extra `-D` options for the configure: `configure-args`.
- Pre-release buildkit: set `buildkit-ref`; `ci.yml` and `codeql.yml` check it out and set
  `BUILDKIT_DIR`. Do not keep a temporary `BUILDKIT_REPOSITORY`/`BUILDKIT_TAG` default in
  the product's CMakeLists.
- Lint: `lint: false` switches all three checks off; use `lint-format`, `lint-cmake` and
  `lint-commits` to pick single checks.

## 7. Packaging and manual

Use `buildkit_add_stage_target` and `buildkit_add_inno_installer` instead of
local installer code. Product specific installer pieces stay in the product: a
WIN32 `LICENSE` install, the `.iss` script and runtime data are passed through
`INSTALL_SCRIPTS` and `ISS`. A product that keeps its own installer
script still needs its WIN32 `install()` rules (for example `LICENSE`) in its own CMake,
in the product's `Common.cmake`: a `-C` initial-cache file such as `windows-installer.cmake`
is only read to preset cache variables, and `install()` does not work there.

A user manual can use `buildkit_add_manual`; it ships inside the installer and must work offline, so any `http://` or `https://` URL in a page fails the check, and a backtick span is always an application label, never inline code.

## 8. Verify

Configure, build and run all tests with the `ci` preset. The test count and the
executables must match the state before the migration.
