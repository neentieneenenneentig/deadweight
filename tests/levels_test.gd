extends SceneTree
## Level validation suite (F9). For every catalog level that has a script (or the one named by
## --only=<id>) it builds the level, checks its INFO (CONTRACT 5.6), placement and budgets, bakes the
## navmesh (CONTRACT 4.11) and checks that walkable paths reach every case and the extraction.
## It also prints the route length, suggested par times, draw calls, triangles and bake time.
## Usage: godot --headless --fixed-fps 90 --path . --script res://tests/levels_test.gd
## Options after "--": --only=<id>. A named level with no script is a FAIL; unnamed ones are skipped.

const Catalog = preload("res://scripts/level_catalog.gd")
const LevelBase = preload("res://scripts/level_base.gd")

const PATH_TOLERANCE := 1.6          # a nav path must end this close to its target (metres)
const MAX_BAKE_MS := 2000.0          # acceptance: the synchronous navmesh bake takes under 2 s
const ASYNC_TIMEOUT_MS := 20000      # the threaded bake gets this long before it counts as stuck
const MAX_LABELS := 60
const MAX_LIGHTS := 6
const ROUTE_SPEED := 5.8             # m/s behind the par suggestion (player GROUND_SPEED; route / 5.8 is the raw run)
## Par suggestion (C10 lead pass): silver is a steady on-foot run with fighting (1.6x the raw run), gold
## beats a flat-out run so it needs rod speed (0.9x); both add the extraction hold. Rounded to 5 s.
const PAR_SILVER_FACTOR := 1.6
const PAR_GOLD_FACTOR := 0.9
const EXTRACTION_HOLD := 6.0         # s; main.gd EXTRACTION_SECONDS
const SPAWN_CLEARANCE := 0.4         # sphere radius for "not inside a solid" at the spawn
const CASE_CLEARANCE := 0.3          # sphere radius for "not inside a solid" at a case
## Required INFO keys (CONTRACT 5.6) and their types. "repeatable" is optional and checked if present.
const INFO_TYPES := {
	"title": TYPE_STRING, "zone": TYPE_STRING, "number": TYPE_INT, "blurb": TYPE_STRING,
	"par_silver": TYPE_FLOAT, "par_gold": TYPE_FLOAT, "cases": TYPE_INT, "bonus": TYPE_INT,
	"enemies": TYPE_BOOL, "practice": TYPE_BOOL,
}

var _only: String = ""
var _checks: int = 0
var _failures: int = 0
var _scene: Node3D


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			_only = argument.substr(7)
	_run.call_deferred()


func _run() -> void:
	_scene = Node3D.new()
	root.add_child(_scene)
	for id: String in _level_ids():
		await _validate_level(id)
	print("")
	print("LEVELS TEST: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


## The levels this run covers: the one named by --only, else every catalog level with a script.
func _level_ids() -> Array[String]:
	var ids: Array[String] = []
	if not _only.is_empty():
		ids.append(_only)
		return ids
	for id: String in Catalog.all_ids():
		if bool(Catalog.info(id).get("available", false)):
			ids.append(id)
		else:
			print("SKIP %s: no level script yet" % id)
	return ids


func _validate_level(id: String) -> void:
	print("")
	print("LEVEL %s" % id)
	var failures_before: int = _failures
	var details: Dictionary = Catalog.info(id)
	var available: bool = bool(details.get("available", false))
	_check(available, "%s: has a level script" % id)
	if available:
		await _validate_built_level(id, str(details["script"]))
	print("RESULT %s: %s" % [id, "PASS" if _failures == failures_before else "FAIL"])


## Reads INFO from the script, builds the level in a holder (freed at the end), and runs every check.
func _validate_built_level(id: String, script_path: String) -> void:
	var script: Script = load(script_path) as Script
	_check(script != null, "%s: level script loads" % id)
	if script == null:
		return
	var declared: Dictionary = script.get_script_constant_map().get("INFO", {})
	_check_info(id, declared)
	var holder := Node3D.new()
	_scene.add_child(holder)
	var dummy := Node3D.new()
	holder.add_child(dummy)
	var level: Node3D = Catalog.create(id)
	_check(level != null, "%s: level script instantiates" % id)
	if level != null:
		holder.add_child(level)
		await _build_and_check(id, level, dummy, declared, holder)
	holder.queue_free()
	await _frames(2)


## INFO is the level's public card (CONTRACT 5.6): every key present with the right type.
func _check_info(id: String, info: Dictionary) -> void:
	for key: String in INFO_TYPES:
		var right_type: bool = info.has(key) and typeof(info[key]) == INFO_TYPES[key]
		_check(right_type, "%s: INFO.%s is present with the right type" % [id, key])
	_check(LevelBase.ZONES.has(str(info.get("zone", ""))), "%s: INFO.zone is a known zone" % id)
	_check(float(info.get("par_gold", 0.0)) <= float(info.get("par_silver", 0.0)), "%s: gold par is no longer than silver par" % id)
	if info.has("repeatable"):
		_check(typeof(info["repeatable"]) == TYPE_BOOL, "%s: INFO.repeatable is a bool" % id)


## Builds the level as INFO says (practice or raid), then runs the counts, budget, placement,
## navigation and report checks on it.
func _build_and_check(id: String, level: Node3D, dummy: Node3D, info: Dictionary, holder: Node3D) -> void:
	var build_start: int = Time.get_ticks_msec()
	level.call("build", dummy, bool(info.get("practice", false)))
	var build_ms: int = Time.get_ticks_msec() - build_start
	# Physics frames let the colliders reach the physics space before any shape or ray query.
	await _frames(2)
	_check(str(level.get("level_id")) == id, "%s: level knows its id" % id)
	var cases: Array[Vector3] = _case_floor_points(level.call("get_objectives"))
	var spawn: Vector3 = level.get("spawn_position")
	var extraction: Vector3 = level.get("extraction_position")
	_check_counts(id, level, info, cases)
	_check_budgets(id, level)
	_check_placement(id, level, spawn, cases, extraction)
	var triangles: int = _count_triangles(level)

	var bake_start: int = Time.get_ticks_msec()
	level.call("bake_navigation", true)
	var bake_ms: int = Time.get_ticks_msec() - bake_start
	_check(bool(level.get("navigation_ready")), "%s: synchronous bake sets navigation_ready" % id)
	_check(bake_ms < MAX_BAKE_MS, "%s: navmesh bake takes under 2 s (%d ms)" % [id, bake_ms])
	# The navigation map syncs on a physics frame, so queries wait for one.
	await _frames(1)
	var route: float = _check_navigation(id, level, spawn, cases, extraction)

	var draw_calls: int = await _measure_draw_calls(holder, spawn, float(level.get("spawn_yaw")))
	var async_ms: int = await _check_threaded_bake(id, level, spawn, extraction)
	_print_report(info, route, cases.size(), draw_calls, triangles, build_ms, bake_ms, async_ms)


## Built counts against INFO: required cases, bonus caches, and enemies present only when INFO says so.
func _check_counts(id: String, level: Node3D, info: Dictionary, cases: Array[Vector3]) -> void:
	var expected_cases: int = int(info.get("cases", 0))
	_check(cases.size() == expected_cases and int(level.get("total_loot")) == expected_cases, "%s: %d cases match INFO.cases" % [id, cases.size()])
	var bonus: int = int(level.get("total_bonus"))
	_check(bonus == int(info.get("bonus", 0)), "%s: %d bonus caches match INFO.bonus" % [id, bonus])
	var enemies: Array[Node] = _enemies_in(level)
	_check((enemies.size() > 0) == bool(info.get("enemies", false)), "%s: %d enemies agree with INFO.enemies" % [id, enemies.size()])
	print("  enemies by kind: %s" % _kind_summary(enemies))


## Label3D and light counts stay inside the budget. Lights include the sun, which is a light node.
func _check_budgets(id: String, level: Node3D) -> void:
	var labels: int = level.find_children("*", "Label3D", true, false).size()
	var lights: int = level.find_children("*", "Light3D", true, false).size()
	_check(labels <= MAX_LABELS, "%s: %d Label3D nodes stay within %d" % [id, labels, MAX_LABELS])
	_check(lights <= MAX_LIGHTS, "%s: %d light nodes stay within %d (sun included)" % [id, lights, MAX_LIGHTS])


## Nothing spawns inside a solid, and the extraction pad sits on ground.
func _check_placement(id: String, level: Node3D, spawn: Vector3, cases: Array[Vector3], extraction: Vector3) -> void:
	_check(not _solid_at(level, spawn, SPAWN_CLEARANCE), "%s: spawn is clear of solids" % id)
	for index in range(cases.size()):
		# A case's centre sits 0.9 m above its floor point; the sphere tests that spot.
		_check(not _solid_at(level, cases[index] + Vector3.UP * 0.9, CASE_CLEARANCE), "%s: case %d is clear of solids" % [id, index + 1])
	var hit: Dictionary = _ground_below(level, extraction)
	var on_ground: bool = false
	if not hit.is_empty():
		var hit_point: Vector3 = hit["position"]
		var normal: Vector3 = hit["normal"]
		on_ground = absf(hit_point.y - extraction.y) < 0.15 and normal.y > 0.7
	_check(on_ground, "%s: extraction pad sits on ground" % id)


## Nav paths from the spawn to every case and to the extraction, then the route length through
## them in declaration order (spawn, case 1, ..., extraction). Returns -1 when the route is broken.
func _check_navigation(id: String, level: Node3D, spawn: Vector3, cases: Array[Vector3], extraction: Vector3) -> float:
	for index in range(cases.size()):
		_check_path(id, level, spawn, cases[index], "case %d" % (index + 1))
	_check_path(id, level, spawn, extraction, "extraction")
	var targets: Array[Vector3] = []
	targets.append_array(cases)
	targets.append(extraction)
	var route: float = 0.0
	var from: Vector3 = spawn
	for target: Vector3 in targets:
		var leg: PackedVector3Array = level.call("get_nav_path", from, target)
		if leg.is_empty() or leg[leg.size() - 1].distance_to(target) > PATH_TOLERANCE:
			_check(false, "%s: route leg reaches %s" % [id, target])
			return -1.0
		route += _path_length(leg)
		from = target
	return route


## A nav path from `from` must end within PATH_TOLERANCE of `to`.
func _check_path(id: String, level: Node3D, from: Vector3, to: Vector3, label: String) -> void:
	var path: PackedVector3Array = level.call("get_nav_path", from, to)
	var gap: float = INF
	if not path.is_empty():
		gap = path[path.size() - 1].distance_to(to)
	_check(gap <= PATH_TOLERANCE, "%s: nav path from spawn reaches %s (ends %.2f m away, limit %.1f)" % [id, label, gap, PATH_TOLERANCE])


## Draw calls from a camera at the spawn looking along the spawn yaw. Headless runs have no GPU, so
## the number can read as zero there; the windowed level_preview gives the real figure.
func _measure_draw_calls(holder: Node3D, spawn: Vector3, yaw: float) -> int:
	var camera := Camera3D.new()
	camera.fov = 78.0
	camera.far = 600.0
	holder.add_child(camera)
	var eye: Vector3 = spawn + Vector3.UP * 0.7
	camera.global_position = eye
	camera.look_at(eye + Vector3(-sin(yaw), 0.05, -cos(yaw)), Vector3.UP)
	camera.make_current()
	for i in range(3):
		await process_frame
	return int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))


## The threaded bake path must finish, set navigation_ready and still reach the extraction.
## Returns the wall time it took in ms.
func _check_threaded_bake(id: String, level: Node3D, spawn: Vector3, extraction: Vector3) -> int:
	var start: int = Time.get_ticks_msec()
	level.call("bake_navigation", false)
	while not bool(level.get("navigation_ready")) and Time.get_ticks_msec() - start < ASYNC_TIMEOUT_MS:
		await physics_frame
	var elapsed: int = Time.get_ticks_msec() - start
	var ready: bool = bool(level.get("navigation_ready"))
	_check(ready, "%s: threaded bake finishes and sets navigation_ready (%d ms)" % [id, elapsed])
	if ready:
		await _frames(1)
		var path: PackedVector3Array = level.call("get_nav_path", spawn, extraction)
		_check(path.size() >= 2, "%s: threaded bake still reaches the extraction" % id)
	return elapsed


## Per-level numbers for the log. Par suggestions use the route at ROUTE_SPEED; no-clock levels
## (practice, par_silver 0) get no suggestion.
func _print_report(info: Dictionary, route: float, case_count: int, draw_calls: int, triangles: int, build_ms: int, bake_ms: int, async_ms: int) -> void:
	var par_silver: float = float(info.get("par_silver", 0.0))
	if route < 0.0:
		print("  route: broken, no walkable path through every case")
	else:
		print("  route %.0f m through %d case(s) to extraction" % [route, case_count])
	if par_silver <= 0.0:
		print("  par: no clock (practice level), no suggestion")
	elif route >= 0.0:
		var raw: float = route / ROUTE_SPEED
		print("  suggested par: silver %.0f s, gold %.0f s (INFO: silver %.0f s, gold %.0f s)" % [
			snappedf(raw * PAR_SILVER_FACTOR + EXTRACTION_HOLD, 5.0), snappedf(raw * PAR_GOLD_FACTOR + EXTRACTION_HOLD, 5.0),
			par_silver, float(info.get("par_gold", 0.0))])
	print("  draw calls %d, triangles %d" % [draw_calls, triangles])
	print("  navmesh bake %d ms (threaded %d ms), level build %d ms" % [bake_ms, async_ms, build_ms])


## Case floor points in declaration order. get_objectives reports each pickup's centre (floor + 0.9 m),
## so the floor point is recovered by taking that height off.
func _case_floor_points(objectives: Array) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for objective: Dictionary in objectives:
		if objective.get("kind", "") == "case":
			points.append((objective["position"] as Vector3) - Vector3.UP * 0.9)
	return points


func _enemies_in(level: Node3D) -> Array[Node]:
	var found: Array[Node] = []
	for node: Node in get_nodes_in_group("enemies"):
		if level.is_ancestor_of(node):
			found.append(node)
	return found


func _kind_summary(enemies: Array[Node]) -> String:
	var counts: Dictionary = {}
	for enemy: Node in enemies:
		var kind: String = str(enemy.get("kind"))
		counts[kind] = int(counts.get(kind, 0)) + 1
	return str(counts)


## True when a sphere at point touches any solid on layer 1.
func _solid_at(level: Node3D, point: Vector3, radius: float) -> bool:
	var shape := SphereShape3D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, point)
	query.collision_mask = LevelBase.LAYER_WORLD
	var hits: Array = level.get_world_3d().direct_space_state.intersect_shape(query, 1)
	return not hits.is_empty()


## The first layer-1 surface a ray hits when it drops onto point from 1 m above it.
func _ground_below(level: Node3D, point: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 1.0, point + Vector3.DOWN * 2.0, LevelBase.LAYER_WORLD)
	return level.get_world_3d().direct_space_state.intersect_ray(query)


## Triangles in the level's mesh instances: index count / 3, or vertex count / 3 for unindexed meshes.
func _count_triangles(level: Node3D) -> int:
	var total: int = 0
	for node: Node in level.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (node as MeshInstance3D).mesh
		if mesh == null:
			continue
		for surface in range(mesh.get_surface_count()):
			var arrays: Array = mesh.surface_get_arrays(surface)
			var indices: Variant = arrays[Mesh.ARRAY_INDEX]
			if indices is PackedInt32Array and not (indices as PackedInt32Array).is_empty():
				total += (indices as PackedInt32Array).size() / 3
			else:
				total += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total


func _path_length(path: PackedVector3Array) -> float:
	var total: float = 0.0
	for index in range(1, path.size()):
		total += path[index - 1].distance_to(path[index])
	return total


func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("PASS: " + description)
	else:
		_failures += 1
		push_error("FAIL: " + description)
