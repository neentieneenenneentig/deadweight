extends Node3D

signal loot_collected(value: int)
signal extraction_changed(inside: bool)
signal threat_changed(text: String)

const EnemyScript = preload("res://scripts/enemy.gd")

var spawn_position := Vector3(0, 2, 14)
var extraction_position := Vector3(16, 0, -116)
var total_loot: int = 3
var _player: Node3D
var _active: bool = false
var _practice: bool = false
var _inside_extraction: bool = false
var _clock: float = 0.0
var _loot: Array[Dictionary] = []
var _enemies: Array[Node] = []
var _materials: Dictionary = {}
var _extract_ring: MeshInstance3D
var _collect_flash: Array[MeshInstance3D] = []


func build(player: Node3D, practice: bool = false) -> void:
	_player = player
	_practice = practice
	_materials = {
		"concrete": _material(Color("35484a")),
		"light_concrete": _material(Color("647371")),
		"dark": _material(Color("14282f")),
		"rust": _material(Color("81513b")),
		"yellow": _material(Color("d8a84e")),
		"stripe": _material(Color("25383b")),
		"cyan": _material(Color("5ad6c8"), true),
		"amber": _material(Color("ffc46b"), true),
		"red": _material(Color("ef654e"), true),
		"water": _material(Color("193e48")),
		"white": _material(Color("c5d0bc")),
	}
	_build_environment()
	_build_ground()
	_build_entrance()
	_build_pump_house()
	_build_gantry()
	_build_relay_yard()
	_build_extraction()
	_build_dressing()
	_add_loot(Vector3(-15, 2.4, -18), "01 / PUMP HOUSE")
	_add_loot(Vector3(14, 5.0, -54), "02 / HIGH GANTRY")
	_add_loot(Vector3(-13, 0, -91), "03 / RELAY YARD")
	if not practice:
		_spawn_enemy("hound", Vector3(8, 0.1, -26))
		_spawn_enemy("hound", Vector3(-7, 0.1, -61))
		_spawn_enemy("hound", Vector3(6, 0.1, -96))
		_spawn_enemy("sentry", Vector3(-22, 3.6, -46))
		_spawn_enemy("sentry", Vector3(22, 2.8, -83))


func set_active(value: bool) -> void:
	_active = value
	for enemy in _enemies:
		if is_instance_valid(enemy):
			enemy.call("set_active", value)
	if not value and _inside_extraction:
		_inside_extraction = false
		extraction_changed.emit(false)


func _build_environment() -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("193b4a")
	sky_material.sky_horizon_color = Color("b6aa8e")
	sky_material.ground_bottom_color = Color("172d34")
	sky_material.ground_horizon_color = Color("9ba58e")
	sky_material.sun_angle_max = 8.0
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("a8c8cd")
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("536e72")
	environment.fog_light_energy = 0.65
	environment.fog_density = 0.0035
	environment_node.environment = environment
	add_child(environment_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-32, -24, 0)
	sun.light_color = Color("ffd5a2")
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)


func _build_ground() -> void:
	_box(Vector3(0, -0.6, -53), Vector3(58, 1.2, 158), "concrete", true)
	# Drainage channels are shallow, giving low cover without unavoidable death pits.
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 26, 0.025, -50), Vector3(2.8, 0.035, 144), "water")
		_box(Vector3(side * 29, 3.0, -52), Vector3(1.2, 6.0, 160), "dark", true)
		for z in range(18, -130, -12):
			_box(Vector3(side * 28.2, 3.1, float(z)), Vector3(1.1, 6.2, 1.2), "light_concrete", true)
			_box(Vector3(side * 27.48, 2.0, float(z)), Vector3(0.06, 0.18, 1.5), "amber")
	_box(Vector3(0, 3, 26), Vector3(58, 6, 1.3), "dark", true)
	_box(Vector3(0, 5, -132), Vector3(58, 10, 1.3), "dark", true)
	# Long route seams and lane markings anchor the sensation of speed.
	for z in range(16, -125, -5):
		_box(Vector3(0, 0.018, float(z)), Vector3(0.15, 0.025, 2.3), "yellow")
		_box(Vector3(-5.8, 0.012, float(z)), Vector3(0.035, 0.02, 4.9), "dark")
		_box(Vector3(5.8, 0.012, float(z)), Vector3(0.035, 0.02, 4.9), "dark")
	for z in [-4.0, -36.0, -73.0, -108.0]:
		_box(Vector3(0, 0.035, z), Vector3(43, 0.05, 0.22), "yellow")
		for x in range(-20, 21, 2):
			_box(Vector3(float(x), 0.045, z - 0.8), Vector3(0.8, 0.06, 1.0), "yellow")


func _build_entrance() -> void:
	# A heavy entrance frame silhouettes the first launch and establishes the title.
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 8.5, 5.5, 8), Vector3(1.5, 11, 2), "rust", true)
	_box(Vector3(0, 10.4, 8), Vector3(18.5, 1.8, 2), "rust", true)
	_box(Vector3(0, 10.3, 9.04), Vector3(15.2, 1.2, 0.1), "dark")
	_label("D E A D W E I G H T", Vector3(0, 10.3, 9.12), 56, Color("e0cda6"), 0.012)
	_label("FLOODWORKS  /  QUARANTINE SECTOR 09", Vector3(0, 8.7, 8.9), 26, Color("ffc46b"), 0.011)
	_sign("01   PUMP HOUSE", Vector3(-10, 2.1, -2), "SALVAGE SIGNAL   /   LEFT RAMP")
	_sign("KEEP MOVING", Vector3(10, 2.1, 2), "CHARGE > CAST > LOCK > REEL")
	for side in [-1.0, 1.0]:
		_crate(Vector3(side * 13.0, 0, 11), Vector3(3.0, 2.3, 3.0))
		_crate(Vector3(side * 18.0, 0, 2), Vector3(4.8, 2.9, 3.4))
		_barrier(Vector3(side * 5.5, 0, -8), 4.0)
	# A safe launch target makes the first movement experiment readable.
	_label("CAST ABOVE THE GATE", Vector3(0, 6.7, -12), 34, Color("5ad6c8"), 0.014, true)


func _build_pump_house() -> void:
	_box(Vector3(-15, 1.1, -19), Vector3(15, 2.2, 14), "dark", true)
	_box(Vector3(-15, 2.3, -19), Vector3(15.4, 0.2, 14.4), "light_concrete", true)
	_ramp(Vector3(-15, 0, 2), Vector3(-15, 2.4, -12), 5.5)
	for x in [-21.0, -9.0]:
		_box(Vector3(x, 4.4, -24), Vector3(0.45, 4.0, 0.45), "rust", true)
	_box(Vector3(-15, 6.3, -24), Vector3(13, 0.45, 0.6), "rust", true)
	_box(Vector3(-21.7, 3.1, -20), Vector3(0.35, 1.4, 10), "rust", true)
	_box(Vector3(-15, 3.3, -25.8), Vector3(14.2, 1.8, 0.35), "rust", true)
	for x in [-19.0, -11.0]:
		_cylinder(Vector3(x, 3.1, -23), 0.65, 1.4, "yellow", true)
	_label("P U M P  /  0 1", Vector3(-15, 4.5, -25.5), 36, Color("dce0c9"), 0.018)
	_box(Vector3(9, 2.5, -21), Vector3(9, 5, 10), "rust", true)
	for y in [1.2, 2.4, 3.6]:
		_box(Vector3(9, y, -15.95), Vector3(8.2, 0.05, 0.04), "yellow")
	_label("C-09", Vector3(9, 3, -15.88), 58, Color("e8bc72"), 0.025)
	_barrier(Vector3(0, 0, -24), 5.0)
	_crate(Vector3(19, 0, -31), Vector3(6, 3, 4))
	_sign("02   HIGH GANTRY", Vector3(6, 2.1, -33), "LOOK UP   /   CAST OVER COVER")


func _build_gantry() -> void:
	# Tall traversal landmark with an accessible long ramp along the right edge.
	for x in [-16.0, 14.0]:
		for z in [-48.0, -60.0]:
			_box(Vector3(x, 4, z), Vector3(0.9, 8, 0.9), "rust", true)
	_box(Vector3(0, 7.5, -49), Vector3(32, 0.8, 1), "rust", true)
	_box(Vector3(0, 7.5, -59), Vector3(32, 0.8, 1), "rust", true)
	_box(Vector3(14, 4.7, -54), Vector3(9, 0.6, 15), "dark", true)
	_box(Vector3(14, 5.02, -54), Vector3(9.4, 0.06, 15.4), "light_concrete")
	_ramp(Vector3(21, 0, -28), Vector3(21, 5.0, -49), 4.5)
	_box(Vector3(18.7, 4.72, -50), Vector3(5, 0.56, 4), "dark", true)
	_box(Vector3(0, 4.7, -59), Vector3(25, 0.6, 4), "dark", true)
	for x in range(-12, 19, 3):
		_box(Vector3(float(x), 5.6, -61), Vector3(0.1, 1.2, 0.1), "yellow", true)
	_box(Vector3(1, 6.15, -61), Vector3(28, 0.12, 0.12), "yellow", true)
	_box(Vector3(18.5, 5.7, -56), Vector3(0.2, 1.4, 10), "rust", true)
	_box(Vector3(14, 5.6, -61.2), Vector3(9, 1.2, 0.2), "rust", true)
	_label("GANTRY  /  02", Vector3(1, 6.7, -48.4), 45, Color("e8d6a8"), 0.018)
	_box(Vector3(-22, 1.8, -46), Vector3(6, 3.6, 7), "light_concrete", true)
	_label("SENTRY", Vector3(-22, 2, -42.45), 30, Color("ef654e"), 0.02)
	for x in [-7.0, 2.0]:
		_cylinder(Vector3(x, 1.7, -48), 2.1, 3.4, "rust", true)
		_cylinder(Vector3(x, 3.45, -48), 2.25, 0.18, "dark")
	_barrier(Vector3(-7, 0, -38), 6)
	_barrier(Vector3(-2, 0, -64), 5)
	_crate(Vector3(-18, 0, -66), Vector3(4, 3.2, 6))
	_crate(Vector3(16, 0, -69), Vector3(6, 2.8, 4))
	_sign("03   RELAY YARD", Vector3(-8, 2.1, -72), "LAST SIGNAL   /   THEN EXTRACT")


func _build_relay_yard() -> void:
	_box(Vector3(-15, 2.6, -95), Vector3(18, 5.2, 1), "dark", true)
	_box(Vector3(-23, 2.6, -88), Vector3(1, 5.2, 14), "dark", true)
	_box(Vector3(-7, 2.6, -92), Vector3(1, 5.2, 7), "dark", true)
	_box(Vector3(-15, 5.2, -93), Vector3(18, 0.4, 5), "rust", true)
	_label("R E L A Y  /  0 3", Vector3(-15, 3.7, -94.42), 40, Color("c5d0bc"), 0.017)
	_box(Vector3(-19, 1.35, -92.8), Vector3(3, 2.7, 1.4), "light_concrete", true)
	for x in [-19.7, -19.0, -18.3]:
		_box(Vector3(x, 1.6, -92.05), Vector3(0.1, 0.7, 0.04), "cyan")
	_box(Vector3(22, 1.4, -83), Vector3(7, 2.8, 8), "light_concrete", true)
	_crate(Vector3(5, 0, -82), Vector3(6.3, 2.6, 4.0))
	_crate(Vector3(-3, 0, -98), Vector3(4, 2.3, 5))
	_barrier(Vector3(12, 0, -98), 5)
	_barrier(Vector3(-16, 0, -105), 5)
	_sign("EXTRACTION   >", Vector3(0, 2.1, -108), "SECURE THREE CASES   /   HOLD SIX SECONDS", "cyan")
	# Tall comms mast is a distant orientation point.
	_box(Vector3(-24, 12, -115), Vector3(0.75, 24, 0.75), "rust", true)
	for y in [8.0, 14.0, 20.0]:
		_box(Vector3(-24, y, -115), Vector3(6, 0.18, 0.18), "dark")
		_cylinder(Vector3(-24, y + 0.5, -115), 0.35, 0.45, "amber")


func _build_extraction() -> void:
	_box(Vector3(16, 0.025, -116), Vector3(10, 0.05, 10), "dark")
	for x in [11.0, 21.0]:
		_box(Vector3(x, 0.08, -116), Vector3(0.18, 0.06, 10), "cyan")
	for z in [-111.0, -121.0]:
		_box(Vector3(16, 0.08, z), Vector3(10, 0.06, 0.18), "cyan")
	for x in [11.0, 21.0]:
		_box(Vector3(x, 3, -122), Vector3(0.6, 6, 0.6), "rust", true)
	_box(Vector3(16, 5.8, -122), Vector3(11, 0.65, 0.7), "dark", true)
	_label("E X T R A C T I O N", Vector3(16, 5.8, -121.5), 38, Color("5ad6c8"), 0.012)
	_label("BANK SALVAGE  /  HOLD POSITION", Vector3(16, 4.7, -121.5), 24, Color("d8dfca"), 0.011)
	_box(Vector3(16, 0.11, -116), Vector3(4.2, 0.05, 0.3), "cyan")
	_box(Vector3(16, 0.11, -116), Vector3(0.3, 0.05, 4.2), "cyan")
	_extract_ring = _cylinder(Vector3(16, 0.09, -116), 3.8, 0.05, "cyan")
	var ring_material := _material(Color(0.2, 0.85, 0.72, 0.12), true)
	_extract_ring.material_override = ring_material
	_box(Vector3(7, 1.6, -116), Vector3(2.5, 3.2, 8), "light_concrete", true)
	_box(Vector3(24, 1.6, -116), Vector3(2.5, 3.2, 8), "light_concrete", true)


func _build_dressing() -> void:
	# Static silhouette skyline: no expensive imported assets or dynamic lights.
	var rng := RandomNumberGenerator.new()
	rng.seed = 90421
	for side in [-1.0, 1.0]:
		for i in range(12):
			var height: float = rng.randf_range(11.0, 28.0)
			var x: float = side * rng.randf_range(36, 55)
			var z: float = 20.0 - float(i) * 14.0
			_box(Vector3(x, height * 0.5 - 4, z), Vector3(rng.randf_range(8, 15), height, rng.randf_range(7, 12)), "dark")
			if i % 3 == 0:
				_cylinder(Vector3(x, height + 1, z), 1.4, 10, "rust")
		for z in [-14.0, -45.0, -78.0, -109.0]:
			_box(Vector3(side * 25.6, 5.6, z), Vector3(0.25, 11.2, 0.25), "rust", true)
			_box(Vector3(side * 24.2, 11, z), Vector3(3.0, 0.22, 0.3), "dark")
			_box(Vector3(side * 23, 10.8, z), Vector3(1.1, 0.12, 0.5), "amber")
	# A suspended pipe threads the whole map; strong parallax during flight.
	for side in [-1.0, 1.0]:
		var pipe := _cylinder(Vector3(side * 24.3, 7.3, -51), 0.42, 142, "rust")
		pipe.rotation.x = PI * 0.5
	for z in [-8.0, -34.0, -70.0, -104.0]:
		for side in [-1.0, 1.0]:
			_cylinder(Vector3(side * 23, 0.6, z), 0.45, 1.2, "yellow", true)


func _add_loot(location: Vector3, title: String) -> void:
	var node := Node3D.new()
	node.position = location
	add_child(node)
	var case_mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = Vector3(1.2, 0.55, 0.8)
	case_mesh.mesh = shape
	case_mesh.material_override = _materials["yellow"]
	case_mesh.position.y = 0.4
	node.add_child(case_mesh)
	for x in [-0.4, 0.4]:
		var stripe := MeshInstance3D.new()
		var stripe_mesh := BoxMesh.new()
		stripe_mesh.size = Vector3(0.08, 0.58, 0.82)
		stripe.mesh = stripe_mesh
		stripe.material_override = _materials["dark"]
		stripe.position = Vector3(x, 0.4, 0)
		node.add_child(stripe)
	var marker := Label3D.new()
	marker.text = "◇  SALVAGE\n" + title
	marker.position.y = 2.5
	marker.font_size = 32
	marker.pixel_size = 0.012
	marker.modulate = Color("5ad6c8")
	marker.outline_modulate = Color("101e24")
	marker.outline_size = 8
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.no_depth_test = false
	marker.visibility_range_end = 70.0
	node.add_child(marker)
	var beam := MeshInstance3D.new()
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 0.045
	beam_mesh.bottom_radius = 0.045
	beam_mesh.height = 6.0
	beam_mesh.radial_segments = 6
	beam.mesh = beam_mesh
	beam.material_override = _materials["cyan"]
	beam.position.y = 3.5
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(beam)
	_loot.append({"node": node, "mesh": case_mesh, "position": location, "marker": marker})


func _spawn_enemy(kind: String, location: Vector3) -> void:
	var enemy := EnemyScript.new()
	add_child(enemy)
	enemy.setup(_player, kind, location)
	enemy.fired.connect(func(origin: Vector3, end: Vector3) -> void: _tracer(origin, end, "red"))
	enemy.alerted.connect(func(message: String) -> void: threat_changed.emit(message))
	_enemies.append(enemy)


func _physics_process(delta: float) -> void:
	_clock += delta
	if not _active or not is_instance_valid(_player):
		return
	for loot in _loot.duplicate():
		var node: Node3D = loot["node"]
		var location: Vector3 = loot["position"]
		var mesh: MeshInstance3D = loot["mesh"]
		mesh.position.y = 0.4 + sin(_clock * 2.5) * 0.08
		if _player.global_position.distance_to(location + Vector3.UP * 0.9) < 2.35:
			_loot.erase(loot)
			node.queue_free()
			loot_collected.emit(1)
			threat_changed.emit("SALVAGE SECURED — REACH EXTRACTION")
	var offset: Vector3 = _player.global_position - extraction_position
	var inside: bool = absf(offset.x) < 4.7 and absf(offset.z) < 4.7 and offset.y > -0.5 and offset.y < 3.0
	if inside != _inside_extraction:
		_inside_extraction = inside
		extraction_changed.emit(inside)
	if is_instance_valid(_extract_ring):
		var pulse: float = 0.96 + sin(_clock * 2.0) * 0.03
		_extract_ring.scale = Vector3(pulse, 1, pulse)


func apply_shot(origin: Vector3, direction: Vector3, damage: float) -> bool:
	if not _active or direction.length_squared() < 0.01:
		return false
	var end: Vector3 = origin + direction.normalized() * 160.0
	var query := PhysicsRayQueryParameters3D.create(origin, end, 1 | 4 | 8)
	if _player is CollisionObject3D:
		query.exclude = [(_player as CollisionObject3D).get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	var hit_enemy: bool = false
	if not hit.is_empty():
		end = hit["position"]
		var collider: Object = hit["collider"]
		if collider.has_method("take_damage"):
			collider.call("take_damage", damage)
			hit_enemy = true
		elif collider is RigidBody3D:
			(collider as RigidBody3D).apply_central_impulse(direction.normalized() * 18.0)
		_impact(end, hit_enemy)
	_tracer(origin + Vector3(0, -0.12, 0), end, "amber")
	return hit_enemy


func _tracer(origin: Vector3, end: Vector3, color_name: String) -> void:
	var distance: float = origin.distance_to(end)
	if distance < 0.01:
		return
	var tracer := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.025
	mesh.bottom_radius = 0.025
	mesh.height = distance
	mesh.radial_segments = 4
	tracer.mesh = mesh
	tracer.material_override = _materials[color_name]
	tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tracer)
	tracer.global_position = (origin + end) * 0.5
	tracer.quaternion = Quaternion(Vector3.UP, (end - origin).normalized())
	var tween := create_tween()
	tween.tween_interval(0.09)
	tween.tween_callback(tracer.queue_free)


func _impact(location: Vector3, hit_enemy: bool) -> void:
	var spark := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.09 if hit_enemy else 0.055
	mesh.height = mesh.radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	spark.mesh = mesh
	spark.material_override = _materials["red" if hit_enemy else "amber"]
	add_child(spark)
	spark.global_position = location
	var tween := create_tween()
	tween.tween_property(spark, "scale", Vector3(3, 3, 3), 0.12)
	tween.tween_callback(spark.queue_free)


func _box(location: Vector3, size: Vector3, color_name: String, solid: bool = false) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = _materials[color_name]
	instance.position = location
	add_child(instance)
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
		instance.add_child(body)
	return instance


func _cylinder(location: Vector3, radius: float, height: float, color_name: String, solid: bool = false) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	instance.mesh = mesh
	instance.material_override = _materials[color_name]
	instance.position = location
	add_child(instance)
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var collision := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		collision.shape = shape
		body.add_child(collision)
		instance.add_child(body)
	return instance


func _ramp(start: Vector3, finish: Vector3, width: float) -> void:
	var offset: Vector3 = finish - start
	var length: float = offset.length()
	var ramp := _box((start + finish) * 0.5 - Vector3.UP * 0.14, Vector3(width, 0.28, length + 0.4), "light_concrete", true)
	# Local -Z follows the slope. Both mesh and child collision rotate together.
	ramp.look_at_from_position(ramp.position, ramp.position + offset, Vector3.UP)
	for side in [-1.0, 1.0]:
		var edge := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.12, 0.035, length)
		edge.mesh = mesh
		edge.material_override = _materials["yellow"]
		edge.position = Vector3(side * (width * 0.5 - 0.15), 0.155, 0)
		ramp.add_child(edge)


func _crate(base: Vector3, size: Vector3) -> void:
	_box(base + Vector3.UP * size.y * 0.5, size, "rust", true)
	for x in [-0.37, 0.37]:
		_box(base + Vector3(x * size.x, size.y * 0.5, size.z * 0.5 + 0.025), Vector3(0.09, size.y, 0.04), "dark")
	_box(base + Vector3(0, size.y - 0.3, size.z * 0.5 + 0.04), Vector3(size.x * 0.8, 0.08, 0.04), "yellow")
	_label("DW / 09", base + Vector3(0, size.y * 0.58, size.z * 0.5 + 0.06), 28, Color("c5ad83"), 0.012)


func _barrier(base: Vector3, length: float) -> void:
	_box(base + Vector3.UP * 0.75, Vector3(length, 1.5, 0.9), "light_concrete", true)
	_box(base + Vector3(0, 1.16, 0.46), Vector3(length, 0.4, 0.025), "yellow")
	for x in range(int(length)):
		var stripe := _box(base + Vector3(float(x) - length * 0.5 + 0.4, 1.16, 0.48), Vector3(0.3, 0.4, 0.025), "stripe")
		stripe.rotation.z = -0.35


func _sign(title: String, location: Vector3, subtitle: String, color_name: String = "amber") -> void:
	_box(location, Vector3(8.3, 1.65, 0.22), "dark", true)
	_box(location + Vector3(-4.05, 0, 0.13), Vector3(0.1, 1.65, 0.04), color_name)
	for x in [-3.5, 3.5]:
		_box(Vector3(location.x + x, location.y * 0.5 - 0.4, location.z), Vector3(0.13, maxf(location.y - 0.8, 0.1), 0.13), "rust", true)
	_label(title, location + Vector3(0, 0.25, 0.15), 38, Color("e4ddbd"), 0.011)
	_label(subtitle, location + Vector3(0, -0.4, 0.15), 22, Color("76bfb7"), 0.009)


func _label(text: String, location: Vector3, size: int, color: Color, pixel_size: float, billboard: bool = false) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = location
	label.font_size = size
	label.pixel_size = pixel_size
	label.modulate = color
	label.outline_modulate = Color("14282f")
	label.outline_size = 5
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED if billboard else BaseMaterial3D.BILLBOARD_DISABLED
	label.visibility_range_end = 85.0
	add_child(label)
	return label


func _material(color: Color, glow: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	if glow:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.0
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
