<#
.SYNOPSIS
  Builds signed, versioned DEADWEIGHT release artifacts into builds/.
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools/build.ps1 -Target All
  powershell -ExecutionPolicy Bypass -File tools/build.ps1 -Target Windows,Linux -SkipTests
.NOTES
  - Name, version, version code, package id and company come from tools/release.json. They are
    stamped into export_presets.cfg for the duration of the build; the original file is always
    restored byte for byte.
  - application/config/version in project.godot must equal release.json "version".
  - Android release builds are signed with the upload key from tools/make-upload-key.ps1.
  - Outputs: builds/DEADWEIGHT-<version>-windows.zip, -linux.zip, DEADWEIGHT-<version>.apk,
    DEADWEIGHT-<version>.aab, SHA256SUMS.txt, BUILD_INFO.txt, and logs in builds/logs/.
#>
param(
    [ValidateSet('Windows', 'Linux', 'AndroidApk', 'AndroidAab', 'All')][string[]]$Target = @('All'),
    [switch]$SkipTests,
    [switch]$SkipImport
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$toolRoot = Join-Path $projectRoot '.tools'
$manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'toolchain.json') -Raw | ConvertFrom-Json
$release = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'release.json') -Raw | ConvertFrom-Json
$editor = Join-Path $toolRoot ('godot/Godot_v' + $manifest.godot_version + '_win64_console.exe')
if (-not (Test-Path -LiteralPath $editor)) { throw 'Godot is missing. Run tools/setup.ps1 first.' }
$buildRoot = Join-Path $projectRoot 'builds'
$logRoot = Join-Path $buildRoot 'logs'
New-Item -ItemType Directory -Force -Path $buildRoot, $logRoot | Out-Null
$utf8 = New-Object Text.UTF8Encoding($false)

# ---------------------------------------------------------------- release.json checks
$version = [string]$release.version
$versionCode = [int]$release.version_code
if ($version -notmatch '^\d+\.\d+\.\d+$') { throw "release.json: version '$version' must look like 1.2.3" }
if ($versionCode -lt 1) { throw 'release.json: version_code must be a positive integer (raise it for every Play upload)' }
if ([string]$release.package -notmatch '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$') { throw "release.json: package '$($release.package)' is not a valid Android application id" }
$projectVersion = [regex]::Match((Get-Content -LiteralPath (Join-Path $projectRoot 'project.godot') -Raw), '(?m)^config/version="([^"]*)"').Groups[1].Value
if ($projectVersion -ne $version) { throw "project.godot config/version '$projectVersion' differs from release.json version '$version'. Make them equal." }

$targets = @($Target)
if ($targets -contains 'All') { $targets = @('Windows', 'Linux', 'AndroidApk', 'AndroidAab') }
$targets = @($targets | Select-Object -Unique)
$android = @($targets | Where-Object { $_ -like 'Android*' }).Count -gt 0

# ---------------------------------------------------------------- helpers
function Invoke-Godot([string[]]$GodotArgs, [string]$LogName, [string[]]$Secrets = @()) {
    $log = Join-Path $logRoot ($LogName + '.log')
    $err = $log + '.stderr'
    $quoted = @($GodotArgs | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } })
    # -Wait is required: without it PowerShell 5.1 reports no exit code.
    $process = Start-Process -FilePath $editor -ArgumentList $quoted -WorkingDirectory $projectRoot -NoNewWindow -Wait -PassThru -RedirectStandardOutput $log -RedirectStandardError $err
    $text = [string](Get-Content -LiteralPath $log -Raw -ErrorAction SilentlyContinue) + [string](Get-Content -LiteralPath $err -Raw -ErrorAction SilentlyContinue)
    foreach ($secret in $Secrets) {
        if ($secret -and $text.Contains($secret)) {
            $text = $text.Replace($secret, '********')
            foreach ($file in @($log, $err)) {
                $raw = [IO.File]::ReadAllText($file)
                [IO.File]::WriteAllText($file, $raw.Replace($secret, '********'), $utf8)
            }
        }
    }
    # Godot colours its output even when redirected, so allow ANSI codes before "ERROR:".
    $problems = @([regex]::Matches($text, '(?m)^.*(SCRIPT ERROR|Parse Error|BUILD FAILED|FAILURE: ).*$|^(\x1b\[[0-9;]*m)*\s*ERROR:.*$') | ForEach-Object { $_.Value.Trim() })
    if ($process.ExitCode -ne 0 -or $problems.Count -gt 0) {
        $problems | Select-Object -First 15 | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
        throw "Godot step '$LogName' failed (exit $($process.ExitCode)). Full log: $log"
    }
}

# Runs a command-line tool and returns its exit code and combined output. Tools that report on
# stderr would otherwise throw under 'Stop' in Windows PowerShell.
function Invoke-Native([string]$Exe, [string[]]$Arguments) {
    $ErrorActionPreference = 'Continue'
    $output = & $Exe @Arguments 2>&1 | ForEach-Object { "$_" }
    return [pscustomobject]@{ Exit = $LASTEXITCODE; Text = ($output -join "`n") }
}

function Reset-Folder([string]$Path) {
    if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
}

function Set-PresetOption([string]$Text, [string]$Key, [string]$Value) {
    $pattern = '(?m)^' + [regex]::Escape($Key) + '=.*$'
    return [regex]::Replace($Text, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $Key + '=' + $Value })
}

function ConvertTo-CfgString([string]$Value) { return '"' + $Value.Replace('\', '\\').Replace('"', '\"') + '"' }

function Get-JavaHome {
    $java = Get-ChildItem -LiteralPath (Join-Path $toolRoot 'java') -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $java) { throw 'Local JDK is missing. Run tools/setup.ps1.' }
    return $java.FullName
}

# ---------------------------------------------------------------- tests and import
if (-not $SkipTests) {
    Write-Host '== Quality gate'
    & (Join-Path $projectRoot 'tests/run_all.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'Quality gate failed; nothing was built.' }
}
if ($android) { & (Join-Path $PSScriptRoot 'setup.ps1') | Out-Null }
if (-not $SkipImport) {
    Write-Host '== Import'
    Invoke-Godot @('--headless', '--editor', '--path', $projectRoot, '--import') 'import'
}

# ---------------------------------------------------------------- signing material (Android)
$sdkRoot = Join-Path $toolRoot 'android-sdk'
$buildTools = Join-Path $sdkRoot ('build-tools/' + $manifest.android_template.build_tools)
$keyPassword = ''
$keystorePath = ''
$keyAlias = ''
$uploadCertSha256 = ''
if ($android) {
    $javaHome = Get-JavaHome
    $env:JAVA_HOME = $javaHome
    $env:ANDROID_HOME = $sdkRoot
    # A Gradle daemon would outlive the export and keep this script waiting on Godot forever.
    $env:GRADLE_OPTS = '-Dorg.gradle.daemon=false'
    $propertiesPath = Join-Path $toolRoot 'keys/upload-key.properties'
    if (-not (Test-Path -LiteralPath $propertiesPath)) { throw 'No upload key. Run tools/make-upload-key.ps1 once (and back up .tools/keys/).' }
    $properties = @{}
    foreach ($line in Get-Content -LiteralPath $propertiesPath) {
        if ($line -match '^\s*([A-Za-z]+)\s*=\s*(.*)$') { $properties[$Matches[1]] = $Matches[2].Trim() }
    }
    $keystorePath = Join-Path (Split-Path -Parent $propertiesPath) $properties['storeFile']
    $keyAlias = $properties['keyAlias']
    $keyPassword = $properties['storePassword']
    if (-not (Test-Path -LiteralPath $keystorePath) -or -not $keyAlias -or -not $keyPassword) { throw "Upload key properties are incomplete: $propertiesPath" }
    $env:DEADWEIGHT_UPLOAD_PASS = $keyPassword
    $listing = Invoke-Native (Join-Path $javaHome 'bin/keytool.exe') @('-list', '-v', '-keystore', $keystorePath, '-alias', $keyAlias, '-storepass:env', 'DEADWEIGHT_UPLOAD_PASS')
    Remove-Item Env:DEADWEIGHT_UPLOAD_PASS -ErrorAction SilentlyContinue
    $uploadCertSha256 = ([regex]::Match($listing.Text, 'SHA256:\s*([0-9A-F:]+)')).Groups[1].Value
    if (-not $uploadCertSha256) { throw 'Could not read the upload key certificate. Check .tools/keys/.' }
}

# ---------------------------------------------------------------- stamp presets, export, restore
$presetsPath = Join-Path $projectRoot 'export_presets.cfg'
$presetsOriginal = [IO.File]::ReadAllBytes($presetsPath)
$fileVersion = $version + '.0'
$name = [string]$release.name
$stamped = [Text.Encoding]::UTF8.GetString($presetsOriginal)
foreach ($pair in @(
    @('version/code', [string]$versionCode),
    @('version/name', (ConvertTo-CfgString $version)),
    @('package/unique_name', (ConvertTo-CfgString ([string]$release.package))),
    @('package/name', (ConvertTo-CfgString $name)),
    @('application/file_version', (ConvertTo-CfgString $fileVersion)),
    @('application/product_version', (ConvertTo-CfgString $fileVersion)),
    @('application/product_name', (ConvertTo-CfgString $name)),
    @('application/file_description', (ConvertTo-CfgString $name)),
    @('application/company_name', (ConvertTo-CfgString ([string]$release.company))),
    @('application/copyright', (ConvertTo-CfgString ([string]$release.copyright)))
)) { $stamped = Set-PresetOption $stamped $pair[0] $pair[1] }

$artifacts = @()
$notices = Join-Path $projectRoot 'THIRD_PARTY_NOTICES.txt'
try {
    [IO.File]::WriteAllText($presetsPath, $stamped, $utf8)
    foreach ($item in $targets) {
        Write-Host "== $item"
        switch ($item) {
            { $_ -in @('Windows', 'Linux') } {
                $folder = Join-Path $buildRoot $item.ToLower()
                $binary = Join-Path $folder $(if ($item -eq 'Windows') { 'DEADWEIGHT.exe' } else { 'DEADWEIGHT.x86_64' })
                $preset = $(if ($item -eq 'Windows') { 'Windows Desktop' } else { 'Linux' })
                Reset-Folder $folder
                Invoke-Godot @('--headless', '--path', $projectRoot, '--export-release', $preset, $binary) ('export-' + $item.ToLower())
                if (-not (Test-Path -LiteralPath $binary)) { throw "$preset export produced no file" }
                Copy-Item -LiteralPath $notices -Destination $folder
                $zip = Join-Path $buildRoot ('DEADWEIGHT-' + $version + '-' + $item.ToLower() + '.zip')
                if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
                Compress-Archive -Path (Join-Path $folder '*') -DestinationPath $zip
                $artifacts += $zip
            }
            'AndroidApk' {
                $apk = Join-Path $buildRoot ('DEADWEIGHT-' + $version + '.apk')
                if (Test-Path -LiteralPath $apk) { Remove-Item -LiteralPath $apk -Force }
                $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = $keystorePath
                $env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = $keyAlias
                $env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = $keyPassword
                Invoke-Godot @('--headless', '--path', $projectRoot, '--export-release', 'Android APK', $apk) 'export-android-apk' @($keyPassword)
                if (-not (Test-Path -LiteralPath $apk)) { throw 'APK export produced no file' }
                # Signature: valid, and made with the upload key.
                $certs = Invoke-Native (Join-Path $buildTools 'apksigner.bat') @('verify', '--print-certs', $apk)
                if ($certs.Exit -ne 0) { throw "apksigner rejected the APK:`n$($certs.Text)" }
                $apkCert = ([regex]::Match($certs.Text, 'certificate SHA-256 digest:\s*([0-9a-f]+)')).Groups[1].Value
                if ($apkCert.ToUpper() -ne $uploadCertSha256.Replace(':', '')) { throw 'The APK is not signed with the upload key.' }
                # Manifest: package, version, target SDK, release-only flags, permissions.
                $badging = (Invoke-Native (Join-Path $buildTools 'aapt2.exe') @('dump', 'badging', $apk)).Text
                $expect = @(
                    "package: name='$($release.package)' versionCode='$versionCode' versionName='$version'",
                    ("targetSdkVersion:'" + $manifest.android_template.target_sdk + "'")
                )
                foreach ($line in $expect) { if (-not $badging.Contains($line)) { throw "APK manifest check failed: expected `"$line`"" } }
                if ($badging -match 'application-debuggable') { throw 'Release APK is debuggable' }
                $permissions = @([regex]::Matches($badging, "uses-permission: name='([^']+)'") | ForEach-Object { $_.Groups[1].Value })
                $unexpected = @($permissions | Where-Object { $_ -ne 'android.permission.VIBRATE' })
                if ($unexpected.Count -gt 0) { throw ('Unexpected Android permissions: ' + ($unexpected -join ', ')) }
                # 16 KB page-size alignment (Google Play requirement for targetSdk 35+).
                if ((Invoke-Native (Join-Path $buildTools 'zipalign.exe') @('-c', '-P', '16', '4', $apk)).Exit -ne 0) { throw 'APK is not 16 KB aligned (zipalign -c -P 16 4)' }
                $artifacts += $apk
            }
            'AndroidAab' {
                $aab = Join-Path $buildRoot ('DEADWEIGHT-' + $version + '.aab')
                if (Test-Path -LiteralPath $aab) { Remove-Item -LiteralPath $aab -Force }
                $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = $keystorePath
                $env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = $keyAlias
                $env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = $keyPassword
                $aabStarted = (Get-Date).AddSeconds(-2)
                Invoke-Godot @('--headless', '--path', $projectRoot, '--export-release', 'Android AAB', $aab) 'export-android-aab' @($keyPassword)
                if (-not (Test-Path -LiteralPath $aab)) { throw 'AAB export produced no file' }
                $verify = Invoke-Native (Join-Path $javaHome 'bin/jarsigner.exe') @('-verify', $aab)
                if ($verify.Exit -ne 0 -or $verify.Text -notmatch 'jar verified') { throw "jarsigner rejected the AAB:`n$($verify.Text)" }
                $printed = (Invoke-Native (Join-Path $javaHome 'bin/keytool.exe') @('-printcert', '-jarfile', $aab)).Text
                $aabCert = ([regex]::Match($printed, 'SHA256:\s*([0-9A-F:]+)')).Groups[1].Value
                if ($aabCert -ne $uploadCertSha256) { throw 'The AAB is not signed with the upload key.' }
                # The manifest Gradle put into the bundle (the AAB itself stores it as protobuf).
                $merged = Get-ChildItem -LiteralPath (Join-Path $projectRoot 'android/build/build/intermediates/bundle_manifest') -Recurse -Filter 'AndroidManifest.xml' -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.FullName -cmatch 'standardRelease' -and $_.LastWriteTime -ge $aabStarted } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                if (-not $merged) { throw 'Could not find this build''s release bundle manifest under android/build/build/intermediates/bundle_manifest' }
                [xml]$xml = Get-Content -LiteralPath $merged.FullName -Raw
                $ns = 'http://schemas.android.com/apk/res/android'
                $sdk = $xml.manifest.'uses-sdk'
                $checks = @{
                    'package' = @($xml.manifest.package, [string]$release.package)
                    'versionCode' = @($xml.manifest.GetAttribute('versionCode', $ns), [string]$versionCode)
                    'versionName' = @($xml.manifest.GetAttribute('versionName', $ns), $version)
                    'targetSdkVersion' = @($sdk.GetAttribute('targetSdkVersion', $ns), [string]$manifest.android_template.target_sdk)
                }
                foreach ($key in $checks.Keys) {
                    if ([string]$checks[$key][0] -ne [string]$checks[$key][1]) { throw "AAB manifest check failed: $key is '$($checks[$key][0])', expected '$($checks[$key][1])'" }
                }
                $permissions = @($xml.manifest.'uses-permission' | ForEach-Object { $_.GetAttribute('name', $ns) })
                $unexpected = @($permissions | Where-Object { $_ -and $_ -ne 'android.permission.VIBRATE' })
                if ($unexpected.Count -gt 0) { throw ('Unexpected Android permissions in the AAB: ' + ($unexpected -join ', ')) }
                $artifacts += $aab
            }
        }
    }
} finally {
    [IO.File]::WriteAllBytes($presetsPath, $presetsOriginal)
    foreach ($var in @('GODOT_ANDROID_KEYSTORE_RELEASE_PATH', 'GODOT_ANDROID_KEYSTORE_RELEASE_USER', 'GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD')) {
        Remove-Item -Path ('Env:' + $var) -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------------- checksums and build info
$current = @(Get-ChildItem -LiteralPath $buildRoot -File | Where-Object { $_.Name -like ('DEADWEIGHT-' + $version + '*') -and $_.Extension -in @('.zip', '.apk', '.aab') } | Sort-Object Name)
$sums = $current | ForEach-Object { (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLower() + '  ' + $_.Name }
[IO.File]::WriteAllText((Join-Path $buildRoot 'SHA256SUMS.txt'), (($sums -join "`n") + "`n"), $utf8)
$commit = 'unknown'
if (Get-Command git -ErrorAction SilentlyContinue) {
    Push-Location $projectRoot
    try {
        $commit = (& git rev-parse --short HEAD 2>$null)
        if ($LASTEXITCODE -ne 0 -or -not $commit) { $commit = 'unknown' }
        elseif (& git status --porcelain 2>$null) { $commit += ' (uncommitted changes)' }
    } finally { Pop-Location }
}
$info = @(
    "DEADWEIGHT $version (version code $versionCode)",
    "Package:      $($release.package)",
    "Built (UTC):  $((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss'))",
    "Commit:       $commit",
    "Godot:        $($manifest.godot_version)",
    "Targets:      $($targets -join ', ')",
    "Android:      targetSdk $($manifest.android_template.target_sdk), minSdk $($manifest.android_template.min_sdk)"
)
if ($uploadCertSha256) { $info += "Upload key:   SHA-256 $uploadCertSha256" }
$info += ''
$info += 'Artifacts:'
$info += ($current | ForEach-Object { '  {0}  ({1:N1} MB)' -f $_.Name, ($_.Length / 1MB) })
[IO.File]::WriteAllText((Join-Path $buildRoot 'BUILD_INFO.txt'), (($info -join "`n") + "`n"), $utf8)
$info | ForEach-Object { Write-Host $_ }
Write-Host 'BUILD: OK' -ForegroundColor Green
