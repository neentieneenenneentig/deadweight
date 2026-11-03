param([string]$Serial)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$adb = Join-Path $projectRoot '.tools/android-sdk/platform-tools/adb.exe'
$apk = Join-Path $projectRoot 'builds/DEADWEIGHT-android-debug.apk'
if (-not (Test-Path -LiteralPath $adb)) { throw 'ADB is missing. Run tools/setup.ps1.' }
if (-not (Test-Path -LiteralPath $apk)) { throw 'APK is missing. Run tools/build.ps1 -Target Android.' }
$adbArgs = @()
if ($Serial) { $adbArgs += @('-s', $Serial) }
& $adb @adbArgs install -r $apk
if ($LASTEXITCODE -ne 0) { throw 'ADB install failed. Enable USB debugging and approve this computer on the phone.' }
