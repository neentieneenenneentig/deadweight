extends "res://scripts/ui/screen.gd"
## Settings (CONTRACT 5.2): five tabs of controls. Every change is emitted at once as
## setting_changed(key, typed value); main.gd stores it and calls refresh() so the values shown
## here are always the ones kept. Touch appears only with touch controls on; window mode only
## on desktop. Gamepad: LB/RB (or Q/E) switch tabs; D-pad and sticks move focus.

const TAB_IDS := ["gameplay", "controls", "video", "audio", "touch"]
const TAB_TITLES := {"gameplay": "GAMEPLAY", "controls": "CONTROLS", "video": "VIDEO", "audio": "AUDIO", "touch": "TOUCH"}
const DEVICE_NAMES := {"kbm": "KEYBOARD + MOUSE", "gamepad": "GAMEPAD", "touch": "TOUCH"}
## Row kinds: "slider" (min, max, step, fmt), "toggle", "cycle" (options as [caption, value]).
## fmt: "pct" (0-1 shown as percent), "x" (multiplier), "deg" (degrees), "" (plain).
const ROWS := {
	"gameplay": [
		{"key": "difficulty", "label": "DIFFICULTY", "kind": "cycle", "options": [["RELAXED", 0], ["STANDARD", 1], ["HARDENED", 2]]},
		{"key": "auto_cut", "label": "AUTO-CUT LINE", "kind": "toggle"},
		{"key": "show_telemetry", "label": "TELEMETRY READOUT", "kind": "toggle"},
		{"key": "camera_shake", "label": "CAMERA SHAKE", "kind": "slider", "min": 0.0, "max": 1.0, "step": 0.05, "fmt": "pct"},
	],
	"controls": [
		{"key": "look_sensitivity", "label": "LOOK SENSITIVITY", "kind": "slider", "min": 0.2, "max": 3.0, "step": 0.05, "fmt": "x"},
		{"key": "gamepad_sensitivity", "label": "GAMEPAD SENSITIVITY", "kind": "slider", "min": 0.2, "max": 3.0, "step": 0.05, "fmt": "x"},
		{"key": "invert_y", "label": "INVERT LOOK Y", "kind": "toggle"},
	],
	"video": [
		{"key": "window_mode", "label": "WINDOW MODE", "kind": "cycle", "desktop_only": true, "options": [["WINDOWED", "windowed"], ["FULLSCREEN", "fullscreen"]]},
		{"key": "vsync", "label": "VSYNC", "kind": "toggle"},
		{"key": "max_fps", "label": "FRAME RATE CAP", "kind": "cycle", "options": [["UNLIMITED", 0], ["30 FPS", 30], ["60 FPS", 60], ["90 FPS", 90], ["120 FPS", 120], ["144 FPS", 144]]},
		{"key": "quality", "label": "GRAPHICS QUALITY", "kind": "cycle", "options": [["LOW", 0], ["MEDIUM", 1], ["HIGH", 2]]},
		{"key": "render_scale", "label": "RENDER SCALE", "kind": "slider", "min": 0.5, "max": 1.0, "step": 0.05, "fmt": "pct"},
		{"key": "fov", "label": "FIELD OF VIEW", "kind": "slider", "min": 60.0, "max": 95.0, "step": 1.0, "fmt": "deg"},
	],
	"audio": [
		{"key": "master_volume", "label": "MASTER", "kind": "slider", "min": 0.0, "max": 1.0, "step": 0.05, "fmt": "pct"},
		{"key": "music_volume", "label": "MUSIC", "kind": "slider", "min": 0.0, "max": 1.0, "step": 0.05, "fmt": "pct"},
		{"key": "sfx_volume", "label": "EFFECTS", "kind": "slider", "min": 0.0, "max": 1.0, "step": 0.05, "fmt": "pct"},
	],
	"touch": [
		{"key": "touch_scale", "label": "CONTROL SIZE", "kind": "slider", "min": 0.75, "max": 1.35, "step": 0.05, "fmt": "pct"},
		{"key": "touch_opacity", "label": "CONTROL OPACITY", "kind": "slider", "min": 0.3, "max": 1.0, "step": 0.05, "fmt": "pct"},
		{"key": "touch_left_handed", "label": "LEFT-HANDED LAYOUT", "kind": "toggle"},
		{"key": "haptics", "label": "VIBRATION", "kind": "toggle"},
	],
}
## Controls reference shown on the CONTROLS tab: [caption, action] rows (glyphs from ui_root).
const REFERENCE_ROWS := [
	["MOVE", "move"], ["LOOK", "look"], ["CAST  (HOLD, RELEASE)", "cast"], ["LOCK / FREE SPOOL", "lock"],
	["REEL", "reel"], ["CUT LINE", "cut"], ["JUMP", "jump"], ["ROD / SIDEARM", "weapon"],
	["RELOAD", "reload"], ["PAUSE", "pause"],
]

var _tab_buttons: Array[Button] = []
var _tab_ids: Array[String] = []
var _tab: int = 0
var _scroll: ScrollContainer
var _content: VBoxContainer
var _reference: VBoxContainer
## key -> {"control": Control, "value": Label or null, "spec": Dictionary}
var _fields: Dictionary = {}
## key -> value currently shown (kept in step with what was emitted).
var _shown: Dictionary = {}
var _back: Button


func build() -> void:
	var f: Dictionary = frame("SETTINGS", "OPTIONS")
	var body: VBoxContainer = f["body"]
	_tab_ids.clear()
	for id: String in TAB_IDS:
		if id == "touch" and not bool(ui.get("touch_enabled")):
			continue
		_tab_ids.append(id)
	var tab_bar := HFlowContainer.new()
	tab_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab_bar.add_theme_constant_override("h_separation", int(s(8)))
	tab_bar.add_theme_constant_override("v_separation", int(s(6)))
	body.add_child(tab_bar)
	for index in range(_tab_ids.size()):
		var tab: Button = button(tab_bar, TAB_TITLES[_tab_ids[index]], "TabButton", _select_tab.bind(index), "ui_move")
		tab.toggle_mode = true
		_tab_buttons.append(tab)
	var card: PanelContainer = panel(body, "GlassSoft")
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll = scroller(card)
	_content = vbox(_scroll, 14)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_back = footer_controls(f["footer"], [["ui_cancel", "BACK"], ["ui_accept", "SELECT"], ["tab_next", "NEXT TAB"]])


func open(_args: Dictionary = {}) -> void:
	_populate()


func refresh() -> void:
	for key: String in _fields:
		var field: Dictionary = _fields[key]
		var spec: Dictionary = field["spec"]
		var value: Variant = _stored_value(spec)
		_shown[key] = value
		var control: Control = field["control"]
		if control is HSlider:
			(control as HSlider).set_value_no_signal(float(value))
		elif control is CheckButton:
			(control as CheckButton).set_pressed_no_signal(bool(value))
		_show_value(key)


func primary_focus() -> Control:
	if _tab_buttons.is_empty():
		return _back
	return _tab_buttons[_tab]


func device_changed(_device: String) -> void:
	_update_hints()
	_fill_reference()


## Opens a tab by id (tests and previews). Unknown or hidden ids are ignored.
func show_tab(id: String) -> void:
	var index: int = _tab_ids.find(id)
	if index >= 0:
		_select_tab(index, true)


## LB/RB or Q/E switch tabs; everything else is left to the focused control.
func handle_input(event: InputEvent) -> bool:
	var step: int = 0
	if event is InputEventJoypadButton and event.is_pressed():
		var pad_button: int = (event as InputEventJoypadButton).button_index
		if pad_button == JOY_BUTTON_LEFT_SHOULDER:
			step = -1
		elif pad_button == JOY_BUTTON_RIGHT_SHOULDER:
			step = 1
	elif event is InputEventKey and event.is_pressed() and not (event as InputEventKey).echo:
		var key: int = (event as InputEventKey).keycode
		if key == KEY_Q:
			step = -1
		elif key == KEY_E:
			step = 1
	if step == 0 or _tab_ids.is_empty():
		return false
	_select_tab(_tab + step, true)
	return true


func _select_tab(index: int, focus_tab: bool = false) -> void:
	if _tab_ids.is_empty():
		return
	_tab = posmod(index, _tab_ids.size())
	for i in range(_tab_buttons.size()):
		_tab_buttons[i].button_pressed = i == _tab
	_populate()
	_scroll.scroll_vertical = 0
	if focus_tab:
		_tab_buttons[_tab].grab_focus()


## Rebuilds the rows of the current tab. Values are read by refresh().
func _populate() -> void:
	_fields.clear()
	_reference = null
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	if _tab_ids.is_empty():
		return
	var id: String = _tab_ids[_tab]
	var grid := GridContainer.new()
	grid.columns = _grid_columns()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", int(s(32)))
	grid.add_theme_constant_override("v_separation", int(s(18)))
	_content.add_child(grid)
	for spec: Dictionary in ROWS[id]:
		if bool(spec.get("desktop_only", false)) and bool(ui.get("is_mobile")):
			continue
		_add_row(grid, spec)
	if id == "controls":
		_add_reference()
	refresh()


## Two columns from about 800 px of usable width, three from about 1600 px.
func _grid_columns() -> int:
	var width: float = get_viewport().get_visible_rect().size.x
	var usable: float = width - clampf(width * 0.04, 28.0, 72.0) * 2.0
	return clampi(int(usable / s(400.0)), 1, 3)


func _add_row(parent: Node, spec: Dictionary) -> void:
	var key: String = str(spec["key"])
	var column: VBoxContainer = vbox(parent, 6)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head: HBoxContainer = hbox(column, 10)
	label(head, str(spec["label"]), "Body")
	expander(head)
	var value: Label = null
	var control: Control
	match str(spec["kind"]):
		"slider":
			value = label(head, "", "ValueCyan")
			value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			value.custom_minimum_size.x = s(84)
			control = _make_slider(column, key, spec)
		"toggle":
			control = _make_toggle(column, key)
		_:
			control = _make_cycle(column, key)
	_fields[key] = {"control": control, "value": value, "spec": spec}


func _make_slider(parent: Node, key: String, spec: Dictionary) -> HSlider:
	var slider := HSlider.new()
	slider.focus_mode = Control.FOCUS_ALL
	slider.min_value = float(spec["min"])
	slider.max_value = float(spec["max"])
	slider.step = float(spec["step"])
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(0, s(28))
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slider.value_changed.connect(_on_slider.bind(key))
	parent.add_child(slider)
	return slider


func _make_toggle(parent: Node, key: String) -> CheckButton:
	var check := CheckButton.new()
	check.focus_mode = Control.FOCUS_ALL
	check.alignment = HORIZONTAL_ALIGNMENT_LEFT
	check.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	check.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	check.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	check.toggled.connect(_on_toggle.bind(key))
	wire_button(check, Callable(), "ui_accept")
	parent.add_child(check)
	return check


func _make_cycle(parent: Node, key: String) -> Button:
	var item: Button = button(parent, "", "", _on_cycle.bind(key))
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.alignment = HORIZONTAL_ALIGNMENT_CENTER
	return item


func _on_slider(value: float, key: String) -> void:
	_shown[key] = value
	_show_value(key)
	ui.emit_signal("setting_changed", key, value)


func _on_toggle(on: bool, key: String) -> void:
	_shown[key] = on
	_show_value(key)
	ui.emit_signal("setting_changed", key, on)


func _on_cycle(key: String) -> void:
	var field: Dictionary = _fields[key]
	var options: Array = (field["spec"] as Dictionary)["options"]
	var index: int = _option_index(options, _shown.get(key))
	var next: Variant = options[(index + 1) % options.size()][1]
	_shown[key] = next
	_show_value(key)
	ui.emit_signal("setting_changed", key, next)


## Updates the caption, switch text or value label of one row from _shown.
func _show_value(key: String) -> void:
	if not _fields.has(key):
		return
	var field: Dictionary = _fields[key]
	var spec: Dictionary = field["spec"]
	var value: Variant = _shown.get(key)
	var control: Control = field["control"]
	match str(spec["kind"]):
		"slider":
			var value_label: Label = field["value"]
			value_label.text = _format(spec, value)
		"toggle":
			(control as CheckButton).text = "ON" if bool(value) else "OFF"
		_:
			(control as Button).text = "‹  %s  ›" % _caption_for(spec, value)


func _stored_value(spec: Dictionary) -> Variant:
	var value: Variant = ui.call("setting", str(spec["key"]), null)
	if value != null:
		return value
	match str(spec["kind"]):
		"slider":
			return float(spec["min"])
		"toggle":
			return false
	return (spec["options"] as Array)[0][1]


func _format(spec: Dictionary, value: Variant) -> String:
	var number: float = float(value)
	match str(spec.get("fmt", "")):
		"pct":
			return "%d%%" % roundi(number * 100.0)
		"x":
			return "%.2f×" % number
		"deg":
			return "%d°" % roundi(number)
	return str(value)


func _caption_for(spec: Dictionary, value: Variant) -> String:
	var options: Array = spec["options"]
	return str(options[maxi(_option_index(options, value), 0)][0])


## Index of the option whose value equals value, or -1.
func _option_index(options: Array, value: Variant) -> int:
	for i in range(options.size()):
		if options[i][1] == value:
			return i
	return -1


func _add_reference() -> void:
	var card: PanelContainer = panel(_content, "GlassSoft")
	var column: VBoxContainer = vbox(card, 8)
	var device: String = str(ui.get("device"))
	label(column, "CONTROLS  -  %s" % str(DEVICE_NAMES.get(device, device.to_upper())), "Overline")
	_reference = vbox(column, 6)
	_fill_reference()


func _fill_reference() -> void:
	if _reference == null or ui == null:
		return
	for child in _reference.get_children():
		_reference.remove_child(child)
		child.queue_free()
	var current: String = str(ui.get("device"))
	for entry: Array in REFERENCE_ROWS:
		var line: HBoxContainer = hbox(_reference, 12)
		label(line, str(entry[0]), "Small")
		expander(line)
		_keycap(line, str(ui.call("ui_glyph", str(entry[1]), current)))


func _keycap(parent: Node, text: String) -> void:
	var cap := PanelContainer.new()
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.add_theme_stylebox_override("panel", UiTheme.box(Color(0.9, 0.93, 0.9, 0.12), Color(0.9, 0.93, 0.9, 0.42), 1, 4, s(8), s(2)))
	parent.add_child(cap)
	var glyph: Label = label(cap, text, "Caption")
	glyph.add_theme_color_override("font_color", UiTheme.PAPER)
