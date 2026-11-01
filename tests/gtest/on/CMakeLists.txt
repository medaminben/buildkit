cmake_minimum_required(VERSION 3.29)
project(gtest_on LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
include(${BUILDKIT_DIR}/cmake/Buildkit.cmake)
include(CTest)

# GoogleTest is resolved by dev_dependency on the first call (installed, else fetched).
build_gtest_executable(NAME test_tiny SRC test_tiny.cpp DEPENDS GTest::gtest_main)
if(NOT TARGET test_tiny OR NOT TARGET GTest::gtest_main)
    message(FATAL_ERROR "GoogleTest not available after build_gtest_executable")
endif()
