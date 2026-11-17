param(
    [string]$PortName = 'COM6',
    [int]$BaudRate = 115200
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$recordPath = Join-Path $projectRoot 'build\serial-test'
New-Item -ItemType Directory -Path $recordPath -Force | Out-Null
$serial = New-Object System.IO.Ports.SerialPort
$serial.PortName = $PortName
$serial.BaudRate = $BaudRate
$serial.DataBits = 8
$serial.Parity = [System.IO.Ports.Parity]::None
$serial.StopBits = [System.IO.Ports.StopBits]::One
$serial.Handshake = [System.IO.Ports.Handshake]::None
$serial.DtrEnable = $false
$serial.RtsEnable = $false
$serial.Encoding = [System.Text.Encoding]::ASCII
$serial.ReadTimeout = 200
$serial.WriteTimeout = 1000
$capture = New-Object System.Text.StringBuilder
$events = New-Object System.Collections.Generic.List[object]
$clock = [System.Diagnostics.Stopwatch]::StartNew()
$result = [ordered]@{
    port = $PortName; baud = $BaudRate; format = '8N1'; handshake = 'None'
    overall_result = 'FAIL'; serial_port_closed = $false
}
function Read-For([int]$Milliseconds) {
    $until = $clock.ElapsedMilliseconds + $Milliseconds
    while ($clock.ElapsedMilliseconds -lt $until) {
        $chunk = $serial.ReadExisting()
        if ($chunk.Length -gt 0) {
            [void]$capture.Append($chunk)
            $events.Add([ordered]@{ seconds = [Math]::Round($clock.Elapsed.TotalSeconds, 3); received = $chunk })
        }
        Start-Sleep -Milliseconds 20
    }
}
try {
    $serial.Open()
    $serial.DiscardInBuffer()
    Read-For 2300
    foreach ($command in @('p', '3', '?')) {
        $events.Add([ordered]@{ seconds = [Math]::Round($clock.Elapsed.TotalSeconds, 3); sent = $command })
        $serial.Write($command)
        Read-For 500
    }
    Read-For 3300
    $received = $capture.ToString()
    $tickMatches = [regex]::Matches($received, '(?m)^TICK=([0-9A-F]{8}) GPIO=([0-9A-F]{8})\r?$')
    $ticks = @($tickMatches | ForEach-Object { [Convert]::ToUInt32($_.Groups[1].Value, 16) })
    $consecutive = $ticks.Count -ge 4
    for ($i = 1; $i -lt $ticks.Count; $i++) {
        if (($ticks[$i] - $ticks[$i - 1]) -ne 1) { $consecutive = $false }
    }
    $result.pong_received = [regex]::IsMatch($received, '(?m)^PONG\r?$')
    $result.gpio_command_readback_received = [regex]::IsMatch($received, '(?m)^GPIO=00000008\r?$')
    $result.cpu_status_received = [regex]::IsMatch($received, '(?m)^CPU=PicoRV32 TICKS=[0-9A-F]{8} GPIO=[0-9A-F]{8}\r?$')
    $result.tick_values = $ticks
    $result.consecutive_ticks = $consecutive
    $result.capture_seconds = [Math]::Round($clock.Elapsed.TotalSeconds, 3)
    if (-not ($result.pong_received -and $result.gpio_command_readback_received -and $result.cpu_status_received -and $consecutive)) {
        throw 'Missing serial reply or consecutive periodic ticks. See capture.txt.'
    }
    $result.overall_result = 'SERIAL_CPU_RX_TX_GPIO_TIMER_PASS'
} catch {
    $result.error = $_.Exception.Message
} finally {
    if ($serial.IsOpen) { $serial.Close() }
    $serial.Dispose()
    $result.serial_port_closed = $true
    $result.capture_seconds = [Math]::Round($clock.Elapsed.TotalSeconds, 3)
    [IO.File]::WriteAllText((Join-Path $recordPath 'capture.txt'), $capture.ToString(), [Text.Encoding]::UTF8)
    [IO.File]::WriteAllText((Join-Path $recordPath 'events.json'), (ConvertTo-Json -InputObject $events.ToArray() -Depth 5), [Text.Encoding]::UTF8)
    $json = $result | ConvertTo-Json -Depth 6
    [IO.File]::WriteAllText((Join-Path $recordPath 'result.json'), $json, [Text.Encoding]::UTF8)
    Write-Output $capture.ToString()
    Write-Output $json
}
if ($result.overall_result -ne 'SERIAL_CPU_RX_TX_GPIO_TIMER_PASS') { exit 1 }
