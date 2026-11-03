extends SceneTree
## F2 input map and platform services: bindings, deadzones, idempotence, glyphs, tokens, platform stubs.
## G8 gamepad pass: real main.gd driven by joypad events (right-stick look, LT reel, Start pause,
## device-switched glyphs, pad navigation of every screen). Headless. Touches only user://test_g8*.cfg;
## the save file is never touched. Run: godot --headless --fixed-fps 90 --path . --script res://tests/input_test.gd

const InputSetup = preload("res://scripts/input_setup.gd")
const Platform = preload("res://scripts/platform.gd")
const MainScript = preload("res://scripts/main.gd")
const PATH := "user://test_g8.cfg"

const GAME_ACTIONS := [
	"move_left", "move_right", "move_forward", "move_back",
	"look_left", "look_right", "look_up", "look_down",
	"cast", "lock", "reel", "cut", "weapon", "reload", "jump", "pause",
]

var _failures := 0
var _checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var before: int = _failures
	_test_register_creates_actions()
	_pass_if_clean("register creates actions", before)
	before = _failures
	_test_bindings()
	_pass_if_clean("bindings per action", before)
	before = _failures
	_test_ui_bindings()
	_pass_if_clean("ui bindings", before)
	before = _failures
	_test_deadzones()
	_pass_if_clean("deadzones", before)
	before = _failures
	_test_idempotent()
	_pass_if_clean("register is idempotent", before)
	before = _failures
	_test_glyphs()
	_pass_if_clean("glyphs", before)
	before = _failures
	_test_tokens()
	_pass_if_clean("tokens", before)
	before = _failures
	_test_platform()
	_pass_if_clean("platform without Steam", before)
	before = _failures
	await _test_gamepad_pass()
	_pass_if_clean("gamepad pass through main.gd", before)
	if _failures == 0:
		print("INPUT TESTS PASSED: %d checks" % _checks)
	else:
		print("INPUT TESTS FAILED: %d of %d checks" % [_failures, _checks])
	quit(0 if _failures == 0 else 1)


func _test_register_creates_actions() -> void:
	for action_name: String in GAME_ACTIONS:
		if InputMap.has_action(action_name):
			InputMap.erase_action(action_name)
	InputSetup.register()
	for action_name: String in GAME_ACTIONS:
		_expect(InputMap.has_action(action_name), "action %s exists" % action_name)


func _test_bindings() -> void:
	for action_name: String in GAME_ACTIONS:
		_expect(_has_keyboard_or_mouse(action_name), "%s has keyboard or mouse" % action_name)
		_expect(_has_pad(action_name), "%s has a gamepad event" % action_name)
	_expect(_has_mouse("cast", MOUSE_BUTTON_LEFT), "cast is LMB")
	_expect(_has_pad_axis("cast", JOY_AXIS_TRIGGER_RIGHT, true), "cast is RT")
	_expect(_has_mouse("lock", MOUSE_BUTTON_RIGHT), "lock is RMB")
	_expect(_has_pad_button("lock", JOY_BUTTON_RIGHT_SHOULDER), "lock is RB")
	_expect(_has_key("reel", KEY_E), "reel is E")
	_expect(_has_pad_axis("reel", JOY_AXIS_TRIGGER_LEFT, true), "reel is LT analog")
	_expect(_has_key("cut", KEY_Q), "cut is Q")
	_expect(_has_pad_button("cut", JOY_BUTTON_LEFT_SHOULDER), "cut is LB")
	_expect(_has_pad_button("cut", JOY_BUTTON_B), "cut is B")
	_expect(_has_key("jump", KEY_SPACE), "jump is Space")
	_expect(_has_pad_button("jump", JOY_BUTTON_A), "jump is A")
	_expect(_has_key("weapon", KEY_F), "weapon is F")
	_expect(_has_pad_button("weapon", JOY_BUTTON_Y), "weapon is Y")
	_expect(_has_key("reload", KEY_R), "reload is R")
	_expect(_has_pad_button("reload", JOY_BUTTON_X), "reload is X")
	_expect(_has_key("pause", KEY_ESCAPE), "pause is Esc")
	_expect(_has_pad_button("pause", JOY_BUTTON_START), "pause is Start")
	_expect(_has_key("move_left", KEY_A), "move_left is A")
	_expect(_has_pad_axis("move_left", JOY_AXIS_LEFT_X, false), "move_left is left stick left")
	_expect(_has_pad_axis("move_right", JOY_AXIS_LEFT_X, true), "move_right is left stick right")
	_expect(_has_pad_axis("move_forward", JOY_AXIS_LEFT_Y, false), "move_forward is left stick up")
	_expect(_has_pad_axis("move_back", JOY_AXIS_LEFT_Y, true), "move_back is left stick down")
	_expect(_has_pad_axis("look_left", JOY_AXIS_RIGHT_X, false), "look_left is right stick left")
	_expect(_has_pad_axis("look_down", JOY_AXIS_RIGHT_Y, true), "look_down is right stick down")


func _test_ui_bindings() -> void:
	_expect(_has_pad_button("ui_left", JOY_BUTTON_DPAD_LEFT), "ui_left has D-pad left")
	_expect(_has_pad_axis("ui_left", JOY_AXIS_LEFT_X, false), "ui_left has left stick")
	_expect(_has_pad_button("ui_right", JOY_BUTTON_DPAD_RIGHT), "ui_right has D-pad right")
	_expect(_has_pad_button("ui_up", JOY_BUTTON_DPAD_UP), "ui_up has D-pad up")
	_expect(_has_pad_button("ui_down", JOY_BUTTON_DPAD_DOWN), "ui_down has D-pad down")
	_expect(_has_pad_button("ui_accept", JOY_BUTTON_A), "ui_accept is A")
	_expect(_has_pad_button("ui_cancel", JOY_BUTTON_B), "ui_cancel is B")


func _test_deadzones() -> void:
	_expect(_near(InputMap.action_get_deadzone("move_left"), 0.2), "move_left deadzone 0.2")
	_expect(_near(InputMap.action_get_deadzone("look_up"), 0.2), "look_up deadzone 0.2")
	_expect(_near(InputMap.action_get_deadzone("ui_left"), 0.2), "ui_left deadzone 0.2")
	_expect(_near(InputMap.action_get_deadzone("cast"), 0.1), "cast trigger deadzone 0.1")
	_expect(_near(InputMap.action_get_deadzone("reel"), 0.1), "reel trigger deadzone 0.1")


func _test_idempotent() -> void:
	var first: Dictionary = _snapshot()
	InputSetup.register()
	var second: Dictionary = _snapshot()
	InputSetup.register()
	var third: Dictionary = _snapshot()
	_expect(first == second, "second register() keeps event counts")
	_expect(second == third, "third register() keeps event counts")
	_expect(int(first.get("cast", -1)) == 2, "cast has mouse and RT (2 events)")
	_expect(int(first.get("ui_accept", -1)) >= 2, "ui_accept has Enter/Space and A")


func _test_glyphs() -> void:
	var cases: Array = [
		["cast", "kbm", "LMB"], ["cast", "gamepad", "RT"], ["cast", "touch", "CAST"],
		["reel", "kbm", "E"], ["reel", "gamepad", "LT"], ["reel", "touch", "REEL"],
		["lock", "kbm", "RMB"], ["lock", "gamepad", "RB"],
		["cut", "gamepad", "LB"], ["jump", "gamepad", "A"], ["jump", "kbm", "SPACE"],
		["weapon", "gamepad", "Y"], ["reload", "gamepad", "X"], ["pause", "gamepad", "START"],
		["pause", "touch", "II"], ["move_left", "kbm", "WASD"], ["move_forward", "gamepad", "L-STICK"],
		["look_up", "gamepad", "R-STICK"], ["look_up", "kbm", "MOUSE"],
	]
	for row: Array in cases:
		var label: String = InputSetup.glyph(row[0], row[1])
		_expect(label == row[2], "glyph(%s, %s) is %s (got %s)" % [row[0], row[1], row[2], label])
	_expect(InputSetup.glyph("no_such_action", "kbm") == "", "unknown action has no glyph")
	_expect(InputSetup.glyph("jump", "xbox") == "SPACE", "unknown device falls back to kbm")


func _test_tokens() -> void:
	_expect(InputSetup.expand_tokens("Hold {cast} to cast, {reel} to reel.", "gamepad") == "Hold RT to cast, LT to reel.", "tokens expand on gamepad")
	_expect(InputSetup.expand_tokens("{pause} pauses", "kbm") == "ESC pauses", "pause token on kbm")
	_expect(InputSetup.expand_tokens("{move} and {look}", "touch") == "LEFT STICK and DRAG", "move and look tokens on touch")
	_expect(InputSetup.expand_tokens("{cut}/{lock}", "kbm") == "Q/RMB", "cut and lock tokens on kbm")
	_expect(InputSetup.expand_tokens("no tokens here", "gamepad") == "no tokens here", "plain text unchanged")


func _test_platform() -> void:
	var platform: Variant = Platform.new()
	platform.setup()
	_expect(not platform.is_steam(), "no Steam without the singleton")
	_expect(platform.is_mobile() == OS.has_feature("mobile"), "is_mobile matches the OS feature")
	platform.unlock_achievement("ACH_TEST")
	platform.unlock_achievement("")
	platform.set_haptics(false)
	platform.vibrate(50)
	platform.set_haptics(true)
	platform.vibrate(50)
	platform.vibrate(0)
	platform.vibrate(-5)
	platform.setup()
	_expect(not platform.is_steam(), "setup() twice still reports no Steam")
	platform.free()


## G8: a real main.gd, a temp profile and joypad events fed through Input.parse_input_event.
func _test_gamepad_pass() -> void:
	_wipe(PATH)
	var main: Node3D = MainScript.new()
	main.override_args = PackedStringArray(["--profile=" + PATH, "--windowed", "--level=l01", "--unlock-all"])
	root.add_child(main)
	await main.level_started
	await _frames(6)
	_expect(main.state == "playing", "gamepad: l01 is playing after --level")

	# Right stick look: the same signs as a mouse move (right turns yaw down, down tilts pitch down).
	var right_1: Vector2 = await _hold_stick(main, JOY_AXIS_RIGHT_X, 1.0, 30)
	_expect(right_1.x < -0.5, "right stick turns right (yaw change %.3f)" % right_1.x)
	_expect(absf(right_1.y) < 0.001, "right stick turn leaves pitch alone")
	var down_1: Vector2 = await _hold_stick(main, JOY_AXIS_RIGHT_Y, 1.0, 30)
	_expect(down_1.y < -0.5, "right stick down tilts pitch down (change %.3f)" % down_1.y)
	_expect(absf(down_1.x) < 0.001, "right stick tilt leaves yaw alone")

	# invert_y applies to the stick as well as the mouse.
	main.ui.setting_changed.emit("invert_y", true)
	var down_inverted: Vector2 = await _hold_stick(main, JOY_AXIS_RIGHT_Y, 1.0, 30)
	_expect(down_inverted.y > 0.5, "invert_y flips the stick tilt (change %.3f)" % down_inverted.y)
	main.ui.setting_changed.emit("invert_y", false)

	# gamepad_sensitivity scales the stick turn rate (2.0 turns about twice as far as 1.0).
	main.ui.setting_changed.emit("gamepad_sensitivity", 2.0)
	var right_2: Vector2 = await _hold_stick(main, JOY_AXIS_RIGHT_X, 1.0, 30)
	_expect(absf(right_2.x) > absf(right_1.x) * 1.5, "higher gamepad_sensitivity turns further (%.3f vs %.3f)" % [right_2.x, right_1.x])
	main.ui.setting_changed.emit("gamepad_sensitivity", 1.0)

	# LT is analog: 0.5 on the trigger gives about half reel (the input map's 0.1 trigger deadzone
	# rescales 0.5 to about 0.44, so the check allows 0.1).
	_pad_motion(JOY_AXIS_TRIGGER_LEFT, 0.5)
	await _frames(3)
	var reel: float = float(main.tether.reel_strength)
	_expect(absf(reel - 0.5) < 0.1, "LT at 0.5 sets tether.reel_strength near 0.5 (got %.3f)" % reel)
	_pad_motion(JOY_AXIS_TRIGGER_LEFT, 0.0)
	await _frames(3)

	# Keyboard reel stays full strength, and the keyboard takes the device back.
	_key(KEY_E, true)
	await _frames(3)
	_expect(float(main.tether.reel_strength) == 1.0 and main._device == "kbm", "keyboard reel keeps reel_strength at 1.0")
	_key(KEY_E, false)
	await _frames(2)

	# Glyphs: the hint re-expands the moment the pad becomes the last-used device.
	main.set_hint("CAST {cast}", 5.0)
	_expect(main._hint == "CAST LMB", "hint shows the keyboard glyph while kbm is in use (got %s)" % main._hint)
	_pad_button(JOY_BUTTON_LEFT_STICK, true)
	await _frames(2)
	_pad_button(JOY_BUTTON_LEFT_STICK, false)
	await _frames(2)
	_expect(main._device == "gamepad" and main._hint == "CAST RT", "a pad press re-expands the hint to RT (got %s)" % main._hint)
	# F1 is unmapped, so this key only switches the device back to the keyboard.
	_key(KEY_F1, true)
	_key(KEY_F1, false)
	await _frames(2)
	_expect(main._device == "kbm" and main._hint == "CAST LMB", "a key press brings the keyboard glyphs back (got %s)" % main._hint)

	# Start pauses the raid and Start again resumes it.
	_pad_button(JOY_BUTTON_START, true)
	_pad_button(JOY_BUTTON_START, false)
	await _frames(3)
	_expect(main.state == "paused" and main.ui.current_screen() == "pause", "Start pauses the raid")
	_pad_button(JOY_BUTTON_START, true)
	_pad_button(JOY_BUTTON_START, false)
	await _frames(3)
	_expect(main.state == "playing" and not main.ui.is_open(), "Start resumes the raid")

	# Every screen can be walked with the D-pad: focus stays on the screen after down and up.
	var screens: Array = [
		["title", func() -> void: main.ui.show_title()],
		["levels", func() -> void: main.ui.show_level_select()],
		["workshop", func() -> void: main.ui.show_workshop()],
		["records", func() -> void: main.ui.show_records()],
		["settings", func() -> void: main.ui.show_settings()],
		["credits", func() -> void: main.ui.show_credits()],
		["pause", func() -> void: main.ui.show_pause("Sluice Gate")],
	]
	for entry: Array in screens:
		await _test_pad_navigation(main, str(entry[0]), entry[1] as Callable)
	main.ui.hide_all()
	await _frames(2)

	main.queue_free()
	await _frames(3)
	_wipe(PATH)


## Opens one screen, presses D-pad down and up, and checks that focus stays inside that screen.
func _test_pad_navigation(main: Node3D, screen_name: String, opener: Callable) -> void:
	main.ui.hide_all()
	opener.call()
	await _frames(3)
	var screen: Control = main.ui.get_screen(screen_name)
	_pad_button(JOY_BUTTON_DPAD_DOWN, true)
	_pad_button(JOY_BUTTON_DPAD_DOWN, false)
	await _frames(3)
	var owner: Control = root.gui_get_focus_owner()
	_expect(owner != null and screen.is_ancestor_of(owner), "%s: D-pad down keeps focus on the screen" % screen_name)
	_pad_button(JOY_BUTTON_DPAD_UP, true)
	_pad_button(JOY_BUTTON_DPAD_UP, false)
	await _frames(3)
	owner = root.gui_get_focus_owner()
	_expect(owner != null and screen.is_ancestor_of(owner), "%s: D-pad up keeps focus on the screen" % screen_name)


## Holds one stick axis at value for frames, centres it, and returns the yaw and pitch change.
func _hold_stick(main: Node3D, axis: int, value: float, frames: int) -> Vector2:
	var before := Vector2(float(main.player.yaw), float(main.player.pitch))
	_pad_motion(axis, value)
	await _frames(frames)
	_pad_motion(axis, 0.0)
	await _frames(2)
	return Vector2(float(main.player.yaw), float(main.player.pitch)) - before


# --- Helpers ------------------------------------------------------------------------------------

func _has_keyboard_or_mouse(action_name: String) -> bool:
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventKey or event is InputEventMouseButton:
			return true
	return false


func _has_pad(action_name: String) -> bool:
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			return true
	return false


func _has_key(action_name: String, keycode: int) -> bool:
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == keycode:
			return true
	return false


func _has_mouse(action_name: String, button: int) -> bool:
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == button:
			return true
	return false


func _has_pad_button(action_name: String, button: int) -> bool:
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == button:
			return true
	return false


func _has_pad_axis(action_name: String, axis: int, positive: bool) -> bool:
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventJoypadMotion:
			var motion := event as InputEventJoypadMotion
			if motion.axis == axis and (motion.axis_value > 0.0) == positive:
				return true
	return false


## Event count per action for every action in the map, for comparing two register() runs.
func _snapshot() -> Dictionary:
	var counts: Dictionary = {}
	for action_name: StringName in InputMap.get_actions():
		counts[str(action_name)] = InputMap.action_get_events(action_name).size()
	return counts


func _near(actual: float, expected: float) -> bool:
	return absf(actual - expected) < 0.0001


func _pad_motion(axis: int, value: float) -> void:
	var motion := InputEventJoypadMotion.new()
	motion.axis = axis as JoyAxis
	motion.axis_value = value
	Input.parse_input_event(motion)


func _pad_button(button: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button as JoyButton
	event.pressed = pressed
	Input.parse_input_event(event)


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _wipe(path: String) -> void:
	for suffix: String in ["", ".bak", ".tmp", ".corrupt"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)


func _frames(count: int) -> void:
	for i in range(count):
		await process_frame


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		print("FAIL " + message)


func _pass_if_clean(group: String, failures_before: int) -> void:
	if _failures == failures_before:
		print("PASS " + group)
