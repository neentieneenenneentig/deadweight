# Installs the release APK from tools/build.ps1 on a phone connected with USB debugging.
#   powershell -ExecutionPolicy Bypass -File tools/install-android.ps1 [-Serial <adb serial>] [-Apk <path>]
# The APK is signed with the upload key. A copy installed from Google Play is signed with Google's
# app signing key instead, so uninstall one before installing the other.
param([string]$Serial, [string]$Apk)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$adb = Join-Path $projectRoot '.tools/android-sdk/platform-tools/adb.exe'
if (-not (Test-Path -LiteralPath $adb)) { throw 'ADB is missing. Run tools/setup.ps1.' }
if (-not $Apk) {
    $release = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'release.json') -Raw | ConvertFrom-Json
    $Apk = Join-Path $projectRoot ('builds/DEADWEIGHT-' + $release.version + '.apk')
}
if (-not (Test-Path -LiteralPath $Apk)) { throw "APK is missing ($Apk). Run tools/build.ps1 -Target AndroidApk." }
$adbArgs = @()
if ($Serial) { $adbArgs += @('-s', $Serial) }
& $adb @adbArgs install -r $Apk
if ($LASTEXITCODE -ne 0) { throw 'ADB install failed. Enable USB debugging, approve this computer on the phone, and uninstall any Play Store copy first.' }
Write-Host "Installed $Apk"
