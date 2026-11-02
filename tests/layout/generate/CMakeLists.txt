# generate_libraries without CMAKE_ROOT_NAME writes the flat layout from
# buildkit's templates. The tree is generated into the binary dir, so the
# source tree stays clean and every run starts empty.
cmake_minimum_required(VERSION 3.29)
project(LayoutGenerate VERSION 0.1.0 LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
include(${BUILDKIT_DIR}/cmake/Buildkit.cmake)
include(CTest)

set(gen ${CMAKE_BINARY_DIR}/gen)
generate_libraries(
    LIBRARIES_LIST     Alpha
    LIBRARIES_LOCATION ${gen}/libraries
    APPS_LOCATION      ${gen}/applications
    TEMPLATE_LOCATION  ${BUILDKIT_ROOT}/template
)

set(hdr ${gen}/libraries/Alpha/include/Alpha/Alpha.h)
if(NOT EXISTS "${hdr}")
    message(FATAL_ERROR "missing ${hdr}")
endif()
file(READ "${hdr}" text)
if(NOT text MATCHES "namespace Alpha {" OR NOT text MATCHES "<Alpha/Alpha_export.h>"
   OR NOT text MATCHES "ALPHA_API")
    message(FATAL_ERROR "${hdr} is not flat:\n${text}")
endif()

add_subdirectory(${gen}/libraries    libraries)
add_subdirectory(${gen}/applications applications)

if(NOT TARGET Alpha::Alpha OR NOT TARGET Alpha_Console)
    message(FATAL_ERROR "Alpha::Alpha or Alpha_Console missing")
endif()
if(TARGET Alpha_Wx_UI)
    message(STATUS "LAYOUT_GENERATE wx app: built")
else()
    message(STATUS "LAYOUT_GENERATE wx app: skipped (no wxWidgets)")
endif()
add_test(NAME alpha_console_runs COMMAND Alpha_Console)
set_tests_properties(alpha_console_runs PROPERTIES PASS_REGULAR_EXPRESSION "The answer is 42")
message(STATUS "LAYOUT_GENERATE_OK")
