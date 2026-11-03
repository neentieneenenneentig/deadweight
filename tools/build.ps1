param([ValidateSet('All','Windows','Android')][string]$Target = 'All', [switch]$Setup)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$toolRoot = Join-Path $projectRoot '.tools'
$manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'toolchain.json') -Raw | ConvertFrom-Json
$editor = Join-Path $toolRoot ('godot/Godot_v' + $manifest.godot_version + '_win64_console.exe')
if ($Setup) { & (Join-Path $PSScriptRoot 'setup.ps1') -DesktopOnly:($Target -eq 'Windows') }
if (-not (Test-Path -LiteralPath $editor)) { throw 'Godot is missing. Run tools/setup.ps1 or add -Setup.' }
$buildRoot = Join-Path $projectRoot 'builds'
New-Item -ItemType Directory -Force -Path $buildRoot | Out-Null

function Invoke-GodotBuild([string[]]$BuildArgs, [string]$LogName) {
    $log = Join-Path $buildRoot $LogName
    # Use a file rather than piping native stderr through PowerShell's error handler.
    $process = Start-Process -FilePath $editor -ArgumentList $BuildArgs -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $log -RedirectStandardError ($log + '.stderr')
    $output = (Get-Content -LiteralPath $log -Raw) + (Get-Content -LiteralPath ($log + '.stderr') -Raw)
    Write-Host $output
    if ($process.ExitCode -ne 0 -or $output -match 'SCRIPT ERROR:|Parse Error:|ERROR:') { throw "Godot failed; see $log" }
}

$quotedRoot = '"' + $projectRoot + '"'
Invoke-GodotBuild @('--headless','--editor','--path',$quotedRoot,'--import') 'import.log'
if ($Target -in @('All','Windows')) {
    $windowsDir = Join-Path $buildRoot 'windows'
    New-Item -ItemType Directory -Force -Path $windowsDir | Out-Null
    $windowsPath = Join-Path $windowsDir 'DEADWEIGHT.exe'
    Invoke-GodotBuild @('--headless','--path',$quotedRoot,'--export-release','"Windows Desktop"',('"' + $windowsPath + '"')) 'windows-export.log'
    Copy-Item -LiteralPath (Join-Path $projectRoot 'THIRD_PARTY_NOTICES.txt') -Destination $windowsDir
    Compress-Archive -LiteralPath $windowsPath,(Join-Path $windowsDir 'THIRD_PARTY_NOTICES.txt') -DestinationPath (Join-Path $buildRoot 'DEADWEIGHT-windows.zip') -Force
}
if ($Target -in @('All','Android')) {
    & (Join-Path $PSScriptRoot 'configure-android.ps1')
    $java = Get-ChildItem -LiteralPath (Join-Path $toolRoot 'java') -Directory | Select-Object -First 1
    $env:JAVA_HOME = $java.FullName
    $env:ANDROID_HOME = Join-Path $toolRoot 'android-sdk'
    $env:GODOT_ANDROID_KEYSTORE_DEBUG_PATH = Join-Path $toolRoot 'debug.keystore'
    $env:GODOT_ANDROID_KEYSTORE_DEBUG_USER = 'androiddebugkey'
    $env:GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD = 'android'
    $apkPath = Join-Path $buildRoot 'DEADWEIGHT-android-debug.apk'
    Invoke-GodotBuild @('--headless','--path',$quotedRoot,'--export-debug','Android',('"' + $apkPath + '"')) 'android-export.log'
    & (Join-Path $env:ANDROID_HOME 'build-tools/35.0.1/apksigner.bat') verify --verbose $apkPath
    if ($LASTEXITCODE -ne 0) { throw 'APK signature verification failed' }
}
Get-ChildItem -LiteralPath $buildRoot -File | Where-Object { $_.Extension -in @('.apk','.zip') } | Get-FileHash -Algorithm SHA256 | Format-Table -AutoSize
