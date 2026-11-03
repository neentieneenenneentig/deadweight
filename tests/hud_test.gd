extends SceneTree
## HUD checks: touch routing, lifecycle release, state readouts, medal target, telemetry switch,
## banner, six viewport layouts (outside the screen, overlaps), safe-area insets and, when run
## as `-- --shots` with a windowed renderer, the G6 captures in .tools/captures/G6.

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
const CAPTURE_DIR := "res://.tools/captures/G6"

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
	await _test_layouts()
	await _test_safe_area()

	if "--shots" in OS.get_cmdline_user_args():
		await _capture_shots()

	_hud.queue_free()
	await process_frame
	if _failures == 0:
		print("HUD TESTS PASSED: two-thumb aim, finger reuse, focus/hide release, state readouts, medal target, telemetry, banner, six layouts, safe area")
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


# --- Medal target and telemetry ------------------------------------------------------------------

func _test_medal_target_and_telemetry() -> void:
	_hud.show_telemetry = true
	_hud.update_state({"time": 74.0, "par_silver": 90.0, "par_gold": 60.0, "tension": 14000.0, "line_length": 9.4, "reel_state": "LOCKED / TAUT", "charge": 0.0, "weapon": "ROD"})
	_expect(_hud._target_label.text == "NEXT SILVER   01:30", "past gold par the next target is silver")
	_expect(_hud._line_label.text.contains("kN"), "telemetry on shows line tension numbers")
	_expect(_hud._reticle_state.text.contains("kN"), "telemetry on shows tension in the reticle state")
	_hud.update_state({"time": 50.0, "par_silver": 90.0, "par_gold": 60.0})
	_expect(_hud._target_label.text == "NEXT GOLD   01:00", "before gold par the next target is gold")
	_hud.update_state({"time": 100.0, "par_silver": 90.0, "par_gold": 60.0})
	_expect(_hud._target_label.text == "BRONZE   /   EXTRACT TO BANK", "past silver par the target is bronze")

	_hud.show_telemetry = false
	_hud.update_state({"time": 74.0, "par_silver": 90.0, "par_gold": 60.0, "tension": 14000.0, "line_length": 9.4, "reel_state": "LOCKED / TAUT", "charge": 0.5, "weapon": "ROD", "speed": 17.5})
	_expect(not _hud._line_label.text.contains("kN") and not _hud._line_label.text.contains("M LINE"), "telemetry off hides line numbers")
	_expect(not _hud._reticle_state.text.contains("kN"), "telemetry off hides tension in the reticle state")
	_expect(_hud._rod_label.text == "CHARGING", "telemetry off shows charging without a percentage")
	_expect(not _hud._speed_label.text.contains("M/S"), "telemetry off hides the speed number")
	_expect(_hud._target_label.text == "NEXT SILVER   01:30", "the medal target is shown regardless of telemetry")
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


# --- Layouts -------------------------------------------------------------------------------------

func _test_layouts() -> void:
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
		var size_text: String = str(dimensions)

		var outside: Array[String] = []
		_collect_outside(_hud, bounds, outside)
		_expect(outside.is_empty(), "layout %s: every control stays inside the viewport%s" % [size_text, _list_suffix(outside)])

		var overlaps: Array[String] = []
		_collect_overlaps(_layout_group(), overlaps)
		_expect(overlaps.is_empty(), "layout %s: objectives, timer, reticle and the other HUD panels do not overlap%s" % [size_text, _list_suffix(overlaps)])

		for action in _hud._touch_pads:
			var rect: Rect2 = _hud._touch_pads[action].get_rect()
			_expect(rect.position.x >= 0 and rect.position.y >= 0 and rect.end.x <= logical_size.x and rect.end.y <= logical_size.y, action + " touch control stays visible at " + size_text)
		print("HUD layout: physical ", dimensions, " / canvas ", logical_size)
	_hud.set_active(false)


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
	await _shot(dir, "hud_1280x720_kbm", Vector2i(1280, 720), false, FULL_STATE, "CASE SECURED", "2 OF 3 SALVAGED")
	await _shot(dir, "hud_2400x1080_extract", Vector2i(2400, 1080), false, EXTRACT_STATE, "EXTRACTION READY", "Hold for six seconds")
	await _shot(dir, "hud_800x1280_touch", Vector2i(800, 1280), true, FULL_STATE, "CASE SECURED", "2 OF 3 SALVAGED")
	backdrop_layer.queue_free()
	root.size = Vector2i(1280, 720)


func _shot(dir: String, shot_name: String, size: Vector2i, touch: bool, state: Dictionary, title: String, subtitle: String) -> void:
	root.size = size
	_hud.touch_enabled = touch
	_hud.set_active(false)
	_hud.set_active(true)
	_hud.update_state(state)
	_hud.show_banner(title, subtitle, 30.0, "amber")
	await _frames(60)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = dir + "/" + shot_name + ".png"
	var err: int = image.save_png(path)
	_expect(err == OK, "capture saved: " + path)
	print("HUD capture: ", path)
