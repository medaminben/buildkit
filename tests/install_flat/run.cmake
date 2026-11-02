# Installs the flat layout fixture (tests/layout/flat) and consumes it.
# Inputs (-D): BUILDKIT_DIR, WORK_DIR (under build/).
#   1. configure + build the fixture (no GoogleTest: BUILD_TESTING=OFF), install it
#      into <WORK_DIR>/prefix
#   2. a second project (tests/install_flat/consumer) runs
#      find_package(LayoutFlat CONFIG), links Vision::Vision, builds and runs
get_filename_component(here "${CMAKE_CURRENT_LIST_FILE}" DIRECTORY)
set(flat "${here}/../layout/flat")
file(REMOVE_RECURSE "${WORK_DIR}")

function(step what)
    execute_process(COMMAND ${ARGN} RESULT_VARIABLE rc OUTPUT_VARIABLE o ERROR_VARIABLE e)
    if(NOT rc EQUAL 0)
        message(FATAL_ERROR "${what} failed (exit ${rc})\n${o}${e}")
    endif()
    message(STATUS "${what}: ok")
endfunction()

step("configure flat" "${CMAKE_COMMAND}" -S "${flat}" -B "${WORK_DIR}/flat"
    -DBUILDKIT_DIR=${BUILDKIT_DIR} -DBUILD_TESTING=OFF)
step("build flat" "${CMAKE_COMMAND}" --build "${WORK_DIR}/flat")
step("install flat" "${CMAKE_COMMAND}" --install "${WORK_DIR}/flat" --prefix "${WORK_DIR}/prefix")

file(GLOB_RECURSE targets "${WORK_DIR}/prefix/*LayoutFlatTargets.cmake")
if(NOT targets)
    message(FATAL_ERROR "no LayoutFlatTargets.cmake installed under ${WORK_DIR}/prefix")
endif()

step("configure consumer" "${CMAKE_COMMAND}" -S "${here}/consumer" -B "${WORK_DIR}/consumer"
    "-DCMAKE_PREFIX_PATH=${WORK_DIR}/prefix")
step("build consumer" "${CMAKE_COMMAND}" --build "${WORK_DIR}/consumer")
step("run consumer" "${CMAKE_CTEST_COMMAND}" --test-dir "${WORK_DIR}/consumer" --no-tests=error
    --output-on-failure)
message(STATUS "INSTALL_FLAT_OK")
