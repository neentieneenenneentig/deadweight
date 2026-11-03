$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$toolRoot = Join-Path $projectRoot '.tools'
$java = Get-ChildItem -LiteralPath (Join-Path $toolRoot 'java') -Directory | Select-Object -First 1
if (-not $java) { throw 'Local JDK is missing. Run tools/setup.ps1.' }
$sdkRoot = Join-Path $toolRoot 'android-sdk'
if (-not (Test-Path -LiteralPath (Join-Path $sdkRoot 'platform-tools/adb.exe'))) { throw 'Local Android SDK is incomplete. Run tools/setup.ps1.' }
$settingsRoot = Join-Path $toolRoot 'godot/editor_data'
New-Item -ItemType Directory -Force -Path $settingsRoot | Out-Null
$settingsPath = Join-Path $settingsRoot 'editor_settings-4.7.tres'
$settings = "[gd_resource type=`"EditorSettings`" format=3]`n`n[resource]`n"
if (Test-Path -LiteralPath $settingsPath) { $settings = Get-Content -LiteralPath $settingsPath -Raw }
foreach ($item in @(
    @{ key = 'export/android/java_sdk_path'; value = $java.FullName.Replace('\','/') },
    @{ key = 'export/android/android_sdk_path'; value = $sdkRoot.Replace('\','/') }
)) {
    $line = $item.key + ' = "' + $item.value + '"'
    $pattern = '(?m)^' + [regex]::Escape($item.key) + ' = .*\r?$'
    if ([regex]::IsMatch($settings, $pattern)) { $settings = [regex]::Replace($settings, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $line }) }
    else { $settings = $settings.TrimEnd() + "`n" + $line + "`n" }
}
[IO.File]::WriteAllText($settingsPath, $settings, (New-Object Text.UTF8Encoding($false)))
$keystore = Join-Path $toolRoot 'debug.keystore'
if (-not (Test-Path -LiteralPath $keystore)) {
    & (Join-Path $java.FullName 'bin/keytool.exe') -genkeypair -keystore $keystore -alias androiddebugkey -storepass android -keypass android -dname 'CN=Android Debug,O=Android,C=US' -keyalg RSA -keysize 2048 -validity 10000
    if ($LASTEXITCODE -ne 0) { throw 'Debug keystore generation failed' }
}
Write-Host 'Android paths configured in the project-local Godot profile.'
