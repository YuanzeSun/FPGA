param([string]$PortName='COM6')
. (Join-Path $PSScriptRoot 'serial_common.ps1')
$result=[ordered]@{OverallResult='FAIL';PhysicalHDMIObservationPerformed=$false;Games=@();SerialPortClosed=$false}
$records=Join-Path (Split-Path $PSScriptRoot -Parent) ('build/serial-test-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
[void](New-Item -ItemType Directory -Path $records)
try {
    Open-ArcadePort $PortName;Read-ArcadeFor 1200
    [void](Send-ArcadeCommand ([string][char](Get-Random -Minimum 66 -Maximum 90)))
    [void](Send-ArcadeCommand 'm')
    foreach($game in 1..3) {
        $initial=Send-ArcadeCommand ([string]$game)
        if($initial.G -ne $game -or $initial.L -ne 3 -or $initial.S -ne 0){throw 'Game selection/reset failed'}
        Write-ArcadeByte 0x81;Read-ArcadeFor 180;Write-ArcadeByte 0x80
        $moved=Send-ArcadeCommand '?'
        if($moved.PX -ge $initial.PX){throw 'Movement failed'}
        $before=Send-ArcadeCommand 'p';Read-ArcadeFor 1600;$after=Send-ArcadeCommand '?'
        if($after.X -ne $before.X -or $after.Y -ne $before.Y -or $after.PX -ne $before.PX -or $after.P -ne 1){throw 'Pause failed'}
        $fps=($after.F-$before.F)/($after.Seconds-$before.Seconds)
        if($fps -lt 57 -or $fps -gt 63){throw "Frame counter rate unexpected: $fps"}
        $reset=Send-ArcadeCommand 'r'
        if($reset.S -ne 0 -or $reset.L -ne 3 -or $reset.P -ne 0){throw 'Restart failed'}
        if($game -gt 1){Write-ArcadeByte 0x84;Read-ArcadeFor 100;Write-ArcadeByte 0x80}
        $result.Games+=@{Game=$game;MovementPassed=$true;PausePassed=$true;RestartPassed=$true;MeasuredFramesPerSecond=[Math]::Round($fps,3)}
    }
    [void](Send-ArcadeCommand '1');[void](Send-ArcadeCommand 'a')
    $result.OverallResult='ARCADE_HARDWARE_CONTROLS_PASS'
} catch {
    $result.Error=$_.Exception.Message
    throw
} finally {
    Close-ArcadePort;$result.SerialPortClosed=$true
    if($null -ne $script:ArcadeCapture){[IO.File]::WriteAllText((Join-Path $records 'capture.txt'),$script:ArcadeCapture.ToString())}
    $script:ArcadeEvents | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $records 'events.json') -Encoding UTF8
    $script:ArcadeSnapshots | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $records 'snapshots.json') -Encoding UTF8
    $result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $records 'result.json') -Encoding UTF8
    $result | ConvertTo-Json -Depth 5 | Write-Host
}
