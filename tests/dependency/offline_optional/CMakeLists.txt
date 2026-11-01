cmake_minimum_required(VERSION 3.29)
project(dep_offline_optional LANGUAGES NONE)
include(${BUILDKIT_DIR}/cmake/Buildkit.cmake)

# Reachable source, but BUILDKIT_OFFLINE=ON must keep configure off the network.
dev_dependency(NoSuchGTestName OPTIONAL
    FETCH_GIT https://github.com/google/googletest.git FETCH_TAG v1.15.2
    FOUND_VAR HAVE_IT)
if(NOT DEFINED HAVE_IT OR HAVE_IT)
    message(FATAL_ERROR "HAVE_IT must be FALSE, is '${HAVE_IT}'")
endif()
if(EXISTS "${CMAKE_BINARY_DIR}/_deps/nosuchgtestname-src")
    message(FATAL_ERROR "offline configure populated a source tree")
endif()
