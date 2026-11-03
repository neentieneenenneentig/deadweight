# Desktop performance baseline (Q1a): every campaign level x renderer x quality preset.
# Runs the game windowed off-screen at 1280x720 with VSync off, using the same fixed views as
# capture-store-art.ps1. Each run is started with --fps, which prints one FPS_SAMPLE line per second.
# The first 2 samples are warm-up; the next 6 are measured, then the game is killed.
#   avg FPS      = mean of the sample fps values
#   1% low FPS   = mean of (1000 / 99th-percentile frame ms) per sample
#   draw calls   = mean of the per-sample draw count
# Writes .tools/perf/latest.csv and prints a table. The profile is a temp file, never the player's save.
#
# Usage (from the project root):
#   powershell -ExecutionPolicy Bypass -File tools/perf.ps1
#   powershell -ExecutionPolicy Bypass -File tools/perf.ps1 -Levels l01 -Renderers gl_compatibility
param(
	[string[]]$Levels = @("tutorial", "l01", "l02", "l03", "l04", "l05", "l06"),
	[string[]]$Renderers = @("forward_plus", "gl_compatibility"),
	[string[]]$Presets = @("low", "medium", "high")
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$godot = Join-Path $root ".tools/godot/Godot_v4.7.2-stable_win64_console.exe"
$outDir = Join-Path $root ".tools/perf"
$runDir = Join-Path $outDir "runs"
$csvPath = Join-Path $outDir "latest.csv"
New-Item -ItemType Directory -Force -Path $runDir | Out-Null

$warmupSamples = 2
$measureSamples = 6
$invariant = [Globalization.CultureInfo]::InvariantCulture

# Same fixed views as tools/capture-store-art.ps1 (the player is frozen there).
$views = @{
	"tutorial" = "-8,4,-2,0,-6"
	"l01" = "19,18,19,16.6,-1.5"
	"l02" = "0,2.5,-16,0,-6"
	"l03" = "0,3,-12,0,-6"
	"l04" = "0,4,-14,0,-4"
	"l05" = "0,2,-12,0,14"
	"l06" = "0,8,-14,0,-10"
}
$qualities = @{ "low" = 0; "medium" = 1; "high" = 2 }

# user://test_perf.cfg lives in Godot's user data folder for this project. The project sets
# config/use_custom_user_dir, so user:// is %APPDATA%\<custom_user_dir_name>, not Godot/app_userdata.
$projectText = Get-Content -Raw (Join-Path $root "project.godot")
$customDir = [regex]::Match($projectText, 'config/custom_user_dir_name="([^"]+)"').Groups[1].Value
if ($projectText -match 'config/use_custom_user_dir=true' -and $customDir) {
	$profilePath = Join-Path $env:APPDATA "$customDir/test_perf.cfg"
} else {
	$projectName = [regex]::Match($projectText, 'config/name="([^"]+)"').Groups[1].Value
	$profilePath = Join-Path $env:APPDATA "Godot/app_userdata/$projectName/test_perf.cfg"
}
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $profilePath) | Out-Null

function Write-PerfProfile([int]$quality) {
	# VSync off and no frame cap so the numbers are the renderer's, not the monitor's.
	# profile.gd rejects a file without its "; end of profile" trailer (cut-short write guard) and
	# would silently fall back to defaults (High, vsync on), so the trailer is required.
	$text = "[profile]`nversion=1`n`n[settings]`nwindow_mode=`"windowed`"`nvsync=false`nmax_fps=0`nquality=$quality`nrender_scale=1.0`n`n; end of profile`n"
	[IO.File]::WriteAllText($profilePath, $text)
}

function Read-Samples([string]$stdoutPath) {
	$found = @()
	if (-not (Test-Path $stdoutPath)) { return ,$found }
	$lines = Get-Content -Path $stdoutPath -ErrorAction SilentlyContinue
	foreach ($line in $lines) {
		$m = [regex]::Match($line, 'FPS_SAMPLE fps=([\d.]+) ms=([\d.]+) ms99=([\d.]+) draws=(\d+) setup=([\d.]+)')
		if ($m.Success) {
			$found += [pscustomobject]@{
				Fps = [double]::Parse($m.Groups[1].Value, $invariant)
				Ms = [double]::Parse($m.Groups[2].Value, $invariant)
				Ms99 = [double]::Parse($m.Groups[3].Value, $invariant)
				Draws = [int]$m.Groups[4].Value
				Setup = [double]::Parse($m.Groups[5].Value, $invariant)
			}
		}
	}
	return ,$found
}

function Invoke-PerfRun([string]$level, [string]$renderer, [string]$preset) {
	Write-PerfProfile $qualities[$preset]
	$stdout = Join-Path $runDir ("{0}_{1}_{2}.txt" -f $level, $renderer, $preset)
	if (Test-Path $stdout) { Remove-Item -Force $stdout }
	$godotArgs = @("--path", $root, "--position", "20000,20000", "--resolution", "1280x720", "--disable-vsync")
	if ($renderer -eq "gl_compatibility") { $godotArgs += @("--rendering-method", "gl_compatibility") }
	$godotArgs += @("--", "--level=$level", "--cam=$($views[$level])", "--fps", "--windowed", "--unlock-all", "--profile=user://test_perf.cfg")
	$proc = Start-Process -FilePath $godot -ArgumentList $godotArgs -RedirectStandardOutput $stdout -PassThru -WindowStyle Hidden
	$needed = $warmupSamples + $measureSamples
	$samples = @()
	$deadline = (Get-Date).AddSeconds(90)
	try {
		while ((Get-Date) -lt $deadline) {
			$samples = Read-Samples $stdout
			if ($samples.Count -ge $needed -or $proc.HasExited) { break }
			Start-Sleep -Milliseconds 250
		}
	} finally {
		if (-not $proc.HasExited) { $proc.Kill() }
		$proc.WaitForExit()
	}
	$samples = Read-Samples $stdout
	if ($samples.Count -lt $needed) {
		return [pscustomobject]@{ Status = "FAIL: $($samples.Count) of $needed samples" }
	}
	$measured = @($samples[$warmupSamples..($needed - 1)])
	return [pscustomobject]@{
		Status = "OK"
		Fps = ($measured | Measure-Object -Property Fps -Average).Average
		Low1 = ($measured | ForEach-Object { 1000.0 / $_.Ms99 } | Measure-Object -Average).Average
		Ms = ($measured | Measure-Object -Property Ms -Average).Average
		Draws = ($measured | Measure-Object -Property Draws -Average).Average
		Setup = ($measured | Measure-Object -Property Setup -Average).Average
	}
}

# Numbers are written with the invariant culture so the CSV reads the same on any machine.
function Format-Num($value, [string]$pattern) {
	return ([double]$value).ToString($pattern, $invariant)
}

if (-not (Test-Path $godot)) { throw "Godot binary not found: $godot" }
$results = @()
foreach ($renderer in $Renderers) {
	foreach ($level in $Levels) {
		foreach ($preset in $Presets) {
			Write-Output ("running {0} {1} {2} ..." -f $level, $renderer, $preset)
			$run = Invoke-PerfRun $level $renderer $preset
			$results += [pscustomobject]@{
				Level = $level
				Renderer = $renderer
				Preset = $preset
				AvgFPS = if ($run.Status -eq "OK") { Format-Num $run.Fps "0.0" } else { "" }
				Low1PctFPS = if ($run.Status -eq "OK") { Format-Num $run.Low1 "0.0" } else { "" }
				AvgFrameMs = if ($run.Status -eq "OK") { Format-Num $run.Ms "0.00" } else { "" }
				DrawCalls = if ($run.Status -eq "OK") { Format-Num $run.Draws "0" } else { "" }
				CpuSetupMs = if ($run.Status -eq "OK") { Format-Num $run.Setup "0.00" } else { "" }
				Status = $run.Status
			}
		}
	}
}

New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$results | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
Write-Output ""
$results | Format-Table -AutoSize | Out-String -Width 200 | Write-Output
$ok = @($results | Where-Object { $_.Status -eq "OK" })
if ($ok.Count -gt 0) {
	# FPS saturates at the display refresh on vsync'd machines, so rank by CPU frame setup instead.
	$heaviest = $ok | Sort-Object { [double]$_.CpuSetupMs } -Descending | Select-Object -First 1
	Write-Output ("Heaviest (highest CPU setup): {0} {1} {2}: setup {3} ms, {4} draw calls, {5} FPS" -f $heaviest.Level, $heaviest.Renderer, $heaviest.Preset, $heaviest.CpuSetupMs, $heaviest.DrawCalls, $heaviest.AvgFPS)
}
Write-Output "CSV: $csvPath"
