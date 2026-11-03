param([switch]$Touch, [switch]$Editor)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'toolchain.json') -Raw | ConvertFrom-Json
$godot = Join-Path $projectRoot ('.tools/godot/Godot_v' + $manifest.godot_version + '_win64.exe')
if (-not (Test-Path -LiteralPath $godot)) { throw 'Godot is missing. Run tools/setup.ps1 -DesktopOnly.' }
$launchArgs = @('--path', ('"' + $projectRoot + '"'))
if ($Editor) { $launchArgs += '--editor' }
if ($Touch) { $launchArgs += @('--','--touch') }
Start-Process -FilePath $godot -ArgumentList $launchArgs -WindowStyle Hidden
