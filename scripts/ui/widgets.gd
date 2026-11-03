extends RefCounted
## Code-drawn UI pieces shared by menus and HUD (no textures): gradients, the logotype,
## medals, tier pips, achievement badges, upgrade icons, hazard stripes, time tracks.
## Usage: const Widgets = preload("res://scripts/ui/widgets.gd"); Widgets.MedalIcon.new()

const UiTheme = preload("res://scripts/ui/theme.gd")
const Draw = preload("res://scripts/ui/draw.gd")


# --- Controls ------------------------------------------------------------------------------

## Full-screen tint that keeps the 3D level visible behind menus.
## mode: "menu" (left-weighted), "dim" (even dim + vignette), "solid" (loading), "none".
class Backdrop extends Control:
	var mode: String = "menu":
		set(value):
			mode = value
			queue_redraw()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		var ink: Color = UiTheme.INK
		match mode:
			"menu":
				Draw.gradient_rect(self, rect, [[0.0, Color(ink, 0.94)], [0.3, Color(ink, 0.84)], [0.55, Color(ink, 0.42)], [0.8, Color(ink, 0.12)], [1.0, Color(ink, 0.05)]])
				Draw.gradient_rect(self, Rect2(0, size.y * 0.62, size.x, size.y * 0.38), [[0.0, Color(ink, 0.0)], [1.0, Color(ink, 0.6)]], true)
				Draw.gradient_rect(self, Rect2(0, 0, size.x, size.y * 0.2), [[0.0, Color(ink, 0.45)], [1.0, Color(ink, 0.0)]], true)
			"dim":
				draw_rect(rect, Color(ink, 0.7))
				Draw.gradient_rect(self, rect, [[0.0, Color(ink, 0.28)], [0.5, Color(ink, 0.0)], [1.0, Color(ink, 0.28)]])
				Draw.edge_glow(self, rect, Color(0, 0.01, 0.015, 0.45), minf(size.x, size.y) * 0.22)
			"pause":
				draw_rect(rect, Color(ink, 0.5))
				Draw.gradient_rect(self, rect, [[0.0, Color(ink, 0.55)], [0.45, Color(ink, 0.2)], [1.0, Color(ink, 0.0)]])
				Draw.edge_glow(self, rect, Color(0, 0.01, 0.015, 0.5), minf(size.x, size.y) * 0.25)
			"solid":
				draw_rect(rect, Color(0.027, 0.06, 0.07, 0.985))
				Draw.gradient_rect(self, rect, [[0.0, Color(0.06, 0.12, 0.13, 0.6)], [0.6, Color(0, 0, 0, 0)], [1.0, Color(0, 0, 0, 0.3)]], true)
				Draw.edge_glow(self, rect, Color(0, 0, 0, 0.45), minf(size.x, size.y) * 0.3)
			_:
				pass


## DEADWEIGHT logotype: heavy, wide, tracked; an amber line drops in and holds a sinker
## under the W, with a measuring hairline beneath (line length telemetry motif).
class Logotype extends Control:
	var font_size: int = 104:
		set(value):
			font_size = value
			update_minimum_size()
			queue_redraw()
	var reveal: float = 1.0:
		set(value):
			reveal = value
			queue_redraw()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _text_width() -> float:
		var logo_font: Font = UiTheme.font("logo")
		return logo_font.get_string_size("DEADWEIGHT", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + font_size * 0.14

	func _get_minimum_size() -> Vector2:
		var logo_font: Font = UiTheme.font("logo")
		return Vector2(_text_width(), logo_font.get_ascent(font_size) * 0.86 + font_size * 0.42)

	func _draw() -> void:
		var logo_font: Font = UiTheme.font("logo")
		var ascent: float = logo_font.get_ascent(font_size)
		var cap: float = ascent * 0.72
		var baseline: float = cap + font_size * 0.06
		var x0: float = font_size * 0.03
		var dead_w: float = logo_font.get_string_size("DEAD", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var text_w: float = _text_width()
		# Soft drop shadow, then the letters.
		draw_string(logo_font, Vector2(x0 + 2, baseline + 5), "DEADWEIGHT", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.45 * reveal))
		draw_string(logo_font, Vector2(x0, baseline), "DEAD", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(UiTheme.PAPER, reveal))
		draw_string(logo_font, Vector2(x0 + dead_w, baseline), "WEIGHT", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(UiTheme.AMBER, reveal))
		# Measuring hairline with ticks under the word.
		var rule_y: float = baseline + font_size * 0.17
		var rule_end: float = x0 + text_w * reveal
		draw_line(Vector2(x0, rule_y), Vector2(rule_end, rule_y), Color(UiTheme.CYAN, 0.5), 1.5, true)
		var ticks: int = 20
		for i in ticks + 1:
			var tx: float = x0 + (text_w - font_size * 0.14) * float(i) / ticks
			if tx > rule_end:
				break
			var tall: bool = i % 5 == 0
			draw_line(Vector2(tx, rule_y), Vector2(tx, rule_y + (font_size * 0.09 if tall else font_size * 0.045)), Color(UiTheme.CYAN, 0.55 if tall else 0.3), 1.5 if tall else 1.0, true)
		# Small mono caption at the right end of the rule: the stock spool length.
		var cap_font: Font = UiTheme.font("label")
		var caption_size: int = maxi(10, int(font_size * 0.12))
		draw_string(cap_font, Vector2(x0, rule_y + font_size * 0.24), "0 M", HORIZONTAL_ALIGNMENT_LEFT, -1, caption_size, Color(UiTheme.CYAN, 0.6 * reveal))
		draw_string(cap_font, Vector2(x0 + text_w - font_size * 0.14 - caption_size * 3.2, rule_y + font_size * 0.24), "40 M", HORIZONTAL_ALIGNMENT_LEFT, -1, caption_size, Color(UiTheme.CYAN, 0.6 * reveal))


## Medal icon (see draw_medal). `pop` animates the reveal scale.
class MedalIcon extends Control:
	var medal: int = 0:
		set(value):
			medal = value
			queue_redraw()
	var pop: float = 1.0:
		set(value):
			pop = value
			queue_redraw()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var radius: float = minf(size.x, size.y) * 0.36 * pop
		if radius <= 0.5:
			return
		Draw.draw_medal(self, Vector2(size.x * 0.5, size.y * 0.42), radius, medal, clampf(pop, 0.0, 1.0))


## Row of tier pips: `filled` of `count`, optional flash on the newest pip.
class Pips extends Control:
	var count: int = 4:
		set(value):
			count = value
			queue_redraw()
	var filled: int = 0:
		set(value):
			filled = value
			queue_redraw()
	var color: Color = UiTheme.AMBER
	var flash: float = 0.0:
		set(value):
			flash = value
			queue_redraw()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if count <= 0:
			return
		var gap: float = 5.0
		var w: float = (size.x - gap * (count - 1)) / count
		var h: float = minf(size.y, 10.0)
		var y: float = (size.y - h) * 0.5
		for i in count:
			var rect := Rect2(i * (w + gap), y, w, h)
			if i < filled:
				var c: Color = color
				if i == filled - 1 and flash > 0.0:
					c = c.lerp(Color.WHITE, flash)
				draw_rect(rect, c)
			else:
				draw_rect(rect, Color(0.02, 0.05, 0.06, 0.9))
				draw_rect(rect, Color(UiTheme.MUTED, 0.35), false, 1.0)


class Badge extends Control:
	var unlocked: bool = false:
		set(value):
			unlocked = value
			queue_redraw()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		Draw.draw_badge(self, size * 0.5, minf(size.x, size.y) * 0.46, unlocked)


class UpgradeIcon extends Control:
	var kind: String = "spool":
		set(value):
			kind = value
			queue_redraw()
	var color: Color = UiTheme.AMBER:
		set(value):
			color = value
			queue_redraw()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		Draw.draw_upgrade_icon(self, kind, Rect2(Vector2.ZERO, size).grow(-size.x * 0.12), color)


## Diagonal amber/ink hazard stripes; optional scroll animation (loading bar).
class HazardStripe extends Control:
	var stripe_color: Color = UiTheme.AMBER
	var animated: bool = false
	var _offset: float = 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true

	func _process(delta: float) -> void:
		if animated and is_visible_in_tree():
			_offset = fmod(_offset + delta * 40.0, size.y * 2.0 + 0.001)
			queue_redraw()

	func _draw() -> void:
		var h: float = size.y
		var step: float = maxf(4.0, h * 2.0)
		var x: float = -step * 2.0 + _offset
		while x < size.x + step:
			draw_colored_polygon(PackedVector2Array([Vector2(x, h), Vector2(x + h, 0), Vector2(x + h + step * 0.5, 0), Vector2(x + step * 0.5, h)]), stripe_color)
			x += step


## Result screen: the run time against silver and gold pars on one horizontal track.
class TimeTrack extends Control:
	var time: float = 0.0
	var par_silver: float = 0.0
	var par_gold: float = 0.0
	var won: bool = true
	var reveal: float = 1.0:
		set(value):
			reveal = value
			queue_redraw()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(240, 46)

	func _draw() -> void:
		if par_silver <= 0.0:
			return
		var label_font: Font = UiTheme.font("label")
		var fs: int = 11
		var top: float = 6.0
		var track_y: float = top + 12.0
		var span: float = maxf(par_silver * 1.35, time * 1.08)
		var to_x := func(t: float) -> float: return clampf(t / span, 0.0, 1.0) * size.x
		draw_rect(Rect2(0, track_y - 2, size.x, 4), Color(0.02, 0.05, 0.06, 0.9))
		# Zones: gold (0..gold), silver (gold..silver), bronze beyond.
		var gx: float = to_x.call(par_gold)
		var sx: float = to_x.call(par_silver)
		draw_rect(Rect2(0, track_y - 2, gx, 4), Color(UiTheme.MEDAL_COLORS[3], 0.75))
		draw_rect(Rect2(gx, track_y - 2, sx - gx, 4), Color(UiTheme.MEDAL_COLORS[2], 0.6))
		draw_rect(Rect2(sx, track_y - 2, size.x - sx, 4), Color(UiTheme.MEDAL_COLORS[1], 0.45))
		for mark in [[gx, "GOLD " + UiTheme.format_time(par_gold, 0), UiTheme.MEDAL_COLORS[3]], [sx, "SILVER " + UiTheme.format_time(par_silver, 0), UiTheme.MEDAL_COLORS[2]]]:
			var mx: float = mark[0]
			draw_line(Vector2(mx, track_y - 8), Vector2(mx, track_y + 8), mark[2], 2.0, true)
			var text: String = mark[1]
			var tw: float = label_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(label_font, Vector2(clampf(mx - tw * 0.5, 0.0, size.x - tw), track_y + 24), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(mark[2], 0.9))
		if won and time > 0.0:
			var px: float = to_x.call(time) * reveal
			var marker := Color(UiTheme.PAPER)
			draw_colored_polygon(PackedVector2Array([Vector2(px - 7, top - 4), Vector2(px + 7, top - 4), Vector2(px, top + 6)]), marker)
			draw_line(Vector2(px, top + 4), Vector2(px, track_y + 6), marker, 2.0, true)


## Decorative corner brackets drawn over a panel (industrial framing).
class Brackets extends Control:
	var color: Color = Color(UiTheme.CYAN, 0.45)
	var arm: float = 14.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w: float = 2.0
		var s: Vector2 = size
		for corner in [[Vector2(0, 0), Vector2(1, 1)], [Vector2(s.x, 0), Vector2(-1, 1)], [Vector2(0, s.y), Vector2(1, -1)], [Vector2(s.x, s.y), Vector2(-1, -1)]]:
			var p: Vector2 = corner[0]
			var d: Vector2 = corner[1]
			draw_line(p, p + Vector2(arm * d.x, 0), color, w)
			draw_line(p, p + Vector2(0, arm * d.y), color, w)
