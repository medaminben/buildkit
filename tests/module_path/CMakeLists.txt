# A product with its own cmake/Common.cmake must win over any buildkit module
# of the same name, even when it only APPENDs its cmake/ folder after the kit.
cmake_minimum_required(VERSION 3.29)
include(${BUILDKIT_DIR}/cmake/Buildkit.cmake)
project(module_path LANGUAGES NONE)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
include(Common)
if(NOT PRODUCT_COMMON_LOADED STREQUAL "product-common")
    message(FATAL_ERROR "include(Common) did not load the product's module")
endif()
message(STATUS "MODULE_PATH_OK ${PRODUCT_COMMON_LOADED}")
