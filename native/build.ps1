[CmdletBinding()]
param([string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
if (!$OutputDirectory) { $OutputDirectory = Join-Path $PSScriptRoot '..\package' }
$taskVswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (!(Test-Path -LiteralPath $taskVswhere)) { throw 'Install Visual Studio 2022 Build Tools with Desktop development with C++ and a Windows SDK.' }
$taskVs = & $taskVswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (!$taskVs) { throw 'MSVC x86 build tools were not found.' }
$taskVcvars = Join-Path $taskVs 'VC\Auxiliary\Build\vcvars32.bat'
$taskOutput = [System.IO.Path]::GetFullPath($OutputDirectory)
$taskBuild = Join-Path $PSScriptRoot 'build'
$taskTests = Join-Path $taskBuild 'tests'
New-Item -ItemType Directory -Force -Path $taskOutput, $taskBuild, $taskTests | Out-Null
$taskBatch = Join-Path $taskBuild 'run-msvc.cmd'
@"
@echo off
call "$taskVcvars"
if errorlevel 1 exit /b 1
cd /d "$PSScriptRoot"
cl /nologo /W4 /WX /O2 /EHsc /std:c++17 /MT /D_WIN32_WINNT=0x0601 /LD runtime.cpp bridge.cpp dualsense.cpp glue.cpp keyboard.cpp /Fo"$taskBuild\\" /Fe"$taskOutput\WindrunnerController.dll" /link user32.lib gdi32.lib setupapi.lib hid.lib /DEF:WindrunnerController.def /IMPLIB:"$taskBuild\WindrunnerController.lib" /INCREMENTAL:NO /Brepro
if errorlevel 1 exit /b 1
cl /nologo /W4 /WX /O2 /EHsc /std:c++17 /MT tests.cpp /Fo"$taskTests\\" /Fe"$taskTests\native-tests.exe" /link /INCREMENTAL:NO /Brepro
if errorlevel 1 exit /b 1
"$taskTests\native-tests.exe"
if errorlevel 1 exit /b 1
cl /nologo /W4 /WX /O2 /EHsc /std:c++17 /MT /D_WIN32_WINNT=0x0601 bridge-tests.cpp /Fo"$taskTests\\" /Fe"$taskTests\bridge-tests.exe" /link /INCREMENTAL:NO /Brepro
if errorlevel 1 exit /b 1
"$taskTests\bridge-tests.exe"
if errorlevel 1 exit /b 1
cl /nologo /W4 /WX /O2 /EHsc /std:c++17 /MT smoke.cpp /Fo"$taskTests\\" /Fe"$taskTests\native-smoke.exe" /link /INCREMENTAL:NO /Brepro
if errorlevel 1 exit /b 1
"$taskTests\native-smoke.exe" "$taskOutput\WindrunnerController.dll"
if errorlevel 1 exit /b 1
cl /nologo /W4 /WX /O2 /EHsc /std:c++17 /MT /D_WIN32_WINNT=0x0601 diagnose-launch.cpp /Fo"$taskTests\\" /Fe"$taskTests\diagnose-launch.exe" /link /INCREMENTAL:NO /Brepro
exit /b %errorlevel%
"@ | Set-Content -LiteralPath $taskBatch -Encoding ASCII
& $env:ComSpec /d /c $taskBatch
if ($LASTEXITCODE -ne 0) { throw "MSVC build or native tests failed (exit $LASTEXITCODE)." }
Write-Output "Built and tested: $taskOutput\WindrunnerController.dll"
