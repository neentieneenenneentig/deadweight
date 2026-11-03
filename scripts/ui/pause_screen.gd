extends "res://scripts/ui/screen.gd"
## Pause menu: RESUME, RESTART, SETTINGS, QUIT TO TITLE on the left and a controls reference
## for the device in use on the right. Esc or B resumes (ui_root maps back() on the root screen).

## [caption, action] rows of the controls reference; glyphs come from ui_root.ui_glyph().
const CONTROL_ROWS := [
	["MOVE", "move"], ["LOOK", "look"], ["CAST  (HOLD, RELEASE)", "cast"], ["LOCK / FREE SPOOL", "lock"],
	["REEL", "reel"], ["CUT LINE", "cut"], ["JUMP", "jump"], ["ROD / SIDEARM", "weapon"],
	["RELOAD", "reload"], ["PAUSE", "pause"],
]

var _title: Label
var _resume: Button
var _controls: VBoxContainer
var _controls_panel: PanelContainer


func _init() -> void:
	backdrop_mode = "pause"


func build() -> void:
	var row: HBoxContainer = hbox(self, 40)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var left: VBoxContainer = vbox(row, 8)
	left.custom_minimum_size.x = s(420)
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label(left, "PAUSED", "Overline")
	_title = label(left, "", "H1")
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.custom_minimum_size.x = s(420)
	spacer(left, 18)
	var menu: VBoxContainer = vbox(left, 2)
	_resume = _item(menu, "RESUME", "MenuItemPrimary", func() -> void: ui.emit_signal("resume_requested"))
	_item(menu, "RESTART", "MenuItem", func() -> void: ui.emit_signal("restart_requested"))
	_item(menu, "SETTINGS", "MenuItem", func() -> void: ui.call("show_settings"))
	_item(menu, "QUIT TO TITLE", "MenuItem", _ask_quit)
	expander(row)
	_controls_panel = panel(row, "GlassSoft")
	_controls_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_controls_panel.custom_minimum_size.x = s(380)
	var inner: VBoxContainer = vbox(_controls_panel, 8)
	label(inner, "CONTROLS", "Overline")
	_controls = vbox(inner, 6)


func open(args: Dictionary = {}) -> void:
	_title.text = str(args.get("title", "RAID")).to_upper()
	refresh()


func refresh() -> void:
	_fill_controls()


func primary_focus() -> Control:
	return _resume


func device_changed(_device: String) -> void:
	_fill_controls()


func _item(parent: Node, text: String, variation: String, callback: Callable) -> Button:
	var item: Button = button(parent, text, variation, callback)
	item.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return item


func _ask_quit() -> void:
	ui.call("confirm", "QUIT TO TITLE?", "Salvage from this raid is lost. Salvage you already banked is safe.", "QUIT", func() -> void: ui.emit_signal("menu_requested"))


func _fill_controls() -> void:
	if _controls == null or ui == null:
		return
	for child in _controls.get_children():
		_controls.remove_child(child)
		child.queue_free()
	var current: String = str(ui.get("device"))
	for entry: Array in CONTROL_ROWS:
		var line: HBoxContainer = hbox(_controls, 12)
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
