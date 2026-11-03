extends CanvasLayer
## Native interface and touch input. Desktop input belongs to main.gd.

signal action_requested(action: String, pressed: bool)
signal look_requested(delta: Vector2)
signal start_requested(practice: bool)
signal restart_requested
signal resume_requested

const INK := Color("0b171a")
const PANEL := Color(0.035, 0.075, 0.085, 0.9)
const PAPER := Color("e5ebe5")
const MUTED := Color("94aaa9")
const AMBER := Color("f5b45b")
const CYAN := Color("67d5d2")
const RED := Color("ed7263")

var move_vector := Vector2.ZERO
var touch_enabled: bool = false
var _mode := "menu"
var _root: Control
var _game: Control
var _menu: Control
var _pause: Control
var _results: Control
var _touch: Control
var _menu_left: VBoxContainer
var _menu_right: PanelContainer
var _title: Label
var _bank_label: Label
var _health_label: Label
var _health_bar: ProgressBar
var _speed_label: Label
var _clock_label: Label
var _loot_label: Label
var _mission_label: Label
var _extract_bar: ProgressBar
var _rod_label: Label
var _line_label: Label
var _weapon_label: Label
var _ammo_label: Label
var _hint: Label
var _tension_bar: ProgressBar
var _charge_bar: ProgressBar
var _reticle: Reticle
var _health_panel: PanelContainer
var _objective_panel: PanelContainer
var _equipment_panel: PanelContainer
var _bottom_controls: Label
var _practice_label: Label
var _result_title: Label
var _result_detail: Label
var _result_stats: Label
var _pause_panel: PanelContainer
var _results_panel: PanelContainer
var _touch_pads: Dictionary = {}
var _touch_roles: Dictionary = {}
var _stick: TouchPad
var _last_size := Vector2.ZERO
var _safe := Vector4(24, 24, 24, 24)
var _hint_override := ""


class TouchPad extends Control:

	var caption := ""
	var accent := Color("94aaa9")
	var held := false
	var is_stick := false
	var stick_value := Vector2.ZERO

	func _draw() -> void:
		var center: Vector2 = size * 0.5
		var radius: float = minf(size.x, size.y) * 0.5 - 3.0
		draw_circle(center, radius, Color(0.025, 0.065, 0.075, 0.68))
		draw_arc(center, radius, 0.0, TAU, 64, Color(accent, 0.8 if held else 0.36), 2.0, true)
		if is_stick:
			draw_circle(center + stick_value * radius * 0.58, radius * 0.3, Color(accent, 0.42 if held else 0.2))
			draw_arc(center, radius * 0.53, 0.0, TAU, 48, Color(accent, 0.14), 1.0, true)
		else:
			if held:
				draw_circle(center, radius - 4.0, Color(accent, 0.13))
			var font: Font = ThemeDB.fallback_font
			var font_size: int = 15 if size.x >= 78 else 12
			var text_size: Vector2 = font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			draw_string(font, Vector2(center.x - text_size.x * 0.5, center.y + font_size * 0.34), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, accent)


class Reticle extends Control:

	var hit := 0.0
	var danger := 0.0
	var sidearm := false

	func _draw() -> void:
		var center: Vector2 = size * 0.5
		var color := Color(0.88, 0.96, 0.92, 0.85)
		draw_circle(center, 2.0, color)
		var gap: float = 6.0 if sidearm else 11.0
		for axis in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			draw_line(center + axis * gap, center + axis * (gap + 5.0), Color(color, 0.48), 1.2, true)
		if hit > 0.0:
			for axis in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				draw_line(center + axis * 8.0, center + axis * 14.0, Color(1.0, 0.77, 0.4, hit), 2.5, true)
		if danger > 0.01:
			var edge := Color(0.83, 0.19, 0.12, danger * 0.45)
			draw_rect(Rect2(Vector2.ZERO, size), edge, false, 7.0)
			draw_rect(Rect2(Vector2(7, 7), size - Vector2(14, 14)), Color(edge, edge.a * 0.4), false, 15.0)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	touch_enabled = OS.has_feature("mobile") or "--touch" in OS.get_cmdline_user_args()
	_root = _control(self)
	_fill(_root)
	_build_game()
	_build_touch()
	_build_menu()
	_build_pause()
	_build_results()
	_reflow()
	show_menu()


func _process(_delta: float) -> void:
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	if view_size != _last_size:
		_reflow()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_release_touches()


func _control(parent: Node) -> Control:
	var node := Control.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node


func _fill(node: Control) -> void:
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _label(parent: Node, text: String, size: int = 18, color: Color = PAPER) -> Label:
	var node := Label.new()
	node.text = text
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	parent.add_child(node)
	return node


func _style(color: Color, border: Color = Color.TRANSPARENT, padding: int = 18) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1 if border.a > 0 else 0)
	style.set_content_margin_all(padding)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	return style


func _panel(parent: Node, padding: int = 18) -> PanelContainer:
	var node := PanelContainer.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_stylebox_override("panel", _style(PANEL, Color(0.43, 0.65, 0.64, 0.18), padding))
	parent.add_child(node)
	return node


func _vbox(parent: Node, separation: int = 10) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", separation)
	parent.add_child(box)
	return box


func _bar(parent: Node, color: Color, height: float = 5.0) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.show_percentage = false
	bar.custom_minimum_size.y = height
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", _style(Color(0.43, 0.6, 0.61, 0.16), Color.TRANSPARENT, 0))
	bar.add_theme_stylebox_override("fill", _style(color, Color.TRANSPARENT, 0))
	parent.add_child(bar)
	return bar


func _button(parent: Node, title: String, accent: bool, callback: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size.y = 52
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_color_override("font_color", INK if accent else PAPER)
	button.add_theme_color_override("font_hover_color", INK if accent else PAPER)
	button.add_theme_color_override("font_pressed_color", INK if accent else AMBER)
	button.add_theme_stylebox_override("normal", _style(AMBER if accent else Color(0.08, 0.14, 0.15, 0.94), Color.TRANSPARENT if accent else Color(0.38, 0.55, 0.55, 0.4)))
	button.add_theme_stylebox_override("hover", _style(Color("ffd493") if accent else Color("263d40")))
	button.add_theme_stylebox_override("pressed", _style(Color("d4984e") if accent else Color("17292c")))
	button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, PAPER, 0))
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _dim(parent: Node, alpha: float) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.015, 0.035, 0.045, alpha)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(dim)
	_fill(dim)


func _build_menu() -> void:
	_menu = _control(_root)
	_fill(_menu)
	_dim(_menu, 0.57)
	_menu_left = _vbox(_menu, 14)
	_label(_menu_left, "FIELD OPERATIONS   /   01", 14, AMBER)
	_title = _label(_menu_left, "DEADWEIGHT", 82)
	_title.add_theme_constant_override("outline_size", 0)
	_label(_menu_left, "The ground is a bad place to stay.", 23, PAPER)
	var description := _label(_menu_left, "Cast a weight. Catch the line. Stay ahead of the hunt.\nGet the salvage out — or leave it all behind.", 17, MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var gap := Control.new()
	gap.custom_minimum_size.y = 14
	_menu_left.add_child(gap)
	_button(_menu_left, "DEPLOY INTO THE FLOODWORKS   >", true, func() -> void: start_requested.emit(false))
	_button(_menu_left, "PRACTICE   /   NO HOSTILES", false, func() -> void: start_requested.emit(true))
	_bank_label = _label(_menu_left, "SALVAGE BANKED  /  00", 14, CYAN)
	_label(_menu_left, "SINGLE PLAYER    •    EXPERIMENTAL MOVEMENT", 12, MUTED)
	_menu_right = _panel(_menu, 24)
	var content := _vbox(_menu_right, 13)
	_label(content, "RAID BRIEFING", 13, AMBER)
	_label(content, "Bring something back.", 25)
	_label(content, "01   Recover the three marked cases.\n02   Reach the cyan extraction zone.\n03   Hold for six seconds. Survive.", 16, PAPER)
	_label(content, "Death loses this run’s salvage.\nHounds close the gap. Sentries watch the lanes.", 14, MUTED)
	_separator(content)
	_label(content, "LEARN THE ROD", 13, CYAN)
	_label(content, "Hold CAST to charge, release to throw.\nLOCK catches the line. Hold REEL to pull.\nCUT before you cast another weight.\nUnlock to let the line run free.", 15, PAPER)
	_separator(content)
	if touch_enabled:
		_label(content, "LEFT THUMB   Move\nRIGHT THUMB   Aim + rod controls\nDrag CAST or REEL to aim while holding.", 14, MUTED)
	else:
		_controls_guide(content, false)
	for child in content.get_children():
		if child is Label:
			child.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _separator(parent: Node) -> void:
	var line := ColorRect.new()
	line.color = Color(0.48, 0.67, 0.65, 0.2)
	line.custom_minimum_size.y = 1
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)


func _controls_guide(parent: Node, large: bool) -> void:
	var text := "WASD   Move     /     MOUSE   Aim\nLMB   Charge / cast / fire     RMB   Lock / free\nE   Reel     Q   Cut     F   Rod / sidearm\nR   Reload     SPACE   Jump     ESC   Pause"
	_label(parent, text, 17 if large else 14, MUTED)


func _build_game() -> void:
	_game = _control(_root)
	_fill(_game)
	_reticle = Reticle.new()
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_game.add_child(_reticle)
	_fill(_reticle)
	_health_panel = _panel(_game, 14)
	var vitals := _vbox(_health_panel, 6)
	_health_label = _label(vitals, "CONDITION   100", 18)
	_health_bar = _bar(vitals, CYAN, 4)
	_speed_label = _label(vitals, "0.0 M/S   /   GROUNDED", 12, MUTED)
	_objective_panel = _panel(_game, 14)
	var objective := _vbox(_objective_panel, 5)
	_loot_label = _label(objective, "SALVAGE   0 / 3", 20, AMBER)
	_mission_label = _label(objective, "RECOVER THE MARKED CASES", 11, MUTED)
	_extract_bar = _bar(objective, CYAN, 4)
	_extract_bar.visible = false
	_equipment_panel = _panel(_game, 14)
	var equipment := _vbox(_equipment_panel, 5)
	var weapon_row := HBoxContainer.new()
	weapon_row.add_theme_constant_override("separation", 12)
	equipment.add_child(weapon_row)
	_weapon_label = _label(weapon_row, "01  /  CASTING RIG", 13, AMBER)
	_weapon_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ammo_label = _label(weapon_row, "", 14, PAPER)
	_rod_label = _label(equipment, "READY TO CAST", 18)
	_line_label = _label(equipment, "0.0 M   /   0.0 kN", 12, MUTED)
	_tension_bar = _bar(equipment, CYAN, 4)
	_charge_bar = _bar(equipment, AMBER, 3)
	_charge_bar.visible = false
	_hint = _label(_game, "", 16, PAPER)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_hint.add_theme_constant_override("shadow_offset_y", 2)
	_clock_label = _label(_game, "00:00", 14, MUTED)
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_practice_label = _label(_game, "PRACTICE / NO HOSTILES", 12, CYAN)
	_practice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bottom_controls = _label(_game, "LMB CAST    RMB LOCK    E REEL    Q CUT    F WEAPON    R RELOAD    ESC PAUSE", 12, MUTED)
	_bottom_controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _build_touch() -> void:
	_touch = _control(_game)
	_fill(_touch)
	_stick = TouchPad.new()
	_stick.is_stick = true
	_stick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_touch.add_child(_stick)
	for action in ["cast", "reel", "lock", "cut", "weapon", "reload", "jump", "pause"]:
		var pad := TouchPad.new()
		pad.caption = {"cast": "CAST", "reel": "REEL", "lock": "LOCK", "cut": "CUT", "weapon": "GUN", "reload": "LOAD", "jump": "JUMP", "pause": "II"}[action]
		pad.accent = AMBER if action == "cast" else (CYAN if action in ["reel", "lock"] else MUTED)
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_touch.add_child(pad)
		_touch_pads[action] = pad
	_touch.visible = touch_enabled


func _build_pause() -> void:
	_pause = _control(_root)
	_fill(_pause)
	_dim(_pause, 0.65)
	_pause_panel = _panel(_pause, 30)
	var content := _vbox(_pause_panel, 16)
	_label(content, "OPERATIONS ON HOLD", 13, AMBER)
	_label(content, "Take a breath.", 42)
	_label(content, "Cast → lock → reel → cut → cast again.", 20, PAPER)
	_label(content, "The weight pulls you only when the line is taut.\nReel to shorten it; unlock to pay out. Cutting keeps your momentum.\nSwitching to the sidearm keeps your line attached.", 16, MUTED)
	_separator(content)
	if touch_enabled:
		_label(content, "Left stick moves. Drag the right side to aim.\nHold CAST to charge; drag while holding to adjust your aim.\nREEL also supports aim drag. LOCK toggles; CUT releases the weight.", 16, MUTED)
	else:
		_controls_guide(content, true)
	_button(content, "RESUME RAID   >", true, func() -> void: resume_requested.emit())
	_button(content, "RESTART RUN", false, func() -> void: restart_requested.emit())


func _build_results() -> void:
	_results = _control(_root)
	_fill(_results)
	_dim(_results, 0.7)
	_results_panel = _panel(_results, 32)
	var content := _vbox(_results_panel, 17)
	_label(content, "OPERATION REPORT   /   FLOODWORKS", 13, MUTED)
	_result_title = _label(content, "EXTRACTED", 52, CYAN)
	_result_detail = _label(content, "You made it out. The salvage is yours.", 19)
	_result_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_separator(content)
	_result_stats = _label(content, "", 21, PAPER)
	_separator(content)
	_button(content, "DEPLOY AGAIN   >", true, func() -> void: restart_requested.emit())
	_button(content, "PRACTICE THE MOVEMENT", false, func() -> void: start_requested.emit(true))


func _reflow() -> void:
	if not is_instance_valid(_root):
		return
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	_last_size = view_size
	_safe = Vector4(24, 24, 24, 24)
	if OS.has_feature("mobile"):
		var safe_rect: Rect2i = DisplayServer.get_display_safe_area()
		var window_size: Vector2i = DisplayServer.window_get_size()
		if window_size.x > 0 and window_size.y > 0 and safe_rect.size.x > 0:
			var scale_x: float = view_size.x / float(window_size.x)
			var scale_y: float = view_size.y / float(window_size.y)
			_safe.x = maxf(24, safe_rect.position.x * scale_x + 12)
			_safe.y = maxf(24, safe_rect.position.y * scale_y + 12)
			_safe.z = maxf(24, (window_size.x - safe_rect.end.x) * scale_x + 12)
			_safe.w = maxf(24, (window_size.y - safe_rect.end.y) * scale_y + 12)
	var width: float = view_size.x
	var height: float = view_size.y
	var right: float = width - _safe.z
	var left: float = _safe.x
	var top: float = _safe.y
	var bottom: float = height - _safe.w
	var menu_margin: float = maxf(36, width * 0.04)
	var briefing_width: float = 360 if width > 1100 else 330
	_menu_left.position = Vector2(maxf(menu_margin, left), height * 0.15)
	_menu_left.size = Vector2(width - menu_margin * 3 - briefing_width, 470)
	_title.add_theme_font_size_override("font_size", int(clampf(_menu_left.size.x / 7.3, 48, 88)))
	_menu_right.position = Vector2(width - menu_margin - briefing_width, maxf(top, (height - 535) * 0.5))
	_menu_right.size = Vector2(briefing_width, 535)
	_health_panel.position = Vector2(left, top)
	_health_panel.size = Vector2(206, 88)
	_objective_panel.position = Vector2(right - 258, top + (68 if touch_enabled else 0))
	_objective_panel.size = Vector2(258, 78)
	_equipment_panel.position = Vector2((width - 340) * 0.5, top if touch_enabled else bottom - 130)
	_equipment_panel.size = Vector2(340, 112)
	_hint.position = Vector2(width * 0.18, top + 154 if touch_enabled else bottom - 177)
	_hint.size = Vector2(width * 0.64, 45)
	_clock_label.position = Vector2((width - 90) * 0.5, top + 120 if touch_enabled else top)
	_clock_label.size = Vector2(90, 20)
	_practice_label.position = Vector2((width - 230) * 0.5, top + 141 if touch_enabled else top + 24)
	_practice_label.size = Vector2(230, 20)
	_bottom_controls.position = Vector2(left, bottom - 16)
	_bottom_controls.size = Vector2(right - left, 20)
	_bottom_controls.visible = not touch_enabled
	_pause_panel.size = Vector2(minf(740, width - left - _safe.z), 530)
	_pause_panel.position = (view_size - _pause_panel.size) * 0.5
	_results_panel.size = Vector2(minf(620, width - left - _safe.z), 450)
	_results_panel.position = (view_size - _results_panel.size) * 0.5
	_stick.position = Vector2(left + 14, bottom - 180)
	_stick.size = Vector2(158, 158)
	_place_pad("cast", Vector2(right - 66, bottom - 133), 112)
	_place_pad("reel", Vector2(right - 188, bottom - 64), 94)
	_place_pad("lock", Vector2(right - 180, bottom - 180), 82)
	_place_pad("cut", Vector2(right - 66, bottom - 255), 66)
	_place_pad("weapon", Vector2(right - 276, bottom - 170), 70)
	_place_pad("reload", Vector2(right - 268, bottom - 264), 64)
	_place_pad("jump", Vector2(right - 294, bottom - 62), 68)
	_place_pad("pause", Vector2(right - 22, top + 22), 46)


func _place_pad(action: String, center: Vector2, diameter: float) -> void:
	var pad: TouchPad = _touch_pads[action]
	pad.position = center - Vector2.ONE * diameter * 0.5
	pad.size = Vector2.ONE * diameter
	pad.queue_redraw()


func show_menu(best: int = 0) -> void:
	_change_mode("menu")
	_bank_label.text = "SALVAGE BANKED  /  %02d" % best


func show_game() -> void:
	_change_mode("game")


func show_pause() -> void:
	_change_mode("pause")


func show_result(won: bool, loot: int, elapsed: float, bank: int) -> void:
	_change_mode("result")
	_result_title.text = "EXTRACTED" if won else "SIGNAL LOST"
	_result_title.add_theme_color_override("font_color", CYAN if won else RED)
	_result_detail.text = "You made it out. The salvage is yours." if won else "The floodworks keep what you leave behind."
	_result_stats.text = "RUN TIME       %s\nSALVAGE        %d %s\nBANK TOTAL     %d" % [_format_time(elapsed), loot, "RECOVERED" if won else "LOST", bank]


func _change_mode(mode: String) -> void:
	_release_touches()
	_mode = mode
	_menu.visible = mode == "menu"
	_game.visible = mode in ["game", "pause"]
	_pause.visible = mode == "pause"
	_results.visible = mode == "result"
	_touch.visible = touch_enabled and mode == "game"


func update_state(data: Dictionary) -> void:
	if not is_instance_valid(_health_label):
		return
	var health: float = clampf(float(data.get("health", 100.0)), 0.0, 100.0)
	var speed: float = float(data.get("speed", 0.0))
	var tension: float = maxf(0.0, float(data.get("tension", 0.0)))
	var charge: float = clampf(float(data.get("charge", 0.0)), 0.0, 1.0)
	var weapon: String = str(data.get("weapon", "ROD"))
	var reel: String = str(data.get("reel_state", "READY"))
	var loot: int = int(data.get("loot", 0))
	var total_loot: int = int(data.get("total_loot", 3))
	var inside: bool = bool(data.get("extraction_inside", false))
	var extraction: float = clampf(float(data.get("extraction", 0.0)), 0.0, 1.0)
	_health_label.text = "CONDITION   %03d" % int(health)
	_health_label.add_theme_color_override("font_color", RED if health < 30 else PAPER)
	_health_bar.value = health / 100.0
	_speed_label.text = "%.1f M/S   /   %s" % [speed, "FAST" if speed > 15 else "MOVING"]
	_clock_label.text = _format_time(float(data.get("time", 0.0)))
	_loot_label.text = "SALVAGE   %d / %d" % [loot, total_loot]
	_mission_label.text = "HOLD POSITION  /  EXTRACTING" if inside and loot >= total_loot else ("RECOVER ALL CASES TO EXTRACT" if inside else ("REACH THE CYAN EXTRACTION ZONE" if loot >= total_loot else "RECOVER THE MARKED CASES"))
	_extract_bar.visible = inside and loot >= total_loot
	_extract_bar.value = extraction
	_weapon_label.text = "01  /  CASTING RIG" if weapon == "ROD" else "02  /  SIDEARM"
	_ammo_label.text = "" if weapon == "ROD" else ("RELOADING" if bool(data.get("reloading", false)) else "%02d / %02d" % [int(data.get("ammo", 0)), int(data.get("reserve", 0))])
	_rod_label.text = "CHARGING   %d%%" % int(charge * 100) if charge > 0 else reel.to_upper()
	_line_label.text = "%.1f M LINE   /   %.1f kN TENSION" % [float(data.get("line_length", 0.0)), tension / 1000.0]
	_tension_bar.value = clampf(tension / 25000.0, 0.0, 1.0)
	_charge_bar.value = charge
	_charge_bar.visible = charge > 0.0
	_hint.text = str(data.get("hint", _hint_override))
	_practice_label.visible = bool(data.get("practice", false))
	_reticle.hit = clampf(float(data.get("hitmarker", 0.0)), 0.0, 1.0)
	_reticle.danger = clampf(float(data.get("danger", 0.0)), 0.0, 1.0)
	_reticle.sidearm = weapon != "ROD"
	_reticle.queue_redraw()
	if touch_enabled:
		var cast_pad: TouchPad = _touch_pads["cast"]
		var weapon_pad: TouchPad = _touch_pads["weapon"]
		var lock_pad: TouchPad = _touch_pads["lock"]
		cast_pad.caption = "CAST" if weapon == "ROD" else "FIRE"
		weapon_pad.caption = "GUN" if weapon == "ROD" else "ROD"
		lock_pad.caption = "FREE" if "LOCK" in reel.to_upper() or "REEL" in reel.to_upper() else "LOCK"
		cast_pad.queue_redraw()
		weapon_pad.queue_redraw()
		lock_pad.queue_redraw()


func set_hint(text: String) -> void:
	_hint_override = text
	if is_instance_valid(_hint):
		_hint.text = text


func _format_time(seconds: float) -> String:
	var total: int = maxi(0, int(seconds))
	return "%02d:%02d" % [total / 60, total % 60]


func _input(event: InputEvent) -> void:
	if _mode != "game" or not touch_enabled:
		return
	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event
		if touch_event.pressed:
			_begin_touch(touch_event.index, touch_event.position)
		else:
			_end_touch(touch_event.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		var role: String = str(_touch_roles.get(drag.index, ""))
		if role == "move":
			_move_stick(drag.position)
		elif role in ["look", "cast", "reel"]:
			look_requested.emit(drag.relative)
		get_viewport().set_input_as_handled()


func _begin_touch(index: int, position: Vector2) -> void:
	if _touch_roles.has(index):
		_end_touch(index)
	var role := "look"
	for action in _touch_pads:
		var pad: TouchPad = _touch_pads[action]
		if position.distance_to(pad.global_position + pad.size * 0.5) <= pad.size.x * 0.5 and not action in _touch_roles.values():
			role = action
			break
	if role == "look" and position.x < _last_size.x * 0.4 and position.y > _last_size.y * 0.4 and not "move" in _touch_roles.values():
		role = "move"
	_touch_roles[index] = role
	if role == "move":
		_stick.held = true
		_move_stick(position)
	elif role != "look":
		var pad: TouchPad = _touch_pads[role]
		pad.held = true
		pad.queue_redraw()
		action_requested.emit(role, true)


func _move_stick(position: Vector2) -> void:
	var raw: Vector2 = (position - (_stick.global_position + _stick.size * 0.5)) / (_stick.size.x * 0.38)
	raw = raw.limit_length(1.0)
	move_vector = Vector2.ZERO if raw.length() < 0.12 else raw.normalized() * ((raw.length() - 0.12) / 0.88)
	_stick.stick_value = raw
	_stick.queue_redraw()


func _end_touch(index: int) -> void:
	if not _touch_roles.has(index):
		return
	var role: String = str(_touch_roles[index])
	_touch_roles.erase(index)
	if role == "move":
		move_vector = Vector2.ZERO
		_stick.held = false
		_stick.stick_value = Vector2.ZERO
		_stick.queue_redraw()
	elif role != "look":
		var pad: TouchPad = _touch_pads[role]
		pad.held = false
		pad.queue_redraw()
		action_requested.emit(role, false)


func _release_touches() -> void:
	for index in _touch_roles.keys():
		_end_touch(int(index))
	move_vector = Vector2.ZERO
