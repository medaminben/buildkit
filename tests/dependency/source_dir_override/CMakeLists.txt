cmake_minimum_required(VERSION 3.29)
project(dep_source_dir_override LANGUAGES NONE)
include(${BUILDKIT_DIR}/cmake/Buildkit.cmake)

# Run with -DBUILDKIT_OFFLINE=ON -DFETCHCONTENT_SOURCE_DIR_TINY=<data/tiny-src>:
# the local source wins over the offline check and the (unreachable) URL.
dev_dependency(tiny REQUIRED FETCH_URL http://127.0.0.1:9/tiny.zip)
if(NOT tiny_AVAILABLE OR NOT TARGET tiny)
    message(FATAL_ERROR "tiny not available from FETCHCONTENT_SOURCE_DIR_TINY")
endif()
if(EXISTS "${CMAKE_BINARY_DIR}/_downloads")
    message(FATAL_ERROR "a local source must not trigger a download")
endif()
