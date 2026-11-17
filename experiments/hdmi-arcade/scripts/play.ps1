param([ValidateRange(1,3)][int]$Game=1,[string]$PortName='COM6')
. (Join-Path $PSScriptRoot 'serial_common.ps1')
if(-not ('ArcadeKeyboard' -as [type])) {
    Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class ArcadeKeyboard {
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
    Open-ArcadePort $PortName
    Read-ArcadeFor 1200
    [void](Send-ArcadeCommand ([string]$Game))
    Write-Host 'HDMI 游戏合集：1 接球躲避；2 打砖块；3 太空射击。'
    Write-Host '左右方向键或 A/D 移动；F/J 发射；空格暂停；R 重开。'
    Write-Host '1/2/3 切换并重开游戏；Tab 自动演示；Q 状态；Esc 或 Ctrl+C 退出。'
    Write-Host '按 Enter 切到手动开始，保持此终端窗口为当前窗口。'
    do {$key=[Console]::ReadKey($true)}until($key.Key -eq 'Enter' -or $key.Key -eq 'Escape' -or [int]$key.KeyChar -eq 3)
    if($key.Key -ne 'Enter'){return}
    $terminalWindow=[ArcadeKeyboard]::GetForegroundWindow()
    [void](Send-ArcadeCommand 'm')
    $lastBits=0;$lastSent=-1000L;$lastPrinted=-1000L
    $edges=@{}
    $commands=@{0x20='p';0x52='r';0x09='a';0x51='?';0x31='1';0x32='2';0x33='3'}
    while($true) {
        Read-ArcadeFor 15
        $active=[ArcadeKeyboard]::GetForegroundWindow() -eq $terminalWindow
        $left=$active -and ([ArcadeKeyboard]::Down(0x25) -or [ArcadeKeyboard]::Down(0x41))
        $right=$active -and ([ArcadeKeyboard]::Down(0x27) -or [ArcadeKeyboard]::Down(0x44))
        $fire=$active -and ([ArcadeKeyboard]::Down(0x46) -or [ArcadeKeyboard]::Down(0x4A))
        $bits=0
        if($left -and -not $right){$bits=$bits -bor 1}
        if($right -and -not $left){$bits=$bits -bor 2}
        if($fire){$bits=$bits -bor 4}
        $now=$script:ArcadeWatch.ElapsedMilliseconds
        if($bits -ne $lastBits -or ($bits -ne 0 -and $now-$lastSent -ge 80)) {
            Write-ArcadeByte ([byte](0x80 -bor $bits));$lastBits=$bits;$lastSent=$now
        }
        foreach($vk in $commands.Keys) {
            $down=$active -and [ArcadeKeyboard]::Down([int]$vk)
            if($down -and -not $edges[$vk]){Write-ArcadeByte ([byte][char]$commands[$vk]);$lastSent=-1000L}
            $edges[$vk]=$down
        }
        if($active -and [ArcadeKeyboard]::Down(0x1B)){break}
        $quit=$false
        while([Console]::KeyAvailable){$key=[Console]::ReadKey($true);if([int]$key.KeyChar -eq 3){$quit=$true}}
        if($quit){break}
        $snapshot=Get-ArcadeSnapshot
        if($null -ne $snapshot -and $now-$lastPrinted -ge 1000) {
            $mode=if($snapshot.A){'自动演示'}else{'手动'}
            $state=if($snapshot.P){'暂停'}elseif($snapshot.T -eq 1){'游戏结束'}elseif($snapshot.T -eq 2){'通关'}else{'运行中'}
            Write-Host ('游戏 {0}  分数 {1:D2}  生命 {2}  {3} {4}  位置 {5}  帧 {6}' -f $snapshot.G,[int]$snapshot.S,$snapshot.L,$mode,$state,$snapshot.PX,$snapshot.F)
            $lastPrinted=$now
        }
    }
} finally {
    try {
        if($null -ne $script:ArcadePort -and $script:ArcadePort.IsOpen) {
            Write-ArcadeByte 0x80
            [void](Send-ArcadeCommand 'm')
            $final=Send-ArcadeCommand 'a'
            if($final.P -ne 0){[void](Send-ArcadeCommand 'p')}
        }
    } finally {
        Close-ArcadePort;[Console]::TreatControlCAsInput=$oldControlC
        Write-Host "`n控制台已退出，串口已释放。"
    }
}
