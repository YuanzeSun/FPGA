param([string]$PortName='COM6')
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot
try {
    & python scripts/program_sram.py
    if($LASTEXITCODE -ne 0) { throw 'SRAM loading failed. See build/sram-test.' }
    & (Join-Path $PSScriptRoot 'console.ps1') -PortName $PortName
} finally { Pop-Location }
