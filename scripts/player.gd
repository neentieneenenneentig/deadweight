extends RigidBody3D
## Upright rigid-body runner. Ground motion applies limited force; air momentum is physical.
## Feel tuning (coyote time, jump buffer, air control, FOV kick, landing dip, bob, shake)
## lives in the constants below so it can be read in one place.

signal damaged(amount: float, source: String, from_position: Vector3)
signal died(source: String)
signal landed(impact_speed: float)
signal jumped
signal footstep
## The player hit an enemy body at speed (W3): the enemy takes slam damage.
signal slammed(target: Node3D, speed: float)

const BASE_LOOK_SENSITIVITY: float = 0.0024
## Time after leaving the ground during which a jump still counts as grounded (ledge forgiveness).
const COYOTE_TIME: float = 0.12
## A jump pressed this long before touchdown fires on landing instead of being lost.
const JUMP_BUFFER_TIME: float = 0.12
const JUMP_SPEED: float = 5.0
const GROUND_SPEED: float = 5.8
## Landing damage (S1). It grows linearly with downward speed, from 0 at FALL_DAMAGE_SPEED to
## FALL_LETHAL_DAMAGE at FALL_LETHAL_SPEED, and keeps growing past it.
## 14 m/s is about a 10 m drop, and 30 m/s about a 46 m drop.
## A taut line turns the fall into a swing, so it is the way to land safely. Water stops a fall
## without damage.
const FALL_DAMAGE_SPEED: float = 14.0
const FALL_LETHAL_SPEED: float = 30.0
const FALL_LETHAL_DAMAGE: float = 100.0
## Speed kills (W3): running into an enemy at SLAM_MIN_SPEED or more deals SLAM_DAMAGE_PER_MS per
## m/s above SLAM_FREE_SPEED (about 60 at 11 m/s, a dead hound by 13 m/s). The player keeps most of
## the momentum through the hit. Enemy contacts never count as ground, so a stomp is not a landing.
const SLAM_MIN_SPEED: float = 11.0
const SLAM_FREE_SPEED: float = 7.0
const SLAM_DAMAGE_PER_MS: float = 15.0
const SLAM_COOLDOWN: float = 0.4
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

## Viewmodel geometry in camera space. The blank runs from ROD_BUTT to ROD_TIP and rod_tip sits at
## the tip, so the line leaves the rod exactly where it is drawn.
const ROD_BUTT: Vector3 = Vector3(0.32, -0.25, -0.65)
const ROD_TIP: Vector3 = Vector3(0.14, 0.02, -1.65)
const ROD_GRIP: Vector3 = Vector3(0.32, -0.29, -0.53)
const GUN_GRIP: Vector3 = Vector3(0.27, -0.23, -0.42)
const GUN_MUZZLE: Vector3 = Vector3(0.27, -0.23, -0.82)
## How far the blank belly sags at full tension, in metres.
const ROD_SAG: float = 0.26
const BLANK_SEGMENTS: int = 12
const BLANK_SIDES: int = 8
const BLANK_BUTT_RADIUS: float = 0.024
const BLANK_TIP_RADIUS: float = 0.006
## Guides sit along the blank at these fractions (0 = butt, 1 = tip).
const GUIDE_FRACTIONS := [0.1, 0.25, 0.42, 0.6, 0.76, 0.9, 0.985]
const GUIDE_TUBE: float = 0.18
const GUIDE_GAP: float = 0.008
## The reel spool turns about its axle; line speed is divided by this radius.
const SPOOL_CENTER: Vector3 = Vector3(0.27, -0.32, -0.6)
const SPOOL_RADIUS: float = 0.075
## Cast spring: stiffness and damping per second, and the forward kick the cast gives the tip.
const WHIP_STIFFNESS: float = 180.0
const WHIP_DAMPING: float = 6.0
const WHIP_KICK: float = 3.0
## A charge above this that drops to zero on the rod counts as a cast.
const CAST_MIN_CHARGE: float = 0.05
## The rod stops this far in front of a wall, and slides back by at most MAX_CLEARANCE_PULL.
const CLEARANCE_MARGIN: float = 0.12
const MAX_CLEARANCE_PULL: float = 0.35

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
## Viewmodel state: eased pose values, the cast spring, the spool and the clearance pulls.
var _cock: float = 0.0
var _bend: float = 0.0
var _whip: float = 0.0
var _whip_velocity: float = 0.0
var _rod_pull: float = 0.0
var _gun_pull: float = 0.0
var _spool_angle: float = 0.0
var _line_speed: float = 0.0
var _last_charge: float = 0.0
var _last_weapon: String = "ROD"
var _spool: Node3D
var _blank_mesh: ImmediateMesh
var _blank_material: StandardMaterial3D
var _guides: MultiMesh
var _materials: Dictionary = {}
var _jump_buffer: float = 0.0
var _coyote_time: float = 0.0
var _reset_position: Vector3 = Vector3.ZERO
var _reset_pending: bool = false
var _previous_fall_speed: float = 0.0
## A geyser's throw (W2) comes with a soft landing: the next touchdown within _cushion_time takes no
## fall damage, unless the player climbs above _cushion_ceiling on their own first.
var _cushion_time: float = 0.0
var _cushion_ceiling: float = INF
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
var _slam_cooldown: float = 0.0
var _previous_velocity: Vector3 = Vector3.ZERO


func _ready() -> void:
	mass = 75.0
	lock_rotation = true
	can_sleep = false
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 6
	collision_layer = 2
	collision_mask = 1 | 8              # the world, and enemy bodies: the player cannot walk through a hound
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
	camera.far = 1500.0                 # the practice range is 1 km long, with its skyline beyond it
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
	_slam_cooldown = maxf(0.0, _slam_cooldown - step)
	_update_cushion(step)
	for index in state.get_contact_count():
		var other: Object = state.get_contact_collider_object(index)
		if other is Node and (other as Node).is_in_group("enemies"):
			_try_slam(other as Node3D, state)
			continue
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
	_previous_velocity = state.linear_velocity
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
	var damage: float = landing_damage(impact)
	if _cushion_time > 0.0:
		damage = 0.0
		_cushion_time = 0.0
	if active and damage > 0.0:
		take_damage.call_deferred(damage, "impact", Vector3.INF)


func _try_slam(target: Node3D, state: PhysicsDirectBodyState3D) -> void:
	var speed: float = _previous_velocity.length()
	if not active or _slam_cooldown > 0.0 or speed < SLAM_MIN_SPEED or not target.has_method("take_damage"):
		return
	_slam_cooldown = SLAM_COOLDOWN
	target.call_deferred("take_damage", slam_damage(speed), "slam")
	state.linear_velocity = _previous_velocity * 0.75 + Vector3.UP * 3.0
	add_shake(0.35)
	slammed.emit(target, speed)


## Damage an enemy takes when the player hits it at speed m/s (W3).
static func slam_damage(speed: float) -> float:
	if speed < SLAM_MIN_SPEED:
		return 0.0
	return (speed - SLAM_FREE_SPEED) * SLAM_DAMAGE_PER_MS


## The next landing within seconds is soft, as long as the player stays below ceiling (a world y).
func cushion_landing(ceiling: float, seconds: float = 10.0) -> void:
	_cushion_time = seconds
	_cushion_ceiling = ceiling


func _update_cushion(step: float) -> void:
	if _cushion_time <= 0.0:
		return
	_cushion_time = maxf(0.0, _cushion_time - step)
	if global_position.y > _cushion_ceiling:
		_cushion_time = 0.0


## Health lost when landing at impact m/s of downward speed (S1).
static func landing_damage(impact: float) -> float:
	if impact <= FALL_DAMAGE_SPEED:
		return 0.0
	return (impact - FALL_DAMAGE_SPEED) / (FALL_LETHAL_SPEED - FALL_DAMAGE_SPEED) * FALL_LETHAL_DAMAGE


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
	# Steps need move input: coasting or sliding on momentum with no input makes no footstep sound (A4).
	if ground_speed < 0.5 or move_input.length() <= 0.05:
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
	_update_viewmodel(delta)


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


## Per-frame state from main. charge and tension drive the rod; weapon picks the model. line_speed
## is metres of line paying out (positive) or reeling in (negative) per second and spins the spool.
## It defaults to 0, so callers that only pass the first three values still work.
func set_feedback(charge: float, tension: float, weapon: String, line_speed: float = 0.0) -> void:
	# A charge that drops to zero on the rod is the cast: the tip whips forward and recoils.
	if _last_charge > CAST_MIN_CHARGE and charge <= 0.0 and weapon == "ROD" and _last_weapon == "ROD":
		_whip_velocity -= WHIP_KICK
	_last_charge = charge
	_last_weapon = weapon
	charge_feedback = charge
	tension_feedback = clampf(tension / 22000.0, 0.0, 1.0)
	_line_speed = line_speed
	rod_model.visible = weapon == "ROD"
	gun_model.visible = weapon == "SIDEARM"


func shot_effect() -> void:
	kick = 1.0
	_shot_flash = 0.045


## Materials are cached by colour, so every part of one colour shares one material.
func _material(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var key: String = "%s/%s" % [color.to_html(), str(unshaded)]
	if _materials.has(key):
		return _materials[key] as StandardMaterial3D
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.35
	if not unshaded:
		result.albedo_texture = preload("res://assets/dreamscape/porcelain.png")
	if unshaded:
		result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_materials[key] = result
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


## Builds both viewmodels under the camera. The rod is a grip, reel, tapered blank, guides and tip;
## the sidearm is a small pistol. Both are shown or hidden by set_feedback.
func _build_viewmodel() -> void:
	rod_model = Node3D.new()
	camera.add_child(rod_model)
	var grip := _box(rod_model, Vector3(0.075, 0.08, 0.4), ROD_GRIP, Color("bdcfd6"))
	grip.rotation.x = -0.12
	_box(rod_model, Vector3(0.08, 0.084, 0.045), Vector3(0.32, -0.27, -0.69), Color("b4a276"))
	_box(rod_model, Vector3(0.12, 0.10, 0.15), Vector3(0.32, -0.34, -0.6), Color("34434d"))
	_build_spool()
	_build_blank()
	rod_tip = Node3D.new()
	rod_tip.position = ROD_TIP
	rod_model.add_child(rod_tip)
	_box(rod_model, Vector3(0.10, 0.11, 0.2), Vector3(0.33, -0.34, -0.37), Color("70616a"))
	_box(rod_model, Vector3(0.12, 0.14, 0.38), Vector3(0.34, -0.40, -0.17), Color("536d7d"))
	_build_sidearm()


## The reel spool sits on a pivot so it can turn about its axle. A dark stripe on the rim shows the turn.
func _build_spool() -> void:
	_spool = Node3D.new()
	_spool.position = SPOOL_CENTER
	rod_model.add_child(_spool)
	var reel := MeshInstance3D.new()
	var drum := CylinderMesh.new()
	drum.top_radius = SPOOL_RADIUS
	drum.bottom_radius = SPOOL_RADIUS
	drum.height = 0.08
	drum.radial_segments = 12
	reel.mesh = drum
	reel.material_override = _material(Color("b4a276"))
	reel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The drum's axis is laid along x so it turns about the same axle as the pivot.
	reel.rotation.z = PI * 0.5
	_spool.add_child(reel)
	_box(_spool, Vector3(0.09, 0.014, 0.014), Vector3(0.0, SPOOL_RADIUS, 0.0), Color("34434d"))


## The blank is one tapered tube rebuilt each frame (one surface, one draw call). The guides are a
## MultiMesh, so all of them also cost one draw call.
func _build_blank() -> void:
	_blank_material = StandardMaterial3D.new()
	_blank_material.albedo_color = Color("526d80")
	_blank_material.albedo_texture = preload("res://assets/dreamscape/porcelain.png")
	_blank_material.roughness = 0.35
	# The tube is open at both ends and seen from inside at the butt, so draw both faces.
	_blank_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_blank_mesh = ImmediateMesh.new()
	rod_bend = MeshInstance3D.new()
	rod_bend.mesh = _blank_mesh
	rod_bend.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rod_model.add_child(rod_bend)
	var guide_set := MultiMesh.new()
	guide_set.transform_format = MultiMesh.TRANSFORM_3D
	guide_set.mesh = _build_guide_mesh()
	guide_set.instance_count = GUIDE_FRACTIONS.size()
	_guides = guide_set
	var guide_view := MultiMeshInstance3D.new()
	guide_view.multimesh = _guides
	guide_view.material_override = _material(Color("b4a276"))
	guide_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rod_model.add_child(guide_view)


## The pistol matches the rod's palette: frame, slide, sights, grip, magazine and a muzzle flash
## that shows on each shot.
func _build_sidearm() -> void:
	gun_model = Node3D.new()
	camera.add_child(gun_model)
	_box(gun_model, Vector3(0.085, 0.085, 0.34), Vector3(0.27, -0.25, -0.5), Color("4b606f"))
	_box(gun_model, Vector3(0.078, 0.05, 0.38), Vector3(0.27, -0.19, -0.52), Color("bdcfd6"))
	_box(gun_model, Vector3(0.04, 0.04, 0.06), Vector3(0.27, -0.205, -0.80), Color("202c36"))
	_box(gun_model, Vector3(0.012, 0.02, 0.02), Vector3(0.27, -0.15, -0.72), Color("b4a276"))
	_box(gun_model, Vector3(0.04, 0.02, 0.03), Vector3(0.27, -0.15, -0.36), Color("34434d"))
	var grip := _box(gun_model, Vector3(0.07, 0.17, 0.09), Vector3(0.27, -0.33, -0.44), Color("536d7d"))
	grip.rotation.x = -0.12
	_box(gun_model, Vector3(0.02, 0.05, 0.11), Vector3(0.27, -0.27, -0.46), Color("34434d"))
	_box(gun_model, Vector3(0.06, 0.02, 0.085), Vector3(0.27, -0.42, -0.44), Color("a4b8c2"))
	_box(gun_model, Vector3(0.10, 0.12, 0.17), Vector3(0.27, -0.35, -0.42), Color("70616a"))
	_box(gun_model, Vector3(0.13, 0.14, 0.28), Vector3(0.28, -0.41, -0.22), Color("536d7d"))
	muzzle = _box(gun_model, Vector3(0.12, 0.10, 0.10), Vector3(0.27, -0.205, -0.86), Color("a8d6df"))
	muzzle.material_override = _material(Color("e0eef1"), true)
	muzzle.visible = false
	gun_model.visible = false


## One viewmodel pass per frame: eases the pose, runs the cast spring, spins the spool, keeps both
## models out of walls and rebuilds the blank. rod_tip is updated even while the sidearm is out,
## because the line still leaves from it.
func _update_viewmodel(delta: float) -> void:
	kick = move_toward(kick, 0.0, delta * 3.2)
	_shot_flash = maxf(0.0, _shot_flash - delta)
	muzzle.visible = _shot_flash > 0.0
	_cock = lerpf(_cock, charge_feedback, minf(1.0, delta * 14.0))
	_bend = lerpf(_bend, tension_feedback, minf(1.0, delta * 10.0))
	_update_whip(delta)
	_spool_angle = fposmod(_spool_angle + _line_speed / SPOOL_RADIUS * delta, TAU)
	_spool.rotation.x = _spool_angle
	_rod_pull = _ease_pull(_rod_pull, _clearance_pull(ROD_GRIP, ROD_TIP), delta)
	rod_model.position = Vector3(0.0, -_cock * 0.08, _cock * 0.16 + _rod_pull)
	# Tilting the rod up as it is pushed back keeps the tip clear of low walls.
	rod_model.rotation.x = _cock * 0.24 + _bend * 0.10 + _whip + _rod_pull * 0.6
	rod_tip.position = _blank_point(1.0)
	if rod_model.visible:
		_rebuild_blank()
		_place_guides()
	_gun_pull = _ease_pull(_gun_pull, _clearance_pull(GUN_GRIP, GUN_MUZZLE), delta)
	gun_model.position = Vector3(0.0, 0.0, _gun_pull)
	gun_model.rotation.x = kick * 0.18


## Damped spring for the cast. The release kicks the tip forward; the spring carries it past rest
## and recoils it back, then it settles.
func _update_whip(delta: float) -> void:
	var accel: float = -WHIP_STIFFNESS * _whip - WHIP_DAMPING * _whip_velocity
	_whip_velocity += accel * delta
	_whip += _whip_velocity * delta


## Forward clearance. A ray runs in camera space from the grip to the rest tip. If world geometry
## stands in front of the tip, it returns how far the rod must slide back toward the camera.
func _clearance_pull(from_local: Vector3, tip_local: Vector3) -> float:
	var world: World3D = get_world_3d()
	if world == null or not is_instance_valid(camera):
		return 0.0
	var query := PhysicsRayQueryParameters3D.create(camera.to_global(from_local), camera.to_global(tip_local), 1)
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return 0.0
	var hit_depth: float = camera.to_local(hit["position"] as Vector3).z
	return clampf(hit_depth + CLEARANCE_MARGIN - tip_local.z, 0.0, MAX_CLEARANCE_PULL)


## Slides back quickly when a wall appears and eases out slowly, so the rod never snaps.
func _ease_pull(current: float, target: float, delta: float) -> float:
	var rate: float = 18.0 if target > current else 4.0
	return lerpf(current, target, minf(1.0, delta * rate))


## Point on the blank at fraction f. The sag grows with f squared: the butt stays stiff and the
## tip bends the most.
func _blank_point(fraction: float) -> Vector3:
	var point: Vector3 = ROD_BUTT.lerp(ROD_TIP, fraction)
	point.y -= _bend * ROD_SAG * fraction * fraction
	return point


## Direction of the blank at fraction f (the derivative of _blank_point, normalised).
func _blank_tangent(fraction: float) -> Vector3:
	var direction: Vector3 = ROD_TIP - ROD_BUTT
	direction.y -= _bend * ROD_SAG * 2.0 * fraction
	return direction.normalized()


func _blank_radius(fraction: float) -> float:
	return lerpf(BLANK_BUTT_RADIUS, BLANK_TIP_RADIUS, fraction)


## Frame along the blank: x is the side, y is up and z points along the tangent toward the tip.
func _blank_basis(fraction: float) -> Basis:
	var tangent: Vector3 = _blank_tangent(fraction)
	var side: Vector3 = tangent.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = Vector3.RIGHT
	side = side.normalized()
	return Basis(side, side.cross(tangent).normalized(), tangent)


## Ring of BLANK_SIDES points around the blank at fraction f.
func _ring(fraction: float) -> PackedVector3Array:
	var frame: Basis = _blank_basis(fraction)
	var centre: Vector3 = _blank_point(fraction)
	var radius: float = _blank_radius(fraction)
	var ring := PackedVector3Array()
	for side_index in range(BLANK_SIDES):
		var angle: float = TAU * float(side_index) / float(BLANK_SIDES)
		ring.append(centre + (frame.x * cos(angle) + frame.y * sin(angle)) * radius)
	return ring


## Rebuilds the tapered tube from the butt to the tip as quads split into triangles. Immediate
## surfaces carry no normals unless set, so each vertex gets the radial direction from its ring centre.
func _rebuild_blank() -> void:
	_blank_mesh.clear_surfaces()
	_blank_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _blank_material)
	var previous: PackedVector3Array = _ring(0.0)
	var previous_centre: Vector3 = _blank_point(0.0)
	for segment in range(1, BLANK_SEGMENTS + 1):
		var fraction: float = float(segment) / float(BLANK_SEGMENTS)
		var current: PackedVector3Array = _ring(fraction)
		var current_centre: Vector3 = _blank_point(fraction)
		for side in range(BLANK_SIDES):
			var next_side: int = (side + 1) % BLANK_SIDES
			_emit_blank_vertex(previous[side], previous_centre)
			_emit_blank_vertex(current[side], current_centre)
			_emit_blank_vertex(current[next_side], current_centre)
			_emit_blank_vertex(previous[side], previous_centre)
			_emit_blank_vertex(current[next_side], current_centre)
			_emit_blank_vertex(previous[next_side], previous_centre)
		previous = current
		previous_centre = current_centre
	_blank_mesh.surface_end()


## One blank vertex with its outward normal (from the ring centre) so the porcelain catches the light.
func _emit_blank_vertex(point: Vector3, centre: Vector3) -> void:
	_blank_mesh.surface_set_normal((point - centre).normalized())
	_blank_mesh.surface_add_vertex(point)


## Each guide is the shared torus, laid across the blank at its fraction and sized to the blank there.
func _place_guides() -> void:
	for index in range(GUIDE_FRACTIONS.size()):
		var fraction: float = GUIDE_FRACTIONS[index]
		var guide_scale: float = _blank_radius(fraction) + GUIDE_GAP
		var frame: Basis = _blank_basis(fraction).scaled(Vector3.ONE * guide_scale)
		_guides.set_instance_transform(index, Transform3D(frame, _blank_point(fraction)))


## One unit torus for every guide: major radius 1 and tube GUIDE_TUBE, lying in the XY plane with its
## axis along z, which matches the blank frame.
func _build_guide_mesh() -> ArrayMesh:
	var major: int = 10
	var minor: int = 4
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for i in range(major):
		var theta: float = TAU * float(i) / float(major)
		var radial := Vector3(cos(theta), sin(theta), 0.0)
		for j in range(minor):
			var phi: float = TAU * float(j) / float(minor)
			verts.append(radial * (1.0 + GUIDE_TUBE * cos(phi)) + Vector3(0.0, 0.0, GUIDE_TUBE * sin(phi)))
			normals.append(radial * cos(phi) + Vector3(0.0, 0.0, sin(phi)))
	for i in range(major):
		for j in range(minor):
			var a: int = i * minor + j
			var b: int = ((i + 1) % major) * minor + j
			var c: int = ((i + 1) % major) * minor + (j + 1) % minor
			var d: int = i * minor + (j + 1) % minor
			for index in [a, b, c, a, c, d]:
				indices.append(index)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
