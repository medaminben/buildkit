# Runs one fixture and checks it exactly. Inputs (-D):
#   FIXTURE_SRC, FIXTURE_BIN, BUILDKIT_DIR
#   FIXTURE_ARGS   extra configure args joined with '|' (spaces inside one arg are kept)
#   EXPECT_FAIL    ON: configure must fail; otherwise it must succeed
#   EXPECT_OUTPUT  regex that stdout+stderr of the configure must match
#   BUILD          ON: after a successful configure run `cmake --build` and
#                  `ctest --test-dir` on the fixture; any failure fails
# Any mismatch ends in FATAL_ERROR (the test fails).
file(REMOVE_RECURSE "${FIXTURE_BIN}")

set(args)
if(FIXTURE_ARGS)
    string(REPLACE "|" ";" args "${FIXTURE_ARGS}")
endif()

execute_process(
    COMMAND ${CMAKE_COMMAND} -S "${FIXTURE_SRC}" -B "${FIXTURE_BIN}"
            -DBUILDKIT_DIR=${BUILDKIT_DIR} ${args}
    RESULT_VARIABLE rc
    OUTPUT_VARIABLE out
    ERROR_VARIABLE err)
set(all "${out}${err}")
message("${all}")

if(EXPECT_FAIL)
    if(rc EQUAL 0)
        message(FATAL_ERROR "expected configure to fail, but it succeeded")
    endif()
else()
    if(NOT rc EQUAL 0)
        message(FATAL_ERROR "configure failed (exit ${rc}), expected success")
    endif()
endif()

if(EXPECT_OUTPUT AND NOT all MATCHES "${EXPECT_OUTPUT}")
    message(FATAL_ERROR "output does not match regex: ${EXPECT_OUTPUT}")
endif()

if(BUILD AND NOT EXPECT_FAIL)
    execute_process(COMMAND ${CMAKE_COMMAND} --build "${FIXTURE_BIN}"
        RESULT_VARIABLE rc OUTPUT_VARIABLE bout ERROR_VARIABLE berr)
    message("${bout}${berr}")
    if(NOT rc EQUAL 0)
        message(FATAL_ERROR "fixture build failed (exit ${rc})")
    endif()
    execute_process(
        COMMAND ${CMAKE_CTEST_COMMAND} --test-dir "${FIXTURE_BIN}" --output-on-failure
        RESULT_VARIABLE rc OUTPUT_VARIABLE tout ERROR_VARIABLE terr)
    message("${tout}${terr}")
    if(NOT rc EQUAL 0)
        message(FATAL_ERROR "fixture ctest failed (exit ${rc})")
    endif()
endif()
