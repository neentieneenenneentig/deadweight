extends Node3D
## The floor is lava (W2). Four kinds of ground danger, built from a level's _design through
## level.traps(), and run here each physics step while the level is active:
##   crack_field  plates (thin ice, old paving) that crack under the player and break after
##                CRACK_TIME, dropping them into whatever is below; a hard landing breaks one at
##                once. Broken plates grow back after REGROW_TIME.
##   mine         a teacup landmine. The player, a hound or the rod's weight within MINE_TRIGGER
##                arms it: it beeps and blinks for MINE_FUSE, then blows. The blast hurts and
##                throws, and it kills hounds, so luring them over a mine works.
##   boulder      a giant marble that waits up a slope until the player enters its trigger box,
##                then rolls. It hurts on contact at speed, flattens hounds, and resets later.
##   flood        water that rises from one height to another once start_flood() is called.
##                Under it the player takes FLOOD_DPS and hounds drown.
## Everything is solid where it looks solid, and nothing here floats text.

const FX = preload("res://scripts/fx.gd")

const CRACK_TIME := 1.4              # seconds from first step to the plate giving way
const REGROW_TIME := 10.0
const HARD_LANDING := 9.0            # m/s: a landing this hard breaks the plate at once
const STAND_HEIGHT := 1.8            # the player centre must be this close above a plate to stand on it

const MINE_TRIGGER := 2.2
const MINE_FUSE := 0.7
const MINE_BLAST := 6.5
const MINE_DAMAGE := 55.0            # at the centre, before damage_scale; falls off to 0 at MINE_BLAST
const MINE_THROW := 14.0             # m/s of launch at the centre
const MINE_ENEMY_DAMAGE := 150.0
const MINE_SCAN := 0.1               # seconds between weight and hound scans

const BOULDER_HIT_SPEED := 4.0       # relative m/s before a boulder hurts
const BOULDER_DAMAGE := 40.0
const BOULDER_LIFETIME := 24.0       # seconds rolling before it resets
const BOULDER_MASS := 3000.0

const FLOOD_DPS := 30.0
const FLOOD_DROWN := 1.5             # seconds under the flood before a hound drowns

var level: Node3D
var _fields: Array[Dictionary] = []
var _mines: Array[Dictionary] = []
var _boulders: Array[Dictionary] = []
var _flood: Dictionary = {}
var _scan_clock: float = 0.0
var _mine_mesh: ArrayMesh
var _mine_armed: StandardMaterial3D
var _mine_idle: StandardMaterial3D
var _connected: bool = false


func setup(owner_level: Node3D) -> void:
	level = owner_level
	name = "Traps"


# --- Builders ------------------------------------------------------------------------------------

## A grid of breakable plates with their tops at center.y. keep(x, z) -> bool may leave tiles out
## (a round lake, say). kind is "ice" or "paving".
func crack_field(center: Vector3, size: Vector2, tile: float, kind: String, keep: Callable = Callable()) -> void:
	var columns: int = maxi(1, int(round(size.x / tile)))
	var rows: int = maxi(1, int(round(size.y / tile)))
	var thickness: float = 0.3 if kind == "ice" else 0.5
	var field := {"center": center, "tile": tile, "columns": columns, "rows": rows, "kind": kind, "cells": {}, "thickness": thickness}
	var shape := BoxShape3D.new()
	shape.size = Vector3(tile - 0.04, thickness, tile - 0.04)
	var origin: Vector2 = Vector2(center.x, center.z) - Vector2(columns, rows) * tile * 0.5
	var placements: Array[Transform3D] = []
	for row in range(rows):
		for column in range(columns):
			var x: float = origin.x + (float(column) + 0.5) * tile
			var z: float = origin.y + (float(row) + 0.5) * tile
			if keep.is_valid() and not bool(keep.call(x, z)):
				continue
			var at := Vector3(x, center.y - thickness * 0.5, z)
			var body := StaticBody3D.new()
			body.position = at
			body.collision_layer = 1
			body.collision_mask = 0
			var collision := CollisionShape3D.new()
			collision.shape = shape
			body.add_child(collision)
			add_child(body)
			var cell := {"body": body, "index": placements.size(), "at": at, "state": 0, "timer": 0.0}
			(field["cells"] as Dictionary)[Vector2i(column, row)] = cell
			placements.append(Transform3D(Basis.from_scale(Vector3(tile - 0.08, thickness, tile - 0.08)), at))
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	var box := BoxMesh.new()
	multi.mesh = box
	multi.instance_count = placements.size()
	for i in range(placements.size()):
		multi.set_instance_transform(i, placements[i])
		multi.set_instance_color(i, _plate_color(kind, 0.0))
	var view := MultiMeshInstance3D.new()
	view.name = "CrackField_" + kind
	view.multimesh = multi
	view.material_override = _plate_material(kind)
	add_child(view)
	field["multimesh"] = multi
	field["placements"] = placements
	_fields.append(field)


func mine(floor_point: Vector3) -> void:
	if _mine_mesh == null:
		_build_mine_assets()
	var view := MeshInstance3D.new()
	view.mesh = _mine_mesh
	view.material_override = _mine_idle
	view.position = floor_point
	view.rotation.y = float(_mines.size()) * 1.7
	add_child(view)
	_mines.append({"at": floor_point, "view": view, "state": 0, "timer": 0.0})


## A marble of radius r waiting at rest_point. Entering trigger (an AABB in level space) releases it
## with an initial push (m/s).
func boulder(rest_point: Vector3, radius: float, trigger: AABB, push: Vector3 = Vector3.ZERO) -> void:
	var body := RigidBody3D.new()
	body.name = "Boulder%d" % _boulders.size()
	body.mass = BOULDER_MASS
	body.collision_layer = 1
	body.collision_mask = 1 | 2 | 8
	body.contact_monitor = true
	body.max_contacts_reported = 6
	body.continuous_cd = true
	body.freeze = true
	body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	var material := PhysicsMaterial.new()
	material.friction = 0.9
	material.bounce = 0.1
	body.physics_material_override = material
	var shape := SphereShape3D.new()
	shape.radius = radius
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	var view := MeshInstance3D.new()
	view.mesh = _marble_mesh(radius)
	var look := StandardMaterial3D.new()
	look.vertex_color_use_as_albedo = true
	look.vertex_color_is_srgb = true
	look.roughness = 0.25
	look.metallic = 0.1
	view.material_override = look
	body.add_child(view)
	body.position = rest_point
	add_child(body)
	var record := {"body": body, "rest": rest_point, "trigger": trigger, "push": push, "state": 0, "timer": 0.0, "cooldown": 0.0}
	body.body_entered.connect(_on_boulder_hit.bind(record))
	_boulders.append(record)


## A flood over area (x/z) that will rise from start_y to end_y at speed m/s once started.
func flood(area: Rect2, start_y: float, end_y: float, speed: float) -> void:
	var view := MeshInstance3D.new()
	view.name = "Flood"
	var plane := PlaneMesh.new()
	plane.size = area.size
	view.mesh = plane
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.36, 0.62, 0.72, 0.78)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.05
	water.metallic = 0.2
	view.material_override = water
	view.position = Vector3(area.get_center().x, start_y, area.get_center().y)
	view.visible = false
	add_child(view)
	_flood = {"area": area, "y": start_y, "end": end_y, "speed": speed, "running": false, "view": view, "under": {}}


func start_flood() -> void:
	if _flood.is_empty() or bool(_flood["running"]):
		return
	_flood["running"] = true
	(_flood["view"] as MeshInstance3D).visible = true
	level.emit_signal("hint_requested", "THE MELTWATER IS RISING  /  get high and stay high", 6.0)


## Current flood height, or -INF before it starts.
func flood_level() -> float:
	if _flood.is_empty() or not bool(_flood["running"]):
		return -INF
	return float(_flood["y"])


# --- Runtime -------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if level == null or not bool(level.get("_active")):
		return
	var player: Node3D = level.get("_player")
	if not is_instance_valid(player):
		return
	if not _connected and player.has_signal("landed"):
		player.connect("landed", _on_player_landed)
		_connected = true
	_update_fields(player, delta)
	_update_mines(player, delta)
	_update_boulders(player, delta)
	_update_flood(player, delta)


func _cell_under(field: Dictionary, point: Vector3) -> Dictionary:
	var center: Vector3 = field["center"]
	var tile: float = field["tile"]
	var origin: Vector2 = Vector2(center.x, center.z) - Vector2(int(field["columns"]), int(field["rows"])) * tile * 0.5
	var key := Vector2i(int(floor((point.x - origin.x) / tile)), int(floor((point.z - origin.y) / tile)))
	var cells: Dictionary = field["cells"]
	if not cells.has(key):
		return {}
	var height: float = point.y - center.y
	if height < -0.4 or height > STAND_HEIGHT:
		return {}
	return cells[key]


func _update_fields(player: Node3D, delta: float) -> void:
	var grounded: bool = bool(player.get("grounded"))
	for field: Dictionary in _fields:
		if grounded:
			var under: Dictionary = _cell_under(field, player.global_position)
			if not under.is_empty() and int(under["state"]) == 0:
				_start_crack(field, under)
		for cell: Dictionary in (field["cells"] as Dictionary).values():
			match int(cell["state"]):
				1:
					cell["timer"] = float(cell["timer"]) - delta
					var shake: float = 1.0 - float(cell["timer"]) / CRACK_TIME
					var multi: MultiMesh = field["multimesh"]
					multi.set_instance_color(int(cell["index"]), _plate_color(str(field["kind"]), shake))
					if float(cell["timer"]) <= 0.0:
						_break(field, cell)
				2:
					cell["timer"] = float(cell["timer"]) - delta
					if float(cell["timer"]) <= 0.0 and not _player_over(player, cell, float(field["tile"])):
						_restore(field, cell)


func _start_crack(field: Dictionary, cell: Dictionary) -> void:
	cell["state"] = 1
	cell["timer"] = CRACK_TIME
	_sound("weight_impact", cell["at"], -8.0)


func _break(field: Dictionary, cell: Dictionary) -> void:
	cell["state"] = 2
	cell["timer"] = REGROW_TIME
	(cell["body"] as StaticBody3D).collision_layer = 0
	var multi: MultiMesh = field["multimesh"]
	multi.set_instance_transform(int(cell["index"]), Transform3D(Basis.from_scale(Vector3.ONE * 0.001), cell["at"]))
	var color: Color = _plate_color(str(field["kind"]), 0.0)
	FX.burst(level, cell["at"], Vector3.UP, color, 18, 5.0, 0.6, 0.12)
	_sound("splash" if str(field["kind"]) == "ice" else "weight_impact", cell["at"])


func _restore(field: Dictionary, cell: Dictionary) -> void:
	cell["state"] = 0
	(cell["body"] as StaticBody3D).collision_layer = 1
	var multi: MultiMesh = field["multimesh"]
	multi.set_instance_transform(int(cell["index"]), (field["placements"] as Array)[int(cell["index"])])
	multi.set_instance_color(int(cell["index"]), _plate_color(str(field["kind"]), 0.0))


func _player_over(player: Node3D, cell: Dictionary, tile: float) -> bool:
	var at: Vector3 = cell["at"]
	return absf(player.global_position.x - at.x) < tile * 0.7 and absf(player.global_position.z - at.z) < tile * 0.7


## A hard landing on a plate breaks it on the spot and sets the ones around it cracking.
func _on_player_landed(impact: float) -> void:
	if impact < HARD_LANDING or not is_instance_valid(level):
		return
	var player: Node3D = level.get("_player")
	for field: Dictionary in _fields:
		var under: Dictionary = _cell_under(field, player.global_position)
		if under.is_empty() or int(under["state"]) == 2:
			continue
		_break(field, under)
		var tile: float = field["tile"]
		for cell: Dictionary in (field["cells"] as Dictionary).values():
			if int(cell["state"]) == 0 and (cell["at"] as Vector3).distance_to(under["at"]) < tile * 1.6:
				_start_crack(field, cell)


func _update_mines(player: Node3D, delta: float) -> void:
	_scan_clock -= delta
	var scan: bool = _scan_clock <= 0.0
	if scan:
		_scan_clock = MINE_SCAN
	for record: Dictionary in _mines:
		match int(record["state"]):
			0:
				var at: Vector3 = record["at"]
				var near: bool = player.global_position.distance_to(at + Vector3.UP * 0.9) < MINE_TRIGGER
				if not near and scan:
					near = _something_near(at, MINE_TRIGGER)
				if near:
					record["state"] = 1
					record["timer"] = MINE_FUSE
					_sound("sentry_charge", at)
			1:
				record["timer"] = float(record["timer"]) - delta
				var view: MeshInstance3D = record["view"]
				view.material_override = _mine_armed if fmod(float(record["timer"]), 0.16) < 0.08 else _mine_idle
				if float(record["timer"]) <= 0.0:
					_blow(record, player)


## True when the rod's weight (layer 4) or a hound (layer 8) is within radius of point.
func _something_near(point: Vector3, radius: float) -> bool:
	var ball := SphereShape3D.new()
	ball.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = ball
	query.transform = Transform3D(Basis.IDENTITY, point + Vector3.UP * 0.6)
	query.collision_mask = 4 | 8
	return not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _blow(record: Dictionary, player: Node3D) -> void:
	record["state"] = 2
	var at: Vector3 = record["at"]
	(record["view"] as MeshInstance3D).visible = false
	FX.explosion(level, at + Vector3.UP * 0.4, Color("ffb347"), 1.6)
	_sound("drone_shot", at, 4.0)
	var offset: Vector3 = player.global_position - at
	var distance: float = offset.length()
	if distance < MINE_BLAST:
		var falloff: float = 1.0 - distance / MINE_BLAST
		player.call("take_damage", MINE_DAMAGE * falloff * float(level.get("damage_scale")), "mine", at)
		var away: Vector3 = Vector3(offset.x, 0.0, offset.z).normalized() * 0.5 + Vector3.UP
		if player is RigidBody3D:
			var body := player as RigidBody3D
			body.linear_velocity += away.normalized() * MINE_THROW * falloff
		if player.has_method("add_shake"):
			player.call("add_shake", 0.7 * falloff)
	for hostile: Node in (level.get("_enemies") as Array):
		if is_instance_valid(hostile) and (hostile as Node3D).global_position.distance_to(at) < MINE_BLAST:
			hostile.call("take_damage", MINE_ENEMY_DAMAGE, "mine")


func _update_boulders(player: Node3D, delta: float) -> void:
	for record: Dictionary in _boulders:
		var body: RigidBody3D = record["body"]
		record["cooldown"] = maxf(0.0, float(record["cooldown"]) - delta)
		match int(record["state"]):
			0:
				if (record["trigger"] as AABB).has_point(player.global_position):
					record["state"] = 1
					record["timer"] = BOULDER_LIFETIME
					body.freeze = false
					body.linear_velocity = record["push"]
					level.emit_signal("hint_requested", "BOULDER  /  get off the slope", 3.0)
					_sound("weight_impact", body.global_position, 6.0)
			1:
				record["timer"] = float(record["timer"]) - delta
				if float(record["timer"]) <= 0.0 or body.global_position.y < float(level.get("kill_y")):
					_reset_boulder(record)
			2:
				# Waiting to re-arm until the player has left the trigger.
				if not (record["trigger"] as AABB).has_point(player.global_position):
					record["state"] = 0


func _reset_boulder(record: Dictionary) -> void:
	var body: RigidBody3D = record["body"]
	body.freeze = true
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.global_position = record["rest"]
	record["state"] = 2


func _on_boulder_hit(other: Node, record: Dictionary) -> void:
	var body: RigidBody3D = record["body"]
	if int(record["state"]) != 1 or float(record["cooldown"]) > 0.0:
		return
	var other_velocity: Vector3 = (other as RigidBody3D).linear_velocity if other is RigidBody3D else Vector3.ZERO
	if other is CharacterBody3D:
		other_velocity = (other as CharacterBody3D).velocity
	var speed: float = (body.linear_velocity - other_velocity).length()
	if speed < BOULDER_HIT_SPEED:
		return
	if other == level.get("_player"):
		record["cooldown"] = 0.8
		other.call("take_damage", BOULDER_DAMAGE * float(level.get("damage_scale")), "boulder", body.global_position)
		if other.has_method("add_shake"):
			other.call("add_shake", 0.8)
	elif other.is_in_group("enemies"):
		other.call("take_damage", 500.0, "boulder")


func _update_flood(player: Node3D, delta: float) -> void:
	if _flood.is_empty() or not bool(_flood["running"]):
		return
	var y: float = minf(float(_flood["end"]), float(_flood["y"]) + float(_flood["speed"]) * delta)
	_flood["y"] = y
	(_flood["view"] as MeshInstance3D).position.y = y
	var area: Rect2 = _flood["area"]
	if player.global_position.y < y - 0.3 and area.has_point(Vector2(player.global_position.x, player.global_position.z)):
		player.call("take_damage", FLOOD_DPS * float(level.get("damage_scale")) * delta, "flood", Vector3.INF)
	var under: Dictionary = _flood["under"]
	for hostile: Node in (level.get("_enemies") as Array):
		if not is_instance_valid(hostile):
			continue
		var below: bool = (hostile as Node3D).global_position.y + 0.6 < y
		var time: float = float(under.get(hostile.get_instance_id(), 0.0))
		time = time + delta if below else 0.0
		under[hostile.get_instance_id()] = time
		if time >= FLOOD_DROWN:
			hostile.call("take_damage", 1000.0, "flood")
			under[hostile.get_instance_id()] = -1000.0


# --- Looks and sounds ----------------------------------------------------------------------------

func _plate_color(kind: String, crack: float) -> Color:
	var base: Color = Color("cfeaf5") if kind == "ice" else Color("cbbfa4")
	var warn: Color = Color("ffffff") if kind == "ice" else Color("8a5a3c")
	var flicker: float = 0.5 + 0.5 * sin(crack * 40.0)
	return base.lerp(warn, clampf(crack * (0.6 + 0.4 * flicker), 0.0, 1.0))


func _plate_material(kind: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	if kind == "ice":
		material.albedo_color = Color(1, 1, 1, 0.82)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.roughness = 0.08
		material.metallic = 0.2
	else:
		material.roughness = 0.9
	return material


func _build_mine_assets() -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var saucer := CylinderMesh.new()
	saucer.top_radius = 0.55
	saucer.bottom_radius = 0.45
	saucer.height = 0.06
	saucer.radial_segments = 14
	_append(tool, saucer, Transform3D(Basis.IDENTITY, Vector3(0, 0.03, 0)), Color("f4efe4"))
	var cup := CylinderMesh.new()
	cup.top_radius = 0.34
	cup.bottom_radius = 0.24
	cup.height = 0.32
	cup.radial_segments = 14
	_append(tool, cup, Transform3D(Basis.IDENTITY, Vector3(0, 0.22, 0)), Color("f4efe4"))
	var handle := TorusMesh.new()
	handle.inner_radius = 0.07
	handle.outer_radius = 0.12
	handle.rings = 10
	handle.ring_segments = 6
	_append(tool, handle, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.38, 0.24, 0)), Color("f4efe4"))
	var fuse := SphereMesh.new()
	fuse.radius = 0.08
	fuse.height = 0.16
	fuse.radial_segments = 8
	fuse.rings = 4
	_append(tool, fuse, Transform3D(Basis.IDENTITY, Vector3(0, 0.4, 0)), Color("d9403a"))
	_mine_mesh = tool.commit()
	_mine_idle = StandardMaterial3D.new()
	_mine_idle.vertex_color_use_as_albedo = true
	_mine_idle.vertex_color_is_srgb = true
	_mine_idle.roughness = 0.3
	_mine_armed = _mine_idle.duplicate() as StandardMaterial3D
	_mine_armed.emission_enabled = true
	_mine_armed.emission = Color("ff3b2f")
	_mine_armed.emission_energy_multiplier = 2.5


## A sphere with coloured bands, so a rolling marble visibly turns.
func _marble_mesh(radius: float) -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 18
	sphere.rings = 10
	var arrays: Array = sphere.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors := PackedColorArray()
	colors.resize(vertices.size())
	for i in range(vertices.size()):
		var v: Vector3 = vertices[i] / radius
		var band: float = sin(atan2(v.z, v.x) * 3.0 + v.y * 4.0)
		colors[i] = Color("4aa3c9").lerp(Color("f2e6c8"), 0.5 + 0.5 * band)
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _append(tool: SurfaceTool, mesh: PrimitiveMesh, placement: Transform3D, color: Color) -> void:
	var arrays: Array = mesh.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for index: int in indices:
		tool.set_color(color)
		tool.set_normal((placement.basis * normals[index]).normalized())
		tool.add_vertex(placement * vertices[index])


func _sound(event: String, at: Vector3, volume_db: float = 0.0) -> void:
	var audio: Node = get_tree().get_first_node_in_group("game_audio")
	if is_instance_valid(audio) and audio.has_method("play_at"):
		audio.call("play_at", event, at, volume_db)
