# Consumer of the installed flat export set: find_package, then link Vision::Vision.
cmake_minimum_required(VERSION 3.29)
project(InstallFlatConsumer LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(LayoutFlat 0.3 CONFIG REQUIRED)
if(NOT TARGET Vision::Vision)
    message(FATAL_ERROR "Vision::Vision not imported by find_package(LayoutFlat)")
endif()

add_executable(consumer main.cpp)
target_link_libraries(consumer PRIVATE Vision::Vision)
enable_testing()
add_test(NAME consumer COMMAND consumer)
