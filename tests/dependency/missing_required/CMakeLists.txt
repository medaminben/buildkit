cmake_minimum_required(VERSION 3.29)
project(dep_missing_required LANGUAGES NONE)
include(${BUILDKIT_DIR}/cmake/Buildkit.cmake)

dev_dependency(NoSuchPkg REQUIRED FETCH_URL http://127.0.0.1:9/x.zip
    INSTALL_HINT "apt install libnosuchpkg-dev")
message(STATUS "unreachable: configure should have stopped")
