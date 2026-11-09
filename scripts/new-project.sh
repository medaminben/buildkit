#!/usr/bin/env bash
# Creates a runnable buildkit product in the current folder.
#
#   cd ~/Dokumente/dev/MyApp
#   bash /path/to/buildkit/scripts/new-project.sh [--repo <owner>/<repo>] [Name] [Lib...]
#
# Name defaults to the folder name, the libraries to Core. The script writes
# the project files, generates libraries/<Lib>/ and applications/<Lib>/,
# builds, runs the tests and the console app, and sets up VS Code so that
# F5 builds and runs <first Lib>_Console. Files that exist are kept.
# --repo marks a public product on GitHub: it also gets LICENSE (MIT, holder
# from git config user.name), CONTRIBUTING, CODE_OF_CONDUCT, SECURITY and the
# issue and pull request templates. Leave it out for private and local ones.
set -euo pipefail

BUILDKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_DIR="$(pwd)"

die() { echo "error: $*" >&2; exit 1; }

[[ -f "$BUILDKIT_DIR/cmake/Buildkit.cmake" ]] || die "no buildkit found at $BUILDKIT_DIR"
# Inside buildkit only its git-ignored build/ is allowed (the self-test runs there).
case "$PROJECT_DIR/" in
    "$BUILDKIT_DIR/build/"*) ;;
    "$BUILDKIT_DIR/"*) die "run this in your new project folder, not inside buildkit ($BUILDKIT_DIR)" ;;
esac
for tool in cmake ninja g++; do
    command -v "$tool" >/dev/null || die "$tool is missing (sudo apt install cmake ninja-build g++)"
done

REPO=""
ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo) [[ $# -ge 2 ]] || die "--repo needs <owner>/<repo>"; REPO="$2"; shift 2 ;;
        --repo=*) REPO="${1#--repo=}"; shift ;;
        -*) die "unknown option $1" ;;
        *) ARGS+=("$1"); shift ;;
    esac
done
set -- "${ARGS[@]+"${ARGS[@]}"}"
COMMUNITY_ARGS=""
if [[ -n "$REPO" ]]; then
    HOLDER="$(git config user.name 2>/dev/null || true)"
    COMMUNITY_ARGS="REPOSITORY;$REPO"
    [[ -z "$HOLDER" ]] || COMMUNITY_ARGS+=";COPYRIGHT_HOLDER;$HOLDER"
fi

NAME="${1:-$(basename "$PROJECT_DIR")}"
shift || true
LIBS=("$@")
[[ ${#LIBS[@]} -gt 0 ]] || LIBS=(Core)

for id in "$NAME" "${LIBS[@]}"; do
    [[ "$id" =~ ^[A-Za-z][A-Za-z0-9_]*$ ]] \
        || die "'$id' is not a valid name (letters, digits, _; starts with a letter)"
done
APP="${LIBS[0]}_Console"

echo "==> Creating $NAME (libraries: ${LIBS[*]}) in $PROJECT_DIR"
echo "    buildkit: $BUILDKIT_DIR"

# 1. CMakeLists.txt, CMakePresets.json, .gitignore, cmake/buildkit.cmake
gen_dir="$(mktemp -d)"
trap 'rm -rf "$gen_dir"' EXIT
cat > "$gen_dir/gen.cmake" <<'EOF'
cmake_minimum_required(VERSION 3.29)
include(${BUILDKIT_DIR}/cmake/Buildkit.cmake)
generate_project(NAME ${NAME} DESTINATION ${DEST} LIBRARIES ${LIBS} ${COMMUNITY})
EOF
cmake -DBUILDKIT_DIR="$BUILDKIT_DIR" -DDEST="$PROJECT_DIR" -DNAME="$NAME" \
      "-DLIBS=$(IFS=';'; echo "${LIBS[*]}")" "-DCOMMUNITY=$COMMUNITY_ARGS" -P "$gen_dir/gen.cmake"

# 2. Local presets that know where buildkit is (git-ignored, machine specific)
if [[ ! -f CMakeUserPresets.json ]]; then
    cat > CMakeUserPresets.json <<EOF
{
  "version": 6,
  "configurePresets": [
    {
      "name": "dev",
      "displayName": "$NAME debug (local buildkit)",
      "inherits": "debug",
      "cacheVariables": { "BUILDKIT_DIR": "$BUILDKIT_DIR" }
    },
    {
      "name": "dev-release",
      "displayName": "$NAME release (local buildkit)",
      "inherits": "default",
      "cacheVariables": { "BUILDKIT_DIR": "$BUILDKIT_DIR" }
    }
  ],
  "buildPresets": [
    { "name": "dev", "configurePreset": "dev" },
    { "name": "dev-release", "configurePreset": "dev-release" }
  ],
  "testPresets": [
    { "name": "dev", "inherits": "base", "configurePreset": "dev" },
    { "name": "dev-release", "inherits": "base", "configurePreset": "dev-release" }
  ]
}
EOF
fi

# 3. VS Code: Ctrl+Shift+B builds, F5 builds and runs the console app
mkdir -p .vscode
[[ -f .vscode/settings.json ]] || cat > .vscode/settings.json <<'EOF'
{
  "cmake.useCMakePresets": "always",
  "cmake.configureOnOpen": true
}
EOF
[[ -f .vscode/tasks.json ]] || cat > .vscode/tasks.json <<'EOF'
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "build",
      "type": "shell",
      "command": "cmake --preset dev && cmake --build --preset dev",
      "group": { "kind": "build", "isDefault": true },
      "problemMatcher": ["$gcc"]
    },
    {
      "label": "test",
      "type": "shell",
      "command": "ctest --preset dev",
      "dependsOn": "build",
      "group": { "kind": "test", "isDefault": true },
      "problemMatcher": []
    }
  ]
}
EOF
[[ -f .vscode/launch.json ]] || cat > .vscode/launch.json <<EOF
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Run $APP",
      "type": "cppdbg",
      "request": "launch",
      "program": "\${workspaceFolder}/build/debug/bin/$APP",
      "cwd": "\${workspaceFolder}/build/debug/bin",
      "preLaunchTask": "build",
      "MIMode": "gdb",
      "externalConsole": false
    }
  ]
}
EOF

# 4. Configure (this generates libraries/ and applications/), build, test, run
cmake --preset dev
cmake --build --preset dev
ctest --preset dev

echo
echo "==> Running $APP"
"build/debug/bin/$APP"

echo
echo "==> Done. Open the folder in VS Code:  code \"$PROJECT_DIR\""
echo "    F5 = build and run $APP, Ctrl+Shift+B = build."
echo "    Your code goes in libraries/${LIBS[0]}/ (include/ and src/)."
