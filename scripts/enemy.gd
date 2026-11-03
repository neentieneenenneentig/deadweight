extends CharacterBody3D

## Enemy kinds (CONTRACT 4.13): the hound is a ground pursuer that follows the level navmesh; the
## sentry is a fixed tripod turret with a telegraphed shot; the drone hovers 4-10 m above its anchor
## and fires slow orbs that the player can dodge. The hound's states:
##   PATROL  circles its patrol centre (its spawn point, or where it gave up a chase)
##   ALERT   a short stop after first sight, so the player gets a tell
##   CHASE   follows the navmesh path to the player while it remembers them
##   ATTACK  the bite, then a short recovery
##   SEARCH  goes to the last seen spot, looks around, then returns to PATROL
## The drone's states are simpler (see _tick_drone): patrol, close to a standoff distance, charge,
## fire one orb, cool down.
## The dummy (E3) has no states: it never attacks, flashes when hit, and stands back up at full health
## DUMMY_REFILL seconds after a kill.

const FX = preload("res://scripts/fx.gd")

signal fired(origin: Vector3, end: Vector3)
signal alerted(text: String)
signal died(kind: String, by: String)

enum State { PATROL, ALERT, CHASE, ATTACK, SEARCH }

const PATH_REFRESH := 0.4            # seconds between navmesh path queries
const SIGHT_RANGE_HOUND := 37.0
const SIGHT_RANGE_SENTRY := 46.0
const SIGHT_RANGE_DRONE := 40.0
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

# Drone (DESIGN: floats 4-10 m up, patrols, closes to about 12 m, telegraphs, fires a slow orb).
const DRONE_HEALTH := 45.0
const DRONE_ALT_MIN := 4.0           # metres above the anchor
const DRONE_ALT_MAX := 10.0
const DRONE_ALT_MID := 7.0
const DRONE_ALT_SWING := 3.0         # the hover height drifts this far either side of the middle
const DRONE_SPEED := 6.0             # m/s
const DRONE_ACCEL := 12.0            # m/s^2, how quickly the drone changes velocity
const DRONE_PATROL_RADIUS := 6.0
const DRONE_PATROL_TURN := 0.3       # radians per second around the patrol circle
const DRONE_STANDOFF := 12.0         # metres (3D) from the player's aim point
const DRONE_FIRE_SLACK := 2.0        # a charge may start this far beyond the standoff distance
const DRONE_CHARGE := 0.9            # seconds of telegraph before the orb leaves
const DRONE_COMMIT := 0.3            # the last seconds of the charge freeze the aim, so a late dodge works
const DRONE_FIRE_COOLDOWN := 2.2
const DRONE_ORB_SPEED := 22.0        # m/s, slow enough to see and to dodge
const DRONE_ORB_RANGE := 40.0        # metres an orb travels before it burns out
const DRONE_ORB_DAMAGE := 14.0       # before damage_scale (CONTRACT 5.3)
const DRONE_ORB_MASK := 1 | 2        # the orb stops on world geometry and on the player
const DRONE_BLAST_RADIUS := 3.0
const DRONE_BLAST_DAMAGE := 25.0     # before damage_scale; only a player inside the radius takes it
const DRONE_ROTOR_SPIN := 40.0       # rad/s, visual only

# Training dummy (E3): a ceramic mannequin that never attacks, flashes when hit and refills after a kill.
const DUMMY_HEALTH := 60.0
const DUMMY_REFILL := 3.0            # seconds down before it stands back up at full health
const DUMMY_FLASH := Color("9ff0e6") # hit flash: pale cyan, so it reads as a target rather than a threat
const PORCELAIN := Color("e8ddc7")

# Death FX (E3): every kind throws a porcelain-shard burst, scaled by kind, once per death (see _die).
const SHARD_COLOR := Color("f1e6d2")
const DEATH_SCALE := {"hound": 0.8, "sentry": 1.1, "drone": 1.0, "dummy": 0.7}

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
# Sentry state: the turret head is the only part that turns.
var _turret: Node3D
# Drone state.
var _drone_charge: float = 0.0       # seconds left in the charge; 0 when not charging
var _orb_cooldown: float = 0.0
var _orbs: Array[Dictionary] = []    # orbs in flight: {node, direction, travelled}
var _rotors: Array[Node3D] = []
# Dummy state.
var _refill_left: float = 0.0        # seconds until a downed dummy stands back up


func setup(player: Node3D, enemy_kind: String, location: Vector3, params: Dictionary = {}) -> void:
	target = player
	kind = enemy_kind
	position = location
	_last_seen = location
	_patrol_center = location
	match kind:
		"hound":
			max_health = 70.0
		"drone":
			max_health = DRONE_HEALTH
		"dummy":
			max_health = DUMMY_HEALTH
		_:
			max_health = 105.0
	health = float(params.get("health", max_health))
	collision_layer = 8
	collision_mask = 1
	if kind == "drone":
		# A flying body: no floor snapping and no gravity, so its velocity is the only motion.
		motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	add_to_group("enemies")
	_build_body()


func set_active(value: bool) -> void:
	active = value
	if not value:
		velocity = Vector3.ZERO
		_aim_time = 0.0
		_drone_charge = 0.0
		if is_instance_valid(_telegraph):
			_telegraph.visible = false


## True while the hound is alerted, chasing or biting; while the drone can see the player; and while the
## sentry has the player in sight or is charging its shot. The sentry's wind-up (_aim_time) counts, and it
## decays after sight is lost, so the sentry keeps tracking until its wind-up has cooled. Dummies never
## track. Feeds level threat_level().
func is_tracking() -> bool:
	if _dead or kind == "dummy":
		return false
	if kind == "drone":
		return _visible_target
	if kind == "sentry":
		return _visible_target or _aim_time > 0.0
	return _state == State.ALERT or _state == State.CHASE or _state == State.ATTACK


func _build_body() -> void:
	var collision := CollisionShape3D.new()
	if kind == "drone":
		var ball := SphereShape3D.new()
		ball.radius = 0.45
		collision.shape = ball
	else:
		var shape := CapsuleShape3D.new()
		shape.radius = 0.46 if kind == "hound" else 0.65
		shape.height = 1.15 if kind == "hound" else 2.3
		collision.shape = shape
		collision.position.y = 0.62 if kind == "hound" else 1.15
	add_child(collision)
	_visual = Node3D.new()
	add_child(_visual)
	_body_material = _material(Color("e8ddc7"))
	_body_material.albedo_texture = preload("res://assets/dreamscape/porcelain.png")
	_body_material.roughness = 0.3
	var armor := _material(Color("b78b9f"))
	var joints := _material(Color("51435e"))
	_eye_material = _material(Color("f7533c"), true)
	match kind:
		"hound":
			_build_hound(armor, joints)
		"drone":
			_build_drone(armor, joints)
		"dummy":
			_build_dummy(armor, joints)
		_:
			_build_sentry(armor, joints)


## A porcelain tea hound: handle, lid, spout and four jointed legs. Its red eye and
## original animation pivots preserve the attack tells. Still 14 mesh instances.
func _build_hound(armor: StandardMaterial3D, joints: StandardMaterial3D) -> void:
	_dream_oval(_visual, Vector3(0, 0.72, 0), Vector3(0.88, 0.65, 1.35), _body_material)
	_dream_oval(_visual, Vector3(0, 1.05, -0.1), Vector3(0.62, 0.16, 0.7), armor)
	var handle := TorusMesh.new()
	handle.inner_radius = 0.21
	handle.outer_radius = 0.31
	handle.rings = 16
	handle.ring_segments = 6
	var tail := _mesh_box(Vector3(0, 0.82, 0.76), Vector3.ONE, joints)
	tail.mesh = handle
	tail.rotation.z = PI * 0.5
	_head = Node3D.new()
	_head.position = Vector3(0, 0.95, -0.85)
	_visual.add_child(_head)
	_dream_oval(_head, Vector3(0, 0, -0.1), Vector3(0.42, 0.36, 0.5), _body_material)
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


## A tripod turret: three splayed legs meet at a column, and the head on top turns to aim. The legs
## and column never move; only the head pivot (_turret) yaws.
func _build_sentry(armor: StandardMaterial3D, joints: StandardMaterial3D) -> void:
	var apex := Vector3(0, 1.25, 0)
	for i in range(3):
		var angle: float = float(i) * TAU / 3.0
		var foot := Vector3(cos(angle) * 0.95, 0.03, sin(angle) * 0.95)
		_strut(_visual, apex, foot, 0.09, joints)
		_mesh_box(foot, Vector3(0.24, 0.06, 0.24), joints)   # foot pad, bottom on the floor
	_mesh_box(Vector3(0, 0.7, 0), Vector3(0.22, 1.4, 0.22), armor)   # column, top hidden in the head
	_turret = Node3D.new()
	_turret.position = Vector3(0, 1.62, 0)
	_visual.add_child(_turret)
	_dream_oval(_turret, Vector3.ZERO, Vector3(1.13, 1.0, 0.65), _body_material)
	_mesh_box_in(_turret, Vector3(0, 0.03, -0.78), Vector3(0.24, 0.24, 1.25), joints)   # barrel, front is -Z
	_mesh_box_in(_turret, Vector3(0, 0.29, -0.42), Vector3(0.72, 0.09, 0.06), _eye_material)
	_dream_oval(_turret, Vector3(-0.5, 0.47, 0.1), Vector3(0.44, 0.22, 0.42), armor)
	_dream_oval(_turret, Vector3(0.5, 0.47, 0.1), Vector3(0.44, 0.22, 0.42), armor)
	_mesh_box_in(_turret, Vector3(0, 0.5, 0.1), Vector3(0.4, 0.12, 0.4), joints)          # sensor housing
	_merge_fittings(_visual, joints)
	_build_aim_line()


## A hovering drone: a dark body with a glowing eye on its nose, four arms and four rotors. Each rotor
## is its own node so it can spin; the rotors are translucent discs.
func _build_drone(armor: StandardMaterial3D, joints: StandardMaterial3D) -> void:
	_dream_oval(_visual, Vector3.ZERO, Vector3(0.78, 0.58, 0.72), _body_material)
	_dream_oval(_visual, Vector3(0, 0.30, 0), Vector3(0.42, 0.16, 0.42), armor)
	_mesh_box(Vector3(0, -0.02, -0.33), Vector3(0.28, 0.16, 0.05), _eye_material)
	var rotor_material := _material(Color(0.55, 0.62, 0.64, 0.28), true)
	for i in range(4):
		var angle: float = PI * 0.25 + float(i) * PI * 0.5
		var tip := Vector3(cos(angle) * 0.82, 0.0, sin(angle) * 0.82)
		_strut(_visual, Vector3.ZERO, tip, 0.07, joints)
		var rotor := Node3D.new()
		rotor.position = tip + Vector3(0, 0.13, 0)
		_visual.add_child(rotor)
		var disc := MeshInstance3D.new()
		var disc_mesh := CylinderMesh.new()
		disc_mesh.top_radius = 0.36
		disc_mesh.bottom_radius = 0.36
		disc_mesh.height = 0.03
		disc_mesh.radial_segments = 12
		disc.mesh = disc_mesh
		disc.material_override = rotor_material
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rotor.add_child(disc)
		_rotors.append(rotor)
	_build_aim_line()


## A ceramic tailor's mannequin on a round stand, with a cyan target ring on its chest. Six meshes, no
## joints and no aim line: the dummy only takes hits and shows where to aim.
func _build_dummy(armor: StandardMaterial3D, joints: StandardMaterial3D) -> void:
	_dream_oval(_visual, Vector3(0, 0.05, 0), Vector3(0.9, 0.1, 0.9), armor)                # round base
	_mesh_box(Vector3(0, 0.6, 0), Vector3(0.08, 1.1, 0.08), joints)                         # stand pole
	_dream_oval(_visual, Vector3(0, 1.25, 0), Vector3(0.6, 0.9, 0.42), _body_material)      # torso
	_dream_oval(_visual, Vector3(0, 1.66, 0), Vector3(0.95, 0.22, 0.46), armor)             # shoulder yoke
	_dream_oval(_visual, Vector3(0, 1.95, 0), Vector3(0.34, 0.42, 0.34), _body_material)   # head
	var torus := TorusMesh.new()
	torus.inner_radius = 0.2
	torus.outer_radius = 0.27
	torus.rings = 16
	torus.ring_segments = 6
	var ring := MeshInstance3D.new()
	ring.mesh = torus
	ring.material_override = _material(Color("5ad6c8"), true)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.rotation.x = PI * 0.5                                                             # a ring in the XY plane
	ring.position = Vector3(0, 1.25, 0.24)                                                 # on the +Z chest, where the range player comes from
	_visual.add_child(ring)


## Joins the sentry's fixed feet and struts into one mesh. They share a material and never animate,
## so one surface is cheaper to draw than one mesh per piece.
func _merge_fittings(parent: Node3D, material: Material) -> void:
	# The sentry's fixed feet and struts share a material and never animate.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for child: Node in parent.get_children():
		if child is MeshInstance3D and child.material_override == material:
			surface.append_from(child.mesh, 0, child.transform)
			child.free()
	var stand := MeshInstance3D.new()
	stand.mesh = surface.commit()
	stand.material_override = material
	stand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(stand)


## Smooth body part: a sphere scaled to an oval, so the porcelain shapes read as curved.
func _dream_oval(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 16
	sphere.rings = 8
	view.mesh = sphere
	view.position = at
	view.scale = size
	view.material_override = material
	parent.add_child(view)
	return view


## The red aim line used by the sentry's wind-up and the drone's charge. Hidden until needed.
func _build_aim_line() -> void:
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


## Stretches a thin box between two points, for tripod legs and drone arms.
func _strut(parent: Node3D, from: Vector3, to: Vector3, thickness: float, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(thickness, thickness, from.distance_to(to))
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.transform = Transform3D(Basis.looking_at((to - from).normalized(), Vector3.UP), (from + to) * 0.5)
	parent.add_child(instance)
	return instance


func _physics_process(delta: float) -> void:
	if kind == "dummy":
		_tick_dummy(delta)
		return
	if _dead:
		return
	if kind == "drone":
		# Orbs in flight keep moving even when the drone is switched off, so none freezes in mid-air.
		_update_orbs(delta)
	if not active or not is_instance_valid(target):
		return
	_clock += delta
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_hurt_flash = maxf(0.0, _hurt_flash - delta)
	_body_material.albedo_color = Color("b44d37") if _hurt_flash > 0.0 else Color("e8ddc7")
	var offset: Vector3 = target.global_position - global_position
	var distance: float = offset.length()
	_ray_clock -= delta
	if _ray_clock <= 0.0:
		_ray_clock = 0.12
		_visible_target = distance < _sight_range() and _can_see_player()
	if _visible_target:
		_last_seen = target.global_position
		_memory = TRACK_MEMORY
		if not _alert_sent:
			_alert_sent = true
			alerted.emit(_alert_text())
	else:
		_memory = maxf(0.0, _memory - delta)
		if _memory <= 0.0:
			_alert_sent = false
	match kind:
		"hound":
			_tick_hound(delta, distance)
		"drone":
			_tick_drone(delta)
		_:
			_tick_sentry(delta)


func _alert_text() -> String:
	match kind:
		"hound":
			return "HOUND TRACKING"
		"drone":
			return "DRONE ACQUIRING — FIND COVER"
	return "SENTRY ACQUIRING — FIND COVER"


func _sight_range() -> float:
	match kind:
		"hound":
			return SIGHT_RANGE_HOUND
		"drone":
			return SIGHT_RANGE_DRONE
	return SIGHT_RANGE_SENTRY


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


## Sentry timing: the aim tracks the player for the wind-up, commits at 1.22 s, and the shot leaves at
## 1.6 s. A dodge during the last part of the wind-up evades the shot.
func _tick_sentry(delta: float) -> void:
	if not _visible_target or _attack_cooldown > 0.0:
		_aim_time = maxf(0.0, _aim_time - delta * 2.0)
		_telegraph.visible = false
		if _memory <= 0.0:
			# Idle: the head sweeps slowly from side to side.
			_turret.rotation.y = sin(_clock * 0.4) * 0.8
		return
	_aim_time += delta
	var origin: Vector3 = global_position + Vector3(0, 1.68, 0)
	# The last fraction of the wind-up commits the aim: a dodge can evade the shot.
	if _aim_time < 1.22:
		_locked_aim = target.global_position + Vector3.UP * 0.2
	var aim: Vector3 = _locked_aim - origin
	_turret.rotation.y = lerp_angle(_turret.rotation.y, atan2(-aim.x, -aim.z), delta * 5.0)
	_show_telegraph(origin, aim)
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


## Draws the aim line from origin along aim (the line runs from origin to origin + aim).
func _show_telegraph(origin: Vector3, aim: Vector3) -> void:
	_telegraph.visible = true
	_telegraph.global_position = origin + aim * 0.5
	_telegraph.quaternion = Quaternion(Vector3.UP, aim.normalized())
	_telegraph.scale = Vector3(1, aim.length(), 1)


## Drone AI: patrol at 4-10 m above the anchor until the player is in view, close to the standoff
## distance, then charge (aim line and glowing eye), commit the aim, fire one orb and cool down.
## Losing sight or reach mid-charge cancels the shot, so breaking line of sight is a dodge too.
func _tick_drone(delta: float) -> void:
	_orb_cooldown = maxf(0.0, _orb_cooldown - delta)
	var player_aim: Vector3 = target.global_position + Vector3.UP * 0.2
	var reach: bool = _visible_target and global_position.distance_to(player_aim) <= DRONE_STANDOFF + DRONE_FIRE_SLACK
	if reach and (_drone_charge > 0.0 or _orb_cooldown <= 0.0):
		_drone_engage(delta, player_aim)
	else:
		_drone_charge = 0.0
		_eye_material.emission_energy_multiplier = lerpf(_eye_material.emission_energy_multiplier, 0.9, minf(1.0, delta * 6.0))
		if _visible_target:
			_fly_to(_drone_standoff(player_aim), delta)
		else:
			_patrol_angle = fmod(_patrol_angle + delta * DRONE_PATROL_TURN, TAU)
			_fly_to(_drone_patrol_point(), delta)
	_spin_rotors(delta)


## Holds station while charging. The aim follows the player until the last DRONE_COMMIT seconds, then
## freezes, so the orb goes where the player stood when the charge was nearly over.
func _drone_engage(delta: float, player_aim: Vector3) -> void:
	if _drone_charge <= 0.0:
		_drone_charge = DRONE_CHARGE
		_play("drone_charge")
	_drone_charge -= delta
	if _drone_charge > DRONE_COMMIT:
		_locked_aim = player_aim
	_fly_to(global_position, delta)
	_face_target(delta)
	var charged: float = clampf(1.0 - _drone_charge / DRONE_CHARGE, 0.0, 1.0)
	_eye_material.emission_energy_multiplier = 1.0 + 2.5 * charged
	_show_telegraph(global_position, _locked_aim - global_position)
	if _drone_charge <= 0.0:
		_drone_fire()


func _drone_fire() -> void:
	_drone_charge = 0.0
	_orb_cooldown = DRONE_FIRE_COOLDOWN
	_telegraph.visible = false
	var direction: Vector3 = (_locked_aim - global_position).normalized()
	_play("drone_shot")
	_spawn_orb(global_position + direction * 0.6, direction)


## Eases the drone's velocity toward a goal, capped at DRONE_SPEED, and turns it to face its motion.
func _fly_to(goal: Vector3, delta: float) -> void:
	var desired: Vector3 = ((goal - global_position) * 2.0).limit_length(DRONE_SPEED)
	velocity = velocity.move_toward(desired, DRONE_ACCEL * delta)
	var planar: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	if planar.length() > 0.5:
		_face(planar.normalized(), delta)
	move_and_slide()


## The point the drone closes to: DRONE_STANDOFF metres from the player on the drone's own side, at a
## hover height from the altitude band. The planar offset shrinks when the height gap is large, so the
## 3D distance stays at the standoff.
func _drone_standoff(player_aim: Vector3) -> Vector3:
	var hover_y: float = _patrol_center.y + _drone_altitude()
	var drop: float = hover_y - player_aim.y
	var planar: float = sqrt(maxf(DRONE_STANDOFF * DRONE_STANDOFF - drop * drop, 9.0))
	var side: Vector3 = global_position - player_aim
	side.y = 0.0
	side = side.normalized() if side.length_squared() > 0.01 else Vector3.BACK
	return Vector3(player_aim.x, hover_y, player_aim.z) + side * planar


func _drone_patrol_point() -> Vector3:
	var ring: Vector3 = Vector3(sin(_patrol_angle), 0.0, cos(_patrol_angle)) * DRONE_PATROL_RADIUS
	return _patrol_center + ring + Vector3.UP * _drone_altitude()


## Hover height above the anchor, drifting between 4 and 10 m.
func _drone_altitude() -> float:
	return clampf(DRONE_ALT_MID + sin(_clock * 0.35) * DRONE_ALT_SWING, DRONE_ALT_MIN, DRONE_ALT_MAX)


func _spin_rotors(delta: float) -> void:
	for i in range(_rotors.size()):
		var direction: float = 1.0 if i % 2 == 0 else -1.0
		_rotors[i].rotate_y(delta * DRONE_ROTOR_SPIN * direction)


## Creates one orb as a visible node under the level, so it survives the drone's own removal.
func _spawn_orb(origin: Vector3, direction: Vector3) -> void:
	var level: Node = get_parent()
	if level == null:
		return
	var node := MeshInstance3D.new()
	node.name = "DroneOrb"
	var sphere := SphereMesh.new()
	sphere.radius = 0.24
	sphere.height = 0.48
	sphere.radial_segments = 10
	sphere.rings = 5
	node.mesh = sphere
	node.material_override = FX.glow_material(Color("ff7a3d"), 2.2)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level.add_child(node)
	node.global_position = origin
	_orbs.append({"node": node, "direction": direction, "travelled": 0.0})


## Moves every orb in flight. Each step is a ray from the orb's last spot to its next one, so an orb
## cannot tunnel through a thin wall or past the player in one physics step.
func _update_orbs(delta: float) -> void:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var step: float = DRONE_ORB_SPEED * delta
	var index: int = _orbs.size() - 1
	while index >= 0:
		var orb: Dictionary = _orbs[index]
		var node: MeshInstance3D = orb["node"]
		var direction: Vector3 = orb["direction"]
		var from: Vector3 = node.global_position
		var to: Vector3 = from + direction * step
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, DRONE_ORB_MASK))
		var done: bool = false
		if hit.is_empty():
			node.global_position = to
			orb["travelled"] = float(orb["travelled"]) + step
			done = float(orb["travelled"]) >= DRONE_ORB_RANGE
		else:
			done = true
			var impact: Vector3 = hit["position"]
			var normal: Vector3 = hit["normal"]
			if is_instance_valid(target) and hit["collider"] == target:
				target.call("take_damage", DRONE_ORB_DAMAGE * damage_scale, kind, global_position)
			FX.burst(node.get_parent(), impact, normal, Color("ff7a3d"), 10, 6.0, 0.35, 0.07)
		if done:
			node.queue_free()
			_orbs.remove_at(index)
		index -= 1


func _clear_orbs() -> void:
	for orb: Dictionary in _orbs:
		var node: Node = orb["node"]
		node.queue_free()
	_orbs.clear()


## The drone's death blast: a ring that marks the blast radius, and short-range damage to the player only
## when they stand within DRONE_BLAST_RADIUS. The fireball is the shared death burst (_death_fx).
func _explode() -> void:
	var level: Node = get_parent()
	var centre: Vector3 = global_position
	FX.ring(level, centre, Color("ffc46b"), DRONE_BLAST_RADIUS, 0.4)
	if is_instance_valid(target) and centre.distance_to(target.global_position) <= DRONE_BLAST_RADIUS:
		target.call("take_damage", DRONE_BLAST_DAMAGE * damage_scale, kind, centre)


func _can_see_player() -> bool:
	var origin: Vector3 = global_position + Vector3.UP * _sight_height()
	var end: Vector3 = target.global_position + Vector3.UP * 0.2
	var query := PhysicsRayQueryParameters3D.create(origin, end, 1 | 2)
	query.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit["collider"] == target


## Height of the eye for line-of-sight rays, above the node origin.
func _sight_height() -> float:
	match kind:
		"hound":
			return 0.8
		"drone":
			return 0.0
	return 1.68


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
		_die(source)


## Runs once per death: _dead blocks every later take_damage, so died, the FX and the fall fire once.
func _die(source: String) -> void:
	_dead = true
	if kind != "dummy":
		active = false
	died.emit(kind, source)
	_play("enemy_death")
	collision_layer = 0
	collision_mask = 0
	remove_from_group("enemies")
	if is_instance_valid(_telegraph):
		_telegraph.visible = false
	_clear_orbs()
	_death_fx()
	if kind == "dummy":
		_fall_dummy()
		return
	_eye_material.emission_enabled = false
	_eye_material.albedo_color = Color("101a1c")
	if kind == "drone":
		_explode()
		_visual.visible = false
		var gone := create_tween()
		gone.tween_interval(1.0)
		gone.tween_callback(queue_free)
		return
	var tween := create_tween()
	tween.tween_property(_visual, "rotation:z", 1.35, 0.35)
	tween.parallel().tween_property(_visual, "position:y", -0.2, 0.35)
	tween.tween_interval(12.0)
	tween.tween_callback(queue_free)


## Porcelain-shard burst for every kind, scaled by kind (DEATH_SCALE). Called once, from _die.
func _death_fx() -> void:
	var centre: Vector3 = global_position + Vector3.UP * 0.8
	FX.explosion(get_parent(), centre, SHARD_COLOR, float(DEATH_SCALE.get(kind, 1.0)))


## A dummy goes down and stays down. Its refill clock runs on physics ticks in _tick_dummy.
func _fall_dummy() -> void:
	_refill_left = DUMMY_REFILL
	var tween := create_tween()
	tween.tween_property(_visual, "rotation:z", 1.35, 0.35)
	tween.parallel().tween_property(_visual, "position:y", -0.2, 0.35)


## Dummy tick, run every physics frame whether or not the level is active. It fades the hit flash
## and counts down the refill. It never looks for the player, so it never attacks.
func _tick_dummy(delta: float) -> void:
	if _dead:
		_refill_left -= delta
		if _refill_left <= 0.0:
			_refill_dummy()
		return
	_hurt_flash = maxf(0.0, _hurt_flash - delta)
	_body_material.albedo_color = DUMMY_FLASH if _hurt_flash > 0.0 else PORCELAIN


## Stands the dummy back up at full health, with its collision and target group restored.
func _refill_dummy() -> void:
	_dead = false
	health = max_health
	_hurt_flash = 0.0
	_body_material.albedo_color = PORCELAIN
	_visual.rotation = Vector3.ZERO
	_visual.position = Vector3.ZERO
	collision_layer = 8
	collision_mask = 1
	add_to_group("enemies")


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
	# Main porcelain volumes cast the silhouette; tiny fittings do not need cascaded passes.
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
