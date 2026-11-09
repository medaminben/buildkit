# generate_project with REPOSITORY: the community files of a public product
# (template/project/community/) are written with the names filled in.
# -DREPOSITORY=<value> overrides the repository (the invalid-value test).
cmake_minimum_required(VERSION 3.29)
project(LayoutProjectPublic LANGUAGES NONE)
include(${BUILDKIT_DIR}/cmake/Buildkit.cmake)

if(NOT DEFINED REPOSITORY)
    set(REPOSITORY octo/Delta)
endif()
set(product ${CMAKE_BINARY_DIR}/Delta)
file(REMOVE_RECURSE ${product})
file(WRITE ${product}/CONTRIBUTING.md "kept\n")
generate_project(NAME Delta DESTINATION ${product} LIBRARIES Delta
    REPOSITORY ${REPOSITORY} COPYRIGHT_HOLDER "Ada Lovelace")

string(TIMESTAMP year "%Y")
set(expect
    "LICENSE|Copyright \\(c\\) ${year} Ada Lovelace"
    "SECURITY.md|github.com/octo/Delta/security/advisories/new"
    "CODE_OF_CONDUCT.md|\\[@octo\\]\\(https://github.com/octo\\)"
    ".github/ISSUE_TEMPLATE/bug_report.yml|Delta version or commit"
    ".github/ISSUE_TEMPLATE/feature_request.yml|that Delta does not support"
    ".github/ISSUE_TEMPLATE/config.yml|github.com/octo/Delta/security"
    ".github/pull_request_template.md|semver:patch")
foreach(pair IN LISTS expect)
    string(REPLACE "|" ";" pair "${pair}")
    list(GET pair 0 f)
    list(GET pair 1 pattern)
    if(NOT EXISTS ${product}/${f})
        message(FATAL_ERROR "generate_project did not write ${f}")
    endif()
    file(READ ${product}/${f} text)
    if(NOT text MATCHES "${pattern}")
        message(FATAL_ERROR "${f} does not match '${pattern}'")
    endif()
    if(text MATCHES "@project_")
        message(FATAL_ERROR "${f} has an unfilled @project_...@ placeholder")
    endif()
endforeach()

# An existing file is kept.
file(READ ${product}/CONTRIBUTING.md contributing)
if(NOT contributing STREQUAL "kept\n")
    message(FATAL_ERROR "an existing CONTRIBUTING.md was overwritten")
endif()
message(STATUS "LAYOUT_PROJECT_PUBLIC_OK")
