# Builds pkgapp_installer with the fake wine and checks the recorded ISCC argv.
set(log "${BIN_DIR}/argv.log")
file(REMOVE "${log}")
execute_process(COMMAND "${CMAKE_COMMAND}" -E env "BUILDKIT_FAKE_LOG=${log}"
    "${CMAKE_COMMAND}" --build "${BIN_DIR}" --target pkgapp_installer
    RESULT_VARIABLE rc OUTPUT_VARIABLE o ERROR_VARIABLE e)
if(NOT rc EQUAL 0)
    message(FATAL_ERROR "installer build failed: ${o}${e}")
endif()
file(READ "${log}" text)
string(REGEX REPLACE "\n$" "" text "${text}")
string(REPLACE ";" "<SEMI>" text "${text}")
string(REPLACE "\n" ";" args "${text}")

function(winpath var path)
    string(REPLACE "/" "\\" p "Z:${path}")
    set(${var} "${p}" PARENT_SCOPE)
endfunction()
winpath(iscc "${SRC_DIR}/fake/ISCC.exe")
winpath(stage "${BIN_DIR}/stage dir")
winpath(out "${EXPECT_OUT}")
winpath(iss "${SRC_DIR}/app.iss")
set(expected "${iscc}" "/DAppVersion=${EXPECT_VERSION}" "/DStageDir=${stage}"
    "/DAppName=Pkg App" "/O${out}" "${iss}")
if(NOT "${args}" STREQUAL "${expected}")
    message(FATAL_ERROR "argv mismatch\n got:      ${args}\n expected: ${expected}")
endif()
