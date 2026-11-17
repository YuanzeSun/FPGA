param([ValidateRange(1,4)][int]$Game=1,[string]$PortName='COM6')
. (Join-Path $PSScriptRoot 'serial_common.ps1')
if(-not ('RiscKeyboard' -as [type])) {
    Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class RiscKeyboard {
    [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int key);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    public static bool Down(int key) { return (GetAsyncKeyState(key) & 0x8000) != 0; }
}
'@
}
$oldControlC=[Console]::TreatControlCAsInput
try {
    if([Console]::IsInputRedirected){throw 'Run in an interactive Windows terminal.'}
    [Console]::TreatControlCAsInput=$true
    Open-RiscPort $PortName
    Read-RiscFor 1200
    [void](Send-RiscCommand ([string]$Game))
    Write-Host 'RISC-V 游戏：1 贪吃蛇；2 迷宫；3 方块消除；4 情书/告白。'
    Write-Host '方向键/WASD 移动；向上或 K 旋转方块；F/J 硬降、拆信或跳过逐字显示。'
    Write-Host '空格暂停；R 重开；1/2/3/4 切换；Tab 重开自动演示；Q 状态。'
    Write-Host '按 Enter 切到手动开始。保持终端焦点；Esc 或 Ctrl+C 退出。'
    do {$key=[Console]::ReadKey($true)}until($key.Key -eq 'Enter' -or $key.Key -eq 'Escape' -or [int]$key.KeyChar -eq 3)
    if($key.Key -ne 'Enter'){return}
    $terminalWindow=[RiscKeyboard]::GetForegroundWindow()
    [void](Send-RiscCommand 'm')
    $lastBits=0;$lastSent=-1000L;$lastPrinted=-1000L
    $edges=@{}
    $commands=@{0x20='p';0x52='r';0x09='a';0x51='?';0x31='1';0x32='2';0x33='3';0x34='4'}
    while($true) {
        Read-RiscFor 15
        $active=[RiscKeyboard]::GetForegroundWindow() -eq $terminalWindow
        $left=$active -and ([RiscKeyboard]::Down(0x25) -or [RiscKeyboard]::Down(0x41))
        $right=$active -and ([RiscKeyboard]::Down(0x27) -or [RiscKeyboard]::Down(0x44))
        $fire=$active -and ([RiscKeyboard]::Down(0x46) -or [RiscKeyboard]::Down(0x4A))
        $up=$active -and ([RiscKeyboard]::Down(0x26) -or [RiscKeyboard]::Down(0x57))
        $down=$active -and ([RiscKeyboard]::Down(0x28) -or [RiscKeyboard]::Down(0x53))
        $rotate=$active -and [RiscKeyboard]::Down(0x4B)
        $bits=0
        if($left -and -not $right){$bits=$bits -bor 1}
        if($right -and -not $left){$bits=$bits -bor 2}
        if($up -and -not $down){$bits=$bits -bor 4}
        if($down -and -not $up){$bits=$bits -bor 8}
        if($fire){$bits=$bits -bor 16}
        if($rotate){$bits=$bits -bor 32}
        $now=$script:RiscWatch.ElapsedMilliseconds
        if($bits -ne $lastBits -or ($bits -ne 0 -and $now-$lastSent -ge 80)) {
            Write-RiscByte ([byte](0x80 -bor $bits));$lastBits=$bits;$lastSent=$now
        }
        foreach($vk in $commands.Keys) {
            $down=$active -and [RiscKeyboard]::Down([int]$vk)
            if($down -and -not $edges[$vk]){Write-RiscByte ([byte][char]$commands[$vk]);$lastSent=-1000L}
            $edges[$vk]=$down
        }
        if($active -and [RiscKeyboard]::Down(0x1B)){break}
        $quit=$false
        while([Console]::KeyAvailable){$key=[Console]::ReadKey($true);if([int]$key.KeyChar -eq 3){$quit=$true}}
        if($quit){break}
        $snapshot=Get-RiscSnapshot
        if($null -ne $snapshot -and $now-$lastPrinted -ge 1000) {
            $mode=if($snapshot.A){'自动演示'}else{'手动'}
            $state=if($snapshot.G -eq 4){'情书'}elseif($snapshot.P){'暂停'}elseif($snapshot.T -eq 1){'游戏结束'}elseif($snapshot.T -eq 2){'通关'}else{'运行中'}
            Write-Host ('程序 {0}  分数/字数 {1}  {2} {3}  坐标 ({4},{5}) 帧 {6}' -f $snapshot.G,$snapshot.S,$mode,$state,$snapshot.X,$snapshot.Y,$snapshot.F)
            $lastPrinted=$now
        }
    }
} finally {
    try {
        if($null -ne $script:RiscPort -and $script:RiscPort.IsOpen) {
            Write-RiscByte 0x80
            [void](Send-RiscCommand 'm')
            $final=Send-RiscCommand 'a'
            if($final.P -ne 0){[void](Send-RiscCommand 'p')}
        }
    } finally {
        Close-RiscPort;[Console]::TreatControlCAsInput=$oldControlC
        Write-Host "`n控制台已退出，串口已释放。"
    }
}
