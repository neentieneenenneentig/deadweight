extends SceneTree
## Actual gameplay scenery and animated sky, captured without loading a user profile.
## --resolution 800x450 --script res://tests/storm_preview.gd
## Frames are 15 fps, 24 seconds. Encode the PNG sequence as a GIF or video externally.
const Catalog = preload("res://scripts/level_catalog.gd")
var _out: String = "res://.tools/captures/storm"
var _start: float = 0.0
var _frames: int = 360

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out = argument.substr(6)
		elif argument.begins_with("--start="):
			_start = maxf(0.0, argument.substr(8).to_float())
		elif argument.begins_with("--frames="):
			_frames = clampi(argument.substr(9).to_int(), 1, 900)
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var stage := Node3D.new()
	root.add_child(stage)
	var dummy := Node3D.new()
	stage.add_child(dummy)
	var level: Node3D = Catalog.create("l04")
	stage.add_child(level)
	level.call("build", dummy, false)
	level.set_process(false)
	var material: ShaderMaterial = level.get("_sky_material")
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.far = 1600.0
	camera.fov = 100.0
	camera.position = Vector3(19, 18, 19)
	camera.look_at(Vector3(-3, 33, -55))
	camera.make_current()
	for i in range(8):
		await process_frame
	for frame in range(_frames):
		var seconds: float = _start + float(frame) / 15.0
		material.set_shader_parameter("storm_time", seconds)
		var atmosphere: Node = level.get_node_or_null("DreamAtmosphere")
		if atmosphere != null:
			atmosphere.set_process(false)
			atmosphere.call("_animate", seconds)
		await process_frame
		await RenderingServer.frame_post_draw
		var path: String = "%s/frame_%04d.png" % [_out, frame]
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("STORM CAPTURE: %d frames / 15 fps at %s" % [_frames, _out])
	quit()
