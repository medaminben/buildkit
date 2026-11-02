# Shared multilingual user manual (Markdown -> static HTML), tools/manual/build_manual.py.
#
#   buildkit_add_manual(<name> ROOT <dir> [LABELS <json>] [TITLE <text>])
#
# ROOT    manual directory with content/<lang>/*.md and assets/ (relative paths
#         are taken from the calling CMakeLists.txt)
# LABELS  JSON {lang: [labels]}; every `label` in the pages must be listed
# TITLE   site title (default: "User manual")
#
# The manual ships inside the installer and must work offline: the check fails
# on any http:// or https:// URL in a page. In this Markdown dialect a backtick
# span is always an application label, never inline code.
#
# Adds the target <name>_manual (builds into ${CMAKE_BINARY_DIR}/manual, not part
# of ALL) and the ctest test <name>_manual_check. Without Python >= 3.11 it only
# prints a status message and adds nothing.
include_guard(GLOBAL)

set(BUILDKIT_MANUAL_SCRIPT "${CMAKE_CURRENT_LIST_DIR}/../tools/manual/build_manual.py")
cmake_path(NORMAL_PATH BUILDKIT_MANUAL_SCRIPT)

function(buildkit_add_manual name)
    cmake_parse_arguments(PARSE_ARGV 1 bm "" "ROOT;LABELS;TITLE" "")
    if(NOT bm_ROOT)
        message(FATAL_ERROR "buildkit_add_manual: ROOT is required")
    endif()
    if(bm_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "buildkit_add_manual: unknown arguments: ${bm_UNPARSED_ARGUMENTS}")
    endif()

    find_package(Python3 3.11 QUIET COMPONENTS Interpreter)
    if(NOT Python3_Interpreter_FOUND)
        message(STATUS "buildkit_add_manual(${name}): Python 3.11+ not found, no manual targets")
        return()
    endif()

    cmake_path(ABSOLUTE_PATH bm_ROOT BASE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}" NORMALIZE)
    set(extra "")
    if(bm_LABELS)
        cmake_path(ABSOLUTE_PATH bm_LABELS BASE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}" NORMALIZE)
        list(APPEND extra --labels "${bm_LABELS}")
    endif()
    set(title_args "")
    if(bm_TITLE)
        set(title_args --title "${bm_TITLE}")
    endif()

    file(GLOB_RECURSE sources CONFIGURE_DEPENDS "${bm_ROOT}/*")
    add_custom_target(${name}_manual
        COMMAND ${Python3_EXECUTABLE} -B -I "${BUILDKIT_MANUAL_SCRIPT}"
                --root "${bm_ROOT}" --out "${CMAKE_BINARY_DIR}/manual" ${title_args} ${extra}
        SOURCES ${sources}
        COMMENT "Building the ${name} manual"
        VERBATIM)
    add_test(NAME ${name}_manual_check
        COMMAND ${Python3_EXECUTABLE} -B -I "${BUILDKIT_MANUAL_SCRIPT}"
                --root "${bm_ROOT}" --check ${extra})
endfunction()
