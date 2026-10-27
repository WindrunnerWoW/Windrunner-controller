[CmdletBinding()]
param([string]$ClientDirectory = 'C:\TurtleDev\04_client\gamebak')
$ErrorActionPreference = 'Stop'
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class ControllerReadMemory {
 [DllImport("kernel32.dll", SetLastError=true)] public static extern IntPtr OpenProcess(uint access, bool inherit, int pid);
 [DllImport("kernel32.dll", SetLastError=true)] public static extern bool ReadProcessMemory(IntPtr process, IntPtr address, byte[] buffer, UIntPtr size, out UIntPtr read);
 [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr handle);
}
'@
$expectedPath = Join-Path $ClientDirectory 'WoW.exe'
$matches = @(Get-CimInstance Win32_Process -Filter "Name='WoW.exe'" | Where-Object { $_.ExecutablePath -eq $expectedPath })
if ($matches.Count -ne 1) { throw 'Exactly one identified backup client is required for read-only diagnostics.' }
$handle = [ControllerReadMemory]::OpenProcess(0x410, $false, $matches[0].ProcessId)
if ($handle -eq [IntPtr]::Zero) { throw 'Cannot open client for read-only diagnostics.' }
function Bytes([long]$address, [int]$length) {
    if ($address -lt 0x10000 -or $address -gt 0xFFFFFFFF -or $length -lt 1 -or $length -gt 1048576) { throw 'Invalid memory range.' }
    $buffer = New-Object byte[] $length
    $read = [UIntPtr]::Zero
    if (![ControllerReadMemory]::ReadProcessMemory($handle, [IntPtr]$address, $buffer, [UIntPtr]$length, [ref]$read) -or $read.ToUInt64() -ne $length) { throw 'Client memory read failed.' }
    return ,$buffer
}
function U32([long]$address) { return [BitConverter]::ToUInt32((Bytes $address 4),0) }
function StringKey([long]$address) {
    $length = U32 ($address + 12)
    if ($length -gt 100 -or $length -eq 0) { return '' }
    return [Text.Encoding]::UTF8.GetString((Bytes ($address + 16) $length))
}
function Field([long]$table, [string]$name) {
    $header = Bytes $table 32
    $power = $header[7]
    if ($power -gt 16) { throw 'Unexpected Lua table layout.' }
    $nodes = [BitConverter]::ToUInt32($header,16)
    $count = 1 -shl $power
    for ($index=0; $index -lt $count; $index++) {
        $node = Bytes ($nodes + $index * 40) 32
        if ([BitConverter]::ToUInt32($node,0) -ne 4) { continue }
        $key = [BitConverter]::ToUInt32($node,8)
        if ((StringKey $key) -ceq $name) { return ,$node[16..31] }
    }
    return $null
}
function Value($bytes) {
    if (!$bytes) { return '<missing>' }
    switch ([BitConverter]::ToUInt32($bytes,0)) {
        0 { return '<nil>' }
        1 { return [BitConverter]::ToUInt32($bytes,8) -ne 0 }
        3 { return [BitConverter]::ToDouble($bytes,8) }
        4 { return StringKey ([BitConverter]::ToUInt32($bytes,8)) }
        default { return ('<type ' + [BitConverter]::ToUInt32($bytes,0) + '>') }
    }
}
try {
    $lua = U32 0x00CEEF74
    if ((U32 ($lua+0x40)) -ne 5) { throw 'Unexpected Lua globals layout.' }
    $globals = U32 ($lua+0x48)
    $controllerValue = Field $globals 'WindrunnerController'
    if (!$controllerValue -or [BitConverter]::ToUInt32($controllerValue,0) -ne 5) { throw 'WindrunnerController addon global is absent.' }
    $controller = [BitConverter]::ToUInt32($controllerValue,8)
    foreach ($name in @('world','armed','paused','connected','foreground','generation','buttons','lt','rt','focusedEditBox','releaseError','clock')) {
        Write-Output ($name + '=' + (Value (Field $controller $name)))
    }
    foreach ($name in @('WindrunnerController_Poll','WindrunnerController_RunFrame','WindrunnerController_RunRelease')) {
        Write-Output ($name + '=' + (Value (Field $globals $name)))
    }
} finally { [void][ControllerReadMemory]::CloseHandle($handle) }
