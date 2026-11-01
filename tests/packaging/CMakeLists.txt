# Packaging: <app>_stage installs into a stage dir that contains a space;
# with no usable ISCC the <app>_installer target must not exist (status only).
cmake_minimum_required(VERSION 3.29)
project(PackagingFix VERSION 1.2.3 LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
include(${BUILDKIT_DIR}/cmake/Buildkit.cmake)
include(CTest)

add_executable(pkgapp main.cpp)
install(TARGETS pkgapp RUNTIME DESTINATION bin)

buildkit_add_stage_target(pkgapp STAGE_DIR "${CMAKE_BINARY_DIR}/stage dir")
buildkit_add_inno_installer(pkgapp ISS "${CMAKE_SOURCE_DIR}/app.iss"
    DEFINES "AppName=Pkg App")

if(NOT TARGET pkgapp_stage)
    message(FATAL_ERROR "pkgapp_stage missing")
endif()
if(TARGET pkgapp_installer)
    message(FATAL_ERROR "pkgapp_installer must not exist without ISCC")
endif()

add_test(NAME stage_has_app
    COMMAND ${CMAKE_COMMAND}
        -DBIN_DIR=${CMAKE_BINARY_DIR} -DAPP=pkgapp
        "-DEXPECTED=${CMAKE_BINARY_DIR}/stage dir/bin/pkgapp${CMAKE_EXECUTABLE_SUFFIX}"
        -P ${CMAKE_SOURCE_DIR}/check_stage.cmake)
message(STATUS "PACKAGING_OK")
