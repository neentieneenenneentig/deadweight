extends RigidBody3D
## Upright rigid-body runner. Ground motion applies limited force; air momentum is physical.

signal damaged(amount: float)
signal died

var camera: Camera3D
var health: float = 100.0
var move_input: Vector2 = Vector2.ZERO
var active: bool = false
var grounded: bool = false
var yaw: float = 0.0
var pitch: float = -0.08
var look_sensitivity: float = 0.0024
var view_pivot: Node3D
var rod_model: Node3D
var gun_model: Node3D
var rod_tip: Node3D
var rod_bend: MeshInstance3D
var muzzle: MeshInstance3D
var charge_feedback: float = 0.0
var tension_feedback: float = 0.0
var kick: float = 0.0
var _jump_requested: bool = false
var _reset_position: Vector3 = Vector3.ZERO
var _reset_pending: bool = false
var _previous_fall_speed: float = 0.0
var _was_grounded: bool = false
var _bob: float = 0.0
var _shot_flash: float = 0.0

func _ready() -> void:
	mass = 75.0
	lock_rotation = true
	can_sleep = false
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 6
	collision_layer = 2
	collision_mask = 1
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.035
	var surface := PhysicsMaterial.new()
	surface.friction = 0.08
	surface.bounce = 0.0
	physics_material_override = surface
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	add_child(shape)
	add_to_group("player")
	view_pivot = Node3D.new()
	view_pivot.position.y = 0.65
	add_child(view_pivot)
	camera = Camera3D.new()
	camera.fov = 80.0
	camera.near = 0.06
	camera.far = 350.0
	camera.current = true
	view_pivot.add_child(camera)
	_build_viewmodel()
	apply_look(Vector2.ZERO)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _reset_pending:
		state.transform = Transform3D(Basis.IDENTITY, _reset_position)
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		_reset_pending = false
		reset_physics_interpolation()
	grounded = false
	for index in state.get_contact_count():
		if state.get_contact_local_normal(index).y > 0.55:
			grounded = true
			break
	if grounded and not _was_grounded and _previous_fall_speed < -20.0 and active:
		take_damage.call_deferred(minf(65.0, (-_previous_fall_speed - 20.0) * 3.0))
	_was_grounded = grounded
	_previous_fall_speed = state.linear_velocity.y
	if not active:
		return
	if grounded:
		var wish := Basis(Vector3.UP, yaw) * Vector3(move_input.x, 0.0, move_input.y)
		var horizontal := Vector3(state.linear_velocity.x, 0.0, state.linear_velocity.z)
		var force := (wish * 5.8 - horizontal) * mass / 0.16
		var limit: float = 2200.0 if move_input.length() > 0.05 else 900.0
		state.apply_central_force(force.limit_length(limit))
		if _jump_requested:
			state.apply_central_impulse(Vector3.UP * mass * 5.0)
	_jump_requested = false

func _process(delta: float) -> void:
	if not is_instance_valid(camera):
		return
	var walking: float = minf(linear_velocity.length() / 5.8, 1.0) if grounded and active else 0.0
	_bob += delta * 11.0 * walking
	camera.position.y = lerpf(camera.position.y, sin(_bob) * 0.016 * walking, delta * 12.0)
	kick = move_toward(kick, 0.0, delta * 3.2)
	rod_model.position = Vector3(0.0, -charge_feedback * 0.08, charge_feedback * 0.16 + kick * 0.07)
	rod_model.rotation.x = charge_feedback * 0.24 + tension_feedback * 0.10
	gun_model.rotation.x = kick * 0.18
	_shot_flash = maxf(0.0, _shot_flash - delta)
	muzzle.visible = _shot_flash > 0.0
	var rod_mesh := ImmediateMesh.new()
	rod_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, rod_bend.material_override)
	for i in range(9):
		var fraction: float = float(i) / 8.0
		var point := Vector3(0.32 - fraction * 0.18, -0.25 + fraction * 0.27, -0.65 - fraction * 1.0)
		point.y -= sin(fraction * PI * 0.5) * tension_feedback * 0.22
		rod_mesh.surface_add_vertex(point)
	rod_mesh.surface_end()
	rod_bend.mesh = rod_mesh
	rod_tip.position = Vector3(0.14, 0.02 - tension_feedback * 0.22, -1.65)

func apply_look(delta: Vector2) -> void:
	yaw -= delta.x * look_sensitivity
	pitch = clampf(pitch - delta.y * look_sensitivity, -1.35, 1.35)
	if is_instance_valid(view_pivot):
		view_pivot.rotation = Vector3(pitch, yaw, 0.0)

func request_jump() -> void:
	if active:
		_jump_requested = true

func reset_at(where: Vector3) -> void:
	_reset_position = where
	_reset_pending = true
	global_position = where
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	health = 100.0
	move_input = Vector2.ZERO
	_previous_fall_speed = 0.0
	_was_grounded = false
	yaw = 0.0
	pitch = -0.08
	apply_look(Vector2.ZERO)

func take_damage(amount: float) -> void:
	if not active or health <= 0.0:
		return
	var actual: float = minf(health, maxf(amount, 0.0))
	health -= actual
	damaged.emit(actual)
	if health <= 0.0:
		died.emit()

func set_feedback(charge: float, tension: float, weapon: String) -> void:
	charge_feedback = charge
	tension_feedback = clampf(tension / 22000.0, 0.0, 1.0)
	rod_model.visible = weapon == "ROD"
	gun_model.visible = weapon == "SIDEARM"

func shot_effect() -> void:
	kick = 1.0
	_shot_flash = 0.045

func _material(color: Color, emissive: bool = false) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.75
	if emissive:
		result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return result

func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = _material(color)
	node.position = at
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

func _build_viewmodel() -> void:
	rod_model = Node3D.new()
	camera.add_child(rod_model)
	var grip := _box(rod_model, Vector3(0.075, 0.08, 0.4), Vector3(0.32, -0.29, -0.53), Color("273940"))
	grip.rotation.x = -0.12
	_box(rod_model, Vector3(0.08, 0.084, 0.045), Vector3(0.32, -0.27, -0.69), Color("e4aa52"))
	_box(rod_model, Vector3(0.12, 0.10, 0.15), Vector3(0.32, -0.34, -0.6), Color("0d181c"))
	var reel := MeshInstance3D.new()
	var spool := CylinderMesh.new()
	spool.top_radius = 0.075
	spool.bottom_radius = 0.075
	spool.height = 0.08
	spool.radial_segments = 12
	reel.mesh = spool
	reel.material_override = _material(Color("cd9951"))
	reel.position = Vector3(0.27, -0.32, -0.6)
	reel.rotation.z = PI * 0.5
	rod_model.add_child(reel)
	rod_bend = MeshInstance3D.new()
	rod_bend.material_override = _material(Color("c7d7ce"), true)
	rod_model.add_child(rod_bend)
	rod_tip = Node3D.new()
	rod_model.add_child(rod_tip)
	_box(rod_model, Vector3(0.10, 0.11, 0.2), Vector3(0.33, -0.34, -0.37), Color("765e49"))
	_box(rod_model, Vector3(0.12, 0.14, 0.38), Vector3(0.34, -0.40, -0.17), Color("344748"))
	gun_model = Node3D.new()
	camera.add_child(gun_model)
	_box(gun_model, Vector3(0.095, 0.10, 0.30), Vector3(0.27, -0.23, -0.57), Color("253139"))
	_box(gun_model, Vector3(0.065, 0.18, 0.09), Vector3(0.27, -0.33, -0.46), Color("111d22"))
	_box(gun_model, Vector3(0.07, 0.025, 0.22), Vector3(0.27, -0.17, -0.57), Color("697a76"))
	_box(gun_model, Vector3(0.022, 0.025, 0.025), Vector3(0.27, -0.15, -0.69), Color("e3b369"))
	_box(gun_model, Vector3(0.10, 0.12, 0.17), Vector3(0.27, -0.35, -0.42), Color("765e49"))
	_box(gun_model, Vector3(0.13, 0.14, 0.28), Vector3(0.28, -0.41, -0.22), Color("344748"))
	muzzle = _box(gun_model, Vector3(0.12, 0.10, 0.10), Vector3(0.27, -0.23, -0.78), Color("ffc46a"))
	muzzle.material_override = _material(Color("ffdc92"), true)
	muzzle.visible = false
	gun_model.visible = false
