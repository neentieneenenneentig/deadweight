extends SceneTree
## Run with Godot --headless --fixed-fps 90 --path . --script res://tests/physics_test.gd

const Player = preload("res://scripts/player.gd")
const Tether = preload("res://scripts/tether.gd")
var failures: int = 0
var arena: Node3D
var player: RigidBody3D
var tether: Node3D

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		push_error("FAIL " + message)
		failures += 1

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func _run() -> void:
	arena = Node3D.new()
	root.add_child(arena)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(500, 2, 500)
	shape.shape = box
	floor_body.position.y = -1.0
	floor_body.add_child(shape)
	arena.add_child(floor_body)
	player = Player.new()
	arena.add_child(player)
	player.global_position = Vector3(0, 20, 0)
	player.gravity_scale = 0.0
	player.linear_damp = 0.0
	player.active = true
	player.pitch = 0.0
	player.apply_look(Vector2.ZERO)
	tether = Tether.new()
	arena.add_child(tether)
	tether.bind(player)
	tether.active = true
	tether.assist_strength = 0.0
	await _frames(3)
	_check(Tether.rope_force(4.0, 5.0, 20.0) == 0.0, "slack line exerts no force even while separating")
	_check(Tether.rope_force(7.0, 5.0, -50.0) == 0.0, "rope cannot push when endpoints approach")
	_check(Tether.rope_force(7.0, 5.0, 100.0) <= Tether.MAX_TENSION, "catch force has a finite cap")
	tether._cast(0.7)
	var weight: RigidBody3D = tether.weight
	weight.gravity_scale = 0.0
	weight.linear_damp = 0.0
	await _frames(4)
	var total: Vector3 = player.linear_velocity * player.mass + weight.linear_velocity * weight.mass
	_check(total.length() < 0.8, "airborne casting conserves combined momentum without assist")
	_check(player.linear_velocity.z > 0.0 and weight.linear_velocity.z < 0.0, "casting applies opposite recoil")
	var old_deployed: float = tether.line_length
	await _frames(8)
	_check(tether.line_length > old_deployed and tether.tension == 0.0, "free spool pays out without artificial pull")
	tether.toggle_lock()
	var lock_length: float = tether.line_length
	await _frames(25)
	_check(is_equal_approx(tether.line_length, lock_length), "locking holds deployed line length")
	total = player.linear_velocity * player.mass + weight.linear_velocity * weight.mass
	_check(total.length() < 1.0, "tension transfers equal opposite momentum")
	tether.reeling = true
	await _frames(15)
	_check(tether.line_length < lock_length, "active reeling shortens line")
	var player_before: Vector3 = player.linear_velocity
	var weight_before: Vector3 = weight.linear_velocity
	tether.cut()
	_check(player.linear_velocity.is_equal_approx(player_before) and weight.linear_velocity.is_equal_approx(weight_before), "cut preserves both body velocities")
	_check(not is_instance_valid(tether.weight) and tether.tension == 0.0, "cut removes the active connection")
	tether.clear()
	player.gravity_scale = 1.0
	player.linear_damp = 0.035
	player.reset_at(Vector3(0, 0.95, 0))
	await _frames(25)
	_check(player.grounded, "rigid player settles on ground")
	player.pitch = 0.6
	player.apply_look(Vector2.ZERO)
	tether.assist_strength = 14500.0
	tether._cast(1.0)
	await _frames(18)
	tether.toggle_lock()
	var max_height: float = player.global_position.y
	var max_speed: float = 0.0
	for i in range(130):
		await physics_frame
		max_height = maxf(max_height, player.global_position.y)
		max_speed = maxf(max_speed, player.linear_velocity.length())
	_check(max_height > 3.0, "assisted cast plus lock lifts the grounded runner")
	_check(max_speed > 8.0 and max_speed < 70.0, "cast provides useful, bounded travel speed")
	_check(player.global_position.is_finite() and player.linear_velocity.is_finite(), "high-load catch remains numerically finite")
	print("FLIGHT max_height=", max_height, " max_speed=", max_speed)
	tether.clear()
	arena.queue_free()
	await process_frame
	print("PHYSICS TESTS ", "PASSED" if failures == 0 else "FAILED", " failures=", failures)
	quit(0 if failures == 0 else 1)
