extends RigidBody3D
## Upright rigid-body runner. Ground motion applies limited force; air momentum is physical.
## Feel tuning (coyote time, jump buffer, air control, FOV kick, landing dip, bob, shake)
## lives in the constants below so it can be read in one place.

signal damaged(amount: float, source: String, from_position: Vector3)
signal died(source: String)
signal landed(impact_speed: float)
signal jumped
signal footstep

const BASE_LOOK_SENSITIVITY: float = 0.0024
## Time after leaving the ground during which a jump still counts as grounded (ledge forgiveness).
const COYOTE_TIME: float = 0.12
## A jump pressed this long before touchdown fires on landing instead of being lost.
const JUMP_BUFFER_TIME: float = 0.12
const JUMP_SPEED: float = 5.0
const GROUND_SPEED: float = 5.8
## Downward speed above which a landing costs health.
const FALL_DAMAGE_SPEED: float = 20.0
## Contact normals above this height count as ground (about 57 degrees).
const GROUND_NORMAL_MIN_Y: float = 0.55
## Air control adds at most this acceleration (m/s^2) while steering...
const AIR_ACCEL: float = 3.0
## ...and never pushes the speed along the wish direction past this, so air control cannot pump speed.
const AIR_SPEED_CAP: float = 6.0
## Standing still on a slope up to this angle cancels gravity along the slope, so the player
## stays put. The half degree is tolerance so a 35 degree ramp keeps its hold despite rounding.
const HOLD_MAX_SLOPE_DEGREES: float = 35.5
## The FOV widens by up to FOV_KICK degrees as speed approaches FOV_KICK_SPEED.
const FOV_KICK: float = 12.0
const FOV_KICK_SPEED: float = 40.0
const BOB_HEIGHT: float = 0.016
## Ground distance between footstep events.
const STEP_DISTANCE: float = 2.4
## Trauma drains at this rate per second.
const SHAKE_DECAY: float = 1.4
## Largest lens offset (fraction of the viewport) at full shake. Offsets move the lens, not the aim.
const SHAKE_OFFSET: float = 0.03

var camera: Camera3D
var health: float = 100.0
var max_health: float = 100.0
var move_input: Vector2 = Vector2.ZERO
var active: bool = false
var grounded: bool = false
var yaw: float = 0.0
var pitch: float = -0.08
var look_sensitivity: float = BASE_LOOK_SENSITIVITY
## Seconds since the player last stood on ground; 0 while grounded.
var airborne_time: float = 0.0
var view_pivot: Node3D
var rod_model: Node3D
var gun_model: Node3D
var rod_tip: Node3D
var rod_bend: MeshInstance3D
var muzzle: MeshInstance3D
var charge_feedback: float = 0.0
var tension_feedback: float = 0.0
var kick: float = 0.0
var _jump_buffer: float = 0.0
var _coyote_time: float = 0.0
var _reset_position: Vector3 = Vector3.ZERO
var _reset_pending: bool = false
var _previous_fall_speed: float = 0.0
var _was_grounded: bool = false
var _bob: float = 0.0
var _shot_flash: float = 0.0
var _base_fov: float = 80.0
var _fov_blend: float = 0.0
var _landing_dip: float = 0.0
var _trauma: float = 0.0
var _shake_scale: float = 1.0
var _shake_clock: float = 0.0
var _step_distance: float = 0.0


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
	var step: float = state.step
	# The most upright contact is the surface we stand on; its normal drives the slope hold.
	var ground_normal: Vector3 = Vector3.UP
	var most_upright: float = -1.0
	grounded = false
	for index in state.get_contact_count():
		var normal: Vector3 = state.get_contact_local_normal(index)
		if normal.y > GROUND_NORMAL_MIN_Y:
			grounded = true
			if normal.y > most_upright:
				most_upright = normal.y
				ground_normal = normal
	if grounded and not _was_grounded:
		_touchdown()
	_was_grounded = grounded
	_previous_fall_speed = state.linear_velocity.y
	_track_airtime(step)
	if not active:
		_jump_buffer = 0.0
		return
	_jump_buffer = maxf(0.0, _jump_buffer - step)
	# A buffered press fires on the first step where coyote time or the ground allows a jump.
	if _jump_buffer > 0.0 and (grounded or _coyote_time > 0.0):
		_jump(state)
	var wish: Vector3 = Basis(Vector3.UP, yaw) * Vector3(move_input.x, 0.0, move_input.y)
	if grounded:
		_drive_on_ground(state, wish, ground_normal)
		_count_footsteps(state)
	else:
		_air_control(state, wish, step)


## Airtime and coyote window: both count from the last step on ground.
func _track_airtime(step: float) -> void:
	if grounded:
		airborne_time = 0.0
		_coyote_time = COYOTE_TIME
	else:
		airborne_time += step
		_coyote_time = maxf(0.0, _coyote_time - step)


## Runs once per touchdown: reports the impact, dips the view, shakes on hard hits and applies
## fall damage. The impact is the downward speed from the last step, before this one.
func _touchdown() -> void:
	var impact: float = maxf(0.0, -_previous_fall_speed)
	landed.emit(impact)
	_landing_dip = maxf(_landing_dip, minf(0.12, impact * 0.01))
	if impact > 6.0:
		add_shake(minf(0.6, impact * 0.03))
	if active and _previous_fall_speed < -FALL_DAMAGE_SPEED:
		take_damage.call_deferred(minf(65.0, (impact - FALL_DAMAGE_SPEED) * 3.0), "fall", Vector3.INF)


func _jump(state: PhysicsDirectBodyState3D) -> void:
	state.apply_central_impulse(Vector3.UP * mass * JUMP_SPEED)
	_jump_buffer = 0.0
	_coyote_time = 0.0
	jumped.emit()


func _drive_on_ground(state: PhysicsDirectBodyState3D, wish: Vector3, ground_normal: Vector3) -> void:
	var moving: bool = move_input.length() > 0.05
	var horizontal := Vector3(state.linear_velocity.x, 0.0, state.linear_velocity.z)
	var force := (wish * GROUND_SPEED - horizontal) * mass / 0.16
	var limit: float = 2200.0 if moving else 900.0
	state.apply_central_force(force.limit_length(limit))
	# Standing still on a gentle slope: cancel the pull along the slope so the player stays put.
	if not moving and ground_normal.angle_to(Vector3.UP) <= deg_to_rad(HOLD_MAX_SLOPE_DEGREES):
		state.apply_central_force(-_downslope_pull(state, ground_normal))


## Gravity component parallel to the surface.
func _downslope_pull(state: PhysicsDirectBodyState3D, ground_normal: Vector3) -> Vector3:
	var weight: Vector3 = state.total_gravity * mass
	return weight - ground_normal * weight.dot(ground_normal)


## Steering in the air adds at most AIR_ACCEL, and only while the speed along the wish direction
## is below AIR_SPEED_CAP. The force is also limited so one step cannot overshoot the cap.
func _air_control(state: PhysicsDirectBodyState3D, wish: Vector3, step: float) -> void:
	var strength: float = minf(move_input.length(), 1.0)
	if strength < 0.05 or wish.length_squared() < 0.0001:
		return
	var direction: Vector3 = wish.normalized()
	var along: float = Vector3(state.linear_velocity.x, 0.0, state.linear_velocity.z).dot(direction)
	if along >= AIR_SPEED_CAP:
		return
	var accel: float = minf(AIR_ACCEL * strength, (AIR_SPEED_CAP - along) / step)
	state.apply_central_force(direction * accel * mass)


func _count_footsteps(state: PhysicsDirectBodyState3D) -> void:
	var ground_speed: float = Vector2(state.linear_velocity.x, state.linear_velocity.z).length()
	if ground_speed < 0.5:
		return
	_step_distance += ground_speed * state.step
	if _step_distance >= STEP_DISTANCE:
		_step_distance -= STEP_DISTANCE
		footstep.emit()


func _process(delta: float) -> void:
	if not is_instance_valid(camera):
		return
	var speed: float = linear_velocity.length()
	var walking: float = minf(speed / GROUND_SPEED, 1.0) if grounded and active else 0.0
	_bob += delta * 11.0 * walking
	_landing_dip = move_toward(_landing_dip, 0.0, delta * 1.5)
	var height: float = sin(_bob) * BOB_HEIGHT * walking - _landing_dip
	camera.position.y = lerpf(camera.position.y, height, minf(1.0, delta * 12.0))
	_fov_blend = lerpf(_fov_blend, clampf(speed / FOV_KICK_SPEED, 0.0, 1.0), minf(1.0, delta * 3.0))
	camera.fov = _base_fov + FOV_KICK * _fov_blend
	_update_shake(delta)
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


## Trauma model: the shake is trauma squared, scaled by the camera_shake setting. It moves only
## the lens offset, so the aim line used for shots and the rope never changes.
func _update_shake(delta: float) -> void:
	_trauma = maxf(0.0, _trauma - SHAKE_DECAY * delta)
	_shake_clock += delta
	var intensity: float = _trauma * _trauma * _shake_scale
	camera.h_offset = sin(_shake_clock * 47.0) * intensity * SHAKE_OFFSET
	camera.v_offset = sin(_shake_clock * 53.0 + 1.3) * intensity * SHAKE_OFFSET


func apply_look(delta: Vector2) -> void:
	yaw -= delta.x * look_sensitivity
	pitch = clampf(pitch - delta.y * look_sensitivity, -1.35, 1.35)
	if is_instance_valid(view_pivot):
		view_pivot.rotation = Vector3(pitch, yaw, 0.0)


## Buffers a jump press. It is honoured on this step or within JUMP_BUFFER_TIME of touchdown.
func request_jump() -> void:
	if active:
		_jump_buffer = JUMP_BUFFER_TIME


## Teleports the capsule centre to where, facing yaw_radians, with full health.
func reset_at(where: Vector3, yaw_radians: float = 0.0) -> void:
	_reset_position = where
	_reset_pending = true
	global_position = where
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	health = max_health
	move_input = Vector2.ZERO
	_previous_fall_speed = 0.0
	# Treat the spawn as already grounded so a reset does not count as a touchdown.
	_was_grounded = true
	airborne_time = 0.0
	_coyote_time = 0.0
	_jump_buffer = 0.0
	_landing_dip = 0.0
	_step_distance = 0.0
	yaw = yaw_radians
	pitch = -0.08
	apply_look(Vector2.ZERO)


func take_damage(amount: float, source: String = "", from_position: Vector3 = Vector3.INF) -> void:
	if not active or health <= 0.0:
		return
	var actual: float = minf(health, maxf(amount, 0.0))
	health -= actual
	damaged.emit(actual, source, from_position)
	if health <= 0.0:
		died.emit(source)


func heal(amount: float) -> void:
	if health <= 0.0:
		return
	health = minf(max_health, health + maxf(amount, 0.0))


## Loadout tuning. Takes max_health and refills health to it.
func configure(stats: Dictionary) -> void:
	max_health = maxf(1.0, float(stats.get("max_health", max_health)))
	health = max_health


## Applies the settings the player owns: look_sensitivity, fov and camera_shake.
## invert_y is not stored here: main's look handler already inverts the mouse delta, so inverting
## again would cancel it out.
func apply_settings(settings: Dictionary) -> void:
	if settings.has("look_sensitivity"):
		look_sensitivity = BASE_LOOK_SENSITIVITY * float(settings["look_sensitivity"])
	if settings.has("fov"):
		_base_fov = float(settings["fov"])
		if is_instance_valid(camera):
			camera.fov = _base_fov
	if settings.has("camera_shake"):
		_shake_scale = clampf(float(settings["camera_shake"]), 0.0, 1.0)


## Adds trauma (0..1). The shake strength is trauma squared, so small hits stay subtle.
func add_shake(amount: float) -> void:
	_trauma = clampf(_trauma + maxf(amount, 0.0), 0.0, 1.0)


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
