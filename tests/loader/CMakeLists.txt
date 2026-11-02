# Fixture for loader/buildkit.cmake. tests/loader/run_case.cmake copies it to
# <work>/app together with the loader (as cmake/buildkit.cmake, like a product
# does) and configures it. The loader is included before project().
cmake_minimum_required(VERSION 3.29)

include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/buildkit.cmake)
if(LOADER_TWICE)
    include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/buildkit.cmake)
endif()

project(loader_fixture LANGUAGES NONE)

buildkit_git_version(${CMAKE_CURRENT_SOURCE_DIR} FIX_VERSION FIX_VERSION_FULL FALLBACK 0.1.0)
message(STATUS "LOADER_OK version=${FIX_VERSION} root=${BUILDKIT_ROOT}")
