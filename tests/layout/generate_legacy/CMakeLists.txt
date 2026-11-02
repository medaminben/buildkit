# generate_libraries with CMAKE_ROOT_NAME keeps the legacy layout
# (include/Demo/Beta/Beta.h, Demo::Beta) with the same buildkit templates.
cmake_minimum_required(VERSION 3.29)
project(LayoutGenerateLegacy VERSION 0.1.0 LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
include(${BUILDKIT_DIR}/cmake/Buildkit.cmake)
include(CTest)

set(CMAKE_ROOT_NAME Demo)
set(BUILD_WX_UI OFF)
set(gen ${CMAKE_BINARY_DIR}/gen)
generate_libraries(
    LIBRARIES_LIST     Beta
    LIBRARIES_LOCATION ${gen}/libraries
    APPS_LOCATION      ${gen}/applications
    TEMPLATE_LOCATION  ${BUILDKIT_ROOT}/template
)

set(hdr ${gen}/libraries/Beta/include/Demo/Beta/Beta.h)
if(NOT EXISTS "${hdr}")
    message(FATAL_ERROR "missing ${hdr}")
endif()
file(READ "${hdr}" text)
if(NOT text MATCHES "namespace Demo::Beta {" OR NOT text MATCHES "<Demo/Beta/Demo_Beta_export.h>")
    message(FATAL_ERROR "${hdr} is not legacy:\n${text}")
endif()
if(EXISTS ${gen}/applications/Beta/Beta_Wx_UI)
    message(FATAL_ERROR "BUILD_WX_UI=OFF must not generate the wx app")
endif()

add_subdirectory(${gen}/libraries    libraries)
add_subdirectory(${gen}/applications applications)
if(NOT TARGET Demo::Beta OR NOT TARGET Beta_Console)
    message(FATAL_ERROR "Demo::Beta or Beta_Console missing")
endif()
message(STATUS "LAYOUT_GENERATE_LEGACY_OK")
