extends "res://scripts/ui/screen.gd"
## Title screen: logotype, tagline, the main menu and the "start with INDUCTION" callout over the
## 3D backdrop. CONTINUE (or CAMPAIGN on a fresh profile) opens the next unfinished raid;
## PRACTICE RANGE starts the sandbox; the rest open sub screens. QUIT is desktop only.

const TAGLINE := "SALVAGE RAIDS  /  FLOODWORKS QUARANTINE"

var _logo: Control
var _bank_chip: Label
var _continue: Button
var _practice: Button
var _quit: Button
var _callout: PanelContainer
var _version: Label
var _hints: HBoxContainer
var _continue_target: String = ""
var _menu_buttons: Array[Button] = []


func _init() -> void:
	backdrop_mode = "menu"


func build() -> void:
	var column: VBoxContainer = vbox(self, 0)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var top: HBoxContainer = hbox(column, 12)
	expander(top)
	_bank_chip = chip(top, "SALVAGE", "0", true)
	var middle: HBoxContainer = hbox(column, 0)
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left: VBoxContainer = vbox(middle, 6)
	left.custom_minimum_size.x = s(500)
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_logo = Widgets.Logotype.new()
	_logo.set("font_size", int(s(84)))
	left.add_child(_logo)
	label(left, TAGLINE, "OverlineCyan")
	spacer(left, 14)
	_callout = panel(left, "Callout")
	var callout_box: VBoxContainer = vbox(_callout, 6)
	label(callout_box, "NEW HERE?", "Overline")
	wrap_label(callout_box, "Start with the INDUCTION: a short training course with no hostiles.", "Body")
	button(callout_box, "START INDUCTION", "PrimaryButton", func() -> void: ui.call("request_level", "tutorial"))
	spacer(left, 8)
	var menu: VBoxContainer = vbox(left, 2)
	menu.custom_minimum_size.x = s(380)
	_continue = _menu_item(menu, "CAMPAIGN", _on_continue)
	_practice = _menu_item(menu, "PRACTICE RANGE", func() -> void: ui.call("request_level", "range"))
	_menu_item(menu, "WORKSHOP", func() -> void: ui.call("show_workshop"))
	_menu_item(menu, "RECORDS", func() -> void: ui.call("show_records"))
	_menu_item(menu, "SETTINGS", func() -> void: ui.call("show_settings"))
	_menu_item(menu, "CREDITS", func() -> void: ui.call("show_credits"))
	_quit = _menu_item(menu, "QUIT", func() -> void: ui.emit_signal("quit_requested"))
	_quit.visible = not bool(ui.get("is_mobile")) and not OS.has_feature("web")
	var bottom: HBoxContainer = hbox(column, 14)
	_version = label(bottom, "", "Caption")
	expander(bottom)
	_hints = hbox(bottom, 18)
	_hints.visible = false
	_update_hints()


func open(_args: Dictionary = {}) -> void:
	refresh()
	if _logo != null:
		_logo.set("reveal", 0.0)
		_logo.create_tween().tween_property(_logo, "reveal", 1.0, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func refresh() -> void:
	if _bank_chip == null:
		return
	_bank_chip.text = UiTheme.format_int(int(ui.call("bank")))
	_version.text = "v%s" % str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	_resolve_continue()
	_practice.disabled = not _is_available("range")
	_practice.text = "PRACTICE RANGE" if not _practice.disabled else "PRACTICE RANGE  (SOON)"
	_callout.visible = not bool(ui.call("profile_value", "tutorial_done", false)) and _is_available("tutorial")


func primary_focus() -> Control:
	for item: Button in _menu_buttons:
		if item.visible and not item.disabled:
			return item
	return null


func device_changed(_device: String) -> void:
	_update_hints()


func _menu_item(parent: Node, text: String, callback: Callable) -> Button:
	var item: Button = button(parent, text, "MenuItem", callback)
	item.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_menu_buttons.append(item)
	return item


## CONTINUE once any raid was tried and one is still open; otherwise CAMPAIGN opens level select.
func _resolve_continue() -> void:
	_continue_target = ""
	var started: bool = false
	var first_open: String = ""
	var ids: Array = ui.call("campaign_ids")
	for id: String in ids:
		var record: Dictionary = ui.call("level_record", id)
		var done: bool = bool(record.get("completed", false))
		started = started or done or int(record.get("attempts", 0)) > 0
		if first_open.is_empty() and not done and bool(ui.call("is_unlocked", id)):
			first_open = id
	if started and not first_open.is_empty():
		_continue_target = first_open
		var title: String = str(ui.call("level_info", first_open).get("title", first_open.to_upper()))
		_continue.text = "CONTINUE  -  " + title
	else:
		_continue.text = "CAMPAIGN"


func _on_continue() -> void:
	if _continue_target.is_empty():
		ui.call("show_level_select")
	else:
		ui.call("request_level", _continue_target)


## False only when the catalog knows the level and says it has no script yet.
func _is_available(id: String) -> bool:
	var info: Dictionary = ui.call("level_info", id)
	return bool(info.get("available", true))


func _update_hints() -> void:
	if _hints == null or ui == null:
		return
	for child in _hints.get_children():
		_hints.remove_child(child)
		child.queue_free()
	var current: String = str(ui.get("device"))
	_hints.visible = current != "touch"
	add_key_hint(_hints, str(ui.call("ui_glyph", "ui_accept", current)), "SELECT")
