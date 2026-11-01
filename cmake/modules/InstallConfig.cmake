# Install / export package configuration for the product's libraries.
# Include it from the top-level CMakeLists after the libraries are added.
#
#   package name   CMAKE_ROOT_NAME (legacy layout), else CMAKE_PROJECT_NAME
#   export set     <package>Targets (what create_library installs into)
#   namespace      <Root>:: (legacy); none in the flat layout, where every
#                  target is exported as <Lib>::<Lib>
#   config file    cmake/<package>Config.cmake.in of the product if it exists
#                  (e.g. Bowlingbox's), else buildkit's PackageConfig.cmake.in
#
# BUILDKIT_INSTALL_CMAKEDIR is the install folder of the package files.

include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

if(NOT "${CMAKE_ROOT_NAME}" STREQUAL "")
    set(BUILDKIT_PACKAGE_NAME ${CMAKE_ROOT_NAME})
    set(_buildkit_namespace NAMESPACE ${CMAKE_ROOT_NAME}::)
else()
    set(BUILDKIT_PACKAGE_NAME ${CMAKE_PROJECT_NAME})
    set(_buildkit_namespace)
endif()

set(BUILDKIT_INSTALL_CMAKEDIR ${CMAKE_INSTALL_LIBDIR}/cmake/${BUILDKIT_PACKAGE_NAME})

write_basic_package_version_file(
    "${CMAKE_CURRENT_BINARY_DIR}/${BUILDKIT_PACKAGE_NAME}ConfigVersion.cmake"
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY SameMajorVersion
)

set(_buildkit_config_in "${CMAKE_SOURCE_DIR}/cmake/${BUILDKIT_PACKAGE_NAME}Config.cmake.in")
if(NOT EXISTS "${_buildkit_config_in}")
    set(_buildkit_config_in "${CMAKE_CURRENT_LIST_DIR}/PackageConfig.cmake.in")
endif()

# configure_package_config_file defines @PACKAGE_INIT@ and
# check_required_components() for the template.
configure_package_config_file(
    "${_buildkit_config_in}"
    "${CMAKE_CURRENT_BINARY_DIR}/${BUILDKIT_PACKAGE_NAME}Config.cmake"
    INSTALL_DESTINATION ${BUILDKIT_INSTALL_CMAKEDIR}
)

install(
    FILES
        "${CMAKE_CURRENT_BINARY_DIR}/${BUILDKIT_PACKAGE_NAME}Config.cmake"
        "${CMAKE_CURRENT_BINARY_DIR}/${BUILDKIT_PACKAGE_NAME}ConfigVersion.cmake"
    DESTINATION ${BUILDKIT_INSTALL_CMAKEDIR}
)

install(
    EXPORT ${BUILDKIT_PACKAGE_NAME}Targets
    ${_buildkit_namespace}
    DESTINATION ${BUILDKIT_INSTALL_CMAKEDIR}
)
unset(_buildkit_namespace)
unset(_buildkit_config_in)
