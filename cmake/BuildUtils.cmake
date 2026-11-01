# Architecture detection and target helpers.

macro(get_project_arch)
    if(CMAKE_SIZEOF_VOID_P EQUAL 8)
        set(PROJECT_ARCH_TARGET "amd64")
    elseif(CMAKE_SIZEOF_VOID_P EQUAL 4)
        set(PROJECT_ARCH_TARGET "i386")
    else()
        message(WARNING "Unknown architecture!")
    endif()
endmacro()

function(check_project_name)
    set(options)
    set(single_value_args NAME)
    set(list_args NAME_LIST)
    cmake_parse_arguments(PARSE_ARGV 0 parameter "${options}" "${single_value_args}" "${list_args}")

    foreach(arg IN LISTS parameter_UNPARSED_ARGUMENTS)
        message(WARNING "unparsed argument: ${arg}")
    endforeach()

    foreach(proj IN LISTS parameter_NAME_LIST)
        if(proj STREQUAL parameter_NAME)
            message(FATAL_ERROR "name already exists: ${proj}")
        endif()
    endforeach()
endfunction()

macro(add_project name name_list)
    check_project_name(NAME ${name} NAME_LIST ${${name_list}})
    list(APPEND ${name_list} ${name})
endmacro()

# Convert "Bowlingbox::Core" -> "bowlingbox_core" for add_library().
macro(get_raw_target_name qualified_name out_var)
    string(REPLACE "::" "_" ${out_var} ${qualified_name})
    string(TOLOWER ${${out_var}} ${out_var})
endmacro()

# _buildkit_runtime_component(<out>): "COMPONENT <name>" for install(), or
# empty. BUILDKIT_RUNTIME_COMPONENT wins; in the legacy layout the product's
# own <ROOT>_RUNTIME_COMPONENT (e.g. BOWLINGBOX_RUNTIME_COMPONENT) is used.
function(_buildkit_runtime_component out)
    set(component "${BUILDKIT_RUNTIME_COMPONENT}")
    if(component STREQUAL "" AND NOT "${CMAKE_ROOT_NAME}" STREQUAL "")
        string(TOUPPER "${CMAKE_ROOT_NAME}" root_upper)
        set(component "${${root_upper}_RUNTIME_COMPONENT}")
    endif()
    if(component STREQUAL "")
        set(${out} "" PARENT_SCOPE)
    else()
        set(${out} COMPONENT "${component}" PARENT_SCOPE)
    endif()
endfunction()

# ---------------------------------------------------------------------------
# create_library — shared/static library with export header + optional tests
#
# create_library(LIB_NAME <Lib> LIB_FILES <files>...
#                [PUBLIC_DEPENDENCIES <t>...] [PRIVATE_DEPENDENCIES <t>...]
#                [TEST_DISCOVER <bool>] [TEST_SOURCES <files>...]
#                [TEST_DEPENDENCIES <t>...] [LIB_RSC <files>...])
#
#                     legacy (CMAKE_ROOT_NAME set)   flat (unset)
#   target            <root>_<lib> (lower case)      <Lib>
#   alias             <Root>::<Lib>                  <Lib>::<Lib>
#   export header     include/<Root>/<Lib>/          include/<Lib>/
#                       <Root>_<Lib>_export.h          <Lib>_export.h
#   export macro      <ROOT>_<LIB>_API               <LIB>_API
#   OUTPUT_NAME       <Root><Lib>                    <Lib>
#   EXPORT_NAME       <Lib>                          <Lib>::<Lib>
#   install EXPORT    <Root>Targets                  <CMAKE_PROJECT_NAME>Targets
#   test executable   test_<root>_<lib>              test_<lib>
#
# LIB_RSC files are copied to ${PROJECT_BUILD_OUTPUT}/data/<target>/ when
# tests are built; discovered tests run in the runtime output dir (bin/), so
# they open ../data/<target>/<file>.
# ---------------------------------------------------------------------------
function(create_library)
    set(options)
    set(single_value_args LIB_NAME TEST_DISCOVER)
    set(list_args LIB_FILES PRIVATE_DEPENDENCIES PUBLIC_DEPENDENCIES
                  TEST_SOURCES TEST_DEPENDENCIES LIB_RSC)
    cmake_parse_arguments(PARSE_ARGV 0 parameter
        "${options}" "${single_value_args}" "${list_args}")

    foreach(arg IN LISTS parameter_UNPARSED_ARGUMENTS)
        message(WARNING "unparsed argument: ${arg}")
    endforeach()

    if(NOT parameter_LIB_NAME)
        message(FATAL_ERROR "create_library: LIB_NAME is required")
    endif()

    include(GNUInstallDirs)
    include(GenerateExportHeader)

    set(lib ${parameter_LIB_NAME})
    string(TOUPPER ${lib} LIB_FLAG)

    if(DEFINED CMAKE_ROOT_NAME AND NOT CMAKE_ROOT_NAME STREQUAL "")
        # Legacy layout (Bowlingbox, unitpro <= 1.x).
        set(LIBRARY_NAME ${CMAKE_ROOT_NAME}::${lib})
        get_raw_target_name(${LIBRARY_NAME} LIBRARY_NAME_RAW)
        string(TOUPPER ${CMAKE_ROOT_NAME} ROOT_FLAG)
        set(_export_dir  "${CMAKE_CURRENT_BINARY_DIR}/include/${CMAKE_ROOT_NAME}/${lib}")
        set(_export_file "${CMAKE_ROOT_NAME}_${lib}_export.h")
        set(_export_base ${ROOT_FLAG}_${LIB_FLAG})
        set(_output_name "${CMAKE_ROOT_NAME}${lib}")
        set(_export_name "${lib}")
        set(_export_set  ${CMAKE_ROOT_NAME}Targets)
    else()
        # Flat layout: one namespace per library.
        set(LIBRARY_NAME ${lib}::${lib})
        set(LIBRARY_NAME_RAW ${lib})
        set(_export_dir  "${CMAKE_CURRENT_BINARY_DIR}/include/${lib}")
        set(_export_file "${lib}_export.h")
        set(_export_base ${LIB_FLAG})
        set(_output_name "${lib}")
        set(_export_name "${lib}::${lib}")
        set(_export_set  ${CMAKE_PROJECT_NAME}Targets)
    endif()

    add_library(${LIBRARY_NAME_RAW} ${parameter_LIB_FILES})
    add_library(${LIBRARY_NAME} ALIAS ${LIBRARY_NAME_RAW})

    file(MAKE_DIRECTORY "${_export_dir}")
    generate_export_header(${LIBRARY_NAME_RAW}
        EXPORT_FILE_NAME  "${_export_dir}/${_export_file}"
        EXPORT_MACRO_NAME ${_export_base}_API
        BASE_NAME         ${_export_base}
        DEFINE_NO_DEPRECATED
    )

    target_include_directories(${LIBRARY_NAME_RAW}
        PUBLIC
            $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
            $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/include>
            $<INSTALL_INTERFACE:include>
    )

    target_link_libraries(${LIBRARY_NAME_RAW}
        PRIVATE ${parameter_PRIVATE_DEPENDENCIES}
        PUBLIC  ${parameter_PUBLIC_DEPENDENCIES}
    )

    buildkit_set_warnings(${LIBRARY_NAME_RAW})

    set_target_properties(${LIBRARY_NAME_RAW} PROPERTIES
        OUTPUT_NAME "${_output_name}"
        EXPORT_NAME "${_export_name}"
        CXX_VISIBILITY_PRESET hidden
        VISIBILITY_INLINES_HIDDEN ON
    )
    if(NOT "${PROJECT_VERSION}" STREQUAL "")
        set_target_properties(${LIBRARY_NAME_RAW} PROPERTIES
            VERSION   ${PROJECT_VERSION}
            SOVERSION ${PROJECT_VERSION_MAJOR}
        )
    endif()

    _buildkit_runtime_component(_component_args)
    install(TARGETS ${LIBRARY_NAME_RAW}
        EXPORT ${_export_set}
        ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
        RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
                ${_component_args}
        INCLUDES DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
    )

    install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/include/
        DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
    )
    install(DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/include/
        DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
    )

    if(BUILD_TESTING AND parameter_TEST_SOURCES)
        string(TOLOWER "test_${LIBRARY_NAME_RAW}" TEST_NAME)
        set(GTEST_DEPENDENCIES GTest::gtest GTest::gmock GTest::gmock_main)

        build_gtest_executable(
            NAME ${TEST_NAME}
            SRC  ${parameter_TEST_SOURCES}
            DEPENDS
                ${parameter_TEST_DEPENDENCIES}
                ${GTEST_DEPENDENCIES}
                ${LIBRARY_NAME}
            DISCOVER ${parameter_TEST_DISCOVER}
        )

        set(_data_root "${PROJECT_BUILD_OUTPUT}")
        if(_data_root STREQUAL "")
            set(_data_root "${CMAKE_BINARY_DIR}")
        endif()
        foreach(item IN LISTS parameter_LIB_RSC)
            set(_rsc "${item}")
            if(NOT IS_ABSOLUTE "${_rsc}")
                set(_rsc "${CMAKE_CURRENT_SOURCE_DIR}/${item}")
            endif()
            if(EXISTS "${_rsc}")
                file(COPY "${_rsc}" DESTINATION "${_data_root}/data/${LIBRARY_NAME_RAW}")
            endif()
        endforeach()
    endif()
endfunction()

# ---------------------------------------------------------------------------
# create_application — executable of kind ENTRY (Console or WX_ui)
#
# create_application(NAME <n> ENTRY <Console|WX_ui> [SOURCES ...] [HEADERS ...]
#                    [RESOURCES ...] [UI <file>] [BUILD_ARGS ...]
#                    [DEPENDENCIES ...] [COMPONENT <install component>])
#
# WX_ui apps are WIN32/MACOSX_BUNDLE executables. A project that defines
# BUILD_WX_UI (Bowlingbox) must guard WX_ui calls with if(BUILD_WX_UI); the
# generated wx app guards itself with if(wxWidgets_AVAILABLE).
# ---------------------------------------------------------------------------
function(create_application)
    # Empty keyword args (e.g. UI with no value) are allowed for app scaffolds.
    if(POLICY CMP0174)
        cmake_policy(SET CMP0174 NEW)
    endif()

    set(options)
    set(single_value_args NAME ENTRY UI COMPONENT)
    set(list_args HEADERS SOURCES RESOURCES BUILD_ARGS DEPENDENCIES)
    cmake_parse_arguments(PARSE_ARGV 0 app
        "${options}" "${single_value_args}" "${list_args}")

    foreach(arg IN LISTS app_UNPARSED_ARGUMENTS)
        message(WARNING "unparsed argument: ${arg}")
    endforeach()

    set(_entries Console WX_ui)
    if(NOT app_ENTRY IN_LIST _entries)
        message(FATAL_ERROR "${app_NAME}: ENTRY must be one of ${_entries}, got '${app_ENTRY}'")
    endif()
    if(app_ENTRY STREQUAL "WX_ui" AND DEFINED BUILD_WX_UI AND NOT BUILD_WX_UI)
        message(FATAL_ERROR "${app_NAME}: ENTRY WX_ui needs BUILD_WX_UI=ON; guard the call with if(BUILD_WX_UI)")
    endif()

    include(GNUInstallDirs)

    set(PROJECT_FILES ${app_HEADERS} ${app_SOURCES} ${app_RESOURCES})
    if(DEFINED app_UI AND NOT app_UI STREQUAL "")
        list(APPEND PROJECT_FILES ${app_UI})
    endif()

    add_executable(${app_NAME} ${app_BUILD_ARGS} ${PROJECT_FILES})
    target_link_libraries(${app_NAME} PRIVATE ${app_DEPENDENCIES})
    if(NOT app_ENTRY STREQUAL "Console")
        set_target_properties(${app_NAME} PROPERTIES
            WIN32_EXECUTABLE TRUE
            MACOSX_BUNDLE TRUE
        )
    endif()
    buildkit_set_warnings(${app_NAME})
    # COMPONENT puts the app into a named install component (e.g. the one a
    # Windows installer stages).
    set(_component_args)
    if(app_COMPONENT)
        set(_component_args COMPONENT ${app_COMPONENT})
    endif()
    install(TARGETS ${app_NAME}
        RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR} ${_component_args}
        BUNDLE  DESTINATION ${CMAKE_INSTALL_BINDIR} ${_component_args}
    )
endfunction()
