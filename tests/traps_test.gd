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
	await _test_turned_plates()
	await _test_wave()
	await _test_mine()
	await _test_boulder()
	await _test_marble_run()
	await _test_geyser()
	await _test_mud()
	await _test_flood()
	await _test_starfall()
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


func _test_turned_plates() -> void:
	# A strip of 3 m slabs turned 45 degrees. 4.5 m along its turned axis lies outside the same
	# strip unturned (1.5 m half-width), so standing there proves the turn.
	_traps.call("crack_field", Vector3(60.0, 0.0, 40.0), Vector2(3.0, 12.0), 3.0, "paving", Callable(), 45.0)
	var along: Vector3 = Basis(Vector3.UP, deg_to_rad(45.0)) * Vector3(0.0, 0.0, 4.5)
	await _place(Vector3(60.0, 1.2, 40.0) + along)
	await _seconds(0.4)
	_check(bool(_player.get("grounded")) and _player.global_position.y > 0.3, "a turned field holds the player on its turned slab")
	await _seconds(2.2)
	_check(_player.global_position.y < -1.0, "and that slab cracks and gives way like any other")


func _test_wave() -> void:
	await _place(Vector3(0.0, 1.2, 0.0))
	var index: int = _traps.call("crack_field", Vector3(-60.0, 0.0, 40.0), Vector2(3.0, 15.0), 3.0, "paving")
	var cells: Array = ((_traps.get("_fields") as Array)[index]["cells"] as Dictionary).values()
	# Slab centres sit 1.5, 4.5, ... 13.5 m from the origin: due at 0.25 s to 2.25 s at 6 m/s.
	_traps.call("crack_wave", [index], Vector3(-60.0, 0.0, 32.5), 6.0, 0.0)
	await _seconds(1.9)
	var first: Dictionary = cells[0]
	var last: Dictionary = cells[cells.size() - 1]
	_check(int(first["state"]) == 2 and int(last["state"]) == 0, "a collapse wave breaks the near slab first and has not reached the far one yet")
	await _seconds(2.6)
	var broken: int = 0
	for cell: Dictionary in cells:
		if int(cell["state"]) == 2:
			broken += 1
	_check(broken == cells.size(), "then it runs on until every slab in the field is down (%d of %d)" % [broken, cells.size()])


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


func _test_marble_run() -> void:
	# A hopper of two marbles on a shelf, letting one go every 1.5 s down onto the floor, rolling +x.
	await _place(Vector3(-15.0, 0.95, 15.0))
	var slots: Array[Vector3] = [Vector3(-14.0, 2.0, -15.0), Vector3(-10.0, 2.0, -15.0)]
	var index: int = _traps.call("marble_run", slots, Vector3(-12.0, 2.0, -10.0), 1.5, 1.5, Vector3(6.0, 0.0, 0.0), 0.0, 2.1)
	var states: Array = _traps.call("run_states", index)
	_check(states == [0, 0], "a marble run's marbles wait in their slots")
	await _seconds(1.0)
	_check(_traps.call("run_states", index) == [0, 0], "nothing leaves before the first period")
	await _seconds(1.3)
	var runs: Array = _traps.get("_runs")
	var first: RigidBody3D = runs[index]["marbles"][0]["body"]
	_check(int(_traps.call("run_states", index)[0]) == 1 and first.global_position.x > -12.0, "the first marble is carried to the gate and rolls off with its push (x %.1f)" % first.global_position.x)
	await _seconds(1.5)
	_check(_traps.call("run_states", index) == [1, 1], "the next marble follows one period later")
	# Each rolls for its lifetime (2.1 s here), then goes home.
	var home: bool = false
	for i in range(int(1.6 * float(Engine.physics_ticks_per_second))):
		await physics_frame
		if int(_traps.call("run_states", index)[0]) == 0 and first.global_position.is_equal_approx(slots[0]):
			home = true
	_check(home, "a run marble goes back to its slot after its lifetime")
	_traps.call("set_run_tempo", 3.0)
	var period: float = float(runs[index]["period"]) / float(_traps.get("_run_tempo"))
	_check(is_equal_approx(period, 0.5), "a jammed hopper releases tempo times as often")
	_traps.call("set_run_tempo", 0.1)
	for record: Dictionary in (runs[index]["marbles"] as Array):
		var body: RigidBody3D = record["body"]
		body.freeze = true
		body.global_position = Vector3(-40.0, -20.0, -40.0)
		record["state"] = 2


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


func _test_starfall() -> void:
	# Out on a wide floor of its own, away from the flood of the test before.
	_floor(Vector3(0.0, -3.5, 0.0), Vector3(420.0, 1.0, 420.0))
	var ground := Vector3(-80.0, -3.0, -80.0)
	await _place(ground + Vector3.UP * 0.95)
	_player.set("health", 100.0)
	_check(bool(_traps.call("strike_star", ground)), "a star can be called down on a point")
	_check(bool(_traps.call("strike_star", ground + Vector3(16.0, 0.0, 0.0))), "and another, far from the player")
	await _seconds(0.5)
	_check(is_equal_approx(float(_player.get("health")), 100.0) and (_traps.call("live_strikes") as Array).size() == 2, "the rings show first: no damage before the strike")
	await _seconds(1.5)
	var hurt: float = 100.0 - float(_player.get("health"))
	_check(hurt > 30.0 and hurt < 60.0, "a star landing at the player's feet hurts, but one alone does not kill (%.0f damage)" % hurt)
	_check((_traps.call("live_strikes") as Array).is_empty(), "both strikes land and clear")
	# Idle stars land far off; hunting stars land near the player.
	_traps.call("starfall", Rect2(-200.0, -200.0, 400.0, 400.0), 0.3, 0.3, 11)
	await _place(ground + Vector3.UP * 0.95)
	await _seconds(0.5)
	var far_reach: float = ((_traps.get_script() as GDScript).get_script_constant_map()["STAR_FAR"] as Vector2).x - 0.5
	var far: bool = true
	for target: Vector3 in _traps.call("live_strikes"):
		far = far and Vector2(target.x - ground.x, target.z - ground.z).length() >= far_reach
	_check(far and not (_traps.call("live_strikes") as Array).is_empty(), "idle stars land far from the player")
	await _seconds(1.8)
	_traps.call("hunt_starfall", 0.3)
	await _seconds(0.4)
	var near: bool = false
	for target: Vector3 in _traps.call("live_strikes"):
		near = near or Vector2(target.x - ground.x, target.z - ground.z).length() < 6.0
	_check(near, "once hunting, the stars land on the player")
	_traps.set("_starfall", {})
	await _seconds(1.8)


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
