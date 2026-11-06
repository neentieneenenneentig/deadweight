extends SceneTree
## Real-physics integration checks for salvage, extraction, weapon hits, and enemy tells.

const Catalog = preload("res://scripts/level_catalog.gd")
const PlayerScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const RangeScript = preload("res://scripts/levels/range.gd")
const LevelBase = preload("res://scripts/level_base.gd")
## Hound navigation tests build their own small level here, far from the Sluice Gate geometry so the
## shared physics space holds nothing else.
const ARENA := Vector3(500.0, 0.0, 0.0)
const ATTACK_REACH := 2.2            # planar metres: close enough that the hound is biting range

var _scene: Node3D
var _player: RigidBody3D
var _world: Node3D
var _range: Node3D
var _failures: int = 0
var _checks: int = 0
var _loot_total: int = 0
var _loot_events: int = 0
var _loot_kinds: Array[String] = []
var _salvage: int = 0
var _extraction_events: Array[bool] = []
var _hint_events: int = 0
var _range_loot: int = 0
var _deaths: int = 0
var _death_kind: String = ""
var _death_by: String = ""
var _damage_log: Array = []          # [amount, source] for every hit the player takes
var _level_kills: int = 0            # enemy_killed relays the range level emitted
var _level_kill_kind: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_scene = Node3D.new()
	root.add_child(_scene)
	_player = PlayerScript.new()
	_scene.add_child(_player)
	_player.freeze = true
	_player.set("active", true)
	_player.global_position = Vector3(0, 0.92, 14)
	_player.connect("damaged", _on_player_damaged)
	_world = Catalog.create("l01")
	_scene.add_child(_world)
	_world.call("build", _player, true)
	_world.connect("loot_collected", _on_loot)
	_world.connect("extraction_changed", _on_extraction)
	await _frames(4)
	_check(get_nodes_in_group("enemies").is_empty(), "practice has no enemies")
	await _test_framework()
	await _test_salvage()
	await _test_extraction()
	await _test_weapon_collision()
	await _test_hound_damage()
	await _test_sentry_telegraph()
	await _test_raid_population()
	await _test_features()
	await _test_hound_wall_route()
	await _test_hound_gives_up()
	await _test_hound_dies_once()
	await _test_drone_orb_dodge()
	await _test_drone_orb_hits()
	await _test_drone_dies_once()
	await _test_dummies()
	await _test_threat()
	await _test_sentry_tracking()
	_test_thaw()
	_test_nature_lod()
	await _test_yuzu_run()
	await _test_ducklings()
	await _test_starfall()
	_test_merge_mix()
	_scene.queue_free()
	await _frames(3)
	print("WORLD TEST: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _test_framework() -> void:
	# These checks hold as levels land: l09 (v1.1) is the stand-in for a level without a script.
	var campaign: Array[String] = Catalog.campaign_ids()
	_check(campaign.has("l01") and not campaign.has("l09") and not campaign.has("range"), "catalog lists only the campaign levels that exist")
	var ids: Array[String] = Catalog.all_ids()
	_check(ids.size() == 17 and ids[7] == "h01" and ids[8] == "h02" and ids[9] == "h03" and ids[10] == "h04" and ids[11] == "h05" and ids[15] == "range" and ids[16] == "valley", "catalog lists all seventeen levels: h01 to h05 after l06, then the range and the highlands preview last")
	_check(campaign[campaign.size() - 1] == "h05", "STARFALL is the last errand of the campaign (its win shows the ending)")
	var details: Dictionary = Catalog.info("l01")
	_check(details["available"] and details["title"] == "SLUICE GATE" and details["zone"] == "floodworks", "catalog merges the level INFO")
	_check(not Catalog.info("l09")["available"], "levels without a script are unavailable")
	_check(Catalog.info("range")["practice"] and Catalog.info("range")["available"], "the range is practice and available now that its script exists")
	_check(Catalog.info("bogus").is_empty() and Catalog.create("bogus") == null and Catalog.create("l09") == null, "unknown or missing levels give empty info and no instance")
	_check(Catalog.next_id(campaign[campaign.size() - 1]) == "" and Catalog.next_id("range") == "", "no level follows the last available one")
	var floodworks: Array[String] = Catalog.zone_ids("floodworks")
	var all_available: bool = true
	for id: String in floodworks:
		all_available = all_available and bool(Catalog.info(id)["available"])
	_check(floodworks.has("l01") and floodworks.has("range") and all_available and Catalog.zone_ids("spillway").is_empty(), "zone lists hold available levels only")
	var info: Dictionary = _world.get("info")
	_check(_world.get("level_id") == "l01" and info["title"] == "SLUICE GATE", "created level knows its id and INFO")
	_check(int(info["cases"]) == int(_world.get("total_loot")) and int(info["bonus"]) == int(_world.get("total_bonus")), "INFO case and bonus counts match the built level")
	_check((_world.get("spawn_position") as Vector3).is_equal_approx(Vector3(0, 0.95, 14)), "spawn is floor + 0.95")
	_check((_world.get("extraction_position") as Vector3).is_equal_approx(Vector3(16, 0, -116)), "extraction position is the pad floor centre")
	_check(get_nodes_in_group("sun").size() == 1 and get_nodes_in_group("world_env").size() == 1, "sun and world environment are grouped")
	var statics: int = 0
	var triangles: int = 0
	var meshes: int = 0
	var labels: int = 0
	var bodies: int = 0
	var shapes: int = 0
	for node in _world.find_children("*", "", true, false):
		if node is MeshInstance3D:
			meshes += 1
			if node.name.begins_with("Static_"):
				statics += 1
				triangles += (node.mesh as Mesh).get_faces().size() / 3
		elif node is Label3D:
			labels += 1
		elif node is StaticBody3D and node.name not in ["Scenery", "PendulumBall", "AlpineRidgesBody", "Grove"]:
			bodies += 1   # the scenery bodies (S1) are separate on purpose: the navmesh bake skips them
		elif node is CollisionShape3D:
			shapes += 1
	print("LEVEL l01: %d staged primitives merged into %d meshes, %d triangles, %d labels, %d collision shapes" % [int(_world.get("_pending_count")), statics, triangles, labels, shapes])
	_check(statics >= 6 and statics <= 14, "static geometry merged to one mesh per material")
	_check(meshes <= 80, "scene holds few mesh instances after merging")
	_check(triangles <= 250000, "level stays inside the triangle budget")
	_check(labels <= 60, "level stays inside the Label3D budget")
	_check(bodies == 1 and shapes > 100, "all solid primitives share one static body")
	var ridges: MeshInstance3D = _world.get_node("AlpineRidges")
	var ridge_body: StaticBody3D = _world.get_node("AlpineRidgesBody")
	var ridge_shape: ConcavePolygonShape3D = (ridge_body.get_child(0) as CollisionShape3D).shape
	_check(ridge_shape.get_faces() == ridges.mesh.get_faces() and ridge_body in _world.get("nav_skip_bodies"), "mountains have an exact solid surface outside the route navmesh")
	# V2b: the groves on the snow are solid, like every tree, and stay out of the route navmesh.
	var grove: StaticBody3D = _world.get_node_or_null("Grove")
	var pines: MultiMeshInstance3D = _world.get_node_or_null("Pines")
	_check(grove != null and pines != null and pines.multimesh.instance_count > 20 and grove in _world.get("nav_skip_bodies"), "pine groves stand between the works and the mountains, off the navmesh")
	if grove != null and grove.get_child_count() > 0:
		# Headless MultiMesh buffers read back as identity, so take the tree from its trunk collider.
		var tree: Vector3 = (grove.get_child(0) as Node3D).position
		await physics_frame
		var probe := PhysicsRayQueryParameters3D.create(Vector3(tree.x + 0.6, 30.0, tree.z + 0.6), Vector3(tree.x + 0.6, tree.y + 0.5, tree.z + 0.6), 1)
		var top: Dictionary = _world.get_world_3d().direct_space_state.intersect_ray(probe)
		_check(not top.is_empty() and top["collider"] == grove and float(top["position"].y) > tree.y + 1.0, "a grove pine's crown is solid")
	_check(_world.get_node_or_null("Snowfall") is GPUParticles3D, "alpine levels have snowfall")
	_check(int(_world.get("_pending_count")) > 300, "the prototype's primitives were staged before merging")
	for quality in [0, 1, 2, 5]:
		_world.call("apply_quality", quality)
	var sun: DirectionalLight3D = get_first_node_in_group("sun")
	_check(int(_world.get("quality")) == 2 and sun.shadow_enabled, "quality clamps and high quality enables shadows")
	_world.call("apply_quality", 0)
	_check(not sun.shadow_enabled, "low quality disables sun shadows")
	_world.call("apply_quality", 2)
	_check(_world.call("is_safe_ground", Vector3(0, 0, 0)), "open floor is safe ground")
	_check(not _world.call("is_safe_ground", Vector3(0, -50, 0)), "the void is not safe ground")
	_check(not _world.call("is_hazard_at", Vector3.ZERO), "no hazards yet")
	_check(is_zero_approx(float(_world.call("threat_level"))), "no enemies, no threat")
	var objectives: Array = _world.call("get_objectives")
	_check(objectives.size() == 6, "objectives list 3 cases, 2 bonus caches and the extraction")
	var extract_objective: Dictionary = objectives[objectives.size() - 1]
	_check(extract_objective["kind"] == "extract" and not extract_objective["active"], "extraction objective starts locked")
	_check(objectives[0]["kind"] == "case" and objectives[3]["kind"] == "bonus", "objectives are cases first, then bonus caches")


func _test_salvage() -> void:
	_world.call("set_active", false)
	await _move_player(Vector3(-15, 3.3, -18))
	_check(_loot_total == 0, "inactive world cannot collect salvage")
	_world.call("set_active", true)
	await _frames(3)
	_check(_loot_total == 1 and _loot_events == 1, "entering first cache collects one case")
	await _frames(10)
	_check(_loot_total == 1 and _loot_events == 1, "remaining in cache does not collect repeatedly")
	await _move_player(Vector3(-15, 3.3, -12))
	await _move_player(Vector3(-15, 3.3, -18))
	_check(_loot_total == 1, "returning to collected cache does not duplicate salvage")
	await _move_player(Vector3(14, 5.9, -54))
	await _move_player(Vector3(-13, 0.9, -91))
	_check(_loot_total == 3 and _loot_events == 3, "all three physical cache locations are collectible")
	_check(int(_world.get("total_loot")) == 3, "world objective matches available case count")
	_check(int(_world.get("collected_loot")) == 3, "level tracks collected cases")
	_check(_salvage == 45 and _loot_kinds == ["case", "case", "case"], "each case pays 15 salvage and reports kind case")
	_check(int(_world.get("total_bonus")) == 2, "level declares two bonus caches")
	await _move_player(Vector3(0, 9.1, -54))
	await _move_player(Vector3(-15, 6.3, -93))
	_check(_loot_kinds.slice(3) == ["bonus", "bonus"], "both bonus caches report kind bonus")
	_check(_salvage == 45 + 60, "each bonus cache pays 30 salvage")
	_check(_world.get("collected_bonus") == [0, 1], "level tracks collected bonus indices")
	_check(int(_world.get("collected_loot")) == 3, "bonus caches do not count as required cases")
	var objectives: Array = _world.call("get_objectives")
	_check(objectives.size() == 1 and objectives[0]["kind"] == "extract" and objectives[0]["active"], "only the unlocked extraction remains as an objective")


func _test_extraction() -> void:
	await _move_player(Vector3(16, 5, -116))
	_check(_extraction_events.is_empty(), "flying above extraction does not enter ground volume")
	await _move_player(Vector3(16, 0.9, -116))
	_check(_extraction_events == [true], "enter extraction emits true once")
	await _frames(8)
	_check(_extraction_events == [true], "holding extraction does not repeat enter event")
	await _move_player(Vector3(9, 0.9, -116))
	_check(_extraction_events == [true, false], "leaving extraction emits false")
	await _move_player(Vector3(16, 0.9, -116))
	_world.call("set_active", false)
	_check(_extraction_events == [true, false, true, false], "deactivating raid clears extraction occupancy")
	_world.call("set_active", true)
	await _move_player(Vector3(0, 0.92, 14))


func _test_weapon_collision() -> void:
	var enemy: CharacterBody3D = _new_enemy("hound", Vector3(0, 0.05, 2))
	await _frames(3)
	var origin: Vector3 = _player.global_position + Vector3.UP * 0.15
	var aim: Vector3 = (enemy.global_position + Vector3.UP * 0.65 - origin).normalized()
	var hit: bool = _world.call("apply_shot", origin, aim, 30.0)
	_check(hit and is_equal_approx(float(enemy.get("health")), 40.0), "sidearm ray hits real enemy collider and applies damage")
	var wall: StaticBody3D = _test_wall(Vector3(0, 1.5, 8))
	await _frames(3)
	hit = _world.call("apply_shot", origin, aim, 30.0)
	_check(not hit and is_equal_approx(float(enemy.get("health")), 40.0), "solid cover blocks sidearm damage")
	wall.queue_free()
	await _frames(3)
	_world.call("set_active", false)
	hit = _world.call("apply_shot", origin, aim, 30.0)
	_check(not hit and is_equal_approx(float(enemy.get("health")), 40.0), "inactive world rejects sidearm shots")
	_world.call("set_active", true)
	enemy.call("take_damage", -20.0)
	_check(is_equal_approx(float(enemy.get("health")), 40.0), "negative damage cannot heal an enemy")
	hit = _world.call("apply_shot", origin, aim, 45.0)
	_check(hit and not enemy.is_in_group("enemies") and enemy.collision_layer == 0, "lethal shot removes enemy combat collision and target group")
	var dead_health: float = float(enemy.get("health"))
	enemy.call("take_damage", 50.0)
	_check(is_equal_approx(float(enemy.get("health")), dead_health), "dead enemy ignores further damage")
	enemy.queue_free()
	await _frames(3)


func _test_hound_damage() -> void:
	_player.set("health", 100.0)
	await _move_player(Vector3(0, 0.92, 14))
	var enemy: CharacterBody3D = _new_enemy("hound", Vector3(0, 0.05, 12.7))
	enemy.call("set_active", true)
	await _frames(5)
	_check(is_equal_approx(float(_player.get("health")), 100.0), "the bite has a visible crouch first: no damage in the first frames")
	await create_timer(0.45, true, true).timeout
	_check(is_equal_approx(float(_player.get("health")), 88.0), "nearby visible hound attacks the real player")
	_check(_planar_gap(enemy, _player) > 0.9, "the biting hound stops short of the player instead of running into them")
	await _frames(10)
	_check(is_equal_approx(float(_player.get("health")), 88.0), "hound bite cooldown prevents every-frame damage")
	enemy.call("set_active", false)
	await create_timer(1.2, true, true).timeout
	_check(is_equal_approx(float(_player.get("health")), 88.0), "inactive enemy cannot damage player")
	enemy.queue_free()
	await _frames(3)


func _test_sentry_telegraph() -> void:
	_player.set("health", 100.0)
	await _move_player(Vector3(0, 0.92, 14))
	var enemy: CharacterBody3D = _new_enemy("sentry", Vector3(0, 0, 2))
	enemy.call("set_active", true)
	await create_timer(0.35, true, true).timeout
	_check(is_equal_approx(float(_player.get("health")), 100.0), "sentry gives warning instead of instant damage")
	await create_timer(1.4, true, true).timeout
	_check(is_equal_approx(float(_player.get("health")), 84.0), "sentry fires after acquisition and damages exposed player")
	enemy.queue_free()
	await _frames(3)
	_player.set("health", 100.0)
	var wall: StaticBody3D = _test_wall(Vector3(0, 1.5, 8))
	enemy = _new_enemy("sentry", Vector3(0, 0, 2))
	enemy.call("set_active", true)
	await create_timer(1.85, true, true).timeout
	_check(is_equal_approx(float(_player.get("health")), 100.0), "solid cover blocks sentry acquisition and damage")
	wall.queue_free()
	enemy.queue_free()
	await _frames(3)
	# Move after the telegraph commits to a position, before the shot arrives.
	enemy = _new_enemy("sentry", Vector3(0, 0, 2))
	enemy.call("set_active", true)
	await create_timer(1.30, true, true).timeout
	await _move_player(Vector3(4, 0.92, 14))
	await create_timer(0.45, true, true).timeout
	_check(is_equal_approx(float(_player.get("health")), 100.0), "dodging committed sentry aim avoids the shot")
	enemy.queue_free()
	await _frames(3)


func _test_raid_population() -> void:
	_world.queue_free()
	await _frames(3)
	_world = Catalog.create("l01")
	_scene.add_child(_world)
	_world.call("build", _player, false)
	await _frames(3)
	_check(get_nodes_in_group("enemies").size() == 5, "raid spawns its hound and sentry population")
	_world.call("set_active", true)
	var all_active: bool = true
	for enemy in get_nodes_in_group("enemies"):
		all_active = all_active and bool(enemy.get("active"))
	_check(all_active, "world activates every raid enemy")
	_world.call("set_active", false)
	var all_inactive: bool = true
	for enemy in get_nodes_in_group("enemies"):
		all_inactive = all_inactive and not bool(enemy.get("active"))
	_check(all_inactive, "world deactivates every raid enemy")


## Level features on a fresh practice range, with real physics. Hazards, lights and the restock
## check use builder calls made after build(); those only add nodes and registry entries.
func _test_features() -> void:
	await _move_player(Vector3(0.0, 0.95, 25.0))
	_range = Catalog.create("range")
	_scene.add_child(_range)
	_range.connect("hint_requested", _on_hint)
	_range.connect("loot_collected", _on_range_loot)
	_range.call("build", _player, true)
	await _frames(3)
	var anchors: Array[Node] = get_nodes_in_group("anchor")
	_check(anchors.size() == 4 and _all_static_bodies(anchors), "anchors are in group anchor as StaticBody3D plates")
	# The outer world (S1): no invisible wall above the visible one, solid ground beyond the walls,
	# bedrock under the floor, and the footprint marks what is in bounds.
	var space: PhysicsDirectSpaceState3D = _range.get_world_3d().direct_space_state
	var mid_z: float = RangeScript.FLOOR_CENTER.z
	var edge_x: float = RangeScript.FLOOR_SIZE.x * 0.5
	# The earlier Sluice Gate fixture shares this physics space. Its mountain scenery
	# must not masquerade as a wall in the independently built practice range.
	var excluded: Array[RID] = []
	for body: Node in _world.find_children("*", "CollisionObject3D", true, false):
		excluded.append((body as CollisionObject3D).get_rid())
	var side_query := PhysicsRayQueryParameters3D.create(Vector3(0.0, 200.0, mid_z), Vector3(edge_x + 50.0, 200.0, mid_z), 1, excluded)
	var side_hit: Dictionary = space.intersect_ray(side_query)
	_check(side_hit.is_empty(), "no invisible wall stands above the range's visible wall")
	var outside := Vector3(edge_x + 40.0, 0.0, mid_z)
	var plain_hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(outside + Vector3.UP * 20.0, outside + Vector3.DOWN * 20.0, 1, excluded))
	_check(not plain_hit.is_empty() and absf(float(plain_hit["position"].y)) < 0.05, "solid ground goes on past the walls, flush with the floor")
	var down_hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0.0, -2.0, mid_z), Vector3(0.0, -60.0, mid_z), 1))
	_check(not down_hit.is_empty() and float(down_hit["position"].y) < float(_range.get("kill_y")), "bedrock lies below kill_y under the floor")
	_check(bool(_range.call("is_in_bounds", Vector3(0.0, 0.0, mid_z))) and not bool(_range.call("is_in_bounds", outside)), "the floor is in bounds and the plain past the walls is not")
	var floating: int = 0
	for text: Node in _range.find_children("*", "Label3D", true, false):
		if (text as Label3D).billboard != BaseMaterial3D.BILLBOARD_DISABLED:
			floating += 1
	_check(floating == 0, "no billboard text floats in the range (%d)" % floating)
	var range_info: Dictionary = _range.get("info")
	_check(bool(range_info["repeatable"]) and bool(range_info["practice"]) and _range.has_method("reset_cases"), "range INFO is repeatable practice and it can reset its cases")

	# Hazards: damage per second is dps x damage_scale, and only inside the volume.
	var hazard_spot := Vector3(-24.0, 0.95, 6.0)
	_range.call("hazard", Vector3(-24.0, 1.5, 6.0), Vector3(4.0, 3.0, 4.0), "heat", 30.0)
	_check(bool(_range.call("is_hazard_at", hazard_spot)) and not bool(_range.call("is_hazard_at", Vector3(-24.0, 0.95, 20.0))), "is_hazard_at is true inside a hazard volume and false outside it")
	_range.set("damage_scale", 1.0)
	var full: float = float(_range.call("hazard_damage_at", hazard_spot, 1.0))
	_range.set("damage_scale", 0.5)
	var relaxed: float = float(_range.call("hazard_damage_at", hazard_spot, 1.0))
	_range.set("damage_scale", 1.5)
	var hardened: float = float(_range.call("hazard_damage_at", hazard_spot, 1.0))
	_check(is_equal_approx(full, 30.0) and is_equal_approx(relaxed, 15.0) and is_equal_approx(hardened, 45.0), "hazard damage per second scales with damage_scale (30 / 15 / 45)")
	_check(is_zero_approx(float(_range.call("hazard_damage_at", Vector3(-24.0, 0.95, 20.0), 1.0))), "no hazard damage outside the volume")

	# Real physics: the range hurts the player on every physics step, scaled by difficulty.
	_range.call("set_active", true)
	await _move_player(hazard_spot)
	_range.set("damage_scale", 0.5)
	_player.set("health", 100.0)
	await _frames(9)
	var lost_relaxed: float = 100.0 - float(_player.get("health"))
	_range.set("damage_scale", 1.5)
	_player.set("health", 100.0)
	await _frames(9)
	var lost_hardened: float = 100.0 - float(_player.get("health"))
	_check(lost_relaxed > 0.0 and is_equal_approx(lost_hardened, lost_relaxed * 3.0), "standing in a hazard costs 3x as much at damage_scale 1.5 as at 0.5")
	_range.set("damage_scale", 1.0)
	await _move_player(Vector3(0.0, 0.95, 25.0))

	# Hint zones: the welcome zone asks for its hint once, however often the player re-enters it.
	var zone_spot := Vector3(RangeScript.HINT_ZONE_CENTER.x, 0.95, RangeScript.HINT_ZONE_CENTER.z)
	_hint_events = 0
	await _move_player(zone_spot)
	var first_entry: int = _hint_events
	await _frames(10)
	await _move_player(Vector3(0.0, 0.95, 25.0))
	await _move_player(zone_spot)
	_check(first_entry == 1 and _hint_events == 1, "a hint zone emits its hint once, not on every entry")

	# Updraft: a RigidBody3D inside the column rises, while a control body outside it falls.
	var lifted: RigidBody3D = _test_body(RangeScript.UPDRAFT_BASE + Vector3(0.0, 2.0, 0.0), true)
	var control: RigidBody3D = _test_body(RangeScript.UPDRAFT_BASE + Vector3(RangeScript.UPDRAFT_SIZE.x * 0.5 + 4.0, 2.0, 0.0), false)
	await _frames(10)
	_check(lifted.linear_velocity.y > 0.5 and lifted.global_position.y > RangeScript.UPDRAFT_BASE.y + 2.0 and lifted.linear_velocity.y > control.linear_velocity.y + 1.0, "an updraft lifts a RigidBody3D in its column while a control body falls")
	lifted.queue_free()
	control.queue_free()

	# Lights: the range has three, and four more requests stop at the cap of six.
	for index in range(4):
		_range.call("light", Vector3(float(index) * 3.0 - 20.0, 3.0, 0.0), Color.WHITE)
	_check(_range.find_children("*", "OmniLight3D", true, false).size() == 6, "lights stop at the cap of six")

	# Repeats: the case pays once, and reset_cases puts it back on the floor for another run.
	var case_spot: Vector3 = RangeScript.CASE_SPOT + Vector3(0.0, 0.95, 0.0)
	await _move_player(case_spot)
	var collected_once: int = _range_loot
	_range.call("reset_cases")
	await _move_player(Vector3(0.0, 0.95, 25.0))
	await _move_player(case_spot)
	_check(collected_once == 1 and _range_loot == 2 and int(_range.get("collected_loot")) == 1, "reset_cases puts the case back so it can be collected again")
	_range.queue_free()
	await _frames(3)


## The hound sees the player, who then steps behind a wall. The hound must route around the wall on the
## navmesh (the chase memory keeps it hunting) and reach biting range from the far side.
func _test_hound_wall_route() -> void:
	var arena: Node3D = _make_arena()
	_add_solid(arena, Vector3(0, 1.5, 3), Vector3(8, 3, 0.6))
	arena.call("bake_navigation", true)
	await _frames(2)
	_check(bool(arena.get("navigation_ready")), "arena navmesh bakes with a wall in it")
	_player.set("health", 100.0)
	await _move_player(ARENA + Vector3(0, 0.92, -4))
	var hound: CharacterBody3D = _new_arena_enemy(arena, "hound", Vector3(0, 0.05, -10))
	hound.call("set_active", true)
	await _frames(2)
	await _move_player(ARENA + Vector3(0, 0.92, 8))   # behind the wall, out of sight
	var ticks: float = float(Engine.physics_ticks_per_second)
	var reached_at: float = -1.0
	for i in range(int(10.0 * ticks)):
		await physics_frame
		if _planar_gap(hound, _player) < ATTACK_REACH:
			reached_at = float(i + 1) / ticks
			break
	print("HOUND ROUTE: attack range %s" % ("not reached" if reached_at < 0.0 else "after %.2f s" % reached_at))
	_check(reached_at > 0.0, "hound routes around the wall to a player it chased from the far side, within 10 s")
	_check(hound.global_position.z > 3.3, "hound ends up on the far side of the wall")
	arena.queue_free()
	await _frames(3)


## A player on a platform the hound cannot climb: after a few failed route checks the hound gives up the
## chase and circles where it stands, instead of chasing up.
func _test_hound_gives_up() -> void:
	var arena: Node3D = _make_arena()
	_add_solid(arena, Vector3(0, 1.5, 8), Vector3(6, 3, 6))   # platform, top at 3 m, no ramp
	arena.call("bake_navigation", true)
	await _frames(2)
	_player.set("health", 100.0)
	await _move_player(ARENA + Vector3(0, 3.92, 8))   # standing on the platform
	var hound: CharacterBody3D = _new_arena_enemy(arena, "hound", Vector3(0, 0.05, -4))
	var start: Vector3 = hound.global_position
	hound.call("set_active", true)
	var ticks: float = float(Engine.physics_ticks_per_second)
	var top: float = 0.0
	var farthest: float = 0.0
	var closest: float = INF
	for i in range(int(3.0 * ticks)):
		await physics_frame
		top = maxf(top, hound.global_position.y)
		farthest = maxf(farthest, hound.global_position.distance_to(start))
		closest = minf(closest, _planar_gap(hound, _player))
	_check(not bool(hound.call("is_tracking")), "hound gives up on a player it cannot reach and stops tracking")
	_check(top < 0.6, "hound never climbs toward the platform")
	_check(farthest > 1.5 and farthest < 7.0, "hound circles below at a patrol radius, neither idle nor wandering off")
	_check(closest > 4.0, "hound never gets near the unreachable player")
	_check(is_equal_approx(float(_player.get("health")), 100.0), "no bite lands on the unreachable player")
	arena.queue_free()
	await _frames(3)


## Three lethal hits, one death: died fires once, with the hound's kind and the lethal hit's source.
func _test_hound_dies_once() -> void:
	var arena: Node3D = _make_arena()
	var hound: CharacterBody3D = _new_arena_enemy(arena, "hound", Vector3(0, 0.05, 0))
	hound.connect("died", _on_enemy_died)
	_deaths = 0
	_check(hound.find_children("*", "MeshInstance3D", true, false).size() <= 14, "hound model stays within 14 mesh instances")
	hound.call("take_damage", 1.0, "bullet")
	_check(_deaths == 0, "a survivable hit does not fire died")
	hound.call("take_damage", 500.0, "bullet")
	hound.call("take_damage", 500.0, "bullet")
	await _frames(20)
	hound.call("take_damage", 500.0, "bullet")
	_check(_deaths == 1 and _death_kind == "hound" and _death_by == "bullet", "a hound killed three times fires died exactly once, with its kind and source")
	arena.queue_free()
	await _frames(3)


## A drone (CONTRACT 4.13) fires one orb after its charge. The player stands still, so the orb hits and
## deals 14 x damage_scale (21 at 1.5). The drone also closes to about 12 m and hovers 4-10 m up.
func _test_drone_orb_hits() -> void:
	var arena: Node3D = _make_arena()
	_player.set("health", 100.0)
	_damage_log.clear()
	await _move_player(ARENA + Vector3(0, 0.92, 0))
	# setup() takes arena-local coordinates; start the flying enemy in its hover band.
	var drone: CharacterBody3D = _new_arena_enemy(arena, "drone", Vector3(0, 7.05, -12))
	drone.set("damage_scale", 1.5)
	drone.call("set_active", true)
	var orb: Node3D = await _wait_for_orb(arena, 8.0)
	_check(orb != null, "a drone that sees the player charges and launches an orb")
	if orb != null:
		var gap: float = drone.global_position.distance_to(_player.global_position)
		var height: float = drone.global_position.y - ARENA.y
		_check(gap > 10.5 and gap < 13.5, "the drone closes to about 12 m from the player when it fires")
		_check(height >= 4.0 and height <= 10.0, "the drone hovers 4-10 m above its anchor when it fires")
	await _wait_for_damage(4.0)
	_check(_damage_log.size() == 1 and _damage_log[0][1] == "drone" and is_equal_approx(float(_damage_log[0][0]), 21.0), "a still player takes one drone orb hit of 14 x damage_scale (21 at 1.5)")
	_check(is_equal_approx(float(_player.get("health")), 79.0), "the orb hit lowers player health by the same amount")
	arena.queue_free()
	await _frames(3)


## A drone orb can be dodged. The player steps 1.5 m sideways as soon as the orb leaves. The orb still
## passes the player's old spot (the aim point), and the player takes no damage.
func _test_drone_orb_dodge() -> void:
	var arena: Node3D = _make_arena()
	_player.set("health", 100.0)
	_damage_log.clear()
	await _move_player(ARENA + Vector3(0, 0.92, 0))
	var drone: CharacterBody3D = _new_arena_enemy(arena, "drone", Vector3(0, 7.05, -12))
	drone.call("set_active", true)
	var orb: Node3D = await _wait_for_orb(arena, 8.0)
	_check(orb != null, "a drone orb is in flight toward the player")
	if orb != null:
		var stood_at: Vector3 = _player.global_position
		var aim_point: Vector3 = stood_at + Vector3.UP * 0.2
		var to_player: Vector3 = stood_at - drone.global_position
		var side: Vector3 = Vector3(-to_player.z, 0.0, to_player.x).normalized()
		await _move_player(stood_at + side * 1.5)
		var ticks: float = float(Engine.physics_ticks_per_second)
		var closest: float = INF
		for i in range(int(4.0 * ticks)):
			await physics_frame
			if not is_instance_valid(orb):
				break
			closest = minf(closest, orb.global_position.distance_to(aim_point))
		_check(closest < 0.4, "the dodged orb passes the player's previous position")
		_check(_damage_log.is_empty() and is_equal_approx(float(_player.get("health")), 100.0), "a player who steps aside is missed by the drone orb")
	arena.queue_free()
	await _frames(3)


## Two lethal hits on a drone: died fires exactly once. The blast hurts the player who stands within
## 3 m of it, and not one who stands farther away.
func _test_drone_dies_once() -> void:
	var arena: Node3D = _make_arena()
	_player.set("health", 100.0)
	await _move_player(ARENA + Vector3(0, 0.92, 0))
	var near: CharacterBody3D = _new_arena_enemy(arena, "drone", Vector3(0, 0.05, 2))
	near.connect("died", _on_enemy_died)
	_deaths = 0
	_damage_log.clear()
	near.call("take_damage", 20.0, "bullet")
	_check(_deaths == 0, "a drone survives a hit short of its 45 HP")
	near.call("take_damage", 30.0, "bullet")
	near.call("take_damage", 500.0, "bullet")
	await _frames(20)
	near.call("take_damage", 500.0, "bullet")
	_check(_deaths == 1 and _death_kind == "drone" and _death_by == "bullet", "a drone killed three times fires died exactly once, with its kind and source")
	_check(_damage_log.size() == 1 and _damage_log[0][1] == "drone" and is_equal_approx(float(_damage_log[0][0]), 25.0), "the blast hurts a player within 3 m, once, at 25 x damage_scale")
	_damage_log.clear()
	var far: CharacterBody3D = _new_arena_enemy(arena, "drone", Vector3(0, 0.05, -6))
	far.connect("died", _on_enemy_died)
	far.call("take_damage", 60.0, "bullet")
	_check(_deaths == 2 and _damage_log.is_empty(), "a player farther than 3 m from a dying drone takes no blast damage")
	arena.queue_free()
	await _frames(3)


## Training dummies in the real practice range (E3), with real physics. A dummy takes sidearm hits and
## flashes, never hurts a player beside it, falls on death, refills 3 s later, and fires died once per kill.
## The level relays enemy_killed for it. The raid world is freed first: it shares the range's origin.
func _test_dummies() -> void:
	_world.queue_free()
	await _frames(3)
	var range_level: Node3D = Catalog.create("range")
	_scene.add_child(range_level)
	range_level.connect("enemy_killed", _on_level_kill)
	range_level.call("build", _player, true)
	range_level.call("set_active", true)
	await _frames(3)
	var dummies: Array[Node] = _enemies_of(range_level, "dummy")
	_check(dummies.size() == 3, "the practice range places its three training dummies")
	if dummies.size() < 3:
		range_level.queue_free()
		await _frames(3)
		return
	var first: CharacterBody3D = dummies[0] as CharacterBody3D
	var second: CharacterBody3D = dummies[2] as CharacterBody3D
	_check(first.global_position.distance_to(RangeScript.DUMMY_SPOTS[0]) < 0.01, "the first dummy stands on its marked spot")
	_check(is_zero_approx(float(range_level.call("threat_level"))), "dummies alone raise no threat")

	# A dummy beside the player never attacks, over four seconds of real time.
	_player.set("health", 100.0)
	_damage_log.clear()
	await _move_player(RangeScript.DUMMY_SPOTS[0] + Vector3(1.6, 0.92, 0.0))
	await _frames(357)
	_check(is_equal_approx(float(_player.get("health")), 100.0) and _damage_log.is_empty(), "a dummy never deals damage to a player standing beside it for four seconds")

	# A sidearm hit flashes the body pale cyan, and the flash fades within a third of a second.
	var body: StandardMaterial3D = first.get("_body_material") as StandardMaterial3D
	var resting_color: Color = body.albedo_color
	var hit: bool = _shoot_dummy(range_level, first, 10.0)
	await _frames(2)
	_check(hit and body.albedo_color != resting_color, "a dummy flashes when a sidearm shot hits it")
	await _frames(30)
	_check(body.albedo_color == resting_color, "the dummy's hit flash fades back to porcelain")

	# A lethal shot fires died once and the level relays it. The dummy stays down for the refill time.
	_deaths = 0
	_death_kind = ""
	_death_by = ""
	_level_kills = 0
	_level_kill_kind = ""
	first.connect("died", _on_enemy_died)
	var lethal: bool = _shoot_dummy(range_level, first, 100.0)
	_check(lethal and _deaths == 1 and _death_kind == "dummy" and _death_by == "bullet", "a lethal sidearm shot fires died once, with kind dummy and source bullet")
	_check(_level_kills == 1 and _level_kill_kind == "dummy", "the practice range relays enemy_killed for a dummy kill")
	_check(not first.is_in_group("enemies") and first.collision_layer == 0, "a downed dummy leaves the target group and stops taking hits")
	await _frames(255)
	_check(bool(first.get("_dead")) and not first.is_in_group("enemies") and _deaths == 1, "a dummy stays down before its 3 s refill")
	await _frames(35)
	_check(not bool(first.get("_dead")) and is_equal_approx(float(first.get("health")), float(first.get("max_health"))) and first.is_in_group("enemies"), "a dummy stands back up at full health about 3 s after its death")

	# The refilled dummy can die again: a second kill is a second emission, and more damage while down adds none.
	_check(_shoot_dummy(range_level, first, 100.0) and _deaths == 2 and _level_kills == 2, "a second kill after the refill fires died again")
	first.call("take_damage", 500.0, "bullet")
	_check(_deaths == 2 and _level_kills == 2, "more damage on a downed dummy fires nothing more")

	# Each death throws exactly one porcelain burst, and a repeat hit on the corpse throws none.
	var bursts_before: int = range_level.find_children("*", "CPUParticles3D", true, false).size()
	second.call("take_damage", 500.0, "bullet")
	var bursts_after: int = range_level.find_children("*", "CPUParticles3D", true, false).size()
	second.call("take_damage", 500.0, "bullet")
	var bursts_final: int = range_level.find_children("*", "CPUParticles3D", true, false).size()
	_check(bursts_after == bursts_before + 1 and bursts_final == bursts_after, "a dummy's death throws exactly one burst of shards")
	range_level.queue_free()
	await _frames(3)


## A hound that sees the player tracks, and the level's threat rises as the player closes in. Inactive
## enemies and dummies add nothing. The arena is a bare level built with the real builder, far from the range.
func _test_threat() -> void:
	var arena: Node3D = LevelBase.new()
	arena.position = ARENA
	_scene.add_child(arena)
	_add_solid(arena, Vector3(0, -0.5, 0), Vector3(40, 1, 40))
	arena.call("build", _player, false)
	arena.call("set_active", true)
	arena.call("enemy", "hound", Vector3(0, 0.05, -30))
	await _move_player(ARENA + Vector3(0, 0.92, 0))
	var hound: CharacterBody3D = _enemies_of(arena, "hound")[0] as CharacterBody3D
	_check(is_zero_approx(float(arena.call("threat_level"))), "an inactive hound is not tracking, so the level has no threat")
	hound.call("set_active", true)
	await _frames(12)
	_check(bool(hound.call("is_tracking")), "a hound that sees the player reports is_tracking")
	var far: float = float(arena.call("threat_level"))
	await _move_player(ARENA + Vector3(0, 0.92, -18))
	var near: float = float(arena.call("threat_level"))
	_check(far > 0.0 and near > far + 0.1, "threat rises as a tracking hound closes in")
	var before: float = float(arena.call("threat_level"))
	arena.call("enemy", "dummy", Vector3(2.0, 0.0, -20.0))
	var after: float = float(arena.call("threat_level"))
	_check(not _enemies_of(arena, "dummy").is_empty() and is_equal_approx(before, after), "a dummy right beside the player adds no threat")
	arena.queue_free()
	await _frames(3)


## A sentry reports is_tracking while it sees the player and through its wind-up, and stops once a wall
## takes its sight and the wind-up has cooled.
func _test_sentry_tracking() -> void:
	var arena: Node3D = _make_arena()
	_player.set("health", 100.0)
	await _move_player(ARENA + Vector3(0, 0.92, 0))
	var sentry: CharacterBody3D = _new_arena_enemy(arena, "sentry", Vector3(0, 0, -10))
	sentry.call("set_active", true)
	await _frames(24)
	_check(bool(sentry.call("is_tracking")), "a sentry that sees the player reports is_tracking")
	_add_solid(arena, Vector3(0, 1.5, -4), Vector3(8, 3, 0.6))
	await _frames(54)
	_check(not bool(sentry.call("is_tracking")), "a sentry behind cover stops tracking once its wind-up cools")
	arena.queue_free()
	await _frames(3)


## An empty level with a floor and its own navmesh, placed far from the shared test geometry.
func _make_arena() -> Node3D:
	var arena: Node3D = LevelBase.new()
	arena.position = ARENA
	_scene.add_child(arena)
	_add_solid(arena, Vector3(0, -0.5, 0), Vector3(40, 1, 40))
	return arena


## A plain solid box on layer 1. The navmesh bake reads the level's children, so walls added this way are baked.
func _add_solid(parent: Node3D, center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = center
	body.collision_layer = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)


func _new_arena_enemy(arena: Node3D, enemy_kind: String, location: Vector3) -> CharacterBody3D:
	var enemy: CharacterBody3D = EnemyScript.new()
	arena.add_child(enemy)
	enemy.call("setup", _player, enemy_kind, location)
	return enemy


## Waits up to `seconds` for a drone orb node to appear under the arena and returns it, or null.
func _wait_for_orb(arena: Node3D, seconds: float) -> Node3D:
	var ticks: float = float(Engine.physics_ticks_per_second)
	for i in range(int(seconds * ticks)):
		await physics_frame
		var orbs: Array[Node] = arena.find_children("*DroneOrb*", "MeshInstance3D", false, false)
		if not orbs.is_empty():
			return orbs[0] as Node3D
	return null


## Waits up to `seconds` until the player has taken a hit.
func _wait_for_damage(seconds: float) -> void:
	var ticks: float = float(Engine.physics_ticks_per_second)
	for i in range(int(seconds * ticks)):
		if not _damage_log.is_empty():
			return
		await physics_frame


func _on_player_damaged(amount: float, source: String, _from_position: Vector3) -> void:
	_damage_log.append([amount, source])


func _planar_gap(a: Node3D, b: Node3D) -> float:
	return Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length()


func _on_enemy_died(kind: String, by: String) -> void:
	_deaths += 1
	_death_kind = kind
	_death_by = by


func _on_level_kill(kind: String, _by: String) -> void:
	_level_kills += 1
	_level_kill_kind = kind


## Every enemy of one kind among a level's direct children (the level adds its enemies as children).
func _enemies_of(level: Node3D, enemy_kind: String) -> Array[Node]:
	var found: Array[Node] = []
	for child: Node in level.get_children():
		if child is CharacterBody3D and str(child.get("kind")) == enemy_kind:
			found.append(child)
	return found


## A sidearm shot from the player's gun hand at a dummy's chest, through the level's real hit scan.
func _shoot_dummy(level: Node3D, dummy: Node3D, damage: float) -> bool:
	var origin: Vector3 = _player.global_position + Vector3.UP * 0.15
	var chest: Vector3 = dummy.global_position + Vector3.UP * 1.2
	return bool(level.call("apply_shot", origin, chest - origin, damage))


func _test_body(location: Vector3, cast_weight: bool) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.mass = 1.0
	body.can_sleep = false
	var shape := CollisionShape3D.new()
	var ball := SphereShape3D.new()
	ball.radius = 0.3
	shape.shape = ball
	body.add_child(shape)
	if cast_weight:
		body.add_to_group("cast_weight")
	_scene.add_child(body)
	body.global_position = location
	return body


func _all_static_bodies(nodes: Array[Node]) -> bool:
	for node: Node in nodes:
		if not (node is StaticBody3D):
			return false
	return true


func _on_hint(_text: String, _duration: float) -> void:
	_hint_events += 1


func _on_range_loot(kind: String, _value: int) -> void:
	if kind == "case":
		_range_loot += 1


func _new_enemy(kind: String, location: Vector3) -> CharacterBody3D:
	var enemy: CharacterBody3D = EnemyScript.new()
	_world.add_child(enemy)
	enemy.call("setup", _player, kind, location)
	return enemy


func _test_wall(location: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.position = location
	wall.collision_layer = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4, 3, 0.5)
	collision.shape = shape
	wall.add_child(collision)
	_scene.add_child(wall)
	return wall


func _move_player(location: Vector3) -> void:
	_player.global_position = location
	await _frames(3)


func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame


func _on_loot(kind: String, value: int) -> void:
	_loot_kinds.append(kind)
	if kind == "case":
		_loot_total += 1
	_loot_events += 1
	_salvage += value


func _on_extraction(inside: bool) -> void:
	_extraction_events.append(inside)


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("PASS: " + description)
	else:
		_failures += 1
		push_error("FAIL: " + description)


## V2b: the highlands' snowfields keep bare, thawed hollows; grass grows only there.
func _test_thaw() -> void:
	var TerrainScript: GDScript = load("res://scripts/world/terrain.gd")
	var land: RefCounted = TerrainScript.new(7319, 1400.0)
	land.call("generate")
	var thawed: int = 0
	var snowy: int = 0
	var both: int = 0
	for i in range(40):
		for j in range(40):
			var x: float = -380.0 + float(i) * 19.0
			var z: float = -380.0 + float(j) * 19.0
			var h: float = land.call("height_at", x, z)
			var t: float = land.call("thaw_at", x, z, h)
			var snow: bool = land.call("is_snow", x, z, h)
			if t > 0.6:
				thawed += 1
				if snow:
					both += 1
			elif snow:
				snowy += 1
	_check(thawed > 80 and snowy > thawed and both == 0, "the valley is mostly snow with thawed hollows (%d thawed, %d snow)" % [thawed, snowy])


## W6: every tree and rock cell has a near view, a far view with a cheaper mesh, and a shadow-only
## caster from the far mesh. The switch moves in with quality, and never leaves a gap.
func _test_nature_lod() -> void:
	var Nature: GDScript = load("res://scripts/world/nature.gd")
	var holder := Node3D.new()
	_scene.add_child(holder)
	var rng := RandomNumberGenerator.new()
	var placements: Array[Transform3D] = []
	for i in range(12):
		placements.append(Transform3D(Basis.IDENTITY, Vector3(float(i) * 70.0 - 400.0, 0.0, 10.0)))
	var near_mesh: ArrayMesh = Nature.call("_pine_mesh")
	var far_mesh: ArrayMesh = Nature.call("_pine_far_mesh")
	Nature.call("_add_multimesh", holder, "Pines", near_mesh, placements, rng, 0.1, 350.0, far_mesh)
	var near: Array[MultiMeshInstance3D] = []
	var far: Array[MultiMeshInstance3D] = []
	var casters: Array[MultiMeshInstance3D] = []
	var instances: int = 0
	for child: Node in holder.get_children():
		var view := child as MultiMeshInstance3D
		if view.name.contains("Shadow"):
			casters.append(view)
		elif view.name.contains("Far"):
			far.append(view)
		else:
			near.append(view)
			instances += view.multimesh.instance_count
	_check(near.size() >= 2 and near.size() == far.size() and near.size() == casters.size() and instances == placements.size(), "each tree cell has a near view, a far view and a shadow caster (%d cells)" % near.size())
	var near_tris: int = near_mesh.get_faces().size() / 3
	var far_tris: int = far_mesh.get_faces().size() / 3
	_check(far_tris * 6 < near_tris, "the far pine is a fraction of the near one (%d vs %d triangles)" % [far_tris, near_tris])
	var shadows_ok: bool = true
	var seamless: bool = true
	for i in range(near.size()):
		shadows_ok = shadows_ok and near[i].cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and far[i].cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and casters[i].cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		seamless = seamless and is_equal_approx(near[i].visibility_range_end, far[i].visibility_range_begin) and near[i].visibility_range_end > 0.0 and far[i].multimesh.instance_count == near[i].multimesh.instance_count
	_check(shadows_ok, "only the cheap caster draws tree shadows")
	_check(seamless, "the near view ends where the far view begins, with the same trees")
	Nature.call("apply_lod", holder, 0)
	var low: float = near[0].visibility_range_end
	Nature.call("apply_lod", holder, 2)
	var high: float = near[0].visibility_range_end
	_check(low < high and is_equal_approx(far[0].visibility_range_begin, high) and is_equal_approx(casters[0].visibility_range_end, high), "lower quality swaps to far trees sooner (%.0f m vs %.0f m)" % [low, high])
	holder.queue_free()


## H03: the marble run follows the hill without a crest a marble would jump, stays walkable, and the
## jammed hopper drops the bin's front wall.
## H04: the aqueduct's paving has open air under it, a fall from the deck hurts without killing, the
## ends meet the ground, and the last duckling sends a collapse along the whole deck.
func _test_ducklings() -> void:
	var holder := Node3D.new()
	_scene.add_child(holder)
	var dummy := Node3D.new()
	holder.add_child(dummy)
	var level: Node3D = Catalog.create("h04")
	holder.add_child(level)
	level.call("build", dummy, false)
	var constants: Dictionary = (level.get_script() as GDScript).get_script_constant_map()
	var land: RefCounted = level.get("land")
	var deck_y: float = level.get("deck_y")
	var traps: Node3D = level.call("traps")
	var fields: Array = traps.get("_fields")
	var deck: Array = level.get("deck_fields")
	_check((level.get("towers") as Array).size() == int(constants["SPANS"]) - 1 and deck.size() == int(constants["SPANS"]) * int(constants["BAYS"]), "the aqueduct has %d towers and %d bays of paving" % [int(constants["SPANS"]) - 1, deck.size()])
	await _frames(2)
	var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	var open: bool = true
	var deepest: float = 0.0
	for index: int in deck:
		for cell: Dictionary in (fields[index]["cells"] as Dictionary).values():
			var at: Vector3 = cell["at"]
			var ground: float = float(land.call("height_at", at.x, at.z))
			deepest = maxf(deepest, deck_y - ground)
			var query := PhysicsRayQueryParameters3D.create(at + Vector3.DOWN * 0.4, Vector3(at.x, ground + 0.3, at.z), LevelBase.LAYER_WORLD)
			if not space.intersect_ray(query).is_empty() and deck_y - ground > 1.0:
				open = false
	_check(open, "nothing solid lies under the paving: a broken slab drops the player to the ground")
	# Princess Capybara is a painted model: it must stop the player like it looks it should.
	var highlands: Dictionary = (level.get_script() as GDScript).get_base_script().get_script_constant_map()
	var tub: Vector3 = level.call("_floor", highlands["TUB_XZ"])
	var scale: float = float(highlands["PRINCESS_SCALE"])
	var crown_ray := PhysicsRayQueryParameters3D.create(tub + Vector3(0.0, 6.0, 0.6 * scale), tub + Vector3(0.0, 1.2, 0.6 * scale), LevelBase.LAYER_WORLD)
	var crown_hit: Dictionary = space.intersect_ray(crown_ray)
	var snout_ray := PhysicsRayQueryParameters3D.create(tub + Vector3(0.0, 1.9 * scale, 5.0), tub + Vector3(0.0, 1.9 * scale, 0.0), LevelBase.LAYER_WORLD)
	var snout_hit: Dictionary = space.intersect_ray(snout_ray)
	_check(not crown_hit.is_empty() and (crown_hit["position"] as Vector3).y > tub.y + 2.5 * scale and not snout_hit.is_empty() and (snout_hit["position"] as Vector3).z > tub.z + 1.3 * scale, "Princess Capybara is solid: her head stops a ray from above and from the front")
	var worst: float = PlayerScript.landing_damage(sqrt(2.0 * 12.0 * deepest))
	_check(deepest > 10.0 and worst < 100.0, "the deepest fall from the deck (%.1f m) hurts (%.0f) without killing" % [deepest, worst])
	var head: Vector3 = level.call("on_line", 0.0)
	var tail: Vector3 = level.call("on_line", float(level.get("causeway_end")) + 2.0)
	_check(absf(deck_y - float(land.call("height_at", head.x, head.z))) < 1.2 and float(land.call("height_at", tail.x, tail.z)) >= deck_y - 0.35, "the deck meets the ground at the spring and where the causeway runs into the hill")
	level.set("collected_loot", int(level.get("total_loot")))
	level.call("_on_duckling_taken", "case", 1)
	var scheduled: bool = true
	for index: int in deck:
		for cell: Dictionary in (fields[index]["cells"] as Dictionary).values():
			scheduled = scheduled and float(cell["due"]) >= 0.0
	_check(scheduled, "once she has all three ducklings every slab on the deck is due to collapse")
	holder.queue_free()
	await _frames(2)


## H05: the Gravity Works' ramp is solid and walkable all the way round to the deck, the mast and
## crow's nest are solid, the lift throws past the deck, the night look is the Foundry's sky, and
## every star taken quickens the starfall.
func _test_starfall() -> void:
	var holder := Node3D.new()
	_scene.add_child(holder)
	var dummy := Node3D.new()
	holder.add_child(dummy)
	var level: Node3D = Catalog.create("h05")
	holder.add_child(level)
	level.call("build", dummy, false)
	var constants: Dictionary = (level.get_script() as GDScript).get_script_constant_map()
	await _frames(2)
	var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	var floor_point: Vector3 = level.get("works_floor")
	var top: float = float(constants["WORKS_TOP"])
	var turn: float = float(level.get("ramp_turn"))
	var solid: bool = true
	var worst_step: float = 0.0
	var last: float = NAN
	var k: float = 0.0
	while k <= turn:
		for r: float in [float(constants["CORE_RADIUS"]) + 0.6, float(constants["RAMP_OUTER"]) - 0.4]:
			var surface: Vector3 = level.call("ramp_point", k, r)
			var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(surface + Vector3.UP * 1.5, surface + Vector3.DOWN * 0.5, LevelBase.LAYER_WORLD))
			solid = solid and not hit.is_empty() and absf((hit["position"] as Vector3).y - surface.y) < 0.1
		var middle: float = (level.call("ramp_point", k, 9.75) as Vector3).y
		if not is_nan(last):
			worst_step = maxf(worst_step, middle - last)
		last = middle
		k += 0.05
	_check(solid, "the Gravity Works' ramp is solid from its foot to the deck, edge to edge")
	_check(worst_step < 0.25 and absf(last - (floor_point.y + top)) < 0.3, "the ramp climbs evenly (%.2f m per step) and arrives level with the deck" % worst_step)
	level.call("bake_navigation", true)
	await _frames(1)
	var foot: Vector3 = level.call("ramp_point", 0.3, 9.75)
	var deck: Vector3 = floor_point + Vector3(3.5, top, 0.0)
	var path: PackedVector3Array = level.call("get_nav_path", foot, deck)
	_check(path.size() > 2 and path[path.size() - 1].distance_to(deck) < 1.6, "a hound can walk the ramp from its foot to the deck")
	var nest_y: float = floor_point.y + top + float(constants["MAST"]) + (constants["NEST"] as Vector3).y
	var nest_hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(floor_point + Vector3(1.5, nest_y + 3.0, 1.5), floor_point + Vector3(1.5, top, 1.5), LevelBase.LAYER_WORLD))
	var mast_hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(floor_point + Vector3(3.0, top + 5.0, 0.0), floor_point + Vector3(0.0, top + 5.0, 0.0), LevelBase.LAYER_WORLD))
	_check(not nest_hit.is_empty() and absf((nest_hit["position"] as Vector3).y - nest_y) < 0.1 and not mast_hit.is_empty(), "the mast and the crow's nest are solid")
	var power: float = float(constants["LIFT_POWER"])
	var throw: float = power * power / (2.0 * 9.8)
	_check(throw > top + 2.0 and throw < top + float(constants["MAST"]), "the public lift throws past the deck (%.0f m) but not up to the crow's nest" % throw)
	var night: Dictionary = level.get("look_override")
	_check(str(night.get("sky", "")) == "nightmare", "the highlands are under the Foundry's night sky")
	var traps: Node3D = level.call("traps")
	_check(not bool(traps.call("is_hunting")), "stars fall far off until the first star is taken")
	var periods: Array[float] = []
	for count in range(1, 4):
		level.set("collected_loot", count)
		level.call("_on_star_taken", "case", 1)
		periods.append(float((traps.get("_starfall") as Dictionary)["hunt_period"]))
	_check(bool(traps.call("is_hunting")) and periods[0] > periods[1] and periods[1] > periods[2], "each star taken quickens the hunt (%s s)" % str(periods))
	holder.queue_free()
	await _frames(2)


## level_base merges each material into one mesh: the chamfered blocks (plain arrays) and the
## primitive boxes (indexed) must both survive the merge.
func _test_merge_mix() -> void:
	var box := BoxMesh.new()
	var block: Mesh = LevelBase.Alpine.block_mesh(Vector3(2.0, 1.0, 1.5))
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.append_from(LevelBase._indexed(block), 0, Transform3D.IDENTITY)
	tool.append_from(LevelBase._indexed(box), 0, Transform3D(Basis.IDENTITY, Vector3(5.0, 0.0, 0.0)))
	var merged: int = tool.commit().get_faces().size() / 3
	var expected: int = block.get_faces().size() / 3 + box.get_faces().size() / 3
	_check(merged == expected, "a merged batch keeps every triangle of mixed block and box meshes (%d of %d)" % [merged, expected])


func _test_yuzu_run() -> void:
	var holder := Node3D.new()
	_scene.add_child(holder)
	var dummy := Node3D.new()
	holder.add_child(dummy)
	var level: Node3D = Catalog.create("h03")
	holder.add_child(level)
	level.call("build", dummy, false)
	var script: GDScript = level.get_script()
	var constants: Dictionary = script.get_script_constant_map()
	var chain: Array = level.get("_chain")
	var land: RefCounted = level.get("land")
	_check(chain.size() >= 10, "the run is planned as a chain of pieces (%d joints)" % chain.size())
	_check(float(level.call("run_grade")) <= float(constants["MAX_GRADE"]) + 0.05, "no piece of the run is steeper than %.0f degrees (%.1f)" % [float(constants["MAX_GRADE"]), float(level.call("run_grade"))])
	var worst_bend: float = 0.0
	var lowest: float = INF
	for i in range(1, chain.size() - 1):
		var here: Vector3 = chain[i]
		worst_bend = maxf(worst_bend, here.y - ((chain[i - 1] as Vector3).y + (chain[i + 1] as Vector3).y) * 0.5)
		lowest = minf(lowest, here.y - float(land.call("height_at", here.x, here.z)))
	_check(worst_bend <= float(constants["MAX_BEND"]) + 0.01, "no crest on the run sharp enough to throw a marble (worst %.2f m)" % worst_bend)
	_check(lowest >= float(constants["CLEARANCE"]) - 0.01, "the run's floor clears the ground at every joint (lowest %.2f m)" % lowest)
	var lintel: float = constants["LINTEL"]
	var radius: float = constants["MARBLE_RADIUS"]
	_check(lintel > LevelBase.NAV_AGENT_HEIGHT + 1.0 and lintel < radius * 2.0 and lintel > radius, "gap bars let a player walk under and stop a marble above its middle")
	var traps: Node3D = level.call("traps")
	_check((traps.call("run_states", 0) as Array).size() == 6, "the hopper holds six marbles")
	var gate: StaticBody3D = level.get_node("BinGate")
	var shut: float = gate.position.y
	level.set("collected_loot", int(level.get("total_loot")))
	level.call("_on_yuzu_taken", "case", 1)
	_check(is_equal_approx(float(traps.get("_run_tempo")), 2.0), "once she has all three yuzu the hopper lets marbles go twice as often")
	await create_timer(1.8, true, true).timeout
	_check(gate.position.y < shut - float(constants["BIN_WALL"]), "and the bin's front wall sinks into the ground")
	holder.queue_free()
	await _frames(2)
