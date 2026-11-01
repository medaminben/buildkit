# Builds demo_manual and checks that it wrote manual/ar/index.html.
execute_process(COMMAND ${CMAKE_COMMAND} --build ${BIN_DIR} --target demo_manual
    RESULT_VARIABLE rc)
if(NOT rc EQUAL 0)
    message(FATAL_ERROR "demo_manual failed to build")
endif()
if(NOT EXISTS "${BIN_DIR}/manual/ar/index.html")
    message(FATAL_ERROR "manual/ar/index.html was not built")
endif()
