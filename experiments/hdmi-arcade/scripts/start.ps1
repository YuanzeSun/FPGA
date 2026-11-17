$ErrorActionPreference='Stop'
Write-Host 'Tang Nano 9K HDMI 游戏合集'
Write-Host '请连接开发板 USB 和显示器 HDMI，再选择游戏。'
Write-Host '1 接球躲避（简单） / 2 打砖块（中等） / 3 太空射击（复杂）'
Write-Host '选择后会加载 SRAM；断电即丢失，Flash 不变。Esc 退出。'
do {$key=[Console]::ReadKey($true)}until($key.KeyChar -in @('1','2','3') -or $key.Key -eq 'Escape')
if($key.Key -eq 'Escape'){return}
$game=[int]::Parse([string]$key.KeyChar)
& python (Join-Path $PSScriptRoot 'program_sram.py')
if($LASTEXITCODE -ne 0){throw 'SRAM load failed. See build/sram-test/result.json.'}
& (Join-Path $PSScriptRoot 'play.ps1') -Game $game
