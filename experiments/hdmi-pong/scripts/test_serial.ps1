param([string]$PortName='COM6')
. (Join-Path $PSScriptRoot 'serial_common.ps1')
$records=Join-Path (Split-Path -Parent $PSScriptRoot) 'build\serial-test'
New-Item -ItemType Directory -Path $records -Force | Out-Null
$result=[ordered]@{OverallResult='FAIL';Port=$PortName;Baud=115200;SerialPortClosed=$false;PhysicalHDMIObservationPerformed=$false}
try {
    Open-PongPort $PortName
    Read-PongFor 1200
    $challenge=[string][char](Get-Random -Minimum 65 -Maximum 91)
    $fresh=Send-PongCommand $challenge
    $result.FreshChallenge=$challenge
    $result.FreshAcknowledgementPassed=$fresh.K -eq [int][char]$challenge
    $manual=Send-PongCommand 'm'
    Read-PongFor 350
    $before=Send-PongCommand '?'
    if($before.A -ne 0){throw 'Manual mode failed'}
    if($before.P -ne 0){[void](Send-PongCommand 'p')}
    $direction=if($before.PY -lt 190){'d'}else{'u'}
    [void](Send-PongCommand $direction 130)
    Read-PongFor 60
    $after=Send-PongCommand '?'
    $moved=if($direction -eq 'u'){$after.PY -lt $before.PY}else{$after.PY -gt $before.PY}
    $result.ManualPaddle=[ordered]@{Command=$direction;BeforeY=$before.PY;AfterY=$after.PY;Passed=$moved}
    if(-not $moved){throw 'Serial movement did not move the paddle in the requested direction'}
    [void](Send-PongCommand 'n')
    Read-PongFor 200
    $paused=Send-PongCommand 'p'
    if($paused.P -ne 1){throw 'Pause command failed'}
    Read-PongFor 1700
    $held=Send-PongCommand '?'
    $still=$held.P -eq 1 -and $held.X -eq $paused.X -and $held.Y -eq $paused.Y
    $fps=($held.F-$paused.F)/($held.Seconds-$paused.Seconds)
    $result.PausePassed=$still
    $result.MeasuredFramesPerSecond=[Math]::Round($fps,3)
    $result.FrameRatePassed=$fps -gt 57 -and $fps -lt 63
    if(-not $still -or -not $result.FrameRatePassed){throw 'Pause or 60 Hz frame counter check failed'}
    [void](Send-PongCommand 'p')
    Read-PongFor 300
    $running=Send-PongCommand '?'
    $result.ResumePassed=$running.P -eq 0 -and ($running.X -ne $held.X -or $running.Y -ne $held.Y)
    if(-not $result.ResumePassed){throw 'Resume failed'}
    $restart=Send-PongCommand 'r'
    $result.RestartPassed=$restart.L -eq 0 -and $restart.R -eq 0 -and $restart.P -eq 0
    if(-not $result.RestartPassed){throw 'Restart failed'}
    $auto=Send-PongCommand 'a'
    $result.AutoplayPassed=$auto.A -eq 1
    if(-not $result.AutoplayPassed){throw 'Autoplay failed'}
    $result.FinalState=Send-PongCommand '?'
    $result.OverallResult='PONG_HARDWARE_CONTROL_AND_60HZ_TELEMETRY_PASS'
} catch {
    $result.Error=$_.Exception.Message
} finally {
    Close-PongPort
    $result.SerialPortClosed=$true
    $result.CaptureSeconds=[Math]::Round($script:PongWatch.Elapsed.TotalSeconds,3)
    [IO.File]::WriteAllText((Join-Path $records 'capture.txt'),$script:PongCapture.ToString(),[Text.Encoding]::UTF8)
    [IO.File]::WriteAllText((Join-Path $records 'events.json'),(ConvertTo-Json -InputObject $script:PongEvents.ToArray() -Depth 5),[Text.Encoding]::UTF8)
    [IO.File]::WriteAllText((Join-Path $records 'snapshots.json'),(ConvertTo-Json -InputObject $script:PongSnapshots.ToArray() -Depth 5),[Text.Encoding]::UTF8)
    $json=$result|ConvertTo-Json -Depth 8
    [IO.File]::WriteAllText((Join-Path $records 'result.json'),$json,[Text.Encoding]::UTF8)
    Write-Output $script:PongCapture.ToString()
    Write-Output $json
}
if($result.OverallResult -ne 'PONG_HARDWARE_CONTROL_AND_60HZ_TELEMETRY_PASS'){exit 1}
