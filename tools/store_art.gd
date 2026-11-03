extends SceneTree
## Store art compositor (R6) and live gameplay screenshots (R6b).
##
## Key art: each JOBS entry builds a catalog level in its own SubViewport of the target size, frames
## it with a camera, and draws the brand lockup over it. "still" jobs freeze the player.
## Run from the project root, off-screen (only the store art paths; the wrapper never runs these):
##   <godot> --path . --position 20000,20000 --script res://tools/store_art.gd -- --only=header
##
## Live shots: each LIVE_SHOTS entry runs the real game (main.tscn, so the HUD, rod, line and enemies
## are the shipped code) in its own process, casts the rod at an anchor, lets the weight latch, swings
## or reels, and saves the root viewport from the player's own camera. The wrapper
## tools/capture-store-art.ps1 runs one process per shot, at the shot's size and renderer:
##   <godot> --path . --position 20000,20000 --resolution 1920x1080 --fixed-fps 60 --script res://tools/store_art.gd -- --shot=hud_03_pump_row_swing --profile=user://test_store_art.cfg --unlock-all
## Use --probe=1 in place of --shot=<name> with --level=<id> to list the anchors and enemies of a level.
##
## Nothing touches the player's save. Writes only under store/art/screenshots/ (live) or the JOBS files
## under store/art/steam/ and store/art/google-play/ (key art).

const Catalog = preload("res://scripts/level_catalog.gd")
const Player = preload("res://scripts/player.gd")
const Tether = preload("res://scripts/tether.gd")
const UiTheme = preload("res://scripts/ui/theme.gd")
const Achievements = preload("res://scripts/achievements.gd")
const MainScene: PackedScene = preload("res://main.tscn")

const MARK_PATH: String = "res://store/art/brand/mark_1024.png"
const ART_DIR: String = "res://store/art/"
const SCREENSHOT_DIR: String = "res://store/art/screenshots/"
const TAGLINE: String = "DEPARTMENT OF UNFINISHED GRAVITY"
const WORDMARK: String = "DEADWEIGHT"
const SETTLE_FRAMES: int = 30
const CAST_TIMEOUT_FRAMES: int = 300
const LIVE_TIMEOUT_FRAMES: int = 1200
## Live runs use --fixed-fps 60, so one physics step is one frame and the frame counts below are exact.
const LIVE_FPS: float = 60.0

## One entry per output. Fields:
##   file: path under store/art/ (new files only); size: output pixels; level: catalog id (or "")
##   mode: "still" (frozen player, camera only) or "cast" (rod fired from "from" at "aim")
##   practice: true removes enemies (clean scenery); cam/look/fov: camera; hold: seconds after latch
##   layout: overlay style, "none" for text-free art; transparent: alpha background (logo only)
const JOBS: Array[Dictionary] = [
	{"file": "steam/steam_header_920x430.png", "size": Vector2i(920, 430), "level": "l03", "mode": "still",
		"practice": false, "cam": Vector3(0.0, 4.0, 12.0), "look": Vector3(-1.0, 4.0, -40.0), "fov": 60.0, "layout": "header"},
	{"file": "steam/steam_capsule_small_462x174.png", "size": Vector2i(462, 174), "level": "l05", "mode": "still",
		"practice": false, "cam": Vector3(6.0, 14.0, 18.0), "look": Vector3(0.0, 9.0, -30.0), "fov": 60.0, "layout": "small"},
	{"file": "steam/steam_capsule_main_1232x706.png", "size": Vector2i(1232, 706), "level": "l01", "mode": "still",
		"practice": false, "cam": Vector3(15.0, 15.0, 34.0), "look": Vector3(-4.0, 9.0, -40.0), "fov": 60.0, "layout": "main"},
	{"file": "steam/steam_capsule_vertical_748x896.png", "size": Vector2i(748, 896), "level": "l04", "mode": "still",
		"practice": false, "cam": Vector3(0.0, 6.0, 12.0), "look": Vector3(0.0, 4.0, -40.0), "fov": 60.0, "layout": "vertical"},
	{"file": "steam/steam_library_capsule_600x900.png", "size": Vector2i(600, 900), "level": "l02", "mode": "still",
		"practice": false, "cam": Vector3(0.0, 4.0, 10.0), "look": Vector3(0.0, 5.0, -30.0), "fov": 60.0, "layout": "capsule"},
	{"file": "steam/steam_library_hero_3840x1240.png", "size": Vector2i(3840, 1240), "level": "l03", "mode": "still",
		"practice": false, "cam": Vector3(0.0, 12.0, 20.0), "look": Vector3(0.0, 4.0, -40.0), "fov": 70.0, "layout": "none"},
	{"file": "steam/steam_library_logo_1280x720.png", "size": Vector2i(1280, 720), "level": "", "mode": "still",
		"practice": false, "cam": Vector3.ZERO, "look": Vector3.FORWARD, "fov": 60.0, "layout": "logo", "transparent": true},
	{"file": "steam/steam_page_background_1438x810.png", "size": Vector2i(1438, 810), "level": "l05", "mode": "still",
		"practice": false, "cam": Vector3(-12.0, 8.0, 14.0), "look": Vector3(4.0, 8.0, -60.0), "fov": 60.0, "layout": "none"},
	{"file": "google-play/play_feature_graphic_1024x500.png", "size": Vector2i(1024, 500), "level": "l03", "mode": "still",
		"practice": false, "cam": Vector3(0.0, 6.0, 16.0), "look": Vector3(0.0, 5.0, -40.0), "fov": 60.0, "layout": "feature"},
]

## Live gameplay shots (R6b). Fields:
##   level: catalog id; from: "spawn" or the capsule centre to cast from; aim: a point near the anchor
##   the rod is fired at (the nearest anchor plate is used); swing: impulse on the player once the
##   weight has latched (N s, zero for none); reel: true to reel in while latched; reel_frames: frames
##   of reel-in before the swing, which shortens the line to a pendulum length; frames: physics frames
##   before the capture; power 0..1 charge; lift: metres added to the aim to clear gravity's drop;
##   track: keep the plate in view once latched; min_speed: capture early at this speed with taut line;
##   latch: false casts at a target and captures the line in flight.
##   look: "velocity" looks along the horizontal swing, pitched up by look_up degrees (default 15), so the
##   line runs from the rod up through the frame and the level shows below; "hound" follows the nearest
##   hound; anything else follows aim. track applies the look once latched, or from the cast for latch false.
##   near: capture once the nearest hound is this close (m), for a chase; 0 for none.
##   practice: true starts the level with --practice (no enemies), so a bite cannot knock the swing off course.
## Casts start 15 to 25 m from their plate, so the line is long in frame. Plates are listed by --probe.
const LIVE_SHOTS: Dictionary = {
	"hud_01_pump_row_hound_chase": {"level": "l02", "from": Vector3(-4, 1, -6), "aim": Vector3(-10, 5, -30), "latch": false, "power": 0.3, "track": true, "look": "hound", "near": 7.0, "frames": 300},
	"hud_02_sluice_gate_sentry_beam": {"level": "l01", "from": Vector3(-8, 1, -30), "aim": Vector3(-22, 3.6, -46), "latch": false, "power": 0.3, "frames": 40},
	"hud_03_pump_row_swing": {"level": "l02", "from": Vector3(0, 1, -16), "aim": Vector3(-5, 8.64, -37), "power": 0.4, "lift": 2.2, "reel_frames": 120, "swing": Vector3(910.0, 250.0, -410.0), "practice": true, "track": true, "look": "velocity", "min_speed": 15.0, "frames": 150},
	"hud_04_overflow_causeway_gantry": {"level": "l03", "from": Vector3(0, 1, -26), "aim": Vector3(12, 8.54, -38), "power": 0.2, "lift": 2.2, "reel_frames": 60, "swing": Vector3(800.0, 250.0, 480.0), "practice": true, "track": true, "look": "velocity", "min_speed": 15.0, "frames": 150},
	"hud_05_slag_line_lintel_swing": {"level": "l04", "from": Vector3(-2, 1, -66), "aim": Vector3(-6, 9.54, -88), "power": 0.6, "lift": 2.2, "reel_frames": 110, "swing": Vector3(1000.0, 200.0, -180.0), "practice": true, "track": true, "look": "velocity", "min_speed": 15.0, "frames": 150},
	"hud_06_crane_yard_arm_reel": {"level": "l05", "from": Vector3(0, 1, -10), "aim": Vector3(-5, 14.99, -22), "power": 0.2, "lift": 1.5, "reel": true, "practice": true, "track": true, "look": "velocity", "frames": 90},
	"hud_07_crucible_kiln_swing": {"level": "l06", "from": Vector3(0, 10, -54), "aim": Vector3(-11, 16.34, -65.05), "power": 0.2, "lift": 1.5, "reel_frames": 60, "swing": Vector3(-600.0, 150.0, 600.0), "practice": true, "track": true, "look": "aim", "view": Vector3(0, 0.5, -46), "min_speed": 12.0, "frames": 150},
	"hud_08_induction_ledge_swing": {"level": "tutorial", "from": Vector3(0, 1, -48), "aim": Vector3(3.5, 7.74, -66), "power": 0.4, "lift": 2.2, "reel_frames": 80, "swing": Vector3(900.0, 200.0, 180.0), "practice": true, "track": true, "look": "velocity", "min_speed": 15.0, "frames": 150},
	"hud_09_practice_range_gantry": {"level": "range", "from": Vector3(0, 1, -50), "aim": Vector3(4, 8.64, -70), "power": 0.4, "lift": 2.2, "reel_frames": 110, "swing": Vector3(900.0, 250.0, 180.0), "practice": true, "track": true, "look": "velocity", "min_speed": 15.0, "frames": 150},
	"touch_01_sluice_gate_sentry_beam": {"level": "l01", "from": Vector3(-8, 1, -30), "aim": Vector3(-22, 3.6, -46), "latch": false, "power": 0.3, "frames": 40},
	"touch_02_overflow_causeway_gantry": {"level": "l03", "from": Vector3(0, 1, -26), "aim": Vector3(-12, 8.54, -38), "power": 0.2, "lift": 2.2, "reel_frames": 60, "swing": Vector3(-800.0, 250.0, 480.0), "practice": true, "track": true, "look": "velocity", "min_speed": 15.0, "frames": 150},
	"touch_03_crane_yard_arm": {"level": "l05", "from": Vector3(0, 1, -10), "aim": Vector3(5, 14.99, -22), "power": 0.2, "lift": 1.5, "reel": true, "practice": true, "track": true, "look": "velocity", "frames": 90},
	"touch_04_crucible_kiln_reel": {"level": "l06", "from": Vector3(0, 1, -14), "aim": Vector3(4, 9.44, 1.5), "power": 0.2, "lift": 2.2, "reel_frames": 60, "swing": Vector3(700.0, 150.0, 220.0), "practice": true, "track": true, "look": "velocity", "min_speed": 15.0, "frames": 150},
}


## The logotype: the brand mark beside the DEADWEIGHT wordmark, drawn the way the title screen
## draws it (paper "DEAD", amber "WEIGHT", cyan measuring rule) but without the spool captions.
## Glyphs are placed one by one at a computed advance, so tracking holds at every size.
class Lockup extends Control:
	var mark: Texture2D
	var tagline: bool = false
	const TRACK: float = 0.22

	static func logo_font() -> Font:
		var variation := FontVariation.new()
		variation.base_font = ThemeDB.fallback_font
		variation.variation_embolden = 1.35
		variation.variation_transform = Transform2D(Vector2(1.18, 0.0), Vector2(0.0, 1.0), Vector2.ZERO)
		return variation

	func _draw() -> void:
		var fs: float = _fit_font_size()
		var font: Font = logo_font()
		var px: int = int(round(fs))
		var mark_side: float = fs * 2.4
		if mark != null:
			draw_texture_rect(mark, Rect2(0.0, (size.y - mark_side) * 0.5, mark_side, mark_side), false)
		var x0: float = mark_side + fs * 0.25
		var cap: float = font.get_ascent(px) * 0.72
		var word_block: float = cap + fs * 0.17 + fs * 0.28 * float(tagline)
		var baseline: float = (size.y - word_block) * 0.5 + cap
		# A soft shadow keeps the wordmark legible on bright sky and on a light page.
		_draw_glyphs(font, px, fs, "DEADWEIGHT", x0 + fs * 0.03, baseline + fs * 0.04, Color(0.03, 0.04, 0.05, 0.6))
		var dead_end: float = _draw_glyphs(font, px, fs, "DEAD", x0, baseline, UiTheme.PAPER)
		_draw_glyphs(font, px, fs, "WEIGHT", dead_end, baseline, UiTheme.AMBER)
		var word_w: float = _word_advance(font, px, fs, "DEADWEIGHT")
		var rule_y: float = baseline + fs * 0.17
		draw_line(Vector2(x0, rule_y), Vector2(x0 + word_w, rule_y), Color(UiTheme.CYAN, 0.7), maxf(1.5, fs * 0.03), true)
		for i in 21:
			var tx: float = x0 + word_w * float(i) / 20.0
			var tall: bool = i % 5 == 0
			draw_line(Vector2(tx, rule_y), Vector2(tx, rule_y + fs * (0.09 if tall else 0.045)), Color(UiTheme.CYAN, 0.7 if tall else 0.4), maxf(1.0, fs * 0.03), true)
		if tagline:
			var label_font: Font = UiTheme.font("label")
			var label_size: int = maxi(9, int(round(fs * 0.2)))
			draw_string(label_font, Vector2(x0, rule_y + fs * 0.34), TAGLINE, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, Color(UiTheme.MUTED, 0.95))

	## Draws each glyph at its own advance and returns the x where the run ends.
	func _draw_glyphs(font: Font, px: int, fs: float, text: String, x: float, baseline: float, color: Color) -> float:
		for index in text.length():
			var ch: String = text.substr(index, 1)
			draw_string(font, Vector2(x, baseline), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)
			x += _advance(font, px, fs, ch)
		return x

	func _advance(font: Font, px: int, fs: float, ch: String) -> float:
		return font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + fs * TRACK

	func _word_advance(font: Font, px: int, fs: float, text: String) -> float:
		var total: float = 0.0
		for index in text.length():
			total += _advance(font, px, fs, text.substr(index, 1))
		return total

	## Font size at which the mark plus wordmark fill the control's width (and height, if tighter).
	func _fit_font_size() -> float:
		var font: Font = logo_font()
		var fs: float = size.x / 11.0
		for step in 4:
			var total: float = fs * 2.4 + fs * 0.25 + _word_advance(font, int(round(fs)), fs, "DEADWEIGHT")
			fs *= size.x / total
		return minf(fs, size.y / 2.6)


var _mark: Texture2D
var _saved: int = 0


func _initialize() -> void:
	var only: String = ""
	var shot: String = ""
	var probe: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			only = argument.substr(7)
		elif argument.begins_with("--shot="):
			shot = argument.substr(7)
		elif argument.begins_with("--probe"):
			probe = "probe"
	_mark = ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(MARK_PATH)))
	if not shot.is_empty() or probe == "probe":
		_run_live.call_deferred(shot, probe == "probe")
	else:
		_run.call_deferred(only)


func _run(only: String) -> void:
	for job: Dictionary in JOBS:
		if not only.is_empty() and not str(job["file"]).contains(only):
			continue
		await _render(job)
	print("STORE_ART saved %d file(s)" % _saved)
	quit(0)


## Runs one live shot through the real game (main.tscn) and saves the root viewport as
## store/art/screenshots/<name>_<width>x<height>.png. With probe the level is only listed.
func _run_live(name: String, probe: bool) -> void:
	var shot: Dictionary = LIVE_SHOTS.get(name, {})
	if shot.is_empty() and not probe:
		push_error("STORE_ART no live shot named %s" % name)
		quit(1)
		return
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var level_id: String = str(shot.get("level", "l01"))
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--level="):
			level_id = argument.substr(8)
	args.append("--level=%s" % level_id)
	# Practice removes the enemies, so a hound bite cannot knock a swing off its line. Only the swing and reel
	# shots use it; the hound chase and the sentry beam keep their enemies.
	if bool(shot.get("practice", false)):
		args.append("--practice")
	var main: Node = MainScene.instantiate()
	main.set("override_args", args)
	root.add_child(main)
	# A --capture run never pauses on focus loss; an off-screen window can lose focus, so mirror that.
	main.set("_capture", true)
	# Achievement toasts would sit in the frame, so every achievement is marked as already earned in
	# the temp profile (the profile is never the player's save; see --profile in tools/capture-store-art.ps1).
	var profile: RefCounted = main.get("profile")
	for achievement_id: String in Achievements.ids():
		profile.call("unlock_achievement", achievement_id)
	if not await _wait_for_state(main, "playing"):
		push_error("STORE_ART %s never reached play" % name)
		quit(1)
		return
	# Practice is only a way to clear enemies for a clean swing; the store frame must not say so. The HUD
	# resets the label's visibility every frame, so it is hidden through its modulate instead.
	if bool(shot.get("practice", false)):
		var practice_label: Variant = main.get("hud").get("_practice_label")
		if practice_label is CanvasItem:
			(practice_label as CanvasItem).modulate.a = 0.0
	await _frames(SETTLE_FRAMES)
	var player: RigidBody3D = main.get("player")
	var tether: Node3D = main.get("tether")
	var level: Node3D = main.get("level")
	if probe:
		_print_probe(level)
		quit(0)
		return
	var from: Vector3 = level.get("spawn_position")
	if shot["from"] is Vector3:
		from = shot["from"]
	# "latch": false casts at a target (an enemy, say) and captures the line in flight.
	var wait_latch: bool = bool(shot.get("latch", true))
	var aim: Vector3 = shot["aim"]
	if wait_latch:
		aim = _nearest_anchor(aim) + Vector3(0.0, float(shot.get("lift", 0.0)), 0.0)
	var latched: bool = await _cast_at(player, tether, from, aim, float(shot.get("power", 1.0)), wait_latch)
	print("STORE_ART %s latched=%s anchor=%s" % [name, str(latched), str(aim)])
	if wait_latch and not latched:
		push_error("STORE_ART %s did not latch; adjust its aim, power or lift" % name)
	# Reel first (shortens the line to a pendulum length), then launch sideways so the line goes taut.
	if wait_latch:
		tether.reeling = true
		await _frames(int(shot.get("reel_frames", 0)))
		tether.reeling = bool(shot.get("reel", false))
	var swing: Vector3 = shot.get("swing", Vector3.ZERO)
	if swing != Vector3.ZERO:
		player.apply_central_impulse(swing)
	# Track: the view follows its target once latched (or from the cast, for a cast in flight). Capture early
	# once the swing is fast and taut (min_speed m/s with at least AMBER_TENSION newtons), once a hound is
	# near (near m), otherwise after "frames" physics frames.
	var track: bool = bool(shot.get("track", false))
	var look: String = str(shot.get("look", "aim"))
	var look_up: float = float(shot.get("look_up", 15.0))
	var min_speed: float = float(shot.get("min_speed", 0.0))
	var near: float = float(shot.get("near", 0.0))
	# view: the point an "aim" look follows, when it is not the plate (the l06 shot keeps the teapot pool in frame).
	var view: Vector3 = Vector3(shot.get("view", aim))
	for step in int(shot.get("frames", 60)):
		await process_frame
		if track and (tether.anchored or not wait_latch):
			_follow(player, look, view, look_up)
		var speed: float = player.linear_velocity.length()
		if min_speed > 0.0 and speed >= min_speed and tether.tension >= Tether.AMBER_AT_TENSION:
			print("STORE_ART swing at %.1f m/s, %.0f N, after %d frames" % [speed, tether.tension, step])
			break
		if near > 0.0 and _hound_within(player, near):
			print("STORE_ART hound within %.1f m after %d frames" % [near, step])
			break
	print("STORE_ART %s captured at %.1f m/s, %.0f N, state %s, health %.0f, at %s, line %.1f m, grounded %s" % [name, player.linear_velocity.length(), tether.tension, str(main.get("state")), float(player.get("health")), str(player.global_position), tether.line_length, str(player.get("grounded"))])
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path(SCREENSHOT_DIR + "%s_%dx%d.png" % [name, image.get_width(), image.get_height()])
	var error: Error = image.save_png(path)
	print("STORE_ART %s %dx%d result=%d" % [path, image.get_width(), image.get_height(), error])
	quit(0 if error == OK else 1)


func _wait_for_state(main: Node, wanted: String) -> bool:
	for index in LIVE_TIMEOUT_FRAMES:
		if str(main.get("state")) == wanted:
			return true
		await process_frame
	return false


## Lists what a level offers, so anchors and aims can be chosen from real positions.
func _print_probe(level: Node3D) -> void:
	print("PROBE spawn %s" % str(level.get("spawn_position")))
	for node: Node in get_nodes_in_group("anchor"):
		var body := node as Node3D
		if body != null:
			print("PROBE anchor %s" % str(body.global_position))
	for node: Node in get_nodes_in_group("enemies"):
		var body := node as Node3D
		if body != null:
			print("PROBE enemy %s %s" % [node.name, str(body.global_position)])


## The anchor plate nearest to a point, so a shot can name a rough spot instead of an exact plate.
func _nearest_anchor(point: Vector3) -> Vector3:
	var found: Vector3 = _nearest_body("anchor", point, "")
	return found if found.is_finite() else point


## The position of the node nearest to a point in a group (of one enemy kind when kind is set). Returns
## INF when the group has no such node, so a caller can tell "none" from "at the point".
func _nearest_body(group: String, point: Vector3, kind: String) -> Vector3:
	var best: Vector3 = Vector3.INF
	var best_distance: float = INF
	for node: Node in get_nodes_in_group(group):
		var body := node as Node3D
		if body == null or (not kind.is_empty() and str(node.get("kind")) != kind):
			continue
		var distance: float = body.global_position.distance_to(point)
		if distance < best_distance:
			best_distance = distance
			best = body.global_position
	return best


## True when the nearest hound is within radius metres of the player.
func _hound_within(player: RigidBody3D, radius: float) -> bool:
	var hound: Vector3 = _nearest_body("enemies", player.global_position, "hound")
	return hound.is_finite() and hound.distance_to(player.global_position) <= radius


## Points the view for a track shot: "velocity" looks along the swing, "hound" follows the nearest hound,
## anything else follows aim.
func _follow(player: RigidBody3D, look: String, aim: Vector3, look_up: float) -> void:
	match look:
		"velocity":
			_look_along(player, look_up)
		"hound":
			var hound: Vector3 = _nearest_body("enemies", player.global_position, "hound")
			if hound.is_finite():
				_look_at(player, hound)
		_:
			_look_at(player, aim)


## Looks along the horizontal velocity with the pitch set to look_up degrees, so the line rises from the rod
## into the upper frame and the level shows below. Keeps the last heading while the weight is nearly still.
func _look_along(player: RigidBody3D, look_up: float) -> void:
	var planar := Vector3(player.linear_velocity.x, 0.0, player.linear_velocity.z)
	if planar.length() < 1.0:
		return
	var direction: Vector3 = planar.normalized()
	player.yaw = atan2(-direction.x, -direction.z)
	player.pitch = deg_to_rad(look_up)
	player.apply_look(Vector2.ZERO)


## Renders one job into a SubViewport of its size and saves the result.
func _render(job: Dictionary) -> void:
	var size_px: Vector2i = job["size"]
	var view := SubViewport.new()
	view.size = size_px
	view.own_world_3d = true
	view.transparent_bg = bool(job.get("transparent", false))
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var level_id: String = str(job["level"])
	var player: RigidBody3D = null
	var tether: Node3D = null
	var level: Node3D = null
	if not level_id.is_empty():
		var stage := Node3D.new()
		view.add_child(stage)
		player = Player.new()
		stage.add_child(player)
		player.freeze = true
		level = Catalog.create(level_id)
		stage.add_child(level)
		level.set("quality", 2)
		level.call("build", player, bool(job["practice"]))
		player.reset_at(level.get("spawn_position"))
		tether = Tether.new()
		stage.add_child(tether)
		tether.bind(player)
		_add_camera(stage, job)
		if str(job["mode"]) == "still":
			player.rod_model.hide()
			player.gun_model.hide()
	await _frames(SETTLE_FRAMES)
	if str(job["mode"]) == "cast":
		player.freeze = false
		player.active = true
		tether.active = true
		level.set_active(true)
		await _cast_at(player, tether, job["from"], job["aim"], float(job.get("power", 1.0)))
	var overlay := Control.new()
	overlay.size = Vector2(size_px)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(overlay)
	_compose(overlay, str(job["layout"]), Vector2(size_px))
	# The SubViewport can still be filling in on the first frames, so wait for several draws.
	await _frames(12)
	await RenderingServer.frame_post_draw
	await _frames(2)
	await RenderingServer.frame_post_draw
	var image: Image = view.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path(ART_DIR + str(job["file"]))
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var error: Error = image.save_png(path)
	print("STORE_ART %s %dx%d result=%d" % [path, image.get_width(), image.get_height(), error])
	if error == OK:
		_saved += 1
	view.queue_free()
	await process_frame


func _add_camera(stage: Node3D, job: Dictionary) -> void:
	var cam := Camera3D.new()
	cam.far = 1000.0
	cam.fov = float(job["fov"])
	stage.add_child(cam)
	cam.global_position = job["cam"]
	cam.look_at(job["look"], Vector3.UP)
	cam.make_current()


func _log_event(event: String) -> void:
	print("STORE_ART tether event %s" % event)


## Turns the player's view (yaw and pitch, as the mouse would) so the camera faces a world point.
func _look_at(player: RigidBody3D, point: Vector3) -> void:
	var camera: Camera3D = player.camera
	var direction: Vector3 = (point - camera.global_position).normalized()
	player.yaw = atan2(-direction.x, -direction.z)
	player.pitch = asin(clampf(direction.y, -1.0, 1.0))
	player.apply_look(Vector2.ZERO)


## Places the player at "from", aims the view at "aim", charges a full cast and releases it. Waits
## until the weight latches on an anchor plate or CAST_TIMEOUT_FRAMES pass. Returns whether it latched.
## Counts physics frames, so a live run at --fixed-fps 60 is the same every time.
func _cast_at(player: RigidBody3D, tether: Node3D, from: Vector3, aim: Vector3, power: float, wait_latch: bool = true) -> bool:
	player.reset_at(from)
	await _frames(SETTLE_FRAMES)
	if not tether.event_happened.is_connected(_log_event):
		tether.event_happened.connect(_log_event)
	_look_at(player, aim)
	await _frames(6)
	tether.begin_charge()
	# Charge rises with physics steps, so "power" maps directly to a number of frames.
	await _frames(int(round(clampf(power, 0.0, 1.0) * float(tether.get("charge_time")) * LIVE_FPS)))
	tether.release_cast()
	if not wait_latch:
		return false
	var waited: int = 0
	while not tether.anchored and waited < CAST_TIMEOUT_FRAMES:
		await process_frame
		waited += 1
	print("STORE_ART cast latched=%s after %d frames" % [str(tether.anchored), waited])
	return bool(tether.anchored)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


## The overlay for a layout: a soft scrim where text sits, then the lockup in its own box.
func _compose(overlay: Control, layout: String, size_px: Vector2) -> void:
	var lockup := Lockup.new()
	lockup.mark = _mark
	var box := Rect2(Vector2.ZERO, size_px)
	match layout:
		"header":
			_scrim(overlay, Vector2(0.0, 0.5), Vector2(0.68, 0.5), 0.72)
			box = Rect2(size_px.x * 0.05, size_px.y * 0.18, size_px.x * 0.56, size_px.y * 0.64)
			lockup.tagline = true
		"small":
			_scrim(overlay, Vector2(0.0, 0.5), Vector2(1.0, 0.5), 0.9)
			box = Rect2(size_px.x * 0.06, size_px.y * 0.16, size_px.x * 0.88, size_px.y * 0.68)
		"main":
			_scrim(overlay, Vector2(0.0, 0.2), Vector2(0.58, 0.2), 0.7)
			box = Rect2(size_px.x * 0.05, size_px.y * 0.08, size_px.x * 0.44, size_px.y * 0.34)
			lockup.tagline = true
		"vertical":
			_scrim(overlay, Vector2(0.5, 1.0), Vector2(0.5, 0.5), 0.85)
			box = Rect2(size_px.x * 0.08, size_px.y * 0.74, size_px.x * 0.84, size_px.y * 0.2)
			lockup.tagline = true
		"capsule":
			_scrim(overlay, Vector2(0.5, 1.0), Vector2(0.5, 0.55), 0.85)
			box = Rect2(size_px.x * 0.08, size_px.y * 0.8, size_px.x * 0.84, size_px.y * 0.14)
		"feature":
			_scrim(overlay, Vector2(0.0, 0.5), Vector2(0.62, 0.5), 0.75)
			box = Rect2(size_px.x * 0.05, size_px.y * 0.2, size_px.x * 0.52, size_px.y * 0.6)
			lockup.tagline = true
		"logo":
			box = Rect2(size_px.x * 0.1, size_px.y * 0.3, size_px.x * 0.8, size_px.y * 0.4)
			lockup.tagline = true
		_:
			return
	lockup.position = box.position
	lockup.size = box.size
	overlay.add_child(lockup)


## A dark gradient from the "from" edge (UV) to the "to" point, for legibility over the sky.
func _scrim(overlay: Control, from: Vector2, to: Vector2, strength: float) -> void:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.02, 0.04, 0.05, strength), Color(0.02, 0.04, 0.05, 0.0)])
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 256
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = from
	texture.fill_to = to
	var rect := TextureRect.new()
	rect.texture = texture
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.position = Vector2.ZERO
	rect.size = overlay.size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(rect)
