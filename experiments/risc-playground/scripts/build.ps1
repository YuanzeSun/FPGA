$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
    & python scripts/generate_assets.py
    if($LASTEXITCODE -ne 0){throw 'Asset generation failed'}
    & python scripts/build.py
    if($LASTEXITCODE -ne 0){throw 'Build failed'}
} finally {Pop-Location}
