extends SceneTree
## Captures a level for review: the spawn view and three overviews, plus draw-call numbers.
## Run windowed but off-screen so nothing pops up on the monitor:
##   godot --path . --position 20000,20000 --resolution 1280x720 --script res://tests/level_preview.gd -- --level=l01
## Options after "--": --level=<id> (default l01), --legacy (build scripts/world.gd instead, for the
## draw-call comparison), --tag=<text> (added to the file names), --out=<folder>.
## Add --rendering-method gl_compatibility to preview the mobile renderer.

const Catalog = preload("res://scripts/level_catalog.gd")
const LegacyWorld = preload("res://scripts/world.gd")

var _level_id: String = "l01"
var _legacy: bool = false
var _tag: String = ""
var _out: String = "res://.tools/captures/F7"


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--level="):
			_level_id = argument.substr(8)
		elif argument == "--legacy":
			_legacy = true
		elif argument.begins_with("--tag="):
			_tag = argument.substr(6)
		elif argument.begins_with("--out="):
			_out = argument.substr(6)
	_run.call_deferred()


func _run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var dummy := Node3D.new()
	scene.add_child(dummy)
	var level: Node3D
	var build_start: int = Time.get_ticks_msec()
	if _legacy:
		level = LegacyWorld.new()
	else:
		level = Catalog.create(_level_id)
	if level == null:
		push_error("No level script for '%s'." % _level_id)
		quit(1)
		return
	scene.add_child(level)
	level.call("build", dummy, false)
	var build_ms: int = Time.get_ticks_msec() - build_start
	var spawn: Vector3 = level.get("spawn_position")
	var yaw: float = level.get("spawn_yaw") if not _legacy else 0.0
	var extraction: Vector3 = level.get("extraction_position")
	dummy.global_position = spawn
	var camera := Camera3D.new()
	camera.fov = 78.0
	camera.far = 600.0
	scene.add_child(camera)
	camera.make_current()
	var name_part: String = ("legacy" if _legacy else _level_id) + (("_" + _tag) if not _tag.is_empty() else "")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var midpoint: Vector3 = (spawn + extraction) * 0.5
	var span: float = maxf(spawn.distance_to(extraction), 40.0)
	var shots := [
		["spawn", spawn + Vector3(0, 0.7, 0), spawn + Vector3(0, 0.7, 0) + Vector3(-sin(yaw), 0.05, -cos(yaw)) * 20.0],
		["overview_high", midpoint + Vector3(0, span * 0.45, span * 0.55), midpoint],
		["overview_side", midpoint + Vector3(span * 0.7, span * 0.22, 0), midpoint],
		["overview_extraction", extraction + Vector3(-12, 9, 22), extraction + Vector3(0, 1.5, 0)],
	]
	var calls: Array[String] = []
	for shot: Array in shots:
		camera.global_position = shot[1]
		camera.look_at(shot[2], Vector3.UP)
		for i in range(8):
			await process_frame
		var draw_calls: int = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		var primitives: int = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
		calls.append("%s: %d draw calls, %d triangles" % [shot[0], draw_calls, primitives])
		var image: Image = root.get_texture().get_image()
		var path: String = "%s/%s_%s.png" % [_out, name_part, shot[0]]
		image.save_png(ProjectSettings.globalize_path(path))
	print("PREVIEW %s (%s): built in %d ms, renderer %s" % [name_part, "legacy world.gd" if _legacy else "level framework", build_ms, RenderingServer.get_current_rendering_method()])
	for line: String in calls:
		print("  " + line)
	quit(0)
