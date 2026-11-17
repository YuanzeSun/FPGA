param([ValidateSet('720p60','1080p30','1080p45')][string]$Mode='720p60')
$ErrorActionPreference='Stop'
Write-Host ('RISC-V HDMI: '+$Mode)
Write-Host 'Close other serial controllers first. Select 1 Snake / 2 Maze / 3 Blocks / 4 Letter.'
Write-Host 'Loads SRAM only. Esc exits.'
do {$key=[Console]::ReadKey($true)}until($key.KeyChar -in @('1','2','3','4') -or $key.Key -eq 'Escape')
if($key.Key -eq 'Escape'){return}
$game=[int]::Parse([string]$key.KeyChar)
& python (Join-Path $PSScriptRoot 'program_hd.py') $Mode
if($LASTEXITCODE -ne 0){throw ('SRAM load failed; see build/hd/'+$Mode+'/sram-test/result.json')}
& (Join-Path $PSScriptRoot 'play.ps1') -Game $game
