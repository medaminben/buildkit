# Legacy layout: CMAKE_ROOT_NAME is set (as in Bowlingbox), so create_library
# gives Demo::Core, include/Demo/Core/Demo_Core_export.h, DEMO_CORE_API and
# OUTPUT_NAME DemoCore. The library CMakeLists is written like Bowlingbox's.
cmake_minimum_required(VERSION 3.29)
project(LayoutLegacy VERSION 1.2.3 LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
include(${BUILDKIT_DIR}/cmake/Buildkit.cmake)
include(CTest)

set(CMAKE_ROOT_NAME Demo)
set(DEMO_RUNTIME_COMPONENT DemoRuntime)

add_subdirectory(Core)
add_subdirectory(app)

if(NOT TARGET Demo::Core)
    message(FATAL_ERROR "Demo::Core missing")
endif()
get_target_property(out demo_core OUTPUT_NAME)
get_target_property(exp demo_core EXPORT_NAME)
if(NOT out STREQUAL "DemoCore" OR NOT exp STREQUAL "Core")
    message(FATAL_ERROR "legacy names wrong: OUTPUT_NAME=${out} EXPORT_NAME=${exp}")
endif()
set(hdr "${CMAKE_BINARY_DIR}/Core/include/Demo/Core/Demo_Core_export.h")
if(NOT EXISTS "${hdr}")
    message(FATAL_ERROR "missing ${hdr}")
endif()
file(READ "${hdr}" text)
if(NOT text MATCHES "DEMO_CORE_API")
    message(FATAL_ERROR "DEMO_CORE_API not in ${hdr}")
endif()
if(NOT EXISTS "${PROJECT_BUILD_OUTPUT}/data/demo_core/CoreTestData.txt")
    message(FATAL_ERROR "LIB_RSC not copied to ${PROJECT_BUILD_OUTPUT}/data/demo_core")
endif()

include(InstallConfig)
message(STATUS "LAYOUT_LEGACY_OK")
