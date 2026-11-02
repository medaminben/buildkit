cmake_minimum_required(VERSION 3.29)
project(dep_missing_optional LANGUAGES NONE)
include(${BUILDKIT_DIR}/cmake/Buildkit.cmake)

# Port 9 (discard) on localhost: the connection is refused at once.
dev_dependency(NoSuchPkg OPTIONAL FETCH_URL http://127.0.0.1:9/x.zip)
if(NOT DEFINED NoSuchPkg_AVAILABLE OR NoSuchPkg_AVAILABLE)
    message(FATAL_ERROR "NoSuchPkg_AVAILABLE must be FALSE, is '${NoSuchPkg_AVAILABLE}'")
endif()
