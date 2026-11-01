cmake_minimum_required(VERSION 3.29)
project(dep_found LANGUAGES C)
include(${BUILDKIT_DIR}/cmake/Buildkit.cmake)

dev_dependency(Threads REQUIRED)
if(NOT Threads_AVAILABLE OR NOT TARGET Threads::Threads)
    message(FATAL_ERROR "Threads_AVAILABLE=${Threads_AVAILABLE}, Threads::Threads missing")
endif()
