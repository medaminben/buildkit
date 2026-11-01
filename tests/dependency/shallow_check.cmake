# Unit check (cmake -P, no network) of the GIT_SHALLOW choice in
# cmake/Dependency.cmake: tags and branches are cloned shallow, a commit hash
# (7-40 hex digits) is not, because --depth 1 cannot fetch an arbitrary commit.
cmake_minimum_required(VERSION 3.29)
include(${BUILDKIT_DIR}/cmake/Dependency.cmake)

function(expect_shallow tag want)
    _dev_dependency_git_declare(https://example.invalid/r.git "${tag}" args)
    if("GIT_SHALLOW" IN_LIST args)
        set(got TRUE)
    else()
        set(got FALSE)
    endif()
    if(NOT got STREQUAL want)
        message(SEND_ERROR "tag '${tag}': GIT_SHALLOW expected ${want}, got ${got} (${args})")
    else()
        message(STATUS "tag '${tag}': shallow=${got} ok")
    endif()
endfunction()

expect_shallow(v1.15.2 TRUE)
expect_shallow(main TRUE)
expect_shallow(abc TRUE)                 # 3 hex digits: too short for a commit
expect_shallow(abcdef TRUE)              # 6 hex digits: still a name
expect_shallow(b514bdc FALSE)            # short commit
expect_shallow(b514bdc898e2951020cbdca1304b75f5950d1f59 FALSE)
expect_shallow(B514BDC898E2951020CBDCA1304B75F5950D1F59 FALSE)
expect_shallow(b514bdc898e2951020cbdca1304b75f5950d1f59a TRUE)   # 41 chars
message(STATUS "SHALLOW_CHECK_DONE")
