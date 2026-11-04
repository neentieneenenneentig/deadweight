# -Level <id> starts straight into a level, e.g. -Level valley for the highlands preview.
param([switch]$Touch, [switch]$Editor, [string]$Level = '')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'toolchain.json') -Raw | ConvertFrom-Json
$godot = Join-Path $projectRoot ('.tools/godot/Godot_v' + $manifest.godot_version + '_win64.exe')
if (-not (Test-Path -LiteralPath $godot)) { throw 'Godot is missing. Run tools/setup.ps1 -DesktopOnly.' }
$launchArgs = @('--path', ('"' + $projectRoot + '"'))
if ($Editor) { $launchArgs += '--editor' }
$userArgs = @()
if ($Touch) { $userArgs += '--touch' }
if ($Level) { $userArgs += ('--level=' + $Level) }
if ($userArgs.Count -gt 0) { $launchArgs += @('--') + $userArgs }
# No -WindowStyle Hidden: Windows applies it to the game window itself, so the game ran invisibly.
Start-Process -FilePath $godot -ArgumentList $launchArgs
