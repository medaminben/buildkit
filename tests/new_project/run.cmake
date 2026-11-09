# Runs scripts/new-project.sh the way a user does: from an empty folder.
# Inputs (-D): BUILDKIT_DIR, WORK_DIR (under build/).
#   1. refused inside the buildkit source tree, for an invalid name and for an
#      unknown option
#   2. a full run with --repo in <WORK_DIR>/Demo: project and community files,
#      user presets, VS Code files, generated library, build, tests and the
#      console app
#   3. a file that exists before the run is kept
find_program(BASH bash REQUIRED)
set(script "${BUILDKIT_DIR}/scripts/new-project.sh")
file(REMOVE_RECURSE "${WORK_DIR}")

function(run_script dir rc_var out_var)
    execute_process(COMMAND "${BASH}" "${script}" ${ARGN}
        WORKING_DIRECTORY "${dir}"
        RESULT_VARIABLE rc OUTPUT_VARIABLE o ERROR_VARIABLE e)
    set(${rc_var} "${rc}" PARENT_SCOPE)
    set(${out_var} "${o}${e}" PARENT_SCOPE)
endfunction()

# 1. Refusals stop before anything is written.
run_script("${BUILDKIT_DIR}/tests" rc out)
if(rc EQUAL 0 OR NOT out MATCHES "not inside buildkit")
    message(FATAL_ERROR "inside the buildkit source tree: exit ${rc}\n${out}")
endif()

file(MAKE_DIRECTORY "${WORK_DIR}/bad")
run_script("${WORK_DIR}/bad" rc out 1bad)
if(rc EQUAL 0 OR NOT out MATCHES "'1bad' is not a valid name")
    message(FATAL_ERROR "invalid name: exit ${rc}\n${out}")
endif()
run_script("${WORK_DIR}/bad" rc out --bogus)
if(rc EQUAL 0 OR NOT out MATCHES "unknown option --bogus")
    message(FATAL_ERROR "unknown option: exit ${rc}\n${out}")
endif()
file(GLOB written "${WORK_DIR}/bad/*")
if(written)
    message(FATAL_ERROR "refused runs wrote files: ${written}")
endif()

# 2. + 3. Full run as a public product; the settings file written beforehand must survive.
set(demo "${WORK_DIR}/Demo")
file(WRITE "${demo}/.vscode/settings.json" "{ \"kept\": true }\n")
run_script("${demo}" rc out --repo octo/Demo)
if(NOT rc EQUAL 0)
    message(FATAL_ERROR "new-project.sh failed (exit ${rc})\n${out}")
endif()
if(NOT out MATCHES "==> Done")
    message(FATAL_ERROR "no '==> Done' in the output\n${out}")
endif()

foreach(f CMakeLists.txt CMakePresets.json CMakeUserPresets.json .gitignore
          cmake/buildkit.cmake libraries/Core/CMakeLists.txt
          .vscode/tasks.json .vscode/launch.json build/debug/bin/Core_Console
          LICENSE SECURITY.md CODE_OF_CONDUCT.md CONTRIBUTING.md
          .github/pull_request_template.md)
    if(NOT EXISTS "${demo}/${f}")
        message(FATAL_ERROR "new-project.sh did not create ${f}")
    endif()
endforeach()

file(READ "${demo}/CMakeUserPresets.json" user_presets)
string(JSON dir GET "${user_presets}" configurePresets 0 cacheVariables BUILDKIT_DIR)
if(NOT dir STREQUAL BUILDKIT_DIR)
    message(FATAL_ERROR "CMakeUserPresets.json points at ${dir}, not ${BUILDKIT_DIR}")
endif()
file(READ "${demo}/.vscode/launch.json" launch)
if(NOT launch MATCHES "build/debug/bin/Core_Console")
    message(FATAL_ERROR "launch.json does not run Core_Console\n${launch}")
endif()
file(READ "${demo}/SECURITY.md" security)
if(NOT security MATCHES "github.com/octo/Demo/security")
    message(FATAL_ERROR "SECURITY.md does not link octo/Demo")
endif()
file(READ "${demo}/.vscode/settings.json" settings)
if(NOT settings MATCHES "\"kept\"")
    message(FATAL_ERROR "an existing .vscode/settings.json was overwritten")
endif()

message(STATUS "NEW_PROJECT_OK")
