# GoogleTest through dev_dependency(): an installed GTest >= 1.15, else the
# pinned release fetched from GitHub. Including this file has no side effect;
# buildkit_use_gtest() resolves GoogleTest on first use (build_gtest_executable
# calls it). GoogleTest is REQUIRED when BUILD_TESTING is ON, else OPTIONAL.
#
# Result in the caller's scope: BUILDKIT_GTEST_AVAILABLE (TRUE/FALSE) and the
# targets GTest::gtest, GTest::gtest_main, GTest::gmock, GTest::gmock_main.
include_guard(GLOBAL)

include(Dependency)
include(GoogleTest)

function(buildkit_use_gtest)
    # Fetched targets are global; an installed GTest is imported per
    # directory, so another directory finds it again.
    if(TARGET GTest::gtest)
        set(BUILDKIT_GTEST_AVAILABLE TRUE PARENT_SCOPE)
        return()
    endif()
    if(BUILD_TESTING)
        set(mode REQUIRED)
    else()
        set(mode OPTIONAL)
    endif()
    dev_dependency(GTest VERSION 1.15 ${mode}
        FETCH_GIT https://github.com/google/googletest.git FETCH_TAG v1.15.2
        FETCH_CACHE INSTALL_GTEST=OFF gtest_force_shared_crt=ON
        FOUND_VAR BUILDKIT_GTEST_AVAILABLE)
    set(BUILDKIT_GTEST_AVAILABLE ${BUILDKIT_GTEST_AVAILABLE} PARENT_SCOPE)
endfunction()
