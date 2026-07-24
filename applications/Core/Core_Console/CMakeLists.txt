project(Core_Console VERSION 1.1.1 LANGUAGES CXX)

set(PROJECT_LIST)
set(EXECUTABLE_NAME ${PROJECT_NAME})
add_project(${EXECUTABLE_NAME} PROJECT_LIST)

set(BUILD_${EXECUTABLE_NAME} ${BUILD_APPS})
set(${EXECUTABLE_NAME}_ENTRY "Console")
set(${EXECUTABLE_NAME}_SOURCES Core_Console.cpp)
set(${EXECUTABLE_NAME}_DEPS ${CMAKE_ROOT_NAME}::Core)

foreach(item IN LISTS PROJECT_LIST)
    if(BUILD_${item})
        create_application(
            NAME         ${item}
            ENTRY        ${${item}_ENTRY}
            SOURCES      ${${item}_SOURCES}
            DEPENDENCIES ${${item}_DEPS}
        )
    endif()
endforeach()
