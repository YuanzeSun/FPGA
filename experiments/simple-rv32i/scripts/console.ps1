param([string]$PortName='COM6',[int]$BaudRate=115200)
$ErrorActionPreference='Stop'
$port=New-Object System.IO.Ports.SerialPort $PortName,$BaudRate,None,8,One
$port.Handshake=[System.IO.Ports.Handshake]::None
$port.DtrEnable=$false; $port.RtsEnable=$false
$port.Encoding=[Text.Encoding]::ASCII
$port.WriteTimeout=1000
try {
    $port.Open()
    Write-Host 'SimpleRV32I: p = ping, ? = status, Esc = exit. No Enter needed.'
    while($true) {
        $text=$port.ReadExisting()
        if($text.Length) { [Console]::Write($text) }
        if([Console]::KeyAvailable) {
            $key=[Console]::ReadKey($true)
            if($key.Key -eq [ConsoleKey]::Escape) { break }
            if($key.KeyChar -ne [char]0) { $port.Write([string]$key.KeyChar) }
        }
        Start-Sleep -Milliseconds 10
    }
} finally {
    if($port.IsOpen) { $port.Close() }; $port.Dispose()
}
