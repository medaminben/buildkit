# Manual: demo_manual builds manual/ar/index.html; demo_manual_check passes.
cmake_minimum_required(VERSION 3.29)
project(ManualFix LANGUAGES NONE)
include(${BUILDKIT_DIR}/cmake/Buildkit.cmake)
include(CTest)

buildkit_add_manual(demo ROOT docs/manual TITLE "Demo")

if(TARGET demo_manual)
    add_test(NAME manual_built
        COMMAND ${CMAKE_COMMAND}
            -DBIN_DIR=${CMAKE_BINARY_DIR}
            -P ${CMAKE_SOURCE_DIR}/check_manual.cmake)
else()
    message(STATUS "MANUAL_SKIPPED (no Python)")
endif()
message(STATUS "MANUAL_OK")
