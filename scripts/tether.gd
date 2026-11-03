extends Node3D
## A free moving weight and tension-only elastic line. All line forces are paired.

signal event_happened(event: String)

const WEIGHT_MASS: float = 145.0
const MAX_LINE: float = 48.0
const STIFFNESS: float = 12000.0
const DAMPING: float = 1200.0
const MAX_TENSION: float = 22000.0
const REEL_FORCE: float = 16000.0
const REEL_SPEED: float = 11.0

var player: RigidBody3D
var weight: RigidBody3D
var active: bool = false
var locked: bool = false
var reeling: bool = false
var charging: bool = false
var charge: float = 0.0
var line_length: float = 0.0
var tension: float = 0.0
var assist_strength: float = 14500.0
var _assist_remaining: float = 0.0
var _assist_direction: Vector3 = Vector3.ZERO
var _line_view: MeshInstance3D
var _line_material: StandardMaterial3D
var _loose_weights: Array[Dictionary] = []
var _cast_cooldown: float = 0.0
var _blocked_time: float = 0.0

func _ready() -> void:
	_line_view = MeshInstance3D.new()
	_line_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_line_material = StandardMaterial3D.new()
	_line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_material.albedo_color = Color("b5ddd5")
	_line_material.no_depth_test = false
	add_child(_line_view)

func bind(body: RigidBody3D) -> void:
	player = body

func begin_charge() -> void:
	if not active or _cast_cooldown > 0.0:
		return
	if is_instance_valid(weight):
		event_happened.emit("CUT FIRST  /  Q or CUT to prepare a new weight")
		return
	charging = true
	charge = 0.0

func release_cast() -> void:
	if not charging or not active:
		return
	charging = false
	_cast(charge)
	charge = 0.0

func _cast(power: float) -> void:
	if is_instance_valid(weight):
		return
	var camera: Camera3D = player.get("camera") as Camera3D
	var direction: Vector3 = -camera.global_basis.z
	var start: Vector3 = camera.global_position + direction * 1.35 + Vector3.DOWN * 0.12
	var clearance := PhysicsRayQueryParameters3D.create(camera.global_position, start, 1)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(clearance)
	if not hit.is_empty():
		event_happened.emit("NO CAST CLEARANCE  /  step back from cover")
		return
	weight = RigidBody3D.new()
	weight.name = "CastWeight"
	weight.mass = WEIGHT_MASS
	weight.collision_layer = 4
	weight.collision_mask = 1 | 8
	weight.continuous_cd = true
	weight.can_sleep = false
	weight.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	weight.linear_damp = 0.025
	var surface := PhysicsMaterial.new()
	surface.bounce = 0.18
	surface.friction = 0.65
	weight.physics_material_override = surface
	var shape := CollisionShape3D.new()
	var ball := SphereShape3D.new()
	ball.radius = 0.29
	shape.shape = ball
	weight.add_child(shape)
	var visual := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.29
	mesh.height = 0.58
	mesh.radial_segments = 12
	mesh.rings = 6
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("dfa754")
	material.metallic = 0.65
	material.roughness = 0.4
	visual.material_override = material
	weight.add_child(visual)
	var belt := MeshInstance3D.new()
	var belt_mesh := CylinderMesh.new()
	belt_mesh.top_radius = 0.30
	belt_mesh.bottom_radius = 0.30
	belt_mesh.height = 0.09
	belt_mesh.radial_segments = 12
	belt.mesh = belt_mesh
	var belt_mat := StandardMaterial3D.new()
	belt_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	belt_mat.albedo_color = Color("6de4dc")
	belt.material_override = belt_mat
	weight.add_child(belt)
	get_parent().add_child(weight)
	weight.global_position = start
	weight.linear_velocity = player.linear_velocity
	var impulse: Vector3 = direction * lerpf(200.0, 530.0, power)
	weight.apply_central_impulse(impulse)
	player.apply_central_impulse(-impulse)
	_assist_direction = direction
	_assist_remaining = lerpf(0.40, 0.72, power)
	line_length = start.distance_to(player.global_position) + 0.1
	tension = 0.0
	locked = false
	reeling = false
	_blocked_time = 0.0
	_cast_cooldown = 0.18
	event_happened.emit("cast")

func toggle_lock() -> void:
	if is_instance_valid(weight):
		locked = not locked
		event_happened.emit("lock" if locked else "release")

func cut() -> void:
	charging = false
	charge = 0.0
	if is_instance_valid(weight):
		# Detaching never changes either body's linear velocity.
		_loose_weights.append({"body": weight, "time": 8.0})
		weight = null
		event_happened.emit("cut")
	tension = 0.0
	line_length = 0.0
	locked = false
	reeling = false
	_assist_remaining = 0.0
	_line_view.mesh = null

func clear() -> void:
	if is_instance_valid(weight):
		weight.queue_free()
		weight = null
	for entry in _loose_weights:
		if is_instance_valid(entry.body):
			entry.body.queue_free()
	_loose_weights.clear()
	charging = false
	charge = 0.0
	locked = false
	reeling = false
	line_length = 0.0
	tension = 0.0
	if is_instance_valid(_line_view):
		_line_view.mesh = null

static func rope_force(distance: float, deployed: float, separating_speed: float, limit: float = MAX_TENSION) -> float:
	if distance <= deployed:
		return 0.0
	return clampf((distance - deployed) * STIFFNESS + separating_speed * DAMPING, 0.0, limit)

func _physics_process(delta: float) -> void:
	if not active or not is_instance_valid(player):
		return
	_cast_cooldown = maxf(0.0, _cast_cooldown - delta)
	if charging:
		charge = minf(1.0, charge + delta / 0.8)
	for index in range(_loose_weights.size() - 1, -1, -1):
		_loose_weights[index].time -= delta
		if _loose_weights[index].time <= 0.0 or _loose_weights.size() > 8:
			if is_instance_valid(_loose_weights[index].body):
				_loose_weights[index].body.queue_free()
			_loose_weights.remove_at(index)
	if not is_instance_valid(weight):
		return
	if _assist_remaining > 0.0:
		var fraction: float = minf(delta, _assist_remaining) / delta
		weight.apply_central_force(_assist_direction * assist_strength * fraction)
		_assist_remaining -= delta
	var displacement: Vector3 = weight.global_position - player.global_position
	var distance: float = displacement.length()
	if distance < 0.01:
		return
	var direction: Vector3 = displacement / distance
	if not locked and not reeling:
		line_length = minf(MAX_LINE, maxf(line_length, distance + 0.04))
	if reeling:
		var load_fraction: float = clampf(tension / REEL_FORCE, 0.0, 1.0)
		line_length = maxf(1.8, line_length - REEL_SPEED * (1.0 - load_fraction) * delta)
	var relative_speed: float = (weight.linear_velocity - player.linear_velocity).dot(direction)
	tension = rope_force(distance, line_length, relative_speed)
	if tension > 0.0:
		var force: Vector3 = direction * tension
		player.apply_central_force(force)
		weight.apply_central_force(-force)
	# A simple line does not wrap: sustained obstruction severs it visibly.
	var query := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP * 0.35, weight.global_position, 1)
	var obstruction: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not obstruction.is_empty() and (obstruction.position as Vector3).distance_to(weight.global_position) > 0.65:
		_blocked_time += delta
	else:
		_blocked_time = 0.0
	if _blocked_time > 0.24:
		cut()
		event_happened.emit("LINE SEVERED  /  keep your line clear of concrete")
	elif distance > MAX_LINE * 2.0:
		cut()
		event_happened.emit("LINE OVERLOAD  /  cast again")

func _process(_delta: float) -> void:
	if not is_instance_valid(weight) or not is_instance_valid(player):
		return
	var rod: Node3D = player.get("rod_tip") as Node3D
	var start: Vector3 = rod.global_position
	var end: Vector3 = weight.global_position
	var slack: float = maxf(0.0, line_length - start.distance_to(end))
	var mesh := ImmediateMesh.new()
	_line_material.albedo_color = Color("edb268") if tension > 8000.0 else Color("b5ddd5")
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, _line_material)
	for i in range(17):
		var ratio: float = float(i) / 16.0
		var point: Vector3 = start.lerp(end, ratio)
		point.y -= sin(ratio * PI) * minf(slack * 0.3, 5.0)
		mesh.surface_add_vertex(to_local(point))
	mesh.surface_end()
	_line_view.mesh = mesh

func state_name() -> String:
	if charging:
		return "CHARGING"
	if not is_instance_valid(weight):
		return "READY TO CAST"
	if reeling:
		return "REELING" if tension < REEL_FORCE else "REEL STALLED"
	if locked:
		return "LOCKED / TAUT" if tension > 100.0 else "LOCKED / SLACK"
	return "SPOOL LIMIT" if line_length >= MAX_LINE else "FREE SPOOL"
