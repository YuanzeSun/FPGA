param([string]$PortName='COM6')
. (Join-Path $PSScriptRoot 'serial_common.ps1')
$result=[ordered]@{OverallResult='FAIL';Game=1;PhysicalHDMIObservationPerformed=$false;SerialPortClosed=$false}
$records=Join-Path (Split-Path $PSScriptRoot -Parent) ('build/serial-test-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
[void](New-Item -ItemType Directory -Path $records)
try {
    Open-RiscPort $PortName
    Read-RiscFor 1400
    $challenge=[string][char](Get-Random -Minimum 66 -Maximum 90)
    $ack=Send-RiscCommand $challenge
    $result.FreshChallenge=$challenge
    $result.FreshChallengeAcknowledged=$true
    [void](Send-RiscCommand 'm')
    $initial=Send-RiscCommand '1' 300
    if($initial.G -ne 1 -or $initial.S -ne 0 -or $initial.T -ne 0 -or $initial.P -ne 0 -or $initial.A -ne 0){throw 'C snake selection/reset failed'}
    Write-RiscByte 0x88
    Read-RiscFor 300
    Write-RiscByte 0x80
    $before=Send-RiscCommand 'p' 300
    if($before.Y -le $initial.Y -or $before.T -ne 0){throw 'C snake downward movement failed'}
    Read-RiscFor 1600
    $after=Send-RiscCommand '?' 300
    if($after.P -ne 1 -or $after.X -ne $before.X -or $after.Y -ne $before.Y -or $after.S -ne $before.S){throw 'C snake pause failed'}
    $fps=($after.F-$before.F)/($after.Seconds-$before.Seconds)
    if($fps -lt 57 -or $fps -gt 63){throw "Frame rate unexpected: $fps"}
    $reset=Send-RiscCommand 'r' 300
    if($reset.P -ne 0 -or $reset.S -ne 0 -or $reset.T -ne 0 -or $reset.X -ne 5 -or $reset.Y -ne 0){throw 'C snake restart failed'}
    $automatic=Send-RiscCommand 'a'
    if($automatic.A -ne 1 -or $automatic.G -ne 1){throw 'C snake autoplay failed'}
    $result.OverallResult='RISC_CPU_SNAKE_HARDWARE_PASS'
    $result.MovementPassed=$true
    $result.PausePassed=$true
    $result.RestartPassed=$true
    $result.AutoplayPassed=$true
    $result.MeasuredFramesPerSecond=[Math]::Round($fps,3)
} catch {
    $result.Error=$_.Exception.Message
    throw
} finally {
    Close-RiscPort
    $result.SerialPortClosed=$true
    if($null -ne $script:RiscCapture){[IO.File]::WriteAllText((Join-Path $records 'capture.txt'),$script:RiscCapture.ToString())}
    $script:RiscEvents | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $records 'events.json') -Encoding UTF8
    $script:RiscSnapshots | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $records 'snapshots.json') -Encoding UTF8
    $result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $records 'result.json') -Encoding UTF8
    $result | ConvertTo-Json -Depth 5 | Write-Host
}
