[CmdletBinding()]
param(
    [string]$DllPath,
    [string]$Version,
    [string]$OutputDirectory
)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $repoRoot 'artifacts' }
if (-not $DllPath) { $DllPath = Join-Path $repoRoot 'artifacts\native\WindrunnerController.dll' }
$DllPath = [IO.Path]::GetFullPath($DllPath)
if (-not (Test-Path -LiteralPath $DllPath -PathType Leaf)) { throw "Native DLL not found: $DllPath" }
$addonRoot = Join-Path $repoRoot 'addon\Windrunner-Controller'
$tocPath = Join-Path $addonRoot 'Windrunner-Controller.toc'
if (-not (Test-Path -LiteralPath $tocPath -PathType Leaf)) { throw "Addon manifest not found: $tocPath" }
$tocContents = [IO.File]::ReadAllText($tocPath)
if ($tocContents -notmatch '(?im)^\s*##\s*Version:\s*(\S+)') { throw "Addon manifest has no Version line: $tocPath" }
# The release workflow passes the version from the tag it is about to create;
# local builds fall back to whatever the TOC currently says.
if (-not $Version) { $Version = $Matches[1] }
$Version = $Version.Trim().TrimStart('v')
if ($Version -notmatch '^\d+\.\d+\.\d+([-.+][0-9A-Za-z.-]+)?$') { throw "Invalid version: $Version" }
foreach ($required in @(
    (Join-Path $repoRoot 'README.md'),
    (Join-Path $repoRoot 'LICENSE')
)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Missing release input: $required" }
}
[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
$stageRoot = Join-Path $OutputDirectory ('stage-' + [Guid]::NewGuid().ToString('N'))
$combinedRoot = Join-Path $stageRoot 'combined'
$combinedAddonRoot = Join-Path $combinedRoot 'Interface\AddOns\Windrunner-Controller'
New-Item -ItemType Directory -Force -Path $combinedAddonRoot | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding($false)
$runtimeExtensions = @('.toc', '.lua', '.xml', '.tga', '.blp', '.ttf')
$copied = 0
foreach ($file in Get-ChildItem -LiteralPath $addonRoot -Recurse -File) {
    $relative = $file.FullName.Substring($addonRoot.Length + 1)
    if ($relative -match '^(tests|scripts|\.git|\.github)[\\/]') { continue }
    if ($file.Extension.ToLowerInvariant() -notin $runtimeExtensions) { continue }
    $target = Join-Path $combinedAddonRoot $relative
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
    Copy-Item -LiteralPath $file.FullName -Destination $target -Force
    $copied++
}
if ($copied -eq 0) { throw 'No addon runtime files were found to package.' }
$stagedToc = Join-Path $combinedAddonRoot 'Windrunner-Controller.toc'
$stampedToc = [regex]::Replace([IO.File]::ReadAllText($stagedToc), '(?im)^(\s*##\s*Version:[ \t]*)\S+', "`${1}$Version")
[IO.File]::WriteAllText($stagedToc, $stampedToc, $utf8)
Copy-Item -LiteralPath $DllPath -Destination (Join-Path $combinedRoot 'WindrunnerController.dll') -Force
Copy-Item -LiteralPath (Join-Path $repoRoot 'README.md') -Destination (Join-Path $combinedRoot 'README.md') -Force
Copy-Item -LiteralPath (Join-Path $repoRoot 'LICENSE') -Destination (Join-Path $combinedRoot 'LICENSE') -Force

$installText = @"
Windrunner Controller v$Version
================================

Requirements
- Windows 32-bit World of Warcraft 1.12.1, build 5875
- VanillaFixes 1.5.3 or newer
- Xbox/XInput, DualSense, or DualSense Edge controller

Install
1. Close World of Warcraft.
2. Copy the Interface folder into your WoW folder. This installs
   Interface\AddOns\Windrunner-Controller.
3. Copy WindrunnerController.dll into the same folder as WoW.exe.
4. Open dlls.txt in the WoW folder with a text editor and add this line:

       WindrunnerController.dll

   Do not remove or replace existing lines. If dlls.txt does not exist, create
   it with that line.
5. Install VanillaFixes if you do not have it:
   https://github.com/hannesmann/vanillafixes
6. Launch the game through VanillaFixes:

       VanillaFixes.exe WoW.exe

7. Enable Windrunner-Controller at character select.
8. Log in, connect a controller, and run /controller status.

Starting WoW.exe directly will not load the DLL.

Updating
- Replace the Windrunner-Controller folder and WindrunnerController.dll.
- Keep the WindrunnerController.dll line in dlls.txt.
- Your WTF settings are not touched.

Uninstalling
- Delete Interface\AddOns\Windrunner-Controller.
- Delete WindrunnerController.dll.
- Remove the WindrunnerController.dll line from dlls.txt.
"@
[IO.File]::WriteAllText((Join-Path $combinedRoot 'INSTALL.txt'), $installText, $utf8)
$combinedHashes = foreach ($file in Get-ChildItem -LiteralPath $combinedRoot -Recurse -File) {
    [PSCustomObject]@{
        path = $file.FullName.Substring($combinedRoot.Length + 1).Replace('\', '/')
        sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
    }
}
[IO.File]::WriteAllText((Join-Path $combinedRoot 'SHA256SUMS.json'), ($combinedHashes | ConvertTo-Json -Depth 3), $utf8)
function New-ZipFromDirectory([string]$sourceRoot, [string]$destinationZip) {
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    Remove-Item -LiteralPath $destinationZip -Force -ErrorAction SilentlyContinue
    $archive = [IO.Compression.ZipFile]::Open($destinationZip, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($file in Get-ChildItem -LiteralPath $sourceRoot -Recurse -File) {
            $entryName = $file.FullName.Substring($sourceRoot.Length + 1).Replace('\', '/')
            [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $archive, $file.FullName, $entryName, [IO.Compression.CompressionLevel]::Optimal)
        }
    } finally {
        $archive.Dispose()
    }
}
$combinedZip = Join-Path $OutputDirectory ("WindrunnerController-v$Version.zip")
New-ZipFromDirectory $combinedRoot $combinedZip
try {
    Remove-Item -LiteralPath $stageRoot -Recurse -Force
} catch {
    Write-Warning "Could not remove staging directory: $stageRoot"
}
Write-Output $combinedZip
