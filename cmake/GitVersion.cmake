# buildkit_git_version(<source_dir> <numeric_var> <full_var> [FALLBACK <x.y.z>])
#
# The version is the nearest tag vX.Y.Z or vX.Y.Z-beta.N. Usable before
# project(): it needs only find_program and execute_process.
#   numeric -- X.Y.Z, for project().
#   full    -- X.Y.Z, X.Y.Z-beta.N, or either followed by +<ahead>.g<sha7>
#              when HEAD is past the tag.
# Without git, without a matching tag, or when <source_dir> is not the
# toplevel of its own repository (a tree unpacked inside another checkout
# must not borrow that checkout's tags): numeric is FALLBACK (default 0.0.0)
# and full is <fallback>-dev, so a dev build never passes for a release.
function(buildkit_git_version source_dir numeric_var full_var)
    cmake_parse_arguments(PARSE_ARGV 3 arg "" "FALLBACK" "")
    if(arg_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "buildkit_git_version: unknown arguments: ${arg_UNPARSED_ARGUMENTS}")
    endif()
    if(NOT DEFINED arg_FALLBACK)
        set(arg_FALLBACK "0.0.0")
    endif()
    set(numeric "${arg_FALLBACK}")
    set(full "${arg_FALLBACK}-dev")

    find_program(BUILDKIT_GIT_EXECUTABLE git)
    if(BUILDKIT_GIT_EXECUTABLE)
        execute_process(
            COMMAND "${BUILDKIT_GIT_EXECUTABLE}" -C "${source_dir}" rev-parse --show-toplevel
            OUTPUT_VARIABLE toplevel OUTPUT_STRIP_TRAILING_WHITESPACE
            RESULT_VARIABLE toplevel_result ERROR_QUIET)
        get_filename_component(source_real "${source_dir}" REALPATH)
        get_filename_component(toplevel_real "${toplevel}" REALPATH)
        if(toplevel_result EQUAL 0 AND source_real STREQUAL toplevel_real)
            # Glob is coarse; the regex below is the real filter, so walk
            # the tags nearest-first until one matches.
            execute_process(
                COMMAND "${BUILDKIT_GIT_EXECUTABLE}" -C "${source_dir}" log --simplify-by-decoration
                        --decorate=full --format=%D HEAD
                OUTPUT_VARIABLE decorations OUTPUT_STRIP_TRAILING_WHITESPACE
                RESULT_VARIABLE log_result ERROR_QUIET)
            set(tag "")
            if(log_result EQUAL 0)
                string(REPLACE "\n" ";" lines "${decorations}")
                foreach(line IN LISTS lines)
                    string(REPLACE ", " ";" refs "${line}")
                    set(found "")
                    foreach(ref IN LISTS refs)
                        if(ref MATCHES "refs/tags/(v(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)(-beta\\.(0|[1-9][0-9]*))?)$")
                            list(APPEND found "${CMAKE_MATCH_1}")
                        endif()
                    endforeach()
                    if(found)
                        # Several tags on one commit: stable beats beta,
                        # then the highest by natural order.
                        set(stable ${found})
                        list(FILTER stable EXCLUDE REGEX "-beta\\.")
                        if(stable)
                            set(found ${stable})
                        endif()
                        list(SORT found COMPARE NATURAL ORDER DESCENDING)
                        list(GET found 0 tag)
                        break()
                    endif()
                endforeach()
            endif()
            if(tag MATCHES "^v(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)(-beta\\.(0|[1-9][0-9]*))?$")
                set(numeric "${CMAKE_MATCH_1}.${CMAKE_MATCH_2}.${CMAKE_MATCH_3}")
                set(full "${numeric}${CMAKE_MATCH_4}")
                execute_process(
                    COMMAND "${BUILDKIT_GIT_EXECUTABLE}" -C "${source_dir}" rev-list --count "${tag}..HEAD"
                    OUTPUT_VARIABLE ahead OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET)
                if(ahead GREATER 0)
                    execute_process(
                        COMMAND "${BUILDKIT_GIT_EXECUTABLE}" -C "${source_dir}" rev-parse --short=7 HEAD
                        OUTPUT_VARIABLE sha OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET)
                    set(full "${full}+${ahead}.g${sha}")
                endif()
            endif()
        endif()
    endif()

    set(${numeric_var} "${numeric}" PARENT_SCOPE)
    set(${full_var} "${full}" PARENT_SCOPE)
endfunction()
