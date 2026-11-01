# Runs one fixture configure: cmake -S FIXTURE_SRC -B FIXTURE_BIN -DBUILDKIT_DIR=...
# The configure output is forwarded so CTest can match it; a failed configure
# makes this script (and so the test) fail.
file(REMOVE_RECURSE "${FIXTURE_BIN}")
execute_process(
    COMMAND ${CMAKE_COMMAND} -S "${FIXTURE_SRC}" -B "${FIXTURE_BIN}"
            -DBUILDKIT_DIR=${BUILDKIT_DIR} ${FIXTURE_ARGS}
    RESULT_VARIABLE rc
    OUTPUT_VARIABLE out
    ERROR_VARIABLE err)
message("${out}")
message("${err}")
if(NOT rc EQUAL 0)
    message(FATAL_ERROR "fixture configure failed (exit ${rc})")
endif()
