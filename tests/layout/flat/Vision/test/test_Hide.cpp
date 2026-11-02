#include <Vision/Hide.h>

#include <gtest/gtest.h>

TEST(test_Hide, Negative) { EXPECT_TRUE(Vision::hidden(-1, 0)); }
TEST(test_Hide, Positive) { EXPECT_FALSE(Vision::hidden(1, 2)); }
