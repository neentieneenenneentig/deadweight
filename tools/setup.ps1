# Sets up the local toolchain in .tools/: the Godot editor and export templates and, unless
# -DesktopOnly is given, JDK 17, the Android SDK packages listed in toolchain.json and the
# project's Android build template (android/build).
# Safe to run repeatedly: installed parts are skipped and nothing is downloaded twice.
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

# Godot editor, in self-contained mode: its settings and templates live in .tools/godot/editor_data.
$editorRoot = Join-Path $toolRoot 'godot'
$editor = Join-Path $editorRoot ('Godot_v' + $manifest.godot_version + '_win64_console.exe')
if (-not (Test-Path -LiteralPath $editor)) {
    $editorZip = Get-VerifiedArchive $manifest.editor.url 'godot.zip' $manifest.editor.sha256
    Expand-Selected $editorZip $editorRoot
}
$selfContained = Join-Path $editorRoot '_sc_'
if (-not (Test-Path -LiteralPath $selfContained)) { Set-Content -LiteralPath $selfContained -Value '' }

# Export templates: only the files the presets use (the full archive is 1.3 GB).
$templateRoot = Join-Path $editorRoot ('editor_data/export_templates/' + $manifest.godot_template_version)
$templateVersion = Join-Path $templateRoot 'version.txt'
$stale = (Test-Path -LiteralPath $templateVersion) -and ((Get-Content -LiteralPath $templateVersion -Raw).Trim() -ne $manifest.godot_template_version)
$missing = @($manifest.template_files | Where-Object { $stale -or -not (Test-Path -LiteralPath (Join-Path $templateRoot $_)) })
if ($missing.Count -gt 0) {
    Write-Host ('Extracting export templates: ' + ($missing -join ', '))
    $templatesZip = Get-VerifiedArchive $manifest.templates.url 'templates.tpz' $manifest.templates.sha256
    Expand-Selected $templatesZip $templateRoot 'templates/' $missing
}

if (-not $DesktopOnly) {
    $javaRoot = Join-Path $toolRoot 'java'
    $java = Get-ChildItem -LiteralPath $javaRoot -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $java) {
        $jdkZip = Get-VerifiedArchive $manifest.jdk.url 'jdk.zip' $manifest.jdk.sha256
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
    # Every installed SDK package has a package.xml in its folder ("build-tools;36.1.0" -> build-tools/36.1.0).
    $needed = @($manifest.android_packages | Where-Object { -not (Test-Path -LiteralPath (Join-Path $sdkRoot (($_ -replace ';','/') + '/package.xml'))) })
    if ($needed.Count -gt 0) {
        Write-Host ('Installing Android SDK packages: ' + ($needed -join ', '))
        # sdkmanager shows the SDK license text during this local development setup.
        (1..30 | ForEach-Object { 'y' }) | & $sdkManager "--sdk_root=$sdkRoot" '--licenses' | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Android SDK license setup failed' }
        (1..30 | ForEach-Object { 'y' }) | & $sdkManager "--sdk_root=$sdkRoot" @needed
        if ($LASTEXITCODE -ne 0) { throw 'Android SDK installation failed' }
    }
    & (Join-Path $PSScriptRoot 'configure-android.ps1')

    # Android build template, installed the way the editor's "Install Android Build Template" does:
    # android/.build_version, android/build/ from android_source.zip, and a .gdignore so Godot
    # doesn't import it. Both android/ and the presets' exclude filter keep it out of exports.
    $androidRoot = Join-Path $projectRoot 'android'
    $gradleRoot = Join-Path $androidRoot 'build'
    $buildVersion = Join-Path $androidRoot '.build_version'
    $installed = ''
    if (Test-Path -LiteralPath $buildVersion) { $installed = (Get-Content -LiteralPath $buildVersion -Raw).Trim() }
    if ($installed -ne $manifest.godot_template_version -or -not (Test-Path -LiteralPath (Join-Path $gradleRoot 'build.gradle'))) {
        Write-Host 'Installing the Android build template into android/build...'
        if (Test-Path -LiteralPath $gradleRoot) { Remove-Item -LiteralPath $gradleRoot -Recurse -Force }
        Expand-Selected (Join-Path $templateRoot 'android_source.zip') $gradleRoot
        $utf8 = New-Object Text.UTF8Encoding($false)
        [IO.File]::WriteAllText((Join-Path $gradleRoot '.gdignore'), "`n", $utf8)
        [IO.File]::WriteAllText($buildVersion, $manifest.godot_template_version + "`n", $utf8)
    }
}
& $editor --version
Write-Host 'Local toolchain ready. Use tools/build.ps1 to create builds.'
