project(demo_console VERSION 1.0.0 LANGUAGES CXX)
create_application(
    NAME         demo_console
    ENTRY        Console
    SOURCES      main.cpp
    DEPENDENCIES Demo::Core
    COMPONENT    ${DEMO_RUNTIME_COMPONENT}
)
add_test(NAME demo_console_runs COMMAND demo_console)
set_tests_properties(demo_console_runs PROPERTIES PASS_REGULAR_EXPRESSION "answer 42")
