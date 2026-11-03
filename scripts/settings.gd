extends RefCounted
## Applies profile settings to the engine (window mode, vsync, frame cap, MSAA, 3D render scale)
## and to the audio buses. Player, HUD and level settings are pushed by main.gd.
## Every helper is safe headless and on mobile, and only touches what actually changed.

const MSAA_BY_QUALITY := [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X]
const WINDOWED_FRACTION := 0.8   # windowed size as a share of the usable screen
const MIN_WINDOW := Vector2i(960, 540)


static func apply_engine(settings: Dictionary, allow_window_changes: bool) -> void:
	var desktop_window: bool = _has_window() and not OS.has_feature("mobile")
	if allow_window_changes and desktop_window:
		_apply_window_mode(str(settings.get("window_mode", "fullscreen")))
	if _has_window():
		var vsync: int = DisplayServer.VSYNC_ENABLED if bool(settings.get("vsync", true)) else DisplayServer.VSYNC_DISABLED
		if DisplayServer.window_get_vsync_mode() != vsync:
			DisplayServer.window_set_vsync_mode(vsync)
	Engine.max_fps = maxi(0, int(settings.get("max_fps", 0)))
	var viewport: Viewport = _root_viewport()
	if viewport != null:
		apply_viewport(viewport, settings)


## MSAA from the quality level and 3D resolution scaling from render_scale.
static func apply_viewport(viewport: Viewport, settings: Dictionary) -> void:
	var quality: int = clampi(int(settings.get("quality", 2)), 0, MSAA_BY_QUALITY.size() - 1)
	var msaa: Viewport.MSAA = MSAA_BY_QUALITY[quality]
	if viewport.msaa_3d != msaa:
		viewport.msaa_3d = msaa
	var scale: float = clampf(float(settings.get("render_scale", 1.0)), 0.5, 1.0)
	if not is_equal_approx(viewport.scaling_3d_scale, scale):
		viewport.scaling_3d_scale = scale
	var mode: Viewport.Scaling3DMode = scaling_mode_for(scale, RenderingServer.get_current_rendering_method())
	if viewport.scaling_3d_mode != mode:
		viewport.scaling_3d_mode = mode


## FSR 1 sharpens upscaled frames on the RenderingDevice renderers; Compatibility only
## supports bilinear scaling.
static func scaling_mode_for(scale: float, rendering_method: String) -> Viewport.Scaling3DMode:
	if scale >= 0.999 or rendering_method == "gl_compatibility":
		return Viewport.SCALING_3D_MODE_BILINEAR
	return Viewport.SCALING_3D_MODE_FSR


## Volumes go through audio.gd when it exists so it can apply its own curve; otherwise the
## Master/Music/SFX/UI buses are set directly (linear 0..1, muted at 0).
static func apply_audio(settings: Dictionary) -> void:
	var master: float = clampf(float(settings.get("master_volume", 0.9)), 0.0, 1.0)
	var music: float = clampf(float(settings.get("music_volume", 0.6)), 0.0, 1.0)
	var sfx: float = clampf(float(settings.get("sfx_volume", 0.9)), 0.0, 1.0)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null:
		var audio: Node = tree.get_first_node_in_group("game_audio")
		if audio != null and audio.has_method("set_volumes"):
			audio.call("set_volumes", master, music, sfx)
			return
	set_bus_volume("Master", master)
	set_bus_volume("Music", music)
	set_bus_volume("SFX", sfx)
	set_bus_volume("UI", sfx)


static func set_bus_volume(bus_name: String, linear: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, linear <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.001)))


static func _apply_window_mode(mode: String) -> void:
	var current: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	var fullscreen: bool = current == DisplayServer.WINDOW_MODE_FULLSCREEN or current == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if mode == "fullscreen" and not fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif mode == "windowed" and fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		_center_window()


## A comfortable 16:9 window on the current screen after leaving fullscreen.
static func _center_window() -> void:
	var screen: int = DisplayServer.window_get_current_screen()
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(screen)
	if usable.size.x <= 0 or usable.size.y <= 0:
		return
	var width: int = int(usable.size.x * WINDOWED_FRACTION)
	var height: int = int(width * 9.0 / 16.0)
	if height > int(usable.size.y * WINDOWED_FRACTION):
		height = int(usable.size.y * WINDOWED_FRACTION)
		width = int(height * 16.0 / 9.0)
	var size := Vector2i(maxi(width, mini(MIN_WINDOW.x, usable.size.x)), maxi(height, mini(MIN_WINDOW.y, usable.size.y)))
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(usable.position + (usable.size - size) / 2)


static func _has_window() -> bool:
	return DisplayServer.get_name() != "headless"


static func _root_viewport() -> Viewport:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return tree.root if tree != null else null
