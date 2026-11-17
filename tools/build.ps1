param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('led-blink','led-chaser','picorv32-uart','picorv32-full','picorv32-max','simple-rv32i','rv32i-algorithms','hdmi-pong','hdmi-arcade','risc-playground')]
    [string]$Project,
    [ValidateSet('base','720p60','1080p30','1080p45','all')]
    [string]$Mode='base'
)
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
$configPath=Join-Path $repo 'config/local.psd1'
if(-not (Test-Path -LiteralPath $configPath)){$configPath=Join-Path $repo 'config/local.example.psd1'}
$cfg=Import-PowerShellDataFile $configPath
$directory=Join-Path $repo ('experiments/'+$Project)
if($cfg.GowinShell){$env:GOWIN_SH=$cfg.GowinShell}
$env:GOWIN_PROGRAMMER=$cfg.ProgrammerCli
$env:FPGA_PYTHON=$cfg.LinuxPython
Push-Location $directory
try {
    if($Project -in @('hdmi-pong','hdmi-arcade','risc-playground')) {
        if(-not (Test-Path -LiteralPath $env:GOWIN_SH -PathType Leaf)){throw 'Set GowinShell in config/local.psd1 to gw_sh.exe'}
        & $cfg.WindowsPython 'scripts/build.py'
        if($LASTEXITCODE -ne 0){throw 'Base build failed'}
        if($Project -eq 'risc-playground' -and $Mode -ne 'base') {
            & $cfg.WindowsPython 'scripts/build_hd.py' '--mode' $Mode
            if($LASTEXITCODE -ne 0){throw 'HD build failed'}
        }
    } else {
        $linuxDirectory=(& wsl.exe -d $cfg.WslDistro --exec wslpath -u $directory).Trim()
        if($LASTEXITCODE -ne 0){throw 'Cannot resolve the WSL project directory'}
        $python=if($Project -in @('simple-rv32i','rv32i-algorithms')){$cfg.LinuxPython}else{'python3'}
        & wsl.exe -d $cfg.WslDistro --cd $linuxDirectory --exec $python scripts/build.py
        if($LASTEXITCODE -ne 0){throw 'WSL build failed'}
    }
} finally {Pop-Location}
