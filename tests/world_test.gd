extends SceneTree
## Real-physics integration checks for salvage, extraction, weapon hits, and enemy tells.

const Catalog = preload("res://scripts/level_catalog.gd")
const PlayerScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/enemy.gd")

var _scene: Node3D
var _player: RigidBody3D
var _world: Node3D
var _failures: int = 0
var _checks: int = 0
var _loot_total: int = 0
var _loot_events: int = 0
var _loot_kinds: Array[String] = []
var _salvage: int = 0
var _extraction_events: Array[bool] = []


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
	_scene.queue_free()
	await _frames(3)
	print("WORLD TEST: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _test_framework() -> void:
	_check(Catalog.campaign_ids() == ["l01"], "catalog lists only the campaign levels that exist")
	_check(Catalog.all_ids().size() == 11 and Catalog.all_ids()[10] == "range", "catalog lists all eleven levels, range last")
	var details: Dictionary = Catalog.info("l01")
	_check(details["available"] and details["title"] == "SLUICE GATE" and details["zone"] == "floodworks", "catalog merges the level INFO")
	_check(not Catalog.info("l02")["available"], "levels without a script are unavailable")
	_check(Catalog.info("range")["practice"] and not Catalog.info("range")["available"], "the range is known to be practice before it exists")
	_check(Catalog.info("bogus").is_empty() and Catalog.create("bogus") == null and Catalog.create("l02") == null, "unknown or missing levels give empty info and no instance")
	_check(Catalog.next_id("l01") == "" and Catalog.next_id("range") == "", "no level follows the last available one")
	_check(Catalog.zone_ids("floodworks") == ["l01"] and Catalog.zone_ids("foundry").is_empty(), "zone lists hold available levels only")
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
		elif node is StaticBody3D:
			bodies += 1
		elif node is CollisionShape3D:
			shapes += 1
	print("LEVEL l01: %d staged primitives merged into %d meshes, %d triangles, %d labels, %d collision shapes" % [int(_world.get("_pending_count")), statics, triangles, labels, shapes])
	_check(statics >= 6 and statics <= 14, "static geometry merged to one mesh per material")
	_check(meshes <= 80, "scene holds few mesh instances after merging")
	_check(triangles <= 250000, "level stays inside the triangle budget")
	_check(labels <= 60, "level stays inside the Label3D budget")
	_check(bodies == 1 and shapes > 100, "all solid primitives share one static body")
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
	_check(is_equal_approx(float(_player.get("health")), 88.0), "nearby visible hound attacks the real player")
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
