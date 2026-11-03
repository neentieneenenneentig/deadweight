extends RefCounted
## Input map for DEADWEIGHT (CONTRACT 5.7, DESIGN Controls). register() is idempotent: it adds
## only bindings that are missing, so calling it again leaves event counts unchanged.
## glyph() and expand_tokens() give the on-screen label for a device: kbm, gamepad or touch.

const DEVICE_KBM := "kbm"
const DEVICE_GAMEPAD := "gamepad"
const DEVICE_TOUCH := "touch"

const ACTIONS := [
	"move_left", "move_right", "move_forward", "move_back",
	"look_left", "look_right", "look_up", "look_down",
	"cast", "lock", "reel", "cut", "weapon", "reload", "jump", "pause",
]
const STICK_ACTIONS := [
	"move_left", "move_right", "move_forward", "move_back",
	"look_left", "look_right", "look_up", "look_down",
	"ui_left", "ui_right", "ui_up", "ui_down",
]
const TRIGGER_ACTIONS := ["cast", "reel"]
const STICK_DEADZONE := 0.2
const TRIGGER_DEADZONE := 0.1

## Keyboard keys per action. Look uses IJKL so arrows stay with move (DESIGN: move WASD / arrows).
const KEYBOARD := {
	"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
	"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
	"look_left": [KEY_J], "look_right": [KEY_L], "look_up": [KEY_I], "look_down": [KEY_K],
	"reel": [KEY_E], "cut": [KEY_Q], "weapon": [KEY_F], "reload": [KEY_R],
	"jump": [KEY_SPACE], "pause": [KEY_ESCAPE],
}
const MOUSE := {"cast": [MOUSE_BUTTON_LEFT], "lock": [MOUSE_BUTTON_RIGHT]}

## Gamepad buttons per action.
const PAD_BUTTONS := {
	"lock": [JOY_BUTTON_RIGHT_SHOULDER],
	"cut": [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_B],
	"jump": [JOY_BUTTON_A], "weapon": [JOY_BUTTON_Y],
	"reload": [JOY_BUTTON_X], "pause": [JOY_BUTTON_START],
}
## Gamepad axes as [action, axis, value]. Triggers are analog axes; sticks are pushed in one direction.
const PAD_AXES := [
	["cast", JOY_AXIS_TRIGGER_RIGHT, 1.0],
	["reel", JOY_AXIS_TRIGGER_LEFT, 1.0],
	["move_left", JOY_AXIS_LEFT_X, -1.0], ["move_right", JOY_AXIS_LEFT_X, 1.0],
	["move_forward", JOY_AXIS_LEFT_Y, -1.0], ["move_back", JOY_AXIS_LEFT_Y, 1.0],
	["look_left", JOY_AXIS_RIGHT_X, -1.0], ["look_right", JOY_AXIS_RIGHT_X, 1.0],
	["look_up", JOY_AXIS_RIGHT_Y, -1.0], ["look_down", JOY_AXIS_RIGHT_Y, 1.0],
]
## Menu navigation: D-pad and left stick for focus moves, A to accept, B to cancel.
const UI_PAD_AXES := [
	["ui_left", JOY_AXIS_LEFT_X, -1.0], ["ui_right", JOY_AXIS_LEFT_X, 1.0],
	["ui_up", JOY_AXIS_LEFT_Y, -1.0], ["ui_down", JOY_AXIS_LEFT_Y, 1.0],
]
const UI_PAD_BUTTONS := {
	"ui_left": [JOY_BUTTON_DPAD_LEFT], "ui_right": [JOY_BUTTON_DPAD_RIGHT],
	"ui_up": [JOY_BUTTON_DPAD_UP], "ui_down": [JOY_BUTTON_DPAD_DOWN],
	"ui_accept": [JOY_BUTTON_A], "ui_cancel": [JOY_BUTTON_B],
}

## On-screen label per control group and device. move_* and look_* map to the move and look groups.
const GLYPHS := {
	"move": {"kbm": "WASD", "gamepad": "L-STICK", "touch": "LEFT STICK"},
	"look": {"kbm": "MOUSE", "gamepad": "R-STICK", "touch": "DRAG"},
	"cast": {"kbm": "LMB", "gamepad": "RT", "touch": "CAST"},
	"lock": {"kbm": "RMB", "gamepad": "RB", "touch": "LOCK"},
	"reel": {"kbm": "E", "gamepad": "LT", "touch": "REEL"},
	"cut": {"kbm": "Q", "gamepad": "LB", "touch": "CUT"},
	"jump": {"kbm": "SPACE", "gamepad": "A", "touch": "JUMP"},
	"weapon": {"kbm": "F", "gamepad": "Y", "touch": "GUN"},
	"reload": {"kbm": "R", "gamepad": "X", "touch": "LOAD"},
	"pause": {"kbm": "ESC", "gamepad": "START", "touch": "II"},
}
const TOKENS := ["move", "look", "cast", "lock", "reel", "cut", "jump", "weapon", "reload", "pause"]


## Creates every action and adds its missing bindings. Safe to call more than once.
static func register() -> void:
	for action_name: String in ACTIONS:
		_ensure_action(action_name)
	for action_name: String in UI_PAD_BUTTONS:
		_ensure_action(action_name)
	for action_name: String in KEYBOARD:
		for keycode: int in KEYBOARD[action_name]:
			var key_event := InputEventKey.new()
			key_event.physical_keycode = keycode as Key
			_add_event(action_name, key_event)
	for action_name: String in MOUSE:
		for button: int in MOUSE[action_name]:
			var mouse_event := InputEventMouseButton.new()
			mouse_event.button_index = button as MouseButton
			_add_event(action_name, mouse_event)
	for action_name: String in PAD_BUTTONS:
		for button: int in PAD_BUTTONS[action_name]:
			_add_pad_button(action_name, button)
	for entry: Array in PAD_AXES:
		_add_pad_axis(entry[0], entry[1], entry[2])
	for entry: Array in UI_PAD_AXES:
		_add_pad_axis(entry[0], entry[1], entry[2])
	for action_name: String in UI_PAD_BUTTONS:
		for button: int in UI_PAD_BUTTONS[action_name]:
			_add_pad_button(action_name, button)
	for action_name: String in STICK_ACTIONS:
		InputMap.action_set_deadzone(action_name, STICK_DEADZONE)
	for action_name: String in TRIGGER_ACTIONS:
		InputMap.action_set_deadzone(action_name, TRIGGER_DEADZONE)


## Label for one action on a device, e.g. glyph("cast", "gamepad") is "RT". Unknown device uses kbm.
static func glyph(action: String, device: String) -> String:
	var key: String = _glyph_key(action)
	if not GLYPHS.has(key):
		return ""
	var row: Dictionary = GLYPHS[key]
	var chosen: String = device if row.has(device) else DEVICE_KBM
	return str(row[chosen])


## Replaces {cast}, {lock}, ... {look} in text with the device's glyphs.
static func expand_tokens(text: String, device: String) -> String:
	var out: String = text
	for token: String in TOKENS:
		out = out.replace("{%s}" % token, glyph(token, device))
	return out


static func _glyph_key(action: String) -> String:
	if action.begins_with("move_"):
		return "move"
	if action.begins_with("look_"):
		return "look"
	return action


static func _ensure_action(action_name: String) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)


static func _add_pad_button(action_name: String, button: int) -> void:
	var button_event := InputEventJoypadButton.new()
	button_event.button_index = button as JoyButton
	_add_event(action_name, button_event)


static func _add_pad_axis(action_name: String, axis: int, value: float) -> void:
	var motion := InputEventJoypadMotion.new()
	motion.axis = axis as JoyAxis
	motion.axis_value = value
	_add_event(action_name, motion)


## Adds the event unless the action already has an event with the same signature.
static func _add_event(action_name: String, event: InputEvent) -> void:
	_ensure_action(action_name)
	var wanted: String = _signature(event)
	for existing: InputEvent in InputMap.action_get_events(action_name):
		if _signature(existing) == wanted:
			return
	InputMap.action_add_event(action_name, event)


static func _signature(event: InputEvent) -> String:
	if event is InputEventKey:
		return "key:%d" % (event as InputEventKey).physical_keycode
	if event is InputEventMouseButton:
		return "mouse:%d" % (event as InputEventMouseButton).button_index
	if event is InputEventJoypadButton:
		return "pad:%d" % (event as InputEventJoypadButton).button_index
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		var direction: int = 1 if motion.axis_value >= 0.0 else -1
		return "axis:%d:%d" % [motion.axis, direction]
	return event.get_class()
