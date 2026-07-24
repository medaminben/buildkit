# UnitPro

C++20 / CMake boilerplate for sandbox and production libraries.

UnitPro gives you a reusable starting point with Clean Architecture boundaries, scaffold generation, GoogleTest, coverage, clang-format/tidy, conventional commits, and GitHub Actions CI/CD.

## Features

- C++20 libraries with public `include/` API and private `src/` implementation
- Optional console and Qt UI application scaffolds
- GoogleTest + CTest with discoverable unit tests
- CMake presets for default, debug, coverage, and CI builds
- Install/export package config (`find_package(UnitPro)`)
- clang-format, clang-tidy, Husky, lint-staged, Commitlint
- GitHub Actions: format, lint, build, test, coverage, security, release

## Requirements

| Tool | Version |
|------|---------|
| CMake | ≥ 3.29 |
| C++ compiler | GCC 12+, Clang 15+, or MSVC 19.3+ |
| make or Ninja | recommended |
| Node.js 20+ | optional, for git hooks |
| Qt 5/6 | optional, for `BUILD_QT_UI` |
| lcov | optional, for HTML coverage reports |

## Quick start

```bash
git clone <repo-url> unitpro
cd unitpro

cmake --preset default
cmake --build --preset default
ctest --preset default --output-on-failure

# optional sample app
./build/default/bin/Core_Console
```

Debug / coverage:

```bash
cmake --preset debug && cmake --build --preset debug
cmake --preset coverage && cmake --build --preset coverage
cmake --build --preset coverage --target coverage   # needs lcov
```

## Project layout

```
unitpro/
├── applications/          # App layer (library consumers)
│   └── Core/Core_Console/
├── libraries/             # Domain / reusable libraries
│   └── Core/
│       ├── include/       # Public API
│       ├── src/           # Private implementation
│       └── test/          # Unit tests
├── cmake/
│   ├── modules/           # Warnings, coverage, install, generator
│   └── template/          # Scaffold templates for new libs/apps
├── scripts/               # CI helpers
├── .github/workflows/     # CI + release
└── docs/                  # Documentation
```

## Build options

| Option | Default | Description |
|--------|---------|-------------|
| `BUILD_SHARED_LIBS` | `ON` | Shared vs static libraries |
| `BUILD_APPS` | `ON` | Build applications |
| `BUILD_TESTING` | `ON` | Build and register tests |
| `BUILD_QT_UI` | `OFF` | Build Qt UI apps |
| `ENABLE_COVERAGE` | `OFF` | gcov instrumentation |
| `ENABLE_CLANG_TIDY` | `OFF` | Run clang-tidy while compiling |
| `GENERATE_SCAFFOLD` | `ON` | Generate missing libraries from templates |
| `BUILD_VERBOSE_OUTPUT` | `OFF` | Dump CMake variables |

Example:

```bash
cmake --preset default -DBUILD_SHARED_LIBS=OFF -DBUILD_QT_UI=ON
```

## Adding a library

1. Append the name to `UNITPRO_LIBRARIES` in the root `CMakeLists.txt`.
2. Reconfigure: `cmake --preset default`
3. UnitPro generates `libraries/<Name>/` and a console app under `applications/<Name>/` if missing.
4. Adapt the public API, implementation, and tests.

Details: [docs/ADDING_LIBRARIES.md](docs/ADDING_LIBRARIES.md)

## Quality tooling

```bash
npm install                 # Husky + Commitlint + lint-staged
npm run format              # clang-format (in-place)
npm run format:check        # clang-format dry-run
```

Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add Matrix library scaffold
fix: correct multiply edge case for negatives
ci: upload coverage artifacts
```

See [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md).

## CI / CD

| Workflow | Trigger | Jobs |
|----------|---------|------|
| `ci.yml` | push / PR | format, lint, build+test (GCC/Clang), coverage, cppcheck, CodeQL |
| `release.yml` | tag `v*` | build, test, package, GitHub Release |

## Install as a package

```bash
cmake --preset default -DCMAKE_INSTALL_PREFIX=$PWD/install
cmake --build --preset default
cmake --install build/default
```

Consumers:

```cmake
find_package(UnitPro REQUIRED)
target_link_libraries(my_app PRIVATE UnitPro::Core)
```

## Documentation

| Doc | Topic |
|-----|-------|
| [Architecture](docs/ARCHITECTURE.md) | Layers, SOLID, module boundaries |
| [Adding libraries](docs/ADDING_LIBRARIES.md) | Scaffold workflow |
| [Contributing](docs/CONTRIBUTING.md) | Style, tests, commits, PR checklist |
| [Migration](docs/MIGRATION.md) | Upgrade path from UnitPro ≤ 1.3 |
| [CI/CD](docs/CI_CD.md) | Pipelines and local parity |

## License

MIT — see [LICENSE](LICENSE).
