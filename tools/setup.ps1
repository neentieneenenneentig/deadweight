param([switch]$DesktopOnly)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$toolRoot = Join-Path $projectRoot '.tools'
$manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'toolchain.json') -Raw | ConvertFrom-Json
New-Item -ItemType Directory -Force -Path $toolRoot,(Join-Path $toolRoot 'downloads') | Out-Null

function Get-VerifiedArchive([string]$Url, [string]$Name, [string]$Hash, [string]$Algorithm = 'SHA256') {
    $path = Join-Path $toolRoot ('downloads/' + $Name)
    if (Test-Path -LiteralPath $path) {
        if ((Get-FileHash -LiteralPath $path -Algorithm $Algorithm).Hash -eq $Hash) { return $path }
    }
    Write-Host "Downloading $Name from the official distributor..."
    & curl.exe -fL --retry 4 --retry-all-errors --silent --show-error $Url -o $path
    if ($LASTEXITCODE -ne 0) { throw "Download failed: $Name" }
    if ((Get-FileHash -LiteralPath $path -Algorithm $Algorithm).Hash -ne $Hash) { throw "Checksum mismatch: $Name" }
    return $path
}

function Expand-Selected([string]$Archive, [string]$Destination, [string]$Prefix = '', [string[]]$Names = @()) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    $safeRoot = [IO.Path]::GetFullPath($Destination).TrimEnd('\') + '\'
    $zip = [IO.Compression.ZipFile]::OpenRead($Archive)
    try {
        foreach ($entry in $zip.Entries) {
            if (-not $entry.FullName.StartsWith($Prefix)) { continue }
            $relative = $entry.FullName.Substring($Prefix.Length)
            if (-not $relative -or $relative.EndsWith('/')) { continue }
            if ($Names.Count -gt 0 -and $relative -notin $Names) { continue }
            $target = [IO.Path]::GetFullPath((Join-Path $Destination $relative))
            if (-not $target.StartsWith($safeRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe archive path' }
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $true)
        }
    } finally { $zip.Dispose() }
}

$editorZip = Get-VerifiedArchive $manifest.editor.url 'godot.zip' $manifest.editor.sha256
$editorRoot = Join-Path $toolRoot 'godot'
$editor = Join-Path $editorRoot ('Godot_v' + $manifest.godot_version + '_win64_console.exe')
if (-not (Test-Path -LiteralPath $editor)) { Expand-Selected $editorZip $editorRoot }
Set-Content -LiteralPath (Join-Path $editorRoot '_sc_') -Value ''

$templatesZip = Get-VerifiedArchive $manifest.templates.url 'templates.tpz' $manifest.templates.sha256
$templateRoot = Join-Path $editorRoot ('editor_data/export_templates/' + $manifest.godot_template_version)
Expand-Selected $templatesZip $templateRoot 'templates/' @('version.txt','windows_debug_x86_64.exe','windows_release_x86_64.exe','android_debug.apk','android_release.apk')

if (-not $DesktopOnly) {
    $jdkZip = Get-VerifiedArchive $manifest.jdk.url 'jdk.zip' $manifest.jdk.sha256
    $javaRoot = Join-Path $toolRoot 'java'
    $java = Get-ChildItem -LiteralPath $javaRoot -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $java) {
        Expand-Selected $jdkZip $javaRoot
        $java = Get-ChildItem -LiteralPath $javaRoot -Directory | Select-Object -First 1
    }
    $env:JAVA_HOME = $java.FullName
    $env:PATH = (Join-Path $env:JAVA_HOME 'bin') + ';' + $env:PATH
    $sdkRoot = Join-Path $toolRoot 'android-sdk'
    $sdkManager = Join-Path $sdkRoot 'cmdline-tools/latest/bin/sdkmanager.bat'
    if (-not (Test-Path -LiteralPath $sdkManager)) {
        $sdkZip = Get-VerifiedArchive $manifest.android_commandline.url 'android-commandline.zip' $manifest.android_commandline.sha1 'SHA1'
        Expand-Selected $sdkZip (Join-Path $sdkRoot 'cmdline-tools/latest') 'cmdline-tools/'
    }
    Write-Host 'Installing the Android packages needed for a prebuilt-template APK export...'
    # The SDK license text is displayed by sdkmanager during this local development setup.
    (1..30 | ForEach-Object { 'y' }) | & $sdkManager "--sdk_root=$sdkRoot" '--licenses'
    if ($LASTEXITCODE -ne 0) { throw 'Android SDK license setup failed' }
    (1..30 | ForEach-Object { 'y' }) | & $sdkManager "--sdk_root=$sdkRoot" @($manifest.android_packages)
    if ($LASTEXITCODE -ne 0) { throw 'Android SDK installation failed' }
    & (Join-Path $PSScriptRoot 'configure-android.ps1')
}
& $editor --version
Write-Host 'Local toolchain ready. Use tools/build.ps1 to create builds.'
