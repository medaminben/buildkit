# Flat layout: no CMAKE_ROOT_NAME, so create_library gives Vision::Vision,
# include/Vision/Vision_export.h, VISION_API and OUTPUT_NAME Vision.
cmake_minimum_required(VERSION 3.29)
project(LayoutFlat VERSION 0.3.0 LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
include(${BUILDKIT_DIR}/cmake/Buildkit.cmake)
include(CTest)

add_subdirectory(Vision)

if(NOT TARGET Vision::Vision)
    message(FATAL_ERROR "Vision::Vision missing")
endif()
get_target_property(out Vision OUTPUT_NAME)
if(NOT out STREQUAL "Vision")
    message(FATAL_ERROR "flat OUTPUT_NAME wrong: ${out}")
endif()
set(hdr "${CMAKE_BINARY_DIR}/Vision/include/Vision/Vision_export.h")
if(NOT EXISTS "${hdr}")
    message(FATAL_ERROR "missing ${hdr}")
endif()
file(READ "${hdr}" text)
if(NOT text MATCHES "VISION_API")
    message(FATAL_ERROR "VISION_API not in ${hdr}")
endif()

include(InstallConfig)
message(STATUS "LAYOUT_FLAT_OK")
