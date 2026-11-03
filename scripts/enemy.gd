extends CharacterBody3D

## Enemy kinds (CONTRACT 4.13): the hound is a ground pursuer that follows the level navmesh; the
## sentry is a fixed turret with a telegraphed shot. The hound's states:
##   PATROL  circles its patrol centre (its spawn point, or where it gave up a chase)
##   ALERT   a short stop after first sight, so the player gets a tell
##   CHASE   follows the navmesh path to the player while it remembers them
##   ATTACK  the bite, then a short recovery
##   SEARCH  goes to the last seen spot, looks around, then returns to PATROL

signal fired(origin: Vector3, end: Vector3)
signal alerted(text: String)
signal died(kind: String, by: String)

enum State { PATROL, ALERT, CHASE, ATTACK, SEARCH }

const PATH_REFRESH := 0.4            # seconds between navmesh path queries
const SIGHT_RANGE_HOUND := 37.0
const SIGHT_RANGE_SENTRY := 46.0
const TRACK_MEMORY := 8.0            # seconds a hound keeps chasing after it last saw the player
const BITE_RANGE := 1.9              # metres, 3D
const BITE_DAMAGE := 12.0            # before damage_scale (CONTRACT 5.3)
const BITE_COOLDOWN := 1.1
const BITE_RECOVER := 0.6            # seconds in ATTACK after a bite
const ALERT_TIME := 0.5
const SEARCH_TIME := 10.0            # total search budget, look-around included
const REACH_HEIGHT := 1.6            # a player centre this far above the hound is out of reach
const REACH_PLANAR := 2.0            # a route must end this close to a high player to count as reaching them
const GIVE_UP_CHECKS := 3            # unreachable checks in a row (about 1.2 s) before giving up, so a jump is not a give-up
const PATROL_RADIUS := 4.0
const PATROL_SPEED := 1.8
const PATROL_TURN := 0.45            # radians per second around the patrol circle
const CHASE_SPEED := 5.1
const SEARCH_SPEED := 3.0
const KNOCKBACK_SPEED := 110.0
const KNOCKBACK_LIFT := 45.0
const GRAVITY := 18.0
const WAYPOINT_REACHED := 0.7        # metres: a route point counts as reached inside this radius

var target: Node3D
var kind: String = "hound"
var active: bool = false
var health: float = 70.0
var max_health: float = 70.0
var damage_scale: float = 1.0
var _dead: bool = false
var _clock: float = 0.0
var _attack_cooldown: float = 0.0
var _aim_time: float = 0.0
var _last_seen: Vector3
var _memory: float = 0.0
var _telegraph: MeshInstance3D
var _eye_material: StandardMaterial3D
var _visual: Node3D
var _alert_sent: bool = false
var _hurt_flash: float = 0.0
var _body_material: StandardMaterial3D
var _ray_clock: float = 0.0
var _visible_target: bool = false
var _locked_aim: Vector3
# Hound state.
var _state: State = State.PATROL
var _state_timer: float = 0.0        # counts down ALERT, ATTACK recovery and the SEARCH budget
var _search_arrived: bool = false
var _patrol_center: Vector3
var _patrol_angle: float = 0.0
var _giving_up: bool = false         # true while circling below a player it cannot reach
var _unreachable_checks: int = 0
var _path: PackedVector3Array = PackedVector3Array()
var _path_index: int = 0
var _path_timer: float = 0.0
var _legs: Array[Node3D] = []        # hip pivots, one per leg
var _knees: Array[Node3D] = []
var _leg_phase: Array[float] = []    # diagonal pairs share a phase, so the gait reads as a trot
var _gait: float = 0.0
var _head: Node3D


func setup(player: Node3D, enemy_kind: String, location: Vector3, params: Dictionary = {}) -> void:
	target = player
	kind = enemy_kind
	position = location
	_last_seen = location
	_patrol_center = location
	max_health = 70.0 if kind == "hound" else 105.0
	health = float(params.get("health", max_health))
	collision_layer = 8
	collision_mask = 1
	add_to_group("enemies")
	_build_body()


func set_active(value: bool) -> void:
	active = value
	if not value:
		velocity = Vector3.ZERO
		_aim_time = 0.0
		if is_instance_valid(_telegraph):
			_telegraph.visible = false


## True while the hound is alerted, chasing or biting. Feeds level threat_level().
func is_tracking() -> bool:
	return not _dead and (_state == State.ALERT or _state == State.CHASE or _state == State.ATTACK)


func _build_body() -> void:
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.46 if kind == "hound" else 0.65
	shape.height = 1.15 if kind == "hound" else 2.3
	collision.shape = shape
	collision.position.y = 0.62 if kind == "hound" else 1.15
	add_child(collision)
	_visual = Node3D.new()
	add_child(_visual)
	_body_material = _material(Color("252f33"))
	var armor := _material(Color("53605b"))
	var joints := _material(Color("101b20"))
	_eye_material = _material(Color("f7533c"), true)
	if kind == "hound":
		_build_hound(armor, joints)
	else:
		_mesh_box(Vector3(0, 0.23, 0), Vector3(1.45, 0.3, 1.45), joints)
		_mesh_box(Vector3(0, 0.95, 0), Vector3(0.3, 1.25, 0.3), armor)
		_mesh_box(Vector3(0, 1.62, 0), Vector3(1.13, 0.72, 0.8), _body_material)
		_mesh_box(Vector3(0, 1.65, -0.78), Vector3(0.24, 0.24, 1.25), joints)
		_mesh_box(Vector3(0, 1.91, -0.42), Vector3(0.72, 0.09, 0.06), _eye_material)
		_mesh_box(Vector3(-0.72, 1.5, 0.1), Vector3(0.28, 0.68, 0.48), armor)
		_mesh_box(Vector3(0.72, 1.5, 0.1), Vector3(0.28, 0.68, 0.48), armor)
		var line_mesh := CylinderMesh.new()
		line_mesh.top_radius = 0.018
		line_mesh.bottom_radius = 0.018
		line_mesh.height = 1.0
		line_mesh.radial_segments = 4
		_telegraph = MeshInstance3D.new()
		_telegraph.mesh = line_mesh
		_telegraph.material_override = _material(Color(1.0, 0.17, 0.09, 0.6), true)
		_telegraph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_telegraph.visible = false
		add_child(_telegraph)


## A low hound with a spine plate, a tail, a head with a glowing eye and four two-segment legs.
## One box per part (14 mesh instances in all), so the draw-call cost stays low.
func _build_hound(armor: StandardMaterial3D, joints: StandardMaterial3D) -> void:
	_mesh_box(Vector3(0, 0.72, 0), Vector3(0.72, 0.5, 1.5), _body_material)
	_mesh_box(Vector3(0, 1.0, -0.1), Vector3(0.5, 0.14, 1.1), armor)
	var tail := _mesh_box(Vector3(0, 0.9, 0.95), Vector3(0.12, 0.12, 0.8), joints)
	tail.rotation.x = -0.5
	_head = Node3D.new()
	_head.position = Vector3(0, 0.95, -0.85)
	_visual.add_child(_head)
	_mesh_box_in(_head, Vector3(0, 0, -0.1), Vector3(0.42, 0.36, 0.5), _body_material)
	_mesh_box_in(_head, Vector3(0, -0.14, -0.34), Vector3(0.3, 0.1, 0.42), joints)
	_mesh_box_in(_head, Vector3(0, 0.05, -0.37), Vector3(0.34, 0.07, 0.03), _eye_material)
	for side in [-1.0, 1.0]:
		for front in [-0.5, 0.5]:
			_add_leg(side, front, joints)


func _add_leg(side: float, front: float, joints: StandardMaterial3D) -> void:
	var hip := Node3D.new()
	hip.position = Vector3(side * 0.3, 0.6, front)
	_visual.add_child(hip)
	_mesh_box_in(hip, Vector3(0, -0.15, 0), Vector3(0.16, 0.3, 0.18), joints)
	var knee := Node3D.new()
	knee.position.y = -0.3
	hip.add_child(knee)
	_mesh_box_in(knee, Vector3(0, -0.15, 0), Vector3(0.12, 0.3, 0.14), joints)
	_legs.append(hip)
	_knees.append(knee)
	# Front-left with back-right, and front-right with back-left, move in step.
	_leg_phase.append(0.0 if side * front < 0.0 else PI)


func _physics_process(delta: float) -> void:
	if _dead or not active or not is_instance_valid(target):
		return
	_clock += delta
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_hurt_flash = maxf(0.0, _hurt_flash - delta)
	_body_material.albedo_color = Color("b44d37") if _hurt_flash > 0.0 else Color("252f33")
	var offset: Vector3 = target.global_position - global_position
	var distance: float = offset.length()
	_ray_clock -= delta
	if _ray_clock <= 0.0:
		_ray_clock = 0.12
		var sight_range: float = SIGHT_RANGE_HOUND if kind == "hound" else SIGHT_RANGE_SENTRY
		_visible_target = distance < sight_range and _can_see_player()
	if _visible_target:
		_last_seen = target.global_position
		_memory = TRACK_MEMORY
		if not _alert_sent:
			_alert_sent = true
			alerted.emit("HOUND TRACKING" if kind == "hound" else "SENTRY ACQUIRING — FIND COVER")
	else:
		_memory = maxf(0.0, _memory - delta)
		if _memory <= 0.0:
			_alert_sent = false
	if kind == "hound":
		_tick_hound(delta, distance)
	else:
		_tick_sentry(delta)


func _tick_hound(delta: float, distance: float) -> void:
	_path_timer -= delta
	if _path_timer <= 0.0:
		_refresh_path()
	if _visible_target and distance < BITE_RANGE and _attack_cooldown <= 0.0:
		_bite()
	else:
		_run_state(delta)
	_animate_hound(delta, Vector2(velocity.x, velocity.z).length())
	_eye_material.emission_energy_multiplier = lerpf(_eye_material.emission_energy_multiplier, _eye_glow(), minf(1.0, delta * 6.0))


func _run_state(delta: float) -> void:
	var sees: bool = _visible_target and not _giving_up
	match _state:
		State.PATROL:
			if sees:
				_set_state(State.ALERT)
				return
			_patrol_angle = fmod(_patrol_angle + delta * PATROL_TURN, TAU)
			_steer(_patrol_point(), PATROL_SPEED, delta, false)
		State.ALERT:
			_face_target(delta)
			_halt(delta)
			_state_timer -= delta
			if _state_timer <= 0.0:
				_set_state(State.CHASE)
		State.CHASE:
			if _memory <= 0.0:
				_set_state(State.SEARCH)
				return
			# Straight-line steering is only safe when the player is in sight and not above the hound's reach.
			var direct: bool = _visible_target and not _is_high()
			_steer(target.global_position, CHASE_SPEED, delta, direct)
		State.ATTACK:
			_face_target(delta)
			_halt(delta)
			_state_timer -= delta
			if _state_timer <= 0.0:
				_set_state(State.CHASE)
		State.SEARCH:
			_run_search(delta, sees)


## Walks to the last seen spot, looks around there, then gives up and returns to PATROL. The budget
## runs out even if the spot is unreachable, so a search can never last forever.
func _run_search(delta: float, sees: bool) -> void:
	if sees:
		_set_state(State.ALERT)
		return
	_state_timer -= delta
	if _state_timer <= 0.0:
		_set_state(State.PATROL)
		return
	if not _search_arrived and _planar_distance(_last_seen) < 1.0:
		_search_arrived = true
	if _search_arrived:
		_halt(delta)
	else:
		_steer(_last_seen, SEARCH_SPEED, delta, false)


func _set_state(next: State) -> void:
	if next == _state:
		return
	_state = next
	_path_timer = 0.0                    # plan a route to the new goal on the next frame
	match next:
		State.ALERT:
			_state_timer = ALERT_TIME
			_play("hound_alert")
		State.SEARCH:
			_state_timer = SEARCH_TIME
			_search_arrived = false


func _bite() -> void:
	_attack_cooldown = BITE_COOLDOWN
	_set_state(State.ATTACK)
	_state_timer = BITE_RECOVER
	_play("hound_bite")
	target.call("take_damage", BITE_DAMAGE * damage_scale, kind, global_position)
	if target is RigidBody3D:
		# The player has no knockback method, so the bite pushes the RigidBody3D directly.
		var push: Vector3 = (target.global_position - global_position).normalized() * KNOCKBACK_SPEED
		(target as RigidBody3D).apply_central_impulse(push + Vector3.UP * KNOCKBACK_LIFT)
	alerted.emit("HOUND ATTACK — GET AIRBORNE")


func _goal_point() -> Vector3:
	match _state:
		State.CHASE:
			return target.global_position
		State.SEARCH:
			return _last_seen
	return _patrol_point()


func _patrol_point() -> Vector3:
	return _patrol_center + Vector3(sin(_patrol_angle), 0.0, cos(_patrol_angle)) * PATROL_RADIUS


## Requests a new navmesh route to the current goal. The give-up check runs first, because it can
## change the state and with it the goal.
func _refresh_path() -> void:
	_update_giveup()
	var wants_route: bool = _state == State.PATROL or _state == State.CHASE or _state == State.SEARCH
	_path = _query_path(_goal_point()) if wants_route else PackedVector3Array()
	_path_index = 0
	_path_timer = PATH_REFRESH


## A hound that cannot reach a player standing high up stops chasing and circles where it is.
## Reachability is checked on each path refresh, and a few misses in a row are needed to give up.
func _update_giveup() -> void:
	if not _is_high():
		_unreachable_checks = 0
		_giving_up = false
		return
	if _route_reaches(_query_path(target.global_position)):
		_unreachable_checks = 0
		_giving_up = false
		return
	_unreachable_checks += 1
	if _giving_up or _unreachable_checks < GIVE_UP_CHECKS:
		return
	if _state == State.ALERT or _state == State.CHASE:
		_giving_up = true
		_patrol_center = global_position
		_unreachable_checks = 0
		_set_state(State.PATROL)


func _is_high() -> bool:
	return target.global_position.y - global_position.y > REACH_HEIGHT


## True when the route ends next to the player and at about their height. A route that ends on the
## floor under a raised platform is not a way up, because the hound cannot climb.
func _route_reaches(route: PackedVector3Array) -> bool:
	if route.is_empty():
		return false
	var end: Vector3 = route[route.size() - 1]
	var player_position: Vector3 = target.global_position
	var planar: float = Vector2(end.x - player_position.x, end.z - player_position.z).length()
	var gap: float = player_position.y - end.y
	return planar < REACH_PLANAR and gap < REACH_HEIGHT


## Navmesh route from the hound to a point (CONTRACT 4.11). Empty when the level has no navmesh yet,
## in which case steering falls back to probes.
func _query_path(to: Vector3) -> PackedVector3Array:
	var level: Node = get_parent()
	if level == null or not level.has_method("get_nav_path"):
		return PackedVector3Array()
	var route: PackedVector3Array = level.call("get_nav_path", global_position, to)
	return route


func _next_waypoint() -> Vector3:
	while _path_index < _path.size() - 1 and _planar_distance(_path[_path_index]) < WAYPOINT_REACHED:
		_path_index += 1
	return _path[_path_index]


## Moves toward goal. Follows the navmesh route when there is one, unless direct is set.
func _steer(goal: Vector3, speed: float, delta: float, direct: bool) -> void:
	var on_route: bool = not direct and not _path.is_empty()
	var point: Vector3 = _next_waypoint() if on_route else goal
	var direction: Vector3 = point - global_position
	direction.y = 0.0
	var desired: Vector3 = Vector3.ZERO
	if direction.length() > 0.2:
		direction = direction.normalized()
		if not on_route:
			direction = _clear_direction(direction)
		desired = direction * speed
		_face(direction, delta)
	_move_on_ground(desired, delta)


func _halt(delta: float) -> void:
	_move_on_ground(Vector3.ZERO, delta)


func _move_on_ground(desired: Vector3, delta: float) -> void:
	velocity.x = move_toward(velocity.x, desired.x, delta * 15.0)
	velocity.z = move_toward(velocity.z, desired.z, delta * 15.0)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.5
	move_and_slide()


## Fallback steering without a navmesh: probe ahead and slide around crates rather than through them.
func _clear_direction(direction: Vector3) -> Vector3:
	var ray_start: Vector3 = global_position + Vector3.UP * 0.7
	var query := PhysicsRayQueryParameters3D.create(ray_start, ray_start + direction * 2.5, 1)
	var obstacle: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if obstacle.is_empty():
		return direction
	var normal: Vector3 = obstacle["normal"]
	var tangent: Vector3 = direction.slide(normal).normalized()
	if tangent.length_squared() < 0.1:
		tangent = Vector3(-normal.z, 0, normal.x)
	if tangent.dot(direction) < -0.1:
		tangent = -tangent
	return (direction * 0.15 + tangent).normalized()


func _face(direction: Vector3, delta: float) -> void:
	_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-direction.x, -direction.z), delta * 9.0)


func _face_target(delta: float) -> void:
	var to_player: Vector3 = target.global_position - global_position
	to_player.y = 0.0
	if to_player.length() > 0.01:
		_face(to_player.normalized(), delta)


func _planar_distance(point: Vector3) -> float:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length()


## Leg swing and knee bend follow the speed, so the legs are still when the hound is still.
func _animate_hound(delta: float, planar_speed: float) -> void:
	var stride: float = clampf(planar_speed / CHASE_SPEED, 0.0, 1.0)
	_gait = fmod(_gait + delta * (4.0 + planar_speed * 2.0), TAU)
	for i in range(_legs.size()):
		var phase: float = _gait + _leg_phase[i]
		_legs[i].rotation.x = sin(phase) * stride * 0.55
		_knees[i].rotation.x = maxf(0.0, cos(phase)) * stride * 0.9
	_visual.position.y = absf(sin(_gait)) * stride * 0.05
	var lunge: float = -0.45 if _state == State.ATTACK else 0.0
	var look: float = sin(_clock * 1.4) * 0.8 if (_state == State.SEARCH and _search_arrived) else 0.0
	_head.rotation.x = lerpf(_head.rotation.x, lunge, minf(1.0, delta * 8.0))
	_head.rotation.y = lerpf(_head.rotation.y, look, minf(1.0, delta * 5.0))


func _eye_glow() -> float:
	match _state:
		State.ALERT:
			return 2.6
		State.ATTACK:
			return 3.2
		State.CHASE:
			return 1.8
		State.SEARCH:
			return 1.2
	return 0.9


func _tick_sentry(delta: float) -> void:
	if not _visible_target or _attack_cooldown > 0.0:
		_aim_time = maxf(0.0, _aim_time - delta * 2.0)
		_telegraph.visible = false
		if _memory <= 0.0:
			_visual.rotation.y = sin(_clock * 0.4) * 0.8
		return
	_aim_time += delta
	var origin: Vector3 = global_position + Vector3(0, 1.68, 0)
	# The last fraction of the wind-up commits the aim: a dodge can evade the shot.
	if _aim_time < 1.22:
		_locked_aim = target.global_position + Vector3.UP * 0.2
	var aim: Vector3 = _locked_aim - origin
	_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-aim.x, -aim.z), delta * 5.0)
	_telegraph.visible = true
	_telegraph.global_position = origin + aim * 0.5
	_telegraph.quaternion = Quaternion(Vector3.UP, aim.normalized())
	_telegraph.scale = Vector3(1, aim.length(), 1)
	_eye_material.emission_energy_multiplier = 1.0 + _aim_time * 2.0
	if _aim_time >= 1.6:
		_aim_time = 0.0
		_attack_cooldown = 1.15
		_telegraph.visible = false
		var end: Vector3 = origin + aim.normalized() * 65.0
		var query := PhysicsRayQueryParameters3D.create(origin, end, 1 | 2 | 4)
		query.exclude = [get_rid()]
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			end = hit["position"]
			if hit["collider"] == target:
				target.call("take_damage", 16.0 * damage_scale, kind, global_position)
		fired.emit(origin, end)


func _can_see_player() -> bool:
	var origin: Vector3 = global_position + Vector3.UP * (0.8 if kind == "hound" else 1.68)
	var end: Vector3 = target.global_position + Vector3.UP * 0.2
	var query := PhysicsRayQueryParameters3D.create(origin, end, 1 | 2)
	query.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit["collider"] == target


func take_damage(amount: float, source: String = "bullet") -> void:
	if _dead or amount <= 0.0:
		return
	health -= amount
	_hurt_flash = 0.16
	if is_instance_valid(target):
		_last_seen = target.global_position
		_memory = 8.0
	if health <= 0.0:
		# Only the first lethal hit gets here: _dead blocks every later call, so died fires once.
		_dead = true
		active = false
		died.emit(kind, source)
		_play("enemy_death")
		collision_layer = 0
		collision_mask = 0
		remove_from_group("enemies")
		if is_instance_valid(_telegraph):
			_telegraph.visible = false
		_eye_material.emission_enabled = false
		_eye_material.albedo_color = Color("101a1c")
		var tween := create_tween()
		tween.tween_property(_visual, "rotation:z", 1.35, 0.35)
		tween.parallel().tween_property(_visual, "position:y", -0.2, 0.35)
		tween.tween_interval(12.0)
		tween.tween_callback(queue_free)


## Positional sound through the audio node (CONTRACT 4.16). Silent when there is no audio node.
func _play(event: String) -> void:
	if not is_inside_tree():
		return
	var audio: Node = get_tree().get_first_node_in_group("game_audio")
	if audio != null and audio.has_method("play_at"):
		audio.call("play_at", event, global_position)


func _mesh_box(location: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	return _mesh_box_in(_visual, location, size, material)


func _mesh_box_in(parent: Node3D, location: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = material
	instance.position = location
	parent.add_child(instance)
	return instance


func _material(color: Color, glow: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.75
	if glow:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.4
		if color.a < 1.0:
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
