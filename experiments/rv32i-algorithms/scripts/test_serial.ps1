param([string]$PortName='COM6')
. (Join-Path $PSScriptRoot 'serial_lab.ps1')
$projectRoot=Split-Path -Parent $PSScriptRoot
$records=Join-Path $projectRoot 'build\serial-test'
New-Item -ItemType Directory -Path $records -Force | Out-Null
$vectors=Get-Content -LiteralPath (Join-Path $projectRoot 'build\hardware-vectors.json') -Raw | ConvertFrom-Json
$checks=New-Object 'System.Collections.Generic.List[object]'
$result=[ordered]@{result='FAIL';date='2026-11-15';port=$PortName;serial_port_closed=$false;cases=$checks}
try {
    Open-LabPort $PortName
    $info=Invoke-LabCommand 'info'
    if($info -notmatch '^CPU=SimpleRV32I ISA=RV32I CLOCK=13500000 ROM=16384 RAM=1024$') { throw 'Unexpected firmware identity' }
    foreach($vector in $vectors) {
        $answer=Invoke-LabCommand $vector.command
        foreach($pattern in $vector.patterns) {
            if(-not [regex]::IsMatch($answer,$pattern,[Text.RegularExpressions.RegexOptions]::Multiline)) {
                throw "Answer mismatch for $($vector.command): $answer ; expected $pattern"
            }
        }
        if($vector.command.StartsWith('maxsub ')) {
            $nums=@($vector.command.Substring(7).Split(' ') | ForEach-Object { [int]$_ })
            $match=[regex]::Match($answer,'MAXSUB sum=(-?\d+) left=(\d+) right=(\d+)')
            $left=[int]$match.Groups[2].Value; $right=[int]$match.Groups[3].Value
            if($left -gt $right -or $right -ge $nums.Count) { throw 'Invalid max-subarray bounds' }
            $sum=0; for($i=$left;$i -le $right;$i++) { $sum+=$nums[$i] }
            if($sum -ne [int]$match.Groups[1].Value) { throw 'Subarray does not match returned sum' }
        }
        $checks.Add([ordered]@{command=$vector.command;response=$answer;result='PASS'})
        Write-Output ('PASS: '+$vector.command)
    }
    $result.result='ALGORITHMS_ON_CUSTOM_CPU_HARDWARE_PASS'
    $result.case_count=$checks.Count
} catch { $result.error=$_.Exception.Message; throw }
finally {
    Close-LabPort; $result.serial_port_closed=$true
    $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $records 'result.json') -Encoding utf8
    $script:LabEvents | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $records 'events.json') -Encoding utf8
    Write-Output ($result | ConvertTo-Json -Depth 8)
}
