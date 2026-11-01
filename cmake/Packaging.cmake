# Packaging: a stage target and an Inno Setup installer target.
#
#   buildkit_add_stage_target(<app_target> [STAGE_DIR <dir>] [INSTALL_SCRIPTS <file>...])
#       Creates <app_target>_stage: runs 'cmake --install' into STAGE_DIR
#       (default ${CMAKE_BINARY_DIR}/stage). Each INSTALL_SCRIPTS file is added
#       with install(SCRIPT) so it runs during that install (e.g. to copy runtime data).
#
#   buildkit_add_inno_installer(<app_target> ISS <file.iss> [DEFINES <k>=<v>...]
#                               [OUTPUT_DIR <dir>] [VERSION <v>])
#       Creates <app_target>_installer (depends on <app_target>_stage). Runs ISCC with
#       /DAppVersion=<v> /DStageDir=<stage> /O<OUTPUT_DIR, default ${CMAKE_BINARY_DIR}/dist>.
#       <v> is VERSION, else ${PROJECT_VERSION_FULL} (set it from buildkit_git_version),
#       else ${PROJECT_VERSION}. ISCC.exe is searched natively on Windows; on Linux it is
#       run as 'wine ISCC.exe' with the path in the BUILDKIT_ISCC cache entry. When ISCC
#       (or wine) is missing no target is created and a status message is printed.
#       Requires buildkit_add_stage_target(<app_target>) first.
include_guard(GLOBAL)

set(BUILDKIT_ISCC "" CACHE FILEPATH "Path to Inno Setup's ISCC.exe (used with wine on Linux)")

function(buildkit_add_stage_target app)
    cmake_parse_arguments(PARSE_ARGV 1 arg "" "STAGE_DIR" "INSTALL_SCRIPTS")
    if(arg_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "buildkit_add_stage_target: unknown arguments: ${arg_UNPARSED_ARGUMENTS}")
    endif()
    if(NOT TARGET ${app})
        message(FATAL_ERROR "buildkit_add_stage_target: no target '${app}'")
    endif()
    if(NOT arg_STAGE_DIR)
        set(arg_STAGE_DIR "${CMAKE_BINARY_DIR}/stage")
    endif()
    foreach(script IN LISTS arg_INSTALL_SCRIPTS)
        install(SCRIPT "${script}")
    endforeach()
    add_custom_target(${app}_stage
        COMMAND "${CMAKE_COMMAND}" --install "${CMAKE_BINARY_DIR}"
                --prefix "${arg_STAGE_DIR}" --config "$<CONFIG>"
        DEPENDS ${app}
        COMMENT "Staging ${app} into ${arg_STAGE_DIR}"
        VERBATIM)
    set_property(TARGET ${app}_stage PROPERTY BUILDKIT_STAGE_DIR "${arg_STAGE_DIR}")
endfunction()

function(buildkit_add_inno_installer app)
    cmake_parse_arguments(PARSE_ARGV 1 arg "" "ISS;OUTPUT_DIR;VERSION" "DEFINES")
    if(arg_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "buildkit_add_inno_installer: unknown arguments: ${arg_UNPARSED_ARGUMENTS}")
    endif()
    if(NOT arg_ISS)
        message(FATAL_ERROR "buildkit_add_inno_installer: ISS is required")
    endif()
    if(NOT TARGET ${app}_stage)
        message(FATAL_ERROR
            "buildkit_add_inno_installer: call buildkit_add_stage_target(${app}) first")
    endif()
    if(NOT arg_OUTPUT_DIR)
        set(arg_OUTPUT_DIR "${CMAKE_BINARY_DIR}/dist")
    endif()
    if(arg_VERSION)
        set(version "${arg_VERSION}")
    elseif(PROJECT_VERSION_FULL)
        set(version "${PROJECT_VERSION_FULL}")
    else()
        set(version "${PROJECT_VERSION}")
    endif()
    get_target_property(stage ${app}_stage BUILDKIT_STAGE_DIR)

    # Locate ISCC. A BUILDKIT_ISCC value that does not exist counts as not found.
    set(iscc "")
    set(runner "")
    if(WIN32)
        if(NOT BUILDKIT_ISCC)
            find_program(BUILDKIT_ISCC NAMES ISCC.exe ISCC
                PATHS "$ENV{ProgramFiles\(x86\)}/Inno Setup 6" "$ENV{ProgramFiles}/Inno Setup 6")
        endif()
        if(BUILDKIT_ISCC AND EXISTS "${BUILDKIT_ISCC}")
            set(iscc "${BUILDKIT_ISCC}")
        endif()
    else()
        find_program(BUILDKIT_WINE wine)
        if(BUILDKIT_WINE AND BUILDKIT_ISCC AND EXISTS "${BUILDKIT_ISCC}")
            set(iscc "${BUILDKIT_ISCC}")
            set(runner "${BUILDKIT_WINE}")
        endif()
    endif()
    if(NOT iscc)
        message(STATUS "${app}_installer: ISCC not found (set BUILDKIT_ISCC; "
            "on Linux wine is also needed); target skipped")
        return()
    endif()

    # Under wine, hand ISCC Windows paths on the Z: drive.
    set(stage_arg "${stage}")
    set(out_arg "${arg_OUTPUT_DIR}")
    set(iss_arg "${arg_ISS}")
    set(iscc_arg "${iscc}")
    if(runner)
        foreach(v IN ITEMS stage_arg out_arg iss_arg iscc_arg)
            string(REPLACE "/" "\\" ${v} "Z:${${v}}")
        endforeach()
    endif()

    set(defines "/DAppVersion=${version}" "/DStageDir=${stage_arg}")
    foreach(kv IN LISTS arg_DEFINES)
        list(APPEND defines "/D${kv}")
    endforeach()

    file(MAKE_DIRECTORY "${arg_OUTPUT_DIR}")
    add_custom_target(${app}_installer
        COMMAND ${runner} "${iscc_arg}" ${defines} "/O${out_arg}" "${iss_arg}"
        DEPENDS ${app}_stage
        COMMENT "Building ${app} installer ${version}"
        VERBATIM)
endfunction()
