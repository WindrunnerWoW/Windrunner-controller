[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$ClientDirectory)
$ErrorActionPreference = 'Stop'
$clientRoot = [IO.Path]::GetFullPath($ClientDirectory).TrimEnd('\')
$gamePath = Join-Path $clientRoot 'WoW.exe'
$launcherPath = Join-Path $clientRoot 'VanillaFixes.exe'
$logPath = Join-Path $clientRoot 'WindrunnerController.log'
foreach ($path in @($gamePath, $launcherPath, (Join-Path $clientRoot 'WindrunnerController.dll'))) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing smoke-test file: $path" }
}
$beforeIds = @(Get-CimInstance Win32_Process -Filter "Name='WoW.exe'" | Select-Object -ExpandProperty ProcessId)
foreach ($existing in @(Get-CimInstance Win32_Process -Filter "Name='WoW.exe'")) {
    if (-not $existing.ExecutablePath -or $existing.ExecutablePath -eq $gamePath) {
        throw 'Close existing WoW clients before the bootstrap smoke test.'
    }
}
$oldLines = if (Test-Path -LiteralPath $logPath) { @(Get-Content -LiteralPath $logPath).Count } else { 0 }
$startedAt = Get-Date
$ownedGame = $null
$ownedLauncher = $null
$logText = ''
function CloseOwnedProcess($identity) {
    if (-not $identity) { return }
    $current = Get-CimInstance Win32_Process -Filter ("ProcessId=" + $identity.ProcessId)
    if (-not $current -or $current.ParentProcessId -ne $identity.ParentProcessId -or $current.CreationDate -ne $identity.CreationDate) { return }
    $process = Get-Process -Id $identity.ProcessId -ErrorAction SilentlyContinue
    if ($process) { [void]$process.CloseMainWindow() }
    $deadline = (Get-Date).AddSeconds(3)
    do {
        Start-Sleep -Milliseconds 200
        $current = Get-CimInstance Win32_Process -Filter ("ProcessId=" + $identity.ProcessId)
    } while ($current -and (Get-Date) -lt $deadline)
    if ($current -and $current.ParentProcessId -eq $identity.ParentProcessId -and $current.CreationDate -eq $identity.CreationDate) {
        $result = Invoke-CimMethod -InputObject $current -MethodName Terminate -Arguments @{Reason=0}
        if ($result.ReturnValue -ne 0) { throw "Could not close owned smoke-test process $($identity.ProcessId)." }
    }
}
try {
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $launcherPath
    $info.Arguments = 'WoW.exe'
    $info.WorkingDirectory = $clientRoot
    $info.UseShellExecute = $false
    $info.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $launcher = [Diagnostics.Process]::Start($info)
    $ownedLauncher = Get-CimInstance Win32_Process -Filter ("ProcessId=" + $launcher.Id)
    $deadline = $startedAt.AddSeconds(30)
    while ((Get-Date) -lt $deadline) {
        # Identity comes from the child of the exact launcher we started, so
        # restricted Process.Path metadata does not prevent safe cleanup.
        foreach ($candidate in @(Get-CimInstance Win32_Process -Filter ("ParentProcessId=" + $launcher.Id + " AND Name='WoW.exe'"))) {
            if ($beforeIds -notcontains $candidate.ProcessId -and $candidate.CreationDate -ge $startedAt.AddSeconds(-1) -and
                (-not $candidate.ExecutablePath -or $candidate.ExecutablePath -eq $gamePath)) {
                $ownedGame = $candidate
                break
            }
        }
        if (Test-Path -LiteralPath $logPath) {
            $logText = (@(Get-Content -LiteralPath $logPath | Select-Object -Skip $oldLines)) -join "`n"
            if ($logText -match 'hooks installed; awaiting script initialization' -or $logText -match 'ERROR:') { break }
        }
        Start-Sleep -Milliseconds 200
    }
    Write-Output $logText
    if ($logText -match 'ERROR:' -or $logText -notmatch 'hooks installed; awaiting script initialization' -or -not $ownedGame) {
        throw 'Native bootstrap failed or timed out. See the log above.'
    }
    Write-Output 'PASS: actual client fingerprints, existing extension hooks, system XInput and native bootstrap. World login and physical input remain untested.'
} finally {
    CloseOwnedProcess $ownedGame
    CloseOwnedProcess $ownedLauncher
}
