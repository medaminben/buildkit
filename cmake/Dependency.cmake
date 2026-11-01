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
# 2. Not found and fetch arguments given: probe the source unless
#    BUILDKIT_OFFLINE or FETCHCONTENT_FULLY_DISCONNECTED is ON.
#      URL  file(DOWNLOAD) into ${CMAKE_BINARY_DIR}/_downloads/<Name>/<file>
#           (INACTIVITY_TIMEOUT 30, SHA-256 checked), then FetchContent from
#           that local file, so nothing is downloaded twice. A file already
#           there with the right hash is reused, also offline.
#      GIT  git ls-remote --exit-code (TIMEOUT 30, no credential prompt),
#           then FetchContent with GIT_SHALLOW. A source tree already
#           populated in the build tree is reused offline.
#    FETCH_CACHE entries are set as cache variables before
#    FetchContent_MakeAvailable (to configure the fetched project).
# 3. Otherwise OPTIONAL: <FOUND_VAR> FALSE and a warning; REQUIRED: FATAL_ERROR.
#
# <FOUND_VAR> is TRUE or FALSE in the caller's scope.
include_guard(GLOBAL)

include(FetchContent)

option(BUILDKIT_OFFLINE "Never download; use installed packages only" OFF)

# Extracted archives get the extraction time as timestamp (CMP0135 NEW).
# include() gives this file its own policy scope; the function records it.
cmake_policy(SET CMP0135 NEW)

function(_dev_dependency_unavailable name required reason)
    if(reason)
        message(STATUS "${name}: ${reason}")
    endif()
    set(text "${name} not available (not installed, no network): building without it. "
             "Install with redev/bootstrap/bootstrap.sh")
    string(JOIN "" text ${text})
    if(required)
        message(FATAL_ERROR "${text}")
    else()
        message(WARNING "${text}")
    endif()
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
    list(REMOVE_ITEM vars_after ${vars_before})
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

    if(NOT dd_FETCH_URL AND NOT dd_FETCH_GIT)
        set(${dd_FOUND_VAR} FALSE PARENT_SCOPE)
        _dev_dependency_unavailable(${name} "${dd_REQUIRED}" "not installed, no fetch source")
        return()
    endif()

    # --- 2. fetch ------------------------------------------------------------
    if(BUILDKIT_OFFLINE OR FETCHCONTENT_FULLY_DISCONNECTED
       OR "$CACHE{FETCHCONTENT_FULLY_DISCONNECTED}")
        set(offline TRUE)
    else()
        set(offline FALSE)
    endif()

    string(TOLOWER "${name}" lc)
    if(FETCHCONTENT_BASE_DIR)
        set(deps_dir "${FETCHCONTENT_BASE_DIR}")
    else()
        set(deps_dir "${CMAKE_BINARY_DIR}/_deps")
    endif()
    set(src_dir "${deps_dir}/${lc}-src")
    # A populated tree from an earlier configure (CMakeLists.txt present).
    set(have_src FALSE)
    if(EXISTS "${src_dir}/CMakeLists.txt")
        set(have_src TRUE)
    endif()

    set(ok FALSE)
    set(reason "")
    set(declare "")
    set(disconnected OFF)

    if(dd_FETCH_URL)
        string(REGEX REPLACE "[?#].*$" "" url_path "${dd_FETCH_URL}")
        get_filename_component(file_name "${url_path}" NAME)
        if(NOT file_name)
            message(FATAL_ERROR "dev_dependency(${name}): FETCH_URL has no file name: ${dd_FETCH_URL}")
        endif()
        set(local "${CMAKE_BINARY_DIR}/_downloads/${name}/${file_name}")
        string(TOLOWER "${dd_FETCH_SHA256}" want)

        # Reuse an earlier download when its hash still matches.
        if(EXISTS "${local}")
            if(want)
                file(SHA256 "${local}" have)
                if(have STREQUAL want)
                    set(ok TRUE)
                endif()
            else()
                set(ok TRUE)
            endif()
        endif()

        if(NOT ok AND offline)
            set(reason "offline (BUILDKIT_OFFLINE or FETCHCONTENT_FULLY_DISCONNECTED), not downloading")
        elseif(NOT ok)
            message(STATUS "${name}: downloading ${dd_FETCH_URL}")
            # No EXPECTED_HASH: a mismatch would be fatal, and configure must
            # not fail for an OPTIONAL dependency. The hash is checked below.
            # No total TIMEOUT (it would cut a slow but working download); a
            # stalled connection ends after INACTIVITY_TIMEOUT.
            file(DOWNLOAD "${dd_FETCH_URL}" "${local}"
                INACTIVITY_TIMEOUT 30 TLS_VERIFY ON STATUS st)
            list(GET st 0 code)
            list(GET st 1 msg)
            if(code EQUAL 0 AND want)
                file(SHA256 "${local}" have)
                if(NOT have STREQUAL want)
                    set(code 1)
                    set(msg "SHA-256 mismatch (got ${have})")
                endif()
            endif()
            if(code EQUAL 0)
                set(ok TRUE)
            else()
                file(REMOVE "${local}")
                set(reason "download failed: ${msg}")
            endif()
        endif()

        if(ok)
            set(declare URL "${local}" DOWNLOAD_EXTRACT_TIMESTAMP TRUE)
            if(want)
                list(APPEND declare URL_HASH SHA256=${want})
            endif()
        endif()
    else()
        if(offline)
            set(reason "offline (BUILDKIT_OFFLINE or FETCHCONTENT_FULLY_DISCONNECTED), not cloning")
        else()
            find_package(Git QUIET)
            if(NOT GIT_EXECUTABLE)
                set(reason "git not found")
            else()
                # A commit hash is not a ref: probe that the repo answers.
                if(dd_FETCH_TAG MATCHES "^[0-9a-fA-F]+$" AND NOT dd_FETCH_TAG MATCHES "^[0-9]+$")
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
                    set(reason "git ls-remote failed (${rc}) ${err}")
                endif()
            endif()
        endif()
        if(NOT ok AND have_src)
            # Cached clone from an earlier configure: use it without network.
            set(ok TRUE)
            set(disconnected ON)
            message(STATUS "${name}: ${reason}; using cached source ${src_dir}")
        endif()
        if(ok)
            set(declare GIT_REPOSITORY "${dd_FETCH_GIT}" GIT_TAG "${dd_FETCH_TAG}" GIT_SHALLOW TRUE)
        endif()
    endif()

    if(NOT ok)
        set(${dd_FOUND_VAR} FALSE PARENT_SCOPE)
        _dev_dependency_unavailable(${name} "${dd_REQUIRED}" "${reason}")
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

    message(STATUS "${name}: fetched")
    set(${dd_FOUND_VAR} TRUE PARENT_SCOPE)
endfunction()
