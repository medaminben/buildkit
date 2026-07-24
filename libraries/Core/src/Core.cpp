#include <UnitPro/Core/Core.h>

#include "Core_impl.h"

namespace UnitPro {
namespace Core {

unsigned int get_the_answer() {
    return get_the_answer_impl();
}

int multiply(int lhs, int rhs) {
    return multiply_impl(lhs, rhs);
}

}  // namespace Core
}  // namespace UnitPro
