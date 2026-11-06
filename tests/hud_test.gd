extends SceneTree
## HUD checks: touch routing, lifecycle release, state readouts, medal target, telemetry switch,
## banner, six viewport layouts (outside the screen, overlaps, also mirrored for left-handed),
## safe-area insets, G7 markers (projection on and off screen), damage arcs, vignettes, touch
## options (scale, opacity, mirror) and, when run as `-- --shots` with a windowed renderer, the
## G7 captures in .tools/captures/G7.

const Catalog = preload("res://scripts/level_catalog.gd")

const LAYOUT_SIZES := [
	Vector2i(1280, 720),
	Vector2i(1280, 800),
	Vector2i(960, 720),
	Vector2i(800, 450),
	Vector2i(2400, 1080),
	Vector2i(800, 1280),
]
const EDGE_TOLERANCE := 0.5
const OVERLAP_TOLERANCE := 1.0
const SETTLE_FRAMES := 3
const CAPTURE_DIR := "res://.tools/captures/G7"

## A raid in progress with every element populated, so the layout checks see the widest text.
const FULL_STATE := {
	"health": 22.0, "speed": 17.5, "airborne": true, "tension": 12000.0, "line_length": 9.4,
	"reel_state": "LOCKED / TAUT", "charge": 0.6, "weapon": "ROD", "ammo": 6, "reserve": 24,
	"reloading": false, "loot": 2, "total_loot": 3, "bonus": 1, "total_bonus": 2,
	"time": 74.2, "par_silver": 90.0, "par_gold": 60.0,
	"hint": "CASE SECURED  /  2 OF 3  /  extraction banks your haul",
	"hitmarker": 0.6, "danger": 0.4, "extraction_inside": false, "alert": true, "practice": true,
}

## Extraction under way with the sidearm drawn and reloading.
const EXTRACT_STATE := {
	"health": 80.0, "speed": 3.0, "airborne": false, "tension": 0.0, "line_length": 0.0,
	"reel_state": "FREE SPOOL", "charge": 0.0, "weapon": "SIDEARM", "ammo": 4, "reserve": 12,
	"reloading": true, "loot": 3, "total_loot": 3, "bonus": 2, "total_bonus": 2,
	"time": 121.5, "par_silver": 150.0, "par_gold": 110.0,
	"hint": "HOLD POSITION  /  extraction in 3.2s", "hitmarker": 0.0, "danger": 0.0,
	"extraction_inside": true, "extraction": 0.45, "extraction_ready": true, "practice": false,
}

var _hud: CanvasLayer
var _camera: Camera3D
var _failures := 0
var _actions: Array[String] = []
var _looks: Array[Vector2] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("HUD TEST: " + message)


func _record_action(action: String, pressed: bool) -> void:
	_actions.append(action + (":down" if pressed else ":up"))


func _record_look(delta: Vector2) -> void:
	_looks.append(delta)


func _touch(index: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	root.push_input(event, true)


func _drag(index: int, position: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = position
	event.relative = relative
	root.push_input(event, true)


func _pad_center(action: String) -> Vector2:
	var pad: Control = _hud._touch_pads[action]
	return pad.global_position + pad.size * 0.5


func _frames(count: int) -> void:
	for i in range(count):
		await process_frame


## Full profile settings for apply_settings: the defaults, with the given keys changed.
func _settings(changes: Dictionary) -> Dictionary:
	var settings: Dictionary = {"show_telemetry": true, "touch_scale": 1.0, "touch_opacity": 0.8, "touch_left_handed": false}
	settings.merge(changes, true)
	return settings


func _run() -> void:
	Input.emulate_mouse_from_touch = false
	Input.use_accumulated_input = false
	_hud = load("res://scripts/hud.gd").new()
	root.add_child(_hud)
	_hud.touch_enabled = true
	_hud.action_requested.connect(_record_action)
	_hud.look_requested.connect(_record_look)
	await process_frame
	_hud._reflow()
	_hud.show_game()

	await _test_touch_routing()
	_test_state_readouts()
	_test_medal_target_and_telemetry()
	_test_banner_and_lifecycle()
	await _test_markers_and_arcs()
	await _test_touch_options()
	await _test_layouts()
	await _test_safe_area()

	if "--shots" in OS.get_cmdline_user_args():
		await _capture_shots()

	_hud.queue_free()
	_camera.queue_free()
	await process_frame
	if _failures == 0:
		print("HUD TESTS PASSED: two-thumb aim, finger reuse, focus/hide release, state readouts, captions, vignettes, medal target, telemetry, banner, objective markers on and off screen, hint-band fade and backing, edge arrow spacing, distance labels, damage arcs, touch scale, opacity and left-handed mirror, six layouts (also left-handed), safe area")
	else:
		push_error("HUD TESTS FAILED: %d checks" % _failures)
	quit(0 if _failures == 0 else 1)


# --- Touch routing and lifecycle release ---------------------------------------------------------

func _test_touch_routing() -> void:
	var stick: Control = _hud._stick
	var move_position: Vector2 = stick.global_position + stick.size * 0.5 + Vector2(42, -15)
	var cast_position: Vector2 = _pad_center("cast")
	_touch(0, move_position, true)
	_touch(1, cast_position, true)
	await process_frame
	_expect(_hud.move_vector.x > 0.4, "left thumb moves while right thumb charges")
	_expect(_actions.count("cast:down") == 1, "cast begins once")
	_drag(1, cast_position + Vector2(-16, -12), Vector2(-16, -12))
	await process_frame
	_expect(_looks.size() == 1 and _looks[0] == Vector2(-16, -12), "held cast still allows aiming")
	_touch(1, cast_position + Vector2(-16, -12), false)
	await process_frame
	_expect(_actions.count("cast:up") == 1, "cast releases once")
	_expect(_hud.move_vector.x > 0.4, "releasing cast preserves other finger movement")

	var reel_position: Vector2 = _pad_center("reel")
	_touch(1, reel_position, true)
	_drag(1, reel_position + Vector2(20, 6), Vector2(20, 6))
	await process_frame
	_expect(_actions.count("reel:down") == 1, "reused finger starts reeling")
	_expect(_looks.size() == 2 and _looks[1] == Vector2(20, 6), "held reel still allows aiming")
	_hud.set_active(false)
	_expect(_actions.count("reel:up") == 1, "hiding the HUD releases a held reel")
	_expect(_hud.move_vector == Vector2.ZERO, "hiding the HUD clears movement")
	_expect(_hud._touch_roles.is_empty(), "hiding the HUD clears all touch owners")
	_touch(0, move_position, false)
	_touch(1, reel_position, false)
	await process_frame
	_expect(_actions.count("reel:up") == 1, "late touch releases do not duplicate release actions")

	_hud.show_game()
	_touch(1, _pad_center("cast"), true)
	await process_frame
	_hud.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect(_actions.count("cast:up") == 2, "focus loss releases charged cast")
	_expect(_hud._touch_roles.is_empty(), "focus loss clears touch owners")
	_touch(1, _pad_center("cut"), true)
	_touch(1, _pad_center("cut"), false)
	await process_frame
	_expect(_actions.count("cut:down") == 1 and _actions.count("cut:up") == 1, "finger reuse works after focus release")


# --- State readouts ------------------------------------------------------------------------------

func _test_state_readouts() -> void:
	_hud.update_state({"health": 32.0, "tension": 14000.0, "weapon": "SIDEARM", "ammo": 6, "reserve": 24, "extraction_inside": true, "loot": 3, "extraction": 0.5})
	_expect(_hud._extract_bar.visible and is_equal_approx(_hud._extract_bar.value, 0.5), "extraction progress appears with sufficient salvage")
	_expect(is_equal_approx(_hud._tension_bar.value, 0.56), "tension uses 25 kN gauge range")
	_expect(_hud._touch_pads["cast"].caption == "FIRE", "sidearm has a clear fire action")
	_expect(_hud._ammo_label.text == "06 / 24", "sidearm shows ammo and reserve")
	_expect(not _hud._low_health, "32 health is not low")
	_hud.update_state({"health": 20.0})
	_expect(_hud._low_health and _hud._health_label.text == "CONDITION   020", "low health starts the pulse")
	_hud.update_state({"health": 80.0})
	_expect(not _hud._low_health, "healthy condition stops the pulse")
	_hud.update_state({"bonus": 1, "total_bonus": 2})
	_expect(_hud._bonus_label.text == "BONUS   1 / 2", "bonus caches read as found / total")
	_hud.update_state({"bonus": 0, "total_bonus": 0})
	_expect(_hud._bonus_label.text == "BONUS   NONE THIS RAID", "a level without bonus caches says so")
	_hud.update_state({"loot": 1, "total_loot": 3, "extraction_inside": true})
	_expect(not _hud._extract_bar.visible, "extraction bar stays hidden until every case is recovered")
	_expect(_hud._mission_label.text == "RECOVER ALL CASES TO EXTRACT", "inside without all cases gives the right objective")

	# Touch captions follow the state.
	_hud.update_state({"reloading": true, "weapon": "SIDEARM", "reel_state": "REEL STALLED"})
	_expect(_hud._touch_pads["reload"].caption == "WAIT" and _hud._touch_pads["reel"].caption == "STALL", "captions: reload reads WAIT while reloading, the reel reads STALL when stalled")
	_hud.update_state({"reloading": false, "reel_state": "LOCKED / TAUT"})
	_expect(_hud._touch_pads["reload"].caption == "LOAD" and _hud._touch_pads["reel"].caption == "REEL" and _hud._touch_pads["lock"].caption == "FREE", "captions go back to LOAD, REEL and FREE")

	# Vignettes: danger from low health or a hit, speed from high speed.
	_hud.update_state({"danger": 0.5, "speed": 24.0})
	_expect(absf(_hud._vignette.strength - 0.5) < 0.001 and absf(_hud._speed_vignette.strength - 1.0) < 0.001, "vignettes: danger and full speed both show")
	_hud.update_state({"speed": 5.0})
	_expect(_hud._speed_vignette.strength == 0.0 and _hud._vignette.strength == 0.0, "vignettes: slow and unhurt show nothing")


# --- Medal target and telemetry ------------------------------------------------------------------

func _test_medal_target_and_telemetry() -> void:
	_hud.show_telemetry = true
	_hud.update_state({"time": 74.0, "par_silver": 90.0, "par_gold": 60.0, "tension": 14000.0, "line_length": 9.4, "reel_state": "LOCKED / TAUT", "charge": 0.0, "weapon": "ROD"})
	_expect(_hud._target_label.text == "NEXT SILVER   01:30", "past gold par the next target is silver")
	_expect(_hud._line_label.text.contains("kN"), "telemetry on shows line tension numbers")
	_expect(_hud._rod_label.text == "LOCKED / TAUT" and not _hud._reticle_state.visible, "the rod panel is the one readout of the reel state; the reticle shows no state word while nothing tracks")
	_hud.update_state({"time": 50.0, "par_silver": 90.0, "par_gold": 60.0})
	_expect(_hud._target_label.text == "NEXT GOLD   01:00", "before gold par the next target is gold")
	_hud.update_state({"time": 100.0, "par_silver": 90.0, "par_gold": 60.0})
	_expect(_hud._target_label.text == "BRONZE   /   EXTRACT TO BANK", "past silver par the target is bronze")

	_hud.show_telemetry = false
	_hud.update_state({"time": 74.0, "par_silver": 90.0, "par_gold": 60.0, "tension": 14000.0, "line_length": 9.4, "reel_state": "LOCKED / TAUT", "charge": 0.5, "weapon": "ROD", "speed": 17.5})
	_expect(not _hud._line_label.text.contains("kN") and not _hud._line_label.text.contains("M LINE"), "telemetry off hides line numbers")
	_expect(_hud._rod_label.text == "CHARGING", "telemetry off shows charging without a percentage")
	_expect(not _hud._speed_label.text.contains("M/S"), "telemetry off hides the speed number")
	_expect(_hud._target_label.text == "NEXT SILVER   01:30", "the medal target is shown regardless of telemetry")
	_hud.update_state({"alert": true, "reel_state": "LOCKED / TAUT"})
	_expect(_hud._reticle_state.visible and _hud._reticle_state.text == "TRACKED", "an alert shows TRACKED at the reticle")
	_expect(_hud._reticle_state.get_theme_color("font_color") == _hud.RED, "the TRACKED word is red")
	_expect(_hud._rod_label.text == "LOCKED / TAUT" and _hud._rod_label.get_theme_color("font_color") == _hud.PAPER, "the alert leaves the rod panel as the single state readout")
	_hud.update_state({"alert": false})
	_expect(not _hud._reticle_state.visible, "the TRACKED word goes when the alert clears")
	_hud.apply_settings({"show_telemetry": true})
	_expect(_hud.show_telemetry, "apply_settings reads show_telemetry from the profile settings")


# --- Banner and lifecycle ------------------------------------------------------------------------

func _test_banner_and_lifecycle() -> void:
	_hud.show_banner("EXTRACTED", "Hold for six seconds", 2.0, "cyan")
	_expect(_hud._banner_title.text == "EXTRACTED" and _hud._banner.visible, "banner shows its title")
	_expect(_hud._banner_subtitle.visible and _hud._banner_subtitle.text == "Hold for six seconds", "banner shows its subtitle")
	_hud.show_banner("SECURED", "", 1.0, "red")
	_expect(not _hud._banner_subtitle.visible, "a banner without a subtitle hides that line")
	_hud.set_active(false)
	_expect(not _hud._game.visible and not _hud._banner.visible, "inactive HUD hides its in-game layer and banner")
	_hud.show_game()
	_expect(_hud._game.visible and _hud._touch.visible, "active touch HUD shows its controls")
	_hud.show_menu()
	_expect(not _hud._game.visible, "show_menu hides the in-game layer")
	_hud.show_game()


# --- Objective markers and damage arcs (G7) -------------------------------------------------------

func _test_markers_and_arcs() -> void:
	root.size = Vector2i(1280, 720)
	_camera = Camera3D.new()
	_camera.current = true
	root.add_child(_camera)
	await _frames(2)
	_hud.set_camera(_camera)
	var view: Vector2 = root.get_visible_rect().size
	var centre: Vector2 = view * 0.5
	var bounds: Rect2 = _hud.marker_bounds()
	# Focal length in pixels for the vertical field of view, so an offset can be checked exactly.
	var focal: float = (view.y * 0.5) / tan(deg_to_rad(_camera.fov * 0.5))

	# Projection on screen: straight ahead is the centre, and 2 m right at 20 m lands where the lens puts it.
	var ahead: Dictionary = _hud.project_marker(Vector3(0.0, 0.0, -20.0))
	var ahead_point: Vector2 = ahead["point"]
	_expect(bool(ahead["on_screen"]) and ahead_point.distance_to(centre) < 0.5, "projection: a marker straight ahead lands at the screen centre")
	var right_marker: Dictionary = _hud.project_marker(Vector3(2.0, 0.0, -20.0))
	var right_point: Vector2 = right_marker["point"]
	_expect(bool(right_marker["on_screen"]) and absf(right_point.x - (centre.x + focal * 0.1)) < 0.5 and absf(right_point.y - centre.y) < 0.5, "projection: a marker 2 m right at 20 m lands at the lens position")
	_expect(right_point.distance_to(_camera.unproject_position(Vector3(2.0, 0.0, -20.0))) < 0.01, "projection matches Camera3D.unproject_position")

	# Projection off screen: far right in front, behind to the right, behind up-left, and dead behind.
	var far_right: Dictionary = _hud.project_marker(Vector3(60.0, 0.0, -10.0))
	var far_point: Vector2 = far_right["point"]
	var far_dir: Vector2 = far_right["direction"]
	_expect(not bool(far_right["on_screen"]) and absf(far_point.x - bounds.end.x) < 0.5 and far_dir.x > 0.99, "off screen: a marker far to the right gets an arrow on the right edge")
	var behind_right: Dictionary = _hud.project_marker(Vector3(10.0, 0.0, 10.0))
	var behind_right_point: Vector2 = behind_right["point"]
	var behind_right_dir: Vector2 = behind_right["direction"]
	_expect(not bool(behind_right["on_screen"]) and absf(behind_right_point.x - bounds.end.x) < 0.5 and behind_right_dir.x > 0.99, "off screen: a marker behind and to the right gets an arrow on the right edge")
	var up_left: Dictionary = _hud.project_marker(Vector3(-10.0, 10.0, 10.0))
	var up_left_point: Vector2 = up_left["point"]
	var up_left_dir: Vector2 = up_left["direction"]
	_expect(not bool(up_left["on_screen"]) and up_left_dir.dot(Vector2(-1.0, -1.0).normalized()) > 0.99, "off screen: a marker behind and up-left points up-left")
	_expect((absf(up_left_point.x - bounds.position.x) < 0.5 or absf(up_left_point.y - bounds.position.y) < 0.5) and bounds.grow(0.5).has_point(up_left_point), "off screen: the up-left arrow sits on the top or left edge")
	var dead_behind: Dictionary = _hud.project_marker(Vector3(0.0, 0.0, 20.0))
	var dead_point: Vector2 = dead_behind["point"]
	var dead_dir: Vector2 = dead_behind["direction"]
	_expect(not bool(dead_behind["on_screen"]) and absf(dead_point.y - bounds.end.y) < 0.5 and dead_dir.y > 0.99, "off screen: a marker dead behind the camera drops to the bottom edge")

	# The marker list: distance in metres, the nearest active objective is next, done markers are inactive.
	_hud.set_objectives([
		{"position": Vector3(0.0, 0.0, -20.0), "kind": "case", "label": "CASE", "active": true},
		{"position": Vector3(-3.0, 0.0, -10.0), "kind": "bonus", "label": "CACHE", "active": true},
		{"position": Vector3(0.0, 0.0, -40.0), "kind": "extract", "label": "EXTRACT", "active": false},
	])
	var markers: Array = _hud._overlay.markers
	_expect(markers.size() == 3, "markers: one marker per objective")
	_expect(is_equal_approx(float(markers[0]["distance"]), 20.0), "markers: the distance is in metres from the camera")
	_expect(bool(markers[1]["next"]) and not bool(markers[0]["next"]) and not bool(markers[2]["next"]), "markers: the nearest active objective is the next one")
	_expect(not bool(markers[2]["active"]) and markers[2]["color"] == _hud.EXTRACT_COLOR, "markers: the extraction gate dims until it is ready and is green-white")
	_expect(markers[1]["color"] == _hud.AMBER and markers[0]["color"] == _hud.CYAN, "markers: bonus is amber and salvage is cyan")

	# Banner band (G7b): a marker behind the hint line fades, one clear of the line stays full strength.
	_hud.update_state({"hint": "DRONE ACQUIRING — FIND COVER"})
	await _frames(2)
	var band_point: Vector2 = Vector2(centre.x, _hud._hint.position.y + 12.0)
	var behind_hint: Vector3 = _camera.project_ray_origin(band_point) + _camera.project_ray_normal(band_point) * 20.0
	_hud.set_objectives([
		{"position": behind_hint, "kind": "case", "label": "CASE", "active": true},
		{"position": Vector3(0.0, 0.0, -20.0), "kind": "case", "label": "CASE", "active": true},
	])
	var faded: Array = _hud._overlay.markers
	_expect(float(faded[0]["band_fade"]) == _hud.BAND_FADE, "banner band: a marker behind the hint line fades")
	_expect(float(faded[1]["band_fade"]) == 1.0, "banner band: a marker clear of the hint line stays at full strength")
	_expect(_hud._overlay.backing.has_area() and _hud._overlay.backing.has_point(band_point), "banner band: the hint line has a backing behind it")
	_hud.update_state({"hint": ""})
	await _frames(1)
	_expect(not _hud._overlay.backing.has_area(), "banner band: no hint means no backing")

	# Edge arrows (G7b): three objectives off the right edge would stack; they come out ARROW_GAP apart.
	_hud.set_objectives([
		{"position": Vector3(60.0, 0.0, -10.0), "kind": "case", "label": "CASE", "active": true},
		{"position": Vector3(60.0, 0.5, -10.0), "kind": "bonus", "label": "CACHE", "active": true},
		{"position": Vector3(60.0, -0.5, -10.0), "kind": "case", "label": "CASE", "active": true},
	])
	var arrows: Array = _hud._overlay.markers
	var arrow_ys: Array[float] = []
	var arrows_on_edge: bool = true
	for arrow: Dictionary in arrows:
		var arrow_point: Vector2 = arrow["point"]
		arrow_ys.append(arrow_point.y)
		arrows_on_edge = arrows_on_edge and absf(arrow_point.x - bounds.end.x) < 0.5
	arrow_ys.sort()
	var smallest_gap: float = INF
	for i in range(1, arrow_ys.size()):
		smallest_gap = minf(smallest_gap, arrow_ys[i] - arrow_ys[i - 1])
	_expect(arrows_on_edge and smallest_gap >= _hud.ARROW_GAP - 0.5, "edge arrows: arrows on one side are spread at least %d px apart (gap %.1f)" % [int(_hud.ARROW_GAP), smallest_gap])
	_expect(arrow_ys[0] >= bounds.position.y - 0.5 and arrow_ys[arrow_ys.size() - 1] <= bounds.end.y + 0.5, "edge arrows: the spread stays inside the marker bounds")

	# Distance labels (G7b): near labels are larger than far ones, and never below 10 px.
	var near_px: int = _hud._overlay.label_size(10.0)
	var far_px: int = _hud._overlay.label_size(300.0)
	_expect(near_px > far_px and far_px == 10 and near_px <= 14, "labels: far objectives get smaller labels, clamped to 10 to 14 px")
	_hud.update_state({"hint": ""})
	_hud.set_objectives([])

	# Damage arcs: the bearing is relative to the camera facing, and each arc lasts about 0.8 s.
	_hud._tick_effects(1.0)
	_hud.damage_from(20.0, "hound", Vector3(10.0, 0.0, -10.0))
	_expect(_hud.arc_count() == 1, "damage: a hit adds one damage arc")
	var arc_bearing: float = _hud._arcs[0]["bearing"]
	_expect(absf(arc_bearing - PI * 0.25) < 0.001, "damage: the arc points 45 degrees right of the facing")
	_hud._tick_effects(0.5)
	_expect(_hud.arc_count() == 1, "damage: the arc is still up at 0.5 s")
	_hud._tick_effects(0.35)
	_expect(_hud.arc_count() == 0, "damage: the arc expires after about 0.8 s")
	_camera.rotation.y = PI * 0.5
	_hud.damage_from(10.0, "sentry", Vector3(-10.0, 0.0, 0.0))
	var facing_bearing: float = _hud._arcs[0]["bearing"]
	_expect(absf(facing_bearing) < 0.001, "damage: a source straight ahead after turning gives a zero bearing")
	_camera.rotation.y = 0.0
	_hud._tick_effects(1.0)
	_hud.damage_from(20.0, "drone", Vector3(0.0, 0.0, -10.0))
	await _frames(20)
	_expect(_hud.arc_count() == 1, "damage: the arc is still up after 20 frames")
	await _frames(80)
	_expect(_hud.arc_count() == 0, "damage: the arc is gone after about a second of frames")


# --- Touch options (G7) --------------------------------------------------------------------------

func _test_touch_options() -> void:
	root.size = Vector2i(1280, 720)
	var canvas: Vector2 = root.get_visible_rect().size
	_hud.apply_settings(_settings({}))
	_hud.show_game()
	await _frames(2)
	_expect(_hud._stick.get_global_rect().get_center().x < canvas.x * 0.5, "right-handed: the stick panel sits on the left")
	_expect(_hud._touch_pads["cast"].get_global_rect().get_center().x > canvas.x * 0.5, "right-handed: the cast pad sits on the right")

	# Left-handed mirror: the stick and the thumb pads move to the other side, pause stays top-right.
	_hud.apply_settings(_settings({"touch_left_handed": true}))
	await _frames(2)
	_expect(_hud._stick.get_global_rect().get_center().x > canvas.x * 0.5, "left-handed: the stick panel moves to the right side of the screen")
	_expect(_hud._touch_pads["cast"].get_global_rect().get_center().x < canvas.x * 0.5, "left-handed: the cast pad moves to the left side")
	_expect(_hud._touch_pads["pause"].get_global_rect().get_center().x > canvas.x * 0.5, "left-handed: the pause pad stays top-right")
	var actions_before: int = _actions.size()
	_touch(2, _pad_center("cast"), true)
	_touch(2, _pad_center("cast"), false)
	await process_frame
	_expect(_actions.size() == actions_before + 2 and _actions[-2] == "cast:down" and _actions[-1] == "cast:up", "left-handed: a touch on the mirrored cast pad fires cast")
	var stick_centre: Vector2 = _hud._stick.get_global_rect().get_center()
	_touch(3, stick_centre + Vector2(42.0, -15.0), true)
	await process_frame
	_expect(_hud.move_vector.length() > 0.4, "left-handed: the stick moves when touched on its new side")
	_touch(3, stick_centre + Vector2(42.0, -15.0), false)
	await process_frame
	_expect(_hud.move_vector == Vector2.ZERO, "left-handed: releasing the stick stops movement")

	# Scale and opacity: the largest scale keeps every control on screen, in both hands.
	for left_handed: bool in [false, true]:
		_hud.apply_settings(_settings({"touch_left_handed": left_handed, "touch_scale": 1.35}))
		await _frames(2)
		var hand: String = "left-handed" if left_handed else "right-handed"
		_expect(absf(_hud._stick.size.x - 158.0 * 1.35) < 0.5, "touch_scale: the stick grows with the setting (" + hand + ")")
		var outside: Array[String] = []
		for action in _hud._touch_pads:
			var rect: Rect2 = _hud._touch_pads[action].get_global_rect()
			if rect.position.x < 0.0 or rect.position.y < 0.0 or rect.end.x > canvas.x or rect.end.y > canvas.y:
				outside.append(action)
		_expect(outside.is_empty(), "touch_scale 1.35 keeps every touch control on screen (" + hand + "): " + str(outside))
	_hud.apply_settings(_settings({"touch_opacity": 0.4}))
	_expect(absf(_hud._touch.modulate.a - 0.4) < 0.001, "touch_opacity sets the touch layer alpha")
	_hud.apply_settings(_settings({"touch_opacity": 5.0}))
	_expect(absf(_hud._touch.modulate.a - 1.0) < 0.001, "touch_opacity is clamped to 1.0")
	_hud.apply_settings(_settings({}))
	_expect(absf(_hud._touch.modulate.a - 0.8) < 0.001 and absf(_hud.touch_scale - 1.0) < 0.001, "apply_settings with defaults restores the touch layout")


# --- Layouts -------------------------------------------------------------------------------------

## Right-handed first, then left-handed: the mirrored layout must fit and not overlap too.
func _test_layouts() -> void:
	await _run_layouts("")
	_hud.apply_settings(_settings({"touch_left_handed": true}))
	await _run_layouts(" (left-handed)")
	_hud.apply_settings(_settings({}))
	_hud.set_active(false)


func _run_layouts(tag: String) -> void:
	# The longest objective wording any catalog level uses, so a long mission is laid out too.
	var longest: Dictionary = {"loot_label": "", "mission": "", "deliver": ""}
	for id: String in Catalog.all_ids():
		var info: Dictionary = Catalog.info(id)
		for key: String in longest:
			if str(info.get(key, "")).length() > str(longest[key]).length():
				longest[key] = str(info.get(key, ""))
	_hud.set_objective_text(longest["loot_label"], longest["mission"], longest["deliver"])
	for dimensions: Vector2i in LAYOUT_SIZES:
		root.size = dimensions
		await _frames(SETTLE_FRAMES)
		_hud._reflow()
		_hud.show_game()
		_hud.update_state(FULL_STATE)
		_hud.show_banner("EXTRACTED", "Hold for six seconds", 2.5, "cyan")
		await _frames(SETTLE_FRAMES)
		var logical_size: Vector2 = root.get_visible_rect().size
		var bounds := Rect2(Vector2.ZERO, logical_size)
		var size_text: String = str(dimensions) + tag

		var outside: Array[String] = []
		_collect_outside(_hud, bounds, outside)
		_expect(outside.is_empty(), "layout %s: every control stays inside the viewport%s" % [size_text, _list_suffix(outside)])

		var overlaps: Array[String] = []
		_collect_overlaps(_layout_group(), overlaps)
		_expect(overlaps.is_empty(), "layout %s: objectives, timer, reticle and the other HUD panels do not overlap%s" % [size_text, _list_suffix(overlaps)])

		for action in _hud._touch_pads:
			var rect: Rect2 = _hud._touch_pads[action].get_rect()
			_expect(rect.position.x >= 0 and rect.position.y >= 0 and rect.end.x <= logical_size.x and rect.end.y <= logical_size.y, action + " touch control stays visible at " + size_text)
		print("HUD layout: physical ", dimensions, " / canvas ", logical_size, tag)
	_hud.set_objective_text("", "", "")


## Every HUD panel the overlap check compares. The touch pads are included on touch screens.
func _layout_group() -> Array[Control]:
	var group: Array[Control] = [_hud._health_panel, _hud._timer_panel, _hud._objective_panel, _hud._reticle, _hud._equipment_panel, _hud._hint, _hud._banner]
	if _hud.touch_enabled:
		for action in _hud._touch_pads:
			group.append(_hud._touch_pads[action])
	return group


## Safe area: on a portrait phone with a notch and a home bar, the top and bottom controls move in.
func _test_safe_area() -> void:
	root.size = Vector2i(800, 1280)
	_hud.touch_enabled = true
	_hud.safe_insets_override = Vector4(0.0, 60.0, 0.0, 40.0)
	_hud._reflow()
	_hud.show_game()
	await _frames(SETTLE_FRAMES)
	var canvas: Vector2 = root.get_visible_rect().size
	_expect(_hud._health_panel.get_global_rect().position.y >= 60.0 - EDGE_TOLERANCE, "safe area: the top panel sits below the top inset")
	_expect(_hud._stick.get_global_rect().end.y <= canvas.y - 40.0 + EDGE_TOLERANCE, "safe area: the touch stick sits above the bottom inset")
	_expect(_hud._touch_pads["pause"].get_global_rect().position.y >= 60.0 - EDGE_TOLERANCE, "safe area: the pause pad sits below the top inset")
	_hud.safe_insets_override = Vector4(-1.0, -1.0, -1.0, -1.0)
	_hud._reflow()
	await _frames(SETTLE_FRAMES)


# --- Shared geometry helpers (same approach as tests/ui_test.gd) ----------------------------------

## Adds every visible control under node whose global rect leaves the bounds.
func _collect_outside(node: Node, bounds: Rect2, out: Array[String]) -> void:
	for child: Node in node.get_children():
		if not (child is Control):
			continue
		var control: Control = child
		if not control.is_visible_in_tree():
			continue
		if not _inside(control.get_global_rect(), bounds):
			out.append(_describe(control))
		_collect_outside(control, bounds, out)


func _inside(rect: Rect2, bounds: Rect2) -> bool:
	return rect.position.x >= bounds.position.x - EDGE_TOLERANCE \
		and rect.position.y >= bounds.position.y - EDGE_TOLERANCE \
		and rect.end.x <= bounds.end.x + EDGE_TOLERANCE \
		and rect.end.y <= bounds.end.y + EDGE_TOLERANCE


## Compares every pair in the group, by global rect.
func _collect_overlaps(controls: Array[Control], out: Array[String]) -> void:
	for i in range(controls.size()):
		for j in range(i + 1, controls.size()):
			var common: Rect2 = controls[i].get_global_rect().intersection(controls[j].get_global_rect())
			if common.size.x > OVERLAP_TOLERANCE and common.size.y > OVERLAP_TOLERANCE:
				out.append("%s / %s" % [_describe(controls[i]), _describe(controls[j])])


func _describe(control: Control) -> String:
	var text: Variant = control.get("text")
	var detail: String = " '%s'" % str(text) if (text is String and not str(text).is_empty()) else ""
	return "%s%s at %s" % [control.get_class(), detail, str(control.get_global_rect())]


func _list_suffix(items: Array[String]) -> String:
	if items.is_empty():
		return ""
	var shown: PackedStringArray = []
	for i in range(mini(3, items.size())):
		shown.append(items[i])
	return " (%s%s)" % ["; ".join(shown), "; ..." if items.size() > 3 else ""]


# --- Captures (only with `-- --shots`, windowed renderer) ----------------------------------------

## A flat fake backdrop, so the translucent HUD panels have something behind them.
class Backdrop extends Control:

	func _draw() -> void:
		var bands := 24
		for i in range(bands):
			var t: float = float(i) / float(bands)
			draw_rect(Rect2(0.0, size.y * t, size.x, size.y / float(bands) + 1.0), Color(0.16 + 0.12 * t, 0.24 + 0.1 * t, 0.27 + 0.08 * t), true)
		draw_rect(Rect2(0.0, size.y * 0.62, size.x, size.y * 0.38), Color(0.09, 0.12, 0.13), true)
		for i in range(14):
			var x: float = fmod(float(i) * 173.0, size.x)
			var h: float = 60.0 + fmod(float(i) * 97.0, 180.0)
			draw_rect(Rect2(x, size.y * 0.62 - h, 90.0 + fmod(float(i) * 41.0, 120.0), h), Color(0.2, 0.26, 0.28), true)


## Four objectives around the camera: two in front, one off the right edge (inactive, the gate),
## one behind so it shows as a bottom-edge arrow.
func _shot_objectives() -> Array:
	return [
		{"position": Vector3(-5.0, 0.0, -18.0), "kind": "case", "label": "CASE", "active": true},
		{"position": Vector3(3.0, 2.5, -26.0), "kind": "bonus", "label": "CACHE", "active": true},
		{"position": Vector3(44.0, 0.0, -16.0), "kind": "extract", "label": "EXTRACT", "active": false},
		{"position": Vector3(4.0, 0.0, 24.0), "kind": "case", "label": "CASE", "active": true},
	]


func _capture_shots() -> void:
	if DisplayServer.get_name() == "headless":
		print("HUD shots skipped: the headless renderer has no framebuffer to capture")
		return
	var dir: String = ProjectSettings.globalize_path(CAPTURE_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var backdrop_layer := CanvasLayer.new()
	backdrop_layer.layer = -1
	root.add_child(backdrop_layer)
	var backdrop := Backdrop.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop_layer.add_child(backdrop)
	_hud.set_camera(_camera)
	_hud.set_objectives(_shot_objectives())
	await _shot(dir, "hud_1280x720_kbm", Vector2i(1280, 720), false, FULL_STATE, "CASE SECURED", "2 OF 3 SALVAGED", Vector3(-8.0, 0.0, -6.0))
	await _shot(dir, "hud_2400x1080_extract", Vector2i(2400, 1080), false, EXTRACT_STATE, "EXTRACTION READY", "Hold for six seconds")
	await _shot(dir, "hud_800x1280_touch", Vector2i(800, 1280), true, FULL_STATE, "CASE SECURED", "2 OF 3 SALVAGED")
	await _shot(dir, "hud_800x1280_touch_lefthanded", Vector2i(800, 1280), true, FULL_STATE, "CASE SECURED", "2 OF 3 SALVAGED", Vector3.INF, true)
	_hud.set_objectives([])
	_hud.apply_settings(_settings({}))
	backdrop_layer.queue_free()
	root.size = Vector2i(1280, 720)


## One capture. arc_from (world space) fires a damage arc just before the frame is taken; left_handed
## mirrors the touch layout for the shot.
func _shot(dir: String, shot_name: String, size: Vector2i, touch: bool, state: Dictionary, title: String, subtitle: String, arc_from: Vector3 = Vector3.INF, left_handed: bool = false) -> void:
	root.size = size
	_hud.touch_enabled = touch
	_hud.apply_settings(_settings({"touch_left_handed": left_handed}))
	_hud.set_active(false)
	_hud.set_active(true)
	_hud.update_state(state)
	_hud.show_banner(title, subtitle, 30.0, "amber")
	if arc_from.is_finite():
		_hud.damage_from(30.0, "hound", arc_from)
	# The arc lasts 0.8 s, so an arc shot is taken sooner than the others.
	await _frames(30 if arc_from.is_finite() else 60)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = dir + "/" + shot_name + ".png"
	var err: int = image.save_png(path)
	_expect(err == OK, "capture saved: " + path)
	print("HUD capture: ", path)
