cmake_policy(SET CMP0054 NEW)
# Runs one loader case in build/tests/loader-<CASE>/ (never in the source tree).
# Inputs (-D): CASE, BUILDKIT_REPO (buildkit root)
#   local     -DBUILDKIT_DIR=<repo>
#   env       BUILDKIT_DIR in the environment only
#   sibling   no BUILDKIT_DIR; the product sits next to a symlink "buildkit"
#   bad_dir   BUILDKIT_DIR without cmake/Buildkit.cmake: fatal, names the path
#   offline   nothing local, BUILDKIT_OFFLINE=ON: fatal, names BUILDKIT_DIR + bootstrap
#   twice     the loader included twice: configures, one "using" line
set(work "${BUILDKIT_REPO}/build/tests/loader-${CASE}")
file(REMOVE_RECURSE "${work}")
file(MAKE_DIRECTORY "${work}")
file(COPY "${BUILDKIT_REPO}/tests/loader/CMakeLists.txt" DESTINATION "${work}/app")
file(COPY "${BUILDKIT_REPO}/loader/buildkit.cmake" DESTINATION "${work}/app/cmake")

set(envargs --unset=BUILDKIT_DIR)
set(args)
set(want_fail OFF)
set(want "using .* \\(local working copy\\)")
if(CASE STREQUAL "local")
    list(APPEND args -DBUILDKIT_DIR=${BUILDKIT_REPO})
elseif(CASE STREQUAL "env")
    set(envargs BUILDKIT_DIR=${BUILDKIT_REPO})
elseif(CASE STREQUAL "sibling")
    file(CREATE_LINK "${BUILDKIT_REPO}" "${work}/buildkit" SYMBOLIC)
elseif(CASE STREQUAL "twice")
    list(APPEND args -DBUILDKIT_DIR=${BUILDKIT_REPO} -DLOADER_TWICE=ON)
elseif(CASE STREQUAL "bad_dir")
    set(want_fail ON)
    list(APPEND args -DBUILDKIT_DIR=${work}/no-such-buildkit)
    set(want "no-such-buildkit.*cmake/Buildkit.cmake")
elseif(CASE STREQUAL "offline")
    set(want_fail ON)
    list(APPEND args -DBUILDKIT_OFFLINE=ON)
    set(want "BUILDKIT_DIR.*bootstrap.sh")
else()
    message(FATAL_ERROR "unknown CASE '${CASE}'")
endif()

execute_process(
    COMMAND ${CMAKE_COMMAND} -E env ${envargs}
            ${CMAKE_COMMAND} -S "${work}/app" -B "${work}/bin" ${args}
    RESULT_VARIABLE rc OUTPUT_VARIABLE out ERROR_VARIABLE err)
set(all "${out}${err}")
message("${all}")

if(want_fail AND rc EQUAL 0)
    message(FATAL_ERROR "expected configure to fail")
elseif(NOT want_fail AND NOT rc EQUAL 0)
    message(FATAL_ERROR "configure failed (${rc})")
endif()
# CMake wraps long messages: allow line breaks between words.
string(REGEX REPLACE "[ \n]+" " " flat "${all}")
if(NOT flat MATCHES "${want}")
    message(FATAL_ERROR "output does not match: ${want}")
endif()
if(NOT want_fail AND NOT all MATCHES "LOADER_OK")
    message(FATAL_ERROR "fixture did not finish")
endif()
if(CASE STREQUAL "twice")
    string(REGEX MATCHALL "buildkit: using" hits "${all}")
    list(LENGTH hits n)
    if(NOT n EQUAL 1)
        message(FATAL_ERROR "loader printed ${n} times, expected once")
    endif()
endif()
