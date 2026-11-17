$ErrorActionPreference='Stop'
function Open-PongPort([string]$PortName='COM6') {
    $script:PongPort=New-Object System.IO.Ports.SerialPort $PortName,115200,None,8,One
    $script:PongPort.DtrEnable=$false
    $script:PongPort.RtsEnable=$false
    $script:PongPort.Handshake=[IO.Ports.Handshake]::None
    $script:PongPort.Encoding=[Text.Encoding]::ASCII
    $script:PongPort.ReadTimeout=100
    $script:PongPort.WriteTimeout=1000
    $script:PongCapture=New-Object Text.StringBuilder
    $script:PongPending=''
    $script:PongEvents=New-Object System.Collections.Generic.List[object]
    $script:PongSnapshots=New-Object System.Collections.Generic.List[object]
    $script:PongWatch=[Diagnostics.Stopwatch]::StartNew()
    $script:PongPort.Open()
    $script:PongPort.DiscardInBuffer()
}
function Close-PongPort {
    if($null -ne $script:PongPort) {
        if($script:PongPort.IsOpen){$script:PongPort.Close()}
        $script:PongPort.Dispose()
    }
}
function Read-PongFor([int]$Milliseconds) {
    $until=$script:PongWatch.ElapsedMilliseconds+$Milliseconds
    while($script:PongWatch.ElapsedMilliseconds -lt $until) {
        $chunk=$script:PongPort.ReadExisting()
        if($chunk.Length -gt 0) {
            [void]$script:PongCapture.Append($chunk)
            $script:PongPending+=$chunk
            while(($split=$script:PongPending.IndexOf("`n")) -ge 0) {
                $line=$script:PongPending.Substring(0,$split).TrimEnd("`r")
                $script:PongPending=$script:PongPending.Substring($split+1)
                $pattern='^PONG F=(?<F>[0-9A-F]{8}) L=(?<L>[0-9A-F]{2}) R=(?<R>[0-9A-F]{2}) PY=(?<PY>[0-9A-F]{3}) X=(?<X>[0-9A-F]{3}) Y=(?<Y>[0-9A-F]{3}) A=(?<A>[01]) P=(?<P>[01]) C=(?<C>[0-9A-F]{8}) K=(?<K>[0-9A-F]{2})$'
                $match=[regex]::Match($line,$pattern)
                if($match.Success) {
                    $sample=[ordered]@{Seconds=[Math]::Round($script:PongWatch.Elapsed.TotalSeconds,4)}
                    foreach($name in @('F','L','R','PY','X','Y','A','P','C','K')) {
                        $sample[$name]=[Convert]::ToUInt32($match.Groups[$name].Value,16)
                    }
                    $script:PongSnapshots.Add([pscustomobject]$sample)
                }
            }
        }
        Start-Sleep -Milliseconds 5
    }
}
function Get-PongSnapshot {
    if($script:PongSnapshots.Count -eq 0){return $null}
    return $script:PongSnapshots[$script:PongSnapshots.Count-1]
}
function Write-PongKey([string]$Key) {
    $script:PongEvents.Add([pscustomobject]@{Seconds=[Math]::Round($script:PongWatch.Elapsed.TotalSeconds,4);Sent=$Key})
    $script:PongPort.Write($Key)
}
function Send-PongCommand([string]$Command,[int]$WaitMs=220) {
    $previous=Get-PongSnapshot
    $minimum=if($null -eq $previous){0}else{[long]$previous.C+1}
    $start=$script:PongWatch.Elapsed.TotalSeconds
    Write-PongKey $Command
    Read-PongFor $WaitMs
    $wanted=[int][char]$Command
    $matches=@($script:PongSnapshots | Where-Object {$_.K -eq $wanted -and $_.C -ge $minimum -and $_.Seconds -gt $start})
    if($matches.Count -eq 0){throw ('No fresh Pong acknowledgement for '+$Command)}
    return $matches[$matches.Count-1]
}
