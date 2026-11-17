$ErrorActionPreference='Stop'
Write-Host 'Tang Nano 9K：RISC-V 小游戏与中文情书'
Write-Host '连接 USB 及 HDMI；选 1 贪吃蛇 / 2 迷宫 / 3 方块 / 4 情书。Esc 退出。'
Write-Host '选择后加载 SRAM，断电丢失，不修改 Flash。'
do {$key=[Console]::ReadKey($true)}until($key.KeyChar -in @('1','2','3','4') -or $key.Key -eq 'Escape')
if($key.Key -eq 'Escape'){return}
$game=[int]::Parse([string]$key.KeyChar)
& python (Join-Path $PSScriptRoot 'program_sram.py')
if($LASTEXITCODE -ne 0){throw 'SRAM load failed; see build/sram-test/result.json.'}
& (Join-Path $PSScriptRoot 'play.ps1') -Game $game
