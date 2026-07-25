#include <UnitPro/Core/Core.h>
#include <gtest/gtest.h>

TEST(test_core_Math, AnswerIsCorrect) {
    EXPECT_EQ(UnitPro::Core::get_the_answer(), 42U);
}

TEST(test_core_Math, MultiplyReturnsCorrectResults) {
    EXPECT_EQ(36, UnitPro::Core::multiply(6, 6));
}

TEST(test_core_Math, MultiplyHandlesZero) {
    EXPECT_EQ(0, UnitPro::Core::multiply(0, 99));
}

TEST(test_core_Math, MultiplyHandlesNegatives) {
    EXPECT_EQ(-12, UnitPro::Core::multiply(-3, 4));
}
