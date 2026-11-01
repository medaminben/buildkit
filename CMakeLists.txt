# buildkit test harness.
#
# This top-level project does not build anything itself. Every module has
# small fixture projects under tests/<module>/; each one is registered here
# as a CTest test that configures the fixture into build/tests/<name>.
cmake_minimum_required(VERSION 3.29)
project(buildkit_tests LANGUAGES NONE)

include(CTest)

# buildkit_add_fixture_test(NAME <n> DIR <dir> [ARGS <cmake args>...]
#                           [EXPECT_FAIL] [EXPECT_OUTPUT <regex>] [BUILD])
#
# Configures tests/<dir> into build/tests/<n> with -DBUILDKIT_DIR=<buildkit>.
# The binary dir is removed first so every run starts from a clean cache.
# tests/run_fixture.cmake checks exactly (CTest's WILL_FAIL and
# PASS_REGULAR_EXPRESSION are not used):
#   default        configure must succeed
#   EXPECT_FAIL    configure must fail
#   EXPECT_OUTPUT  stdout+stderr of the configure must match the regex
#                  (combinable with EXPECT_FAIL)
#   BUILD          after a successful configure also run `cmake --build` and
#                  `ctest --test-dir` on the fixture; any failure fails
# ARGS are joined with '|' for transport, so an ARGS element must not contain
# '|' or ';' (CMake lists split on ';'); spaces inside an element are preserved.
function(buildkit_add_fixture_test)
    cmake_parse_arguments(PARSE_ARGV 0 ft "EXPECT_FAIL;BUILD" "NAME;DIR;EXPECT_OUTPUT" "ARGS")
    if(NOT ft_NAME OR NOT ft_DIR)
        message(FATAL_ERROR "buildkit_add_fixture_test: NAME and DIR are required")
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
            -DEXPECT_FAIL=${ft_EXPECT_FAIL}
            "-DEXPECT_OUTPUT=${ft_EXPECT_OUTPUT}"
            -DBUILD=${ft_BUILD}
            -P ${CMAKE_SOURCE_DIR}/tests/run_fixture.cmake)
endfunction()

buildkit_add_fixture_test(NAME entry DIR entry EXPECT_OUTPUT "BUILDKIT_ROOT=/")

# Harness self-tests
buildkit_add_fixture_test(NAME harness_ok DIR harness/ok)
buildkit_add_fixture_test(NAME harness_ok_output DIR harness/ok
    ARGS "-DMY_ARG=a b c" EXPECT_OUTPUT "HARNESS_OK arg=\\[a b c\\]")
buildkit_add_fixture_test(NAME harness_fail DIR harness/fail EXPECT_FAIL)
buildkit_add_fixture_test(NAME harness_fail_output DIR harness/fail
    EXPECT_FAIL EXPECT_OUTPUT "bootstrap.sh")
buildkit_add_fixture_test(NAME harness_build DIR harness/build BUILD)
