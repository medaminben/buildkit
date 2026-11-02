# Builds <app>_stage and checks the staged executable exists.
execute_process(COMMAND "${CMAKE_COMMAND}" --build "${BIN_DIR}" --target ${APP}_stage
    RESULT_VARIABLE rc OUTPUT_VARIABLE o ERROR_VARIABLE e)
if(NOT rc EQUAL 0)
    message(FATAL_ERROR "stage build failed: ${o}${e}")
endif()
if(NOT EXISTS "${EXPECTED}")
    message(FATAL_ERROR "missing staged file: ${EXPECTED}")
endif()
