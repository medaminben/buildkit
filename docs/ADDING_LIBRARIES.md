# Adding libraries and applications

## Two layouts

The layout follows `CMAKE_ROOT_NAME`. Set before the libraries are added, it
selects the legacy layout (existing products such as Bowlingbox); unset, the
flat layout is used. New products use the flat layout.

| | Flat (`CMAKE_ROOT_NAME` unset) | Legacy (`CMAKE_ROOT_NAME` = `Root`) |
|---|---|---|
| Target | `<Lib>` | `<root>_<lib>` (lower case) |
| Alias | `<Lib>::<Lib>` | `<Root>::<Lib>` |
| Public header | `include/<Lib>/<Lib>.h` | `include/<Root>/<Lib>/<Lib>.h` |
| Namespace | `<Lib>` | `<Root>::<Lib>` |
| Export header | `include/<Lib>/<Lib>_export.h` | `<Root>_<Lib>_export.h` |
| Export macro | `<LIB>_API` | `<ROOT>_<LIB>_API` |
| Test executable | `test_<lib>` | `test_<root>_<lib>` |
| Install export set | `<CMAKE_PROJECT_NAME>Targets` | `<Root>Targets` |
| Warning level (default) | strict | base |

Export headers are generated in the build tree, never in the source tree.

## `create_library`

```cmake
create_library(
    LIB_NAME             Math
    LIB_FILES            ${MATH_FILES}
    PUBLIC_DEPENDENCIES  Other::Dep
    PRIVATE_DEPENDENCIES Some::Dep
    TEST_DISCOVER        ON
    TEST_SOURCES         ${MATH_TEST_SOURCES}
    TEST_DEPENDENCIES    GTest::gtest GTest::gtest_main
    LIB_RSC              test/data/MathTestData.txt
)
```

- PUBLIC dependencies are inherited by consumers, PRIVATE ones only by the library.
- `LIB_RSC` files are copied to `data/<target>/` of the build output; discovered tests
  run in `bin/` and open `../data/<target>/<file>`.
- Warnings are applied with `buildkit_set_warnings`.

## `create_application`

```cmake
create_application(NAME MathConsole ENTRY Console
    SOURCES MathConsole.cpp DEPENDENCIES Math::Math)
```

`ENTRY` is `Console` or `WX_ui` (a WIN32 or bundle executable). A product that
defines `BUILD_WX_UI` guards `WX_ui` calls with `if(BUILD_WX_UI)`. `COMPONENT`
puts the app into a named install component.

## `generate_libraries`

```cmake
set(MYAPP_LIBRARIES Core Math)
generate_libraries(
    LIBRARIES_LIST     ${MYAPP_LIBRARIES}
    LIBRARIES_LOCATION ${CMAKE_CURRENT_SOURCE_DIR}/libraries
    APPS_LOCATION      ${CMAKE_CURRENT_SOURCE_DIR}/applications
    TEMPLATE_LOCATION  ${BUILDKIT_ROOT}/template)
```

For each name without a folder under `LIBRARIES_LOCATION` it writes the library
(CMakeLists, public header, sources, a GoogleTest file) and appends
`add_subdirectory(<Lib>)` to `libraries/CMakeLists.txt`. With `APPS_LOCATION` it
also writes a console app and a wxWidgets app (the latter builds only when
wxWidgets is found). Existing folders are never touched. Set
`-DGENERATE_SCAFFOLD=OFF` in a product that manages its trees by hand.

A product template folder with the pre-buildkit file names still works.
Templates are configured with `${var}` substitution; `${VAR_MARKER_START}x${VAR_MARKER_END}`
writes a literal `${x}`.

## `generate_project`

```cmake
generate_project(NAME MyApp DESTINATION ${dir} LIBRARIES Core)
```

Writes `CMakeLists.txt`, `CMakePresets.json` and `.gitignore` from
`template/project/`, and copies `loader/buildkit.cmake` to `cmake/buildkit.cmake`.
Existing files are kept. The presets are `default`, `debug`, `coverage`, `asan`
and `ci`, all with their binary dir under `build/`.

## Checklist for a library

- [ ] Public headers in `include/`, implementation details in `src/`
- [ ] Unit tests cover the happy path and edge cases
- [ ] No includes from another library's `src/`
- [ ] CI green
