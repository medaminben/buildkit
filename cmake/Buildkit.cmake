# buildkit entry point. A product does
#   include(<buildkit>/cmake/Buildkit.cmake)
# once; it sets BUILDKIT_ROOT, BUILDKIT_VERSION and BUILDKIT_VERSION_FULL, extends CMAKE_MODULE_PATH
# and includes every module that is safe to load without side effects.
include_guard(GLOBAL)

# cmake/ -> buildkit root (absolute)
get_filename_component(BUILDKIT_ROOT "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)

include(${CMAKE_CURRENT_LIST_DIR}/GitVersion.cmake)
buildkit_git_version("${BUILDKIT_ROOT}" BUILDKIT_VERSION BUILDKIT_VERSION_FULL FALLBACK 2.0.0)

list(APPEND CMAKE_MODULE_PATH
    "${BUILDKIT_ROOT}/cmake"
    "${BUILDKIT_ROOT}/cmake/modules")

# Not auto-included: InstallConfig (declares install rules; products opt in).
# TestUtils/GTestSupport are safe: GoogleTest is resolved only when
# build_gtest_executable() (or buildkit_use_gtest()) is first called.
include(BuildLocation)
include(BuildUtils)
include(DebugUtils)
include(CompilerWarnings)
include(Coverage)
include(LibraryGenerator)
include(Dependency)
include(TestUtils)
include(Packaging)
include(Manual)
