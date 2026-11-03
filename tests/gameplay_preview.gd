extends SceneTree
## Captures the viewmodel (rod and sidearm) for review. It builds the real player over a plain floor
## with one wall, then for each shot sets the viewmodel state the way main does every frame, waits
## for the eases to settle and saves a PNG. The file name carries the renderer, so both runs can share
## one folder. Run windowed but off-screen:
##   godot --path . --position 20000,20000 --resolution 1280x720 --script res://tests/gameplay_preview.gd
## Add --rendering-method gl_compatibility to preview the mobile renderer.
## Options after "--": --out=<res:// folder> (default res://.tools/captures/G5).

const Player = preload("res://scripts/player.gd")
## Frames given to each shot so the eases (pose, bend, cast spring, clearance) settle.
const SETTLE_FRAMES: int = 45
## Frames after the cast release before the whip is captured, so the spring is mid-swing.
const WHIP_FRAMES: int = 5

var _out: String = "res://.tools/captures/G5"
var _player: RigidBody3D
var _wall: StaticBody3D


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out = argument.substr(6)
	_run.call_deferred()


func _run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	_build_stage(scene)
	for i in range(5):
		await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var renderer: String = RenderingServer.get_current_rendering_method()
	var saved: Array[String] = []
	for shot: Dictionary in _shots():
		_set_wall(bool(shot["wall"]))
		await _hold(shot["weapon"], float(shot["charge"]), float(shot["tension"]), float(shot["line"]), SETTLE_FRAMES)
		if bool(shot.get("cast", false)):
			# Release the charge the way main does: the charge drops to zero, the cast fires.
			await _hold(shot["weapon"], 0.0, float(shot["tension"]), float(shot["line"]), WHIP_FRAMES)
		saved.append(_capture(str(shot["name"]), renderer))
	print("PREVIEW G5 viewmodel, renderer %s" % renderer)
	for path: String in saved:
		print("  saved " + ProjectSettings.globalize_path(path))
	quit(0)


## Floor, one wall (shown only for the wall shots), a sun and the real player standing still.
func _build_stage(scene: Node3D) -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("14282f")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8fa19c")
	environment.ambient_light_energy = 0.6
	world.environment = environment
	scene.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 35.0, 0.0)
	sun.light_energy = 1.1
	scene.add_child(sun)
	scene.add_child(_static_box(Vector3(60.0, 1.0, 60.0), Vector3(0.0, -0.5, 0.0), Color("647371")))
	_wall = _static_box(Vector3(8.0, 4.0, 0.4), Vector3(0.0, 2.0, -1.5), Color("81513b"))
	scene.add_child(_wall)
	_set_wall(false)
	_player = Player.new()
	scene.add_child(_player)
	_player.global_position = Vector3(0.0, 0.9, 0.0)
	# Frozen so the capsule stays put; the viewmodel reads only the state set here.
	_player.freeze = true


func _static_box(size: Vector3, at: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	var mesh_node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_node.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh_node.material_override = material
	body.add_child(mesh_node)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	return body


## The wall is both visible and solid only in the wall shots; otherwise it has no collision layer.
func _set_wall(on: bool) -> void:
	_wall.visible = on
	_wall.collision_layer = 1 if on else 0


## Each shot: the weapon, charge, tension, line speed (metres per second, drives the spool), and
## whether the rod casts after settling (charge released, whip captured).
func _shots() -> Array[Dictionary]:
	return [
		{"name": "idle", "weapon": "ROD", "charge": 0.0, "tension": 0.0, "line": 0.0, "wall": false},
		{"name": "charging", "weapon": "ROD", "charge": 0.7, "tension": 0.0, "line": 0.0, "wall": false},
		{"name": "taut_flight", "weapon": "ROD", "charge": 0.0, "tension": 19000.0, "line": 9.0, "wall": false},
		{"name": "cast_whip", "weapon": "ROD", "charge": 0.8, "tension": 0.0, "line": 0.0, "wall": false, "cast": true},
		{"name": "sidearm", "weapon": "SIDEARM", "charge": 0.0, "tension": 0.0, "line": 0.0, "wall": false},
		{"name": "wall_rod", "weapon": "ROD", "charge": 0.0, "tension": 0.0, "line": 0.0, "wall": true},
		{"name": "wall_sidearm", "weapon": "SIDEARM", "charge": 0.0, "tension": 0.0, "line": 0.0, "wall": true},
	]


## Sets the viewmodel state every frame, as main does, for the given number of frames.
func _hold(weapon: String, charge: float, tension: float, line: float, frames: int) -> void:
	for i in range(frames):
		_player.set_feedback(charge, tension, weapon, line)
		await process_frame


func _capture(shot_name: String, renderer: String) -> String:
	var image: Image = root.get_texture().get_image()
	var path: String = "%s/%s_%s.png" % [_out, shot_name, renderer]
	image.save_png(ProjectSettings.globalize_path(path))
	return path
