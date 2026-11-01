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

On your machine set `BUILDKIT_DIR` to the buildkit checkout (or keep a sibling
folder `../buildkit`). CI and fresh clones fetch the pinned tag; set
`BUILDKIT_TAG` before the include to choose another.

## 2. Delete the old copies

Remove these from the product's `cmake/` (buildkit provides them; the loader puts
its folders on `CMAKE_MODULE_PATH`):

- `BuildUtils.cmake`, `BuildLocation.cmake`, `DebugUtils.cmake`
- `TestUtils.cmake`, GoogleTest support (`GTestSupport.cmake`)
- `modules/CompilerWarnings.cmake`, `modules/Coverage.cmake`, `modules/LibraryGenerator.cmake`
- any hand written `FetchContent` blocks for third-party code (see step 5)

Keep product specific files: `cmake/<Root>Config.cmake.in` (`InstallConfig` prefers it
over buildkit's template), `cmake/configs/`, and the product's own templates.

## 3. Rename

- `<x>_set_warnings(target)` becomes `buildkit_set_warnings(target)`. The legacy layout keeps
  the base warning level; set `BUILDKIT_STRICT_WARNINGS ON` to opt in to strict.
- Version: replace the hand written version with
  `buildkit_git_version(${CMAKE_CURRENT_SOURCE_DIR} <ROOT>_VERSION <ROOT>_VERSION_FULL FALLBACK <x.y.z>)`
  before `project()`, and tag releases `vX.Y.Z`.
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
(`REQUIRED`). `-DBUILDKIT_OFFLINE=ON` forbids any download.

## 6. CI

Replace the product's own workflows with callers of `ci.yml`, `codeql.yml` and
`release.yml` (examples with permissions in [CI_CD.md](CI_CD.md)). Create the
labels `semver:major`, `semver:minor`, `semver:patch` and `semver:none`, and
a `Beta` branch if you use the beta flow. The installer workflow, if any, needs
`on: workflow_dispatch`.

## 7. Packaging and manual

Use `buildkit_add_stage_target` and `buildkit_add_inno_installer` instead of
local installer code. Product specific installer pieces stay in the product: a
WIN32 `LICENSE` install, the `.iss` script and runtime data are passed through
`INSTALL_SCRIPTS` and `ISS`. A user manual can use `buildkit_add_manual`; it ships inside the installer and must work offline, so any `http://` or `https://` URL in a page fails the check, and a backtick span is always an application label, never inline code.

## 8. Verify

Configure, build and run all tests with the `ci` preset. The test count and the
executables must match the state before the migration.
