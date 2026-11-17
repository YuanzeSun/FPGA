param([string]$PortName = 'COM6', [int]$BaudRate = 115200)
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
$result = [ordered]@{ port = $PortName; baud = $BaudRate; format = '8N1'; overall_result = 'FAIL'; serial_port_closed = $false }
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
    Read-For 1200
    $challengeCodes = @(65..90 | Get-Random -Count 2)
    foreach ($challengeCode in $challengeCodes) {
        $challenge = [string][char]$challengeCode
        $events.Add([ordered]@{ seconds = [Math]::Round($clock.Elapsed.TotalSeconds,3); sent = $challenge })
        $serial.Write($challenge)
        Read-For 600
    }
    foreach ($command in @('p', 'm', 'i', '3', '?', 'i', '?')) {
        $events.Add([ordered]@{ seconds = [Math]::Round($clock.Elapsed.TotalSeconds, 3); sent = $command })
        $serial.Write($command)
        Read-For 600
    }
    Read-For 2300
    $received = $capture.ToString()
    $tickMatches = [regex]::Matches($received, '(?m)^IRQ_TICK=([0-9A-F]{8}) GPIO=([0-9A-F]{8})\r?$')
    $ticks = @($tickMatches | ForEach-Object { [Convert]::ToUInt32($_.Groups[1].Value, 16) })
    $consecutive = $ticks.Count -ge 4
    for ($i = 1; $i -lt $ticks.Count; $i++) {
        if (($ticks[$i] - $ticks[$i - 1]) -ne 1) { $consecutive = $false }
    }
    $pattern = '(?m)^CPU=RV32IMC SELF=000000FF IRQ=([0-9A-F]{8}) SOFT=([0-9A-F]{8}) ILLEGAL=00000002 ALIGN=00000001 TRACE=([0-9A-F]{8}) CYCLEH=([0-9A-F]{8}) CYCLE=([0-9A-F]{8}) INSTRETH=([0-9A-F]{8}) INSTRET=([0-9A-F]{8})\r?$'
    $snapshots = @([regex]::Matches($received, $pattern) | ForEach-Object {
        [ordered]@{
            timer_irq = [Convert]::ToUInt32($_.Groups[1].Value,16)
            soft_irq = [Convert]::ToUInt32($_.Groups[2].Value,16)
            trace = [Convert]::ToUInt32($_.Groups[3].Value,16)
            cycle_high = [Convert]::ToUInt32($_.Groups[4].Value,16)
            cycle = [Convert]::ToUInt32($_.Groups[5].Value,16)
            instret_high = [Convert]::ToUInt32($_.Groups[6].Value,16)
            instret = [Convert]::ToUInt32($_.Groups[7].Value,16)
        }
    })
    $progress = $snapshots.Count -eq 2
    if ($progress) {
        $firstCycle = [UInt64]$snapshots[0].cycle_high * 4294967296 + [UInt64]$snapshots[0].cycle
        $lastCycle = [UInt64]$snapshots[1].cycle_high * 4294967296 + [UInt64]$snapshots[1].cycle
        $firstInstret = [UInt64]$snapshots[0].instret_high * 4294967296 + [UInt64]$snapshots[0].instret
        $lastInstret = [UInt64]$snapshots[1].instret_high * 4294967296 + [UInt64]$snapshots[1].instret
        $progress = $snapshots[1].trace -gt $snapshots[0].trace -and
                    $lastCycle -gt $firstCycle -and $lastInstret -gt $firstInstret -and
                    $snapshots[1].soft_irq -eq ($snapshots[0].soft_irq + 1)
    }
    $fresh = $true
    foreach ($challengeCode in $challengeCodes) {
        $expected = 'RX=' + ('{0:X8}' -f $challengeCode)
        if (-not [regex]::IsMatch($received, '(?m)^' + $expected + '\r?$')) { $fresh = $false }
    }
    $result.challenge_codes = $challengeCodes
    $result.fresh_challenge_passed = $fresh
    $result.pong_received = [regex]::IsMatch($received, '(?m)^PONG\r?$')
    $result.m_extension_retest_passed = [regex]::IsMatch($received, '(?m)^M=PASS\r?$')
    $result.gpio_command_passed = [regex]::IsMatch($received, '(?m)^GPIO=00000008\r?$')
    $softReplies = @([regex]::Matches($received, '(?m)^SOFTIRQ=([0-9A-F]{8})\r?$') | ForEach-Object { [Convert]::ToUInt32($_.Groups[1].Value,16) })
    $softPass = $softReplies.Count -eq 2 -and $snapshots.Count -eq 2
    if ($softPass) {
        $softPass = $softReplies[1] -eq ($softReplies[0] + 1) -and $softReplies[0] -eq $snapshots[0].soft_irq -and $softReplies[1] -eq $snapshots[1].soft_irq
    }
    $result.two_software_interrupts_passed = $softPass
    $result.expected_selftest_mask = '0x000000FF'
    $result.status_snapshots = $snapshots
    $result.counter_and_trace_progress_passed = $progress
    $result.tick_values = $ticks
    $result.consecutive_interrupt_ticks = $consecutive
    if (-not ($fresh -and $result.pong_received -and $result.m_extension_retest_passed -and $result.gpio_command_passed -and $result.two_software_interrupts_passed -and $progress -and $consecutive)) {
        throw 'Full CPU serial validation failed; see capture.txt and result.json.'
    }
    $result.overall_result = 'FULL_CPU_FEATURES_AND_UART_HARDWARE_PASS'
} catch {
    $result.error = $_.Exception.Message
} finally {
    if ($serial.IsOpen) { $serial.Close() }
    $serial.Dispose()
    $result.serial_port_closed = $true
    $result.capture_seconds = [Math]::Round($clock.Elapsed.TotalSeconds,3)
    [IO.File]::WriteAllText((Join-Path $recordPath 'capture.txt'), $capture.ToString(), [Text.Encoding]::UTF8)
    [IO.File]::WriteAllText((Join-Path $recordPath 'events.json'), (ConvertTo-Json -InputObject $events.ToArray() -Depth 5), [Text.Encoding]::UTF8)
    $json = $result | ConvertTo-Json -Depth 7
    [IO.File]::WriteAllText((Join-Path $recordPath 'result.json'), $json, [Text.Encoding]::UTF8)
    Write-Output $capture.ToString()
    Write-Output $json
}
if ($result.overall_result -ne 'FULL_CPU_FEATURES_AND_UART_HARDWARE_PASS') { exit 1 }
