# buildkit loader. A product keeps a copy as cmake/buildkit.cmake and includes
# it BEFORE project():
#
#   cmake_minimum_required(VERSION 3.29)
#   include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/buildkit.cmake)
#   project(MyProduct ...)
#
# buildkit is taken from, in this order:
#   1. BUILDKIT_DIR (cache entry, e.g. -DBUILDKIT_DIR=..., or environment)
#   2. ${CMAKE_SOURCE_DIR}/../buildkit, if it contains cmake/Buildkit.cmake
#   3. a git fetch of BUILDKIT_REPO at BUILDKIT_TAG into
#      ${CMAKE_BINARY_DIR}/_buildkit (populate only, nothing is built)
# and Buildkit.cmake is included. BUILDKIT_TAG may be set before including.
#
# Offline (BUILDKIT_OFFLINE or FETCHCONTENT_FULLY_DISCONNECTED ON) with no
# local copy is a FATAL_ERROR: buildkit itself is required. A fetch that cannot
# reach the remote (30 s probe) is a FATAL_ERROR too.
#
# Needs no compiler, so it works before project(). Idempotent.
include_guard(GLOBAL)

if(NOT DEFINED BUILDKIT_TAG)
    set(BUILDKIT_TAG "v2.0.0")
endif()
if(NOT DEFINED BUILDKIT_REPO)
    set(BUILDKIT_REPO "https://github.com/medaminben/buildkit.git")
endif()

set(_bk_from "")
if(NOT BUILDKIT_DIR AND DEFINED ENV{BUILDKIT_DIR})
    set(BUILDKIT_DIR "$ENV{BUILDKIT_DIR}")
endif()

if(BUILDKIT_DIR)
    if(NOT EXISTS "${BUILDKIT_DIR}/cmake/Buildkit.cmake")
        message(FATAL_ERROR
            "buildkit: BUILDKIT_DIR is '${BUILDKIT_DIR}', but "
            "${BUILDKIT_DIR}/cmake/Buildkit.cmake does not exist")
    endif()
    set(_bk_from "local working copy")
elseif(EXISTS "${CMAKE_SOURCE_DIR}/../buildkit/cmake/Buildkit.cmake")
    get_filename_component(BUILDKIT_DIR "${CMAKE_SOURCE_DIR}/../buildkit" ABSOLUTE)
    set(_bk_from "local working copy")
else()
    if(BUILDKIT_OFFLINE OR FETCHCONTENT_FULLY_DISCONNECTED)
        message(FATAL_ERROR
            "buildkit: no local copy and offline mode is on. Set BUILDKIT_DIR to "
            "a buildkit checkout, or put one at ${CMAKE_SOURCE_DIR}/../buildkit. "
            "Install the tools with redev/bootstrap/bootstrap.sh")
    endif()
    set(_bk_src "${CMAKE_BINARY_DIR}/_buildkit/src")
    find_package(Git QUIET)
    if(NOT GIT_EXECUTABLE)
        message(FATAL_ERROR
            "buildkit: git not found, cannot fetch ${BUILDKIT_REPO}. Set "
            "BUILDKIT_DIR or install git (redev/bootstrap/bootstrap.sh)")
    endif()
    # Probe first so a dead network fails in 30 s and not after minutes.
    execute_process(
        COMMAND ${CMAKE_COMMAND} -E env GIT_TERMINAL_PROMPT=0
                "${GIT_EXECUTABLE}" ls-remote --exit-code "${BUILDKIT_REPO}" "${BUILDKIT_TAG}"
        RESULT_VARIABLE _bk_rc OUTPUT_QUIET ERROR_QUIET TIMEOUT 30)
    if(NOT _bk_rc EQUAL 0 AND NOT EXISTS "${_bk_src}/cmake/Buildkit.cmake")
        message(FATAL_ERROR
            "buildkit: cannot reach ${BUILDKIT_REPO} (tag ${BUILDKIT_TAG}). Set "
            "BUILDKIT_DIR to a local checkout (redev/bootstrap/bootstrap.sh)")
    endif()
    if(_bk_rc EQUAL 0)
        include(FetchContent)
        set(_bk_old_base "${FETCHCONTENT_BASE_DIR}")
        set(FETCHCONTENT_BASE_DIR "${CMAKE_BINARY_DIR}/_buildkit")
        FetchContent_Declare(buildkit_src
            GIT_REPOSITORY "${BUILDKIT_REPO}"
            GIT_TAG        "${BUILDKIT_TAG}"
            GIT_SHALLOW    TRUE
            SOURCE_DIR     "${_bk_src}"
            SOURCE_SUBDIR  buildkit_populate_only)  # folder does not exist: no add_subdirectory
        FetchContent_MakeAvailable(buildkit_src)
        if(_bk_old_base)
            set(FETCHCONTENT_BASE_DIR "${_bk_old_base}")
        else()
            unset(FETCHCONTENT_BASE_DIR)
        endif()
    endif()
    set(BUILDKIT_DIR "${_bk_src}")
    set(_bk_from "tag ${BUILDKIT_TAG}")
endif()

message(STATUS "buildkit: using ${BUILDKIT_DIR} (${_bk_from})")
include("${BUILDKIT_DIR}/cmake/Buildkit.cmake")
unset(_bk_from)
