$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$checked=@()
foreach($file in Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.ps1') {
    $tokens=$null;$errors=$null
    $ast=[Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
    if($errors.Count -ne 0){throw ($errors | Out-String)}
    $checked+=$file.Name
    if($file.Name -eq 'play.ps1') {
        $bindings=$ast.FindAll({param($node) $node -is [Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'Add-Type'},$true)
        Add-Type $bindings[0].CommandElements[1].Value
    }
}
. (Join-Path $PSScriptRoot 'serial_common.ps1')
$count=0;$games=@{}
foreach($line in Get-Content -LiteralPath (Join-Path $root 'build/system-sim.log')) {
    if($line.StartsWith('UART: ')) {
        $parsed=ConvertFrom-ArcadeLine $line.Substring(6).TrimEnd()
        if($null -eq $parsed){throw ('Cannot parse actual simulated UART: '+$line)}
        if($parsed.L -gt 3 -or $parsed.T -gt 2 -or $parsed.PX -gt 640){throw 'Telemetry numeric parsing failed'}
        $games[[int]$parsed.G]=$true;$count++
    }
}
if($count -lt 3 -or $games.Count -ne 3){throw 'Missing simulated telemetry for game modes'}
if($null -ne (ConvertFrom-ArcadeLine 'ARCADE invalid')){throw 'Invalid telemetry accepted'}
$result=@{OverallResult='PASS';PowerShellScripts=$checked;NativeKeyboardBindingsCompiled=$true;SimulatedUARTLinesParsed=$count;GameModesParsed=$games.Count;SerialPortOpened=$false}
$json=$result | ConvertTo-Json -Depth 5
[IO.File]::WriteAllText((Join-Path $root 'build/windows-script-check.json'),$json)
Write-Host $json
