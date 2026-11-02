project(Vision VERSION 0.3.0 LANGUAGES CXX)

create_library(
    LIB_NAME      Vision
    LIB_FILES     include/Vision/Hide.h src/Hide.cpp
    TEST_DISCOVER ON
    TEST_SOURCES  test/test_Hide.cpp
)
