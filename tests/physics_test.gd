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
	await _movement_checks()
	print("PHYSICS TESTS ", "PASSED" if failures == 0 else "FAILED", " failures=", failures)
	quit(0 if failures == 0 else 1)


## Player v2 feel checks. Each one builds its own small world with real bodies.
func _movement_checks() -> void:
	await _touchdown_checks()
	await _jump_checks()
	await _air_control_checks()
	await _ramp_checks()
	await _camera_checks()
	await _health_checks()


func _new_world() -> Node3D:
	var world := Node3D.new()
	root.add_child(world)
	return world


## A floor whose top surface is at y = 0, like the level ground.
func _add_floor(world: Node3D) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 2, 200)
	shape.shape = box
	body.position.y = -1.0
	body.add_child(shape)
	world.add_child(body)


## A player with the game's real physics setup (mass, capsule, damping) at a given spot.
func _spawn(world: Node3D, at: Vector3, gravity: float) -> RigidBody3D:
	var body: RigidBody3D = Player.new()
	world.add_child(body)
	body.global_position = at
	body.gravity_scale = gravity
	body.active = true
	return body


func _touchdown_checks() -> void:
	var world := _new_world()
	_add_floor(world)
	var faller := _spawn(world, Vector3(0, 3.0, 0), 1.0)
	var impacts: Array = []
	faller.landed.connect(func(speed: float) -> void: impacts.append(speed))
	# physics_frame can fire just before a tick is simulated, so the count may lag by one step.
	var step: float = 1.0 / float(Engine.physics_ticks_per_second)
	var air_frames := 0
	var worst_error := 0.0
	var zero_when_grounded := true
	var peak_air := 0.0
	for i in range(120):
		await physics_frame
		if faller.grounded:
			air_frames = 0
			zero_when_grounded = zero_when_grounded and faller.airborne_time == 0.0
		else:
			air_frames += 1
			worst_error = maxf(worst_error, absf(faller.airborne_time - float(air_frames) * step))
			peak_air = maxf(peak_air, faller.airborne_time)
	_check(impacts.size() >= 1, "landed fires on touchdown")
	_check(impacts.size() > 0 and float(impacts[0]) > 5.0 and float(impacts[0]) < 8.0, "landed reports the downward impact speed")
	_check(worst_error <= step + 0.0005 and peak_air > 0.2, "airborne_time measures time since leaving the ground")
	_check(zero_when_grounded and faller.grounded and faller.airborne_time == 0.0, "airborne_time is zero once grounded")
	world.queue_free()
	await process_frame


## Coyote time, the jump buffer and the jump signal, all on the real floor.
func _jump_checks() -> void:
	var world := _new_world()
	_add_floor(world)
	# Coyote: leave the ground by hand, then press jump while still inside the window.
	var hopper := _spawn(world, Vector3(0, 1.0, 0), 1.0)
	var hops: Array = []
	hopper.jumped.connect(func() -> void: hops.append(true))
	await _frames(30)
	hopper.linear_velocity = Vector3(0, 1.5, 0)
	var waited := 0
	while hopper.grounded and waited < 20:
		await physics_frame
		waited += 1
	var air_at_press: float = hopper.airborne_time
	_check(not hopper.grounded and air_at_press > 0.0 and air_at_press < Player.COYOTE_TIME, "coyote test presses jump just after leaving the ground")
	hopper.request_jump()
	await _frames(4)
	_check(hops.size() == 1 and hopper.linear_velocity.y > 4.0, "coyote jump still launches the player")
	# Too late: a press after the coyote window waits in the buffer and expires before landing.
	var late := _spawn(world, Vector3(10, 1.0, 0), 1.0)
	var late_hops: Array = []
	late.jumped.connect(func() -> void: late_hops.append(true))
	await _frames(30)
	late.linear_velocity = Vector3(0, 4.0, 0)
	waited = 0
	while late.airborne_time < 0.3 and waited < 60:
		await physics_frame
		waited += 1
	late.request_jump()
	waited = 0
	while not late.grounded and waited < 200:
		await physics_frame
		waited += 1
	await _frames(3)
	_check(late_hops.is_empty(), "a jump pressed after the coyote window does not fire")
	# Buffer: a press just before touchdown fires on landing.
	var buffered := _spawn(world, Vector3(20, 1.0, 0), 1.0)
	var buffered_hops: Array = []
	buffered.jumped.connect(func() -> void: buffered_hops.append(true))
	await _frames(30)
	buffered.linear_velocity = Vector3(0, 4.0, 0)
	waited = 0
	while buffered.airborne_time < 0.7 and waited < 100:
		await physics_frame
		waited += 1
	buffered.request_jump()
	waited = 0
	while buffered_hops.is_empty() and waited < 200:
		await physics_frame
		waited += 1
	_check(buffered_hops.size() == 1, "a jump pressed just before touchdown fires on landing")
	world.queue_free()
	await process_frame


## Air control adds at most 3 m/s^2 and stops adding speed at 6 m/s.
func _air_control_checks() -> void:
	var world := _new_world()
	var flyer := _spawn(world, Vector3(0, 30, 0), 0.0)
	flyer.linear_damp = 0.0
	flyer.move_input = Vector2(0, -1)
	await _frames(45)
	var forward: float = -flyer.linear_velocity.z
	_check(forward > 1.3 and forward < 1.6, "air control adds at most 3 m/s^2 (0.5 s gives about 1.5 m/s)")
	await _frames(270)
	forward = -flyer.linear_velocity.z
	_check(forward > 5.8 and forward < 6.1, "air control stops adding speed near 6 m/s")
	world.queue_free()
	await process_frame


## Idle on a 35 degree ramp: no sliding. A 50 degree ramp is the control that really slides.
func _ramp_checks() -> void:
	var shallow: Dictionary = await _ramp_drift(35.0)
	_check(bool(shallow["grounded"]) and float(shallow["drift"]) < 0.05, "idle player does not slide on a 35 degree ramp")
	var steep: Dictionary = await _ramp_drift(50.0)
	_check(float(steep["drift"]) > 0.3, "control: an idle player still slides on a 50 degree ramp")


## Drops an idle player onto a tilted box and reports how far it drifted once it had settled.
func _ramp_drift(degrees: float) -> Dictionary:
	var world := _new_world()
	var ramp := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(12, 1, 30)
	shape.shape = box
	ramp.add_child(shape)
	ramp.position = Vector3(0, 5, 0)
	ramp.rotation.x = deg_to_rad(degrees)
	world.add_child(ramp)
	var normal: Vector3 = ramp.transform.basis.y
	var body := _spawn(world, ramp.position + normal * 1.5, 1.0)
	await _frames(90)
	var start: Vector3 = body.global_position
	await _frames(120)
	var result := {"drift": (body.global_position - start).length(), "grounded": body.grounded}
	world.queue_free()
	await process_frame
	return result


## FOV widening, lens shake on/off, and that shake never moves the aim.
func _camera_checks() -> void:
	var world := _new_world()
	var racer := _spawn(world, Vector3(0, 30, 0), 0.0)
	racer.linear_damp = 0.0
	racer.apply_settings({"fov": 70.0, "camera_shake": 1.0})
	_check(is_equal_approx(racer.camera.fov, 70.0), "apply_settings sets the base FOV")
	racer.linear_velocity = Vector3(0, 0, -40)
	await _frames(150)
	var widened: float = racer.camera.fov
	_check(widened > 81.0 and widened <= 82.0001, "FOV widens by up to 12 degrees at 40 m/s")
	racer.linear_velocity = Vector3.ZERO
	var aim_before: Basis = racer.camera.global_basis
	racer.apply_settings({"camera_shake": 0.0})
	racer.add_shake(1.0)
	var worst := 0.0
	for i in range(10):
		await process_frame
		worst = maxf(worst, absf(racer.camera.h_offset))
	_check(worst == 0.0, "camera_shake 0 disables the shake")
	racer.apply_settings({"camera_shake": 1.0})
	racer.add_shake(0.6)
	worst = 0.0
	var aim_drift := 0.0
	for i in range(10):
		await process_frame
		worst = maxf(worst, absf(racer.camera.h_offset))
		aim_drift = maxf(aim_drift, (racer.camera.global_basis.get_rotation_quaternion().angle_to(aim_before.get_rotation_quaternion())))
	_check(worst > 0.001, "add_shake moves the lens")
	_check(aim_drift < 0.0001, "shake offsets the lens without changing the aim")
	world.queue_free()
	await process_frame


## Loadout max health, the damage source passing through, heal capping and the death source.
func _health_checks() -> void:
	var world := _new_world()
	var dummy := _spawn(world, Vector3(0, 30, 0), 0.0)
	dummy.configure({"max_health": 140.0})
	_check(is_equal_approx(dummy.max_health, 140.0) and is_equal_approx(dummy.health, 140.0), "configure sets max health and refills health")
	var hits: Array = []
	dummy.damaged.connect(func(amount: float, source: String, from_pos: Vector3) -> void: hits.append([amount, source, from_pos]))
	dummy.take_damage(40.0, "test_source", Vector3(1, 2, 3))
	_check(hits.size() == 1 and hits[0][1] == "test_source" and (hits[0][2] as Vector3).is_equal_approx(Vector3(1, 2, 3)), "take_damage passes its source through to damaged")
	_check(is_equal_approx(dummy.health, 100.0), "damage reduces health by the amount taken")
	dummy.heal(100.0)
	_check(is_equal_approx(dummy.health, 140.0), "heal caps at max health")
	var deaths: Array = []
	dummy.died.connect(func(source: String) -> void: deaths.append(source))
	dummy.take_damage(1000.0, "pit")
	_check(deaths == ["pit"], "died carries the killing source")
	world.queue_free()
	await process_frame
