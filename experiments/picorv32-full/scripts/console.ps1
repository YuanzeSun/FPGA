param([string]$PortName = 'COM6', [int]$BaudRate = 115200)
$ErrorActionPreference = 'Stop'
$serial = New-Object System.IO.Ports.SerialPort $PortName, $BaudRate, None, 8, One
$serial.Handshake = [System.IO.Ports.Handshake]::None
$serial.DtrEnable = $false
$serial.RtsEnable = $false
$serial.Encoding = [Text.Encoding]::ASCII
$serial.WriteTimeout = 1000
$oldControlC = [Console]::TreatControlCAsInput
try {
    if ([Console]::IsInputRedirected) { throw 'Run this script in an interactive Windows terminal.' }
    [Console]::TreatControlCAsInput = $true
    $serial.Open()
    Write-Host "$PortName at $BaudRate 8N1. Keys are sent immediately; no Enter needed."
    Write-Host 'p: PONG; m: multiply/divide test; i: software IRQ; ?: CPU status; 0..5: LED; Ctrl+C: close.'
    while ($true) {
        $received = $serial.ReadExisting()
        if ($received.Length -gt 0) { [Console]::Write($received) }
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            if ([int]$key.KeyChar -eq 3) { break }
            if ([int]$key.KeyChar -ge 32 -and [int]$key.KeyChar -lt 127) { $serial.Write([string]$key.KeyChar) }
        }
        Start-Sleep -Milliseconds 20
    }
} finally {
    if ($serial.IsOpen) { $serial.Close() }
    $serial.Dispose()
    [Console]::TreatControlCAsInput = $oldControlC
    Write-Host "`nSerial port closed."
}
