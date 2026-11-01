# Guard: buildkit must ship no Common.cmake. The kit's module folders come before
# a product's APPENDed cmake/, so any buildkit Common.cmake would shadow the
# product's own one.
cmake_minimum_required(VERSION 3.29)
include(${BUILDKIT_DIR}/cmake/Buildkit.cmake)
project(module_path LANGUAGES NONE)

foreach(dir "${BUILDKIT_ROOT}/cmake" "${BUILDKIT_ROOT}/cmake/modules")
    if(EXISTS "${dir}/Common.cmake")
        message(FATAL_ERROR "buildkit ships ${dir}/Common.cmake: it shadows every product's Common module")
    endif()
endforeach()

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
include(Common)
if(NOT PRODUCT_COMMON_LOADED STREQUAL "product-common")
    message(FATAL_ERROR "include(Common) did not load the product's module")
endif()
message(STATUS "MODULE_PATH_OK ${PRODUCT_COMMON_LOADED}")
