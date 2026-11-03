extends SceneTree
## Store art compositor (R6). Renders the Steam and Google Play key art at the exact store sizes.
## Each job builds a catalog level in its own SubViewport of the target size, frames it with a
## camera, and draws the brand lockup (the game's logotype font and the brand mark) over it.
## "still" jobs freeze the player; "cast" jobs fire the real rod at an anchor and capture once the
## weight has latched (the line is taut). Nothing touches the player's save.
##
## Run from the project root, off-screen:
##   <godot> --path . --position 20000,20000 --script res://tools/store_art.gd -- --only=header
## (--only= takes a substring of the output file name; leave it out to render every job)
## Writes only the JOBS files under store/art/steam/ and store/art/google-play/.

const Catalog = preload("res://scripts/level_catalog.gd")
const Player = preload("res://scripts/player.gd")
const Tether = preload("res://scripts/tether.gd")
const UiTheme = preload("res://scripts/ui/theme.gd")

const MARK_PATH: String = "res://store/art/brand/mark_1024.png"
const ART_DIR: String = "res://store/art/"
const TAGLINE: String = "DEPARTMENT OF UNFINISHED GRAVITY"
const WORDMARK: String = "DEADWEIGHT"
const SETTLE_FRAMES: int = 30
const CAST_TIMEOUT: float = 5.0

## One entry per output. Fields:
##   file: path under store/art/ (new files only); size: output pixels; level: catalog id (or "")
##   mode: "still" (frozen player, camera only) or "cast" (rod fired from "from" at "aim")
##   practice: true removes enemies (clean scenery); cam/look/fov: camera; hold: seconds after latch
##   layout: overlay style, "none" for text-free art; transparent: alpha background (logo only)
const JOBS: Array[Dictionary] = [
	{"file": "steam/steam_header_920x430.png", "size": Vector2i(920, 430), "level": "l03", "mode": "still",
		"practice": false, "cam": Vector3(0.0, 4.0, 12.0), "look": Vector3(-1.0, 4.0, -40.0), "fov": 60.0, "layout": "header"},
	{"file": "steam/steam_capsule_small_462x174.png", "size": Vector2i(462, 174), "level": "l05", "mode": "still",
		"practice": false, "cam": Vector3(6.0, 14.0, 18.0), "look": Vector3(0.0, 9.0, -30.0), "fov": 60.0, "layout": "small"},
	{"file": "steam/steam_capsule_main_1232x706.png", "size": Vector2i(1232, 706), "level": "l01", "mode": "still",
		"practice": false, "cam": Vector3(15.0, 15.0, 34.0), "look": Vector3(-4.0, 9.0, -40.0), "fov": 60.0, "layout": "main"},
	{"file": "steam/steam_capsule_vertical_748x896.png", "size": Vector2i(748, 896), "level": "l04", "mode": "still",
		"practice": false, "cam": Vector3(0.0, 6.0, 12.0), "look": Vector3(0.0, 4.0, -40.0), "fov": 60.0, "layout": "vertical"},
	{"file": "steam/steam_library_capsule_600x900.png", "size": Vector2i(600, 900), "level": "l02", "mode": "still",
		"practice": false, "cam": Vector3(0.0, 4.0, 10.0), "look": Vector3(0.0, 5.0, -30.0), "fov": 60.0, "layout": "capsule"},
	{"file": "steam/steam_library_hero_3840x1240.png", "size": Vector2i(3840, 1240), "level": "l03", "mode": "still",
		"practice": false, "cam": Vector3(0.0, 12.0, 20.0), "look": Vector3(0.0, 4.0, -40.0), "fov": 70.0, "layout": "none"},
	{"file": "steam/steam_library_logo_1280x720.png", "size": Vector2i(1280, 720), "level": "", "mode": "still",
		"practice": false, "cam": Vector3.ZERO, "look": Vector3.FORWARD, "fov": 60.0, "layout": "logo", "transparent": true},
	{"file": "steam/steam_page_background_1438x810.png", "size": Vector2i(1438, 810), "level": "l05", "mode": "still",
		"practice": false, "cam": Vector3(-12.0, 8.0, 14.0), "look": Vector3(4.0, 8.0, -60.0), "fov": 60.0, "layout": "none"},
	{"file": "google-play/play_feature_graphic_1024x500.png", "size": Vector2i(1024, 500), "level": "l03", "mode": "still",
		"practice": false, "cam": Vector3(0.0, 6.0, 16.0), "look": Vector3(0.0, 5.0, -40.0), "fov": 60.0, "layout": "feature"},
]

## The logotype: the brand mark beside the DEADWEIGHT wordmark, drawn the way the title screen
## draws it (paper "DEAD", amber "WEIGHT", cyan measuring rule) but without the spool captions.
## Glyphs are placed one by one at a computed advance, so tracking holds at every size.
class Lockup extends Control:
	var mark: Texture2D
	var tagline: bool = false
	const TRACK: float = 0.22

	static func logo_font() -> Font:
		var variation := FontVariation.new()
		variation.base_font = ThemeDB.fallback_font
		variation.variation_embolden = 1.35
		variation.variation_transform = Transform2D(Vector2(1.18, 0.0), Vector2(0.0, 1.0), Vector2.ZERO)
		return variation

	func _draw() -> void:
		var fs: float = _fit_font_size()
		var font: Font = logo_font()
		var px: int = int(round(fs))
		var mark_side: float = fs * 2.4
		if mark != null:
			draw_texture_rect(mark, Rect2(0.0, (size.y - mark_side) * 0.5, mark_side, mark_side), false)
		var x0: float = mark_side + fs * 0.25
		var cap: float = font.get_ascent(px) * 0.72
		var word_block: float = cap + fs * 0.17 + fs * 0.28 * float(tagline)
		var baseline: float = (size.y - word_block) * 0.5 + cap
		# A soft shadow keeps the wordmark legible on bright sky and on a light page.
		_draw_glyphs(font, px, fs, "DEADWEIGHT", x0 + fs * 0.03, baseline + fs * 0.04, Color(0.03, 0.04, 0.05, 0.6))
		var dead_end: float = _draw_glyphs(font, px, fs, "DEAD", x0, baseline, UiTheme.PAPER)
		_draw_glyphs(font, px, fs, "WEIGHT", dead_end, baseline, UiTheme.AMBER)
		var word_w: float = _word_advance(font, px, fs, "DEADWEIGHT")
		var rule_y: float = baseline + fs * 0.17
		draw_line(Vector2(x0, rule_y), Vector2(x0 + word_w, rule_y), Color(UiTheme.CYAN, 0.7), maxf(1.5, fs * 0.03), true)
		for i in 21:
			var tx: float = x0 + word_w * float(i) / 20.0
			var tall: bool = i % 5 == 0
			draw_line(Vector2(tx, rule_y), Vector2(tx, rule_y + fs * (0.09 if tall else 0.045)), Color(UiTheme.CYAN, 0.7 if tall else 0.4), maxf(1.0, fs * 0.03), true)
		if tagline:
			var label_font: Font = UiTheme.font("label")
			var label_size: int = maxi(9, int(round(fs * 0.2)))
			draw_string(label_font, Vector2(x0, rule_y + fs * 0.34), TAGLINE, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, Color(UiTheme.MUTED, 0.95))

	## Draws each glyph at its own advance and returns the x where the run ends.
	func _draw_glyphs(font: Font, px: int, fs: float, text: String, x: float, baseline: float, color: Color) -> float:
		for index in text.length():
			var ch: String = text.substr(index, 1)
			draw_string(font, Vector2(x, baseline), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)
			x += _advance(font, px, fs, ch)
		return x

	func _advance(font: Font, px: int, fs: float, ch: String) -> float:
		return font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + fs * TRACK

	func _word_advance(font: Font, px: int, fs: float, text: String) -> float:
		var total: float = 0.0
		for index in text.length():
			total += _advance(font, px, fs, text.substr(index, 1))
		return total

	## Font size at which the mark plus wordmark fill the control's width (and height, if tighter).
	func _fit_font_size() -> float:
		var font: Font = logo_font()
		var fs: float = size.x / 11.0
		for step in 4:
			var total: float = fs * 2.4 + fs * 0.25 + _word_advance(font, int(round(fs)), fs, "DEADWEIGHT")
			fs *= size.x / total
		return minf(fs, size.y / 2.6)


var _mark: Texture2D
var _saved: int = 0


func _initialize() -> void:
	var only: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			only = argument.substr(7)
	_mark = ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(MARK_PATH)))
	_run.call_deferred(only)


func _run(only: String) -> void:
	for job: Dictionary in JOBS:
		if not only.is_empty() and not str(job["file"]).contains(only):
			continue
		await _render(job)
	print("STORE_ART saved %d file(s)" % _saved)
	quit(0)


## Renders one job into a SubViewport of its size and saves the result.
func _render(job: Dictionary) -> void:
	var size_px: Vector2i = job["size"]
	var view := SubViewport.new()
	view.size = size_px
	view.own_world_3d = true
	view.transparent_bg = bool(job.get("transparent", false))
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var level_id: String = str(job["level"])
	var player: RigidBody3D = null
	var tether: Node3D = null
	var level: Node3D = null
	if not level_id.is_empty():
		var stage := Node3D.new()
		view.add_child(stage)
		player = Player.new()
		stage.add_child(player)
		player.freeze = true
		level = Catalog.create(level_id)
		stage.add_child(level)
		level.set("quality", 2)
		level.call("build", player, bool(job["practice"]))
		player.reset_at(level.get("spawn_position"))
		tether = Tether.new()
		stage.add_child(tether)
		tether.bind(player)
		_add_camera(stage, job)
		if str(job["mode"]) == "still":
			player.rod_model.hide()
			player.gun_model.hide()
	await _frames(SETTLE_FRAMES)
	if str(job["mode"]) == "cast":
		await _cast(job, level, player, tether)
	var overlay := Control.new()
	overlay.size = Vector2(size_px)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(overlay)
	_compose(overlay, str(job["layout"]), Vector2(size_px))
	# The SubViewport can still be filling in on the first frames, so wait for several draws.
	await _frames(12)
	await RenderingServer.frame_post_draw
	await _frames(2)
	await RenderingServer.frame_post_draw
	var image: Image = view.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path(ART_DIR + str(job["file"]))
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var error: Error = image.save_png(path)
	print("STORE_ART %s %dx%d result=%d" % [path, image.get_width(), image.get_height(), error])
	if error == OK:
		_saved += 1
	view.queue_free()
	await process_frame


func _add_camera(stage: Node3D, job: Dictionary) -> void:
	var cam := Camera3D.new()
	cam.far = 1000.0
	cam.fov = float(job["fov"])
	stage.add_child(cam)
	cam.global_position = job["cam"]
	cam.look_at(job["look"], Vector3.UP)
	cam.make_current()


## Fires the rod from the spawn at the aim point, lets the weight latch, and holds for "hold"
## seconds. The camera stays where the job put it, so the line and weight stay in frame.
func _cast(job: Dictionary, level: Node3D, player: RigidBody3D, tether: Node3D) -> void:
	var from: Vector3 = job["from"]
	var aim: Vector3 = job["aim"]
	player.freeze = false
	player.reset_at(from)
	player.active = true
	tether.active = true
	level.set_active(true)
	await _frames(SETTLE_FRAMES)
	var direction: Vector3 = (aim - player.global_position).normalized()
	player.yaw = atan2(-direction.x, -direction.z)
	player.pitch = asin(clampf(direction.y, -1.0, 1.0))
	await _frames(6)
	tether.begin_charge()
	await create_timer(float(job.get("charge", 0.8))).timeout
	tether.release_cast()
	var waited: float = 0.0
	while not tether.anchored and waited < CAST_TIMEOUT:
		await process_frame
		waited += root.get_process_delta_time()
	print("STORE_ART cast latched=%s after %.2fs" % [str(tether.anchored), waited])
	await create_timer(float(job.get("hold", 0.4))).timeout


func _count_meshes(node: Node) -> int:
	var total: int = 1 if node is MeshInstance3D else 0
	for child: Node in node.get_children():
		total += _count_meshes(child)
	return total


func _frames(count: int) -> void:
	for i in count:
		await process_frame


## The overlay for a layout: a soft scrim where text sits, then the lockup in its own box.
func _compose(overlay: Control, layout: String, size_px: Vector2) -> void:
	var lockup := Lockup.new()
	lockup.mark = _mark
	var box := Rect2(Vector2.ZERO, size_px)
	match layout:
		"header":
			_scrim(overlay, Vector2(0.0, 0.5), Vector2(0.68, 0.5), 0.72)
			box = Rect2(size_px.x * 0.05, size_px.y * 0.18, size_px.x * 0.56, size_px.y * 0.64)
			lockup.tagline = true
		"small":
			_scrim(overlay, Vector2(0.0, 0.5), Vector2(1.0, 0.5), 0.9)
			box = Rect2(size_px.x * 0.06, size_px.y * 0.16, size_px.x * 0.88, size_px.y * 0.68)
		"main":
			_scrim(overlay, Vector2(0.0, 0.2), Vector2(0.58, 0.2), 0.7)
			box = Rect2(size_px.x * 0.05, size_px.y * 0.08, size_px.x * 0.44, size_px.y * 0.34)
			lockup.tagline = true
		"vertical":
			_scrim(overlay, Vector2(0.5, 1.0), Vector2(0.5, 0.5), 0.85)
			box = Rect2(size_px.x * 0.08, size_px.y * 0.74, size_px.x * 0.84, size_px.y * 0.2)
			lockup.tagline = true
		"capsule":
			_scrim(overlay, Vector2(0.5, 1.0), Vector2(0.5, 0.55), 0.85)
			box = Rect2(size_px.x * 0.08, size_px.y * 0.8, size_px.x * 0.84, size_px.y * 0.14)
		"feature":
			_scrim(overlay, Vector2(0.0, 0.5), Vector2(0.62, 0.5), 0.75)
			box = Rect2(size_px.x * 0.05, size_px.y * 0.2, size_px.x * 0.52, size_px.y * 0.6)
			lockup.tagline = true
		"logo":
			box = Rect2(size_px.x * 0.1, size_px.y * 0.3, size_px.x * 0.8, size_px.y * 0.4)
			lockup.tagline = true
		_:
			return
	lockup.position = box.position
	lockup.size = box.size
	overlay.add_child(lockup)


## A dark gradient from the "from" edge (UV) to the "to" point, for legibility over the sky.
func _scrim(overlay: Control, from: Vector2, to: Vector2, strength: float) -> void:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.02, 0.04, 0.05, strength), Color(0.02, 0.04, 0.05, 0.0)])
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 256
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = from
	texture.fill_to = to
	var rect := TextureRect.new()
	rect.texture = texture
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.position = Vector2.ZERO
	rect.size = overlay.size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(rect)
