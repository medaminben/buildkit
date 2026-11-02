# Configure, build and test the generated product with one of its presets.
foreach(step "--preset;${PRESET}" "--build;--preset;${PRESET}")
    execute_process(COMMAND ${CMAKE_COMMAND} ${step}
        WORKING_DIRECTORY ${PRODUCT} RESULT_VARIABLE rc)
    if(NOT rc EQUAL 0)
        message(FATAL_ERROR "cmake ${step} failed (${rc})")
    endif()
endforeach()
execute_process(COMMAND ${CMAKE_CTEST_COMMAND} --preset ${PRESET}
    WORKING_DIRECTORY ${PRODUCT} RESULT_VARIABLE rc)
if(NOT rc EQUAL 0)
    message(FATAL_ERROR "ctest --preset ${PRESET} failed (${rc})")
endif()
