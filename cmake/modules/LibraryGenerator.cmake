# Scaffold generator: creates library + app trees from templates when missing.
#
# generate_libraries(LIBRARIES_LIST <Lib>... LIBRARIES_LOCATION <dir>
#                    [APPS_LOCATION <dir>] [TEMPLATE_LOCATION <dir>])
#   For every <Lib> without a folder in LIBRARIES_LOCATION: writes the library
#   (CMakeLists, public header, sources, a GoogleTest file) and appends
#   add_subdirectory(<Lib>) to LIBRARIES_LOCATION/CMakeLists.txt. With
#   APPS_LOCATION, and no APPS_LOCATION/<Lib> folder yet, it also writes the
#   console app <Lib>_Console and the wxWidgets app <Lib>_Wx_UI. The wx app is
#   written unless BUILD_WX_UI is defined and OFF; it builds only when
#   wxWidgets is available.
#
#   Layout follows CMAKE_ROOT_NAME (see create_library):
#     unset (flat)  include/<Lib>/<Lib>.h, namespace <Lib>, <Lib>::<Lib>
#     set (legacy)  include/<Root>/<Lib>/<Lib>.h, namespace <Root>::<Lib>,
#                   <Root>::<Lib>
#
#   TEMPLATE_LOCATION defaults to buildkit's template/. A product template dir
#   with the pre-buildkit file names (app/lib_console_CMakeLists.txt.in,
#   lib_Console.cpp.in, lib_wx_ui_CMakeLists.txt.in, lib_Wx_UI.cpp.in) still
#   works; such templates read lib_ROOT_NAME and lib_ROOT_NAME_UPPER.
#
# generate_project(NAME <Name> DESTINATION <dir> [LIBRARIES <Lib>...]
#                  [TEMPLATE_LOCATION <dir>])
#   Writes <dir>/CMakeLists.txt, CMakePresets.json and .gitignore from
#   template/project/ and copies loader/buildkit.cmake to
#   <dir>/cmake/buildkit.cmake (files that exist are kept).
#
# Templates are configured with ${var} substitution; ${VAR_MARKER_START}x${VAR_MARKER_END}
# writes a literal ${x} into the generated file.
include_guard(GLOBAL)

set(VAR_MARKER_START [[${]])
set(VAR_MARKER_END })
get_filename_component(_buildkit_template_dir "${CMAKE_CURRENT_LIST_DIR}/../../template" ABSOLUTE)
set_property(GLOBAL PROPERTY BUILDKIT_TEMPLATE_DIR "${_buildkit_template_dir}")
unset(_buildkit_template_dir)
get_filename_component(_buildkit_loader "${CMAKE_CURRENT_LIST_DIR}/../../loader/buildkit.cmake" ABSOLUTE)
set_property(GLOBAL PROPERTY BUILDKIT_LOADER_FILE "${_buildkit_loader}")
unset(_buildkit_loader)

function(generate_libraries)
    set(options)
    set(single_value_args LIBRARIES_LOCATION APPS_LOCATION TEMPLATE_LOCATION)
    set(list_args LIBRARIES_LIST)
    cmake_parse_arguments(PARSE_ARGV 0 lib
        "${options}" "${single_value_args}" "${list_args}")

    foreach(arg IN LISTS lib_UNPARSED_ARGUMENTS)
        message(WARNING "unparsed argument: ${arg}")
    endforeach()

    if(NOT DEFINED lib_LIBRARIES_LOCATION OR lib_LIBRARIES_LOCATION STREQUAL "")
        message(STATUS "generate_libraries: missing LIBRARIES_LOCATION")
        return()
    endif()
    if(NOT DEFINED lib_TEMPLATE_LOCATION OR lib_TEMPLATE_LOCATION STREQUAL "")
        get_property(lib_TEMPLATE_LOCATION GLOBAL PROPERTY BUILDKIT_TEMPLATE_DIR)
    endif()

    foreach(item IN LISTS lib_LIBRARIES_LIST)
        if(IS_DIRECTORY ${lib_LIBRARIES_LOCATION}/${item})
            message(STATUS "scaffold: ${item} already present")
            continue()
        endif()

        message(STATUS "scaffold: generating ${item}")
        set(apps_args)
        if(DEFINED lib_APPS_LOCATION AND NOT lib_APPS_LOCATION STREQUAL "")
            set(apps_args APPS_DIR ${lib_APPS_LOCATION})
        endif()
        set(root_args)
        if(NOT "${CMAKE_ROOT_NAME}" STREQUAL "")
            set(root_args ROOT_NAME ${CMAKE_ROOT_NAME})
        endif()
        generate_library(
            NAME        ${item}
            DESTINATION ${lib_LIBRARIES_LOCATION}
            ${root_args}
            ${apps_args}
            CFG_SRC     ${lib_TEMPLATE_LOCATION}
        )
    endforeach()
endfunction()

# First existing <dir>/<name> of the candidate names, or FATAL_ERROR.
function(_buildkit_pick_template out dir)
    foreach(name IN LISTS ARGN)
        if(EXISTS "${dir}/${name}")
            set(${out} "${dir}/${name}" PARENT_SCOPE)
            return()
        endif()
    endforeach()
    message(FATAL_ERROR "scaffold: none of ${ARGN} found in ${dir}")
endfunction()

function(generate_library)
    set(options)
    set(list_args)
    set(single_value_args NAME DESTINATION ROOT_NAME APPS_DIR CFG_SRC)
    cmake_parse_arguments(PARSE_ARGV 0 lib
        "${options}" "${single_value_args}" "${list_args}")

    foreach(arg IN LISTS lib_UNPARSED_ARGUMENTS)
        message(WARNING "unparsed argument: ${arg}")
    endforeach()

    if(NOT DEFINED lib_NAME OR lib_NAME STREQUAL "")
        return()
    endif()
    if(NOT DEFINED lib_CFG_SRC OR lib_CFG_SRC STREQUAL "")
        get_property(lib_CFG_SRC GLOBAL PROPERTY BUILDKIT_TEMPLATE_DIR)
    endif()

    set(lib_DIR ${lib_DESTINATION}/${lib_NAME})
    if(IS_DIRECTORY "${lib_DIR}")
        message(STATUS "scaffold: ${lib_NAME} already present")
        return()
    endif()

    # Variables the templates read.
    string(TOUPPER ${lib_NAME} lib_NAME_UPPER)
    if(DEFINED lib_ROOT_NAME AND NOT lib_ROOT_NAME STREQUAL "")
        string(TOUPPER ${lib_ROOT_NAME} lib_ROOT_NAME_UPPER)
        set(lib_INCLUDE_DIR   ${lib_ROOT_NAME}/${lib_NAME})
        set(lib_EXPORT_HEADER ${lib_ROOT_NAME}_${lib_NAME}_export.h)
        set(lib_API           ${lib_ROOT_NAME_UPPER}_${lib_NAME_UPPER}_API)
        set(lib_NAMESPACE     ${lib_ROOT_NAME}::${lib_NAME})
        set(lib_TARGET        ${lib_ROOT_NAME}::${lib_NAME})
        set(lib_GUARD         ${lib_ROOT_NAME_UPPER}_${lib_NAME_UPPER})
    else()
        set(lib_ROOT_NAME "")
        set(lib_ROOT_NAME_UPPER "")
        set(lib_INCLUDE_DIR   ${lib_NAME})
        set(lib_EXPORT_HEADER ${lib_NAME}_export.h)
        set(lib_API           ${lib_NAME_UPPER}_API)
        set(lib_NAMESPACE     ${lib_NAME})
        set(lib_TARGET        ${lib_NAME}::${lib_NAME})
        set(lib_GUARD         ${lib_NAME_UPPER})
    endif()

    set(lib_include_DIR ${lib_DIR}/include/${lib_INCLUDE_DIR})
    set(lib_source_DIR  ${lib_DIR}/src)
    set(lib_test_DIR    ${lib_DIR}/test)
    set(lib_gen_DIR     ${lib_CFG_SRC}/lib)

    configure_file(${lib_gen_DIR}/lib_CMakeLists.txt.in ${lib_DIR}/CMakeLists.txt)
    configure_file(${lib_gen_DIR}/lib.h.in              ${lib_include_DIR}/${lib_NAME}.h)
    configure_file(${lib_gen_DIR}/lib.cpp.in            ${lib_source_DIR}/${lib_NAME}.cpp)
    configure_file(${lib_gen_DIR}/lib_impl.h.in         ${lib_source_DIR}/${lib_NAME}_impl.h)
    configure_file(${lib_gen_DIR}/lib_impl.cpp.in       ${lib_source_DIR}/${lib_NAME}_impl.cpp)
    configure_file(${lib_gen_DIR}/test_lib.cpp.in       ${lib_test_DIR}/src/test_${lib_NAME}.cpp)
    file(WRITE ${lib_test_DIR}/data/${lib_NAME}TestData.txt "")

    if(NOT EXISTS ${lib_DESTINATION}/CMakeLists.txt)
        file(WRITE ${lib_DESTINATION}/CMakeLists.txt
            "# Auto-generated; do not hand-edit unless you know the consequences.\n")
    endif()
    file(APPEND ${lib_DESTINATION}/CMakeLists.txt "\nadd_subdirectory(${lib_NAME})\n")

    message(STATUS "scaffold: ${lib_NAME} library generated")

    if(NOT DEFINED lib_APPS_DIR OR lib_APPS_DIR STREQUAL "")
        return()
    endif()

    # Hand-written applications win over scaffolds.
    if(IS_DIRECTORY ${lib_APPS_DIR}/${lib_NAME})
        message(STATUS "scaffold: apps for ${lib_NAME} already present")
        return()
    endif()

    message(STATUS "scaffold: generating apps for ${lib_NAME}")
    set(app_DIR ${lib_APPS_DIR}/${lib_NAME})
    set(app_gen_DIR ${lib_CFG_SRC}/app)

    _buildkit_pick_template(console_cmake ${app_gen_DIR}
        console_CMakeLists.txt.in lib_console_CMakeLists.txt.in)
    _buildkit_pick_template(console_cpp ${app_gen_DIR}
        Console.cpp.in lib_Console.cpp.in)

    file(WRITE ${app_DIR}/CMakeLists.txt "")
    file(APPEND ${app_DIR}/CMakeLists.txt "\nadd_subdirectory(${lib_NAME}_Console)\n")
    configure_file(${console_cmake} ${app_DIR}/${lib_NAME}_Console/CMakeLists.txt)
    configure_file(${console_cpp}   ${app_DIR}/${lib_NAME}_Console/${lib_NAME}_Console.cpp)

    if(NOT DEFINED BUILD_WX_UI OR BUILD_WX_UI)
        _buildkit_pick_template(wx_cmake ${app_gen_DIR}
            wx_CMakeLists.txt.in lib_wx_ui_CMakeLists.txt.in)
        _buildkit_pick_template(wx_cpp ${app_gen_DIR}
            WxApp.cpp.in lib_Wx_UI.cpp.in)
        file(APPEND ${app_DIR}/CMakeLists.txt "\nadd_subdirectory(${lib_NAME}_Wx_UI)\n")
        configure_file(${wx_cmake} ${app_DIR}/${lib_NAME}_Wx_UI/CMakeLists.txt)
        configure_file(${wx_cpp}   ${app_DIR}/${lib_NAME}_Wx_UI/${lib_NAME}_Wx_UI.cpp)
    endif()

    if(NOT EXISTS ${lib_APPS_DIR}/CMakeLists.txt)
        file(WRITE ${lib_APPS_DIR}/CMakeLists.txt
            "# Auto-generated; do not hand-edit unless you know the consequences.\n")
    endif()
    file(APPEND ${lib_APPS_DIR}/CMakeLists.txt "\nadd_subdirectory(${lib_NAME})\n")
endfunction()

function(generate_project)
    cmake_parse_arguments(PARSE_ARGV 0 prj "" "NAME;DESTINATION;TEMPLATE_LOCATION" "LIBRARIES")
    if(prj_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "generate_project: unknown arguments: ${prj_UNPARSED_ARGUMENTS}")
    endif()
    if(NOT prj_NAME OR NOT prj_DESTINATION)
        message(FATAL_ERROR "generate_project: NAME and DESTINATION are required")
    endif()
    if(NOT prj_NAME MATCHES "^[A-Za-z][A-Za-z0-9_]*$")
        message(FATAL_ERROR "generate_project: NAME '${prj_NAME}' must be a C identifier")
    endif()
    if(NOT prj_TEMPLATE_LOCATION)
        get_property(prj_TEMPLATE_LOCATION GLOBAL PROPERTY BUILDKIT_TEMPLATE_DIR)
    endif()

    # @ONLY variables of template/project/*.in
    set(project_NAME ${prj_NAME})
    string(TOUPPER ${prj_NAME} project_NAME_UPPER)
    set(project_LIBRARIES "")
    foreach(l IN LISTS prj_LIBRARIES)
        string(APPEND project_LIBRARIES "\n    ${l}")
    endforeach()

    foreach(pair "CMakeLists.txt.in|CMakeLists.txt"
                 "CMakePresets.json.in|CMakePresets.json"
                 "gitignore.in|.gitignore")
        string(REPLACE "|" ";" pair "${pair}")
        list(GET pair 0 src)
        list(GET pair 1 dst)
        if(EXISTS "${prj_DESTINATION}/${dst}")
            message(STATUS "generate_project: ${dst} already present")
            continue()
        endif()
        configure_file("${prj_TEMPLATE_LOCATION}/project/${src}" "${prj_DESTINATION}/${dst}" @ONLY)
    endforeach()
    # The product loader: a copy of buildkit's loader/buildkit.cmake.
    if(NOT EXISTS "${prj_DESTINATION}/cmake/buildkit.cmake")
        get_property(loader_file GLOBAL PROPERTY BUILDKIT_LOADER_FILE)
        configure_file("${loader_file}"
                       "${prj_DESTINATION}/cmake/buildkit.cmake" COPYONLY)
    endif()
    message(STATUS "generate_project: ${prj_NAME} written to ${prj_DESTINATION}")
endfunction()
