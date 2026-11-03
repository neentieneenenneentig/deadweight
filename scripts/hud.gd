extends CanvasLayer
## Native in-game interface and touch input. Desktop input belongs to main.gd. Menus, pause and
## the result screen belong to ui_root.gd (CONTRACT 4.15). Layout follows CONTRACT 4.14 and 5.9:
## vitals top-left, timer and medal target top-centre, objectives top-right, reticle at the
## centre, weapon and line bottom-centre, hints above them. G7 adds world markers and damage
## arcs under the panels, speed and danger vignettes, and the touch options (CONTRACT 5.2).

const UiTheme = preload("res://scripts/ui/theme.gd")

signal action_requested(action: String, pressed: bool)
signal look_requested(delta: Vector2)

const PANEL := UiTheme.PANEL
const PANEL_EDGE := Color(0.78, 0.69, 0.52, 0.3)
const PAPER := UiTheme.PAPER
const MUTED := UiTheme.MUTED
const AMBER := UiTheme.AMBER
const CYAN := UiTheme.CYAN
const RED := UiTheme.RED
## Extraction markers are green-white so they read apart from the cyan salvage and amber bonus.
const EXTRACT_COLOR := Color("d2f7d6")

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
## Damage arcs live this long (seconds) and fade over that time, on a ring round the reticle.
const ARC_LIFETIME := 0.8
const ARC_RADIUS := 84.0
## Half-width of an arc in radians (about 18 degrees either side of the source bearing).
const ARC_SPAN := 0.32
const ARC_WIDTH := 4.0
## Oldest arcs are dropped beyond this count, so a burst of hits stays readable.
const MAX_ARCS := 6
## Objective markers and their edge arrows stay this far from the screen edge (before insets).
const MARKER_EDGE := 44.0
## Speed band for the speed vignette: nothing below START, full strength at FULL (m/s).
const SPEED_VIGNETTE_START := 14.0
const SPEED_VIGNETTE_FULL := 24.0
## Touch options (CONTRACT 5.2) are clamped to these ranges.
const TOUCH_SCALE_RANGE := Vector2(0.75, 1.35)
const TOUCH_OPACITY_RANGE := Vector2(0.3, 1.0)

var move_vector := Vector2.ZERO
var touch_enabled: bool = false
## Numeric readouts (speed, line tension, charge percent) show only when this is on.
var show_telemetry: bool = true
## Touch options from the profile: pad size multiplier, pad opacity and the mirrored layout.
var touch_scale: float = 1.0
var touch_opacity: float = 0.8
var touch_left_handed: bool = false
## Device insets in canvas pixels (left, top, right, bottom). Tests set it to fake a notch;
## a negative x means "use the device".
var safe_insets_override := Vector4(-1.0, -1.0, -1.0, -1.0)
var _active := false
var _root: Control
var _game: Control
var _touch: Control
var _vignette: Vignette
var _speed_vignette: Vignette
var _overlay: WorldOverlay
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
## Objectives from main.gd (CONTRACT 5.8) and the camera they are projected through.
var _objectives: Array = []
var _camera: Camera3D
## Live damage arcs: {"bearing": float (radians, NAN = no direction), "time", "amount", "source"}.
var _arcs: Array = []


## Full-screen edge tint. Strength 0..1 sets how far the edge glow reaches.
class Vignette extends Control:

	var strength := 0.0
	var tint := Color(0.83, 0.19, 0.12)

	func _draw() -> void:
		if strength <= 0.01:
			return
		var edge := Color(tint, strength * 0.45)
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


## World-space HUD: damage arcs round the reticle and objective markers (diamonds on screen,
## arrows on the edge when off screen). HUD fills both lists every frame; the panels draw above it.
class WorldOverlay extends Control:

	var markers: Array = []
	var arcs: Array = []

	func _draw() -> void:
		for arc: Dictionary in arcs:
			_draw_arc(arc)
		for marker: Dictionary in markers:
			_draw_marker(marker)

	## Arc fades with its remaining time and points at the source bearing (0 = straight ahead).
	func _draw_arc(arc: Dictionary) -> void:
		var fade: float = clampf(float(arc["time"]) / ARC_LIFETIME, 0.0, 1.0)
		var centre: Vector2 = size * 0.5
		var width: float = ARC_WIDTH + clampf(float(arc["amount"]) / 25.0, 0.0, 1.0) * 3.0
		var bearing: float = arc["bearing"]
		if is_nan(bearing):
			# No usable direction (fall damage, or a source directly overhead): a faint full ring.
			draw_arc(centre, ARC_RADIUS, 0.0, TAU, 64, Color(RED, 0.4 * fade), width, true)
			return
		var heading: float = Vector2(sin(bearing), -cos(bearing)).angle()
		draw_arc(centre, ARC_RADIUS, heading - ARC_SPAN, heading + ARC_SPAN, 24, Color(RED, 0.95 * fade), width, true)

	## Entry keys (from HUD._marker_entry): on_screen, point, direction, color, active, next, distance.
	## Done (inactive) markers dim, the next objective is largest and brightest.
	func _draw_marker(marker: Dictionary) -> void:
		var color: Color = marker["color"]
		var alpha: float = 1.0 if bool(marker["next"]) else (0.7 if bool(marker["active"]) else 0.3)
		color.a *= alpha
		var label: String = "%d M" % roundi(float(marker["distance"]))
		var point: Vector2 = marker["point"]
		if bool(marker["on_screen"]):
			var radius: float = 13.0 if bool(marker["next"]) else 9.0
			var diamond := PackedVector2Array([
				point + Vector2(0, -radius), point + Vector2(radius, 0),
				point + Vector2(0, radius), point + Vector2(-radius, 0)])
			draw_colored_polygon(diamond, Color(color, color.a * 0.18))
			var outline: PackedVector2Array = diamond.duplicate()
			outline.append(diamond[0])
			draw_polyline(outline, color, 2.0, true)
			_draw_label(label, Vector2(point.x, point.y + radius + 16.0), color)
			return
		# Off screen: a chevron on the edge, pointing toward the objective, with its distance inside.
		var direction: Vector2 = marker["direction"]
		var side := Vector2(-direction.y, direction.x)
		var arrow := PackedVector2Array([
			point + direction * 14.0,
			point - direction * 6.0 + side * 9.0,
			point - direction * 6.0 - side * 9.0])
		draw_colored_polygon(arrow, color)
		_draw_label(label, point - direction * 30.0, color)

	## Small centred caption with a shadow so it reads over bright ground.
	func _draw_label(text: String, centre: Vector2, color: Color) -> void:
		var font: Font = ThemeDB.fallback_font
		var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var origin := Vector2(centre.x - width * 0.5, centre.y + 4.0)
		draw_string(font, origin + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0, 0, 0, 0.7))
		draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)


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
	_tick_effects(delta)
	_refresh_markers()


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
	# Tints first, so the markers, arcs and every panel draw above them.
	_vignette = Vignette.new()
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_game.add_child(_vignette)
	_fill(_vignette)
	_speed_vignette = Vignette.new()
	_speed_vignette.tint = CYAN
	_speed_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_game.add_child(_speed_vignette)
	_fill(_speed_vignette)
	_overlay = WorldOverlay.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.arcs = _arcs
	_game.add_child(_overlay)
	_fill(_overlay)
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
	# These labels float over bright porcelain and sky rather than an opaque panel.
	for floating_label: Label in [_bottom_controls, _reticle_state, _practice_label]:
		floating_label.add_theme_color_override("font_outline_color", UiTheme.INK)
		floating_label.add_theme_constant_override("outline_size", 3)
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

	# Touch controls: stick bottom-left, buttons bottom-right, pause top-right. Left-handed mirrors
	# the thumb controls to the other side; the pause pad stays top-right because the vitals sit top-left.
	_place_control(_stick, Vector2(left + 93.0, bottom - 101.0), 158.0)
	_place_pad("cast", Vector2(right - 66.0, bottom - 133.0), 112.0)
	_place_pad("reel", Vector2(right - 188.0, bottom - 64.0), 94.0)
	_place_pad("lock", Vector2(right - 180.0, bottom - 180.0), 82.0)
	_place_pad("cut", Vector2(right - 66.0, bottom - 255.0), 66.0)
	_place_pad("weapon", Vector2(right - 276.0, bottom - 170.0), 70.0)
	_place_pad("reload", Vector2(right - 268.0, bottom - 264.0), 64.0)
	_place_pad("jump", Vector2(right - 294.0, bottom - 62.0), 68.0)
	_place_pad("pause", Vector2(right - 22.0, top + 22.0), 46.0, false)


func _place_pad(action: String, center: Vector2, diameter: float, mirror: bool = true) -> void:
	var pad: TouchPad = _touch_pads[action]
	_place_control(pad, center, diameter, mirror)


## Places a touch control centred on center, scaled by touch_scale. Left-handed mirrors centre x
## across the screen, so the thumb layout keeps the same spacing on the other side.
func _place_control(control: TouchPad, center: Vector2, diameter: float, mirror: bool = true) -> void:
	var placed: Vector2 = center
	if mirror and touch_left_handed:
		placed.x = _last_size.x - center.x
	var side: float = diameter * touch_scale
	control.position = placed - Vector2.ONE * side * 0.5
	control.size = Vector2.ONE * side
	control.queue_redraw()


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


## Reads the profile settings the HUD owns (CONTRACT 5.2): show_telemetry, touch_scale,
## touch_opacity and touch_left_handed. Every touch control is re-placed at once.
func apply_settings(settings: Dictionary) -> void:
	show_telemetry = bool(settings.get("show_telemetry", true))
	touch_scale = clampf(float(settings.get("touch_scale", 1.0)), TOUCH_SCALE_RANGE.x, TOUCH_SCALE_RANGE.y)
	touch_opacity = clampf(float(settings.get("touch_opacity", 0.8)), TOUCH_OPACITY_RANGE.x, TOUCH_OPACITY_RANGE.y)
	touch_left_handed = bool(settings.get("touch_left_handed", false))
	if is_instance_valid(_touch):
		_touch.modulate.a = touch_opacity
	_reflow()


## Gives the HUD the camera that objective markers and damage arcs are measured against.
func set_camera(camera: Camera3D) -> void:
	_camera = camera
	_refresh_markers()


## Objectives from level.get_objectives() (CONTRACT 5.8). main.gd sends them every frame while playing.
func set_objectives(objectives: Array) -> void:
	_objectives = objectives
	_refresh_markers()


## A hit from source at from_position (world space). The arc points where the hit came from,
## relative to the camera's facing. Pass Vector3.INF when the source has no position (falls).
func damage_from(amount: float, source: String, from_position: Vector3) -> void:
	var bearing: float = NAN
	if _camera_ready() and from_position.is_finite():
		var local: Vector3 = _camera.global_transform.affine_inverse() * from_position
		if Vector2(local.x, local.z).length_squared() > 0.0001:
			# 0 is straight ahead, positive is to the right.
			bearing = atan2(local.x, -local.z)
	_arcs.append({"bearing": bearing, "time": ARC_LIFETIME, "amount": amount, "source": source})
	while _arcs.size() > MAX_ARCS:
		_arcs.pop_front()
	_overlay.queue_redraw()


## Number of damage arcs still on screen (used by the tests).
func arc_count() -> int:
	return _arcs.size()


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
	_update_vignettes(clampf(float(data.get("danger", 0.0)), 0.0, 1.0), speed)
	_hint.text = str(data.get("hint", _hint_override))
	_practice_label.visible = bool(data.get("practice", false))
	if touch_enabled:
		_update_captions(sidearm, reel, bool(data.get("reloading", false)))


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
	_reticle_state.text = _state_text(data, charge, reel, tension)
	_reticle_state.add_theme_color_override("font_color", RED if bool(data.get("alert", false)) else PAPER)


## Danger tints the whole edge red (low health or a recent hit). Speed tints it cyan above
## SPEED_VIGNETTE_START, so a fast run reads at a glance even with the numbers hidden.
func _update_vignettes(danger: float, speed: float) -> void:
	_vignette.strength = danger
	_speed_vignette.strength = clampf((speed - SPEED_VIGNETTE_START) / (SPEED_VIGNETTE_FULL - SPEED_VIGNETTE_START), 0.0, 1.0)
	_vignette.queue_redraw()
	_speed_vignette.queue_redraw()


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


## Touch captions follow the state: FIRE with the sidearm, FREE while the line is reeling or locked,
## WAIT while reloading and STALL when the reel is stalled. Other captions stay fixed.
func _update_captions(sidearm: bool, reel: String, reloading: bool) -> void:
	var upper: String = reel.to_upper()
	var cast_pad: TouchPad = _touch_pads["cast"]
	var weapon_pad: TouchPad = _touch_pads["weapon"]
	var lock_pad: TouchPad = _touch_pads["lock"]
	var reload_pad: TouchPad = _touch_pads["reload"]
	var reel_pad: TouchPad = _touch_pads["reel"]
	cast_pad.caption = "FIRE" if sidearm else "CAST"
	weapon_pad.caption = "ROD" if sidearm else "GUN"
	lock_pad.caption = "FREE" if "LOCK" in upper or "REEL" in upper else "LOCK"
	reload_pad.caption = "WAIT" if reloading else "LOAD"
	reel_pad.caption = "STALL" if "STALL" in upper else "REEL"
	for pad: TouchPad in [cast_pad, weapon_pad, lock_pad, reload_pad, reel_pad]:
		pad.queue_redraw()


# --- Objective markers and damage arcs ---------------------------------------------------------

func _camera_ready() -> bool:
	return is_instance_valid(_camera) and _camera.is_inside_tree()


## Rectangle where markers and edge arrows may sit: the screen minus the margin and device insets.
func marker_bounds() -> Rect2:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var insets: Vector4 = _device_insets(view)
	var start := Vector2(maxf(MARKER_EDGE, insets.x + 12.0), maxf(MARKER_EDGE, insets.y + 12.0))
	var finish := view - Vector2(maxf(MARKER_EDGE, insets.z + 12.0), maxf(MARKER_EDGE, insets.w + 12.0))
	return Rect2(start, finish - start)


## Where a world point appears. On screen: its canvas point. Off screen (behind the camera or
## outside the view): the point where an arrow sits on the marker bounds edge, and the unit
## direction the arrow points. Behind the camera, the direction is the side the point lies on.
func project_marker(world: Vector3) -> Dictionary:
	var bounds: Rect2 = marker_bounds()
	if not _camera_ready():
		return {"on_screen": false, "point": bounds.get_center(), "direction": Vector2.DOWN}
	if not _camera.is_position_behind(world):
		var point: Vector2 = _camera.unproject_position(world)
		if bounds.has_point(point):
			return {"on_screen": true, "point": point, "direction": Vector2.ZERO}
		return _edge_result(point - bounds.get_center(), bounds)
	# Behind: the projection would mirror, so take the side from the camera-local offset instead.
	var local: Vector3 = _camera.global_transform.affine_inverse() * world
	var toward := Vector2(local.x, -local.y)
	if toward.length_squared() < 0.000001:
		toward = Vector2.DOWN
	return _edge_result(toward, bounds)


## Clamps a ray from the bounds centre to the bounds edge, and returns the arrow placement.
func _edge_result(toward: Vector2, bounds: Rect2) -> Dictionary:
	var direction: Vector2 = toward.normalized()
	var centre: Vector2 = bounds.get_center()
	var half: Vector2 = bounds.size * 0.5
	var along_x: float = half.x / absf(direction.x) if absf(direction.x) > 0.0001 else INF
	var along_y: float = half.y / absf(direction.y) if absf(direction.y) > 0.0001 else INF
	return {"on_screen": false, "point": centre + direction * minf(along_x, along_y), "direction": direction}


## Rebuilds the marker list from the objectives and the camera, then asks the overlay to redraw.
## Called every frame while active (the camera moves) and whenever objectives or camera change.
func _refresh_markers() -> void:
	if not is_instance_valid(_overlay):
		return
	var entries: Array = []
	if _active and _camera_ready() and not _objectives.is_empty():
		var next_index: int = _next_objective()
		for i in range(_objectives.size()):
			entries.append(_marker_entry(_objectives[i], i == next_index))
	_overlay.markers = entries
	_overlay.queue_redraw()


func _marker_entry(objective: Dictionary, is_next: bool) -> Dictionary:
	var world: Vector3 = objective.get("position", Vector3.ZERO)
	var entry: Dictionary = project_marker(world)
	entry["color"] = _kind_color(str(objective.get("kind", "case")))
	entry["active"] = bool(objective.get("active", true))
	entry["next"] = is_next
	entry["distance"] = _camera.global_position.distance_to(world)
	return entry


## Index of the nearest active objective: the one the player should head for next, or -1.
func _next_objective() -> int:
	var best := -1
	var best_distance := INF
	for i in range(_objectives.size()):
		var objective: Dictionary = _objectives[i]
		if not bool(objective.get("active", true)):
			continue
		var world: Vector3 = objective.get("position", Vector3.ZERO)
		var distance: float = _camera.global_position.distance_to(world)
		if distance < best_distance:
			best_distance = distance
			best = i
	return best


func _kind_color(kind: String) -> Color:
	match kind:
		"bonus":
			return AMBER
		"extract":
			return EXTRACT_COLOR
	return CYAN


## Ages the damage arcs and drops the ones that have run out (ARC_LIFETIME seconds each).
func _tick_effects(delta: float) -> void:
	var index: int = _arcs.size() - 1
	while index >= 0:
		var arc: Dictionary = _arcs[index]
		arc["time"] = float(arc["time"]) - delta
		if float(arc["time"]) <= 0.0:
			_arcs.remove_at(index)
		index -= 1
	_overlay.queue_redraw()


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
	# The stick takes the thumb side: left-hand for the usual layout, right-hand when mirrored.
	var in_move_zone: bool = (position.x > _last_size.x * 0.6) if touch_left_handed else (position.x < _last_size.x * 0.4)
	if role == "look" and in_move_zone and position.y > _last_size.y * 0.4 and not "move" in _touch_roles.values():
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
