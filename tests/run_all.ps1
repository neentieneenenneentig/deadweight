<#
.SYNOPSIS
  DEADWEIGHT quality gate: parse-checks every GDScript file, then runs every headless
  test suite (tests/*_test.gd). Exit code 0 only when everything passes.
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tests/run_all.ps1
  powershell -ExecutionPolicy Bypass -File tests/run_all.ps1 -Only physics_test,world_test -NoParse
#>
param(
    [string[]]$Only = @(),          # suite base names, e.g. physics_test
    [switch]$NoParse,               # skip the per-file parse check
    [int]$MaxFrames = 200000        # hang guard per suite (Godot --quit-after)
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$godot = Join-Path $root '.tools/godot/Godot_v4.7.2-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $godot)) { throw "Godot not found at $godot. Run tools/setup.ps1 -DesktopOnly first." }
$logDir = Join-Path $root '.tools/test-logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$quotedRoot = '"' + $root + '"'

function Invoke-Godot([string[]]$GodotArgs, [string]$LogBase) {
    $out = Join-Path $logDir ($LogBase + '.log')
    $err = $out + '.err'
    # -Wait is required: without it PowerShell 5.1 reports no exit code for this process.
    $process = Start-Process -FilePath $godot -ArgumentList $GodotArgs -NoNewWindow -Wait -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
    $text = [string](Get-Content -LiteralPath $out -Raw -ErrorAction SilentlyContinue) + [string](Get-Content -LiteralPath $err -Raw -ErrorAction SilentlyContinue)
    return [pscustomobject]@{ Exit = $process.ExitCode; Text = $text; Log = $out }
}

$failed = 0
if (-not $NoParse) {
    $scripts = Get-ChildItem -LiteralPath $root -Recurse -Filter '*.gd' -File |
        Where-Object { $_.FullName -notmatch '\\(\.tools|\.godot|android|builds)\\' }
    $parseFailures = @()
    foreach ($file in $scripts) {
        $resPath = 'res://' + $file.FullName.Substring($root.Length + 1).Replace('\', '/')
        $result = Invoke-Godot @('--headless', '--path', $quotedRoot, '--check-only', '--script', $resPath) ('parse_' + $file.BaseName)
        if ($result.Exit -ne 0 -or $result.Text -match 'Parse Error|SCRIPT ERROR') { $parseFailures += $resPath }
    }
    if ($parseFailures.Count -gt 0) {
        $failed += $parseFailures.Count
        Write-Host ("PARSE CHECK FAILED ({0} of {1} files):" -f $parseFailures.Count, $scripts.Count) -ForegroundColor Red
        $parseFailures | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    } else {
        Write-Host ("Parse check: {0} scripts OK" -f $scripts.Count) -ForegroundColor Green
    }
}

$suites = @(Get-ChildItem -LiteralPath (Join-Path $root 'tests') -Filter '*_test.gd' -File | Sort-Object Name)
if ($Only.Count -gt 0) {
    $missing = $Only | Where-Object { $_ -notin $suites.BaseName }
    if ($missing) { Write-Host ("Missing suites: " + ($missing -join ', ')) -ForegroundColor Red; $failed += @($missing).Count }
    $suites = @($suites | Where-Object { $_.BaseName -in $Only })
}
$rows = @()
foreach ($suite in $suites) {
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $result = Invoke-Godot @('--headless', '--fixed-fps', '90', '--quit-after', [string]$MaxFrames, '--path', $quotedRoot, '--script', ('res://tests/' + $suite.Name)) $suite.BaseName
    $watch.Stop()
    $scriptErrors = ([regex]::Matches($result.Text, 'SCRIPT ERROR')).Count
    $ok = ($result.Exit -eq 0) -and ($scriptErrors -eq 0)
    if (-not $ok) { $failed += 1 }
    $rows += [pscustomobject]@{
        Suite = $suite.BaseName
        Result = $(if ($ok) { 'PASS' } else { 'FAIL' })
        Exit = $result.Exit
        ScriptErrors = $scriptErrors
        Seconds = [math]::Round($watch.Elapsed.TotalSeconds, 1)
        Log = $result.Log.Substring($root.Length + 1)
    }
}
$rows | Format-Table -AutoSize | Out-String -Width 200 | Write-Host
if ($failed -gt 0) {
    Write-Host "QUALITY GATE: FAILED ($failed problem(s)). Open the logs listed above." -ForegroundColor Red
    exit 1
}
Write-Host "QUALITY GATE: PASSED" -ForegroundColor Green
exit 0
