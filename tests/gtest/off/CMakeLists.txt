cmake_minimum_required(VERSION 3.29)
project(gtest_off LANGUAGES NONE)
set(BUILD_TESTING OFF)
include(${BUILDKIT_DIR}/cmake/Buildkit.cmake)

# Including buildkit must not resolve GoogleTest by itself.
if(NOT COMMAND build_gtest_executable)
    message(FATAL_ERROR "build_gtest_executable is not defined")
endif()
if(TARGET GTest::gtest OR EXISTS "${CMAKE_BINARY_DIR}/_deps/gtest-src"
   OR DEFINED BUILDKIT_GTEST_AVAILABLE)
    message(FATAL_ERROR "including buildkit resolved GoogleTest")
endif()
message(STATUS "GTEST_UNTOUCHED")
