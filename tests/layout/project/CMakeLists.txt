# generate_project renders template/project/ (CMakeLists.txt, CMakePresets.json,
# .gitignore) into a new product folder inside the binary dir. The product is
# then configured, built and tested with its own `ci` and `asan` presets (the
# ctest tests below), so the generated tree is checked end to end.
cmake_minimum_required(VERSION 3.29)
project(LayoutProject LANGUAGES NONE)
include(${BUILDKIT_DIR}/cmake/Buildkit.cmake)
include(CTest)

set(product ${CMAKE_BINARY_DIR}/Gamma)
generate_project(NAME Gamma DESTINATION ${product} LIBRARIES Gamma)

# Stand-in for the product loader (loader/buildkit.cmake, a later task).
file(WRITE ${product}/cmake/buildkit.cmake
    "include(\"${BUILDKIT_DIR}/cmake/Buildkit.cmake\")\n")

foreach(f CMakeLists.txt CMakePresets.json .gitignore)
    if(NOT EXISTS ${product}/${f})
        message(FATAL_ERROR "generate_project did not write ${f}")
    endif()
endforeach()

file(READ ${product}/CMakePresets.json presets)
set(names)
string(JSON n LENGTH "${presets}" configurePresets)
math(EXPR last "${n} - 1")
foreach(i RANGE ${last})
    string(JSON name GET "${presets}" configurePresets ${i} name)
    string(JSON hidden ERROR_VARIABLE no_hidden GET "${presets}" configurePresets ${i} hidden)
    if(hidden)
        continue()
    endif()
    string(JSON dir GET "${presets}" configurePresets ${i} binaryDir)
    if(NOT dir STREQUAL "\${sourceDir}/build/${name}")
        message(FATAL_ERROR "preset ${name}: binaryDir is ${dir}")
    endif()
    list(APPEND names ${name})
endforeach()
if(NOT names STREQUAL "default;debug;coverage;asan;ci")
    message(FATAL_ERROR "configure presets are '${names}'")
endif()

file(READ ${product}/.gitignore ignore)
if(NOT ignore MATCHES "(^|\n)/?build/")
    message(FATAL_ERROR ".gitignore does not ignore build/")
endif()

foreach(preset ci asan)
    add_test(NAME product_${preset}
        COMMAND ${CMAKE_COMMAND} -DPRODUCT=${product} -DPRESET=${preset}
                -P ${CMAKE_CURRENT_SOURCE_DIR}/run_preset.cmake)
endforeach()
message(STATUS "LAYOUT_PROJECT_OK")
