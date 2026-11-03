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
	# A reel within 2.2 m of the rod tip recovers the weight (tether v2), so this reel takes it back.
	_check(not is_instance_valid(tether.weight) and tether.tension == 0.0, "reeling a weight in next to the rod recovers it")
	tether.reeling = false
	# The cut checks need a weight still on the line, so cast a fresh one.
	tether._cast(0.7)
	await _frames(4)
	var cast_weight: RigidBody3D = tether.weight
	var player_before: Vector3 = player.linear_velocity
	var weight_before: Vector3 = cast_weight.linear_velocity
	tether.cut()
	_check(player.linear_velocity.is_equal_approx(player_before) and cast_weight.linear_velocity.is_equal_approx(weight_before), "cut preserves both body velocities")
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
	await _tether_v2_checks()
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


## A stub with a take_damage counter, used as the enemy for smash checks.
const DUMMY_SOURCE := "extends StaticBody3D\nvar hits: int = 0\nvar last_amount: float = 0.0\nfunc take_damage(amount: float, _source: String = \"bullet\") -> void:\n\thits += 1\n\tlast_amount = amount\n"


## Tether v2 checks: stats, auto-cut, analog reel, recover, anchors, spool limit, smash and impacts.
## Each check builds its own world with real bodies. Gravity is off and cast assist is zero.
func _tether_v2_checks() -> void:
	await _tether_configure_check()
	await _tether_auto_cut_check()
	await _tether_reel_strength_check()
	await _tether_recover_check()
	await _tether_anchor_check()
	await _tether_spool_limit_check()
	await _tether_smash_check()
	await _tether_impact_check()
	await _tether_wrap_checks()


## A player and a tether in one world. Returns {"player", "tether"} as untyped values for the checks.
func _tether_rig(world: Node3D, at: Vector3) -> Dictionary:
	var body := _spawn(world, at, 0.0)
	body.linear_damp = 0.0
	body.pitch = 0.0
	body.apply_look(Vector2.ZERO)
	var line := Tether.new()
	world.add_child(line)
	line.bind(body)
	line.active = true
	line.assist_strength = 0.0
	return {"player": body, "tether": line}


## A static box with collision on the given layer, optionally in a group.
func _add_box(world: Node3D, at: Vector3, size: Vector3, layer: int, group: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.collision_layer = layer
	body.position = at
	if not group.is_empty():
		body.add_to_group(group)
	world.add_child(body)
	return body


func _dummy_script() -> GDScript:
	var script := GDScript.new()
	script.source_code = DUMMY_SOURCE
	script.reload()
	return script


## Puts the weight at a spot with a velocity along -z, for contact checks that need a fast hit.
func _fling(line, at: Vector3, speed: float) -> void:
	line.weight.global_position = at
	line.weight.linear_velocity = Vector3(0, 0, -speed)
	line.weight.angular_velocity = Vector3.ZERO


func _tether_configure_check() -> void:
	var world := _new_world()
	var rig := _tether_rig(world, Vector3(0, 20, 0))
	var line = rig["tether"]
	line.configure({"max_line": 30.0, "reel_force": 15000.0, "reel_speed": 7.0, "weight_mass": 160.0, "assist_strength": 16000.0, "charge_time": 0.5})
	_check(is_equal_approx(line.max_line, 30.0) and is_equal_approx(line.reel_force, 15000.0) and is_equal_approx(line.reel_speed, 7.0), "configure applies the spool and reel stats")
	_check(is_equal_approx(line.weight_mass, 160.0) and is_equal_approx(line.assist_strength, 16000.0) and is_equal_approx(line.charge_time, 0.5), "configure applies the weight, assist and charge stats")
	line.configure({"reel_force": 99999.0})
	_check(is_equal_approx(line.reel_force, Tether.MAX_TENSION), "reel force is capped at the line's maximum tension")
	world.queue_free()
	await process_frame


func _tether_auto_cut_check() -> void:
	var world := _new_world()
	var rig := _tether_rig(world, Vector3(0, 20, 0))
	var line = rig["tether"]
	var events: Array = []
	line.event_happened.connect(func(event: String) -> void: events.append(event))
	line._cast(0.5)
	await _frames(20)
	# The cast cooldown is 0.18 s, so 20 frames is enough for a second CAST.
	line.auto_cut = false
	line.begin_charge()
	_check(events.has("cut_first") and is_instance_valid(line.weight) and not line.charging, "cut_first: CAST with a weight out only asks for a cut")
	line.auto_cut = true
	line.begin_charge()
	_check(events.has("auto_cut") and events.has("cut") and not is_instance_valid(line.weight) and line.charging, "auto_cut: CAST drops the weight and starts the next charge")
	line.charging = false
	world.queue_free()
	await process_frame


## Reeling at half strength takes in line at about half the rate over the same time.
func _tether_reel_strength_check() -> void:
	var world := _new_world()
	var rig := _tether_rig(world, Vector3(0, 20, 0))
	var line = rig["tether"]
	var player_body = rig["player"]
	line.configure({"max_line": 60.0})
	var drops: Array = []
	for strength: float in [1.0, 0.5]:
		line._cast(0.5)
		await _frames(5)
		# Park the weight 6 m out, beyond the recover radius, with no velocity of its own.
		line.weight.global_position = player_body.global_position + Vector3(0, 0, -6.0)
		line.weight.linear_velocity = Vector3.ZERO
		# Keep the line slack so the reel is not loaded: only the reel speed decides the rate.
		line.line_length = 18.0
		line.reel_strength = strength
		line.reeling = true
		var before: float = line.line_length
		await _frames(45)
		line.reeling = false
		drops.append(before - line.line_length)
		line.cut()
	_check(float(drops[0]) > 4.0, "full reel shortens a slack line at the reel speed")
	_check(absf(float(drops[1]) / float(drops[0]) - 0.5) < 0.05, "reel_strength 0.5 reels at about half speed")
	world.queue_free()
	await process_frame


## A free weight reeled in within 2.2 m of the rod tip is recovered, but not before.
func _tether_recover_check() -> void:
	var world := _new_world()
	var rig := _tether_rig(world, Vector3(0, 20, 0))
	var line = rig["tether"]
	var player_body = rig["player"]
	var events: Array = []
	line.event_happened.connect(func(event: String) -> void: events.append(event))
	line._cast(0.0)
	await _frames(2)
	# Park the weight 4 m out, about 2.35 m from the rod tip, which is outside the recover radius.
	line.weight.gravity_scale = 0.0
	line.weight.global_position = player_body.global_position + Vector3(0, 0, -4.0)
	line.weight.linear_velocity = Vector3.ZERO
	line.line_length = 5.0
	line.reeling = true
	await _frames(1)
	_check(not events.has("recover") and is_instance_valid(line.weight), "a weight outside 2.2 m of the rod tip is not recovered")
	var waited := 0
	while is_instance_valid(line.weight) and waited < 300:
		await physics_frame
		waited += 1
	_check(events.has("recover") and not is_instance_valid(line.weight), "reeling the weight within 2.2 m of the rod tip recovers it")
	world.queue_free()
	await process_frame


## Touching an anchor latches the weight. A latched weight is reeled from, not recovered.
func _tether_anchor_check() -> void:
	var world := _new_world()
	_add_box(world, Vector3(0, 20, -6.0), Vector3(3, 3, 0.5), 1, "anchor")
	var rig := _tether_rig(world, Vector3(0, 20, 0))
	var line = rig["tether"]
	var player_body = rig["player"]
	var events: Array = []
	line.event_happened.connect(func(event: String) -> void: events.append(event))
	line._cast(0.0)
	await _frames(3)
	line.weight.gravity_scale = 0.0
	line.weight.global_position = Vector3(0, 20, -3.0)
	line.weight.linear_velocity = Vector3(0, 0, -8.0)
	line.line_length = 30.0
	var waited := 0
	while not line.anchored and waited < 90:
		await physics_frame
		waited += 1
	_check(line.anchored and events.has("anchor") and line.weight.freeze, "a weight touching an anchor latches and freezes")
	var start_z: float = player_body.global_position.z
	line.line_length = 8.0
	line.reeling = true
	await _frames(120)
	line.reeling = false
	_check(line.anchored and player_body.global_position.z < start_z - 0.3, "reeling from an anchor pulls the player toward the plate")
	_check(not events.has("recover") and is_instance_valid(line.weight), "an anchored weight is not recovered by reeling")
	world.queue_free()
	await process_frame


## spool_limit fires once, at the moment free spool reaches the line maximum.
func _tether_spool_limit_check() -> void:
	var world := _new_world()
	var rig := _tether_rig(world, Vector3(0, 20, 0))
	var line = rig["tether"]
	line.configure({"max_line": 4.0})
	var events: Array = []
	line.event_happened.connect(func(event: String) -> void: events.append(event))
	line._cast(1.0)
	var waited := 0
	while not events.has("spool_limit") and waited < 120:
		await physics_frame
		waited += 1
	# Read the line straight after the event, before any later overload can cut it.
	_check(events.has("spool_limit") and is_equal_approx(line.line_length, 4.0), "spool_limit fires when the line reaches its maximum")
	await _frames(20)
	_check(events.count("spool_limit") == 1, "spool_limit does not repeat while the line stays at its maximum")
	world.queue_free()
	await process_frame


## A fast weight hit on an enemy deals damage, emits weight_smash, and a second hit inside 0.35 s deals none.
func _tether_smash_check() -> void:
	var world := _new_world()
	var rig := _tether_rig(world, Vector3(0, 20, 0))
	var line = rig["tether"]
	var target := _add_box(world, Vector3(0, 20, -6.0), Vector3(3, 3, 0.5), 8, "enemies")
	target.set_script(_dummy_script())
	var smashes: Array = []
	line.weight_smash.connect(func(_hit: Node, speed: float, damage: float) -> void: smashes.append([speed, damage]))
	line._cast(0.0)
	await _frames(3)
	line.weight.gravity_scale = 0.0
	line.line_length = 40.0
	_fling(line, Vector3(0, 20, -3.0), 14.0)
	var waited := 0
	while int(target.get("hits")) == 0 and waited < 60:
		await physics_frame
		waited += 1
	_check(int(target.get("hits")) == 1 and smashes.size() == 1, "a fast weight hit smashes the enemy once")
	var damage: float = float(target.get("last_amount"))
	_check(damage > 0.0 and damage <= Tether.SMASH_MAX_DAMAGE, "smash damage is positive and capped")
	# Second hit inside the 0.35 s cooldown: the weight reaches the enemy again but deals nothing.
	_fling(line, Vector3(0, 20, -4.8), 14.0)
	await _frames(6)
	_check(int(target.get("hits")) == 1, "a second smash within 0.35 s deals no damage")
	await _frames(40)
	_fling(line, Vector3(0, 20, -4.8), 14.0)
	waited = 0
	while int(target.get("hits")) < 2 and waited < 30:
		await physics_frame
		waited += 1
	_check(int(target.get("hits")) == 2, "smash works again once the cooldown has passed")
	world.queue_free()
	await process_frame


## weight_impact fires on a hard world hit and is throttled while the weight keeps touching.
func _tether_impact_check() -> void:
	var world := _new_world()
	var rig := _tether_rig(world, Vector3(0, 20, 0))
	var line = rig["tether"]
	_add_box(world, Vector3(0, 20, -6.0), Vector3(3, 3, 0.5), 1, "")
	var impacts: Array = []
	line.weight_impact.connect(func(_at: Vector3, speed: float) -> void: impacts.append(speed))
	line._cast(0.0)
	await _frames(3)
	line.weight.gravity_scale = 0.0
	line.line_length = 40.0
	_fling(line, Vector3(0, 20, -3.0), 8.0)
	var waited := 0
	while impacts.is_empty() and waited < 60:
		await physics_frame
		waited += 1
	_check(impacts.size() == 1 and float(impacts[0]) > 4.0, "a hard world hit emits weight_impact")
	# A second hit within the 0.15 s interval is throttled out.
	_fling(line, Vector3(0, 20, -4.9), 8.0)
	await _frames(10)
	_check(impacts.size() == 1, "weight_impact is throttled to one per 0.15 s")
	world.queue_free()
	await process_frame


# --- Wrapping (G3) -------------------------------------------------------------------------------
# The corner scene: a 2 x 4 x 2 box between the player at (0, 20, 0) and a weight at (4, 20, -6).
# The straight line clips the box's near face, so the line must bend around its corner at (2.5, 20, -2).
const WRAP_BOX_CENTER := Vector3(1.5, 20.0, -3.0)
const WRAP_BOX_SIZE := Vector3(2.0, 4.0, 2.0)


func _tether_wrap_checks() -> void:
	await _tether_wrap_corner_check()
	await _tether_wrap_overflow_check()
	await _tether_wrap_rate_check()


## Puts the weight at a spot and stops both bodies, so each wrap check starts from rest.
func _park_weight(line, player_body, at: Vector3) -> void:
	line.weight.gravity_scale = 0.0
	line.weight.global_position = at
	line.weight.linear_velocity = Vector3.ZERO
	player_body.linear_velocity = Vector3.ZERO


## A box corner adds one wrap point at the corner, the wrap holds while the line is blocked, and it is
## removed once the weight is somewhere the player can see directly.
func _tether_wrap_corner_check() -> void:
	var world := _new_world()
	var rig := _tether_rig(world, Vector3(0, 20, 0))
	var line = rig["tether"]
	var player_body = rig["player"]
	_add_box(world, WRAP_BOX_CENTER, WRAP_BOX_SIZE, 1, "")
	line._cast(0.0)
	await _frames(3)
	_park_weight(line, player_body, Vector3(4, 20, -6))
	# Slack line: the total length stays under the deployed length, so no tension is involved here.
	line.line_length = 14.0
	await _frames(2)
	var wraps: PackedVector3Array = line.get_wrap_points()
	_check(wraps.size() == 1, "a box corner between the line and the weight adds one wrap point")
	_check(wraps.size() == 1 and wraps[0].distance_to(Vector3(2.5, 20, -2)) < 0.5, "the wrap point sits at the box corner")
	var finite := true
	for i in range(60):
		await physics_frame
		finite = finite and is_finite(line.tension) and is_finite(line.line_length)
		finite = finite and line.weight.global_position.is_finite() and player_body.global_position.is_finite()
		finite = finite and line.get_wrap_points().size() == 1
	_check(finite, "the wrap holds while the line is blocked, and every value stays finite")
	_park_weight(line, player_body, Vector3(-4, 20, -6))
	await _frames(3)
	_check(line.get_wrap_points().is_empty(), "the wrap point is removed once sight returns")
	world.queue_free()
	await process_frame


## Eight wraps the line still needs, plus a ninth. A thin fence stands between the player and the weight,
## and the injected wraps alternate sides in pairs (++--++--), so every wrap's chord crosses the fence and
## none is dropped as redundant. The ninth need must sever the line.
func _tether_wrap_overflow_check() -> void:
	var world := _new_world()
	var rig := _tether_rig(world, Vector3(0, 20, -0.5))
	var line = rig["tether"]
	var player_body = rig["player"]
	_add_box(world, Vector3(0, 20, 0), Vector3(12, 4, 0.2), 1, "")
	var events: Array = []
	line.event_happened.connect(func(event: String) -> void: events.append(event))
	line._cast(0.0)
	await _frames(3)
	_park_weight(line, player_body, Vector3(2.5, 20, 0.5))
	line.line_length = 40.0
	var sides := [0.2, 0.2, -0.2, -0.2, 0.2, 0.2, -0.2, -0.2]
	for i in range(Tether.MAX_WRAPS):
		line._wraps.append(Vector3(-1.75 + 0.5 * float(i), 20.0, float(sides[i])))
	await _frames(2)
	_check(events.has("severed") and not is_instance_valid(line.weight), "a ninth needed wrap severs the line")
	_check(line.get_wrap_points().is_empty(), "a severed line keeps no wrap points")
	world.queue_free()
	await process_frame


## The same wrapped pull at 60 Hz and 120 Hz moves the player about the same distance in 0.1 s.
func _tether_wrap_rate_check() -> void:
	var slow: Dictionary = await _wrap_pull(60)
	var fast: Dictionary = await _wrap_pull(120)
	var moved_slow: float = slow["moved"]
	var moved_fast: float = fast["moved"]
	_check(bool(slow["finite"]) and bool(fast["finite"]), "a wrapped pull keeps every value finite at 60 and 120 Hz")
	_check(moved_slow > 0.02 and absf(moved_slow - moved_fast) <= 0.2 * maxf(moved_slow, moved_fast), "60 Hz and 120 Hz wrapped pulls agree within 20 percent")
	print("WRAP PULL 60Hz=", moved_slow, " 120Hz=", moved_fast)


## Runs the corner pull at a physics rate and reports how far the player moved and whether values stayed finite.
func _wrap_pull(ticks: int) -> Dictionary:
	var previous: int = Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = ticks
	var world := _new_world()
	var rig := _tether_rig(world, Vector3(0, 20, 0))
	var line = rig["tether"]
	var player_body = rig["player"]
	_add_box(world, WRAP_BOX_CENTER, WRAP_BOX_SIZE, 1, "")
	line._cast(0.0)
	await _frames(3)
	_park_weight(line, player_body, Vector3(4, 20, -6))
	# Locked and a little short of the wrapped length (about 7.5 m), so the wrap carries real tension.
	line.line_length = 7.3
	line.locked = true
	var start: Vector3 = player_body.global_position
	var finite := true
	for i in range(int(0.1 * float(ticks))):
		await physics_frame
		finite = finite and is_finite(line.tension) and is_finite(line.line_length)
		finite = finite and player_body.global_position.is_finite() and line.weight.global_position.is_finite()
	var moved: float = player_body.global_position.distance_to(start)
	Engine.physics_ticks_per_second = previous
	world.queue_free()
	await process_frame
	return {"moved": moved, "finite": finite}
