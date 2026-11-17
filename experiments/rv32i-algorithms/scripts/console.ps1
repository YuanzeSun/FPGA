param([string]$PortName='COM6')
. (Join-Path $PSScriptRoot 'serial_lab.ps1')
$demo=@('sort 9 -2 5 1','find 5 1 3 5 7','maxsub -2 1 -3 4 -1 2 1 -5 4','gcd 48 18')
try {
    Open-LabPort $PortName
    Write-Host (Invoke-LabCommand 'info')
    Write-Host 'Enter a command and press Enter. help = commands, demo = four examples, exit = close.'
    while($true) {
        $command=Read-Host 'RV32I'
        if($command -eq 'exit') { break }
        if([string]::IsNullOrWhiteSpace($command)) { continue }
        if($command -eq 'demo') {
            foreach($example in $demo) { Write-Host ('> '+$example);Write-Host (Invoke-LabCommand $example) }
        } else { Write-Host (Invoke-LabCommand $command) }
    }
} finally { Close-LabPort }
