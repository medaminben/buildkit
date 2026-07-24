#include <UnitPro/Core/Core.h>

#include <iostream>
#include <string>

int main() {
    using namespace UnitPro;

    std::cout << "UnitPro Core console sample\n";
    std::cout << "6 * 6 = " << Core::multiply(6, 6) << '\n';
    std::cout << "The answer is " << Core::get_the_answer() << '\n';
    return 0;
}
