param([string]$PortName='COM6')
. (Join-Path $PSScriptRoot 'serial_common.ps1')
if(-not ('PongKeyboard' -as [type])) {
    Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class PongKeyboard {
    [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int key);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    public static bool Down(int key) { return (GetAsyncKeyState(key) & 0x8000) != 0; }
}
'@
}
$oldControlC=[Console]::TreatControlCAsInput
try {
    if([Console]::IsInputRedirected){throw 'Run play.ps1 in an interactive Windows terminal.'}
    [Console]::TreatControlCAsInput=$true
    Open-PongPort $PortName
    Write-Host 'HDMI PONG：你控制青色左球拍，粉色右球拍为自动对手。'
    Write-Host 'W/S 或方向键上下移动；空格暂停；R 重开；A 自动对战；Q 查看状态。'
    Write-Host '请保持此窗口为当前窗口，按 Enter 开始。Esc 或 Ctrl+C 退出。'
    do {$startKey=[Console]::ReadKey($true)}until($startKey.Key -eq 'Enter' -or $startKey.Key -eq 'Escape' -or [int]$startKey.KeyChar -eq 3)
    if($startKey.Key -ne 'Enter'){return}
    $terminalWindow=[PongKeyboard]::GetForegroundWindow()
    Write-PongKey 'm'
    Write-PongKey 'n'
    $previousMove='n'
    $lastMoveSent=-1000L
    $lastPrinted=-1000L
    $previousSpace=$false;$previousR=$false;$previousA=$false;$previousQ=$false
    while($true) {
        Read-PongFor 15
        $active=[PongKeyboard]::GetForegroundWindow() -eq $terminalWindow
        $up=$active -and ([PongKeyboard]::Down(0x57) -or [PongKeyboard]::Down(0x26))
        $down=$active -and ([PongKeyboard]::Down(0x53) -or [PongKeyboard]::Down(0x28))
        $move=if($up -and -not $down){'u'}elseif($down -and -not $up){'d'}else{'n'}
        $now=$script:PongWatch.ElapsedMilliseconds
        if($move -ne $previousMove -or ($move -ne 'n' -and $now-$lastMoveSent -ge 80)) {
            Write-PongKey $move;$previousMove=$move;$lastMoveSent=$now
        }
        $space=$active -and [PongKeyboard]::Down(0x20)
        $r=$active -and [PongKeyboard]::Down(0x52)
        $a=$active -and [PongKeyboard]::Down(0x41)
        $q=$active -and [PongKeyboard]::Down(0x51)
        if($space -and -not $previousSpace){Write-PongKey 'p'}
        if($r -and -not $previousR){Write-PongKey 'r'}
        if($a -and -not $previousA){Write-PongKey 'a'}
        if($q -and -not $previousQ){Write-PongKey '?'}
        $previousSpace=$space;$previousR=$r;$previousA=$a;$previousQ=$q
        if($active -and [PongKeyboard]::Down(0x1B)){break}
        $quit=$false
        while([Console]::KeyAvailable) {
            $key=[Console]::ReadKey($true)
            if([int]$key.KeyChar -eq 3){$quit=$true}
        }
        if($quit){break}
        $snapshot=Get-PongSnapshot
        if($null -ne $snapshot -and $now-$lastPrinted -ge 1000) {
            $mode=if($snapshot.A){'自动对战'}else{'手动操作'}
            $pause=if($snapshot.P){'暂停'}else{'运行中'}
            Write-Host ('比分 {0:D2}:{1:D2}  {2} {3}  球拍={4} 球=({5},{6}) 帧={7}' -f [int]$snapshot.L,[int]$snapshot.R,$mode,$pause,$snapshot.PY,$snapshot.X,$snapshot.Y,$snapshot.F)
            $lastPrinted=$now
        }
    }
} finally {
    try {
        if($null -ne $script:PongPort -and $script:PongPort.IsOpen) {
            Write-PongKey 'n'
            [void](Send-PongCommand 'm')
            $final=Send-PongCommand 'a'
            if($final.P -ne 0){[void](Send-PongCommand 'p')}
        }
    } finally {
        Close-PongPort
        [Console]::TreatControlCAsInput=$oldControlC
        Write-Host "`n控制台已关闭，串口已释放。"
    }
}
