# Uploads builds/windows and builds/linux to Steam with SteamPipe. OWNER ONLY, run by hand after
# `tools/build.ps1 -Target Windows` and `-Target Linux` (or -Target All). Nothing runs this automatically.
#
#   powershell -ExecutionPolicy Bypass -File tools/steam/upload.ps1 -SteamUser <account> [-Preview]
#
# - App and depot ids come from tools/release.json (steam_app_id, steam_depot_windows,
#   steam_depot_linux). The filled scripts are written to builds/steam/.
# - -Preview runs SteamPipe in preview mode: it checks the files and uploads nothing.
# - Credentials are never stored by this script: steamcmd asks for the password and Steam Guard code.
# - The upload never goes live by itself. Set the build live on a branch in Steamworks
#   (App Admin > SteamPipe > Builds), and test it on the beta branch first.
# - steamcmd: https://developer.valvesoftware.com/wiki/SteamCMD, or the Steamworks SDK's
#   tools/ContentBuilder/builder/steamcmd.exe. Pass -SteamCmd, set STEAMCMD, or put it in .tools/steamcmd/.
param(
    [Parameter(Mandatory = $true)][string]$SteamUser,
    [switch]$Preview,
    [string]$Description = '',
    [string]$SteamCmd = ''
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$release = Get-Content -LiteralPath (Join-Path $projectRoot 'tools/release.json') -Raw | ConvertFrom-Json
foreach ($field in @('steam_app_id', 'steam_depot_windows', 'steam_depot_linux')) {
    if ([string]$release.$field -notmatch '^\d+$') { throw "tools/release.json: '$field' must be the numeric id shown in Steamworks." }
}
$windowsRoot = Join-Path $projectRoot 'builds/windows'
$linuxRoot = Join-Path $projectRoot 'builds/linux'
if (-not (Test-Path -LiteralPath (Join-Path $windowsRoot 'DEADWEIGHT.exe'))) { throw 'builds/windows/DEADWEIGHT.exe is missing. Run tools/build.ps1 -Target Windows first.' }
if (-not (Test-Path -LiteralPath (Join-Path $linuxRoot 'DEADWEIGHT.x86_64'))) { throw 'builds/linux/DEADWEIGHT.x86_64 is missing. Run tools/build.ps1 -Target Linux first.' }

if (-not $SteamCmd) { $SteamCmd = [string]$env:STEAMCMD }
if (-not $SteamCmd) { $SteamCmd = Join-Path $projectRoot '.tools/steamcmd/steamcmd.exe' }
if (-not (Test-Path -LiteralPath $SteamCmd)) { throw "steamcmd.exe not found ($SteamCmd). See the notes at the top of this script." }

if (-not $Description) { $Description = 'DEADWEIGHT ' + $release.version + ' (code ' + $release.version_code + ')' }
$Description = $Description.Replace('"', "'")
$outRoot = Join-Path $projectRoot 'builds/steam'
$logRoot = Join-Path $outRoot 'output'
New-Item -ItemType Directory -Force -Path $outRoot, $logRoot | Out-Null

function ConvertTo-VdfPath([string]$Path) { return ([IO.Path]::GetFullPath($Path).Replace('\', '/').TrimEnd('/') + '/') }
$tokens = @{
    'APP_ID' = [string]$release.steam_app_id
    'DEPOT_WINDOWS' = [string]$release.steam_depot_windows
    'DEPOT_LINUX' = [string]$release.steam_depot_linux
    'DESCRIPTION' = $Description
    'PREVIEW' = $(if ($Preview) { '1' } else { '0' })
    'BUILD_OUTPUT' = (ConvertTo-VdfPath $logRoot)
    'CONTENT_WINDOWS' = (ConvertTo-VdfPath $windowsRoot)
    'CONTENT_LINUX' = (ConvertTo-VdfPath $linuxRoot)
}
foreach ($template in Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.vdf.template') {
    $text = Get-Content -LiteralPath $template.FullName -Raw
    foreach ($key in $tokens.Keys) { $text = $text.Replace('{{' + $key + '}}', $tokens[$key]) }
    if ($text -match '\{\{[A-Z_]+\}\}') { throw "Unfilled token in $($template.Name): $($Matches[0])" }
    $target = Join-Path $outRoot ($template.Name -replace '\.template$', '')
    [IO.File]::WriteAllText($target, $text, (New-Object Text.UTF8Encoding($false)))
}
$appBuild = Join-Path $outRoot 'app_build.vdf'
Write-Host ("SteamPipe {0}: app {1}, '{2}'" -f $(if ($Preview) { 'PREVIEW' } else { 'UPLOAD' }), $release.steam_app_id, $Description)
# Linux note: uploads from Windows carry no executable bit. Steam marks the launch-option
# executable (DEADWEIGHT.x86_64) executable itself; check it once on a Linux machine or Steam Deck.
& $SteamCmd +login $SteamUser +run_app_build $appBuild +quit
if ($LASTEXITCODE -ne 0) { throw "steamcmd failed (exit $LASTEXITCODE). Logs: $logRoot" }
Write-Host 'Done. Set the build live on a branch in Steamworks: App Admin > SteamPipe > Builds.'
