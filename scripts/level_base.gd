extends Node3D
## Base class of every DEADWEIGHT level (CONTRACT 4.11).
##
## A level is a small script that extends this one, declares an INFO constant (CONTRACT 5.6) and
## describes its geometry in _design() with the builder calls below. Nothing else is needed:
## the base class owns the zone look (sky, sun, fog, materials), the pickups, the extraction
## pad, enemies, shooting, signals and the draw-call batching.
##
##     extends "res://scripts/level_base.gd"
##     const INFO := {"title": "EXAMPLE", "zone": "floodworks", "number": 1, "blurb": "One line.",
##         "par_silver": 120.0, "par_gold": 80.0, "cases": 1, "bonus": 0, "enemies": false,
##         "practice": false}
##     func _design() -> void:
##         set_zone("floodworks")                              # call first
##         set_spawn(Vector3(0, 0, 10))
##         ground(Vector3(0, 0, -20), Vector2(40, 60))         # top surface at y = 0
##         ramp(Vector3(0, 0, -5), Vector3(0, 3, -17), 5.0)    # walk-surface points
##         platform(Vector3(0, 3, -22), Vector2(10, 8))
##         case_at(Vector3(0, 3.0, -22), "01 / THE ROOF")
##         extraction(Vector3(0, 0, -40))
##
## Static meshes are collected during _design() and merged into one mesh per material when
## build() finishes, so a whole level costs a handful of draw calls. All collision for solid
## primitives lives in one StaticBody3D (layer 1). Moving a node returned by a builder call
## changes how it looks but not its collision; pass `yaw` to the builder instead.
##
## Features (task F8): anchor, updraft, hazard, water, hint_zone, light, skyline, perimeter. They
## are described in the "Level features" section near the end of this file.
## Not here yet (task F9): navigation baking.

signal loot_collected(kind: String, value: int)    # kind "case" | "bonus"; value = salvage
signal extraction_changed(inside: bool)
signal threat_changed(text: String)
signal hint_requested(text: String, duration: float)
signal enemy_killed(kind: String, by: String)

const EnemyScript = preload("res://scripts/enemy.gd")
const FX = preload("res://scripts/fx.gd")
const ProfileScript = preload("res://scripts/profile.gd")

const PICKUP_RADIUS := 2.0
const EXTRACT_HALF_SIZE := 4.7
const EXTRACT_PAD_SIZE := 9.4
const MAX_SLOPE_DEGREES := 35.0
const SHOT_RANGE := 160.0
const LAYER_WORLD := 1
const LAYER_WEAPON_TARGETS := 1 | 4 | 8

const GLOW_KEYS := ["cyan", "amber", "red", "orange", "white"]
const NO_SHADOW_KEYS := ["cyan", "amber", "red", "orange", "white", "water", "glass"]
const GRIME_KEYS := ["concrete", "light_concrete", "dark", "rust", "metal", "stripe"]
const GRIME_SCALE := 0.08

const MAX_LIGHTS := 6                                # lights cost draw calls and shader work on mobile
const HAZARD_KINDS := ["electric", "heat", "water"]
const HAZARD_ZAP_INTERVAL := 0.5                     # seconds between hazard_zap sounds
const WATER_DPS := 25.0                              # deep water damage per second (before damage_scale)

## Per-zone look. "colors" must define every material key (CONTRACT 4.11).
const ZONES := {
	"floodworks": {
		"sky_top": "193b4a", "sky_horizon": "b6aa8e", "ground_bottom": "172d34", "ground_horizon": "9ba58e",
		"ambient": "a8c8cd", "ambient_energy": 0.65, "fog": "536e72", "fog_density": 0.0035,
		"sun": "ffd5a2", "sun_energy": 1.6, "sun_rotation": Vector3(-32, -24, 0),
		"colors": {
			"concrete": "35484a", "light_concrete": "647371", "dark": "14282f", "rust": "81513b",
			"metal": "56666a", "yellow": "d8a84e", "stripe": "25383b", "glass": "7fb7bd", "water": "193e48",
			"cyan": "5ad6c8", "amber": "ffc46b", "red": "ef654e", "orange": "f08a3c", "white": "c5d0bc",
		},
	},
	"foundry": {
		"sky_top": "0d0f12", "sky_horizon": "4a3226", "ground_bottom": "0a0b0d", "ground_horizon": "2e2420",
		"ambient": "8a6a5a", "ambient_energy": 0.5, "fog": "2e211b", "fog_density": 0.006,
		"sun": "ff9a5a", "sun_energy": 0.9, "sun_rotation": Vector3(-20, 40, 0),
		"colors": {
			"concrete": "3a3d3f", "light_concrete": "5f625f", "dark": "17181a", "rust": "7a3f27",
			"metal": "5b6168", "yellow": "e0b13a", "stripe": "2a2a2c", "glass": "6c8791", "water": "4a2a14",
			"cyan": "5ad6c8", "amber": "ffb347", "red": "ff5a40", "orange": "ff7a1a", "white": "e8e0d0",
		},
	},
	"spillway": {
		"sky_top": "5f8fb8", "sky_horizon": "dce6ea", "ground_bottom": "9db0b6", "ground_horizon": "cfdadb",
		"ambient": "d6e4ec", "ambient_energy": 0.9, "fog": "c4d4dc", "fog_density": 0.0025,
		"sun": "fff4e0", "sun_energy": 1.9, "sun_rotation": Vector3(-48, -30, 0),
		"colors": {
			"concrete": "8d9893", "light_concrete": "bcc5c0", "dark": "3e4e55", "rust": "8a6048",
			"metal": "7c8b92", "yellow": "e6c052", "stripe": "4c5a5e", "glass": "8fbccb", "water": "1f5f86",
			"cyan": "5ad6c8", "amber": "ffc46b", "red": "ef654e", "orange": "f08a3c", "white": "eef2ee",
		},
	},
}

# --- Public state (CONTRACT 4.11) ---------------------------------------------------------------

var level_id: String = ""
var info: Dictionary = {}
var zone: String = "floodworks"
var spawn_position: Vector3 = Vector3(0, 0.95, 0)    # capsule centre (floor + 0.95)
var spawn_yaw: float = 0.0                           # radians
var extraction_position: Vector3 = Vector3.ZERO      # floor centre of the pad
var total_loot: int = 0                              # required cases
var collected_loot: int = 0
var total_bonus: int = 0
var collected_bonus: Array[int] = []                 # bonus indices collected this run
var practice: bool = false
var damage_scale: float = 1.0                        # set by main before build()
var quality: int = 2                                 # set by main before build()
var kill_y: float = -20.0
var navigation_ready: bool = false

# --- Internal state -----------------------------------------------------------------------------

static var _grime_texture: ImageTexture
static var _material_cache: Dictionary = {}          # zone name -> {key: Material}

var _player: Node3D
var _active: bool = false
var _inside_extraction: bool = false
var _has_extraction: bool = false
var _clock: float = 0.0
var _pickups: Array[Dictionary] = []                 # {node, mesh, position, kind, index, title}
var _enemies: Array[Node] = []
var _materials: Dictionary = {}
var _stage: Node3D                                   # pending static meshes, merged then freed
var _pending: Array[MeshInstance3D] = []
var _body: StaticBody3D                              # every solid primitive's collider
var _extract_ring: MeshInstance3D
var _environment: Environment
var _sun: DirectionalLight3D
var _fog_base: float = 0.0
var _label_count: int = 0
var _pending_count: int = 0                          # statics before merging (for budgets/logs)
var _merged_count: int = 0
var _built: bool = false
var _case_spots: Array[Dictionary] = []              # {floor_point, title}: restock_cases() respawns them
var _hazards: Array[Dictionary] = []                 # volume records with "dps"
var _updrafts: Array[Dictionary] = []                # volume records with "strength" (m/s^2)
var _hint_zones: Array[Dictionary] = []              # {box, text, duration, fired}
var _light_count: int = 0
var _zap_time: float = -10.0                         # clock time of the last hazard_zap


# --- Lifecycle ----------------------------------------------------------------------------------

func build(player: Node3D, practice_mode: bool = false) -> void:
	_player = player
	practice = practice_mode
	_reset_build_state()
	info = _declared_info()
	set_zone(str(info.get("zone", "floodworks")))
	_design()
	_finish_build()
	_built = true


## Override in the level script. Call the builder functions below.
func _design() -> void:
	pass


func set_active(value: bool) -> void:
	_active = value
	for hostile: Node in _enemies:
		if is_instance_valid(hostile):
			hostile.call("set_active", value)
	if not value and _inside_extraction:
		_inside_extraction = false
		extraction_changed.emit(false)


func _reset_build_state() -> void:
	_pickups.clear()
	_enemies.clear()
	_pending.clear()
	total_loot = 0
	collected_loot = 0
	total_bonus = 0
	collected_bonus.clear()
	_case_spots.clear()
	_hazards.clear()
	_updrafts.clear()
	_hint_zones.clear()
	_light_count = 0
	_label_count = 0
	_has_extraction = false
	if is_instance_valid(_stage):
		_stage.free()
	_stage = Node3D.new()
	_stage.name = "PendingStatics"
	add_child(_stage)
	if is_instance_valid(_body):
		_body.free()
	_body = StaticBody3D.new()
	_body.name = "Colliders"
	_body.collision_layer = LAYER_WORLD
	_body.collision_mask = 0
	add_child(_body)


## INFO as declared by the level script itself ({} when the script has none).
func _declared_info() -> Dictionary:
	var script: Script = get_script()
	if script == null:
		return {}
	var declared: Variant = script.get_script_constant_map().get("INFO", {})
	return (declared as Dictionary).duplicate(true) if declared is Dictionary else {}


# --- Builder: scene setup -----------------------------------------------------------------------

## "floodworks" | "foundry" | "spillway". Call first: it chooses the material palette.
func set_zone(zone_name: String) -> void:
	if not ZONES.has(zone_name):
		push_warning("Level %s: unknown zone '%s', using floodworks." % [level_id, zone_name])
		zone_name = "floodworks"
	zone = zone_name
	_materials = _zone_materials(zone_name)


func set_spawn(floor_point: Vector3, yaw_degrees: float = 0.0) -> void:
	spawn_position = floor_point + Vector3.UP * 0.95
	spawn_yaw = deg_to_rad(yaw_degrees)


func set_kill_y(y: float) -> void:
	kill_y = y


# --- Builder: geometry --------------------------------------------------------------------------

## A flat slab whose top surface is at center.y.
func ground(center: Vector3, size: Vector2, material: String = "concrete", thickness: float = 1.2) -> void:
	_box_at(Transform3D(Basis.IDENTITY, center - Vector3.UP * (thickness * 0.5)), Vector3(size.x, thickness, size.y), material, true)


func box(center: Vector3, size: Vector3, material: String = "concrete", solid: bool = true, yaw: float = 0.0) -> Node3D:
	return _box_at(_frame(center, yaw), size, material, solid)


## Like box() but placed by the bottom centre.
func block(base: Vector3, size: Vector3, material: String = "concrete", yaw: float = 0.0) -> Node3D:
	return _box_at(_frame(base + Vector3.UP * size.y * 0.5, yaw), size, material, true)


## A walkable slope. start and finish are points on the walking surface.
func ramp(start: Vector3, finish: Vector3, width: float, material: String = "light_concrete") -> void:
	var offset: Vector3 = finish - start
	var length: float = offset.length()
	if length < 0.01:
		return
	var run: float = Vector2(offset.x, offset.z).length()
	var slope: float = rad_to_deg(atan2(absf(offset.y), maxf(run, 0.001)))
	if slope > MAX_SLOPE_DEGREES:
		push_warning("Level %s: ramp %s -> %s is %.0f degrees, steeper than %.0f." % [level_id, start, finish, slope, MAX_SLOPE_DEGREES])
	var basis: Basis = Basis.looking_at(offset.normalized(), Vector3.UP)
	var middle: Vector3 = (start + finish) * 0.5 - basis.y * 0.14
	var frame := Transform3D(basis, middle)
	_box_at(frame, Vector3(width, 0.28, length + 0.4), material, true)
	for side: float in [-1.0, 1.0]:
		_part(frame, Vector3(side * (width * 0.5 - 0.15), 0.155, 0.0), Vector3(0.12, 0.035, length), "yellow")


func cylinder(center: Vector3, radius: float, height: float, material: String = "rust", solid: bool = true) -> Node3D:
	return _cylinder_at(Transform3D(Basis.IDENTITY, center), radius, height, material, solid)


## A cylinder laid between two points.
func pipe(from: Vector3, to: Vector3, radius: float, material: String = "rust", solid: bool = true) -> Node3D:
	var axis: Vector3 = to - from
	if axis.length() < 0.01:
		return null
	var basis: Basis = Basis(Quaternion(Vector3.UP, axis.normalized()))
	return _cylinder_at(Transform3D(basis, (from + to) * 0.5), radius, axis.length(), material, solid)


func crate(base: Vector3, size: Vector3, yaw: float = 0.0) -> void:
	var frame: Transform3D = _frame(base, yaw)
	_part(frame, Vector3.UP * size.y * 0.5, size, "rust", true)
	for x: float in [-0.37, 0.37]:
		_part(frame, Vector3(x * size.x, size.y * 0.5, size.z * 0.5 + 0.025), Vector3(0.09, size.y, 0.04), "dark")
	_part(frame, Vector3(0, size.y - 0.3, size.z * 0.5 + 0.04), Vector3(size.x * 0.8, 0.08, 0.04), "yellow")


func barrier(base: Vector3, length: float, yaw: float = 0.0) -> void:
	var frame: Transform3D = _frame(base, yaw)
	_part(frame, Vector3.UP * 0.75, Vector3(length, 1.5, 0.9), "light_concrete", true)
	_part(frame, Vector3(0, 1.16, 0.46), Vector3(length, 0.4, 0.025), "yellow")
	for index in range(int(length)):
		var stripe: Node3D = _part(frame, Vector3(float(index) - length * 0.5 + 0.4, 1.16, 0.48), Vector3(0.3, 0.4, 0.025), "stripe")
		stripe.transform = stripe.transform * Transform3D(Basis(Vector3.BACK, -0.35), Vector3.ZERO)


## A slab with its top at top_center.y; supports adds four posts down to y = 0.
func platform(top_center: Vector3, size: Vector2, material: String = "dark", supports: bool = true) -> void:
	var thickness: float = 0.3
	_box_at(Transform3D(Basis.IDENTITY, top_center - Vector3.UP * (thickness * 0.5)), Vector3(size.x, thickness, size.y), material, true)
	if not supports or top_center.y - thickness < 0.5:
		return
	var post_height: float = top_center.y - thickness
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			var base := Vector3(top_center.x + x * (size.x * 0.5 - 0.4), 0.0, top_center.z + z * (size.y * 0.5 - 0.4))
			pillar(base, post_height, 0.5, "rust")


func pillar(base: Vector3, height: float, width: float = 0.9, material: String = "rust") -> void:
	_box_at(Transform3D(Basis.IDENTITY, base + Vector3.UP * height * 0.5), Vector3(width, height, width), material, true)


## A signboard on two posts. position is the board centre.
func signboard(title: String, position: Vector3, subtitle: String = "", accent: String = "amber", yaw: float = 0.0) -> void:
	var frame: Transform3D = _frame(position, yaw)
	_part(frame, Vector3.ZERO, Vector3(8.3, 1.65, 0.22), "dark", true)
	_part(frame, Vector3(-4.05, 0, 0.13), Vector3(0.1, 1.65, 0.04), accent)
	for x: float in [-3.5, 3.5]:
		_part(frame, Vector3(x, -position.y * 0.5 - 0.4, 0), Vector3(0.13, maxf(position.y - 0.8, 0.1), 0.13), "rust", true)
	label(title, frame * Vector3(0, 0.25, 0.15), 38, Color("e4ddbd"), 0.011, false, yaw)
	if not subtitle.is_empty():
		label(subtitle, frame * Vector3(0, -0.4, 0.15), 22, Color("76bfb7"), 0.009, false, yaw)


func label(text: String, position: Vector3, font_size: int = 32, color: Color = Color("e4ddbd"), pixel_size: float = 0.012, billboard: bool = false, yaw: float = 0.0) -> Label3D:
	var node := Label3D.new()
	node.text = text
	node.position = position
	node.rotation_degrees.y = yaw
	node.font_size = font_size
	node.pixel_size = pixel_size
	node.modulate = color
	node.outline_modulate = Color("14282f")
	node.outline_size = 5
	node.billboard = BaseMaterial3D.BILLBOARD_ENABLED if billboard else BaseMaterial3D.BILLBOARD_DISABLED
	node.visibility_range_end = 85.0
	add_child(node)
	_label_count += 1
	return node


# --- Builder: objectives, extraction, enemies ---------------------------------------------------

## A required case: all of them must be collected before extraction unlocks.
func case_at(floor_point: Vector3, title: String) -> void:
	total_loot += 1
	_case_spots.append({"floor_point": floor_point, "title": title})
	_add_pickup(floor_point, title, "case", total_loot - 1)


## An optional cache; it pays on extraction. Often reachable only with the rod.
func bonus_at(floor_point: Vector3, title: String) -> void:
	total_bonus += 1
	_add_pickup(floor_point, title, "bonus", total_bonus - 1)


## The extraction pad (9.4 x 9.4 m, floor-centre point) with cyan markings and a pulsing ring.
func extraction(floor_point: Vector3) -> void:
	extraction_position = floor_point
	_has_extraction = true
	var half: float = EXTRACT_PAD_SIZE * 0.5
	var frame := Transform3D(Basis.IDENTITY, floor_point)
	_part(frame, Vector3(0, 0.025, 0), Vector3(EXTRACT_PAD_SIZE, 0.05, EXTRACT_PAD_SIZE), "dark")
	for x: float in [-half, half]:
		_part(frame, Vector3(x, 0.08, 0), Vector3(0.18, 0.06, EXTRACT_PAD_SIZE), "cyan")
	for z: float in [-half, half]:
		_part(frame, Vector3(0, 0.08, z), Vector3(EXTRACT_PAD_SIZE, 0.06, 0.18), "cyan")
	_part(frame, Vector3(0, 0.11, 0), Vector3(4.2, 0.05, 0.3), "cyan")
	_part(frame, Vector3(0, 0.11, 0), Vector3(0.3, 0.05, 4.2), "cyan")
	_extract_ring = MeshInstance3D.new()
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 3.8
	ring_mesh.bottom_radius = 3.8
	ring_mesh.height = 0.05
	ring_mesh.radial_segments = 32
	_extract_ring.mesh = ring_mesh
	_extract_ring.material_override = _ring_material()
	_extract_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_extract_ring.position = floor_point + Vector3(0, 0.09, 0)
	add_child(_extract_ring)


## Hounds and sentries today; drones and dummies arrive with tasks E2 and E3. Raids only:
## practice levels skip everything except dummies.
func enemy(kind: String, position: Vector3, params: Dictionary = {}) -> void:
	if practice and kind != "dummy":
		return
	if kind != "hound" and kind != "sentry":
		push_warning("Level %s: enemy kind '%s' is not available yet; skipped." % [level_id, kind])
		return
	var node := EnemyScript.new()
	add_child(node)
	node.setup(_player, kind, position)
	node.set("damage_scale", damage_scale)
	if params.has("health"):
		node.set("health", float(params["health"]))
	node.fired.connect(func(origin: Vector3, end: Vector3) -> void: FX.tracer(self, origin, end, Color("ef654e"), 0.03, 0.12))
	node.alerted.connect(func(text: String) -> void: threat_changed.emit(text))
	if node.has_signal("died"):
		node.connect("died", func(dead_kind: String, by: String) -> void: enemy_killed.emit(dead_kind, by))
	_enemies.append(node)


# --- Runtime ------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_clock += delta
	_animate_features()
	if not _active or not is_instance_valid(_player):
		return
	_update_pickups()
	_update_extraction()
	_update_features(delta)


func _update_pickups() -> void:
	var player_position: Vector3 = _player.global_position
	for pickup: Dictionary in _pickups.duplicate():
		var mesh: MeshInstance3D = pickup["mesh"]
		mesh.position.y = 0.4 + sin(_clock * 2.5 + float(pickup["index"])) * 0.08
		var centre: Vector3 = (pickup["position"] as Vector3) + Vector3.UP * 0.9
		if player_position.distance_to(centre) >= PICKUP_RADIUS:
			continue
		_pickups.erase(pickup)
		(pickup["node"] as Node3D).queue_free()
		_collect(pickup)


func _collect(pickup: Dictionary) -> void:
	var kind: String = pickup["kind"]
	var centre: Vector3 = (pickup["position"] as Vector3) + Vector3.UP * 0.9
	FX.burst(self, centre, Vector3.UP, Color("5ad6c8") if kind == "case" else Color("ffc46b"), 16, 6.0, 0.5, 0.07)
	if kind == "case":
		collected_loot += 1
		loot_collected.emit("case", ProfileScript.CASE_REWARD)
		if collected_loot >= total_loot:
			threat_changed.emit("ALL CASES SECURED — REACH EXTRACTION")
		else:
			threat_changed.emit("CASE SECURED — %d OF %d" % [collected_loot, total_loot])
	else:
		collected_bonus.append(int(pickup["index"]))
		loot_collected.emit("bonus", ProfileScript.BONUS_REWARD)
		threat_changed.emit("BONUS CACHE FOUND — PAYS ON EXTRACTION")


func _update_extraction() -> void:
	if not _has_extraction:
		return
	var offset: Vector3 = _player.global_position - extraction_position
	var inside: bool = absf(offset.x) < EXTRACT_HALF_SIZE and absf(offset.z) < EXTRACT_HALF_SIZE and offset.y > -0.5 and offset.y < 3.0
	if inside != _inside_extraction:
		_inside_extraction = inside
		extraction_changed.emit(inside)
	if is_instance_valid(_extract_ring):
		var pulse: float = 0.96 + sin(_clock * 2.0) * 0.03
		_extract_ring.scale = Vector3(pulse, 1, pulse)


## Sidearm hit scan. True when an enemy was hit.
func apply_shot(origin: Vector3, direction: Vector3, damage: float) -> bool:
	if not _active or direction.length_squared() < 0.01:
		return false
	var aim: Vector3 = direction.normalized()
	var end: Vector3 = origin + aim * SHOT_RANGE
	var query := PhysicsRayQueryParameters3D.create(origin, end, LAYER_WEAPON_TARGETS)
	if _player is CollisionObject3D:
		query.exclude = [(_player as CollisionObject3D).get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	var hit_enemy: bool = false
	if not hit.is_empty():
		end = hit["position"]
		var collider: Object = hit["collider"]
		if collider.has_method("take_damage"):
			collider.call("take_damage", damage, "bullet")
			hit_enemy = true
		elif collider is RigidBody3D:
			(collider as RigidBody3D).apply_central_impulse(aim * 18.0)
		FX.burst(self, end, hit.get("normal", Vector3.UP), Color("ef654e") if hit_enemy else Color("ffc46b"), 8 if hit_enemy else 5, 5.0, 0.25, 0.05)
	FX.tracer(self, origin + Vector3(0, -0.12, 0), end, Color("ffc46b"), 0.025, 0.09)
	return hit_enemy


## Quick-and-cheap danger estimate 0..1 for music and the HUD: how close the nearest living
## enemy is, boosted when it is tracking the player.
func threat_level() -> float:
	if not is_instance_valid(_player) or not _active:
		return 0.0
	var best: float = 0.0
	for enemy_node: Node in _enemies:
		if not is_instance_valid(enemy_node) or not enemy_node.is_in_group("enemies"):
			continue
		var distance: float = _player.global_position.distance_to((enemy_node as Node3D).global_position)
		var level: float = clampf(1.0 - distance / 45.0, 0.0, 1.0)
		if enemy_node.has_method("is_tracking") and bool(enemy_node.call("is_tracking")):
			level = maxf(level, 0.7)
		best = maxf(best, level)
	return best


## Where the HUD and compass should point (CONTRACT 5.8).
func get_objectives() -> Array:
	var result: Array = []
	for pickup: Dictionary in _pickups:
		var is_case: bool = pickup["kind"] == "case"
		result.append({
			"position": (pickup["position"] as Vector3) + Vector3.UP * 0.9,
			"kind": pickup["kind"],
			"label": str(pickup["title"]),
			"active": true,
		})
		if not is_case:
			result[result.size() - 1]["label"] = "CACHE " + str(pickup["title"])
	if _has_extraction:
		result.append({
			"position": extraction_position + Vector3.UP * 1.0,
			"kind": "extract",
			"label": "EXTRACT",
			"active": collected_loot >= total_loot,
		})
	return result


## True when position (level space; levels sit at the origin) is inside any hazard volume.
func is_hazard_at(position: Vector3) -> bool:
	for record: Dictionary in _hazards:
		if (record["box"] as AABB).has_point(position):
			return true
	return false


## Solid, flat ground under position that is not a hazard: a fair place to respawn.
func is_safe_ground(position: Vector3) -> bool:
	if not is_inside_tree():
		return false
	var query := PhysicsRayQueryParameters3D.create(position + Vector3.UP * 0.5, position + Vector3.DOWN * 3.0, LAYER_WORLD)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var normal: Vector3 = hit["normal"]
	return normal.y > 0.7 and not is_hazard_at(hit["position"])


## Navigation arrives with task F9.
func bake_navigation(_synchronous: bool = false) -> void:
	pass


func get_nav_path(_from: Vector3, _to: Vector3) -> PackedVector3Array:
	return PackedVector3Array()


## Shadows, glow and SSAO by quality level (0 low, 1 medium, 2 high).
func apply_quality(value: int) -> void:
	quality = clampi(value, 0, 2)
	if is_instance_valid(_sun):
		_sun.shadow_enabled = quality >= 1
		_sun.directional_shadow_max_distance = [40.0, 70.0, 100.0][quality]
		_sun.directional_shadow_mode = [DirectionalLight3D.SHADOW_ORTHOGONAL, DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS][quality]
	if _environment != null:
		_environment.glow_enabled = quality >= 2
		_environment.ssao_enabled = quality >= 2 and RenderingServer.get_current_rendering_method() == "forward_plus"
		_environment.fog_density = _fog_base * [1.25, 1.0, 1.0][quality]


# --- Level features (task F8) -------------------------------------------------------------------
# Features are cheap per-frame checks over small registries: a box test per updraft, hazard and
# hint zone, and a body test for the player and cast weights. Their visuals are separate nodes
# because they move, so each level keeps only a handful of them.

## Builder: a magnetic plate that latches weights. facing is the side the plate faces; weights
## arrive from that side. The plate is world geometry (layer 1) in group "anchor".
func anchor(position: Vector3, facing: Vector3 = Vector3.DOWN) -> void:
	var plate_size := Vector3(1.2, 0.12, 1.2)
	var body := StaticBody3D.new()
	body.name = "Anchor"
	body.add_to_group("anchor")
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
	var up: Vector3 = facing if facing.length_squared() > 0.0001 else Vector3.DOWN
	body.transform = Transform3D(_basis_with_up(up), position)
	var shape := BoxShape3D.new()
	shape.size = plate_size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	var mesh := BoxMesh.new()
	mesh.size = plate_size
	var plate := MeshInstance3D.new()
	plate.mesh = mesh
	plate.material_override = _materials["cyan"]
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(plate)
	add_child(body)


## Builder: rising air. base is the bottom centre of the column. strength is the upward
## acceleration (m/s^2) given to the player and to cast weights inside it; gravity is 12.
func updraft(base: Vector3, size: Vector3, strength: float = 26.0) -> void:
	var record: Dictionary = _new_volume("updraft", base, size)
	record["strength"] = strength
	_updrafts.append(record)
	_add_volume_visuals(record, 0.1)


## Builder: a damaging volume. kind is "electric", "heat" or "water"; center is the middle of the
## box. dps is damage per second at damage_scale 1.0 (the difficulty setting). Practice keeps
## hazards on purpose, so they still hurt there.
func hazard(center: Vector3, size: Vector3, kind: String = "electric", dps: float = 30.0) -> void:
	var kind_name: String = kind
	if not HAZARD_KINDS.has(kind):
		push_warning("Level %s: hazard kind '%s' is unknown; using electric." % [level_id, kind])
		kind_name = "electric"
	var record: Dictionary = _new_volume(kind_name, center - Vector3.UP * size.y * 0.5, size)
	record["dps"] = dps
	_hazards.append(record)
	_add_volume_visuals(record, 0.3 if kind_name == "water" else 0.12)


## Builder (call from _design): a water surface with its top at center.y. Deep water is also a
## water hazard three metres deep, under the surface.
func water(center: Vector3, size: Vector2, deep: bool = false) -> void:
	_box_at(Transform3D(Basis.IDENTITY, center - Vector3.UP * 0.06), Vector3(size.x, 0.12, size.y), "water", false)
	if deep:
		hazard(center - Vector3.UP * 1.5, Vector3(size.x, 3.0, size.y), "water", WATER_DPS)


## Builder: an invisible trigger box. The first time the player enters it, hint_requested fires
## with the text ({tokens} are left for the HUD to expand). It never fires again in this build.
func hint_zone(center: Vector3, size: Vector3, text: String, duration: float = 6.0) -> void:
	_hint_zones.append({"box": AABB(center - size * 0.5, size), "text": text, "duration": duration, "fired": false})


## Builder: a point light with a small glowing fitting. At most MAX_LIGHTS per level; extra lights
## are skipped with a warning so the budget stays visible.
func light(position: Vector3, color: Color, energy: float = 1.2, light_range: float = 14.0) -> void:
	if _light_count >= MAX_LIGHTS:
		push_warning("Level %s: over the %d light cap; light at %s skipped." % [level_id, MAX_LIGHTS, position])
		return
	_light_count += 1
	var lamp := OmniLight3D.new()
	lamp.position = position
	lamp.light_color = color
	lamp.light_energy = energy
	lamp.omni_range = light_range
	lamp.shadow_enabled = false
	add_child(lamp)
	var sphere := SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	sphere.radial_segments = 8
	sphere.rings = 4
	var fitting := MeshInstance3D.new()
	fitting.mesh = sphere
	fitting.material_override = FX.glow_material(color, 2.0)
	fitting.position = position
	fitting.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fitting)


## Builder (call from _design): a ring of dark towers far off with amber window strips. Deterministic
## for a given seed_value. Not solid, and merged with the other static geometry.
func skyline(seed_value: int, center: Vector3, inner_radius: float, outer_radius: float, count: int = 24) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for _tower in range(count):
		var angle: float = rng.randf() * TAU
		var distance: float = rng.randf_range(inner_radius, outer_radius)
		var width: float = rng.randf_range(6.0, 14.0)
		var depth: float = rng.randf_range(6.0, 12.0)
		var height: float = rng.randf_range(12.0, 38.0)
		var frame := Transform3D(Basis(Vector3.UP, rng.randf() * TAU), center + Vector3(cos(angle) * distance, height * 0.5, sin(angle) * distance))
		_box_at(frame, Vector3(width, height, depth), "dark", false)
		var window_frame: Transform3D = frame * Transform3D(Basis.IDENTITY, Vector3(0.0, height * 0.25, depth * 0.5 + 0.02))
		_box_at(window_frame, Vector3(width * 0.5, 0.35, 0.04), "amber", false)


## Builder (call from _design): solid walls around a rectangle on the ground, with a yellow cap so
## the edge reads at speed.
func perimeter(center: Vector3, size: Vector2, height: float = 6.0, material: String = "dark") -> void:
	var half: Vector2 = size * 0.5
	var thickness: float = 0.6
	# Each run is {offset from centre, wall size}. The north and south walls cover the corners.
	var runs: Array[Array] = [
		[Vector3(0.0, 0.0, -half.y), Vector3(size.x + thickness, height, thickness)],
		[Vector3(0.0, 0.0, half.y), Vector3(size.x + thickness, height, thickness)],
		[Vector3(-half.x, 0.0, 0.0), Vector3(thickness, height, size.y)],
		[Vector3(half.x, 0.0, 0.0), Vector3(thickness, height, size.y)],
	]
	for run: Array in runs:
		var offset: Vector3 = run[0]
		var wall: Vector3 = run[1]
		box(center + offset + Vector3.UP * height * 0.5, wall, material, true)
		box(center + offset + Vector3.UP * (height + 0.1), Vector3(wall.x, 0.2, wall.z), "yellow", false)


## Cases back on the floor, for repeatable levels (the range) after an extraction.
func restock_cases() -> void:
	for pickup: Dictionary in _pickups.duplicate():
		if pickup["kind"] == "case":
			_pickups.erase(pickup)
			(pickup["node"] as Node3D).queue_free()
	collected_loot = 0
	for index in range(_case_spots.size()):
		var spot: Dictionary = _case_spots[index]
		_add_pickup(spot["floor_point"] as Vector3, str(spot["title"]), "case", index)


## Hazard damage for one step at position: the dps of every hazard that contains it, times
## damage_scale and the step length. The level applies this to the player every physics frame.
func hazard_damage_at(position: Vector3, delta: float) -> float:
	var total: float = 0.0
	for record: Dictionary in _hazards:
		if (record["box"] as AABB).has_point(position):
			total += float(record["dps"])
	return total * damage_scale * maxf(delta, 0.0)


func _update_features(delta: float) -> void:
	_apply_updrafts()
	_apply_hazards(delta)
	_check_hint_zones()


## Updrafts push the player and cast weights upward. A force lasts one physics step, so this
## runs every frame from _physics_process.
func _apply_updrafts() -> void:
	if _updrafts.is_empty():
		return
	var bodies: Array[RigidBody3D] = []
	if _player is RigidBody3D:
		bodies.append(_player as RigidBody3D)
	for node: Node in get_tree().get_nodes_in_group("cast_weight"):
		if node is RigidBody3D:
			bodies.append(node as RigidBody3D)
	for body: RigidBody3D in bodies:
		var local: Vector3 = to_local(body.global_position)
		for record: Dictionary in _updrafts:
			if not (record["box"] as AABB).has_point(local):
				continue
			# A sleeping body would ignore the push until something else woke it.
			body.sleeping = false
			body.apply_central_force(Vector3.UP * float(record["strength"]) * body.mass)


func _apply_hazards(delta: float) -> void:
	if _hazards.is_empty() or not _player.has_method("take_damage"):
		return
	var damage: float = hazard_damage_at(to_local(_player.global_position), delta)
	if damage <= 0.0:
		return
	_player.call("take_damage", damage)
	_zap_hazard()


## Zaps are throttled so standing in a hazard sounds like a rhythm, not a constant buzz.
func _zap_hazard() -> void:
	if _clock - _zap_time < HAZARD_ZAP_INTERVAL:
		return
	_zap_time = _clock
	var audio: Node = get_tree().get_first_node_in_group("game_audio")
	if is_instance_valid(audio) and audio.has_method("play"):
		audio.call("play", "hazard_zap")


## Each hint zone asks for its hint once per build, the first time the player enters it.
func _check_hint_zones() -> void:
	var local: Vector3 = to_local(_player.global_position)
	for zone: Dictionary in _hint_zones:
		if bool(zone["fired"]) or not (zone["box"] as AABB).has_point(local):
			continue
		zone["fired"] = true
		hint_requested.emit(str(zone["text"]), float(zone["duration"]))


## Visual motion only, so it runs even while the level is inactive.
func _animate_features() -> void:
	for record: Dictionary in _updrafts:
		_animate_motes(record)
	for record: Dictionary in _hazards:
		_animate_motes(record)


func _new_volume(kind: String, origin: Vector3, size: Vector3) -> Dictionary:
	return {
		"kind": kind,
		"origin": origin,
		"size": size,
		"box": AABB(origin - Vector3(size.x, 0.0, size.z) * 0.5, size),
		"motes": null,
	}


## A translucent shell around the volume plus a MultiMesh of moving motes (one draw call).
func _add_volume_visuals(record: Dictionary, shell_alpha: float) -> void:
	var kind: String = record["kind"]
	var origin: Vector3 = record["origin"]
	var size: Vector3 = record["size"]
	var color: Color = _feature_color(kind)
	var shell_mesh := BoxMesh.new()
	shell_mesh.size = size
	var shell := MeshInstance3D.new()
	shell.mesh = shell_mesh
	shell.material_override = _tint_material(color, shell_alpha)
	shell.position = origin + Vector3.UP * size.y * 0.5
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shell)
	var mote_mesh := BoxMesh.new()
	var count: int = 8
	match kind:
		"updraft":
			mote_mesh.size = Vector3(0.06, 1.2, 0.06)
		"heat":
			mote_mesh.size = Vector3(0.12, 0.7, 0.12)
		"electric":
			mote_mesh.size = Vector3(0.035, 1.0, 0.035)
			count = 10
		_:
			# Water: flat glints sliding over the surface.
			mote_mesh.size = Vector3(0.6, 0.02, 0.1)
			count = 12
	var motes := MultiMesh.new()
	motes.transform_format = MultiMesh.TRANSFORM_3D
	motes.mesh = mote_mesh
	motes.instance_count = count
	# Motes stay near the volume, so a box the size of the volume (plus margin) is enough for culling.
	motes.custom_aabb = (record["box"] as AABB).grow(1.5)
	var node := MultiMeshInstance3D.new()
	node.multimesh = motes
	node.material_override = FX.glow_material(Color(color, 0.85), 2.0)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	record["motes"] = motes
	_animate_motes(record)


func _animate_motes(record: Dictionary) -> void:
	var motes: MultiMesh = record["motes"] as MultiMesh
	if motes == null:
		return
	var kind: String = record["kind"]
	var origin: Vector3 = record["origin"]
	var size: Vector3 = record["size"]
	for index in range(motes.instance_count):
		motes.set_instance_transform(index, _mote_transform(kind, index, motes.instance_count, origin, size))


## Where mote number index sits right now. Updraft streaks rise, heat wobbles as it rises,
## electric arcs flicker in new spots, and water glints slide along the surface.
func _mote_transform(kind: String, index: int, count: int, origin: Vector3, size: Vector3) -> Transform3D:
	var fraction: float = float(index) / float(count)
	match kind:
		"updraft", "heat":
			var rise: float = 6.0 if kind == "updraft" else 2.4
			var height: float = fposmod(_clock * rise / size.y + fraction, 1.0) * size.y
			var angle: float = fraction * TAU
			var wobble: float = sin(_clock * 2.0 + float(index)) * 0.12 if kind == "heat" else 0.0
			var offset := Vector3(cos(angle) * size.x * (0.3 + wobble), height, sin(angle) * size.z * 0.3)
			return Transform3D(Basis.IDENTITY, origin + offset)
		"electric":
			# Each arc lives for one flicker step (about 9 per second), then jumps somewhere else.
			var slot: float = floorf(_clock * 9.0) + float(index) * 1.7
			if _hash01(slot * 3.1 + float(index)) < 0.45:
				return Transform3D(Basis.from_scale(Vector3.ZERO), origin)
			var arc_height: float = size.y * (0.3 + 0.5 * _hash01(slot * 7.3 + 1.0))
			var spot := Vector3(
				(_hash01(slot * 5.7) * 2.0 - 1.0) * size.x * 0.45,
				(size.y - arc_height) * _hash01(slot * 2.9 + 3.0) + arc_height * 0.5,
				(_hash01(slot * 4.1 + 2.0) * 2.0 - 1.0) * size.z * 0.45)
			return Transform3D(Basis.from_scale(Vector3(1.0, arc_height, 1.0)), origin + spot)
		_:
			var along: float = fposmod(_clock * 0.9 + fraction, 1.0) * size.x - size.x * 0.5
			var across: float = (fraction * 2.0 - 1.0) * size.z * 0.35
			return Transform3D(Basis.IDENTITY, origin + Vector3(along, size.y + 0.03, across))


## Cheap deterministic pseudo-random value in 0..1, used to scatter the electric arcs.
static func _hash01(value: float) -> float:
	return absf(fmod(sin(value * 12.9898 + 78.233) * 43758.5453, 1.0))


static func _feature_color(kind: String) -> Color:
	match kind:
		"updraft":
			return Color("5ad6c8")
		"heat":
			return Color("ff7a1a")
		"electric":
			return Color("ffe066")
		_:
			return Color("2aa7c4")


## Translucent unshaded tint for volume shells.
static func _tint_material(color: Color, alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(color, alpha)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.35
	return material


## A basis whose Y axis is up (any unit vector). Used to orient anchor plates.
static func _basis_with_up(up: Vector3) -> Basis:
	var y: Vector3 = up.normalized()
	var x: Vector3 = Vector3.RIGHT.cross(y)
	if x.length_squared() < 0.0001:
		x = Vector3.FORWARD.cross(y)
	x = x.normalized()
	return Basis(x, y, x.cross(y))


# --- Build internals ----------------------------------------------------------------------------

func _finish_build() -> void:
	_pending_count = _pending.size()
	_merge_statics()
	_build_environment()
	apply_quality(quality)


func _frame(origin: Vector3, yaw_degrees: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_degrees)), origin)


## A box placed relative to a parent frame (used by the composite builders).
func _part(frame: Transform3D, local_position: Vector3, size: Vector3, material: String, solid: bool = false) -> Node3D:
	return _box_at(frame * Transform3D(Basis.IDENTITY, local_position), size, material, solid)


func _box_at(placement: Transform3D, size: Vector3, material: String, solid: bool) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := _stage_mesh(mesh, placement, material)
	if solid:
		var shape := BoxShape3D.new()
		shape.size = size
		_add_collider(shape, placement)
	return instance


func _cylinder_at(placement: Transform3D, radius: float, height: float, material: String, solid: bool) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	var instance := _stage_mesh(mesh, placement, material)
	if solid:
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		_add_collider(shape, placement)
	return instance


func _stage_mesh(mesh: Mesh, placement: Transform3D, material: String) -> MeshInstance3D:
	if not _materials.has(material):
		push_warning("Level %s: unknown material '%s', using concrete." % [level_id, material])
		material = "concrete"
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.transform = placement
	instance.set_meta("material", material)
	_stage.add_child(instance)
	_pending.append(instance)
	return instance


func _add_collider(shape: Shape3D, placement: Transform3D) -> void:
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.transform = placement
	_body.add_child(collision)


## Merges every staged mesh into one mesh per material, then frees the staging nodes.
func _merge_statics() -> void:
	var tools: Dictionary = {}
	for instance: MeshInstance3D in _pending:
		if not is_instance_valid(instance):
			continue
		var key: String = instance.get_meta("material")
		if not tools.has(key):
			var fresh := SurfaceTool.new()
			fresh.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[key] = fresh
		(tools[key] as SurfaceTool).append_from(instance.mesh, 0, instance.transform)
	_merged_count = tools.size()
	_pending.clear()
	remove_child(_stage)
	_stage.free()
	var keys: Array = tools.keys()
	keys.sort()
	for key: String in keys:
		var merged := MeshInstance3D.new()
		merged.name = "Static_" + key
		merged.mesh = (tools[key] as SurfaceTool).commit()
		merged.material_override = _materials[key]
		if NO_SHADOW_KEYS.has(key):
			merged.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(merged)


func _build_environment() -> void:
	var preset: Dictionary = ZONES[zone]
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(str(preset["sky_top"]))
	sky_material.sky_horizon_color = Color(str(preset["sky_horizon"]))
	sky_material.ground_bottom_color = Color(str(preset["ground_bottom"]))
	sky_material.ground_horizon_color = Color(str(preset["ground_horizon"]))
	sky_material.sun_angle_max = 8.0
	sky.sky_material = sky_material
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color(str(preset["ambient"]))
	_environment.ambient_light_energy = float(preset["ambient_energy"])
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_environment.fog_enabled = true
	_environment.fog_light_color = Color(str(preset["fog"]))
	_environment.fog_light_energy = 0.65
	_fog_base = float(preset["fog_density"])
	_environment.fog_density = _fog_base
	var holder := WorldEnvironment.new()
	holder.name = "WorldEnvironment"
	holder.environment = _environment
	holder.add_to_group("world_env")
	add_child(holder)
	_sun = DirectionalLight3D.new()
	_sun.name = "Sun"
	_sun.rotation_degrees = preset["sun_rotation"]
	_sun.light_color = Color(str(preset["sun"]))
	_sun.light_energy = float(preset["sun_energy"])
	_sun.shadow_enabled = true
	_sun.add_to_group("sun")
	add_child(_sun)


func _add_pickup(floor_point: Vector3, title: String, kind: String, index: int) -> void:
	var is_case: bool = kind == "case"
	var node := Node3D.new()
	node.position = floor_point
	add_child(node)
	var body := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = Vector3(1.2, 0.55, 0.8) if is_case else Vector3(0.9, 0.5, 0.9)
	body.mesh = shape
	body.material_override = _materials["yellow" if is_case else "orange"]
	body.position.y = 0.4
	node.add_child(body)
	for x: float in [-0.4, 0.4]:
		var stripe := MeshInstance3D.new()
		var stripe_mesh := BoxMesh.new()
		stripe_mesh.size = Vector3(0.08, 0.58, 0.82)
		stripe.mesh = stripe_mesh
		stripe.material_override = _materials["dark"]
		stripe.position = Vector3(x, 0.4, 0)
		body.add_child(stripe)
		stripe.position = Vector3(x, 0, 0)
	var marker := Label3D.new()
	marker.text = ("◇  SALVAGE\n" if is_case else "◇  BONUS CACHE\n") + title
	marker.position.y = 2.5
	marker.font_size = 32
	marker.pixel_size = 0.012
	marker.modulate = Color("5ad6c8") if is_case else Color("ffc46b")
	marker.outline_modulate = Color("101e24")
	marker.outline_size = 8
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.visibility_range_end = 70.0
	node.add_child(marker)
	_label_count += 1
	var beam := MeshInstance3D.new()
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 0.045
	beam_mesh.bottom_radius = 0.045
	beam_mesh.height = 6.0
	beam_mesh.radial_segments = 6
	beam.mesh = beam_mesh
	beam.material_override = _materials["cyan" if is_case else "amber"]
	beam.position.y = 3.5
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(beam)
	_pickups.append({"node": node, "mesh": body, "position": floor_point, "kind": kind, "index": index, "title": title})


func _ring_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	var color := Color(0.2, 0.85, 0.72, 0.12)
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


# --- Materials ----------------------------------------------------------------------------------

static func _zone_materials(zone_name: String) -> Dictionary:
	if _material_cache.has(zone_name):
		return _material_cache[zone_name]
	var colors: Dictionary = ZONES[zone_name]["colors"]
	var result: Dictionary = {}
	for key: String in colors:
		result[key] = _make_material(key, Color(str(colors[key])))
	_material_cache[zone_name] = result
	return result


static func _make_material(key: String, color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	if GLOW_KEYS.has(key):
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.0
		return material
	if GRIME_KEYS.has(key):
		# World-space triplanar noise: grime that never stretches, whatever a box's size.
		material.albedo_texture = _grime()
		material.uv1_triplanar = true
		material.uv1_world_triplanar = true
		material.uv1_scale = Vector3.ONE * GRIME_SCALE
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	match key:
		"metal":
			material.metallic = 0.55
			material.roughness = 0.45
		"glass":
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_color = Color(color, 0.38)
			material.roughness = 0.08
		"water":
			material.roughness = 0.12
			material.metallic = 0.3
	return material


## Seamless grayscale noise, built once for every material and every level.
static func _grime() -> ImageTexture:
	if _grime_texture != null:
		return _grime_texture
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.045
	noise.fractal_octaves = 4
	noise.seed = 7041
	var image: Image = noise.get_seamless_image(256, 256, false, false, 0.1)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var value: float = image.get_pixel(x, y).r
			var shade: float = lerpf(0.76, 1.0, clampf(value, 0.0, 1.0))
			image.set_pixel(x, y, Color(shade, shade, shade, 1.0))
	image.generate_mipmaps()
	_grime_texture = ImageTexture.create_from_image(image)
	return _grime_texture
