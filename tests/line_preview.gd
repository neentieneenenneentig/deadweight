extends SceneTree
## Off-screen gameplay captures of the line and weight (G4). Never loads or writes the player's profile.
## Run with --position 20000,20000 --resolution 1280x720; add --rendering-method gl_compatibility for the
## mobile renderer. Captures land in .tools/captures/G4/ as <shot>_<renderer>.png. Viewmodel shots live in
## tests/gameplay_preview.gd (G5).
##   godot --path . --position 20000,20000 --resolution 1280x720 --script res://tests/line_preview.gd
const Catalog = preload("res://scripts/level_catalog.gd")
const Player = preload("res://scripts/player.gd")
const TetherScript = preload("res://scripts/tether.gd")

var _out: String = "res://.tools/captures/G4"
var _quality: int = 2


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out = argument.substr(6)
		elif argument.begins_with("--quality="):
			_quality = clampi(argument.substr(10).to_int(), 0, 2)
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var stage := Node3D.new()
	root.add_child(stage)
	var player := Player.new()
	stage.add_child(player)
	player.freeze = true
	var level: Node3D = Catalog.create("l01")
	stage.add_child(level)
	level.set("quality", _quality)
	level.call("build", player, true)
	player.position = level.get("spawn_position")
	player.camera.far = 1000.0
	player.camera.make_current()
	var tether: Node3D = TetherScript.new()
	stage.add_child(tether)
	tether.bind(player)
	tether.active = true
	var overlook := Camera3D.new()
	overlook.far = 1000.0
	overlook.fov = 60.0
	stage.add_child(overlook)
	for i in range(30):
		await process_frame
	var rod: Vector3 = player.rod_tip.global_position
	# The physics measures the line from the player's origin, so stretch is set against that point.
	var origin: Vector3 = player.global_position

	# Slack: a weight in front, the line held locked with 2.5 m spare, so it sags.
	_attach_weight(tether, stage, rod + Vector3(-1.0, -1.0, -5.0))
	tether.locked = true
	tether.line_length = rod.distance_to(tether.weight.global_position) + 2.5
	_look(overlook, rod + Vector3(2.8, 1.2, 2.6), rod + Vector3(-0.6, -0.6, -2.5))
	await _settle(overlook, 6)
	_report("slack_wide", tether)
	await _capture("slack_wide")
	_look(overlook, rod + Vector3(0.9, 0.5, 1.4), rod + Vector3(-0.9, -0.7, -2.2))
	await _settle(overlook, 4)
	await _capture("slack_close")
	_clear(tether)
	await process_frame

	# Taut: a frozen weight 0.6 m past the line length, so the line holds at about 7200 N (fully amber).
	var swing: RigidBody3D = _attach_weight(tether, stage, rod + Vector3(2.5, -0.6, -6.0))
	tether.locked = true
	tether.line_length = origin.distance_to(swing.global_position) - 0.6
	_look(overlook, rod + Vector3(3.2, 1.0, 3.0), rod + Vector3(1.0, -0.6, -3.0))
	await _settle(overlook, 6)
	_report("taut_swing", tether)
	await _capture("taut_swing")
	_clear(tether)
	await process_frame

	# Wrapped: a chalk wall stands between the rod and the weight, so the line bends around its right corner.
	var wall := _wall(stage, rod + Vector3(-1.8, -0.5, -3.0), Vector3(4.4, 5.0, 0.4))
	var behind: RigidBody3D = _attach_weight(tether, stage, rod + Vector3(-3.0, -0.5, -6.0))
	tether.locked = true
	tether.line_length = origin.distance_to(behind.global_position) + 3.0
	_look(overlook, rod + Vector3(-7.0, 2.6, -0.5), rod + Vector3(-1.6, -0.6, -3.6))
	await _settle(overlook, 8)
	_report("wrapped", tether)
	await _capture("wrapped")
	_clear(tether)
	wall.queue_free()
	await process_frame

	# Near max: the line stretched 1.6 m past its length, so tension sits near 19200 N (about 87 % of MAX_TENSION).
	var stretched: RigidBody3D = _attach_weight(tether, stage, rod + Vector3(0.5, -0.4, -6.5))
	stretched.freeze = true
	tether.locked = true
	tether.line_length = origin.distance_to(stretched.global_position) - 1.6
	_look(overlook, rod + Vector3(1.1, 0.9, 1.6), rod + Vector3(0.1, -0.3, -3.0))
	await _settle(overlook, 6)
	_report("near_max", tether)
	await _capture("near_max_close")
	_look(overlook, rod + Vector3(2.4, 1.0, 2.2), rod + Vector3(0.0, -0.3, -3.0))
	await _settle(overlook, 4)
	await _capture("near_max")
	_clear(tether)
	await process_frame

	# Speed trail: a full-power cast through the real cast path, captured while the weight is still flying.
	var cast_from: Vector3 = player.camera.global_position
	_look(overlook, cast_from + Vector3(4.5, 0.4, -3.5), cast_from + Vector3(0.0, 0.0, -5.0))
	tether.charging = true
	tether.charge = 1.0
	tether.release_cast()
	for i in range(6):
		await process_frame
	await create_timer(0.09).timeout
	await _settle(overlook, 2)
	_report("weight_trail", tether)
	await _capture("weight_trail")
	_clear(tether)
	await process_frame

	stage.queue_free()
	await process_frame
	quit()


## A weight built by the tether's own factory, placed and parked: frozen unless the caller unfreezes it.
func _attach_weight(tether: Node3D, stage: Node3D, at: Vector3) -> RigidBody3D:
	var body: RigidBody3D = tether.call("_build_weight") as RigidBody3D
	stage.add_child(body)
	body.global_position = at
	body.freeze = true
	tether.set("weight", body)
	tether.set("active", true)
	return body


## Chalk wall on the world layer, so the tether's ray tests see it.
func _wall(stage: Node3D, centre: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("d6c9b0")
	material.roughness = 0.9
	visual.material_override = material
	body.add_child(visual)
	body.position = centre
	stage.add_child(body)
	return body


## Clears the weight and any loose weights so the next shot starts from nothing.
func _clear(tether: Node3D) -> void:
	tether.call("clear")
	tether.set("locked", false)
	tether.set("line_length", 0.0)


func _look(camera: Camera3D, eye: Vector3, target: Vector3) -> void:
	camera.global_position = eye
	camera.look_at(target)
	camera.make_current()


## Lets physics and the line visuals run for a few frames before a capture.
func _settle(_camera: Camera3D, frames: int) -> void:
	for i in range(frames):
		await process_frame


func _report(shot: String, tether: Node3D) -> void:
	print("STATE %s: %s tension=%.0f wraps=%d line=%.2f" % [shot, tether.call("state_name"), float(tether.get("tension")), (tether.call("get_wrap_points") as PackedVector3Array).size(), float(tether.get("line_length"))])


func _capture(shot: String) -> void:
	await RenderingServer.frame_post_draw
	var path: String = "%s/%s_%s.png" % [_out, shot, RenderingServer.get_current_rendering_method()]
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("CAPTURE " + path)
