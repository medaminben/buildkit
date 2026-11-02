# buildkit test harness.
#
# This top-level project does not build anything itself. Every module has
# small fixture projects under tests/<module>/; each one is registered here
# as a CTest test that configures the fixture into build/tests/<name>.
cmake_minimum_required(VERSION 3.29)
project(buildkit_tests LANGUAGES NONE)

include(CTest)

find_package(Python3 3.11 REQUIRED COMPONENTS Interpreter)

# buildkit_add_fixture_test(NAME <n> DIR <dir> [ARGS <cmake args>...]
#                           [ENV <VAR=value>] [EXPECT_FAIL] [EXPECT_OUTPUT <regex>]
#                           [FORBID_OUTPUT <regex>] [BUILD])
#
# Configures tests/<dir> into build/tests/<n> with -DBUILDKIT_DIR=<buildkit>.
# The binary dir is removed first so every run starts from a clean cache.
# tests/run_fixture.cmake checks exactly (CTest's WILL_FAIL and
# PASS_REGULAR_EXPRESSION are not used):
#   default        configure must succeed
#   EXPECT_FAIL    configure must fail
#   EXPECT_OUTPUT  stdout+stderr of the configure must match the regex
#                  (combinable with EXPECT_FAIL)
#   FORBID_OUTPUT  the output must NOT match the regex
#   BUILD          after a successful configure also run `cmake --build` and
#                  `ctest --test-dir` on the fixture; any failure fails
# ARGS are joined with '|' for transport, so an ARGS element must not contain
# '|' or ';' (CMake lists split on ';'); spaces inside an element are preserved.
function(buildkit_add_fixture_test)
    cmake_parse_arguments(PARSE_ARGV 0 ft "EXPECT_FAIL;BUILD" "NAME;DIR;EXPECT_OUTPUT;FORBID_OUTPUT;ENV" "ARGS")
    if(NOT ft_NAME OR NOT ft_DIR)
        message(FATAL_ERROR "buildkit_add_fixture_test: NAME and DIR are required")
    endif()
    if(ft_BUILD AND ft_EXPECT_FAIL)
        message(FATAL_ERROR
            "buildkit_add_fixture_test: BUILD and EXPECT_FAIL are mutually exclusive")
    endif()
    if(ft_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR
            "buildkit_add_fixture_test: unknown arguments: ${ft_UNPARSED_ARGUMENTS}")
    endif()

    set(src "${CMAKE_SOURCE_DIR}/tests/${ft_DIR}")
    set(bin "${CMAKE_SOURCE_DIR}/build/tests/${ft_NAME}")

    set(joined "")
    set(sep "")
    foreach(a IN LISTS ft_ARGS)
        string(APPEND joined "${sep}${a}")
        set(sep "|")
    endforeach()

    add_test(NAME ${ft_NAME}
        COMMAND ${CMAKE_COMMAND}
            -DFIXTURE_SRC=${src}
            -DFIXTURE_BIN=${bin}
            -DBUILDKIT_DIR=${CMAKE_SOURCE_DIR}
            "-DFIXTURE_ARGS=${joined}"
            "-DFIXTURE_ENV=${ft_ENV}"
            -DEXPECT_FAIL=${ft_EXPECT_FAIL}
            "-DEXPECT_OUTPUT=${ft_EXPECT_OUTPUT}"
            "-DFORBID_OUTPUT=${ft_FORBID_OUTPUT}"
            -DBUILD=${ft_BUILD}
            -P ${CMAKE_SOURCE_DIR}/tests/run_fixture.cmake)
endfunction()

buildkit_add_fixture_test(NAME entry DIR entry EXPECT_OUTPUT "BUILDKIT_ROOT=/")
# Guard: buildkit ships no Common.cmake, so a product's own `include(Common)` is
# never shadowed (fixture checks both module folders and then includes the product's).
buildkit_add_fixture_test(NAME module_path DIR module_path
    EXPECT_OUTPUT "MODULE_PATH_OK product-common")

# Harness self-tests
buildkit_add_fixture_test(NAME harness_ok DIR harness/ok)
buildkit_add_fixture_test(NAME harness_ok_output DIR harness/ok
    ARGS "-DMY_ARG=a b c" EXPECT_OUTPUT "HARNESS_OK arg=\\[a b c\\]")
buildkit_add_fixture_test(NAME harness_fail DIR harness/fail EXPECT_FAIL)
buildkit_add_fixture_test(NAME harness_fail_output DIR harness/fail
    EXPECT_FAIL EXPECT_OUTPUT "package manager")
buildkit_add_fixture_test(NAME harness_build DIR harness/built BUILD)

# dev_dependency (cmake/Dependency.cmake). CMake wraps long messages, so the
# regexes allow a line break (.*) between words.
buildkit_add_fixture_test(NAME dependency_found DIR dependency/found
    EXPECT_OUTPUT "Threads.*installed")
buildkit_add_fixture_test(NAME dependency_missing_optional DIR dependency/missing_optional
    EXPECT_OUTPUT "NoSuchPkg not available \\(not installed,.*no network\\):.*building.*without")
buildkit_add_fixture_test(NAME dependency_missing_required DIR dependency/missing_required
    EXPECT_FAIL EXPECT_OUTPUT "NoSuchPkg not available \\(not installed,.*no network\\):.*cannot.*build.*package manager.*apt.*install.*libnosuchpkg-dev")
buildkit_add_fixture_test(NAME dependency_offline_optional DIR dependency/offline_optional
    ARGS -DBUILDKIT_OFFLINE=ON
    EXPECT_OUTPUT "NoSuchGTestName not available \\(not installed,.*offline\\):.*building.*without")
# The environment alone must switch offline mode on (BUILDKIT_OFFLINE, FETCHCONTENT_FULLY_DISCONNECTED).
buildkit_add_fixture_test(NAME dependency_offline_env DIR dependency/offline_optional
    ENV BUILDKIT_OFFLINE=1
    EXPECT_OUTPUT "NoSuchGTestName not available \\(not installed,.*offline\\):.*building.*without")
buildkit_add_fixture_test(NAME dependency_disconnected_env DIR dependency/offline_optional
    ENV FETCHCONTENT_FULLY_DISCONNECTED=ON
    EXPECT_OUTPUT "NoSuchGTestName not available \\(not installed,.*offline\\):.*building.*without")
set_tests_properties(dependency_offline_env dependency_disconnected_env PROPERTIES TIMEOUT 35)
buildkit_add_fixture_test(NAME dependency_fetch_url DIR dependency/fetch_url
    EXPECT_OUTPUT "tiny: fetched")
buildkit_add_fixture_test(NAME dependency_blackhole_optional DIR dependency/blackhole_optional
    EXPECT_OUTPUT "NoSuchPkg not available")
buildkit_add_fixture_test(NAME dependency_source_dir_override DIR dependency/source_dir_override
    ARGS -DBUILDKIT_OFFLINE=ON
         "-DFETCHCONTENT_SOURCE_DIR_TINY=${CMAKE_SOURCE_DIR}/tests/dependency/data/tiny-src"
    EXPECT_OUTPUT "tiny: local source")
# REQUIRED and offline with no installed copy: stop with the package-manager and install
# hints, and never probe or download.
buildkit_add_fixture_test(NAME dependency_offline_required DIR dependency/missing_required
    EXPECT_FAIL ARGS -DBUILDKIT_OFFLINE=ON
    EXPECT_OUTPUT "NoSuchPkg not available \\(not installed,.*offline\\):.*package manager.*apt install libnosuchpkg-dev"
    FORBID_OUTPUT "probing|downloading http|Downloading|unreachable")
set_tests_properties(dependency_missing_optional dependency_offline_optional
    PROPERTIES TIMEOUT 35)
# A host that drops packets costs the full 30 s probe timeout.
set_tests_properties(dependency_blackhole_optional PROPERTIES TIMEOUT 40 LABELS slow)
add_test(NAME dependency_shallow_check
    COMMAND ${CMAKE_COMMAND} -DBUILDKIT_DIR=${CMAKE_SOURCE_DIR}
            -P ${CMAKE_SOURCE_DIR}/tests/dependency/shallow_check.cmake)

# GoogleTest via dev_dependency (cmake/GTestSupport.cmake, cmake/TestUtils.cmake)
buildkit_add_fixture_test(NAME gtest DIR gtest/on BUILD
    EXPECT_OUTPUT "GTest[^\n]*: (installed|fetched)")
buildkit_add_fixture_test(NAME gtest_off DIR gtest/off EXPECT_OUTPUT "GTEST_UNTOUCHED")

# buildkit_git_version (cmake/GitVersion.cmake)
add_test(NAME version
    COMMAND ${CMAKE_COMMAND} -DBUILDKIT_DIR=${CMAKE_SOURCE_DIR}
            -P ${CMAKE_SOURCE_DIR}/tests/version/run.cmake)

# create_library / generate_libraries layouts (cmake/BuildUtils.cmake,
# cmake/modules/LibraryGenerator.cmake) and the project templates.
buildkit_add_fixture_test(NAME layout_legacy DIR layout/legacy BUILD
    EXPECT_OUTPUT "LAYOUT_LEGACY_OK")
buildkit_add_fixture_test(NAME layout_flat DIR layout/flat BUILD
    EXPECT_OUTPUT "LAYOUT_FLAT_OK")
buildkit_add_fixture_test(NAME layout_generate DIR layout/generate BUILD
    EXPECT_OUTPUT "LAYOUT_GENERATE_OK")
buildkit_add_fixture_test(NAME layout_generate_legacy DIR layout/generate_legacy BUILD
    EXPECT_OUTPUT "LAYOUT_GENERATE_LEGACY_OK")
buildkit_add_fixture_test(NAME layout_project DIR layout/project BUILD
    EXPECT_OUTPUT "LAYOUT_PROJECT_OK")

# Install the flat layout and consume it with find_package + Vision::Vision.
add_test(NAME install_flat
    COMMAND ${CMAKE_COMMAND} -DBUILDKIT_DIR=${CMAKE_SOURCE_DIR}
            -DWORK_DIR=${CMAKE_SOURCE_DIR}/build/tests/install_flat
            -P ${CMAKE_SOURCE_DIR}/tests/install_flat/run.cmake)
set_tests_properties(install_flat PROPERTIES PASS_REGULAR_EXPRESSION "INSTALL_FLAT_OK")

# Loader (loader/buildkit.cmake); fetch cases use a file:// repo built under build/.
foreach(case local env sibling bad_dir offline twice fetch cached_offline
                disconnected stale_offline tagchange dead_cached
                offline_env cached_offline_env disconnected_env)
    add_test(NAME loader_${case}
        COMMAND ${CMAKE_COMMAND} -DCASE=${case} -DBUILDKIT_REPO=${CMAKE_SOURCE_DIR}
                -P ${CMAKE_SOURCE_DIR}/tests/loader/run_case.cmake)
endforeach()

# Packaging (cmake/Packaging.cmake): stage target; no ISCC on this machine, so the
# installer target must be absent with a status message.
buildkit_add_fixture_test(NAME packaging DIR packaging BUILD
    ARGS -DBUILDKIT_ISCC=/nonexistent/ISCC.exe
    EXPECT_OUTPUT "PACKAGING_OK")
buildkit_add_fixture_test(NAME packaging_no_iscc_message DIR packaging
    ARGS -DBUILDKIT_ISCC=/nonexistent/ISCC.exe
    EXPECT_OUTPUT "pkgapp_installer: ISCC not found.*skipped")

# Installer command through a fake wine (found-ISCC path; no real wine/ISCC needed).
foreach(c version_arg full name_full plain)
    buildkit_add_fixture_test(NAME packaging_installer_${c} DIR packaging_installer BUILD
        ARGS -DCASE=${c}
             "-DBUILDKIT_WINE=${CMAKE_SOURCE_DIR}/tests/packaging_installer/fake/wine"
             "-DBUILDKIT_ISCC=${CMAKE_SOURCE_DIR}/tests/packaging_installer/fake/ISCC.exe")
endforeach()
buildkit_add_fixture_test(NAME packaging_installer_search DIR packaging_installer BUILD
    ARGS -DCASE=search
         "-DBUILDKIT_WINE=${CMAKE_SOURCE_DIR}/tests/packaging_installer/fake/wine")

# Release version tool (tools/release/next_version.py). -B keeps __pycache__ out of
# the source tree; -I keeps the script directory and cwd off sys.path.
add_test(NAME release_tool
    COMMAND ${Python3_EXECUTABLE} -B -I -m unittest discover
            -s ${CMAKE_CURRENT_SOURCE_DIR}/tools/release -p "test_*.py" -v)

# The buildkit version pins (workflows, loader, Buildkit.cmake, docs) must agree.
add_test(NAME release_pins
    COMMAND ${Python3_EXECUTABLE} -B -I ${CMAKE_CURRENT_SOURCE_DIR}/tests/release_pins/check_pins.py
            ${CMAKE_CURRENT_SOURCE_DIR})

# Manual builder (tools/manual/build_manual.py) and its fixture project.
add_test(NAME manual_tool
    COMMAND ${Python3_EXECUTABLE} -B -I -m unittest discover
            -s ${CMAKE_CURRENT_SOURCE_DIR}/tools/manual -p "test_*.py" -v)
buildkit_add_fixture_test(NAME manual DIR manual BUILD)
