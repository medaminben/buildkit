cmake_minimum_required(VERSION 3.29)
project(dep_blackhole_optional LANGUAGES NONE)
include(${BUILDKIT_DIR}/cmake/Buildkit.cmake)

# 10.255.255.1 drops packets (no refusal): only a bounded probe ends this.
dev_dependency(NoSuchPkg OPTIONAL FETCH_URL http://10.255.255.1/x.zip)
if(NOT DEFINED NoSuchPkg_AVAILABLE OR NoSuchPkg_AVAILABLE)
    message(FATAL_ERROR "NoSuchPkg_AVAILABLE must be FALSE, is '${NoSuchPkg_AVAILABLE}'")
endif()
