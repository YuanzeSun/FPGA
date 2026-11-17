param([string]$PortName='COM6', [int]$BaudRate=115200)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
$records=Join-Path $projectRoot 'build\serial-test'
New-Item -ItemType Directory -Path $records -Force | Out-Null
$port=New-Object System.IO.Ports.SerialPort $PortName,$BaudRate,None,8,One
$port.Handshake=[System.IO.Ports.Handshake]::None
$port.DtrEnable=$false; $port.RtsEnable=$false
$port.Encoding=[Text.Encoding]::ASCII
$port.WriteTimeout=1000
$capture=New-Object Text.StringBuilder
$events=New-Object 'System.Collections.Generic.List[object]'
$watch=[Diagnostics.Stopwatch]::StartNew()
$result=[ordered]@{result='FAIL';port=$PortName;baud=$BaudRate;serial_port_closed=$false;physical_led_observation=$false}
function Read-For([int]$ms) {
    $end=$watch.ElapsedMilliseconds+$ms
    while($watch.ElapsedMilliseconds -lt $end) {
        $chunk=$port.ReadExisting()
        if($chunk.Length) {
            [void]$capture.Append($chunk)
            $events.Add([ordered]@{seconds=$watch.Elapsed.TotalSeconds;rx=$chunk})
        }
        Start-Sleep -Milliseconds 10
    }
}
function Send-Key([string]$key) {
    $start=$capture.Length
    $events.Add([ordered]@{seconds=$watch.Elapsed.TotalSeconds;tx=$key})
    $port.Write($key); Read-For 350
    return $capture.ToString().Substring($start)
}
function Query-State {
    $when=$watch.Elapsed.TotalSeconds
    $text=Send-Key '?'
    $m=[regex]::Match($text,'CPU=SimpleRV32I SELF=PASS COUNT=([0-9A-F]{8}) GPIO=([0-9A-F]{8}) TICKS=([0-9A-F]{8})')
    if(!$m.Success) { throw 'Missing fresh CPU status reply' }
    return [ordered]@{seconds=$when;count=[Convert]::ToUInt32($m.Groups[1].Value,16);gpio=[Convert]::ToUInt32($m.Groups[2].Value,16);ticks=[Convert]::ToUInt32($m.Groups[3].Value,16)}
}
try {
    $port.Open(); Read-For 1200
    $challenges=@(65..90 | Get-Random -Count 2)
    foreach($code in $challenges) {
        $text=Send-Key ([string][char]$code)
        if($text -notmatch ('RX='+('{0:X8}' -f $code))) { throw 'Fresh challenge failed' }
    }
    if((Send-Key 'p') -notmatch 'PONG') { throw 'CPU ping failed' }
    $first=Query-State
    Read-For 2200
    $second=Query-State
    $delta=([uint64]$second.ticks+4294967296-[uint64]$first.ticks)%4294967296
    $hz=$delta/($second.seconds-$first.seconds)
    if($second.count -le $first.count -or $hz -lt 12500000 -or $hz -gt 14500000) { throw 'CPU timer/count not progressing correctly' }
    $gpio=[uint32]$second.gpio
    if($gpio -eq 0 -or $gpio -gt 32 -or ($gpio -band ($gpio-1)) -ne 0) { throw 'Unexpected GPIO pattern' }
    $result.result='HARDWARE_CPU_UART_AND_TIMER_PASS'
    $result.selftest='000000FF'
    $result.challenge_codes=$challenges
    $result.fresh_challenge_passed=$true
    $result.ping_passed=$true
    $result.snapshots=@($first,$second)
    $result.estimated_cpu_hz=[Math]::Round($hz)
} finally {
    if($port.IsOpen) { $port.Close() }; $port.Dispose()
    $result.serial_port_closed=$true
    $capture.ToString() | Set-Content -LiteralPath (Join-Path $records 'capture.txt') -Encoding utf8
    $events | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $records 'events.json') -Encoding utf8
    $result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $records 'result.json') -Encoding utf8
    $result | ConvertTo-Json -Depth 5
}
