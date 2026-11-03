# Gameplay screenshots for the store page, taken through the game's own --level/--cam/--capture
# arguments (CONTRACT 4.7). Runs off-screen. Writes only new PNGs under store/art/screenshots/.
# Key art is made by tools/store_art.gd (run it separately).
#
# Usage (from the project root):
#   powershell -ExecutionPolicy Bypass -File tools/capture-store-art.ps1
#   powershell -ExecutionPolicy Bypass -File tools/capture-store-art.ps1 -Only touch_
#
# --cam=x,y,z,yaw_deg,pitch_deg freezes the player at that view. The capture waits 150 frames so
# the level settles first. The profile is a temp file, never the player's save.
param([string]$Only = "")

$root = Split-Path -Parent $PSScriptRoot
$godot = Join-Path $root ".tools/godot/Godot_v4.7.2-stable_win64_console.exe"
$out = Join-Path $root "store/art/screenshots"
New-Item -ItemType Directory -Force -Path $out | Out-Null

# The shot list. "renderer" gl_compatibility is the mobile path; "touch" forces the touch HUD.
$shots = @(
	@{ name = "hud_01_sluice_gate_spawn"; size = "1920x1080"; renderer = "forward_plus"; touch = $false; args = @("--level=l01") },
	@{ name = "hud_02_sluice_gate_overlook"; size = "1920x1080"; renderer = "forward_plus"; touch = $false; args = @("--level=l01", "--cam=19,18,19,16.6,-1.5") },
	@{ name = "hud_03_pump_row_pumps"; size = "1920x1080"; renderer = "forward_plus"; touch = $false; args = @("--level=l02", "--cam=0,2.5,-16,0,-6") },
	@{ name = "hud_04_overflow_causeway"; size = "1920x1080"; renderer = "forward_plus"; touch = $false; args = @("--level=l03", "--cam=0,3,-12,0,-6") },
	@{ name = "hud_05_slag_line_catwalks"; size = "1920x1080"; renderer = "forward_plus"; touch = $false; args = @("--level=l04", "--cam=0,4,-14,0,-4") },
	@{ name = "hud_06_crane_yard_arms"; size = "1920x1080"; renderer = "forward_plus"; touch = $false; args = @("--level=l05", "--cam=0,2,-12,0,14") },
	@{ name = "hud_07_crucible_teapot"; size = "1920x1080"; renderer = "forward_plus"; touch = $false; args = @("--level=l06", "--cam=0,8,-14,0,-10") },
	@{ name = "hud_08_induction_ledge"; size = "1920x1080"; renderer = "forward_plus"; touch = $false; args = @("--level=tutorial", "--cam=-8,4,-2,0,-6") },
	@{ name = "hud_09_practice_range"; size = "1920x1080"; renderer = "forward_plus"; touch = $false; args = @("--level=range") },
	@{ name = "touch_01_sluice_gate_spawn"; size = "2400x1080"; renderer = "gl_compatibility"; touch = $true; args = @("--level=l01") },
	@{ name = "touch_02_overflow_causeway"; size = "2400x1080"; renderer = "gl_compatibility"; touch = $true; args = @("--level=l03", "--cam=0,3,-12,0,-6") },
	@{ name = "touch_03_crane_yard_arms"; size = "2400x1080"; renderer = "gl_compatibility"; touch = $true; args = @("--level=l05", "--cam=0,2,-12,0,14") },
	@{ name = "touch_04_crucible_teapot"; size = "2400x1080"; renderer = "gl_compatibility"; touch = $true; args = @("--level=l06", "--cam=0,8,-14,0,-10") }
)

foreach ($shot in $shots) {
	if ($Only -ne "" -and -not $shot.name.Contains($Only)) { continue }
	$png = Join-Path $out ("{0}_{1}.png" -f $shot.name, $shot.size)
	$godotArgs = @("--path", $root, "--position", "20000,20000", "--resolution", $shot.size)
	if ($shot.renderer -eq "gl_compatibility") { $godotArgs += @("--rendering-method", "gl_compatibility") }
	$godotArgs += "--"
	$godotArgs += $shot.args
	$godotArgs += @("--capture", "--capture-delay=150", "--capture-path=$png", "--profile=user://test_store_art.cfg", "--unlock-all")
	if ($shot.touch) { $godotArgs += "--touch" }
	& $godot @godotArgs | Out-Null
	if (Test-Path $png) { Write-Output "OK   $png" } else { Write-Output "FAIL $png" }
}
