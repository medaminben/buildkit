# buildkit test harness.
#
# This top-level project does not build anything itself. Every module has
# small fixture projects under tests/<module>/; each one is registered here
# as a CTest test that configures the fixture into build/tests/<name>.
cmake_minimum_required(VERSION 3.29)
project(buildkit_tests LANGUAGES NONE)

include(CTest)

# buildkit_add_fixture_test(NAME <n> DIR <dir> [ARGS <cmake args>...]
#                           [EXPECT_FAIL] [EXPECT_OUTPUT <regex>])
#
# Configures tests/<dir> into build/tests/<n> with -DBUILDKIT_DIR=<buildkit>.
# The binary dir is removed first so every run starts from a clean cache.
# EXPECT_FAIL: the configure must fail. EXPECT_OUTPUT: the output must match.
function(buildkit_add_fixture_test)
    cmake_parse_arguments(PARSE_ARGV 0 ft "EXPECT_FAIL" "NAME;DIR;EXPECT_OUTPUT" "ARGS")
    if(NOT ft_NAME OR NOT ft_DIR)
        message(FATAL_ERROR "buildkit_add_fixture_test: NAME and DIR are required")
    endif()
    if(ft_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR
            "buildkit_add_fixture_test: unknown arguments: ${ft_UNPARSED_ARGUMENTS}")
    endif()

    set(src "${CMAKE_SOURCE_DIR}/tests/${ft_DIR}")
    set(bin "${CMAKE_SOURCE_DIR}/build/tests/${ft_NAME}")

    add_test(NAME ${ft_NAME}
        COMMAND ${CMAKE_COMMAND}
            -DFIXTURE_SRC=${src}
            -DFIXTURE_BIN=${bin}
            -DBUILDKIT_DIR=${CMAKE_SOURCE_DIR}
            "-DFIXTURE_ARGS=${ft_ARGS}"
            -P ${CMAKE_SOURCE_DIR}/tests/run_fixture.cmake)

    if(ft_EXPECT_FAIL)
        set_tests_properties(${ft_NAME} PROPERTIES WILL_FAIL TRUE)
    endif()
    if(ft_EXPECT_OUTPUT)
        set_tests_properties(${ft_NAME} PROPERTIES
            PASS_REGULAR_EXPRESSION "${ft_EXPECT_OUTPUT}")
    endif()
endfunction()

buildkit_add_fixture_test(NAME entry DIR entry EXPECT_OUTPUT "BUILDKIT_ROOT=/")
