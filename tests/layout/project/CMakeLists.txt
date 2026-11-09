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

foreach(f CMakeLists.txt CMakePresets.json .gitignore cmake/buildkit.cmake)
    if(NOT EXISTS ${product}/${f})
        message(FATAL_ERROR "generate_project did not write ${f}")
    endif()
endforeach()
# Without REPOSITORY the product is private or local: no community files.
foreach(f LICENSE SECURITY.md CODE_OF_CONDUCT.md CONTRIBUTING.md .github)
    if(EXISTS ${product}/${f})
        message(FATAL_ERROR "generate_project wrote ${f} without REPOSITORY")
    endif()
endforeach()

# The loader is a verbatim copy of the real one.
file(READ ${BUILDKIT_DIR}/loader/buildkit.cmake real_loader)
file(READ ${product}/cmake/buildkit.cmake product_loader)
if(NOT real_loader STREQUAL product_loader)
    message(FATAL_ERROR "cmake/buildkit.cmake is not a copy of loader/buildkit.cmake")
endif()

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
    # The generated product finds buildkit through the real loader.
    set_tests_properties(product_${preset} PROPERTIES
        ENVIRONMENT "BUILDKIT_DIR=${BUILDKIT_DIR}")
endforeach()
message(STATUS "LAYOUT_PROJECT_OK")
