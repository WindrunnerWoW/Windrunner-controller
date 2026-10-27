[CmdletBinding()]
param([string]$LuaExecutable, [string]$ExperienceAddonRoot)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path $PSScriptRoot -Parent
if (!$ExperienceAddonRoot) { $ExperienceAddonRoot = Join-Path $taskRoot 'addon\Windrunner-Controller' }
$controllerLua = Join-Path $ExperienceAddonRoot 'WindrunnerController.lua'
if (!(Test-Path -LiteralPath $controllerLua -PathType Leaf)) {
    throw "Merged controller addon source not found: $controllerLua. Pass -ExperienceAddonRoot with the Windrunner-Controller source folder."
}
if (!$LuaExecutable) {
    $taskResearch = Join-Path $taskRoot 'research'
    New-Item -ItemType Directory -Force -Path $taskResearch | Out-Null
    $taskSource = Join-Path $taskResearch 'lua-5.0.3'
    $taskArchive = Join-Path $taskResearch 'lua-5.0.3.tar.gz'
    if (!(Test-Path -LiteralPath $taskArchive)) {
        Invoke-WebRequest -Uri 'https://www.lua.org/ftp/lua-5.0.3.tar.gz' -OutFile $taskArchive
    }
    if (!(Test-Path -LiteralPath (Join-Path $taskSource 'include\lua.h'))) {
        # Prefer the Windows tar; Git for Windows ships a tar that treats C:\ paths as remote hosts.
        $taskTar = Join-Path $env:SystemRoot 'System32\tar.exe'
        if (!(Test-Path -LiteralPath $taskTar -PathType Leaf)) { $taskTar = 'tar' }
        & $taskTar -xf $taskArchive -C $taskResearch 'lua-5.0.3/include' 'lua-5.0.3/src'
        if ($LASTEXITCODE -ne 0) { throw 'Lua 5.0.3 source extraction failed.' }
    }
    $LuaExecutable = Join-Path $PSScriptRoot 'build\lua50.exe'
    if (!(Test-Path -LiteralPath $LuaExecutable)) {
        $taskVswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
        $taskVs = & $taskVswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
        if (!$taskVs) { throw 'MSVC x86 build tools are required to build the Lua 5.0 test runtime.' }
        $taskVcvars = Join-Path $taskVs 'VC\Auxiliary\Build\vcvars32.bat'
        $taskBuild = Split-Path $LuaExecutable -Parent
        New-Item -ItemType Directory -Force -Path $taskBuild | Out-Null
        $taskSources = @((Get-ChildItem -LiteralPath (Join-Path $taskSource 'src') -Filter '*.c'), (Get-ChildItem -LiteralPath (Join-Path $taskSource 'src\lib') -Filter '*.c')) | ForEach-Object { $_ } | ForEach-Object { '"' + $_.FullName + '"' }
        # /Od (not /O2): the VS 2026 x86 optimizer miscompiles Lua 5.0.3, producing a
        # runtime that access-violates at startup on windows-2025 runners.
        $taskBatch = Join-Path $taskBuild 'build-lua50.cmd'
        @"
@echo off
call "$taskVcvars"
if errorlevel 1 exit /b 1
cd /d "$taskBuild"
cl /nologo /w /Od /MT /D_CRT_SECURE_NO_WARNINGS /D_USE_32BIT_TIME_T /I"$taskSource\include" /I"$taskSource\src" $($taskSources -join ' ') "$taskSource\src\lua\lua.c" /Fe"$LuaExecutable"
exit /b %errorlevel%
"@ | Set-Content -LiteralPath $taskBatch -Encoding ASCII
        & $env:ComSpec /d /c $taskBatch
        if ($LASTEXITCODE -ne 0) { throw 'Lua 5.0.3 test runtime build failed.' }
    }
}
Push-Location $taskRoot
try {
    & $LuaExecutable (Join-Path $PSScriptRoot 'addon-tests.lua') $controllerLua $ExperienceAddonRoot
    if ($LASTEXITCODE -ne 0) { throw 'Controller addon Lua 5.0 tests failed.' }
    & $LuaExecutable (Join-Path $PSScriptRoot 'experience-tests.lua') $ExperienceAddonRoot
    if ($LASTEXITCODE -ne 0) { throw 'Current experience regression scenarios failed.' }
    & $LuaExecutable (Join-Path $PSScriptRoot 'appearance-tests.lua') $ExperienceAddonRoot
    if ($LASTEXITCODE -ne 0) { throw 'Appearance and profile regression scenarios failed.' }
    foreach ($taskSuite in @('bindings-tests.lua','layout-tests.lua','inventory-tests.lua','rings-tests.lua','pet-unit-loot-tests.lua','features-ui-tests.lua','world-map-tests.lua')) {
        & $LuaExecutable (Join-Path $PSScriptRoot $taskSuite) $ExperienceAddonRoot
        if ($LASTEXITCODE -ne 0) { throw "$taskSuite failed." }
    }
    $taskPortableSuite = Join-Path $ExperienceAddonRoot 'tests\setup-typing-sharing-tests.lua'
    if (Test-Path -LiteralPath $taskPortableSuite) {
        & $LuaExecutable $taskPortableSuite $ExperienceAddonRoot
        if ($LASTEXITCODE -ne 0) { throw 'Setup, typing and sharing tests failed.' }
    }
    & $LuaExecutable (Join-Path $ExperienceAddonRoot 'tests\controller-lifecycle-tests.lua') $ExperienceAddonRoot
    if ($LASTEXITCODE -ne 0) { throw 'Controller activation and UI restoration tests failed.' }
    $taskLuaFiles = @(Get-ChildItem -LiteralPath $ExperienceAddonRoot -Recurse -Filter '*.lua' | Where-Object { $_.FullName -notmatch '[\\/](build|dist|\.git)[\\/]' } | ForEach-Object { $_.FullName })
    & $LuaExecutable (Join-Path $PSScriptRoot 'syntax-check.lua') @taskLuaFiles
    if ($LASTEXITCODE -ne 0) { throw 'Staged addon Lua 5.0 syntax check failed.' }
} finally { Pop-Location }
