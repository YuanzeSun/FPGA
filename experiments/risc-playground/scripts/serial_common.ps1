$ErrorActionPreference='Stop'
function ConvertFrom-RiscLine([string]$Line) {
    $pattern='^RISC G=(?<G>[1234]) F=(?<F>[0-9A-F]{8}) S=(?<S>[0-9A-F]{4}) X=(?<X>[0-9A-F]{4}) Y=(?<Y>[0-9A-F]{4}) T=(?<T>[0-2]) A=(?<A>[01]) P=(?<P>[01]) C=(?<C>[0-9A-F]{8}) K=(?<K>[0-9A-F]{2})$'
    $match=[regex]::Match($Line,$pattern)
    if(-not $match.Success){return $null}
    $sample=[ordered]@{}
    foreach($name in @('G','F','S','T','X','Y','A','P','C','K')) {
        $sample[$name]=[Convert]::ToUInt32($match.Groups[$name].Value,16)
    }
    return [pscustomobject]$sample
}
function Open-RiscPort([string]$PortName='COM6') {
    $script:RiscPort=New-Object System.IO.Ports.SerialPort $PortName,115200,None,8,One
    $script:RiscPort.DtrEnable=$false;$script:RiscPort.RtsEnable=$false
    $script:RiscPort.Handshake=[IO.Ports.Handshake]::None
    $script:RiscPort.Encoding=[Text.Encoding]::ASCII
    $script:RiscPort.ReadTimeout=100;$script:RiscPort.WriteTimeout=1000
    $script:RiscCapture=New-Object Text.StringBuilder
    $script:RiscPending=''
    $script:RiscEvents=New-Object System.Collections.Generic.List[object]
    $script:RiscSnapshots=New-Object System.Collections.Generic.List[object]
    $script:RiscWatch=[Diagnostics.Stopwatch]::StartNew()
    $script:RiscPort.Open();$script:RiscPort.DiscardInBuffer()
}
function Close-RiscPort {
    if($null -ne $script:RiscPort) {
        if($script:RiscPort.IsOpen){$script:RiscPort.Close()}
        $script:RiscPort.Dispose()
    }
}
function Read-RiscFor([int]$Milliseconds) {
    $until=$script:RiscWatch.ElapsedMilliseconds+$Milliseconds
    while($script:RiscWatch.ElapsedMilliseconds -lt $until) {
        $chunk=$script:RiscPort.ReadExisting()
        if($chunk.Length -gt 0) {
            [void]$script:RiscCapture.Append($chunk);$script:RiscPending+=$chunk
            while(($split=$script:RiscPending.IndexOf("`n")) -ge 0) {
                $line=$script:RiscPending.Substring(0,$split).TrimEnd("`r")
                $script:RiscPending=$script:RiscPending.Substring($split+1)
                $sample=ConvertFrom-RiscLine $line
                if($null -ne $sample) {
                    $sample | Add-Member -NotePropertyName Seconds -NotePropertyValue ([Math]::Round($script:RiscWatch.Elapsed.TotalSeconds,4))
                    $script:RiscSnapshots.Add($sample)
                }
            }
        }
        Start-Sleep -Milliseconds 5
    }
}
function Get-RiscSnapshot {
    if($script:RiscSnapshots.Count -eq 0){return $null}
    return $script:RiscSnapshots[$script:RiscSnapshots.Count-1]
}
function Write-RiscByte([byte]$Value) {
    $script:RiscEvents.Add([pscustomobject]@{Seconds=[Math]::Round($script:RiscWatch.Elapsed.TotalSeconds,4);Byte=[int]$Value})
    $script:RiscPort.Write([byte[]]@($Value),0,1)
}
function Send-RiscCommand([string]$Command,[int]$WaitMs=650) {
    $previous=Get-RiscSnapshot
    $minimum=if($null -eq $previous){0}else{[long]$previous.C+1}
    $start=$script:RiscWatch.Elapsed.TotalSeconds
    Write-RiscByte ([byte][char]$Command)
    Read-RiscFor $WaitMs
    $wanted=[int][char]$Command
    $matches=@($script:RiscSnapshots | Where-Object {$_.K -eq $wanted -and $_.C -ge $minimum -and $_.Seconds -gt $start})
    if($matches.Count -eq 0){throw ('No fresh Risc acknowledgement for '+$Command)}
    return $matches[$matches.Count-1]
}
