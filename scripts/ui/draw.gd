extends RefCounted
## Static vector drawing helpers shared by menu widgets and the HUD (no textures).
## Usage: const Draw = preload("res://scripts/ui/draw.gd"); Draw.draw_medal(self, ...)

const UiTheme = preload("res://scripts/ui/theme.gd")


## Horizontal or vertical multi-stop gradient. stops: Array of [offset 0..1, Color].
static func gradient_rect(ci: CanvasItem, rect: Rect2, stops: Array, vertical: bool = false) -> void:
	for i in range(stops.size() - 1):
		var a: Array = stops[i]
		var b: Array = stops[i + 1]
		var t0: float = float(a[0])
		var t1: float = float(b[0])
		var c0: Color = a[1]
		var c1: Color = b[1]
		if c0.a <= 0.002 and c1.a <= 0.002:
			continue
		var points: PackedVector2Array
		var colors: PackedColorArray
		if vertical:
			var y0: float = rect.position.y + rect.size.y * t0
			var y1: float = rect.position.y + rect.size.y * t1
			points = PackedVector2Array([Vector2(rect.position.x, y0), Vector2(rect.end.x, y0), Vector2(rect.end.x, y1), Vector2(rect.position.x, y1)])
			colors = PackedColorArray([c0, c0, c1, c1])
		else:
			var x0: float = rect.position.x + rect.size.x * t0
			var x1: float = rect.position.x + rect.size.x * t1
			points = PackedVector2Array([Vector2(x0, rect.position.y), Vector2(x1, rect.position.y), Vector2(x1, rect.end.y), Vector2(x0, rect.end.y)])
			colors = PackedColorArray([c0, c1, c1, c0])
		ci.draw_polygon(points, colors)


## Edge vignette band: colour at the screen edge fading to transparent inwards.
static func edge_glow(ci: CanvasItem, rect: Rect2, color: Color, depth: float) -> void:
	var clear := Color(color, 0.0)
	var o: Vector2 = rect.position
	var e: Vector2 = rect.end
	var d: float = minf(depth, minf(rect.size.x, rect.size.y) * 0.5)
	var bands: Array = [
		[Vector2(o.x, o.y), Vector2(e.x, o.y), Vector2(e.x - d, o.y + d), Vector2(o.x + d, o.y + d)],
		[Vector2(e.x, o.y), Vector2(e.x, e.y), Vector2(e.x - d, e.y - d), Vector2(e.x - d, o.y + d)],
		[Vector2(e.x, e.y), Vector2(o.x, e.y), Vector2(o.x + d, e.y - d), Vector2(e.x - d, e.y - d)],
		[Vector2(o.x, e.y), Vector2(o.x, o.y), Vector2(o.x + d, o.y + d), Vector2(o.x + d, e.y - d)],
	]
	for band in bands:
		ci.draw_polygon(PackedVector2Array(band), PackedColorArray([color, color, clear, clear]))


static func diamond_points(center: Vector2, radius: float) -> PackedVector2Array:
	return PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0)])


static func draw_diamond(ci: CanvasItem, center: Vector2, radius: float, color: Color, filled: bool = true, width: float = 2.0) -> void:
	var points: PackedVector2Array = diamond_points(center, radius)
	if filled:
		ci.draw_colored_polygon(points, color)
	else:
		points.append(points[0])
		ci.draw_polyline(points, color, width, true)


## Five-point star (used on gold medals and unlocked badges).
static func star_points(center: Vector2, outer: float, inner: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 10:
		var angle: float = -PI * 0.5 + i * PI / 5.0
		var r: float = outer if i % 2 == 0 else inner
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	return points


## Medal disc: 0 none (dashed ring), 1 bronze, 2 silver, 3 gold. `alpha` fades it.
static func draw_medal(ci: CanvasItem, center: Vector2, radius: float, medal: int, alpha: float = 1.0) -> void:
	var tier: int = clampi(medal, 0, 3)
	if tier == 0:
		var faint := Color(UiTheme.MUTED, 0.35 * alpha)
		var steps: int = 16
		for i in steps:
			if i % 2 == 0:
				var a0: float = TAU * float(i) / steps
				ci.draw_arc(center, radius * 0.86, a0, a0 + TAU / steps, 4, faint, maxf(1.5, radius * 0.08), true)
		return
	var base: Color = UiTheme.MEDAL_COLORS[tier]
	var dark: Color = base.darkened(0.45)
	var light: Color = base.lightened(0.35)
	# Ribbon tails behind the disc.
	var ribbon := Color(dark, alpha)
	var rw: float = radius * 0.42
	ci.draw_colored_polygon(PackedVector2Array([center + Vector2(-rw * 1.4, -radius * 0.2), center + Vector2(-rw * 0.2, -radius * 0.2), center + Vector2(-rw * 0.55, radius * 1.25), center + Vector2(-rw * 1.05, radius * 1.05), center + Vector2(-rw * 1.6, radius * 1.3)]), ribbon)
	ci.draw_colored_polygon(PackedVector2Array([center + Vector2(rw * 0.2, -radius * 0.2), center + Vector2(rw * 1.4, -radius * 0.2), center + Vector2(rw * 1.6, radius * 1.3), center + Vector2(rw * 1.05, radius * 1.05), center + Vector2(rw * 0.55, radius * 1.25)]), ribbon)
	ci.draw_circle(center, radius, Color(dark, alpha), true, -1.0, true)
	ci.draw_circle(center, radius * 0.9, Color(base, alpha), true, -1.0, true)
	# Bevel highlight on the upper-left rim.
	ci.draw_arc(center, radius * 0.78, PI * 0.95, PI * 1.6, 18, Color(light, 0.75 * alpha), maxf(1.2, radius * 0.07), true)
	ci.draw_arc(center, radius * 0.7, 0.0, TAU, 40, Color(dark, 0.55 * alpha), maxf(1.0, radius * 0.045), true)
	var mark := Color(dark.darkened(0.2), alpha)
	if tier == 3:
		ci.draw_colored_polygon(star_points(center, radius * 0.45, radius * 0.2), mark)
	else:
		# Silver: two bars, bronze: one bar (tally marks read at a glance).
		var bars: int = tier
		var bar_w: float = radius * 0.16
		var gap: float = radius * 0.14
		var total: float = bars * bar_w + (bars - 1) * gap
		for b in bars:
			var x: float = center.x - total * 0.5 + b * (bar_w + gap)
			ci.draw_rect(Rect2(x, center.y - radius * 0.36, bar_w, radius * 0.72), mark)


static func draw_lock(ci: CanvasItem, center: Vector2, scale_px: float, color: Color) -> void:
	var body := Rect2(center + Vector2(-0.5, -0.1) * scale_px, Vector2(1.0, 0.75) * scale_px)
	ci.draw_arc(center + Vector2(0, -0.1) * scale_px, scale_px * 0.3, PI, TAU, 16, color, maxf(1.5, scale_px * 0.12), true)
	ci.draw_line(center + Vector2(-0.3, -0.1) * scale_px, center + Vector2(-0.3, 0.0) * scale_px, color, maxf(1.5, scale_px * 0.12), true)
	ci.draw_line(center + Vector2(0.3, -0.1) * scale_px, center + Vector2(0.3, 0.0) * scale_px, color, maxf(1.5, scale_px * 0.12), true)
	ci.draw_rect(body, color)
	ci.draw_circle(center + Vector2(0, 0.22) * scale_px, scale_px * 0.09, UiTheme.INK, true, -1.0, true)


## Hexagonal achievement badge. Unlocked = amber with a star, locked = dim with a lock.
static func draw_badge(ci: CanvasItem, center: Vector2, radius: float, unlocked: bool) -> void:
	var hex := PackedVector2Array()
	for i in 6:
		var angle: float = PI / 6.0 + i * TAU / 6.0
		hex.append(center + Vector2(cos(angle), sin(angle)) * radius)
	if unlocked:
		ci.draw_colored_polygon(hex, UiTheme.AMBER)
		var inner := PackedVector2Array()
		for p in hex:
			inner.append(center + (p - center) * 0.8)
		inner.append(inner[0])
		ci.draw_polyline(inner, Color(UiTheme.INK, 0.35), maxf(1.0, radius * 0.06), true)
		ci.draw_colored_polygon(star_points(center, radius * 0.48, radius * 0.21), UiTheme.INK)
	else:
		ci.draw_colored_polygon(hex, Color(0.06, 0.11, 0.12, 0.9))
		var outline: PackedVector2Array = hex.duplicate()
		outline.append(hex[0])
		ci.draw_polyline(outline, Color(UiTheme.MUTED, 0.35), maxf(1.0, radius * 0.06), true)
		draw_lock(ci, center + Vector2(0, radius * 0.05), radius * 0.62, Color(UiTheme.MUTED, 0.6))


## Simple pictograms for the six workshop tracks, drawn inside `rect`.
static func draw_upgrade_icon(ci: CanvasItem, kind: String, rect: Rect2, color: Color) -> void:
	var c: Vector2 = rect.get_center()
	var r: float = minf(rect.size.x, rect.size.y) * 0.5
	var w: float = maxf(1.5, r * 0.12)
	match kind:
		"spool":
			ci.draw_arc(c, r * 0.82, 0.0, TAU, 36, color, w, true)
			ci.draw_arc(c, r * 0.5, 0.0, TAU, 28, color, w * 0.8, true)
			ci.draw_circle(c, r * 0.16, color, true, -1.0, true)
			ci.draw_line(c + Vector2(r * 0.5, 0), c + Vector2(r * 1.0, r * 0.9), color, w * 0.6, true)
		"reel":
			for i in 8:
				var angle: float = i * TAU / 8.0
				ci.draw_line(c + Vector2(cos(angle), sin(angle)) * r * 0.55, c + Vector2(cos(angle), sin(angle)) * r * 0.88, color, w * 1.3, true)
			ci.draw_arc(c, r * 0.6, 0.0, TAU, 30, color, w, true)
			ci.draw_circle(c, r * 0.22, color, true, -1.0, true)
		"weight":
			ci.draw_line(c + Vector2(0, -r * 0.95), c + Vector2(0, -r * 0.45), color, w * 0.6, true)
			ci.draw_arc(c + Vector2(0, -r * 0.5), r * 0.14, 0.0, TAU, 12, color, w * 0.6, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.32, -r * 0.3), c + Vector2(r * 0.32, -r * 0.3), c + Vector2(r * 0.72, r * 0.7), c + Vector2(r * 0.6, r * 0.85), c + Vector2(-r * 0.6, r * 0.85), c + Vector2(-r * 0.72, r * 0.7)]), color)
		"plating":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.9), c + Vector2(r * 0.75, -r * 0.55), c + Vector2(r * 0.62, r * 0.35), c + Vector2(0, r * 0.92), c + Vector2(-r * 0.62, r * 0.35), c + Vector2(-r * 0.75, -r * 0.55)]), color)
			ci.draw_line(c + Vector2(0, -r * 0.5), c + Vector2(0, r * 0.5), UiTheme.INK, w, true)
			ci.draw_line(c + Vector2(-r * 0.35, -r * 0.05), c + Vector2(r * 0.35, -r * 0.05), UiTheme.INK, w, true)
		"quickdraw":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.15, -r * 0.95), c + Vector2(-r * 0.55, r * 0.12), c + Vector2(-r * 0.05, r * 0.12), c + Vector2(-r * 0.2, r * 0.95), c + Vector2(r * 0.55, -r * 0.15), c + Vector2(r * 0.05, -r * 0.15)]), color)
		"sidearm":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.9, -r * 0.45), c + Vector2(r * 0.9, -r * 0.45), c + Vector2(r * 0.9, -r * 0.1), c + Vector2(-r * 0.1, -r * 0.1), c + Vector2(-r * 0.2, r * 0.85), c + Vector2(-r * 0.7, r * 0.85), c + Vector2(-r * 0.55, -r * 0.1), c + Vector2(-r * 0.9, -r * 0.1)]), color)
			ci.draw_arc(c + Vector2(-r * 0.05, r * 0.05), r * 0.2, 0.0, PI, 10, color, w * 0.7, true)
		_:
			ci.draw_arc(c, r * 0.8, 0.0, TAU, 32, color, w, true)
