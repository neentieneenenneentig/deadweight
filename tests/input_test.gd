extends SceneTree
## F2 input map and platform services: bindings, deadzones, idempotence, glyphs, tokens, platform stubs.
## Headless. Touches no save file; the platform checks run without GodotSteam.

const InputSetup = preload("res://scripts/input_setup.gd")
const Platform = preload("res://scripts/platform.gd")

const GAME_ACTIONS := [
	"move_left", "move_right", "move_forward", "move_back",
	"look_left", "look_right", "look_up", "look_down",
	"cast", "lock", "reel", "cut", "weapon", "reload", "jump", "pause",
]

var _failures := 0
var _checks := 0


func _initialize() -> void:
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


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		print("FAIL " + message)


func _pass_if_clean(group: String, failures_before: int) -> void:
	if _failures == failures_before:
		print("PASS " + group)
