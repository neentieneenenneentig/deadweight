extends SceneTree
## Real-physics integration checks for salvage, extraction, weapon hits, and enemy tells.

const WorldScript = preload("res://scripts/world.gd")
const PlayerScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/enemy.gd")

var _scene: Node3D
var _player: RigidBody3D
var _world: Node3D
var _failures: int = 0
var _checks: int = 0
var _loot_total: int = 0
var _loot_events: int = 0
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
	_world = WorldScript.new()
	_scene.add_child(_world)
	_world.call("build", _player, true)
	_world.connect("loot_collected", _on_loot)
	_world.connect("extraction_changed", _on_extraction)
	await _frames(4)
	_check(get_nodes_in_group("enemies").is_empty(), "practice has no enemies")
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
	_world = WorldScript.new()
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


func _on_loot(value: int) -> void:
	_loot_total += value
	_loot_events += 1


func _on_extraction(inside: bool) -> void:
	_extraction_events.append(inside)


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("PASS: " + description)
	else:
		_failures += 1
		push_error("FAIL: " + description)
