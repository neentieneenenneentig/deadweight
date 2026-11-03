extends CanvasLayer
## Menus and overlays (CONTRACT 4.15). Everything is built in code with one shared Theme
## (theme.gd). Mouse, touch, keyboard and gamepad all work: every screen focuses its primary
## control when shown and ui_cancel goes back. UI sounds go through the game_audio group.
## Data comes from the bound profile plus the catalog/upgrades/achievements scripts, which
## are loaded only if present (tests may inject stand-ins with set_sources()).

signal level_requested(level_id: String)
signal resume_requested
signal restart_requested
signal next_level_requested
signal menu_requested
signal setting_changed(key: String, value: Variant)
signal upgrade_requested(upgrade_id: String)
signal reset_progress_requested
signal quit_requested

const UiTheme = preload("res://scripts/ui/theme.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const SCREEN_SCRIPTS := {
	"title": "res://scripts/ui/title_screen.gd",
	"levels": "res://scripts/ui/levels_screen.gd",
	"workshop": "res://scripts/ui/workshop_screen.gd",
	"records": "res://scripts/ui/records_screen.gd",
	"settings": "res://scripts/ui/settings_screen.gd",
	"credits": "res://scripts/ui/credits_screen.gd",
	"pause": "res://scripts/ui/pause_screen.gd",
	"result": "res://scripts/ui/result_screen.gd",
	"loading": "res://scripts/ui/loading_screen.gd",
}
const CATALOG_PATH := "res://scripts/level_catalog.gd"
const UPGRADES_PATH := "res://scripts/upgrades.gd"
const ACHIEVEMENTS_PATH := "res://scripts/achievements.gd"
const INPUT_SETUP_PATH := "res://scripts/input_setup.gd"
const TOAST_SECONDS := 3.4
## Fallback glyphs when input_setup.gd is unavailable (DESIGN controls table).
const GLYPHS := {
	"kbm": {"cast": "LMB", "lock": "RMB", "reel": "E", "cut": "Q", "jump": "SPACE", "weapon": "F", "reload": "R", "pause": "ESC", "move": "WASD", "look": "MOUSE", "ui_accept": "ENTER", "ui_cancel": "ESC", "tab_prev": "Q", "tab_next": "E", "scroll": "↑↓"},
	"gamepad": {"cast": "RT", "lock": "RB", "reel": "LT", "cut": "LB", "jump": "A", "weapon": "Y", "reload": "X", "pause": "START", "move": "L-STICK", "look": "R-STICK", "ui_accept": "A", "ui_cancel": "B", "tab_prev": "LB", "tab_next": "RB", "scroll": "R-STICK"},
	"touch": {"cast": "CAST", "lock": "LOCK", "reel": "REEL", "cut": "CUT", "jump": "JUMP", "weapon": "GUN", "reload": "LOAD", "pause": "II", "move": "LEFT STICK", "look": "DRAG", "ui_accept": "TAP", "ui_cancel": "BACK", "tab_prev": "TAP", "tab_next": "TAP", "scroll": "DRAG"},
}
const DEFAULT_RECORD := {"completed": false, "best_time": -1.0, "medal": 0, "bonus_found": [], "attempts": 0, "extractions": 0}

var touch_enabled: bool = false:
	set(value):
		if touch_enabled == value:
			return
		touch_enabled = value
		if is_node_ready():
			_rebuild()
var profile: RefCounted
## Data sources: scripts (or stand-in objects) providing the CONTRACT 4.2/4.3/4.5/4.12 API.
var catalog: Variant
var upgrades: Variant
var achievements: Variant
var input_setup: Variant
## Last input device used: "kbm", "gamepad" or "touch".
var device: String = "kbm"
var ui_scale: float = 1.0
var is_mobile: bool = false
## Tests: simulated safe-area insets in canvas pixels (left, top, right, bottom); x < 0 = off.
var safe_insets_override := Vector4(-1, -1, -1, -1)

var _root: Control
var _backdrop: Control
var _safe: MarginContainer
var _stage: Control
var _screens: Dictionary = {}
var _stack: Array[String] = []
var _last_focus: Dictionary = {}
var _toast_holder: VBoxContainer
var _toast_queue: Array = []
var _toast_busy: bool = false
var _confirm: Control
var _confirm_title: Label
var _confirm_text: Label
var _confirm_yes: Button
var _confirm_no: Button
var _confirm_action: Callable
var _view_size := Vector2.ZERO
var _quiet_focus: bool = false
var _opened_frame: int = -1
var _mouse_moved_frame: int = -100
var _forced_touch: bool = false


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("ui_root")
	is_mobile = OS.has_feature("mobile")
	if not touch_enabled and (is_mobile or "--touch" in OS.get_cmdline_user_args()):
		touch_enabled = true
	device = "touch" if touch_enabled else "kbm"
	_load_sources()
	_build()
	get_viewport().gui_focus_changed.connect(_on_focus_changed)


func _process(_delta: float) -> void:
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	if view_size != _view_size:
		_view_size = view_size
		_apply_safe_area()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_open() and current_screen() not in ["title", "loading"]:
		back()


# --- Public API (CONTRACT 4.15) ------------------------------------------------------------

func bind(profile_object: RefCounted) -> void:
	profile = profile_object
	refresh()


func show_title() -> void:
	_show_root("title")


func show_level_select() -> void:
	_show_sub("levels")


func show_workshop() -> void:
	_show_sub("workshop")


func show_records() -> void:
	_show_sub("records")


func show_settings() -> void:
	_show_sub("settings")


func show_credits() -> void:
	_show_sub("credits")


func show_pause(level_title: String) -> void:
	_show_root("pause", {"title": level_title})


func show_result(result: Dictionary) -> void:
	_show_root("result", result)


func show_loading(title: String, subtitle: String) -> void:
	_show_root("loading", {"title": title, "subtitle": subtitle})


func show_toast(title: String, subtitle: String) -> void:
	_toast_queue.append([title, subtitle])
	if not _toast_busy:
		_next_toast()


func hide_all() -> void:
	_close_confirm()
	_stack.clear()
	for id in _screens:
		var screen: Control = _screens[id]
		screen.visible = false
	_set_backdrop("none")
	var owner_control: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if owner_control != null and _root.is_ancestor_of(owner_control):
		owner_control.release_focus()


func refresh() -> void:
	var id: String = current_screen()
	if id != "" and _screens.has(id):
		_screens[id].call("refresh")


func is_open() -> bool:
	return not _stack.is_empty()


# --- Extra public helpers (used by screens and tests) -----------------------------------------

func current_screen() -> String:
	return _stack[-1] if not _stack.is_empty() else ""


func get_screen(id: String) -> Control:
	return _screens.get(id, null)


## Replace data sources (tests). Pass null to keep the current one.
func set_sources(catalog_source: Variant, upgrades_source: Variant, achievements_source: Variant, input_source: Variant = null) -> void:
	if catalog_source != null:
		catalog = catalog_source
	if upgrades_source != null:
		upgrades = upgrades_source
	if achievements_source != null:
		achievements = achievements_source
	if input_source != null:
		input_setup = input_source
	refresh()


## Go back one screen (ui_cancel). Pause resumes; title and result stay.
func back() -> void:
	if _confirm != null and _confirm.visible:
		_close_confirm()
		sound("ui_back")
		return
	var id: String = current_screen()
	if id == "":
		return
	var screen: Control = _screens[id]
	if bool(screen.call("back")):
		return
	if _stack.size() > 1:
		_stack.pop_back()
		sound("ui_back")
		_display(current_screen(), {}, true)
	elif id == "pause":
		sound("ui_back")
		resume_requested.emit()


## Open a sub screen on top of the current one (Back returns here).
func open_sub(id: String) -> void:
	_show_sub(id)


func request_level(level_id: String) -> void:
	level_requested.emit(level_id)


func sound(event: String) -> void:
	if event == "" or not is_inside_tree():
		return
	var audio: Node = get_tree().get_first_node_in_group("game_audio")
	if audio != null and audio.has_method("play"):
		audio.call("play", event)


func pointer_focus_allowed() -> bool:
	return device == "kbm" and Engine.get_process_frames() - _mouse_moved_frame < 3


## Show a modal yes/no dialog (built into the UI; OS dialogs are not used).
func confirm(title: String, text: String, confirm_text: String, action: Callable) -> void:
	_confirm_title.text = title
	_confirm_text.text = text
	_confirm_yes.text = confirm_text
	_confirm_action = action
	_confirm.visible = true
	_quiet_focus = true
	_confirm_no.grab_focus()
	_quiet_focus = false


func is_confirm_open() -> bool:
	return _confirm != null and _confirm.visible


# --- Data adapters (all guarded) ----------------------------------------------------------------

func campaign_ids() -> Array[String]:
	var ids: Array[String] = []
	if catalog != null and _has(catalog, "campaign_ids"):
		for id in catalog.call("campaign_ids"):
			ids.append(str(id))
	return ids


func level_info(id: String) -> Dictionary:
	var info: Dictionary = {}
	if catalog != null and _has(catalog, "info"):
		var raw: Variant = catalog.call("info", id)
		if raw is Dictionary:
			info = (raw as Dictionary).duplicate()
	if not info.has("title"):
		info["title"] = "PRACTICE RANGE" if id == "range" else id.to_upper()
	info["id"] = id
	return info


func zone_info(zone: String) -> Dictionary:
	var zones: Variant = _const(catalog, "ZONES")
	if zones is Dictionary and (zones as Dictionary).has(zone):
		var entry: Dictionary = (zones as Dictionary)[zone]
		return entry
	var accents := {"floodworks": UiTheme.CYAN, "foundry": Color("ef8a4e"), "spillway": Color("8fc4e8")}
	return {"title": zone.to_upper(), "accent": accents.get(zone, UiTheme.CYAN)}


func next_level_id(id: String) -> String:
	if catalog != null and _has(catalog, "next_id"):
		return str(catalog.call("next_id", id))
	var ids: Array[String] = campaign_ids()
	var index: int = ids.find(id)
	return ids[index + 1] if index >= 0 and index + 1 < ids.size() else ""


func upgrade_ids() -> Array:
	var order: Variant = _const(upgrades, "ORDER")
	return (order as Array) if order is Array else []


func upgrade_def(id: String) -> Dictionary:
	var defs: Variant = _const(upgrades, "DEFS")
	if defs is Dictionary and (defs as Dictionary).has(id):
		return (defs as Dictionary)[id]
	return {"title": id.to_upper(), "desc": "", "stat_label": "", "values": []}


func upgrade_describe(id: String, tier: int) -> String:
	if upgrades != null and _has(upgrades, "describe"):
		return str(upgrades.call("describe", id, tier))
	var values: Array = upgrade_def(id).get("values", [])
	return str(values[tier]) if tier >= 0 and tier < values.size() else ""


func upgrade_max_tier() -> int:
	if upgrades != null and _has(upgrades, "max_tier"):
		return int(upgrades.call("max_tier"))
	var costs: Variant = _const(upgrades, "COSTS")
	return (costs as Array).size() if costs is Array else 4


func achievement_list() -> Array:
	var list: Variant = _const(achievements, "LIST")
	return (list as Array) if list is Array else []


func bank() -> int:
	return int(_prop("bank", 0))


func level_record(id: String) -> Dictionary:
	var record: Dictionary = DEFAULT_RECORD.duplicate(true)
	if profile != null and profile.has_method("level_record"):
		var raw: Variant = profile.call("level_record", id)
		if raw is Dictionary:
			record.merge(raw, true)
	else:
		var levels: Variant = _prop("levels", {})
		if levels is Dictionary and (levels as Dictionary).has(id):
			record.merge((levels as Dictionary)[id], true)
	return record


func is_unlocked(id: String) -> bool:
	if id == "range" or "--unlock-all" in OS.get_cmdline_user_args():
		return true
	if profile != null and profile.has_method("is_unlocked"):
		return bool(profile.call("is_unlocked", id))
	var ids: Array[String] = campaign_ids()
	var index: int = ids.find(id)
	return index <= 1 or bool(level_record(ids[index - 1]).get("completed", false))


func upgrade_tier(id: String) -> int:
	if profile != null and profile.has_method("upgrade_tier"):
		return int(profile.call("upgrade_tier", id))
	var tiers: Variant = _prop("upgrades", {})
	return int((tiers as Dictionary).get(id, 0)) if tiers is Dictionary else 0


func upgrade_cost(id: String) -> int:
	if profile != null and profile.has_method("upgrade_cost"):
		return int(profile.call("upgrade_cost", id))
	var tier: int = upgrade_tier(id)
	var costs: Variant = _const(upgrades, "COSTS")
	if costs is Array and tier < (costs as Array).size():
		return int((costs as Array)[tier])
	return -1


func can_purchase(id: String) -> bool:
	if profile != null and profile.has_method("can_purchase"):
		return bool(profile.call("can_purchase", id))
	var cost: int = upgrade_cost(id)
	return cost >= 0 and bank() >= cost


func setting(key: String, fallback: Variant = null) -> Variant:
	if profile != null and profile.has_method("setting"):
		var value: Variant = profile.call("setting", key)
		if value != null:
			return value
	var settings: Variant = _prop("settings", {})
	if settings is Dictionary and (settings as Dictionary).has(key):
		return (settings as Dictionary)[key]
	return fallback


func achievement_unlocked(id: String) -> bool:
	var unlocked: Variant = _prop("achievements", {})
	return unlocked is Dictionary and bool((unlocked as Dictionary).get(id, false))


func stat(key: String) -> Variant:
	var stats: Variant = _prop("stats", {})
	return (stats as Dictionary).get(key, 0) if stats is Dictionary else 0


func profile_value(key: String, fallback: Variant) -> Variant:
	return _prop(key, fallback)


## Display glyph for an action on a device (input_setup.gd when present).
func ui_glyph(action: String, for_device: String = "") -> String:
	var dev: String = for_device if for_device != "" else device
	if input_setup != null and _has(input_setup, "glyph") and not action.begins_with("ui_") and not action.begins_with("tab_") and action != "scroll":
		var text: String = str(input_setup.call("glyph", action, dev))
		if text != "":
			return text
	var table: Dictionary = GLYPHS.get(dev, GLYPHS["kbm"])
	return str(table.get(action, action.to_upper()))


# --- Building ------------------------------------------------------------------------------------

func _load_sources() -> void:
	catalog = _load_script(CATALOG_PATH)
	upgrades = _load_script(UPGRADES_PATH)
	achievements = _load_script(ACHIEVEMENTS_PATH)
	input_setup = _load_script(INPUT_SETUP_PATH)


func _load_script(path: String) -> Variant:
	if not ResourceLoader.exists(path):
		return null
	var script: Variant = load(path)
	return script if script is Script else null


func _build() -> void:
	ui_scale = UiTheme.ui_scale(touch_enabled)
	_root = Control.new()
	_root.name = "UIRootControl"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiTheme.build(touch_enabled)
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop = Widgets.Backdrop.new()
	_root.add_child(_backdrop)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.visible = false
	_safe = MarginContainer.new()
	_safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_safe)
	_safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_safe.add_child(_stage)
	for id in SCREEN_SCRIPTS:
		var path: String = SCREEN_SCRIPTS[id]
		var screen: Control = load(path).new()
		_stage.add_child(screen)
		screen.call("setup", self, id)
		screen.visible = false
		_screens[id] = screen
	_build_toasts()
	_build_confirm()
	_view_size = Vector2.ZERO


func _rebuild() -> void:
	var stack_copy: Array[String] = _stack.duplicate()
	var args_by_screen: Dictionary = {}
	for id in _screens:
		args_by_screen[id] = _screens[id].get_meta("open_args", {})
	if _root != null:
		_root.queue_free()
		remove_child(_root)
	_screens.clear()
	_last_focus.clear()
	_toast_busy = false
	_build()
	_apply_safe_area()
	_stack.clear()
	if not stack_copy.is_empty():
		_stack = stack_copy
		_display(current_screen(), args_by_screen.get(current_screen(), {}), false)


func _apply_safe_area() -> void:
	if _safe == null:
		return
	var view: Vector2 = get_viewport().get_visible_rect().size
	var insets: Vector4 = _device_insets(view)
	var pad_x: float = clampf(view.x * 0.04, 28.0, 72.0)
	var pad_y: float = clampf(view.y * 0.045, 22.0, 46.0)
	_safe.add_theme_constant_override("margin_left", int(pad_x + insets.x))
	_safe.add_theme_constant_override("margin_top", int(pad_y + insets.y))
	_safe.add_theme_constant_override("margin_right", int(pad_x + insets.z))
	_safe.add_theme_constant_override("margin_bottom", int(pad_y + insets.w))
	if _toast_holder != null:
		_toast_holder.offset_right = -(pad_x + insets.z)
		_toast_holder.offset_top = pad_y + insets.y + 96.0 * ui_scale


## Device safe-area insets converted to canvas pixels (notches, rounded corners).
func _device_insets(view: Vector2) -> Vector4:
	if safe_insets_override.x >= 0.0:
		return safe_insets_override
	if not is_mobile:
		return Vector4.ZERO
	var safe_rect: Rect2i = DisplayServer.get_display_safe_area()
	var window: Vector2i = DisplayServer.window_get_size()
	if window.x <= 0 or window.y <= 0 or safe_rect.size.x <= 0:
		return Vector4.ZERO
	var sx: float = view.x / float(window.x)
	var sy: float = view.y / float(window.y)
	return Vector4(maxf(0.0, safe_rect.position.x * sx), maxf(0.0, safe_rect.position.y * sy), maxf(0.0, (window.x - safe_rect.end.x) * sx), maxf(0.0, (window.y - safe_rect.end.y) * sy))


func _build_toasts() -> void:
	var layer_control := Control.new()
	layer_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(layer_control)
	layer_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_toast_holder = VBoxContainer.new()
	_toast_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer_control.add_child(_toast_holder)
	_toast_holder.anchor_left = 1.0
	_toast_holder.anchor_right = 1.0
	_toast_holder.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_toast_holder.offset_left = -400.0 * ui_scale
	_toast_holder.offset_right = -40.0
	_toast_holder.offset_top = 120.0


func _next_toast() -> void:
	if _toast_queue.is_empty() or _toast_holder == null:
		_toast_busy = false
		return
	_toast_busy = true
	var entry: Array = _toast_queue.pop_front()
	var toast := PanelContainer.new()
	toast.theme_type_variation = "Toast"
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.focus_mode = Control.FOCUS_NONE
	toast.name = "Toast"
	_toast_holder.add_child(toast)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", int(14 * ui_scale))
	toast.add_child(row)
	var badge: Control = Widgets.Badge.new()
	badge.unlocked = true
	badge.custom_minimum_size = Vector2(46, 46) * ui_scale
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(badge)
	var text_box := VBoxContainer.new()
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_theme_constant_override("separation", 1)
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_box)
	for spec in [["ACHIEVEMENT UNLOCKED", "Overline"], [str(entry[0]), "H3"], [str(entry[1]), "Small"]]:
		if str(spec[0]) == "":
			continue
		var line := Label.new()
		line.text = str(spec[0])
		line.theme_type_variation = str(spec[1])
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_box.add_child(line)
	sound("ui_unlock")
	toast.modulate.a = 0.0
	toast.position.x = 40.0
	var tween: Tween = toast.create_tween()
	tween.tween_property(toast, "modulate:a", 1.0, 0.18)
	tween.tween_interval(TOAST_SECONDS)
	tween.tween_property(toast, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func() -> void:
		toast.queue_free()
		_next_toast())


func _build_confirm() -> void:
	_confirm = Control.new()
	_confirm.name = "Confirm"
	_confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_confirm)
	_confirm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.INK, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := PanelContainer.new()
	box.theme_type_variation = "Glass"
	box.custom_minimum_size = Vector2(520, 0) * ui_scale
	center.add_child(box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", int(14 * ui_scale))
	box.add_child(column)
	var over := Label.new()
	over.text = "CONFIRM"
	over.theme_type_variation = "Overline"
	column.add_child(over)
	_confirm_title = Label.new()
	_confirm_title.theme_type_variation = "H2"
	column.add_child(_confirm_title)
	_confirm_text = Label.new()
	_confirm_text.theme_type_variation = "BodyMuted"
	_confirm_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_text.custom_minimum_size = Vector2(460, 0) * ui_scale
	column.add_child(_confirm_text)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", int(12 * ui_scale))
	column.add_child(row)
	_confirm_no = Button.new()
	_confirm_no.text = "CANCEL"
	row.add_child(_confirm_no)
	_confirm_yes = Button.new()
	_confirm_yes.theme_type_variation = "DangerButton"
	row.add_child(_confirm_yes)
	_confirm_no.pressed.connect(func() -> void:
		sound("ui_back")
		_close_confirm())
	_confirm_yes.pressed.connect(func() -> void:
		sound("ui_accept")
		var action: Callable = _confirm_action
		_close_confirm()
		if action.is_valid():
			action.call())
	for b in [_confirm_no, _confirm_yes]:
		var target: Button = b
		target.mouse_entered.connect(func() -> void:
			if pointer_focus_allowed():
				target.grab_focus())
	_confirm.visible = false


func _close_confirm() -> void:
	if _confirm == null or not _confirm.visible:
		return
	_confirm.visible = false
	_confirm_action = Callable()
	_focus_screen(current_screen(), true)


# --- Navigation ------------------------------------------------------------------------------------

func _show_root(id: String, args: Dictionary = {}) -> void:
	_close_confirm()
	_stack.clear()
	_stack.append(id)
	_display(id, args, false)


func _show_sub(id: String, args: Dictionary = {}) -> void:
	_close_confirm()
	if _stack.is_empty():
		_stack.append("title")
	if current_screen() != id:
		_remember_focus(current_screen())
		_stack.append(id)
	_display(id, args, false)


func _display(id: String, args: Dictionary, returning: bool) -> void:
	if not _screens.has(id):
		return
	for other in _screens:
		if other != id:
			_screens[other].visible = false
	var screen: Control = _screens[id]
	if not returning:
		screen.set_meta("open_args", args)
		screen.call("open", args)
	else:
		screen.call("refresh")
	screen.visible = true
	_set_backdrop(str(screen.get("backdrop_mode")))
	_opened_frame = Engine.get_process_frames()
	screen.modulate.a = 0.0
	screen.position = Vector2(-14.0, 0.0)
	var tween: Tween = screen.create_tween().set_parallel(true)
	tween.tween_property(screen, "modulate:a", 1.0, 0.16)
	tween.tween_property(screen, "position:x", 0.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_focus_screen(id, returning)


func _focus_screen(id: String, restore: bool) -> void:
	if id == "" or not _screens.has(id):
		return
	var target: Control = null
	if restore and _last_focus.has(id):
		var remembered: Variant = _last_focus[id]
		if is_instance_valid(remembered) and (remembered as Control).is_visible_in_tree():
			target = remembered
	if target == null:
		target = _screens[id].call("primary_focus")
	if target != null and target.is_inside_tree():
		_quiet_focus = true
		target.grab_focus()
		_quiet_focus = false
		# Containers may still be sorting this frame: grab again once layout settled.
		_regrab.call_deferred(target)


func _regrab(target: Control) -> void:
	if is_instance_valid(target) and target.is_visible_in_tree() and not target.has_focus() and not is_confirm_open():
		var focused: Control = get_viewport().gui_get_focus_owner()
		if focused == null or not _root.is_ancestor_of(focused):
			_quiet_focus = true
			target.grab_focus()
			_quiet_focus = false


func _remember_focus(id: String) -> void:
	if id == "" or not is_inside_tree():
		return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused != null and _screens.has(id) and (_screens[id] as Control).is_ancestor_of(focused):
		_last_focus[id] = focused


func _set_backdrop(mode: String) -> void:
	if _backdrop == null:
		return
	_backdrop.set("mode", mode)
	_backdrop.visible = mode != "none"


# --- Input -----------------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	var previous: String = device
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		device = "touch"
	elif event is InputEventJoypadButton:
		device = "gamepad"
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) > 0.4:
			device = "gamepad"
	elif event is InputEventKey:
		device = "kbm"
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		if not touch_enabled and motion.relative.length_squared() > 0.0:
			device = "kbm"
			_mouse_moved_frame = Engine.get_process_frames()
	elif event is InputEventMouseButton and not touch_enabled:
		device = "kbm"
	if device != previous:
		var id: String = current_screen()
		if id != "":
			_screens[id].call("device_changed", device)


func _unhandled_input(event: InputEvent) -> void:
	if not is_open() or not visible:
		return
	if is_confirm_open():
		if event.is_action_pressed("ui_cancel") and not event.is_echo():
			back()
			get_viewport().set_input_as_handled()
		return
	var screen: Control = _screens[current_screen()]
	if bool(screen.call("handle_input", event)):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		# The key that opened this screen (e.g. Esc pausing the game) must not close it.
		if Engine.get_process_frames() != _opened_frame:
			back()
		return
	for action in ["ui_up", "ui_down", "ui_left", "ui_right", "ui_accept", "ui_focus_next", "ui_focus_prev"]:
		if event.is_action_pressed(action):
			var focused: Control = get_viewport().gui_get_focus_owner()
			if focused == null or not focused.is_visible_in_tree():
				_focus_screen(current_screen(), false)
				get_viewport().set_input_as_handled()
			return


func _on_focus_changed(control: Control) -> void:
	if _quiet_focus or control == null or _root == null or not _root.is_ancestor_of(control):
		return
	sound("ui_move")


# --- Small utilities -------------------------------------------------------------------------------

func _has(source: Variant, method: String) -> bool:
	return source is Object and (source as Object).has_method(method)


func _const(source: Variant, constant: String) -> Variant:
	if source == null or not (source is Object):
		return null
	if source is Script:
		var map: Dictionary = (source as Script).get_script_constant_map()
		return map.get(constant, null)
	return (source as Object).get(constant)


func _prop(key: String, fallback: Variant) -> Variant:
	if profile == null:
		return fallback
	var value: Variant = profile.get(key)
	return fallback if value == null else value
