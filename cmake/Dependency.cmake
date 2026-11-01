# dev_dependency(): the one way a product pulls in third-party code.
#
# Rule: use an installed copy -> else fetch it -> else build without it
# (OPTIONAL) or stop with a clear error (REQUIRED). Offline never hangs and
# never ends configure with an error for an OPTIONAL dependency.
#
# dev_dependency(<Name>
#     [VERSION <min>] [COMPONENTS <c>...] [FIND_ARGS <args>...]
#     [FETCH_URL <url> [FETCH_SHA256 <hex>] | FETCH_GIT <repo> FETCH_TAG <tag>]
#     [FETCH_CACHE <VAR>=<value>...]
#     [REQUIRED | OPTIONAL]                  # default OPTIONAL
#     [FOUND_VAR <var>])                     # default <Name>_AVAILABLE
#
# 1. find_package(<Name> [<VERSION>] QUIET <FIND_ARGS> [COMPONENTS ...]).
#    The variables it defines (<Name>_FOUND, <Name>_DIR, ...) are passed to
#    the caller's scope; its imported targets live in the caller's directory.
# 2. Not found: FETCHCONTENT_SOURCE_DIR_<NAME> (upper case) naming an existing
#    directory wins: that source is used directly, with no offline check and
#    no probe ("<Name>: local source (<dir>)").
# 3. Else, with fetch arguments, the source is probed unless BUILDKIT_OFFLINE
#    or FETCHCONTENT_FULLY_DISCONNECTED is ON:
#      URL  a 1-byte ranged request (TIMEOUT 30, which also bounds connecting
#           to a host that drops packets; if the server ignores the range and
#           the whole file arrives within it, that is the download), then
#           file(DOWNLOAD) to
#           ${CMAKE_BINARY_DIR}/_downloads/<Name>/<file>.part (INACTIVITY_TIMEOUT
#           30), SHA-256 checked, renamed to <file> on success, its URL kept in
#           <file>.url. FetchContent then reads that local file, so nothing is
#           downloaded twice. An earlier download is reused (also offline) when
#           its hash matches, or without FETCH_SHA256 when <file>.url matches.
#      GIT  git ls-remote --exit-code (TIMEOUT 30, no credential prompt),
#           then FetchContent with GIT_SHALLOW TRUE, except for a commit hash
#           (7-40 hex digits), which cannot be cloned shallow. A clone already
#           populated in the build tree is reused when offline or the probe
#           fails; a WARNING names both revisions if it is not at FETCH_TAG.
# 4. Otherwise OPTIONAL: <FOUND_VAR> FALSE and a WARNING; REQUIRED: FATAL_ERROR.
#    Both name the cause (not installed / no network / offline / SHA-256
#    mismatch / git missing) and redev/bootstrap/bootstrap.sh.
#
# <FOUND_VAR> is TRUE or FALSE in the caller's scope.
#
# Notes and known limits:
# - FETCH_CACHE entries are set with CACHE ... FORCE before
#   FetchContent_MakeAvailable, so they override a -D<VAR>=... of the user.
# - Called before project(), only packages that need no enabled language can
#   be found or fetched.
# - Only reachability is probed. A failure after a successful probe (clone,
#   extraction or add_subdirectory of the fetched project) is fatal, even for
#   an OPTIONAL dependency.
include_guard(GLOBAL)

include(FetchContent)

option(BUILDKIT_OFFLINE "Never download; use installed packages only" OFF)

# Extracted archives get the extraction time as timestamp (CMP0135 NEW).
# include() gives this file its own policy scope; the functions record it.
cmake_policy(SET CMP0135 NEW)

# TRUE when <ref> is a commit hash (7 to 40 hex digits), not a tag/branch.
function(_dev_dependency_is_commit ref out)
    string(LENGTH "${ref}" len)
    if(ref MATCHES "^[0-9a-fA-F]+$" AND len GREATER_EQUAL 7 AND len LESS_EQUAL 40)
        set(${out} TRUE PARENT_SCOPE)
    else()
        set(${out} FALSE PARENT_SCOPE)
    endif()
endfunction()

# FetchContent_Declare arguments for a git source. A commit cannot be
# fetched with --depth 1, so GIT_SHALLOW is used for tags/branches only.
function(_dev_dependency_git_declare repo tag out)
    set(args GIT_REPOSITORY "${repo}" GIT_TAG "${tag}")
    _dev_dependency_is_commit("${tag}" is_commit)
    if(NOT is_commit)
        list(APPEND args GIT_SHALLOW TRUE)
    endif()
    set(${out} "${args}" PARENT_SCOPE)
endfunction()

function(_dev_dependency_unavailable name required cause detail)
    if(detail)
        message(STATUS "${name}: ${detail}")
    endif()
    if(required)
        message(FATAL_ERROR "${name} not available (${cause}): cannot build without it. "
                            "Install with redev/bootstrap/bootstrap.sh")
    else()
        message(WARNING "${name} not available (${cause}): building without it. "
                        "Install with redev/bootstrap/bootstrap.sh")
    endif()
endfunction()

# Warns when the cached clone <src> is not at <tag>.
function(_dev_dependency_check_clone name src tag)
    if(NOT GIT_EXECUTABLE)
        message(WARNING "${name}: cannot verify cached source ${src} against ${tag} (git missing)")
        return()
    endif()
    execute_process(COMMAND "${GIT_EXECUTABLE}" -C "${src}" rev-parse HEAD
        RESULT_VARIABLE rc OUTPUT_VARIABLE head ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE)
    if(NOT rc EQUAL 0)
        message(WARNING "${name}: cannot verify cached source ${src} against ${tag} (not a git checkout)")
        return()
    endif()
    _dev_dependency_is_commit("${tag}" is_commit)
    if(is_commit)
        string(TOLOWER "${tag}" want)
        string(FIND "${head}" "${want}" pos)
        if(pos EQUAL 0)
            return()
        endif()
    else()
        execute_process(COMMAND "${GIT_EXECUTABLE}" -C "${src}" rev-parse --verify --quiet "${tag}^{commit}"
            RESULT_VARIABLE rc OUTPUT_VARIABLE want ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE)
        if(rc EQUAL 0 AND want STREQUAL head)
            return()
        endif()
        if(NOT rc EQUAL 0)
            set(want "unknown here")
        endif()
    endif()
    message(WARNING "${name}: cached source ${src} is at ${head}, but FETCH_TAG ${tag} is "
                    "${want}; using the cached source (offline). Reconfigure online to update.")
endfunction()

function(dev_dependency name)
    cmake_parse_arguments(PARSE_ARGV 1 dd
        "REQUIRED;OPTIONAL"
        "VERSION;FETCH_URL;FETCH_SHA256;FETCH_GIT;FETCH_TAG;FOUND_VAR"
        "COMPONENTS;FIND_ARGS;FETCH_CACHE")

    if(dd_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "dev_dependency(${name}): unknown arguments: ${dd_UNPARSED_ARGUMENTS}")
    endif()
    if(dd_REQUIRED AND dd_OPTIONAL)
        message(FATAL_ERROR "dev_dependency(${name}): REQUIRED and OPTIONAL are exclusive")
    endif()
    if(dd_FETCH_URL AND dd_FETCH_GIT)
        message(FATAL_ERROR "dev_dependency(${name}): FETCH_URL and FETCH_GIT are exclusive")
    endif()
    if(dd_FETCH_GIT AND NOT dd_FETCH_TAG)
        message(FATAL_ERROR "dev_dependency(${name}): FETCH_GIT needs FETCH_TAG")
    endif()
    if(dd_FETCH_SHA256 AND NOT dd_FETCH_URL)
        message(FATAL_ERROR "dev_dependency(${name}): FETCH_SHA256 needs FETCH_URL")
    endif()
    if(NOT dd_FOUND_VAR)
        set(dd_FOUND_VAR ${name}_AVAILABLE)
    endif()

    # --- 1. installed copy -------------------------------------------------
    set(find_args ${dd_VERSION} QUIET ${dd_FIND_ARGS})
    if(dd_COMPONENTS)
        list(APPEND find_args COMPONENTS ${dd_COMPONENTS})
    endif()
    get_cmake_property(vars_before VARIABLES)
    find_package(${name} ${find_args})
    get_cmake_property(vars_after VARIABLES)
    list(REMOVE_ITEM vars_after ${vars_before} vars_before)
    list(APPEND vars_after ${name}_FOUND ${name}_VERSION ${name}_DIR)
    list(REMOVE_DUPLICATES vars_after)
    foreach(v IN LISTS vars_after)
        if(DEFINED ${v})
            set(${v} "${${v}}" PARENT_SCOPE)
        endif()
    endforeach()

    if(${name}_FOUND)
        if(${name}_DIR)
            set(where "${${name}_DIR}")
        else()
            set(where "Find${name}.cmake")
        endif()
        if(${name}_VERSION)
            message(STATUS "${name} ${${name}_VERSION}: installed (${where})")
        else()
            message(STATUS "${name}: installed (${where})")
        endif()
        set(${dd_FOUND_VAR} TRUE PARENT_SCOPE)
        return()
    endif()

    string(TOLOWER "${name}" lc)
    string(TOUPPER "${name}" uc)

    set(ok FALSE)
    set(cause "")
    set(detail "")
    set(declare "")
    set(status "fetched")
    set(disconnected OFF)

    # --- 2. explicit local source ---------------------------------------
    set(override "${FETCHCONTENT_SOURCE_DIR_${uc}}")
    if(override AND IS_DIRECTORY "${override}")
        set(ok TRUE)
        set(declare SOURCE_DIR "${override}")
        set(status "local source (${override})")
    elseif(NOT dd_FETCH_URL AND NOT dd_FETCH_GIT)
        set(${dd_FOUND_VAR} FALSE PARENT_SCOPE)
        _dev_dependency_unavailable(${name} "${dd_REQUIRED}" "not installed" "")
        return()
    endif()

    # --- 3. fetch ------------------------------------------------------------
    if(BUILDKIT_OFFLINE OR FETCHCONTENT_FULLY_DISCONNECTED
       OR "$CACHE{FETCHCONTENT_FULLY_DISCONNECTED}")
        set(offline TRUE)
    else()
        set(offline FALSE)
    endif()
    set(offline_detail "offline (BUILDKIT_OFFLINE or FETCHCONTENT_FULLY_DISCONNECTED)")

    if(ok)
        # explicit local source: nothing to probe
    elseif(dd_FETCH_URL)
        string(REGEX REPLACE "[?#].*$" "" url_path "${dd_FETCH_URL}")
        get_filename_component(file_name "${url_path}" NAME)
        if(NOT file_name)
            message(FATAL_ERROR "dev_dependency(${name}): FETCH_URL has no file name: ${dd_FETCH_URL}")
        endif()
        set(local "${CMAKE_BINARY_DIR}/_downloads/${name}/${file_name}")
        set(part "${local}.part")
        set(url_file "${local}.url")
        string(TOLOWER "${dd_FETCH_SHA256}" want)

        # Reuse an earlier, complete download of the same content.
        if(EXISTS "${local}")
            if(want)
                file(SHA256 "${local}" have)
                if(have STREQUAL want)
                    set(ok TRUE)
                endif()
            elseif(EXISTS "${url_file}")
                file(READ "${url_file}" old_url)
                if(old_url STREQUAL dd_FETCH_URL)
                    set(ok TRUE)
                endif()
            endif()
        endif()

        if(NOT ok AND offline)
            set(cause "not installed, offline")
            set(detail "${offline_detail}, not downloading")
        elseif(NOT ok)
            # Probe: one byte, bounded in total. INACTIVITY_TIMEOUT alone does
            # not cover connecting to a host that drops packets.
            set(probe "${local}.probe")
            message(STATUS "${name}: probing ${dd_FETCH_URL}")
            file(DOWNLOAD "${dd_FETCH_URL}" "${probe}"
                RANGE_START 0 RANGE_END 0 TIMEOUT 30 TLS_VERIFY ON STATUS st)
            list(GET st 0 code)
            list(GET st 1 msg)
            set(size 0)
            if(EXISTS "${probe}")
                file(SIZE "${probe}" size)
            endif()
            # 0 with 1 byte: 206, range honoured. 0 with more: the server
            # ignored the range and the whole file arrived within the probe
            # timeout; it is the download. 28 with bytes: range ignored and
            # the file is still coming (reachable, download it properly).
            if(code EQUAL 0 AND size GREATER 1)
                file(RENAME "${probe}" "${part}")
                set(complete TRUE)
            else()
                file(REMOVE "${probe}")
                set(complete FALSE)
            endif()
            if(NOT (code EQUAL 0 OR (code EQUAL 28 AND size GREATER 0)))
                set(cause "not installed, no network")
                set(detail "probe failed: ${msg}")
            else()
                if(NOT complete)
                    message(STATUS "${name}: downloading ${dd_FETCH_URL}")
                    # No EXPECTED_HASH: a mismatch would be fatal, and
                    # configure must not fail for an OPTIONAL dependency;
                    # checked below. No total TIMEOUT (it would cut a slow but
                    # working download).
                    file(DOWNLOAD "${dd_FETCH_URL}" "${part}"
                        INACTIVITY_TIMEOUT 30 TLS_VERIFY ON STATUS st)
                    list(GET st 0 code)
                    list(GET st 1 msg)
                endif()
                if(NOT code EQUAL 0)
                    set(cause "not installed, no network")
                    set(detail "download failed: ${msg}")
                elseif(want)
                    file(SHA256 "${part}" have)
                    if(NOT have STREQUAL want)
                        set(code 1)
                        set(cause "not installed, SHA-256 mismatch")
                        set(detail "SHA-256 of ${dd_FETCH_URL} is ${have}, expected ${want}")
                    endif()
                endif()
                if(code EQUAL 0)
                    file(RENAME "${part}" "${local}")
                    file(WRITE "${url_file}" "${dd_FETCH_URL}")
                    set(ok TRUE)
                else()
                    file(REMOVE "${part}")
                endif()
            endif()
        endif()

        if(ok)
            set(declare URL "${local}" DOWNLOAD_EXTRACT_TIMESTAMP TRUE)
            if(want)
                list(APPEND declare URL_HASH SHA256=${want})
            endif()
        endif()
    else()
        if(FETCHCONTENT_BASE_DIR)
            set(deps_dir "${FETCHCONTENT_BASE_DIR}")
        else()
            set(deps_dir "${CMAKE_BINARY_DIR}/_deps")
        endif()
        set(src_dir "${deps_dir}/${lc}-src")
        find_package(Git QUIET)

        if(offline)
            set(cause "not installed, offline")
            set(detail "${offline_detail}, not cloning")
        elseif(NOT GIT_EXECUTABLE)
            set(cause "not installed, git missing")
            set(detail "git not found, cannot clone ${dd_FETCH_GIT}")
        else()
            # A commit hash is not a ref: probe that the repo answers.
            _dev_dependency_is_commit("${dd_FETCH_TAG}" is_commit)
            if(is_commit)
                set(ref HEAD)
            else()
                set(ref "${dd_FETCH_TAG}")
            endif()
            message(STATUS "${name}: probing ${dd_FETCH_GIT} ${ref}")
            execute_process(
                COMMAND ${CMAKE_COMMAND} -E env GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=never
                        "${GIT_EXECUTABLE}" ls-remote --exit-code "${dd_FETCH_GIT}" "${ref}"
                TIMEOUT 30
                RESULT_VARIABLE rc
                OUTPUT_QUIET
                ERROR_VARIABLE err)
            if(rc STREQUAL "0")
                set(ok TRUE)
            else()
                string(STRIP "${err}" err)
                set(cause "not installed, no network")
                set(detail "git ls-remote failed (${rc}) ${err}")
            endif()
        endif()
        if(NOT ok AND EXISTS "${src_dir}/CMakeLists.txt")
            # Clone from an earlier configure: use it without network.
            message(STATUS "${name}: ${detail}; using cached source ${src_dir}")
            _dev_dependency_check_clone(${name} "${src_dir}" "${dd_FETCH_TAG}")
            set(ok TRUE)
            set(disconnected ON)
            set(status "fetched (cached)")
        endif()
        if(ok)
            _dev_dependency_git_declare("${dd_FETCH_GIT}" "${dd_FETCH_TAG}" declare)
        endif()
    endif()

    if(NOT ok)
        set(${dd_FOUND_VAR} FALSE PARENT_SCOPE)
        _dev_dependency_unavailable(${name} "${dd_REQUIRED}" "${cause}" "${detail}")
        return()
    endif()

    foreach(entry IN LISTS dd_FETCH_CACHE)
        if(NOT entry MATCHES "^([^=]+)=(.*)$")
            message(FATAL_ERROR "dev_dependency(${name}): FETCH_CACHE entry is not VAR=value: ${entry}")
        endif()
        set(key "${CMAKE_MATCH_1}")
        set(value "${CMAKE_MATCH_2}")
        string(TOUPPER "${value}" uvalue)
        if(uvalue MATCHES "^(ON|OFF|TRUE|FALSE|YES|NO|Y|N|0|1)$")
            set(${key} "${value}" CACHE BOOL "set by dev_dependency(${name})" FORCE)
        else()
            set(${key} "${value}" CACHE STRING "set by dev_dependency(${name})" FORCE)
        endif()
    endforeach()

    # Local to this function: a fully disconnected FetchContent would skip a
    # population that needs no network (local archive), and a cached clone
    # must not be updated offline.
    set(FETCHCONTENT_FULLY_DISCONNECTED ${disconnected})
    FetchContent_Declare(${name} ${declare})
    FetchContent_MakeAvailable(${name})

    message(STATUS "${name}: ${status}")
    set(${dd_FOUND_VAR} TRUE PARENT_SCOPE)
endfunction()
