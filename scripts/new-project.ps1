# Creates a runnable buildkit product in the current folder (Windows version of
# new-project.sh, same steps and files).
#
#   cd $HOME\dev\MyApp
#   powershell -ExecutionPolicy Bypass -File C:\path\to\buildkit\scripts\new-project.ps1 [-Repo <owner>/<repo>] [Name] [Lib...]
#
# Name defaults to the folder name, the libraries to Core. The script writes
# the project files, generates libraries\<Lib>\ and applications\<Lib>\,
# builds, runs the tests and the console app, and sets up VS Code so that
# F5 builds and runs <first Lib>_Console. Files that exist are kept.
# -Repo marks a public product on GitHub: it also gets LICENSE (MIT, holder
# from git config user.name), CONTRIBUTING, CODE_OF_CONDUCT, SECURITY and the
# issue and pull request templates. Leave it out for private and local ones.
#
# Needs cmake, ninja and g++ on PATH: the MSYS2 UCRT64 toolchain, for example
# C:\msys64\ucrt64\bin.
[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$Repo = "",
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Rest = @()
)
$ErrorActionPreference = "Stop"

function Die([string]$msg) { [Console]::Error.WriteLine("error: $msg"); exit 1 }

# Writes UTF-8 without a BOM (Set-Content in Windows PowerShell 5.1 adds one).
function Write-NewFile([string]$path, [string]$text) {
    if (Test-Path -LiteralPath $path) { return }
    $dir = Split-Path -Parent $path
    if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    [System.IO.File]::WriteAllText($path, $text.Replace("`r`n", "`n"))
}

function Invoke-Step([string]$exe, [string[]]$arguments) {
    & $exe @arguments
    if ($LASTEXITCODE -ne 0) { Die "$exe $($arguments -join ' ') failed (exit $LASTEXITCODE)" }
}

$BuildkitDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$ProjectDir = (Get-Location).Path
$sep = [System.IO.Path]::DirectorySeparatorChar

if (-not (Test-Path (Join-Path $BuildkitDir "cmake/Buildkit.cmake"))) { Die "no buildkit found at $BuildkitDir" }
# Inside buildkit only its git-ignored build\ is allowed (the self-test runs there).
$inside = ($ProjectDir + $sep).StartsWith($BuildkitDir + $sep, [System.StringComparison]::OrdinalIgnoreCase)
$inBuild = ($ProjectDir + $sep).StartsWith((Join-Path $BuildkitDir "build") + $sep, [System.StringComparison]::OrdinalIgnoreCase)
if ($inside -and -not $inBuild) { Die "run this in your new project folder, not inside buildkit ($BuildkitDir)" }
foreach ($tool in "cmake", "ninja", "g++") {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        Die "$tool is missing (MSYS2 UCRT64: pacman -S mingw-w64-ucrt-x86_64-{cmake,ninja,gcc}, and put ucrt64\bin on PATH)"
    }
}
foreach ($arg in $Rest) { if ($arg.StartsWith("-")) { Die "unknown option $arg" } }

$community = ""
if ($Repo) {
    $holder = ""
    if (Get-Command git -ErrorAction SilentlyContinue) { $holder = (& git config user.name 2>$null) -join "" }
    $community = "REPOSITORY;$Repo"
    if ($holder) { $community += ";COPYRIGHT_HOLDER;$holder" }
}

$Name = if ($Rest.Count -gt 0) { $Rest[0] } else { Split-Path -Leaf $ProjectDir }
$Libs = @(if ($Rest.Count -gt 1) { $Rest[1..($Rest.Count - 1)] } else { "Core" })
foreach ($id in @($Name) + $Libs) {
    if ($id -notmatch '^[A-Za-z][A-Za-z0-9_]*$') { Die "'$id' is not a valid name (letters, digits, _; starts with a letter)" }
}
$App = "$($Libs[0])_Console"
$exe = if ($IsLinux -or $IsMacOS) { $App } else { "$App.exe" }
# Forward slashes: the paths go into JSON and CMake files.
$bk = $BuildkitDir.Replace("\", "/")
$dest = $ProjectDir.Replace("\", "/")

Write-Host "==> Creating $Name (libraries: $($Libs -join ' ')) in $ProjectDir"
Write-Host "    buildkit: $BuildkitDir"

# 1. CMakeLists.txt, CMakePresets.json, .gitignore, cmake/buildkit.cmake
$genDir = Join-Path ([System.IO.Path]::GetTempPath()) ("buildkit-gen-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $genDir | Out-Null
try {
    $gen = Join-Path $genDir "gen.cmake"
    Write-NewFile $gen @'
cmake_minimum_required(VERSION 3.29)
include(${BUILDKIT_DIR}/cmake/Buildkit.cmake)
generate_project(NAME ${NAME} DESTINATION ${DEST} LIBRARIES ${LIBS} ${COMMUNITY})
'@
    Invoke-Step cmake @("-DBUILDKIT_DIR=$bk", "-DDEST=$dest", "-DNAME=$Name",
        "-DLIBS=$($Libs -join ';')", "-DCOMMUNITY=$community", "-P", $gen)
} finally {
    Remove-Item -Recurse -Force $genDir
}

# 2. Local presets that know where buildkit is (git-ignored, machine specific)
Write-NewFile (Join-Path $ProjectDir "CMakeUserPresets.json") @"
{
  "version": 6,
  "configurePresets": [
    {
      "name": "dev",
      "displayName": "$Name debug (local buildkit)",
      "inherits": "debug",
      "cacheVariables": { "BUILDKIT_DIR": "$bk" }
    },
    {
      "name": "dev-release",
      "displayName": "$Name release (local buildkit)",
      "inherits": "default",
      "cacheVariables": { "BUILDKIT_DIR": "$bk" }
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
"@

# 3. VS Code: Ctrl+Shift+B builds, F5 builds and runs the console app
Write-NewFile (Join-Path $ProjectDir ".vscode/settings.json") @'
{
  "cmake.useCMakePresets": "always",
  "cmake.configureOnOpen": true
}
'@
Write-NewFile (Join-Path $ProjectDir ".vscode/tasks.json") @'
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "build",
      "type": "shell",
      "command": "cmake --preset dev; if ($?) { cmake --build --preset dev }",
      "options": { "shell": { "executable": "powershell.exe", "args": ["-NoProfile", "-Command"] } },
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
'@
Write-NewFile (Join-Path $ProjectDir ".vscode/launch.json") @"
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Run $App",
      "type": "cppdbg",
      "request": "launch",
      "program": "`${workspaceFolder}/build/debug/bin/$exe",
      "cwd": "`${workspaceFolder}/build/debug/bin",
      "preLaunchTask": "build",
      "MIMode": "gdb",
      "miDebuggerPath": "gdb",
      "externalConsole": false
    }
  ]
}
"@

# 4. Configure (this generates libraries\ and applications\), build, test, run
Invoke-Step cmake @("--preset", "dev")
Invoke-Step cmake @("--build", "--preset", "dev")
Invoke-Step ctest @("--preset", "dev")

Write-Host ""
Write-Host "==> Running $App"
Invoke-Step (Join-Path $ProjectDir "build/debug/bin/$exe") @()

Write-Host ""
Write-Host "==> Done. Open the folder in VS Code:  code `"$ProjectDir`""
Write-Host "    F5 = build and run $App, Ctrl+Shift+B = build."
Write-Host "    Your code goes in libraries\$($Libs[0])\ (include\ and src\)."
