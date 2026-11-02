# Installer command: a fake wine records the ISCC argv; CASE selects what is checked.
#   version_arg  VERSION wins over PROJECT_VERSION_FULL; relative ISS/OUTPUT_DIR
#   full         PROJECT_VERSION_FULL used
#   name_full    only ${PROJECT_NAME}_VERSION_FULL set: used
#   plain        PROJECT_VERSION used
#   search       ISCC found via BUILDKIT_ISCC_HINTS (BUILDKIT_ISCC unset)
cmake_minimum_required(VERSION 3.29)
project(PkgInstFix VERSION 1.2.3 LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
include(${BUILDKIT_DIR}/cmake/Buildkit.cmake)
include(CTest)

add_executable(pkgapp ../packaging/main.cpp)
install(TARGETS pkgapp RUNTIME DESTINATION bin)
buildkit_add_stage_target(pkgapp STAGE_DIR "${CMAKE_BINARY_DIR}/stage dir")

set(out_args)
set(expect_version 1.2.3)
set(expect_out "${CMAKE_BINARY_DIR}/dist")
set(ver_args)
if(CASE STREQUAL "version_arg")
    set(PROJECT_VERSION_FULL 9.9.9-full)
    set(ver_args VERSION 5.0.0-arg)
    set(out_args OUTPUT_DIR "out dir")
    set(expect_version 5.0.0-arg)
    set(expect_out "${CMAKE_BINARY_DIR}/out dir")
elseif(CASE STREQUAL "full")
    set(PROJECT_VERSION_FULL 9.9.9-full)
    set(expect_version 9.9.9-full)
elseif(CASE STREQUAL "name_full")
    set(${PROJECT_NAME}_VERSION_FULL 8.8.8-name)
    set(expect_version 8.8.8-name)
elseif(NOT CASE STREQUAL "plain" AND NOT CASE STREQUAL "search")
    message(FATAL_ERROR "unknown CASE '${CASE}'")
endif()
if(CASE STREQUAL "search")
    set(BUILDKIT_ISCC_HINTS "${CMAKE_SOURCE_DIR}/fake")
endif()

buildkit_add_inno_installer(pkgapp ISS app.iss DEFINES "AppName=Pkg App" ${ver_args} ${out_args})
if(NOT TARGET pkgapp_installer)
    message(FATAL_ERROR "pkgapp_installer missing")
endif()
if(CASE STREQUAL "search")
    if(NOT BUILDKIT_ISCC STREQUAL "${CMAKE_SOURCE_DIR}/fake/ISCC.exe")
        message(FATAL_ERROR "search result not cached: '${BUILDKIT_ISCC}'")
    endif()
endif()

add_test(NAME installer_argv
    COMMAND ${CMAKE_COMMAND}
        -DBIN_DIR=${CMAKE_BINARY_DIR} -DSRC_DIR=${CMAKE_SOURCE_DIR}
        -DEXPECT_VERSION=${expect_version} "-DEXPECT_OUT=${expect_out}"
        -P ${CMAKE_SOURCE_DIR}/check_argv.cmake)
