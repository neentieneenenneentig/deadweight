extends Node3D
## A free moving weight and tension-only elastic line. All line forces are paired.
## Owns casting, spool, reel, recover, the anchor latch, line wrapping, smash and impact events (CONTRACT 4.9).
## Line visuals beyond the basic ribbon come in a later task.

const FxScript = preload("res://scripts/fx.gd")

## Event ids only. Main maps them to hints and sounds (CONTRACT 4.9 and 5.11).
signal event_happened(event: String)
signal weight_impact(position: Vector3, speed: float)
signal weight_smash(target: Node, speed: float, damage: float)

# --- Tuning -------------------------------------------------------------------------------------
# Stock values. Upgrades.stats() replaces the workshop-driven ones through configure().
const DEFAULT_WEIGHT_MASS: float = 145.0    # kg
const DEFAULT_MAX_LINE: float = 48.0        # m of line on the spool
const DEFAULT_REEL_FORCE: float = 16000.0   # N; the reel stalls when line load reaches this
const DEFAULT_REEL_SPEED: float = 11.0      # m/s of line taken in at full reel and no load
const DEFAULT_ASSIST_STRENGTH: float = 14500.0
const DEFAULT_CHARGE_TIME: float = 0.8      # s to a full-power cast
const CAST_COOLDOWN: float = 0.18           # s before another cast or charge
const CAST_START_DISTANCE: float = 1.35     # m in front of the camera where the weight starts
# Line physics.
const STIFFNESS: float = 12000.0
const DAMPING: float = 1200.0
const MAX_TENSION: float = 22000.0          # N, the catch force cap
const MIN_LINE: float = 1.8                 # m, the reel never takes the line shorter than this
const LOAD_TAKE_UP: float = 0.04            # m of slack allowed past the distance on free spool
# Wrapping around layer-1 geometry (G3). The line bends at wrap points, at most MAX_WRAPS of them.
const MAX_WRAPS: int = 8                    # a ninth needed wrap severs the line
const WRAP_OFFSET: float = 0.12             # m a wrap sits off the surface, along its normal
const WRAP_MARGIN: float = 0.08             # m of clearance a chord needs before its wrap is dropped
const WRAP_SEARCH_STEP: float = 0.05        # m between candidate corners while sliding along a surface
const WRAP_SEARCH_RANGE: float = 6.0        # m a candidate corner may slide from the first hit
const WEIGHT_CONTACT: float = 0.35          # m; a hit this close to the weight is the weight touching a surface
const MIN_SEGMENT: float = 0.02             # m; a wrap this close to a neighbour has collapsed onto it
const LINE_LAYER: int = 1                   # world geometry only
# Recover, smash and impacts.
const RECOVER_DISTANCE: float = 2.2         # m; a reeled weight this close to the rod tip is recovered
const SMASH_MIN_SPEED: float = 9.0          # m/s; slower enemy contacts are only bumps
const SMASH_BASE_DAMAGE: float = 40.0
const SMASH_DAMAGE_PER_MS: float = 4.0      # extra damage per m/s above SMASH_MIN_SPEED
const SMASH_MAX_DAMAGE: float = 90.0        # cap for one smash
const SMASH_COOLDOWN: float = 0.35          # s between smashes
const IMPACT_MIN_SPEED: float = 4.0         # m/s; slower world contacts make no impact
const IMPACT_INTERVAL: float = 0.15         # s between weight_impact emits
const WEIGHT_TIMEOUT: float = 8.0           # s a cut weight lingers before it is freed
const MAX_LOOSE_WEIGHTS: int = 8

# --- State --------------------------------------------------------------------------------------
var player: RigidBody3D
var weight: RigidBody3D
var active: bool = false
var locked: bool = false
var reeling: bool = false
## 0..1 analog reel. The gamepad trigger sets it; keyboard reel is full strength.
var reel_strength: float = 1.0
var charging: bool = false
var charge: float = 0.0
## Deployed line on the spool. The wrapped line's total length is kept at or under this while locked.
var line_length: float = 0.0
var tension: float = 0.0
## True while the weight is latched on an anchor plate (frozen, line acts as a fixed pivot).
var anchored: bool = false
## Auto-cut on: CAST with a weight attached drops it and charges the next. Off: the player must CUT.
var auto_cut: bool = true
var max_line: float = DEFAULT_MAX_LINE
var reel_force: float = DEFAULT_REEL_FORCE
var reel_speed: float = DEFAULT_REEL_SPEED
var weight_mass: float = DEFAULT_WEIGHT_MASS
var charge_time: float = DEFAULT_CHARGE_TIME
var assist_strength: float = DEFAULT_ASSIST_STRENGTH
var _assist_remaining: float = 0.0
var _assist_direction: Vector3 = Vector3.ZERO
var _line_view: MeshInstance3D
var _line_material: StandardMaterial3D
var _loose_weights: Array[Dictionary] = []
## Wrap points in order from the player end toward the weight. The line bends at each one.
var _wraps: Array[Vector3] = []
var _cast_cooldown: float = 0.0
var _smash_cooldown: float = 0.0
var _impact_cooldown: float = 0.0
var _previous_speed: float = 0.0
var _at_spool_limit: bool = false
var _stalled: bool = false


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


## Applies the workshop stats from Upgrades.stats (CONTRACT 5.1). Missing keys keep their value.
func configure(stats: Dictionary) -> void:
	max_line = maxf(1.0, float(stats.get("max_line", max_line)))
	# The line cannot carry more than MAX_TENSION, so a stronger motor cannot stall above it.
	reel_force = minf(MAX_TENSION, float(stats.get("reel_force", reel_force)))
	reel_speed = float(stats.get("reel_speed", reel_speed))
	weight_mass = maxf(1.0, float(stats.get("weight_mass", weight_mass)))
	assist_strength = float(stats.get("assist_strength", assist_strength))
	charge_time = maxf(0.05, float(stats.get("charge_time", charge_time)))


## CAST while a weight is out. With auto_cut the weight is dropped and the next charge starts;
## without it the player must cut first.
func begin_charge() -> void:
	if not active or _cast_cooldown > 0.0:
		return
	if is_instance_valid(weight):
		if not auto_cut:
			event_happened.emit("cut_first")
			return
		cut()
		event_happened.emit("auto_cut")
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
	var start: Vector3 = camera.global_position + direction * CAST_START_DISTANCE + Vector3.DOWN * 0.12
	var clearance := PhysicsRayQueryParameters3D.create(camera.global_position, start, 1)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(clearance)
	if not hit.is_empty():
		event_happened.emit("no_clearance")
		return
	weight = _build_weight()
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
	anchored = false
	_at_spool_limit = false
	_stalled = false
	_wraps.clear()
	_cast_cooldown = CAST_COOLDOWN
	event_happened.emit("cast")


## The cast weight: a heavy sphere with a teal belt on collision layer 4.
## Contact monitoring lets the tether see anchors and enemies that the weight touches.
func _build_weight() -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = "CastWeight"
	body.mass = weight_mass
	body.collision_layer = 4
	body.collision_mask = 1 | 8
	body.continuous_cd = true
	body.can_sleep = false
	body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.linear_damp = 0.025
	body.contact_monitor = true
	body.max_contacts_reported = 4
	var surface := PhysicsMaterial.new()
	surface.bounce = 0.18
	surface.friction = 0.65
	body.physics_material_override = surface
	var shape := CollisionShape3D.new()
	var ball := SphereShape3D.new()
	ball.radius = 0.29
	shape.shape = ball
	body.add_child(shape)
	var visual := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.29
	mesh.height = 0.72
	mesh.radial_segments = 12
	mesh.rings = 6
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("f0ddc0")
	material.albedo_texture = preload("res://assets/dreamscape/porcelain.png")
	material.metallic = 0.1
	material.roughness = 0.28
	visual.material_override = material
	body.add_child(visual)
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
	body.add_child(belt)
	return body


## An anchored weight is already a fixed pivot, so the lock cannot be released while latched.
func toggle_lock() -> void:
	if is_instance_valid(weight) and not anchored:
		locked = not locked
		event_happened.emit("lock" if locked else "release")


func cut() -> void:
	charging = false
	charge = 0.0
	if is_instance_valid(weight):
		# Detaching never changes either body's linear velocity.
		weight.freeze = false
		_loose_weights.append({"body": weight, "time": WEIGHT_TIMEOUT})
		weight = null
		event_happened.emit("cut")
	anchored = false
	tension = 0.0
	line_length = 0.0
	locked = false
	reeling = false
	_assist_remaining = 0.0
	_at_spool_limit = false
	_stalled = false
	_wraps.clear()
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
	anchored = false
	_at_spool_limit = false
	_stalled = false
	_wraps.clear()
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
	_smash_cooldown = maxf(0.0, _smash_cooldown - delta)
	_impact_cooldown = maxf(0.0, _impact_cooldown - delta)
	if charging:
		charge = minf(1.0, charge + delta / charge_time)
	_age_loose_weights(delta)
	if is_instance_valid(weight):
		_step_weight(delta)
	# Remember the speed for the next step: a contact can slow the weight within the step it hits.
	_previous_speed = weight.linear_velocity.length() if is_instance_valid(weight) else 0.0


func _age_loose_weights(delta: float) -> void:
	for index in range(_loose_weights.size() - 1, -1, -1):
		_loose_weights[index].time -= delta
		if _loose_weights[index].time <= 0.0 or _loose_weights.size() > MAX_LOOSE_WEIGHTS:
			if is_instance_valid(_loose_weights[index].body):
				_loose_weights[index].body.queue_free()
			_loose_weights.remove_at(index)


## One physics step for the attached weight: assist, contacts, wraps, spool, reel, rope and line rules.
func _step_weight(delta: float) -> void:
	if _assist_remaining > 0.0:
		var fraction: float = minf(delta, _assist_remaining) / delta
		weight.apply_central_force(_assist_direction * assist_strength * fraction)
		_assist_remaining -= delta
	if not anchored:
		_check_contacts(maxf(_previous_speed, weight.linear_velocity.length()))
	var origin: Vector3 = player.global_position
	if weight.global_position.distance_to(origin) < 0.01:
		return
	# Drop the wraps the line no longer needs, then bend the line where geometry now blocks it.
	_drop_redundant_wraps(origin)
	if not _add_blocking_wrap(origin):
		return
	var points: PackedVector3Array = _line_points(origin)
	if not _is_finite(points):
		_sever()
		return
	var total: float = _polyline_length(points)
	var first_dir: Vector3 = (points[1] - points[0]).normalized()
	var last_dir: Vector3 = (points[points.size() - 1] - points[points.size() - 2]).normalized()
	if not locked and not reeling:
		line_length = minf(max_line, maxf(line_length, total + LOAD_TAKE_UP))
		_update_spool_limit()
	if reeling:
		_reel_in(delta)
		# An anchored weight stays latched; only a free weight can be reeled back into the rod.
		if not anchored and _try_recover():
			return
	# Each end is pulled along its own end segment: the player toward the first point, the weight toward the last.
	var relative_speed: float = last_dir.dot(weight.linear_velocity) - first_dir.dot(player.linear_velocity)
	tension = rope_force(total, line_length, relative_speed)
	if tension > 0.0:
		player.apply_central_force(first_dir * tension)
		weight.apply_central_force(-last_dir * tension)
	_check_line_rules(total)


## Emits spool_limit once each time free spool reaches the line maximum.
func _update_spool_limit() -> void:
	var at_limit: bool = line_length >= max_line
	if at_limit and not _at_spool_limit:
		event_happened.emit("spool_limit")
	_at_spool_limit = at_limit


## Takes line in at reel_speed scaled by reel_strength. Load on the line slows the reel and stalls it.
func _reel_in(delta: float) -> void:
	var load_fraction: float = clampf(tension / reel_force, 0.0, 1.0)
	var stalled: bool = load_fraction >= 1.0
	if stalled and not _stalled:
		event_happened.emit("reel_stall")
	_stalled = stalled
	var strength: float = clampf(reel_strength, 0.0, 1.0)
	line_length = maxf(MIN_LINE, line_length - reel_speed * strength * (1.0 - load_fraction) * delta)


## A free weight reeled within RECOVER_DISTANCE of the rod tip is taken back. Returns true when it was.
func _try_recover() -> bool:
	if weight.global_position.distance_to(_rod_tip_position()) > RECOVER_DISTANCE:
		return false
	weight.queue_free()
	weight = null
	locked = false
	reeling = false
	tension = 0.0
	line_length = 0.0
	_at_spool_limit = false
	_stalled = false
	_wraps.clear()
	_line_view.mesh = null
	event_happened.emit("recover")
	return true


## The rod tip is the rope's near end. Falls back to the player centre when the rod is not built.
func _rod_tip_position() -> Vector3:
	var rod: Node3D = player.get("rod_tip") as Node3D
	if is_instance_valid(rod):
		return rod.global_position
	return player.global_position


## Reads what the weight touches this step. Anchors latch, enemies take smash hits, world hits make impacts.
func _check_contacts(speed: float) -> void:
	for body: Node in weight.get_colliding_bodies():
		if body.is_in_group("anchor"):
			_latch()
			return
		if body.is_in_group("enemies"):
			if speed > SMASH_MIN_SPEED and _smash_cooldown <= 0.0:
				_smash(body as Node3D, speed)
		elif speed > IMPACT_MIN_SPEED and _impact_cooldown <= 0.0:
			_impact(speed)


## The weight sticks to an anchor plate. It freezes where it touched and the line holds as a fixed pivot.
func _latch() -> void:
	anchored = true
	locked = true
	weight.linear_velocity = Vector3.ZERO
	weight.angular_velocity = Vector3.ZERO
	weight.freeze = true
	event_happened.emit("anchor")


## A fast weight hit on an enemy: capped damage, a cooldown, a signal and FX.
func _smash(target: Node3D, speed: float) -> void:
	var raw: float = SMASH_BASE_DAMAGE + maxf(0.0, speed - SMASH_MIN_SPEED) * SMASH_DAMAGE_PER_MS
	# Heavier weights hit harder, scaled from the stock mass.
	var damage: float = minf(SMASH_MAX_DAMAGE, raw * weight_mass / DEFAULT_WEIGHT_MASS)
	_smash_cooldown = SMASH_COOLDOWN
	if target.has_method("take_damage"):
		target.call("take_damage", damage, "weight")
	var contact: Vector3 = weight.global_position
	var normal: Vector3 = (contact - target.global_position).normalized()
	if normal.is_zero_approx():
		normal = Vector3.UP
	FxScript.flash(get_parent(), contact, Color("ffc46b"), 0.5, 0.1)
	FxScript.burst(get_parent(), contact, normal, Color("ef654e"), 16, 8.0, 0.45, 0.07)
	weight_smash.emit(target, speed, damage)
	event_happened.emit("smash")


## A hard world hit. Throttled so a bouncing weight does not flood listeners.
func _impact(speed: float) -> void:
	_impact_cooldown = IMPACT_INTERVAL
	weight_impact.emit(weight.global_position, speed)
	event_happened.emit("weight_impact")


# --- Wrapping (CONTRACT 4.9) ---------------------------------------------------------------------

## The line as a polyline: the player end, each wrap in order, then the weight.
func _line_points(origin: Vector3) -> PackedVector3Array:
	var points := PackedVector3Array()
	points.append(origin)
	for wrap_point in _wraps:
		points.append(wrap_point)
	points.append(weight.global_position)
	return points


func _polyline_length(points: PackedVector3Array) -> float:
	var total: float = 0.0
	for s in range(points.size() - 1):
		total += points[s].distance_to(points[s + 1])
	return total


func _is_finite(points: PackedVector3Array) -> bool:
	for point in points:
		if not point.is_finite():
			return false
	return weight.linear_velocity.is_finite() and player.linear_velocity.is_finite()


## The wrap points the line bends around, from the player end toward the weight. Empty when the line is straight.
func get_wrap_points() -> PackedVector3Array:
	return PackedVector3Array(_wraps)


## Severs the line on overflow or a degenerate state, through the same path as an obstruction cut.
func _sever() -> void:
	cut()
	event_happened.emit("severed")


## Adds a wrap at the first blocked segment. Returns false when the line was severed instead.
func _add_blocking_wrap(origin: Vector3) -> bool:
	var blocked: Dictionary = _first_blocked_segment(_line_points(origin))
	if blocked.is_empty():
		return true
	var corner: Vector3 = blocked["point"]
	if _wraps.size() >= MAX_WRAPS or not corner.is_finite():
		_sever()
		return false
	_wraps.insert(int(blocked["index"]), corner)
	return true


## Drops each wrap whose neighbours see each other again with WRAP_MARGIN to spare, or that has
## collapsed onto a neighbour. Walks from the weight end so the earlier indices stay valid.
func _drop_redundant_wraps(origin: Vector3) -> void:
	for index in range(_wraps.size() - 1, -1, -1):
		var points: PackedVector3Array = _line_points(origin)
		var before: Vector3 = points[index]
		var wrap_point: Vector3 = points[index + 1]
		var after: Vector3 = points[index + 2]
		var collapsed: bool = wrap_point.distance_to(before) < MIN_SEGMENT or wrap_point.distance_to(after) < MIN_SEGMENT
		if collapsed or _clear_with_margin(before, after):
			_wraps.remove_at(index)


## The first segment of the line that world geometry blocks, as {index, point}: index is where the wrap
## is inserted and point is the corner it bends around. Empty when the whole line is clear.
func _first_blocked_segment(points: PackedVector3Array) -> Dictionary:
	for index in range(points.size() - 1):
		# Only the segment into the weight may touch: a weight resting on a plate is not blocked by it.
		var end_contact: float = WEIGHT_CONTACT if index == points.size() - 2 else 0.0
		var hit: Dictionary = _blocking_hit(points[index], points[index + 1], end_contact)
		if hit.is_empty():
			continue
		var surface: Vector3 = hit["position"]
		var normal: Vector3 = hit["normal"]
		if normal.is_zero_approx():
			normal = Vector3.UP
		var corner: Vector3 = _corner_point(surface, normal, points[index], points[index + 1], end_contact)
		return {"index": index, "point": corner}
	return {}


## The first world hit on the segment a to b, or empty when it is clear. A hit within end_contact of b is
## that end touching geometry, so it does not block.
func _blocking_hit(a: Vector3, b: Vector3, end_contact: float) -> Dictionary:
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a, b, LINE_LAYER))
	if hit.is_empty():
		return hit
	var at: Vector3 = hit["position"]
	if at.distance_to(b) < end_contact:
		return {}
	return hit


## True when both legs a to mid and mid to b are clear of world geometry.
func _chain_clear(a: Vector3, mid: Vector3, b: Vector3, end_contact: float) -> bool:
	return _blocking_hit(a, mid, 0.0).is_empty() and _blocking_hit(mid, b, end_contact).is_empty()


## Where a line that hits a surface at hit bends around it. The wrap sits WRAP_OFFSET off the surface and
## slides along it, toward the far end, until the bent line clears the geometry. The shorter way round wins.
func _corner_point(hit: Vector3, normal: Vector3, from: Vector3, to: Vector3, end_contact: float) -> Vector3:
	var base: Vector3 = hit + normal * WRAP_OFFSET
	var across: Vector3 = (to - hit).slide(normal)
	if across.length() < 0.01:
		return base
	var along: Vector3 = across.normalized()
	var best: Vector3 = base
	var best_length: float = INF
	var steps: int = int(WRAP_SEARCH_RANGE / WRAP_SEARCH_STEP)
	for direction in [along, -along]:
		for step in range(1, steps + 1):
			var candidate: Vector3 = base + direction * (WRAP_SEARCH_STEP * float(step))
			if _chain_clear(from, candidate, to, end_contact):
				var length: float = from.distance_to(candidate) + candidate.distance_to(to)
				if length < best_length:
					best_length = length
					best = candidate
				break
	return best


## True when a sphere of WRAP_MARGIN can sweep from a to b without touching world geometry.
func _clear_with_margin(a: Vector3, b: Vector3) -> bool:
	var ball := SphereShape3D.new()
	ball.radius = WRAP_MARGIN
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = ball
	query.transform = Transform3D(Basis(), a)
	query.motion = b - a
	query.collision_mask = LINE_LAYER
	var fractions: PackedFloat32Array = get_world_3d().direct_space_state.cast_motion(query)
	return fractions.size() == 2 and fractions[0] >= 1.0 and fractions[1] >= 1.0


## Overload rule: a line stretched past twice its maximum is cut.
func _check_line_rules(total: float) -> void:
	if total > max_line * 2.0:
		cut()
		event_happened.emit("overload")


func _process(_delta: float) -> void:
	if not is_instance_valid(weight) or not is_instance_valid(player):
		return
	var rod: Node3D = player.get("rod_tip") as Node3D
	var points: PackedVector3Array = _line_points(rod.global_position)
	var total: float = _polyline_length(points)
	var sag_max: float = minf(maxf(0.0, line_length - total) * 0.3, 5.0)
	var mesh := ImmediateMesh.new()
	_line_material.albedo_color = Color("edb268") if tension > 8000.0 else Color("b5ddd5")
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, _line_material)
	# Each segment sags in proportion to its share of the line, so the rope droops between wraps too.
	for s in range(points.size() - 1):
		var a: Vector3 = points[s]
		var b: Vector3 = points[s + 1]
		var sag: float = sag_max * a.distance_to(b) / maxf(total, 0.001)
		for i in range(17):
			var ratio: float = float(i) / 16.0
			var point: Vector3 = a.lerp(b, ratio)
			point.y -= sin(ratio * PI) * sag
			mesh.surface_add_vertex(to_local(point))
	mesh.surface_end()
	_line_view.mesh = mesh


func state_name() -> String:
	if charging:
		return "CHARGING"
	if not is_instance_valid(weight):
		return "READY TO CAST"
	if reeling:
		return "REELING" if tension < reel_force else "REEL STALLED"
	if anchored:
		return "ANCHORED"
	if locked:
		return "LOCKED / TAUT" if tension > 100.0 else "LOCKED / SLACK"
	return "SPOOL LIMIT" if line_length >= max_line else "FREE SPOOL"
