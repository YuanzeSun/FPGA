$ErrorActionPreference='Stop'
function ConvertFrom-ArcadeLine([string]$Line) {
    $pattern='^ARCADE G=(?<G>[123]) F=(?<F>[0-9A-F]{8}) S=(?<S>[0-9A-F]{2}) L=(?<L>[0-3]) T=(?<T>[0-2]) PX=(?<PX>[0-9A-F]{3}) X=(?<X>[0-9A-F]{3}) Y=(?<Y>[0-9A-F]{3}) A=(?<A>[01]) P=(?<P>[01]) C=(?<C>[0-9A-F]{8}) K=(?<K>[0-9A-F]{2})$'
    $match=[regex]::Match($Line,$pattern)
    if(-not $match.Success){return $null}
    $sample=[ordered]@{}
    foreach($name in @('G','F','S','L','T','PX','X','Y','A','P','C','K')) {
        $sample[$name]=[Convert]::ToUInt32($match.Groups[$name].Value,16)
    }
    return [pscustomobject]$sample
}
function Open-ArcadePort([string]$PortName='COM6') {
    $script:ArcadePort=New-Object System.IO.Ports.SerialPort $PortName,115200,None,8,One
    $script:ArcadePort.DtrEnable=$false;$script:ArcadePort.RtsEnable=$false
    $script:ArcadePort.Handshake=[IO.Ports.Handshake]::None
    $script:ArcadePort.Encoding=[Text.Encoding]::ASCII
    $script:ArcadePort.ReadTimeout=100;$script:ArcadePort.WriteTimeout=1000
    $script:ArcadeCapture=New-Object Text.StringBuilder
    $script:ArcadePending=''
    $script:ArcadeEvents=New-Object System.Collections.Generic.List[object]
    $script:ArcadeSnapshots=New-Object System.Collections.Generic.List[object]
    $script:ArcadeWatch=[Diagnostics.Stopwatch]::StartNew()
    $script:ArcadePort.Open();$script:ArcadePort.DiscardInBuffer()
}
function Close-ArcadePort {
    if($null -ne $script:ArcadePort) {
        if($script:ArcadePort.IsOpen){$script:ArcadePort.Close()}
        $script:ArcadePort.Dispose()
    }
}
function Read-ArcadeFor([int]$Milliseconds) {
    $until=$script:ArcadeWatch.ElapsedMilliseconds+$Milliseconds
    while($script:ArcadeWatch.ElapsedMilliseconds -lt $until) {
        $chunk=$script:ArcadePort.ReadExisting()
        if($chunk.Length -gt 0) {
            [void]$script:ArcadeCapture.Append($chunk);$script:ArcadePending+=$chunk
            while(($split=$script:ArcadePending.IndexOf("`n")) -ge 0) {
                $line=$script:ArcadePending.Substring(0,$split).TrimEnd("`r")
                $script:ArcadePending=$script:ArcadePending.Substring($split+1)
                $sample=ConvertFrom-ArcadeLine $line
                if($null -ne $sample) {
                    $sample | Add-Member -NotePropertyName Seconds -NotePropertyValue ([Math]::Round($script:ArcadeWatch.Elapsed.TotalSeconds,4))
                    $script:ArcadeSnapshots.Add($sample)
                }
            }
        }
        Start-Sleep -Milliseconds 5
    }
}
function Get-ArcadeSnapshot {
    if($script:ArcadeSnapshots.Count -eq 0){return $null}
    return $script:ArcadeSnapshots[$script:ArcadeSnapshots.Count-1]
}
function Write-ArcadeByte([byte]$Value) {
    $script:ArcadeEvents.Add([pscustomobject]@{Seconds=[Math]::Round($script:ArcadeWatch.Elapsed.TotalSeconds,4);Byte=[int]$Value})
    $script:ArcadePort.Write([byte[]]@($Value),0,1)
}
function Send-ArcadeCommand([string]$Command,[int]$WaitMs=260) {
    $previous=Get-ArcadeSnapshot
    $minimum=if($null -eq $previous){0}else{[long]$previous.C+1}
    $start=$script:ArcadeWatch.Elapsed.TotalSeconds
    Write-ArcadeByte ([byte][char]$Command)
    Read-ArcadeFor $WaitMs
    $wanted=[int][char]$Command
    $matches=@($script:ArcadeSnapshots | Where-Object {$_.K -eq $wanted -and $_.C -ge $minimum -and $_.Seconds -gt $start})
    if($matches.Count -eq 0){throw ('No fresh Arcade acknowledgement for '+$Command)}
    return $matches[$matches.Count-1]
}
