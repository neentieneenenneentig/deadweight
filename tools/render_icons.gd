extends SceneTree
## DEADWEIGHT brand kit. The sinker mark is built as SVG in code and rendered to every icon
## the launchers and stores need; the script then re-reads and verifies what it wrote.
##
##   .tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/render_icons.gd
##   ... -- --check     verify the existing files only (no rendering)
##   ... -- --preview   also write a contact sheet to .tools/captures/store/icons_sheet.png
##
## The mark: a heavy amber sinker flying up and right on a taut cyan line, speed streaks
## trailing behind it. The weight drags you into the sky. Palette: CONTRACT section 8.
## Other scripts reuse the SVG builders: const Brand = preload("res://tools/render_icons.gd").

const ICONS_DIR := "res://icons"
const ART_DIR := "res://store/art"
const STEAM_DIR := "res://store/art/steam"
const PLAY_DIR := "res://store/art/google-play"
const BRAND_DIR := "res://store/art/brand"
const ACHIEVEMENT_DIR := "res://store/art/steam/achievements"
const CAPTURE_DIR := "res://.tools/captures/store"

const INK := "#0b171a"
const AMBER := "#f5b45b"
const AMBER_BRIGHT := "#ffd391"
const AMBER_DEEP := "#cf8d3e"
const AMBER_SHADOW := "#b0712f"
const CYAN := "#5ad6c8"
const CYAN_BRIGHT := "#9cf2e6"
const CYAN_DEEP := "#2b938b"
const PAPER := "#e5ebe5"
const STEEL := "#c9d6d2"
const STEEL_DARK := "#263d42"
const STEEL_EDGE := "#6a8a8b"
const RED := "#ef654e"
const GOLD := "#f2c14e"

## Pear-shaped sinker in local units: heavy end towards -y, neck at +y. 208 units wide.
const BODY_PATH := "M -21 92 C -52 66 -104 22 -104 -36 A 104 104 0 0 1 104 -36 C 104 22 52 66 21 92 Z"
## Local point placed at the centre of compact layouts (midway between nose and eye).
const MARK_CENTER := Vector2(0.0, 7.0)
## Radius (local units) that holds the whole mark except the trailing line.
const MARK_RADIUS := 150.0
## Adaptive icon: 108 dp canvas, 66 dp safe zone (developer.android.com adaptive icons).
const ADAPTIVE_SIZE := 432
const ADAPTIVE_SAFE_RADIUS := 132.0

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not "--check" in args:
		render_all()
		if "--preview" in args:
			save_contact_sheet()
	verify_all()
	print("render_icons: %d checks, %d failed" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


# ---------------------------------------------------------------- SVG building blocks


static func _n(value: float) -> String:
	return String.num(value, 2)


static func detail_for(size: int) -> int:
	if size <= 32:
		return 0
	if size <= 96:
		return 1
	return 2


## Shared <defs>: facet gradients for the body and belt, the body clip, the background glow.
## glow_center/glow_radius place the background light behind the weight.
static func defs(glow_center: Vector2 = Vector2(300, 200), glow_radius: float = 440.0, line_fade: float = 0.0) -> String:
	var parts := PackedStringArray()
	parts.append('<defs>')
	parts.append('<linearGradient id="dw_body" gradientUnits="userSpaceOnUse" x1="-104" y1="0" x2="104" y2="0">')
	parts.append('<stop offset="0" stop-color="%s"/><stop offset="0.25" stop-color="%s"/>' % [AMBER_BRIGHT, AMBER_BRIGHT])
	parts.append('<stop offset="0.25" stop-color="%s"/><stop offset="0.57" stop-color="%s"/>' % [AMBER, AMBER])
	parts.append('<stop offset="0.57" stop-color="%s"/><stop offset="1" stop-color="%s"/>' % [AMBER_DEEP, AMBER_SHADOW])
	parts.append('</linearGradient>')
	parts.append('<linearGradient id="dw_belt" gradientUnits="userSpaceOnUse" x1="-104" y1="0" x2="104" y2="0">')
	parts.append('<stop offset="0" stop-color="%s"/><stop offset="0.25" stop-color="%s"/>' % [CYAN_BRIGHT, CYAN_BRIGHT])
	parts.append('<stop offset="0.25" stop-color="%s"/><stop offset="0.57" stop-color="%s"/>' % [CYAN, CYAN])
	parts.append('<stop offset="0.57" stop-color="%s"/><stop offset="1" stop-color="%s"/>' % [CYAN_DEEP, CYAN_DEEP])
	parts.append('</linearGradient>')
	parts.append('<clipPath id="dw_clip"><path d="%s"/></clipPath>' % BODY_PATH)
	parts.append('<clipPath id="dw_right"><rect x="0" y="-200" width="200" height="400"/></clipPath>')
	parts.append('<radialGradient id="dw_bg" gradientUnits="userSpaceOnUse" cx="%s" cy="%s" r="%s">' % [_n(glow_center.x), _n(glow_center.y), _n(glow_radius)])
	parts.append('<stop offset="0" stop-color="#28525a"/><stop offset="0.45" stop-color="#173540"/><stop offset="1" stop-color="%s"/>' % INK)
	parts.append('</radialGradient>')
	if line_fade > 0.0:
		parts.append('<linearGradient id="dw_line" gradientUnits="userSpaceOnUse" x1="0" y1="128" x2="0" y2="%s">' % _n(128.0 + line_fade))
		parts.append('<stop offset="0" stop-color="%s" stop-opacity="1"/><stop offset="0.55" stop-color="%s" stop-opacity="0.85"/><stop offset="1" stop-color="%s" stop-opacity="0"/>' % [CYAN, CYAN, CYAN])
		parts.append('</linearGradient>')
	parts.append('</defs>')
	return "".join(parts)


## The sinker, its line and speed streaks in local units (heavy end at -y).
## detail 0: tiny silhouette (16-32 px), 1: small (48-96 px), 2: full.
## mono: single-colour white layer with alpha shading (Android themed icon).
## line_end: local y where the line stops; line_fade uses the dw_line gradient.
## with_streaks: false drops the speed streaks (Android adaptive layers, where a launcher mask
## would clip them).
static func mark(detail: int, mono: bool = false, line_end: float = 900.0, line_fade: bool = false, with_streaks: bool = true) -> String:
	var parts := PackedStringArray()
	var streak_color: String = "#ffffff" if mono else PAPER
	var streaks: Array = []
	if not with_streaks:
		streaks = []
	elif detail == 1:
		streaks = [[-146.0, 0.0, 112.0, 22.0, 0.6], [146.0, 36.0, 124.0, 22.0, 0.5]]
	elif detail >= 2:
		streaks = [[-142.0, -6.0, 118.0, 15.0, 0.55], [142.0, 30.0, 132.0, 15.0, 0.45], [-180.0, 70.0, 140.0, 11.0, 0.28]]
	for streak: Array in streaks:
		parts.append('<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="%s" stroke-opacity="%s" stroke-width="%s" stroke-linecap="round"/>' % [
			_n(streak[0]), _n(streak[1]), _n(streak[0]), _n(streak[2]), streak_color, _n(streak[4]), _n(streak[3])])
	var line_width: float = [40.0, 22.0, 18.0][detail]
	var line_paint: String = "url(#dw_line)" if line_fade and not mono else ("#ffffff" if mono else CYAN)
	parts.append('<line x1="0" y1="118" x2="0" y2="%s" stroke="%s" stroke-width="%s"/>' % [_n(line_end), line_paint, _n(line_width)])
	if detail >= 1:
		parts.append('<circle cx="0" cy="128" r="19" fill="none" stroke="%s" stroke-width="%s"/>' % ["#ffffff" if mono else STEEL, "13" if detail == 1 else "11"])
	if mono:
		parts.append('<path d="%s" fill="#ffffff"/>' % BODY_PATH)
		parts.append('<path d="%s" fill="#000000" fill-opacity="0.0"/>' % BODY_PATH)
	else:
		parts.append('<path d="%s" fill="url(#dw_body)"/>' % BODY_PATH)
		if detail >= 1:
			parts.append('<rect x="-110" y="-52" width="220" height="%s" fill="url(#dw_belt)" clip-path="url(#dw_clip)"/>' % ("34" if detail == 1 else "30"))
		if detail >= 2:
			parts.append('<ellipse cx="-44" cy="-80" rx="12" ry="28" transform="rotate(34 -44 -80)" fill="#fff6e3" fill-opacity="0.92"/>')
	var collar_color: String = "#ffffff" if mono else STEEL_DARK
	parts.append('<rect x="-28" y="84" width="56" height="26" rx="6" fill="%s"/>' % collar_color)
	if not mono:
		parts.append('<rect x="-28" y="84" width="56" height="7" rx="3" fill="%s"/>' % STEEL_EDGE)
	return "".join(parts)


## Transform that puts the mark into a square icon of `canvas` units (512 design space).
static func mark_transform(detail: int) -> String:
	match detail:
		0:
			return "translate(270 246) rotate(45) scale(1.28)"
		1:
			return "translate(272 240) rotate(45) scale(1.12)"
	return "translate(276 236) rotate(45)"


## Full icon as SVG. style: rounded (desktop/project icon, transparent corners),
## square (full bleed for Google Play, Steam app icon), foreground / background /
## monochrome (Android adaptive layers, 432 canvas), mark (transparent, no background).
static func icon_svg(size: int, style: String = "rounded") -> String:
	var detail: int = detail_for(size)
	var head := '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">'
	match style:
		"foreground", "monochrome":
			var transform: String = "translate(216 216) rotate(45) scale(%s) translate(%s %s)" % [_n(ADAPTIVE_SAFE_RADIUS / MARK_RADIUS), _n(-MARK_CENTER.x), _n(-MARK_CENTER.y)]
			var body: String = mark(maxi(detail, 1), style == "monochrome", 900.0, false, false)
			return (head % [size, size, ADAPTIVE_SIZE, ADAPTIVE_SIZE]) + defs() + '<g transform="%s">%s</g></svg>' % [transform, body]
		"background":
			return (head % [size, size, ADAPTIVE_SIZE, ADAPTIVE_SIZE]) + defs(Vector2(244, 190), 380.0) + '<rect width="432" height="432" fill="url(#dw_bg)"/>' + _background_detail(432.0) + '</svg>'
		"mark":
			var fade_transform: String = "translate(256 256) rotate(45) scale(%s) translate(%s %s)" % [_n(240.0 / MARK_RADIUS * 0.82), _n(-MARK_CENTER.x), _n(-MARK_CENTER.y)]
			return (head % [size, size, 512, 512]) + defs(Vector2(300, 200), 440.0, 260.0) + '<g transform="%s">%s</g></svg>' % [fade_transform, mark(2, false, 400.0, true)]
	var background: String
	if style == "square":
		background = '<rect width="512" height="512" fill="url(#dw_bg)"/>' + _background_detail(512.0)
	else:
		background = '<rect x="12" y="12" width="488" height="488" rx="108" fill="url(#dw_bg)"/>'
		background += '<rect x="14" y="14" width="484" height="484" rx="106" fill="none" stroke="#3a6b70" stroke-opacity="0.55" stroke-width="4"/>'
	return (head % [size, size, 512, 512]) + defs() + background + '<g transform="%s">%s</g></svg>' % [mark_transform(detail), mark(detail)]


## Faint industrial texture for full-bleed backgrounds: a hazard-stripe band in the corner.
static func _background_detail(canvas: float) -> String:
	var k: float = canvas / 512.0
	var parts := PackedStringArray()
	parts.append('<g opacity="0.10" transform="scale(%s)">' % _n(k))
	for i in range(7):
		var x: float = 330.0 + float(i) * 34.0
		parts.append('<path d="M %s 512 L %s 512 L %s 600 L %s 600 Z" fill="%s"/>' % [_n(x), _n(x + 17.0), _n(x + 105.0), _n(x + 88.0), AMBER])
	parts.append('</g>')
	return "".join(parts)


static func render_svg(svg: String, scale: float = 1.0) -> Image:
	var image := Image.new()
	var error: Error = image.load_svg_from_string(svg, scale)
	if error != OK:
		push_error("SVG render failed (%s)" % error_string(error))
		return null
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	return image


static func render_icon(size: int, style: String = "rounded") -> Image:
	return render_svg(icon_svg(size, style))


# ---------------------------------------------------------------- ICO writer


## Multi-size .ico: 32-bit BMP (DIB + AND mask) entries below 256 px, PNG at 256 px.
static func ico_bytes(images: Array[Image]) -> PackedByteArray:
	var payloads: Array[PackedByteArray] = []
	for image: Image in images:
		payloads.append(image.save_png_to_buffer() if image.get_width() >= 256 else _dib_bytes(image))
	var header := StreamPeerBuffer.new()
	header.put_u16(0)
	header.put_u16(1)
	header.put_u16(images.size())
	var offset: int = 6 + 16 * images.size()
	for index in images.size():
		var width: int = images[index].get_width()
		var height: int = images[index].get_height()
		header.put_u8(0 if width >= 256 else width)
		header.put_u8(0 if height >= 256 else height)
		header.put_u8(0)
		header.put_u8(0)
		header.put_u16(1)
		header.put_u16(32)
		header.put_u32(payloads[index].size())
		header.put_u32(offset)
		offset += payloads[index].size()
	var bytes: PackedByteArray = header.data_array
	for payload: PackedByteArray in payloads:
		bytes.append_array(payload)
	return bytes


static func _dib_bytes(source: Image) -> PackedByteArray:
	var image: Image = source.duplicate()
	image.convert(Image.FORMAT_RGBA8)
	var width: int = image.get_width()
	var height: int = image.get_height()
	var data: PackedByteArray = image.get_data()
	var mask_stride: int = int((width + 31) / 32) * 4
	var buffer := StreamPeerBuffer.new()
	buffer.put_u32(40)
	buffer.put_32(width)
	buffer.put_32(height * 2)
	buffer.put_u16(1)
	buffer.put_u16(32)
	buffer.put_u32(0)
	buffer.put_u32(width * height * 4 + mask_stride * height)
	buffer.put_32(0)
	buffer.put_32(0)
	buffer.put_u32(0)
	buffer.put_u32(0)
	var pixels := PackedByteArray()
	pixels.resize(width * height * 4)
	var mask := PackedByteArray()
	mask.resize(mask_stride * height)
	mask.fill(0)
	for row in height:
		var source_row: int = height - 1 - row
		for x in width:
			var from: int = (source_row * width + x) * 4
			var to: int = (row * width + x) * 4
			pixels[to] = data[from + 2]
			pixels[to + 1] = data[from + 1]
			pixels[to + 2] = data[from]
			pixels[to + 3] = data[from + 3]
			if data[from + 3] < 8:
				mask[row * mask_stride + (x >> 3)] |= 0x80 >> (x & 7)
	buffer.put_data(pixels)
	buffer.put_data(mask)
	return buffer.data_array


## Parses an .ico and returns [{width, height, png: bool, image: Image}] (empty on error).
static func read_ico(bytes: PackedByteArray) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if bytes.size() < 6 or bytes.decode_u16(0) != 0 or bytes.decode_u16(2) != 1:
		return result
	var count: int = bytes.decode_u16(4)
	for index in count:
		var entry: int = 6 + index * 16
		if entry + 16 > bytes.size():
			return []
		var width: int = bytes[entry] if bytes[entry] != 0 else 256
		var height: int = bytes[entry + 1] if bytes[entry + 1] != 0 else 256
		var length: int = bytes.decode_u32(entry + 8)
		var offset: int = bytes.decode_u32(entry + 12)
		if offset + length > bytes.size() or length <= 0:
			return []
		var payload: PackedByteArray = bytes.slice(offset, offset + length)
		var is_png: bool = payload.size() > 8 and payload[0] == 0x89 and payload[1] == 0x50
		var image: Image = null
		if is_png:
			image = Image.new()
			if image.load_png_from_buffer(payload) != OK:
				image = null
		else:
			image = _decode_dib(payload)
		result.append({"width": width, "height": height, "png": is_png, "image": image})
	return result


static func _decode_dib(payload: PackedByteArray) -> Image:
	if payload.size() < 40 or payload.decode_u32(0) != 40 or payload.decode_u16(14) != 32:
		return null
	var width: int = payload.decode_s32(4)
	var height: int = payload.decode_s32(8) / 2
	if width <= 0 or height <= 0 or payload.size() < 40 + width * height * 4:
		return null
	var data := PackedByteArray()
	data.resize(width * height * 4)
	for row in height:
		for x in width:
			var from: int = 40 + ((height - 1 - row) * width + x) * 4
			var to: int = (row * width + x) * 4
			data[to] = payload[from + 2]
			data[to + 1] = payload[from + 1]
			data[to + 2] = payload[from]
			data[to + 3] = payload[from + 3]
	return Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, data)


# ---------------------------------------------------------------- rendering


func render_all() -> void:
	for directory: String in [ICONS_DIR, ART_DIR, STEAM_DIR, PLAY_DIR, BRAND_DIR, ACHIEVEMENT_DIR]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_write_text("res://icon.svg", _project_icon_svg())
	_save_png(render_icon(192, "rounded"), ICONS_DIR + "/icon_192.png")
	_save_png(render_icon(512, "square"), ICONS_DIR + "/icon_512.png")
	_save_png(render_icon(ADAPTIVE_SIZE, "foreground"), ICONS_DIR + "/adaptive_foreground_432.png")
	_save_png(_opaque(render_icon(ADAPTIVE_SIZE, "background")), ICONS_DIR + "/adaptive_background_432.png")
	_save_png(render_icon(ADAPTIVE_SIZE, "monochrome"), ICONS_DIR + "/adaptive_monochrome_432.png")
	var windows: Array[Image] = [render_icon(16), render_icon(32), render_icon(48), render_icon(256)]
	_write_bytes(ICONS_DIR + "/icon_256.ico", ico_bytes(windows))
	var client: Array[Image] = [render_icon(16), render_icon(32)]
	_write_bytes(ART_DIR + "/steam_client_icon_32.ico", ico_bytes(client))
	_save_png(render_icon(32), ART_DIR + "/steam_client_icon_32.png")
	_save_png(render_icon(256), STEAM_DIR + "/shortcut_icon_256.png")
	var app_icon: Image = _opaque(render_icon(184, "square"))
	app_icon.save_jpg(ProjectSettings.globalize_path(STEAM_DIR + "/app_icon_184.jpg"), 0.95)
	_save_png(_opaque(render_icon(512, "square")), PLAY_DIR + "/icon_512.png")
	_write_linux_icons(STEAM_DIR + "/linux_client_icons.zip")
	_write_text(BRAND_DIR + "/icon_rounded.svg", icon_svg(512, "rounded"))
	_write_text(BRAND_DIR + "/icon_square.svg", icon_svg(512, "square"))
	_write_text(BRAND_DIR + "/mark.svg", icon_svg(512, "mark"))
	_save_png(render_icon(1024, "mark"), BRAND_DIR + "/mark_1024.png")
	_save_png(_opaque(render_svg(feature_graphic_svg())), ART_DIR + "/play_feature_graphic_placeholder_1024x500.png")
	print("render_icons: wrote icons, store icons and brand files")


## Placeholder Google Play feature graphic (1024x500, opaque, no text). Task R6 replaces it with
## a rendered scene and the logotype.
static func feature_graphic_svg() -> String:
	var parts := PackedStringArray()
	parts.append('<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="500" viewBox="0 0 1024 500">')
	parts.append(defs(Vector2(690, 170), 640.0, 300.0))
	parts.append('<rect width="1024" height="500" fill="url(#dw_bg)"/>')
	parts.append('<g opacity="0.12">')
	for i in range(14):
		var x: float = 40.0 + float(i) * 44.0
		parts.append('<path d="M %s 500 L %s 500 L %s 452 L %s 452 Z" fill="%s"/>' % [_n(x), _n(x + 22.0), _n(x + 70.0), _n(x + 48.0), AMBER])
	parts.append('</g>')
	var transform: String = "translate(690 230) rotate(45) scale(1.05) translate(%s %s)" % [_n(-MARK_CENTER.x), _n(-MARK_CENTER.y)]
	parts.append('<g transform="%s">%s</g>' % [transform, mark(2, false, 520.0, true)])
	parts.append('</svg>')
	return "".join(parts)


## The project icon (window/editor/boot) keeps the 256 px imported size.
static func _project_icon_svg() -> String:
	var svg: String = icon_svg(256, "rounded")
	return "<!-- DEADWEIGHT mark. Generated by tools/render_icons.gd: edit the builders there. -->\n" + svg + "\n"


## Steam client icons for Linux: a zip of square PNGs named <n>x<n>.png.
func _write_linux_icons(path: String) -> void:
	var zip := ZIPPacker.new()
	var error: Error = zip.open(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("cannot write %s" % path)
		return
	for size: int in [16, 24, 32, 48, 64, 96, 128, 256, 512]:
		zip.start_file("%dx%d.png" % [size, size])
		zip.write_file(render_icon(size).save_png_to_buffer())
		zip.close_file()
	zip.close()


static func _opaque(image: Image) -> Image:
	var flat := Image.create(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
	flat.fill(Color(INK))
	flat.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
	flat.convert(Image.FORMAT_RGB8)
	return flat


static func _save_png(image: Image, path: String) -> void:
	if image == null:
		push_error("nothing to save for %s" % path)
		return
	var error: Error = image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("save failed %s (%s)" % [path, error_string(error)])


static func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.WRITE)
	if file == null:
		push_error("cannot write %s" % path)
		return
	file.store_buffer(bytes)


static func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.WRITE)
	if file == null:
		push_error("cannot write %s" % path)
		return
	file.store_string(text)


# ---------------------------------------------------------------- preview


## Contact sheet: icons at every launcher size on dark and light grounds, store masks,
## adaptive masks, themed monochrome and pixel zooms. Saved under .tools/captures/store.
func save_contact_sheet() -> void:
	var sheet := Image.create(1600, 1180, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("1e2326"))
	_fill(sheet, Rect2i(0, 300, 1600, 280), Color("eef1f0"))
	var x: int = 20
	for size: int in [256, 128, 96, 64, 48, 32, 24, 16]:
		var icon: Image = render_icon(size)
		sheet.blend_rect(icon, Rect2i(Vector2i.ZERO, icon.get_size()), Vector2i(x, 20))
		sheet.blend_rect(icon, Rect2i(Vector2i.ZERO, icon.get_size()), Vector2i(x, 310))
		x += size + 24
	var play: Image = _masked(render_icon(512, "square"), "rounded30")
	for size: int in [256, 128, 64, 48]:
		var copy: Image = play.duplicate()
		copy.resize(size, size, Image.INTERPOLATE_LANCZOS)
		sheet.blend_rect(copy, Rect2i(Vector2i.ZERO, copy.get_size()), Vector2i(20 + [0, 280, 432, 520][[256, 128, 64, 48].find(size)], 600))
	var foreground: Image = render_icon(ADAPTIVE_SIZE, "foreground")
	var background: Image = render_icon(ADAPTIVE_SIZE, "background")
	var layered: Image = background.duplicate()
	layered.blend_rect(foreground, Rect2i(0, 0, 432, 432), Vector2i.ZERO)
	var shapes: Array[String] = ["circle", "squircle", "rounded30", "teardrop"]
	for index in shapes.size():
		var shaped: Image = _masked(_crop_viewport(layered), shapes[index])
		shaped.resize(144, 144, Image.INTERPOLATE_LANCZOS)
		sheet.blend_rect(shaped, Rect2i(0, 0, 144, 144), Vector2i(620 + index * 164, 600))
	var mono: Image = render_icon(ADAPTIVE_SIZE, "monochrome")
	var themed := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	themed.fill(Color("d7e3ff"))
	var tinted: Image = _tint(mono, Color("1b3b78"))
	themed.blend_rect(tinted, Rect2i(0, 0, 432, 432), Vector2i.ZERO)
	var themed_shaped: Image = _masked(_crop_viewport(themed), "circle")
	themed_shaped.resize(144, 144, Image.INTERPOLATE_LANCZOS)
	sheet.blend_rect(themed_shaped, Rect2i(0, 0, 144, 144), Vector2i(1276, 600))
	var safe_overlay: Image = foreground.duplicate()
	_ring(safe_overlay, Vector2(216, 216), ADAPTIVE_SAFE_RADIUS, Color(1, 0.2, 0.3, 1))
	safe_overlay.resize(216, 216, Image.INTERPOLATE_LANCZOS)
	var guide: Image = background.duplicate()
	guide.resize(216, 216, Image.INTERPOLATE_LANCZOS)
	guide.blend_rect(safe_overlay, Rect2i(0, 0, 216, 216), Vector2i.ZERO)
	sheet.blend_rect(guide, Rect2i(0, 0, 216, 216), Vector2i(20, 900))
	for zoom_size: int in [16, 32, 48]:
		var zoom: Image = render_icon(zoom_size)
		var factor: int = 192 / zoom_size
		zoom.resize(zoom_size * factor, zoom_size * factor, Image.INTERPOLATE_NEAREST)
		sheet.blend_rect(zoom, Rect2i(Vector2i.ZERO, zoom.get_size()), Vector2i(270 + [0, 220, 440][[16, 32, 48].find(zoom_size)], 900))
	var mark_image: Image = render_icon(512, "mark")
	mark_image.resize(256, 256, Image.INTERPOLATE_LANCZOS)
	sheet.blend_rect(mark_image, Rect2i(0, 0, 256, 256), Vector2i(1000, 880))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
	sheet.save_png(ProjectSettings.globalize_path(CAPTURE_DIR + "/icons_sheet.png"))
	print("render_icons: contact sheet saved to %s/icons_sheet.png" % CAPTURE_DIR)


## The 72 dp visible viewport of an adaptive icon (inner 288 of 432 px).
static func _crop_viewport(image: Image) -> Image:
	return image.get_region(Rect2i(72, 72, 288, 288))


static func _masked(source: Image, shape: String) -> Image:
	var image: Image = source.duplicate()
	image.convert(Image.FORMAT_RGBA8)
	var size: float = float(image.get_width())
	var half: float = size * 0.5
	for y in image.get_height():
		for x in image.get_width():
			var p := Vector2(float(x) + 0.5 - half, float(y) + 0.5 - half) / half
			var inside: float = _shape_coverage(p, shape, 1.5 / half)
			if inside < 1.0:
				var color: Color = image.get_pixel(x, y)
				color.a *= inside
				image.set_pixel(x, y, color)
	return image


static func _shape_coverage(p: Vector2, shape: String, feather: float) -> float:
	var distance: float
	match shape:
		"circle":
			distance = p.length() - 1.0
		"squircle":
			distance = pow(pow(absf(p.x), 4.0) + pow(absf(p.y), 4.0), 0.25) - 1.0
		"teardrop":
			distance = p.length() - 1.0 if not (p.x > 0.0 and p.y > 0.0) else maxf(p.x, p.y) - 1.0
		_:
			var radius: float = 0.6
			var q := Vector2(absf(p.x), absf(p.y)) - Vector2(1.0 - radius, 1.0 - radius)
			distance = Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - radius
	return clampf(0.5 - distance / feather, 0.0, 1.0)


static func _tint(source: Image, color: Color) -> Image:
	var image: Image = source.duplicate()
	for y in image.get_height():
		for x in image.get_width():
			var alpha: float = image.get_pixel(x, y).a
			image.set_pixel(x, y, Color(color, alpha))
	return image


static func _ring(image: Image, center: Vector2, radius: float, color: Color) -> void:
	for step in 720:
		var angle: float = TAU * float(step) / 720.0
		var point: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
		var px := Vector2i(int(point.x), int(point.y))
		if Rect2i(Vector2i.ZERO, image.get_size()).has_point(px):
			image.set_pixelv(px, color)


static func _fill(image: Image, rect: Rect2i, color: Color) -> void:
	image.fill_rect(rect, color)


# ---------------------------------------------------------------- verification


func verify_all() -> void:
	_check_png(ICONS_DIR + "/icon_192.png", Vector2i(192, 192), "corners")
	_check_png(ICONS_DIR + "/icon_512.png", Vector2i(512, 512), "opaque")
	_check_png(ICONS_DIR + "/adaptive_foreground_432.png", Vector2i(432, 432), "corners")
	_check_png(ICONS_DIR + "/adaptive_background_432.png", Vector2i(432, 432), "opaque")
	_check_png(ICONS_DIR + "/adaptive_monochrome_432.png", Vector2i(432, 432), "mono")
	_check_safe_zone()
	_check_ico(ICONS_DIR + "/icon_256.ico", [16, 32, 48, 256])
	_check_ico(ART_DIR + "/steam_client_icon_32.ico", [16, 32])
	_check_png(ART_DIR + "/steam_client_icon_32.png", Vector2i(32, 32), "corners")
	_check_png(STEAM_DIR + "/shortcut_icon_256.png", Vector2i(256, 256), "corners")
	_check_jpg(STEAM_DIR + "/app_icon_184.jpg", Vector2i(184, 184))
	_check_png(PLAY_DIR + "/icon_512.png", Vector2i(512, 512), "opaque")
	_check_file_size(PLAY_DIR + "/icon_512.png", 1024 * 1024)
	_check_linux_zip(STEAM_DIR + "/linux_client_icons.zip")
	_check_png(ART_DIR + "/play_feature_graphic_placeholder_1024x500.png", Vector2i(1024, 500), "opaque")
	_check_svg("res://icon.svg", Vector2i(256, 256))
	for file: String in ["icon_rounded.svg", "icon_square.svg", "mark.svg"]:
		_check_svg(BRAND_DIR + "/" + file, Vector2i(512, 512))


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("PASS ", label)
	else:
		_failures += 1
		print("FAIL ", label)


func _load_png(path: String) -> Image:
	var absolute: String = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(absolute):
		return null
	var image := Image.new()
	if image.load(absolute) != OK:
		return null
	return image


func _check_png(path: String, size: Vector2i, rule: String) -> void:
	var image: Image = _load_png(path)
	_expect(image != null, "%s exists and decodes" % path)
	if image == null:
		return
	_expect(image.get_size() == size, "%s is %dx%d (got %dx%d)" % [path, size.x, size.y, image.get_width(), image.get_height()])
	image.convert(Image.FORMAT_RGBA8)
	match rule:
		"opaque":
			_expect(not image.detect_alpha(), "%s has no transparency (store rule)" % path)
		"corners":
			_expect(image.get_pixel(0, 0).a < 0.05 and image.get_pixel(size.x - 1, size.y - 1).a < 0.05, "%s has transparent corners" % path)
			_expect(image.get_pixel(size.x / 2, size.y / 2).a > 0.5 or image.get_pixel(size.x / 2 + size.x / 16, size.y / 2 - size.y / 16).a > 0.5, "%s has content near the centre" % path)
		"mono":
			var coloured: int = 0
			for y in range(0, size.y, 3):
				for x in range(0, size.x, 3):
					var pixel: Color = image.get_pixel(x, y)
					if pixel.a > 0.1 and (pixel.r < 0.9 or pixel.g < 0.9 or pixel.b < 0.9):
						coloured += 1
			_expect(coloured == 0, "%s is a white-only alpha layer" % path)


## Everything but the trailing line must sit inside the 66 dp safe circle.
func _check_safe_zone() -> void:
	var transform: String = "translate(216 216) rotate(45) scale(%s) translate(%s %s)" % [_n(ADAPTIVE_SAFE_RADIUS / MARK_RADIUS), _n(-MARK_CENTER.x), _n(-MARK_CENTER.y)]
	var svg: String = '<svg xmlns="http://www.w3.org/2000/svg" width="432" height="432" viewBox="0 0 432 432">' + defs() + '<g transform="%s">%s</g></svg>' % [transform, mark(1, true, 118.0, false, false)]
	var image: Image = render_svg(svg)
	var outside: int = 0
	var covered: int = 0
	for y in 432:
		for x in 432:
			if image.get_pixel(x, y).a > 0.25:
				covered += 1
				if Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(Vector2(216, 216)) > ADAPTIVE_SAFE_RADIUS + 1.0:
					outside += 1
	_expect(covered > 15000, "adaptive mark fills the safe zone (%d px)" % covered)
	_expect(outside == 0, "adaptive mark stays inside the 66 dp safe zone (%d px outside)" % outside)


func _check_ico(path: String, sizes: Array) -> void:
	var absolute: String = ProjectSettings.globalize_path(path)
	_expect(FileAccess.file_exists(absolute), "%s exists" % path)
	if not FileAccess.file_exists(absolute):
		return
	var entries: Array[Dictionary] = read_ico(FileAccess.get_file_as_bytes(absolute))
	var found: Array = []
	for entry: Dictionary in entries:
		found.append(entry["width"])
		var image: Image = entry["image"]
		_expect(image != null and image.get_width() == int(entry["width"]) and image.get_height() == int(entry["height"]), "%s %dpx entry decodes" % [path, int(entry["width"])])
	_expect(found == sizes, "%s holds sizes %s (got %s)" % [path, str(sizes), str(found)])


func _check_jpg(path: String, size: Vector2i) -> void:
	var image: Image = _load_png(path)
	_expect(image != null and image.get_size() == size, "%s is a %dx%d JPEG" % [path, size.x, size.y])


func _check_file_size(path: String, limit: int) -> void:
	var file := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.READ)
	var length: int = file.get_length() if file != null else -1
	_expect(length > 0 and length <= limit, "%s is %d bytes (limit %d)" % [path, length, limit])


func _check_linux_zip(path: String) -> void:
	var zip := ZIPReader.new()
	var opened: bool = zip.open(ProjectSettings.globalize_path(path)) == OK
	_expect(opened, "%s opens" % path)
	if not opened:
		return
	var files: PackedStringArray = zip.get_files()
	_expect(files.size() == 9, "%s has 9 icon sizes" % path)
	var valid: bool = true
	for file: String in files:
		var image := Image.new()
		var side: int = int(file.get_slice("x", 0))
		if image.load_png_from_buffer(zip.read_file(file)) != OK or image.get_width() != side or image.get_height() != side:
			valid = false
	zip.close()
	_expect(valid, "%s entries decode at their named sizes" % path)


func _check_svg(path: String, size: Vector2i) -> void:
	var absolute: String = ProjectSettings.globalize_path(path)
	var text: String = FileAccess.get_file_as_string(absolute) if FileAccess.file_exists(absolute) else ""
	var image: Image = render_svg(text) if not text.is_empty() else null
	_expect(image != null and image.get_size() == size, "%s renders at %dx%d" % [path, size.x, size.y])
