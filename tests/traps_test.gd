extends SceneTree
## Real-physics checks for the floor-is-lava traps (W2): cracking plates, teacup mines, the flood
## and a boulder, on a bare level with the real player.

const LevelBase = preload("res://scripts/level_base.gd")
const PlayerScript = preload("res://scripts/player.gd")

var _scene: Node3D
var _player: RigidBody3D
var _level: Node3D
var _traps: Node3D
var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_scene = Node3D.new()
	root.add_child(_scene)
	_player = PlayerScript.new()
	_scene.add_child(_player)
	_player.set("active", true)
	_level = LevelBase.new()
	_scene.add_child(_level)
	_level.call("build", _player, true)
	_level.call("set_active", true)
	_floor(Vector3(0.0, -0.5, 0.0), Vector3(40.0, 1.0, 40.0))
	_traps = _level.call("traps")
	await _test_plates()
	await _test_mine()
	await _test_boulder()
	await _test_geyser()
	await _test_mud()
	await _test_flood()
	_scene.queue_free()
	await _frames(3)
	print("TRAPS TEST: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _test_plates() -> void:
	# A 2 x 2 field of 6 m plates over nothing, well away from the floor.
	_traps.call("crack_field", Vector3(60.0, 0.0, 0.0), Vector2(12.0, 12.0), 6.0, "ice")
	await _place(Vector3(57.0, 1.2, -3.0))
	await _seconds(0.4)
	_check(bool(_player.get("grounded")) and _player.global_position.y > 0.5, "the player stands on an intact plate")
	await _seconds(2.2)
	_check(_player.global_position.y < -1.0, "the plate breaks under the player after the crack time and they fall through")
	var fields: Array = _traps.get("_fields")
	var broken: int = 0
	for cell: Dictionary in (fields[0]["cells"] as Dictionary).values():
		if int(cell["state"]) == 2:
			broken += 1
	_check(broken == 1, "only the plate stood on breaks (%d broken)" % broken)


func _test_mine() -> void:
	_player.set("health", 100.0)
	_traps.call("mine", Vector3(0.0, 0.0, 0.0))
	await _place(Vector3(0.0, 0.95, 1.2))
	await _seconds(0.3)
	_check(is_equal_approx(float(_player.get("health")), 100.0), "a mine beeps before it blows: no damage at once")
	var top: float = -INF
	for i in range(60):
		await physics_frame
		top = maxf(top, _player.global_position.y)
	_check(float(_player.get("health")) < 80.0, "the blast hurts the player beside it (health %.0f)" % float(_player.get("health")))
	_check(top > 1.6, "the blast throws the player up (peak %.1f m)" % top)
	var mines: Array = _traps.get("_mines")
	_check(int(mines[0]["state"]) == 2, "a mine blows once")


func _test_boulder() -> void:
	_player.set("health", 100.0)
	await _place(Vector3(0.0, 0.95, 8.0))
	var trigger := AABB(Vector3(-5.0, -2.0, 4.0), Vector3(10.0, 6.0, 10.0))
	_traps.call("boulder", Vector3(0.0, 2.6, -12.0), 2.5, trigger, Vector3(0.0, 0.0, 16.0))
	await _seconds(2.0)
	_check(float(_player.get("health")) < 100.0, "a released boulder that rolls into the player hurts them")


func _test_geyser() -> void:
	_player.set("health", 100.0)
	var period: float = 14.0             # long enough to come down before the next eruption
	# Phase it so the hiss starts in about 0.3 s and the column 1.4 s after that.
	var now: float = float(_traps.get("_clock"))
	var top: Vector3 = _traps.call("geyser", Vector3(12.0, 0.0, -12.0), period, period - 4.1 - fmod(now, period) + period, 24.0)
	await _place(top + Vector3(0.0, 1.0, 0.0))
	await _seconds(0.3)
	_check(bool(_player.get("grounded")), "the player can stand on a geyser's solid mound")
	var hissed: bool = false
	var peak: float = -INF
	var was_up: bool = false
	var landed_at: float = -1.0
	var health_after: float = -1.0
	var tick: float = 1.0 / float(Engine.physics_ticks_per_second)
	for i in range(int(14.0 / tick)):
		await physics_frame
		var states: Array = _traps.call("geyser_states")
		if int(states[0]) == 1 and peak < top.y + 3.0:
			hissed = true
		peak = maxf(peak, _player.global_position.y)
		if _player.global_position.y > top.y + 10.0:
			was_up = true
		if was_up and landed_at < 0.0 and bool(_player.get("grounded")):
			landed_at = float(i) * tick
		if landed_at >= 0.0 and float(i) * tick > landed_at + 0.2:
			health_after = float(_player.get("health"))
			break
	_check(hissed, "a geyser hisses before it erupts")
	_check(peak > top.y + 15.0, "the eruption throws the player high into the air (peak %.1f m above the vent)" % (peak - top.y))
	_check(landed_at > 0.0 and health_after >= 100.0, "a geyser ride lands softly: no fall damage from its own throw (%.0f health)" % health_after)
	_traps.call("set_geyser_tempo", 0.1)
	await _place(Vector3(0.0, 0.95, 0.0))


func _test_mud() -> void:
	_player.set("health", 100.0)
	_traps.call("mud_pool", Vector3(12.0, 0.04, 12.0), 4.0)
	_check(bool(_level.call("is_hazard_at", Vector3(12.0, 0.5, 12.0))), "boiling mud counts as a hazard (no safe-ground respawn in it)")
	await _place(Vector3(12.0, 0.95, 12.0))
	await _seconds(1.0)
	var health: float = float(_player.get("health"))
	_check(health < 80.0 and health > 40.0, "wading in boiling mud hurts steadily (%.0f health after 1 s)" % health)
	await _place(Vector3(0.0, 0.95, 0.0))


func _test_flood() -> void:
	_player.set("health", 100.0)
	await _place(Vector3(-10.0, 0.95, -10.0))
	_traps.call("flood", Rect2(-30.0, -30.0, 60.0, 60.0), -1.0, 4.0, 10.0)
	_check(is_inf(float(_traps.call("flood_level"))), "the flood waits until it is started")
	_traps.call("start_flood")
	await _seconds(1.0)
	_check(is_equal_approx(float(_traps.call("flood_level")), 4.0), "the flood rises to its end height and stops")
	_check(float(_player.get("health")) < 100.0, "the player under the flood takes damage")


func _place(at: Vector3) -> void:
	_player.call("reset_at", at)
	await _frames(3)


func _floor(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	body.position = center
	_scene.add_child(body)


func _seconds(value: float) -> void:
	await create_timer(value, true, true).timeout


func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: " + message)
