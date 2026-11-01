include_guard(GLOBAL)
include(GTestSupport)

# build_gtest_executable(
#   NAME     test_bowlingbox_core           # must start with test_, lower case
#   SRC      test/src/test_Core.cpp
#   DEPENDS  Bowlingbox::Core GTest::gtest ...
#   DISCOVER ON                             # gtest_discover_tests, else add_test
#   LABELS   unit                           # default: unit
# )
# Discovered tests run in the runtime output dir (CMAKE_RUNTIME_OUTPUT_DIRECTORY,
# else ${PROJECT_BUILD_OUTPUT}/bin, else the current binary dir), where the
# binaries live and create_library copies LIB_RSC to ../data/<target>/.
function(build_gtest_executable)
    set(options)
    set(single_value_args NAME DISCOVER LABELS)
    set(list_args SRC DEPENDS)
    cmake_parse_arguments(PARSE_ARGV 0 test
        "${options}" "${single_value_args}" "${list_args}")

    foreach(arg IN LISTS test_UNPARSED_ARGUMENTS)
        message(WARNING "unparsed argument: ${arg}")
    endforeach()

    if(NOT "${test_NAME}" MATCHES "^test_")
        message(FATAL_ERROR "${test_NAME}: test executable name must start with test_")
    endif()

    if("${test_NAME}" MATCHES "[A-Z]")
        message(FATAL_ERROR "${test_NAME}: test executable name must be lowercase")
    endif()

    if("${test_SRC}" STREQUAL "")
        message(FATAL_ERROR "${test_NAME}: missing SRC files")
    endif()

    if(NOT test_LABELS)
        set(test_LABELS unit)
    endif()

    buildkit_use_gtest()
    if(NOT BUILDKIT_GTEST_AVAILABLE)
        message(WARNING "${test_NAME}: GoogleTest not available, test not built")
        return()
    endif()

    add_executable(${test_NAME} ${test_SRC})
    target_link_libraries(${test_NAME} PRIVATE ${test_DEPENDS})
    # Keep tests building against third-party headers without treating their
    # diagnostics as project errors.
    if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
        target_compile_options(${test_NAME} PRIVATE -Wall -Wextra -Wno-error
            -Werror=unused-result)
    endif()

    if(test_DISCOVER)
        set(_test_wd ${CMAKE_RUNTIME_OUTPUT_DIRECTORY})
        if(NOT _test_wd AND PROJECT_BUILD_OUTPUT)
            set(_test_wd ${PROJECT_BUILD_OUTPUT}/bin)
        endif()
        if(NOT _test_wd)
            set(_test_wd ${CMAKE_CURRENT_BINARY_DIR})
        endif()
        # gtest_discover_tests splits an unescaped semicolon, so every label
        # after the first would be dropped. Keep the list as one property value.
        string(REPLACE ";" "\;" _discover_labels "${test_LABELS}")
        gtest_discover_tests(${test_NAME}
            WORKING_DIRECTORY ${_test_wd}
            PROPERTIES LABELS "${_discover_labels}"
        )
    else()
        add_test(NAME ${test_NAME} COMMAND ${test_NAME})
        set_tests_properties(${test_NAME} PROPERTIES LABELS "${test_LABELS}")
    endif()
endfunction()
