#ifndef CORE_H
#define CORE_H

#include <UnitPro/Core/UnitPro_Core_export.h>

namespace UnitPro {
namespace Core {

/// Returns the sample domain answer used by the template demos.
unsigned int UNITPRO_CORE_API get_the_answer();

/// Multiplies two integers.
int UNITPRO_CORE_API multiply(int lhs, int rhs);

}  // namespace Core
}  // namespace UnitPro

#endif  // CORE_H
