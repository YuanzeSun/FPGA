$ErrorActionPreference='Stop'
function Open-LabPort([string]$PortName='COM6') {
    $script:LabPort=New-Object System.IO.Ports.SerialPort $PortName,115200,None,8,One
    $script:LabPort.Handshake=[IO.Ports.Handshake]::None
    $script:LabPort.DtrEnable=$false; $script:LabPort.RtsEnable=$false
    $script:LabPort.Encoding=[Text.Encoding]::ASCII; $script:LabPort.WriteTimeout=1000
    $script:LabEvents=New-Object 'System.Collections.Generic.List[object]'
    $script:LabPort.Open()
    $warm=[Diagnostics.Stopwatch]::StartNew()
    while($warm.ElapsedMilliseconds -lt 1200) {
        $data=$script:LabPort.ReadExisting()
        if($data.Length) { $script:LabEvents.Add([ordered]@{warmup=$data}) }
        Start-Sleep -Milliseconds 10
    }
    $script:LabPort.DiscardInBuffer()
}
function Close-LabPort {
    if($null -ne $script:LabPort) {
        if($script:LabPort.IsOpen) { $script:LabPort.Close() }
        $script:LabPort.Dispose()
    }
}
function Invoke-LabCommand([string]$Command,[int]$TimeoutMs=10000) {
    if($Command -match '[^\x08\x20-\x7E]') { throw 'Use ASCII commands and integers.' }
    $script:LabPort.DiscardInBuffer()
    foreach($character in ($Command+"`n").ToCharArray()) {
        $script:LabPort.Write([string]$character)
        Start-Sleep -Milliseconds 2
    }
    $watch=[Diagnostics.Stopwatch]::StartNew(); $answer=''
    while($watch.ElapsedMilliseconds -lt $TimeoutMs) {
        $answer+=$script:LabPort.ReadExisting()
        if($answer -match '(?m)^READY\r?$') {
            $body=($answer -replace '(?m)^READY\r?\n?','').Replace("`r",'').Trim()
            $script:LabEvents.Add([ordered]@{command=$Command;response=$body})
            return $body
        }
        Start-Sleep -Milliseconds 5
    }
    throw "Timed out waiting for board READY: $Command ; received: $answer"
}
