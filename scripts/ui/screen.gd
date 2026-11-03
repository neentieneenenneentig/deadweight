extends Control
## Base class of every menu screen. Screens are built once in code by ui_root.gd, then
## opened (with arguments), refreshed from the profile and closed. Subclasses override
## build(), open(), refresh(), primary_focus() and optionally back()/handle_input().

const UiTheme = preload("res://scripts/ui/theme.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const Draw = preload("res://scripts/ui/draw.gd")

## The ui_root.gd CanvasLayer (duck-typed to avoid a preload cycle).
var ui: Node
var screen_id: String = ""
## Backdrop mode ui_root shows behind this screen (see Widgets.Backdrop).
var backdrop_mode: String = "dim"
var _hint_bar: HBoxContainer


func setup(root: Node, id: String) -> void:
	ui = root
	screen_id = id
	name = id.capitalize().replace(" ", "") + "Screen"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	build()


# --- Overridables -----------------------------------------------------------------------

func build() -> void:
	pass


func open(_args: Dictionary = {}) -> void:
	refresh()


func refresh() -> void:
	pass


func primary_focus() -> Control:
	return null


## Return true when the screen handled ui_cancel itself.
func back() -> bool:
	return false


## Screen-specific input (tab switching, scrolling). Return true when consumed.
func handle_input(_event: InputEvent) -> bool:
	return false


## Called by ui_root when the active input device changes ("kbm", "gamepad", "touch").
func device_changed(_device: String) -> void:
	_update_hints()


# --- Factories ----------------------------------------------------------------------------

func s(value: float) -> float:
	return value * float(ui.get("ui_scale")) if ui != null else value


func label(parent: Node, text: String, variation: String = "Body") -> Label:
	var node := Label.new()
	node.text = text
	node.theme_type_variation = variation
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node


func wrap_label(parent: Node, text: String, variation: String = "Body") -> Label:
	var node: Label = label(parent, text, variation)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node


## Button with UI sound, hover-to-focus (mouse) and an optional callback.
func button(parent: Node, text: String, variation: String = "", callback: Callable = Callable(), sound: String = "ui_accept") -> Button:
	var node := Button.new()
	node.text = text
	if variation != "":
		node.theme_type_variation = variation
	node.focus_mode = Control.FOCUS_ALL
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	parent.add_child(node)
	wire_button(node, callback, sound)
	return node


func wire_button(node: BaseButton, callback: Callable = Callable(), sound: String = "ui_accept") -> void:
	node.mouse_entered.connect(_hover_focus.bind(node))
	if sound != "":
		node.pressed.connect(func() -> void: ui.call("sound", sound))
	if callback.is_valid():
		node.pressed.connect(callback)


func _hover_focus(node: Control) -> void:
	if ui != null and bool(ui.call("pointer_focus_allowed")) and node.is_visible_in_tree() and node.focus_mode != Control.FOCUS_NONE and not node.has_focus():
		node.grab_focus()


func vbox(parent: Node, separation: float = -1.0) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if separation >= 0.0:
		node.add_theme_constant_override("separation", int(s(separation)))
	parent.add_child(node)
	return node


func hbox(parent: Node, separation: float = -1.0) -> HBoxContainer:
	var node := HBoxContainer.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if separation >= 0.0:
		node.add_theme_constant_override("separation", int(s(separation)))
	parent.add_child(node)
	return node


func panel(parent: Node, variation: String = "Glass") -> PanelContainer:
	var node := PanelContainer.new()
	node.theme_type_variation = variation
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node


func spacer(parent: Node, height: float = 0.0, width: float = 0.0) -> Control:
	var node := Control.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.custom_minimum_size = Vector2(s(width), s(height))
	parent.add_child(node)
	return node


func expander(parent: Node, vertical: bool = false) -> Control:
	var node: Control = spacer(parent)
	if vertical:
		node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


func rule(parent: Node, color: Color = UiTheme.LINE) -> ColorRect:
	var node := ColorRect.new()
	node.color = color
	node.custom_minimum_size = Vector2(0, 1)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node


func scroller(parent: Node) -> ScrollContainer:
	var node := ScrollContainer.new()
	node.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	node.follow_focus = true
	node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(node)
	return node


## Small rounded chip: [icon-less] "LABEL  VALUE".
func chip(parent: Node, caption: String, value: String, amber: bool = false) -> Label:
	var box: PanelContainer = panel(parent, "ChipAmber" if amber else "Chip")
	var row: HBoxContainer = hbox(box, 8)
	label(row, caption, "Caption")
	var value_label: Label = label(row, value, "ValueAmber" if amber else "Value")
	value_label.add_theme_font_size_override("font_size", int(s(16)))
	return value_label


## Standard screen frame: header (overline + title + right slot), body, footer.
## Returns {"root", "header_right", "body", "footer", "title", "overline"}.
func frame(overline_text: String, title_text: String) -> Dictionary:
	var root: VBoxContainer = vbox(self, 14)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var header: HBoxContainer = hbox(root, 16)
	var titles: VBoxContainer = vbox(header, 0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var over: Label = label(titles, overline_text, "Overline")
	var title: Label = label(titles, title_text, "H1")
	var right: HBoxContainer = hbox(header, 10)
	right.alignment = BoxContainer.ALIGNMENT_END
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rule(root, UiTheme.LINE)
	var body: VBoxContainer = vbox(root, 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var footer: HBoxContainer = hbox(root, 14)
	return {"root": root, "header_right": right, "body": body, "footer": footer, "title": title, "overline": over}


## Footer BACK button plus device-aware input hints on the right.
func footer_controls(footer: HBoxContainer, hints: Array = [["ui_cancel", "BACK"], ["ui_accept", "SELECT"]]) -> Button:
	var back_button: Button = button(footer, "BACK", "GhostButton", func() -> void: ui.call("back"), "")
	back_button.icon = null
	back_button.text = "‹  BACK"
	expander(footer)
	_hint_bar = hbox(footer, 18)
	_hint_bar.set_meta("hints", hints)
	_update_hints()
	return back_button


func _update_hints() -> void:
	if _hint_bar == null or ui == null:
		return
	for child in _hint_bar.get_children():
		child.queue_free()
	var device: String = str(ui.get("device"))
	_hint_bar.visible = device != "touch"
	var hints: Array = _hint_bar.get_meta("hints", [])
	for hint in hints:
		var pair: Array = hint
		add_key_hint(_hint_bar, str(ui.call("ui_glyph", str(pair[0]), device)), str(pair[1]))


## Keycap glyph followed by a caption (e.g. [ESC] BACK).
func add_key_hint(parent: Node, glyph_text: String, caption: String) -> void:
	var row: HBoxContainer = hbox(parent, 7)
	var cap := PanelContainer.new()
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UiTheme.box(Color(0.9, 0.93, 0.9, 0.12), Color(0.9, 0.93, 0.9, 0.42), 1, 4, s(7), s(2))
	cap.add_theme_stylebox_override("panel", style)
	row.add_child(cap)
	var glyph_label: Label = label(cap, glyph_text, "Caption")
	glyph_label.add_theme_color_override("font_color", UiTheme.PAPER)
	label(row, caption, "Caption")


## Brief horizontal shake for denied actions.
func shake(node: Control) -> void:
	if node == null or not node.is_inside_tree():
		return
	var origin: float = node.position.x
	var tween: Tween = node.create_tween()
	for offset in [7.0, -6.0, 4.0, -2.0, 0.0]:
		tween.tween_property(node, "position:x", origin + offset, 0.035)


## Fade/slide a control in quickly (stagger with delay).
func reveal(node: CanvasItem, delay: float = 0.0, duration: float = 0.16) -> void:
	node.modulate.a = 0.0
	var tween: Tween = node.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(node, "modulate:a", 1.0, duration)
