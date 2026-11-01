#include <Demo/Core/Core.h>

#include <gtest/gtest.h>

#include <fstream>

TEST(test_Core, Answer) { EXPECT_EQ(Demo::Core::answer(), 42); }

// Discovered tests run in the runtime output dir (bin/), and LIB_RSC files
// are copied to ../data/<target>/ (Bowlingbox's convention).
TEST(test_Core, ResourceIsBesideTheBinaries) {
    std::ifstream in("../data/demo_core/CoreTestData.txt");
    EXPECT_TRUE(in.good());
}
