# Live gameplay screenshots for the store page (R6b). Each shot is one Godot process running
# tools/store_art.gd --shot=<name>, which drives the real game (main.tscn) through its scripted cast,
# latch, swing or reel, then saves the viewport from the player's own camera. Runs off-screen.
# The scenario for each shot lives in LIVE_SHOTS in tools/store_art.gd; this file only holds the
# output size, the renderer and the touch flag. Key art is made by tools/store_art.gd without --shot.
#
# Usage (from the project root):
#   powershell -ExecutionPolicy Bypass -File tools/capture-store-art.ps1
#   powershell -ExecutionPolicy Bypass -File tools/capture-store-art.ps1 -Only hud_03
#
# Output: store/art/screenshots/<name>_<width>x<height>.png. Before a shot renders, the older PNGs
# with the same id (hud_03_*, touch_02_*) are deleted, so a renamed shot leaves no stale file.
# The profile is a temp file under user://, never the player's save. Fixed 60 fps keeps runs repeatable.
param([string]$Only = "")

$root = Split-Path -Parent $PSScriptRoot
$godot = Join-Path $root ".tools/godot/Godot_v4.7.2-stable_win64_console.exe"
$out = Join-Path $root "store/art/screenshots"
New-Item -ItemType Directory -Force -Path $out | Out-Null

# id, scenario name (LIVE_SHOTS in store_art.gd), size, renderer ("gl_compatibility" is the mobile path), touch
$shots = @(
	@{ id = "hud_01"; name = "hud_01_pump_row_hound_chase"; size = "1920x1080"; renderer = "forward_plus"; touch = $false },
	@{ id = "hud_02"; name = "hud_02_sluice_gate_sentry_beam"; size = "1920x1080"; renderer = "forward_plus"; touch = $false },
	@{ id = "hud_03"; name = "hud_03_pump_row_swing"; size = "1920x1080"; renderer = "forward_plus"; touch = $false },
	@{ id = "hud_04"; name = "hud_04_overflow_causeway_gantry"; size = "1920x1080"; renderer = "forward_plus"; touch = $false },
	@{ id = "hud_05"; name = "hud_05_slag_line_lintel_swing"; size = "1920x1080"; renderer = "forward_plus"; touch = $false },
	@{ id = "hud_06"; name = "hud_06_crane_yard_arm_reel"; size = "1920x1080"; renderer = "forward_plus"; touch = $false },
	@{ id = "hud_07"; name = "hud_07_crucible_kiln_swing"; size = "1920x1080"; renderer = "forward_plus"; touch = $false },
	@{ id = "hud_08"; name = "hud_08_induction_ledge_swing"; size = "1920x1080"; renderer = "forward_plus"; touch = $false },
	@{ id = "hud_09"; name = "hud_09_practice_range_gantry"; size = "1920x1080"; renderer = "forward_plus"; touch = $false },
	@{ id = "touch_01"; name = "touch_01_sluice_gate_sentry_beam"; size = "2400x1080"; renderer = "gl_compatibility"; touch = $true },
	@{ id = "touch_02"; name = "touch_02_overflow_causeway_gantry"; size = "2400x1080"; renderer = "gl_compatibility"; touch = $true },
	@{ id = "touch_03"; name = "touch_03_crane_yard_arm"; size = "2400x1080"; renderer = "gl_compatibility"; touch = $true },
	@{ id = "touch_04"; name = "touch_04_crucible_kiln_reel"; size = "2400x1080"; renderer = "gl_compatibility"; touch = $true }
)

foreach ($shot in $shots) {
	if ($Only -ne "" -and -not $shot.name.Contains($Only)) { continue }
	Get-ChildItem -Path $out -Filter ("{0}_*.png" -f $shot.id) -ErrorAction SilentlyContinue | Remove-Item -Force
	$godotArgs = @("--path", $root, "--position", "20000,20000", "--resolution", $shot.size, "--fixed-fps", "60")
	if ($shot.renderer -eq "gl_compatibility") { $godotArgs += @("--rendering-method", "gl_compatibility") }
	$godotArgs += @("--script", "res://tools/store_art.gd", "--", "--shot=$($shot.name)", "--profile=user://test_store_art.cfg", "--unlock-all")
	if ($shot.touch) { $godotArgs += "--touch" }
	& $godot @godotArgs | Where-Object { $_ -match "STORE_ART|SCRIPT ERROR|ERROR:" } | ForEach-Object { Write-Output $_ }
	$png = Join-Path $out ("{0}_{1}.png" -f $shot.name, $shot.size)
	if (Test-Path $png) { Write-Output ("OK   {0}" -f $png) } else { Write-Output ("FAIL {0}" -f $png) }
}
