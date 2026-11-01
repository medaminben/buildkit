# buildkit_git_version test: builds throw-away git repos under build/tests/version/
# and checks the numeric and full version for each state.
# Usage: cmake -DBUILDKIT_DIR=<buildkit> -P run.cmake
if(NOT BUILDKIT_DIR)
    message(FATAL_ERROR "BUILDKIT_DIR is required")
endif()
include("${BUILDKIT_DIR}/cmake/GitVersion.cmake")

find_program(GIT git REQUIRED)
set(root "${BUILDKIT_DIR}/build/tests/version")
file(REMOVE_RECURSE "${root}")
file(MAKE_DIRECTORY "${root}")

function(git dir)
    execute_process(COMMAND "${GIT}" -c user.name=t -c user.email=t@t -c init.defaultBranch=main
        -c commit.gpgsign=false -c tag.gpgsign=false ${ARGN}
        WORKING_DIRECTORY "${dir}" RESULT_VARIABLE r OUTPUT_QUIET ERROR_VARIABLE e)
    if(NOT r EQUAL 0)
        message(FATAL_ERROR "git ${ARGN} failed in ${dir}: ${e}")
    endif()
endfunction()

function(new_repo name)
    set(d "${root}/${name}")
    file(MAKE_DIRECTORY "${d}")
    git("${d}" init)
    file(WRITE "${d}/f.txt" "0")
    git("${d}" add f.txt)
    git("${d}" commit -m c0)
endfunction()

function(commit name n)
    foreach(i RANGE 1 ${n})
        file(APPEND "${root}/${name}/f.txt" "${i}")
        git("${root}/${name}" commit -am c${i})
    endforeach()
endfunction()

# check(<dir> <expected numeric> <expected full regex> [FALLBACK x])
function(check dir want_numeric want_full_re)
    buildkit_git_version("${dir}" got_numeric got_full ${ARGN})
    if(NOT got_numeric STREQUAL want_numeric)
        message(FATAL_ERROR "${dir}: numeric '${got_numeric}', expected '${want_numeric}'")
    endif()
    if(NOT got_full MATCHES "${want_full_re}")
        message(FATAL_ERROR "${dir}: full '${got_full}' does not match '${want_full_re}'")
    endif()
    message(STATUS "ok: ${dir} -> ${got_numeric} / ${got_full}")
endfunction()

# tag at HEAD
new_repo(tagged)
git("${root}/tagged" tag v1.5.4)
check("${root}/tagged" 1.5.4 "^1\\.5\\.4$")

# 2 commits after the tag
commit(tagged 2)
check("${root}/tagged" 1.5.4 "^1\\.5\\.4\\+2\\.g[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]$")

# beta tag at HEAD
new_repo(beta)
git("${root}/beta" tag v1.6.0-beta.3)
check("${root}/beta" 1.6.0 "^1\\.6\\.0-beta\\.3$")
commit(beta 1)
check("${root}/beta" 1.6.0 "^1\\.6\\.0-beta\\.3\\+1\\.g[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]$")

# unrelated tags are ignored
new_repo(other_tags)
git("${root}/other_tags" tag v1.2.3)
commit(other_tags 1)
git("${root}/other_tags" tag v9.9.9-rc.1)
git("${root}/other_tags" tag release-7)
check("${root}/other_tags" 1.2.3 "^1\\.2\\.3\\+1\\.g[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]$")

# no tags, with and without FALLBACK
new_repo(untagged)
check("${root}/untagged" 1.4.0 "^1\\.4\\.0-dev$" FALLBACK 1.4.0)
check("${root}/untagged" 0.0.0 "^0\\.0\\.0-dev$")

# no .git at all
file(MAKE_DIRECTORY "${root}/nogit")
check("${root}/nogit" 0.0.0 "^0\\.0\\.0-dev$")

# subfolder of another repo (which has a tag): treated as no git
file(MAKE_DIRECTORY "${root}/tagged/sub")
check("${root}/tagged/sub" 3.0.0 "^3\\.0\\.0-dev$" FALLBACK 3.0.0)

message(STATUS "version: all cases passed")
