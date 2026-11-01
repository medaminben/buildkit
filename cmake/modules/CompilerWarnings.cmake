# Consistent warning levels across compilers (treat warnings as errors).
#
# buildkit_set_warnings(<target>)
#   base    /W4 /WX /permissive-  |  -Wall -Wextra -Wpedantic -Werror
#   strict  base plus -Wconversion -Wshadow -Wnon-virtual-dtor -Wold-style-cast
#           -Wcast-align -Wunused -Woverloaded-virtual -Wnull-dereference
#           -Wdouble-promotion -Wformat=2 (GCC/Clang)
#
# BUILDKIT_STRICT_WARNINGS picks the level. When it is not set, the flat
# layout (no CMAKE_ROOT_NAME) is strict and the legacy layout keeps the base
# level that Bowlingbox's own bowlingbox_set_warnings used.
include_guard(GLOBAL)

function(buildkit_set_warnings target)
    if(DEFINED BUILDKIT_STRICT_WARNINGS)
        set(strict ${BUILDKIT_STRICT_WARNINGS})
    elseif("${CMAKE_ROOT_NAME}" STREQUAL "")
        set(strict ON)
    else()
        set(strict OFF)
    endif()

    if(MSVC)
        target_compile_options(${target} PRIVATE /W4 /WX /permissive-)
    elseif(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
        target_compile_options(${target} PRIVATE
            -Wall
            -Wextra
            -Wpedantic
            -Werror
        )
        if(strict)
            target_compile_options(${target} PRIVATE
                -Wconversion
                -Wshadow
                -Wnon-virtual-dtor
                -Wold-style-cast
                -Wcast-align
                -Wunused
                -Woverloaded-virtual
                -Wnull-dereference
                -Wdouble-promotion
                -Wformat=2
            )
        endif()
    endif()
endfunction()
