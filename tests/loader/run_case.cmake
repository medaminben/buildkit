cmake_policy(SET CMP0054 NEW)
# Runs one loader case in build/tests/loader-<CASE>/ (never in the source tree).
# Inputs (-D): CASE, BUILDKIT_REPO (buildkit root)
#   local         -DBUILDKIT_DIR=<repo>
#   env           BUILDKIT_DIR in the environment only
#   sibling       no BUILDKIT_DIR; the product sits next to a symlink "buildkit"
#   bad_dir       BUILDKIT_DIR without cmake/Buildkit.cmake: fatal, names the path
#   offline       nothing local, BUILDKIT_OFFLINE=ON: fatal, names BUILDKIT_DIR
#   twice         the loader included twice: configures, one "using" line
#   fetch         tag fetched from a file:// repo into <bin>/_buildkit/src
#   cached_offline  after a fetch, offline: the cache is used ("cached")
#   disconnected    same with FETCHCONTENT_FULLY_DISCONNECTED
#   stale_offline   after a fetch of one tag, offline for another: fatal, names both
#   tagchange       after a fetch, online with another tag: re-fetched
#   offline_env     like offline, but BUILDKIT_OFFLINE=1 in the environment only
#   cached_offline_env / disconnected_env  like cached_offline / disconnected, via the environment
#   dead_cached     after a fetch, remote unreachable: the cache is used
set(work "${BUILDKIT_REPO}/build/tests/loader-${CASE}")
file(REMOVE_RECURSE "${work}")
file(MAKE_DIRECTORY "${work}")
file(COPY "${BUILDKIT_REPO}/tests/loader/CMakeLists.txt" DESTINATION "${work}/app")
file(COPY "${BUILDKIT_REPO}/loader/buildkit.cmake" DESTINATION "${work}/app/cmake")

# run(<out_all> <out_rc> <env...> -- <args...>): one configure of the fixture into ${work}/bin
function(run out_all out_rc)
    cmake_parse_arguments(PARSE_ARGV 2 r "" "" "ENV;ARGS")
    execute_process(
        COMMAND ${CMAKE_COMMAND} -E env ${r_ENV}
                ${CMAKE_COMMAND} -S "${work}/app" -B "${work}/bin" ${r_ARGS}
        RESULT_VARIABLE rc OUTPUT_VARIABLE o ERROR_VARIABLE e)
    set(all "${o}${e}")
    message("${all}")
    # CMake wraps long messages: allow line breaks between words.
    string(REGEX REPLACE "[ \n]+" " " flat "${all}")
    set(${out_all} "${flat}" PARENT_SCOPE)
    set(${out_rc} ${rc} PARENT_SCOPE)
endfunction()

function(expect_ok all rc regex)
    if(NOT rc EQUAL 0)
        message(FATAL_ERROR "configure failed (${rc})")
    endif()
    if(NOT all MATCHES "${regex}")
        message(FATAL_ERROR "output does not match: ${regex}")
    endif()
    if(NOT all MATCHES "LOADER_OK")
        message(FATAL_ERROR "fixture did not finish")
    endif()
endfunction()

function(expect_fail all rc regex)
    if(rc EQUAL 0)
        message(FATAL_ERROR "expected configure to fail")
    endif()
    if(NOT all MATCHES "${regex}")
        message(FATAL_ERROR "output does not match: ${regex}")
    endif()
endfunction()

function(re_escape out s)
    string(REGEX REPLACE "([][+.*()^$?|\\\\])" "\\\\\\1" s "${s}")
    set(${out} "${s}" PARENT_SCOPE)
endfunction()

# A local "remote": a git repo with buildkit's cmake/ tagged v9.9.8 and v9.9.9.
function(make_remote)
    find_program(GIT git REQUIRED)
    set(d "${work}/remote")
    file(MAKE_DIRECTORY "${d}")
    file(COPY "${BUILDKIT_REPO}/cmake" DESTINATION "${d}")
    set(g ${GIT} -c user.name=t -c user.email=t@t -c init.defaultBranch=main
        -c commit.gpgsign=false -c tag.gpgsign=false)
    foreach(step "init" "add;." "commit;-q;-m;c" "tag;v9.9.8" "tag;v9.9.9")
        execute_process(COMMAND ${g} ${step} WORKING_DIRECTORY "${d}"
            RESULT_VARIABLE rc OUTPUT_QUIET ERROR_VARIABLE err)
        if(NOT rc EQUAL 0)
            message(FATAL_ERROR "git ${step} failed: ${err}")
        endif()
    endforeach()
    set(REMOTE "file://${d}" PARENT_SCOPE)
endfunction()

set(unset_env --unset=BUILDKIT_DIR --unset=BUILDKIT_OFFLINE --unset=FETCHCONTENT_FULLY_DISCONNECTED)
re_escape(repo_re "${BUILDKIT_REPO}")
re_escape(work_re "${work}")
set(src_re "${work_re}/bin/_buildkit/src")

if(CASE STREQUAL "local")
    run(all rc ENV ${unset_env} ARGS -DBUILDKIT_DIR=${BUILDKIT_REPO})
    expect_ok("${all}" ${rc} "using ${repo_re} \\(local working copy\\)")
elseif(CASE STREQUAL "env")
    run(all rc ENV BUILDKIT_DIR=${BUILDKIT_REPO})
    expect_ok("${all}" ${rc} "using ${repo_re} \\(local working copy\\)")
elseif(CASE STREQUAL "sibling")
    file(CREATE_LINK "${BUILDKIT_REPO}" "${work}/buildkit" SYMBOLIC)
    run(all rc ENV ${unset_env})
    expect_ok("${all}" ${rc} "using ${work_re}/buildkit \\(local working copy\\)")
elseif(CASE STREQUAL "twice")
    run(all rc ENV ${unset_env} ARGS -DBUILDKIT_DIR=${BUILDKIT_REPO} -DLOADER_TWICE=ON)
    expect_ok("${all}" ${rc} "using ${repo_re} \\(local working copy\\)")
    string(REGEX MATCHALL "buildkit: using" hits "${all}")
    list(LENGTH hits n)
    if(NOT n EQUAL 1)
        message(FATAL_ERROR "loader printed ${n} times, expected once")
    endif()
elseif(CASE STREQUAL "bad_dir")
    run(all rc ENV ${unset_env} ARGS -DBUILDKIT_DIR=${work}/no-such-buildkit)
    expect_fail("${all}" ${rc} "no-such-buildkit.*cmake/Buildkit.cmake")
elseif(CASE STREQUAL "offline")
    run(all rc ENV ${unset_env} ARGS -DBUILDKIT_OFFLINE=ON)
    expect_fail("${all}" ${rc} "BUILDKIT_DIR")
elseif(CASE STREQUAL "offline_env")
    run(all rc ENV ${unset_env} BUILDKIT_OFFLINE=1)
    expect_fail("${all}" ${rc} "BUILDKIT_DIR")
else()
    make_remote()
    set(online -DBUILDKIT_REPOSITORY=${REMOTE} -DBUILDKIT_TAG=v9.9.9)
    run(all rc ENV ${unset_env} ARGS ${online})
    expect_ok("${all}" ${rc} "using ${src_re} \\(tag v9.9.9\\)")
    file(READ "${work}/bin/_buildkit/tag" stamp)
    string(STRIP "${stamp}" stamp)
    if(NOT stamp STREQUAL "v9.9.9")
        message(FATAL_ERROR "stamp is '${stamp}', expected v9.9.9")
    endif()
    if(CASE STREQUAL "fetch")
        # nothing more
    elseif(CASE STREQUAL "cached_offline")
        run(all rc ENV ${unset_env} ARGS ${online} -DBUILDKIT_OFFLINE=ON)
        expect_ok("${all}" ${rc} "using ${src_re} \\(tag v9.9.9, cached\\)")
    elseif(CASE STREQUAL "cached_offline_env")
        run(all rc ENV ${unset_env} BUILDKIT_OFFLINE=1 ARGS ${online})
        expect_ok("${all}" ${rc} "using ${src_re} \\(tag v9.9.9, cached\\)")
    elseif(CASE STREQUAL "disconnected_env")
        run(all rc ENV ${unset_env} FETCHCONTENT_FULLY_DISCONNECTED=ON ARGS ${online})
        expect_ok("${all}" ${rc} "using ${src_re} \\(tag v9.9.9, cached\\)")
    elseif(CASE STREQUAL "disconnected")
        run(all rc ENV ${unset_env} ARGS ${online} -DFETCHCONTENT_FULLY_DISCONNECTED=ON)
        expect_ok("${all}" ${rc} "using ${src_re} \\(tag v9.9.9, cached\\)")
    elseif(CASE STREQUAL "stale_offline")
        run(all rc ENV ${unset_env}
            ARGS -DBUILDKIT_TAG=v9.9.8 -DBUILDKIT_REPOSITORY=${REMOTE} -DBUILDKIT_OFFLINE=ON)
        expect_fail("${all}" ${rc} "v9.9.9.*v9.9.8|v9.9.8.*v9.9.9")
    elseif(CASE STREQUAL "tagchange")
        run(all rc ENV ${unset_env} ARGS -DBUILDKIT_TAG=v9.9.8 -DBUILDKIT_REPOSITORY=${REMOTE})
        expect_ok("${all}" ${rc} "using ${src_re} \\(tag v9.9.8\\)")
        file(READ "${work}/bin/_buildkit/tag" stamp)
        string(STRIP "${stamp}" stamp)
        if(NOT stamp STREQUAL "v9.9.8")
            message(FATAL_ERROR "stamp is '${stamp}', expected v9.9.8")
        endif()
    elseif(CASE STREQUAL "dead_cached")
        run(all rc ENV ${unset_env}
            ARGS -DBUILDKIT_TAG=v9.9.9 -DBUILDKIT_REPOSITORY=file://${work}/no-such-remote)
        expect_ok("${all}" ${rc} "using ${src_re} \\(tag v9.9.9, cached\\)")
    else()
        message(FATAL_ERROR "unknown CASE '${CASE}'")
    endif()
endif()
