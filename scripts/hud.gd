extends CanvasLayer
## Native in-game interface and touch input. Desktop input belongs to main.gd. Menus, pause and
## the result screen belong to ui_root.gd (CONTRACT 4.15). Layout follows CONTRACT 4.14 and 5.9:
## vitals top-left, timer and medal target top-centre, objectives top-right, reticle at the
## centre, weapon and line bottom-centre, hints above them.

const UiTheme = preload("res://scripts/ui/theme.gd")

signal action_requested(action: String, pressed: bool)
signal look_requested(delta: Vector2)

const PANEL := Color(0.035, 0.075, 0.085, 0.9)
const PANEL_EDGE := Color(0.43, 0.65, 0.64, 0.18)
const PAPER := Color("e5ebe5")
const MUTED := Color("94aaa9")
const AMBER := Color("f5b45b")
const CYAN := Color("67d5d2")
const RED := Color("ed7263")

## Margin kept between the screen edge and every panel, before device insets are added.
const EDGE := 24.0
## Health below this value makes the health panel border pulse.
const LOW_HEALTH := 30.0
## Full-scale line tension in newtons (the gauge reads 0..25 kN).
const TENSION_FULL := 25000.0
## Speed above this (m/s) reads as FAST.
const FAST_SPEED := 15.0
## On touch the pause pad sits in the top-right corner, so the objectives panel drops below it.
const TOUCH_TOP_OFFSET := 56.0

var move_vector := Vector2.ZERO
var touch_enabled: bool = false
## Numeric readouts (speed, line tension, charge percent) show only when this is on.
var show_telemetry: bool = true
## Device insets in canvas pixels (left, top, right, bottom). Tests set it to fake a notch;
## a negative x means "use the device".
var safe_insets_override := Vector4(-1.0, -1.0, -1.0, -1.0)
var _active := false
var _root: Control
var _game: Control
var _touch: Control
var _vignette: Vignette
var _health_panel: PanelContainer
var _health_style: StyleBoxFlat
var _health_label: Label
var _health_bar: ProgressBar
var _speed_label: Label
var _timer_panel: PanelContainer
var _clock_label: Label
var _target_label: Label
var _practice_label: Label
var _objective_panel: PanelContainer
var _loot_label: Label
var _bonus_label: Label
var _mission_label: Label
var _extract_bar: ProgressBar
var _reticle: Reticle
var _reticle_state: Label
var _equipment_panel: PanelContainer
var _weapon_label: Label
var _ammo_label: Label
var _rod_label: Label
var _line_label: Label
var _tension_bar: ProgressBar
var _charge_bar: ProgressBar
var _hint: Label
var _bottom_controls: Label
var _banner: PanelContainer
var _banner_title: Label
var _banner_subtitle: Label
var _banner_time := 0.0
var _banner_duration := 0.0
var _touch_pads: Dictionary = {}
var _touch_roles: Dictionary = {}
var _stick: TouchPad
var _last_size := Vector2.ZERO
var _hint_override := ""
var _clock := 0.0
var _low_health := false
var _pulse_applied := false


## Full-screen red edge that warns of nearby danger.
class Vignette extends Control:

	var danger := 0.0

	func _draw() -> void:
		if danger <= 0.01:
			return
		var edge := Color(0.83, 0.19, 0.12, danger * 0.45)
		draw_rect(Rect2(Vector2.ZERO, size), edge, false, 7.0)
		draw_rect(Rect2(Vector2(7, 7), size - Vector2(14, 14)), Color(edge, edge.a * 0.4), false, 15.0)


## Reticle centred on the ring: crosshair, a tension ring and a charge arc. The control is 160 x 184;
## the ring sits in the top 160 px and the state text hangs underneath it.
class Reticle extends Control:

	var hit := 0.0
	var sidearm := false
	var charge := 0.0
	var tension := 0.0

	func _draw() -> void:
		var center := Vector2(size.x * 0.5, size.x * 0.5)
		var ink := Color(0.88, 0.96, 0.92, 0.85)
		draw_circle(center, 2.0, ink)
		var gap: float = 6.0 if sidearm else 11.0
		for axis in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			draw_line(center + axis * gap, center + axis * (gap + 5.0), Color(ink, 0.48), 1.2, true)
		# Tension ring: a faint track, and a sweep that grows with line tension and reddens near snap.
		draw_arc(center, 58.0, 0.0, TAU, 96, Color(ink, 0.12), 2.0, true)
		if tension > 0.001:
			var ring: Color = Color("ed7263") if tension > 0.85 else Color("67d5d2")
			draw_arc(center, 58.0, -PI * 0.5, -PI * 0.5 + tension * TAU, 96, Color(ring, 0.9), 3.0, true)
		# Charge arc: fills clockwise while the rod charges.
		if charge > 0.0:
			draw_arc(center, 46.0, -PI * 0.5, -PI * 0.5 + charge * TAU, 64, Color(1.0, 0.77, 0.4, 0.95), 3.0, true)
		if hit > 0.0:
			for axis in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				draw_line(center + axis * 8.0, center + axis * 14.0, Color(1.0, 0.77, 0.4, hit), 2.5, true)


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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	touch_enabled = OS.has_feature("mobile") or "--touch" in OS.get_cmdline_user_args()
	_root = _control(self)
	_fill(_root)
	_build_game()
	_build_touch()
	_reflow()
	set_active(false)


func _process(delta: float) -> void:
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	if view_size != _last_size:
		_reflow()
	if not _active:
		return
	_clock += delta
	_update_pulse()
	_update_banner(delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		release_touches()


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
	node.add_theme_stylebox_override("panel", _style(PANEL, PANEL_EDGE, padding))
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


# --- Layout build (all controls exist once; _reflow places them) ------------------------------

func _build_game() -> void:
	_game = _control(_root)
	_fill(_game)
	_vignette = Vignette.new()
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_game.add_child(_vignette)
	_fill(_vignette)
	_build_vitals()
	_build_timer()
	_build_objectives()
	_build_reticle()
	_build_equipment()
	_hint = _label(_game, "", 16, PAPER)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_hint.add_theme_constant_override("shadow_offset_y", 2)
	_bottom_controls = _label(_game, "LMB CAST    RMB LOCK    E REEL    Q CUT    F WEAPON    R RELOAD    ESC PAUSE", 12, MUTED)
	_bottom_controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_build_banner()


func _build_vitals() -> void:
	_health_panel = _panel(_game, 14)
	_health_style = _health_panel.get_theme_stylebox("panel") as StyleBoxFlat
	var vitals := _vbox(_health_panel, 6)
	_health_label = _label(vitals, "CONDITION   100", 18)
	_health_bar = _bar(vitals, CYAN, 4)
	_speed_label = _label(vitals, "GROUNDED", 12, MUTED)


func _build_timer() -> void:
	_timer_panel = _panel(_game, 10)
	var clock := _vbox(_timer_panel, 0)
	_clock_label = _label(clock, "00:00", 28)
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_label = _label(clock, "BRONZE   /   EXTRACT TO BANK", 12, MUTED)
	_target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_practice_label = _label(_game, "PRACTICE / NO HOSTILES", 12, CYAN)
	_practice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _build_objectives() -> void:
	_objective_panel = _panel(_game, 14)
	var objective := _vbox(_objective_panel, 5)
	_loot_label = _label(objective, "SALVAGE   0 / 3", 20, AMBER)
	_bonus_label = _label(objective, "BONUS   NONE THIS RAID", 14, CYAN)
	_mission_label = _label(objective, "RECOVER THE MARKED CASES", 11, MUTED)
	_extract_bar = _bar(objective, CYAN, 4)
	_extract_bar.visible = false


func _build_reticle() -> void:
	_reticle = Reticle.new()
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_game.add_child(_reticle)
	_reticle_state = _label(_reticle, "READY TO CAST", 13, PAPER)
	_reticle_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reticle_state.position = Vector2(-30.0, 150.0)
	_reticle_state.size = Vector2(220, 22)


func _build_equipment() -> void:
	_equipment_panel = _panel(_game, 14)
	var equipment := _vbox(_equipment_panel, 5)
	var weapon_row := HBoxContainer.new()
	weapon_row.add_theme_constant_override("separation", 12)
	weapon_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	equipment.add_child(weapon_row)
	_weapon_label = _label(weapon_row, "01  /  CASTING RIG", 13, AMBER)
	_weapon_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ammo_label = _label(weapon_row, "", 14, PAPER)
	_rod_label = _label(equipment, "READY TO CAST", 18)
	_line_label = _label(equipment, "0.0 M LINE   /   0.0 kN TENSION", 12, MUTED)
	_tension_bar = _bar(equipment, CYAN, 4)
	_charge_bar = _bar(equipment, AMBER, 3)
	_charge_bar.visible = false


func _build_banner() -> void:
	_banner = _panel(_game, 16)
	_banner.visible = false
	var content := _vbox(_banner, 4)
	_banner_title = _label(content, "", 30, AMBER)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_subtitle = _label(content, "", 15, MUTED)
	_banner_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


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


# --- Layout ------------------------------------------------------------------------------------

## Device safe-area insets in canvas pixels (left, top, right, bottom). Zero on desktop.
func _device_insets(view: Vector2) -> Vector4:
	if safe_insets_override.x >= 0.0:
		return safe_insets_override
	if not OS.has_feature("mobile"):
		return Vector4.ZERO
	var safe_rect: Rect2i = DisplayServer.get_display_safe_area()
	var window_size: Vector2i = DisplayServer.window_get_size()
	if window_size.x <= 0 or window_size.y <= 0 or safe_rect.size.x <= 0:
		return Vector4.ZERO
	var scale_x: float = view.x / float(window_size.x)
	var scale_y: float = view.y / float(window_size.y)
	return Vector4(
		maxf(0.0, safe_rect.position.x * scale_x),
		maxf(0.0, safe_rect.position.y * scale_y),
		maxf(0.0, (window_size.x - safe_rect.end.x) * scale_x),
		maxf(0.0, (window_size.y - safe_rect.end.y) * scale_y))


func _reflow() -> void:
	if not is_instance_valid(_root):
		return
	var view: Vector2 = get_viewport().get_visible_rect().size
	_last_size = view
	var insets: Vector4 = _device_insets(view)
	var left: float = maxf(EDGE, insets.x + 12.0)
	var top: float = maxf(EDGE, insets.y + 12.0)
	var right: float = view.x - maxf(EDGE, insets.z + 12.0)
	var bottom: float = view.y - maxf(EDGE, insets.w + 12.0)
	var mid_x: float = view.x * 0.5
	var mid_y: float = view.y * 0.5

	# Top row: vitals, timer and objectives.
	_health_panel.position = Vector2(left, top)
	_health_panel.size = Vector2(216, 96)
	_timer_panel.position = Vector2(mid_x - 130.0, top)
	_timer_panel.size = Vector2(260, 74)
	_practice_label.position = Vector2(mid_x - 120.0, top + 80.0)
	_practice_label.size = Vector2(240, 20)
	var objectives_top: float = top + (TOUCH_TOP_OFFSET if touch_enabled else 0.0)
	_objective_panel.position = Vector2(right - 262.0, objectives_top)
	_objective_panel.size = Vector2(262, 112)

	# Centre: the ring is centred on the screen, its state text hangs below it.
	_reticle.position = Vector2(mid_x - 80.0, mid_y - 80.0)
	_reticle.size = Vector2(160, 184)

	# Bottom: weapon and line, hints above them, and the keyboard strip on desktop.
	var equip_bottom: float = bottom if touch_enabled else bottom - 30.0
	_equipment_panel.size = Vector2(340, 118)
	_equipment_panel.position = Vector2(mid_x - 170.0, equip_bottom - 118.0)
	# Narrower than the screen so a long hint never reaches the touch buttons.
	var hint_width: float = view.x * 0.44
	_hint.size = Vector2(hint_width, 56)
	_hint.position = Vector2(mid_x - hint_width * 0.5, equip_bottom - 118.0 - 12.0 - 56.0)
	_bottom_controls.visible = not touch_enabled
	_bottom_controls.position = Vector2(left, bottom - 22.0)
	_bottom_controls.size = Vector2(right - left, 22)

	# Banner: centred under the timer, clear of the objectives panel.
	var banner_width: float = view.x * 0.5
	# Size is set too, not only the minimum: a stale size would keep the panel tall after a resize.
	_banner.custom_minimum_size = Vector2(banner_width, 0)
	_banner.size = Vector2(banner_width, 0)
	_banner.position = Vector2(mid_x - banner_width * 0.5, top + 110.0)

	# Touch controls: stick bottom-left, buttons bottom-right, pause top-right.
	_stick.position = Vector2(left + 14.0, bottom - 180.0)
	_stick.size = Vector2(158, 158)
	_place_pad("cast", Vector2(right - 66.0, bottom - 133.0), 112.0)
	_place_pad("reel", Vector2(right - 188.0, bottom - 64.0), 94.0)
	_place_pad("lock", Vector2(right - 180.0, bottom - 180.0), 82.0)
	_place_pad("cut", Vector2(right - 66.0, bottom - 255.0), 66.0)
	_place_pad("weapon", Vector2(right - 276.0, bottom - 170.0), 70.0)
	_place_pad("reload", Vector2(right - 268.0, bottom - 264.0), 64.0)
	_place_pad("jump", Vector2(right - 294.0, bottom - 62.0), 68.0)
	_place_pad("pause", Vector2(right - 22.0, top + 22.0), 46.0)


func _place_pad(action: String, center: Vector2, diameter: float) -> void:
	var pad: TouchPad = _touch_pads[action]
	pad.position = center - Vector2.ONE * diameter * 0.5
	pad.size = Vector2.ONE * diameter
	pad.queue_redraw()


# --- Public API (CONTRACT 4.14) ----------------------------------------------------------------

## Shows or hides the in-game layer. Hiding also releases every held touch, so a pause or a
## result never leaves an action stuck down. The CanvasLayer's own visibility stays with main.gd.
func set_active(value: bool) -> void:
	if not value:
		release_touches()
	_active = value
	if value:
		_reflow()
	_game.visible = value
	_touch.visible = touch_enabled and value
	if not value:
		_banner_time = 0.0
		_banner.visible = false


func show_game() -> void:
	set_active(true)


## Kept for main.gd: the menus now belong to ui_root, so this only hides the in-game layer.
func show_menu() -> void:
	set_active(false)


func release_touches() -> void:
	for index in _touch_roles.keys():
		_end_touch(int(index))
	move_vector = Vector2.ZERO


## Reads the profile settings the HUD uses. G7 adds the touch options here.
func apply_settings(settings: Dictionary) -> void:
	show_telemetry = bool(settings.get("show_telemetry", true))


func show_banner(title: String, subtitle: String = "", duration: float = 2.5, accent: String = "amber") -> void:
	_banner_title.text = title
	_banner_title.add_theme_color_override("font_color", _accent_color(accent))
	_banner_subtitle.text = subtitle
	_banner_subtitle.visible = not subtitle.is_empty()
	_banner_duration = maxf(duration, 0.05)
	_banner_time = _banner_duration
	_banner.modulate.a = 0.0
	_banner.visible = true


func update_state(data: Dictionary) -> void:
	if not is_instance_valid(_health_label):
		return
	var health: float = clampf(float(data.get("health", 100.0)), 0.0, 100.0)
	var speed: float = float(data.get("speed", 0.0))
	var airborne: bool = bool(data.get("airborne", false))
	var tension: float = maxf(0.0, float(data.get("tension", 0.0)))
	var tension_norm: float = clampf(tension / TENSION_FULL, 0.0, 1.0)
	var charge: float = clampf(float(data.get("charge", 0.0)), 0.0, 1.0)
	var weapon: String = str(data.get("weapon", "ROD"))
	var sidearm: bool = weapon != "ROD"
	var reel: String = str(data.get("reel_state", "READY TO CAST"))
	var loot: int = int(data.get("loot", 0))
	var total_loot: int = int(data.get("total_loot", 3))
	var inside: bool = bool(data.get("extraction_inside", false))
	var extract_ready: bool = bool(data.get("extraction_ready", loot >= total_loot))

	_update_vitals(health, speed, airborne)
	_update_timer(float(data.get("time", 0.0)), float(data.get("par_silver", 0.0)), float(data.get("par_gold", 0.0)))
	_update_objectives(loot, total_loot, int(data.get("bonus", 0)), int(data.get("total_bonus", 0)), inside, extract_ready, clampf(float(data.get("extraction", 0.0)), 0.0, 1.0))
	_update_weapon(data, sidearm, charge, reel, tension, tension_norm)
	_update_reticle(data, charge, reel, tension, tension_norm, sidearm)
	_hint.text = str(data.get("hint", _hint_override))
	_practice_label.visible = bool(data.get("practice", false))
	if touch_enabled:
		_update_captions(sidearm, reel)


func set_hint(text: String) -> void:
	_hint_override = text
	if is_instance_valid(_hint):
		_hint.text = text


# --- State readouts ----------------------------------------------------------------------------

func _update_vitals(health: float, speed: float, airborne: bool) -> void:
	_low_health = health < LOW_HEALTH
	_health_label.text = "CONDITION   %03d" % int(health)
	_health_label.add_theme_color_override("font_color", RED if _low_health else PAPER)
	_health_bar.value = health / 100.0
	var state: String = "AIRBORNE" if airborne else ("FAST" if speed > FAST_SPEED else "GROUNDED")
	_speed_label.text = "%.1f M/S   /   %s" % [speed, state] if show_telemetry else state


## Timer plus the next medal target: gold while its par is still reachable, then silver, then bronze.
func _update_timer(elapsed: float, par_silver: float, par_gold: float) -> void:
	_clock_label.text = _format_time(elapsed)
	var medal: int = 1
	var par: float = 0.0
	if par_gold > 0.0 and elapsed <= par_gold:
		medal = 3
		par = par_gold
	elif par_silver > 0.0 and elapsed <= par_silver:
		medal = 2
		par = par_silver
	if medal == 1:
		_target_label.text = "BRONZE   /   EXTRACT TO BANK"
	else:
		_target_label.text = "NEXT %s   %s" % [UiTheme.MEDAL_NAMES[medal], _format_time(par)]
	_target_label.add_theme_color_override("font_color", UiTheme.MEDAL_COLORS[medal])


func _update_objectives(loot: int, total_loot: int, bonus: int, total_bonus: int, inside: bool, extract_ready: bool, extraction: float) -> void:
	_loot_label.text = "SALVAGE   %d / %d" % [loot, total_loot]
	_bonus_label.text = "BONUS   %d / %d" % [bonus, total_bonus] if total_bonus > 0 else "BONUS   NONE THIS RAID"
	_mission_label.text = _mission_text(inside, extract_ready)
	_extract_bar.visible = inside and extract_ready
	_extract_bar.value = extraction


func _mission_text(inside: bool, extract_ready: bool) -> String:
	if inside and extract_ready:
		return "HOLD POSITION  /  EXTRACTING"
	if inside:
		return "RECOVER ALL CASES TO EXTRACT"
	if extract_ready:
		return "REACH THE CYAN EXTRACTION ZONE"
	return "RECOVER THE MARKED CASES"


func _update_weapon(data: Dictionary, sidearm: bool, charge: float, reel: String, tension: float, tension_norm: float) -> void:
	_weapon_label.text = "02  /  SIDEARM" if sidearm else "01  /  CASTING RIG"
	if not sidearm:
		_ammo_label.text = ""
	elif bool(data.get("reloading", false)):
		_ammo_label.text = "RELOADING"
	else:
		_ammo_label.text = "%02d / %02d" % [int(data.get("ammo", 0)), int(data.get("reserve", 0))]
	if charge > 0.0:
		_rod_label.text = "CHARGING   %d%%" % int(charge * 100.0) if show_telemetry else "CHARGING"
	else:
		_rod_label.text = reel.to_upper()
	if show_telemetry:
		_line_label.text = "%.1f M LINE   /   %.1f kN TENSION" % [float(data.get("line_length", 0.0)), tension / 1000.0]
	else:
		_line_label.text = "LINE TAUT" if tension > 1000.0 else "LINE SLACK"
	_tension_bar.value = tension_norm
	_charge_bar.value = charge
	_charge_bar.visible = charge > 0.0


func _update_reticle(data: Dictionary, charge: float, reel: String, tension: float, tension_norm: float, sidearm: bool) -> void:
	_reticle.hit = clampf(float(data.get("hitmarker", 0.0)), 0.0, 1.0)
	_reticle.sidearm = sidearm
	_reticle.charge = charge
	_reticle.tension = tension_norm
	_reticle.queue_redraw()
	_vignette.danger = clampf(float(data.get("danger", 0.0)), 0.0, 1.0)
	_vignette.queue_redraw()
	_reticle_state.text = _state_text(data, charge, reel, tension)
	_reticle_state.add_theme_color_override("font_color", RED if bool(data.get("alert", false)) else PAPER)


## Short state word under the reticle. Numbers are appended only when telemetry is on.
func _state_text(data: Dictionary, charge: float, reel: String, tension: float) -> String:
	if bool(data.get("reloading", false)):
		return "RELOADING"
	if charge > 0.0:
		return "CHARGING"
	if str(data.get("weapon", "ROD")) != "ROD":
		return "SIDEARM"
	var text: String = reel.to_upper()
	if show_telemetry and tension > 0.0:
		text += "   %.1f kN" % (tension / 1000.0)
	return text


func _update_captions(sidearm: bool, reel: String) -> void:
	var cast_pad: TouchPad = _touch_pads["cast"]
	var weapon_pad: TouchPad = _touch_pads["weapon"]
	var lock_pad: TouchPad = _touch_pads["lock"]
	cast_pad.caption = "FIRE" if sidearm else "CAST"
	weapon_pad.caption = "ROD" if sidearm else "GUN"
	lock_pad.caption = "FREE" if "LOCK" in reel.to_upper() or "REEL" in reel.to_upper() else "LOCK"
	cast_pad.queue_redraw()
	weapon_pad.queue_redraw()
	lock_pad.queue_redraw()


# --- Per-frame effects -------------------------------------------------------------------------

## Pulses the health panel border while condition is low.
func _update_pulse() -> void:
	if _low_health:
		var beat: float = 0.5 + 0.5 * sin(_clock * 7.0)
		_health_style.border_color = Color(RED, 0.2 + 0.6 * beat)
		_health_style.set_border_width_all(2)
		_pulse_applied = true
	elif _pulse_applied:
		_health_style.border_color = PANEL_EDGE
		_health_style.set_border_width_all(1)
		_pulse_applied = false


## Fades the banner in and out over its duration.
func _update_banner(delta: float) -> void:
	if _banner_time <= 0.0:
		return
	_banner_time = maxf(0.0, _banner_time - delta)
	var fade_in: float = minf(1.0, (_banner_duration - _banner_time) / 0.25)
	var fade_out: float = minf(1.0, _banner_time / 0.4)
	_banner.modulate.a = minf(fade_in, fade_out)
	_banner.visible = _banner_time > 0.0


func _accent_color(accent: String) -> Color:
	match accent:
		"cyan":
			return CYAN
		"red":
			return RED
		"paper":
			return PAPER
	return AMBER


func _format_time(seconds: float) -> String:
	var total: int = maxi(0, int(seconds))
	return "%02d:%02d" % [total / 60, total % 60]


# --- Touch routing (unchanged since the first HUD; see tests/hud_test.gd) -----------------------

func _input(event: InputEvent) -> void:
	if not _active or not touch_enabled:
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
