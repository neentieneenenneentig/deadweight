extends Node3D
## Raid lifecycle and input routing. Simulation always uses a fixed physics tick.

const PlayerScript = preload("res://scripts/player.gd")
const TetherScript = preload("res://scripts/tether.gd")
const WorldScript = preload("res://scripts/world.gd")
const HudScript = preload("res://scripts/hud.gd")
const SoundScript = preload("res://scripts/audio.gd")
const MAGAZINE: int = 12
const EXTRACTION_SECONDS: float = 6.0

var player: RigidBody3D
var tether: Node3D
var world: Node3D
var hud: CanvasLayer
var sound: Node
var mode: String = "menu"
var practice: bool = false
var loot: int = 0
var bank: int = 0
var elapsed: float = 0.0
var extraction_time: float = 0.0
var extraction_inside: bool = false
var weapon: String = "ROD"
var ammo: int = MAGAZINE
var reserve: int = 48
var _reload_time: float = 0.0
var _fire_cooldown: float = 0.0
var _hint: String = ""
var _hint_time: float = 0.0
var _hitmarker: float = 0.0
var _danger: float = 0.0
var _initial_run: bool = true
var _capture: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_inputs()
	_load_profile()
	player = PlayerScript.new()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	player.damaged.connect(_on_damage)
	player.died.connect(func() -> void: _finish(false))
	tether = TetherScript.new()
	tether.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(tether)
	tether.bind(player)
	tether.event_happened.connect(_on_tether_event)
	sound = SoundScript.new()
	sound.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(sound)
	hud = HudScript.new()
	add_child(hud)
	hud.action_requested.connect(_action)
	hud.look_requested.connect(func(delta: Vector2) -> void:
		if mode == "playing":
			player.apply_look(delta * 1.4))
	hud.start_requested.connect(_start_run)
	hud.restart_requested.connect(func() -> void: _start_run(practice))
	hud.resume_requested.connect(_resume)
	if "--touch" in OS.get_cmdline_user_args():
		Input.emulate_touch_from_mouse = true
	_build_world(false)
	player.freeze = true
	player.global_position = world.spawn_position
	player.pitch = -0.04
	player.apply_look(Vector2.ZERO)
	hud.show_menu(bank)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--practice" in args:
		_start_run(true)
	elif "--raid" in args:
		_start_run(false)
	if "--capture" in args:
		_capture = true
		_capture_frame.call_deferred()

func _build_world(safe: bool) -> void:
	if is_instance_valid(world):
		world.set_active(false)
		remove_child(world)
		world.queue_free()
	world = WorldScript.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	world.loot_collected.connect(_on_loot)
	world.extraction_changed.connect(func(inside: bool) -> void:
		extraction_inside = inside
		if not inside:
			extraction_time = 0.0)
	if world.has_signal("threat_changed"):
		world.threat_changed.connect(func(message: String) -> void:
			if mode == "playing":
				set_hint(message, 2.5))
	world.build(player, safe)
	world.set_active(false)

func _start_run(safe: bool) -> void:
	get_tree().paused = false
	practice = safe
	mode = "loading"
	tether.clear()
	_build_world(safe)
	loot = 0
	elapsed = 0.0
	extraction_time = 0.0
	extraction_inside = false
	weapon = "ROD"
	ammo = MAGAZINE
	reserve = 48
	_reload_time = 0.0
	_fire_cooldown = 0.0
	_hitmarker = 0.0
	_danger = 0.0
	player.freeze = false
	player.reset_at(world.spawn_position)
	player.active = true
	tether.active = true
	world.set_active(true)
	mode = "playing"
	hud.show_game()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if hud.touch_enabled else Input.MOUSE_MODE_CAPTURED
	set_hint("AIM ABOVE THE HORIZON  /  charge CAST, release, then LOCK to ride the weight", 8.0)
	_initial_run = false

func _process(delta: float) -> void:
	if not is_instance_valid(hud):
		return
	if mode == "playing":
		_hint_time = maxf(0.0, _hint_time - delta)
		_hitmarker = maxf(0.0, _hitmarker - delta * 5.0)
		_danger = maxf(0.0, _danger - delta * 0.9)
		player.set_feedback(tether.charge, tether.tension, weapon)
		sound.motion(player.linear_velocity.length(), tether.tension, tether.reeling, true)
		var default_hint: String = "SALVAGE %d / %d  /  follow the cyan case beacons" % [loot, world.total_loot]
		if loot >= world.total_loot:
			default_hint = "ALL CASES SECURED  /  reach the amber extraction gate"
		if extraction_inside:
			default_hint = "HOLD POSITION  /  extraction in %.1fs" % maxf(0.0, EXTRACTION_SECONDS - extraction_time) if loot >= world.total_loot else "EXTRACTION LOCKED  /  recover all 3 cases"
		hud.update_state({
			"health": player.health, "speed": player.linear_velocity.length(),
			"tension": tether.tension, "line_length": tether.line_length,
			"reel_state": tether.state_name(), "charge": tether.charge,
			"loot": loot, "total_loot": world.total_loot,
			"extraction": extraction_time / EXTRACTION_SECONDS,
			"extraction_inside": extraction_inside, "time": elapsed,
			"weapon": weapon, "ammo": ammo, "reserve": reserve,
			"reloading": _reload_time > 0.0,
			"hint": _hint if _hint_time > 0.0 else default_hint,
			"hitmarker": _hitmarker, "danger": _danger, "practice": practice
		})

func _physics_process(delta: float) -> void:
	if mode != "playing":
		return
	elapsed += delta
	var keyboard: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	player.move_input = (keyboard + hud.move_vector).limit_length(1.0)
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	if _reload_time > 0.0:
		_reload_time -= delta
		if _reload_time <= 0.0:
			var loaded: int = mini(MAGAZINE - ammo, reserve)
			ammo += loaded
			reserve -= loaded
	if extraction_inside and loot >= world.total_loot:
		extraction_time += delta
		if extraction_time >= EXTRACTION_SECONDS:
			_finish(true)
			return
	else:
		extraction_time = 0.0
	if player.global_position.y < -18.0:
		if practice:
			tether.clear()
			player.reset_at(world.spawn_position)
			set_hint("PRACTICE RESET  /  cast upward before locking", 5.0)
		else:
			player.take_damage(100.0)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if mode == "playing":
			_pause()
		elif mode == "paused":
			_resume()
		get_viewport().set_input_as_handled()
		return
	if mode != "playing":
		return
	if event is InputEventMouseMotion and not hud.touch_enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.apply_look(event.relative)
	if hud.touch_enabled and (event is InputEventMouseMotion or event is InputEventMouseButton):
		return
	for action in ["cast", "lock", "reel", "cut", "weapon", "reload", "jump"]:
		if event.is_action_pressed(action) and not event.is_echo():
			_action(action, true)
		elif event.is_action_released(action):
			_action(action, false)

func _action(action: String, pressed: bool) -> void:
	if action == "pause" and pressed:
		if mode == "playing":
			_pause()
		elif mode == "paused":
			_resume()
		return
	if mode != "playing":
		return
	match action:
		"cast":
			if weapon == "SIDEARM":
				if pressed:
					_fire()
			elif pressed:
				tether.begin_charge()
			else:
				tether.release_cast()
		"lock":
			if pressed:
				tether.toggle_lock()
		"reel":
			tether.reeling = pressed and is_instance_valid(tether.weight)
		"cut":
			if pressed:
				tether.cut()
		"weapon":
			if pressed:
				tether.charging = false
				tether.charge = 0.0
				weapon = "SIDEARM" if weapon == "ROD" else "ROD"
		"reload":
			if pressed and ammo < MAGAZINE and reserve > 0 and _reload_time <= 0.0:
				_reload_time = 1.5
				sound.play("reload")
		"jump":
			if pressed:
				player.request_jump()

func _fire() -> void:
	if _fire_cooldown > 0.0 or _reload_time > 0.0:
		return
	if ammo <= 0:
		sound.play("empty")
		set_hint("EMPTY  /  reload with R or RELOAD", 2.0)
		_fire_cooldown = 0.2
		return
	ammo -= 1
	_fire_cooldown = 0.22
	var camera: Camera3D = player.camera
	var hit: bool = world.apply_shot(camera.global_position, -camera.global_basis.z, 34.0)
	sound.play("shot")
	player.shot_effect()
	if hit:
		_hitmarker = 1.0
		sound.play("hit")

func _on_loot(value: int) -> void:
	if mode != "playing":
		return
	loot += value
	sound.play("loot")
	set_hint("CASE SECURED  /  %d OF %d  /  extraction banks your haul" % [loot, world.total_loot], 3.0)

func _on_damage(_amount: float) -> void:
	_danger = 1.0
	sound.play("hurt")
	if hud.touch_enabled:
		Input.vibrate_handheld(100)

func _on_tether_event(event: String) -> void:
	if event in ["cast", "lock", "release", "cut"]:
		sound.play(event)
		if event == "cast":
			set_hint("WEIGHT AWAY  /  LOCK the spool to take the pull", 2.5)
	else:
		set_hint(event, 3.0)

func set_hint(message: String, duration: float = 3.0) -> void:
	_hint = message
	_hint_time = duration

func _release_controls() -> void:
	player.move_input = Vector2.ZERO
	tether.reeling = false
	tether.charging = false
	tether.charge = 0.0

func _pause() -> void:
	mode = "paused"
	_release_controls()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_pause()
	get_tree().paused = true

func _resume() -> void:
	if mode != "paused":
		return
	get_tree().paused = false
	mode = "playing"
	hud.show_game()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if hud.touch_enabled else Input.MOUSE_MODE_CAPTURED

func _finish(won: bool) -> void:
	if mode != "playing":
		return
	mode = "result"
	_release_controls()
	player.active = false
	tether.active = false
	world.set_active(false)
	if won and not practice:
		bank += loot
		_save_profile()
	sound.motion(0.0, 0.0, false, false)
	sound.play("win" if won else "lose")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_result(won, loot, elapsed, bank)
	# Freeze physics in a result view without pausing the UI or the result sound.
	player.freeze = true
	if is_instance_valid(tether.weight):
		tether.weight.freeze = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and mode == "playing" and not _capture:
		_pause()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST and mode == "playing":
		_pause()

func _load_profile() -> void:
	var profile := ConfigFile.new()
	if profile.load("user://profile.cfg") == OK:
		bank = maxi(0, int(profile.get_value("salvage", "bank", 0)))

func _save_profile() -> void:
	var profile := ConfigFile.new()
	profile.set_value("salvage", "bank", bank)
	profile.save("user://profile.cfg")

func _register_inputs() -> void:
	var keys: Dictionary = {
		"move_left": KEY_A, "move_right": KEY_D, "move_forward": KEY_W,
		"move_back": KEY_S, "reel": KEY_E, "cut": KEY_Q, "weapon": KEY_F,
		"reload": KEY_R, "jump": KEY_SPACE, "pause": KEY_ESCAPE
	}
	for name: String in keys:
		if not InputMap.has_action(name):
			InputMap.add_action(name)
		var event := InputEventKey.new()
		event.physical_keycode = keys[name]
		InputMap.action_add_event(name, event)
	for name: String in {"cast": MOUSE_BUTTON_LEFT, "lock": MOUSE_BUTTON_RIGHT}:
		if not InputMap.has_action(name):
			InputMap.add_action(name)
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT if name == "cast" else MOUSE_BUTTON_RIGHT
		InputMap.action_add_event(name, event)

func _capture_frame() -> void:
	for frame in range(90):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path: String = "res://builds/capture.png"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-path="):
			path = arg.trim_prefix("--capture-path=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var error: Error = get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURE ", path, " result=", error)
	get_tree().quit(0 if error == OK else 1)
