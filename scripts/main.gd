extends Node3D
## Game flow (CONTRACT 4.7): boot -> title/menu -> loading -> playing <-> paused -> result.
## Owns the player, tether, HUD, UI root, audio and the current level; routes desktop input
## (touch arrives through the HUD signals); records runs, rewards and saving. Simulation always
## uses the fixed physics tick, and the menus run while the tree is paused.

signal state_changed(new_state: String)
signal level_started(level_id: String)
signal run_finished(result: Dictionary)

const PlayerScript = preload("res://scripts/player.gd")
const TetherScript = preload("res://scripts/tether.gd")
const HudScript = preload("res://scripts/hud.gd")
const SoundScript = preload("res://scripts/audio.gd")
const UiRootScript = preload("res://scripts/ui/ui_root.gd")
const ProfileScript = preload("res://scripts/profile.gd")
const Catalog = preload("res://scripts/level_catalog.gd")
const Achievements = preload("res://scripts/achievements.gd")
const Settings = preload("res://scripts/settings.gd")
const INPUT_SETUP_PATH := "res://scripts/input_setup.gd"

const CHECKPOINT_SECONDS: float = 0.5
const FALL_DAMAGE: float = 35.0
const PlatformScript = preload("res://scripts/platform.gd")
const UpgradesScript = preload("res://scripts/upgrades.gd")
const EXTRACTION_SECONDS: float = 6.0
const LOADING_SECONDS: float = 0.45
const RESTART_LOADING_SECONDS: float = 0.15
const SAVE_DELAY_SECONDS: float = 0.6
const BASE_LOOK_SENSITIVITY: float = 0.0024
const DAMAGE_SCALE := [0.5, 1.0, 1.5]
const TITLE_LEVEL := "l01"
const DEFAULT_CAPTURE_FRAMES: int = 90

## Command-line user arguments (CONTRACT 4.7). Tests set this before adding the node to the tree;
## when empty the real arguments after "--" are used.
var override_args: PackedStringArray = PackedStringArray()

var state: String = "boot"
var player: RigidBody3D
var tether: Node3D
var level: Node3D
var hud: CanvasLayer
var ui: CanvasLayer
var sound: Node
var platform: Node
var profile: RefCounted
var level_id: String = ""
var practice: bool = false
var elapsed: float = 0.0
var extraction_time: float = 0.0
var extraction_inside: bool = false
var weapon: String = "ROD"
var ammo: int = 0
var reserve: int = 48
## Per-run counters handed to profile.record_run (CONTRACT 5.5).
var run_stats: Dictionary = {}
var last_result: Dictionary = {}
## Workshop numbers for this raid (Upgrades.stats), read when the raid begins.
var loadout: Dictionary = {}

var _args: PackedStringArray = PackedStringArray()
var _forced_practice: bool = false
var _load_token: int = 0
var _reload_time: float = 0.0
var _fire_cooldown: float = 0.0
var _hint: String = ""
var _hint_time: float = 0.0
var _hitmarker: float = 0.0
var _danger: float = 0.0
var _air_time: float = 0.0
var _fell_out: bool = false
var _next_level: String = ""
var _capture: bool = false
var _hide_ui: bool = false
var _cam_override: Array = []
var _save_timer: Timer
var _save_pending: bool = false
var _attract: Camera3D
var _attract_time: float = 0.0
var _checkpoint: Vector3 = Vector3.ZERO
var _checkpoint_yaw: float = 0.0
var _checkpoint_timer: float = 0.0
var _device: String = "kbm"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_args = override_args if not override_args.is_empty() else OS.get_cmdline_user_args()
	_hide_ui = "--hide-ui" in _args
	_capture = "--capture" in _args
	_register_inputs()
	_load_profile()
	_build_nodes()
	if "--touch" in _args:
		Input.emulate_touch_from_mouse = true
	_apply_settings()
	_catch_up_achievements()
	var cam_text: String = _arg_value("--cam=", "")
	if not cam_text.is_empty():
		for part: String in cam_text.split(","):
			_cam_override.append(part.to_float())
		if _cam_override.size() != 5:
			push_warning("--cam expects x,y,z,yaw_deg,pitch_deg")
			_cam_override.clear()
	var start_id: String = _arg_value("--level=", "")
	if not start_id.is_empty():
		start_level(start_id)
	else:
		_open_title()
		var screen_name: String = _arg_value("--screen=", "")
		if not screen_name.is_empty():
			_open_screen(screen_name)
	if _capture:
		_capture_frame.call_deferred()


func _build_nodes() -> void:
	player = PlayerScript.new()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	player.damaged.connect(_on_damage)
	player.died.connect(_on_player_died)
	tether = TetherScript.new()
	tether.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(tether)
	tether.bind(player)
	tether.event_happened.connect(_on_tether_event)
	sound = SoundScript.new()
	sound.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(sound)
	sound.add_to_group("game_audio")
	platform = PlatformScript.new()
	add_child(platform)
	platform.setup()
	hud = HudScript.new()
	add_child(hud)
	hud.action_requested.connect(_action)
	hud.look_requested.connect(func(delta: Vector2) -> void:
		if state == "playing":
			_look(delta * 1.4))
	_set_hud_visible(false)
	_attract = Camera3D.new()
	_attract.fov = 70.0
	_attract.far = 400.0
	add_child(_attract)
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DELAY_SECONDS
	_save_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_save_timer.timeout.connect(_flush_save)
	add_child(_save_timer)
	# The UI root is added last so it sees input before the game does.
	ui = UiRootScript.new()
	add_child(ui)
	ui.bind(profile)
	ui.level_requested.connect(func(id: String) -> void: start_level(id))
	ui.restart_requested.connect(_restart)
	ui.next_level_requested.connect(func() -> void:
		if not _next_level.is_empty():
			start_level(_next_level))
	ui.resume_requested.connect(_resume)
	ui.menu_requested.connect(_open_title)
	ui.setting_changed.connect(_on_setting_changed)
	ui.upgrade_requested.connect(_on_upgrade_requested)
	ui.reset_progress_requested.connect(_on_reset_requested)
	ui.quit_requested.connect(_quit)
	if _hide_ui:
		ui.visible = false


# --- State machine -----------------------------------------------------------------------------

func _set_state(next: String) -> void:
	if state == next:
		return
	state = next
	_update_mouse()
	# Any path out of "paused" (resume, title, a new level) lifts the SFX low-pass again.
	if is_instance_valid(sound):
		sound.set_paused(next == "paused")
	state_changed.emit(next)


## The title screen over a slow fly-by of Sluice Gate (practice mode, so no enemies).
func _open_title() -> void:
	_load_token += 1
	get_tree().paused = false
	_release_controls()
	_end_run_nodes()
	_build_level(TITLE_LEVEL, true)
	level.set_active(false)
	player.freeze = true
	player.global_position = level.get("spawn_position")
	_attract_time = 0.0
	_place_attract()
	_attract.make_current()
	_set_hud_visible(false)
	_set_state("title")
	ui.hide_all()
	ui.show_title()


func _open_screen(screen_name: String) -> void:
	match screen_name:
		"title":
			pass
		"levels":
			ui.show_level_select()
		"workshop":
			ui.show_workshop()
		"settings":
			ui.show_settings()
		"credits":
			ui.show_credits()
		"records":
			ui.show_records()
		"pause":
			ui.show_pause("Sluice Gate")
		"loading":
			ui.show_loading("Sluice Gate", "FLOODWORKS  /  RAID 01")
		"result":
			ui.show_result(_sample_result())
		_:
			push_warning("--screen: unknown screen '%s'" % screen_name)


## Loads and starts a level through the loading screen. Await it to know when play has begun.
func start_level(id: String, force_practice: bool = false) -> void:
	var details: Dictionary = Catalog.info(id)
	if details.is_empty() or not bool(details.get("available", false)):
		push_warning("Level '%s' is not available." % id)
		if state == "boot":
			_open_title()
		return
	_load_token += 1
	var token: int = _load_token
	var quick: bool = id == level_id and state in ["result", "paused", "playing"]
	var wants_practice: bool = bool(details.get("practice", false)) or force_practice or "--practice" in _args
	_forced_practice = force_practice or "--practice" in _args
	get_tree().paused = false
	_release_controls()
	_end_run_nodes()
	_set_hud_visible(false)
	_set_state("loading")
	ui.hide_all()
	ui.show_loading(str(details.get("title", id)), _loading_subtitle(details, wants_practice))
	var started: int = Time.get_ticks_msec()
	await get_tree().process_frame
	await get_tree().process_frame
	if token != _load_token:
		return
	_build_level(id, wants_practice)
	var wait: float = (RESTART_LOADING_SECONDS if quick else LOADING_SECONDS) - float(Time.get_ticks_msec() - started) / 1000.0
	if wait > 0.0:
		await get_tree().create_timer(wait, true, false, true).timeout
		if token != _load_token:
			return
	_begin_play()
	level_started.emit(id)


func _loading_subtitle(details: Dictionary, wants_practice: bool) -> String:
	var zone_title: String = str(Catalog.ZONES.get(str(details.get("zone", "")), {}).get("title", ""))
	var number: int = int(details.get("number", -1))
	var tail: String = "PRACTICE" if wants_practice else ("INDUCTION" if number == 0 else ("RAID %02d" % number if number > 0 else ""))
	if zone_title.is_empty():
		return tail
	return zone_title if tail.is_empty() else "%s  /  %s" % [zone_title, tail]


func _build_level(id: String, practice_mode: bool) -> void:
	if is_instance_valid(level):
		level.set_active(false)
		remove_child(level)
		level.queue_free()
	level_id = id
	practice = practice_mode
	level = Catalog.create(id)
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	level.set("damage_scale", float(DAMAGE_SCALE[clampi(int(profile.setting("difficulty")), 0, 2)]))
	level.set("quality", int(profile.setting("quality")))
	add_child(level)
	move_child(level, 0)
	level.loot_collected.connect(_on_loot)
	level.extraction_changed.connect(func(inside: bool) -> void:
		extraction_inside = inside
		if not inside:
			extraction_time = 0.0)
	level.threat_changed.connect(func(message: String) -> void:
		if state == "playing":
			set_hint(message, 2.5))
	level.enemy_killed.connect(_on_enemy_killed)
	# Hint zones (F8) show their text once per build, only while playing.
	level.hint_requested.connect(func(text: String, duration: float) -> void:
		if state == "playing":
			set_hint(text, duration))
	level.build(player, practice_mode)
	# Hounds path over the navmesh (E1). Baked synchronously so it is ready at once.
	level.bake_navigation(true)
	level.apply_quality(int(profile.setting("quality")))
	level.set_active(false)


func _begin_play() -> void:
	_reset_run()
	player.freeze = false
	player.reset_at(level.get("spawn_position"))
	# configure() sets max_health from the loadout and refills health to it (G1).
	player.configure(loadout)
	player.yaw = float(level.get("spawn_yaw"))
	player.pitch = -0.04
	player.apply_look(Vector2.ZERO)
	_checkpoint = level.get("spawn_position")
	_checkpoint_yaw = float(level.get("spawn_yaw"))
	_checkpoint_timer = CHECKPOINT_SECONDS
	player.active = true
	tether.active = true
	player.camera.make_current()
	level.set_active(true)
	_apply_player_settings()
	_set_state("playing")
	ui.hide_all()
	_set_hud_visible(true)
	hud.show_game()
	set_hint("AIM ABOVE THE HORIZON  /  charge {cast}, release, then {lock} to ride the weight", 8.0)
	if not _cam_override.is_empty():
		player.reset_at(Vector3(_cam_override[0], _cam_override[1], _cam_override[2]))
		player.yaw = deg_to_rad(float(_cam_override[3]))
		player.pitch = deg_to_rad(float(_cam_override[4]))
		player.apply_look(Vector2.ZERO)
		player.active = false
		tether.active = false
		player.freeze = true


func _reset_run() -> void:
	elapsed = 0.0
	extraction_time = 0.0
	extraction_inside = false
	loadout = UpgradesScript.stats(profile.upgrades)
	# Workshop stats for the line: spool, reel motor, sinker, assist and quickdraw (CONTRACT 4.9).
	tether.configure(loadout)
	weapon = "ROD"
	ammo = magazine_size()
	reserve = 48
	_reload_time = 0.0
	_fire_cooldown = 0.0
	_hitmarker = 0.0
	_danger = 0.0
	_air_time = 0.0
	_fell_out = false
	_hint = ""
	_hint_time = 0.0
	run_stats = {"casts": 0, "kills": 0, "smash_kills": 0, "shots": 0, "damage_taken": 0.0, "max_speed": 0.0, "max_airtime": 0.0}


## Magazine size for this raid, from the sidearm workshop track (stock 10).
func magazine_size() -> int:
	return int(loadout.get("magazine", 10))


## Stops the player and tether and drops the current weight (used before loading and on the title).
func _end_run_nodes() -> void:
	player.active = false
	tether.active = false
	tether.clear()
	if is_instance_valid(level):
		level.set_active(false)


func _restart() -> void:
	if level_id.is_empty():
		return
	start_level(level_id, _forced_practice)


func _pause() -> void:
	if state != "playing":
		return
	_release_controls()
	_set_state("paused")
	_set_hud_visible(false)
	hud.show_menu()
	get_tree().paused = true
	ui.show_pause(str(level.get("info").get("title", level_id)))


func _resume() -> void:
	if state != "paused":
		return
	get_tree().paused = false
	ui.hide_all()
	_set_state("playing")
	_set_hud_visible(true)
	hud.show_game()


func _finish(won: bool, cause: String = "") -> void:
	if state != "playing":
		return
	_set_state("result")
	_release_controls()
	player.active = false
	tether.active = false
	level.set_active(false)
	last_result = _build_result(won, cause)
	sound.motion(0.0, 0.0, false, false)
	_sfx("win" if won else "lose")
	_set_hud_visible(false)
	hud.show_menu()
	# Freeze physics in a result view without pausing the UI or the result sound.
	player.freeze = true
	if is_instance_valid(tether.weight):
		tether.weight.freeze = true
	ui.show_result(last_result)
	run_finished.emit(last_result)


## Records the finished run in the profile, saves, and returns the CONTRACT 5.10 result.
func _build_result(won: bool, cause: String) -> Dictionary:
	var info: Dictionary = level.get("info")
	var run: Dictionary = run_stats.duplicate()
	run["level_id"] = level_id
	run["won"] = won
	run["time"] = elapsed
	run["cases"] = int(level.get("collected_loot"))
	run["bonus_indices"] = (level.get("collected_bonus") as Array).duplicate()
	run["total_bonus"] = int(level.get("total_bonus"))
	run["enemies_present"] = bool(info.get("enemies", false)) and not practice
	var reward: Dictionary = {"salvage": 0, "breakdown": [], "medal": 0, "previous_medal": 0, "best_time": -1.0, "new_best": false}
	var titles: Array[String] = []
	if practice:
		profile.add_play_stats(run)
	else:
		reward = profile.record_run(run)
		for achievement_id: String in Achievements.end_of_run(run, profile):
			if profile.unlock_achievement(achievement_id):
				titles.append(Achievements.title_of(achievement_id))
				_platform_unlock(achievement_id)
	_flush_save_now()
	var next_id: String = ""
	if won and not practice:
		next_id = profile.next_campaign_id(level_id)
		if not next_id.is_empty() and not profile.is_unlocked(next_id):
			next_id = ""
	_next_level = next_id
	return {
		"won": won, "level_id": level_id, "title": str(info.get("title", level_id)), "time": elapsed,
		"cases": int(run["cases"]), "total_cases": int(level.get("total_loot")),
		"bonus": (run["bonus_indices"] as Array).size(), "total_bonus": int(run["total_bonus"]),
		"salvage": int(reward["salvage"]), "breakdown": reward["breakdown"],
		"medal": int(reward["medal"]), "previous_medal": int(reward["previous_medal"]),
		"best_time": float(reward["best_time"]), "new_best": bool(reward["new_best"]),
		"par_silver": float(info.get("par_silver", 0.0)), "par_gold": float(info.get("par_gold", 0.0)),
		"bank": int(profile.bank), "next_level": next_id, "achievements": titles, "cause": cause,
		"stats": {
			"max_speed": float(run["max_speed"]), "max_airtime": float(run["max_airtime"]),
			"casts": int(run["casts"]), "kills": int(run["kills"]), "damage_taken": float(run["damage_taken"]),
		},
	}


# --- Per-frame ---------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not is_instance_valid(hud):
		return
	if state == "title" or state == "menu":
		_attract_time += delta
		_place_attract()
		_follow_menu_state()
	elif state == "playing":
		_hint_time = maxf(0.0, _hint_time - delta)
		_hitmarker = maxf(0.0, _hitmarker - delta * 5.0)
		_danger = maxf(0.0, _danger - delta * 0.9)
		player.set_feedback(tether.charge, tether.tension, weapon)
		sound.motion(player.linear_velocity.length(), tether.tension, tether.reeling, true)
		var cases: int = int(level.get("collected_loot"))
		var total: int = int(level.get("total_loot"))
		var default_hint: String = "SALVAGE %d / %d  /  follow the cyan case beacons" % [cases, total]
		if cases >= total:
			default_hint = "ALL CASES SECURED  /  reach the amber extraction gate"
		if extraction_inside:
			default_hint = "HOLD POSITION  /  extraction in %.1fs" % maxf(0.0, EXTRACTION_SECONDS - extraction_time) if cases >= total else "EXTRACTION LOCKED  /  recover all %d cases" % total
		hud.update_state({
			"health": player.health * 100.0 / maxf(1.0, float(loadout.get("max_health", 100.0))), "speed": player.linear_velocity.length(),
			"tension": tether.tension, "line_length": tether.line_length,
			"reel_state": tether.state_name(), "charge": tether.charge,
			"loot": cases, "total_loot": total,
			"extraction": extraction_time / EXTRACTION_SECONDS,
			"extraction_inside": extraction_inside, "time": elapsed,
			"weapon": weapon, "ammo": ammo, "reserve": reserve,
			"reloading": _reload_time > 0.0,
			"hint": _hint if _hint_time > 0.0 else default_hint,
			"hitmarker": _hitmarker, "danger": _danger, "practice": practice,
			# Medal target, bonus progress and extraction state for the HUD (G6).
			"par_silver": float((level.get("info") as Dictionary).get("par_silver", 0.0)),
			"par_gold": float((level.get("info") as Dictionary).get("par_gold", 0.0)),
			"bonus": (level.get("collected_bonus") as Array).size(),
			"total_bonus": int(level.get("total_bonus")),
			"extraction_ready": cases >= total,
			"airborne": not player.grounded
		})


func _physics_process(delta: float) -> void:
	if state != "playing":
		return
	elapsed += delta
	var speed: float = player.linear_velocity.length()
	run_stats["max_speed"] = maxf(float(run_stats["max_speed"]), speed)
	if player.grounded:
		_air_time = 0.0
	else:
		_air_time += delta
		run_stats["max_airtime"] = maxf(float(run_stats["max_airtime"]), _air_time)
	if speed >= Achievements.TERMINAL_SPEED:
		_award("TERMINAL")
	if _air_time >= Achievements.HANG_TIME_SECONDS:
		_award("HANG_TIME")
	_track_checkpoint(delta)
	var keyboard: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	player.move_input = (keyboard + hud.move_vector).limit_length(1.0)
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	if _reload_time > 0.0:
		_reload_time -= delta
		if _reload_time <= 0.0:
			var loaded: int = mini(magazine_size() - ammo, reserve)
			ammo += loaded
			reserve -= loaded
	if extraction_inside and int(level.get("collected_loot")) >= int(level.get("total_loot")):
		extraction_time += delta
		if extraction_time >= EXTRACTION_SECONDS:
			if bool((level.get("info") as Dictionary).get("repeatable", false)):
				_extract_repeatable()
			else:
				_finish(true)
				return
	else:
		extraction_time = 0.0
	if player.global_position.y < float(level.get("kill_y")) and _cam_override.is_empty():
		_fall_respawn()


# --- Input -------------------------------------------------------------------------------------

## Remembers the last device used, so hints name the buttons the player is actually using.
func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton:
		_device = "kbm"
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_device = "gamepad"
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		_device = "touch"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		if state == "playing":
			_pause()
			get_viewport().set_input_as_handled()
		elif state == "paused" and ui.current_screen() == "pause" and not ui.is_confirm_open():
			_resume()
			get_viewport().set_input_as_handled()
		return
	if state != "playing":
		return
	if event is InputEventMouseMotion and not hud.touch_enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look((event as InputEventMouseMotion).relative)
	if hud.touch_enabled and (event is InputEventMouseMotion or event is InputEventMouseButton):
		return
	for action in ["cast", "lock", "reel", "cut", "weapon", "reload", "jump"]:
		if event.is_action_pressed(action) and not event.is_echo():
			_action(action, true)
		elif event.is_action_released(action):
			_action(action, false)


## Checkpoints: every CHECKPOINT_SECONDS the grounded player's spot becomes the respawn point.
func _track_checkpoint(delta: float) -> void:
	_checkpoint_timer -= delta
	if _checkpoint_timer > 0.0:
		return
	_checkpoint_timer = CHECKPOINT_SECONDS
	if player.grounded and player.global_position.y > float(level.get("kill_y")) + 2.0:
		_checkpoint = player.global_position
		_checkpoint_yaw = player.yaw


## A fall below kill_y cuts the line and returns the player to the last safe ground.
## Raids take FALL_DAMAGE (a fatal fall ends the run with cause "fall"); practice is free.
func _fall_respawn() -> void:
	tether.cut()
	if practice:
		_return_to_checkpoint()
		set_hint("PRACTICE RESET  /  back on the last safe ground", 4.0)
		return
	_fell_out = true
	player.take_damage(FALL_DAMAGE)
	if state != "playing":
		return
	_fell_out = false
	_return_to_checkpoint()
	set_hint("FELL  /  line cut, back on the last safe ground", 4.0)


## reset_at restores full health, so the health held before the reset is put back.
func _return_to_checkpoint() -> void:
	var health: float = player.health
	player.reset_at(_checkpoint)
	player.yaw = _checkpoint_yaw
	player.apply_look(Vector2.ZERO)
	player.health = maxf(health, 1.0)


## Repeatable levels (the range) bank the extraction, show a banner and restock their cases.
func _extract_repeatable() -> void:
	extraction_time = 0.0
	ui.show_toast("EXTRACTED", "cases reset for the next run")
	_sfx("win")
	if level.has_method("reset_cases"):
		level.call("reset_cases")


## Live achievement: unlocks once, toasts, and reaches Steam through platform.gd.
func _award(achievement_id: String) -> void:
	if profile.has_achievement(achievement_id):
		return
	if profile.unlock_achievement(achievement_id):
		var entry: Dictionary = Achievements.find(achievement_id)
		ui.show_toast(str(entry.get("title", achievement_id)), str(entry.get("desc", "")))
		_platform_unlock(achievement_id)
		_save_soon()


## Tells the platform layer about an unlock. Does nothing when platform.gd is absent.
func _platform_unlock(achievement_id: String) -> void:
	if is_instance_valid(platform):
		platform.unlock_achievement(achievement_id)


## Plays a sound event through the audio node when it exists.
func _sfx(event_name: String) -> void:
	if is_instance_valid(sound) and sound.has_method("play"):
		sound.play(event_name)


## Hint text with {tokens} replaced for the last-used device (input_setup.gd, F2).
## Text without tokens comes back unchanged, and so does everything when that file is absent.
func _expand(text: String) -> String:
	if not ResourceLoader.exists(INPUT_SETUP_PATH):
		return text
	var setup: Script = load(INPUT_SETUP_PATH) as Script
	if setup == null or not setup.has_method("expand_tokens"):
		return text
	var device: String = "touch" if is_instance_valid(hud) and hud.touch_enabled else _device
	return str(setup.call("expand_tokens", text, device))


func _look(delta: Vector2) -> void:
	if bool(profile.setting("invert_y")):
		delta.y = -delta.y
	player.apply_look(delta)


func _action(action: String, pressed: bool) -> void:
	if action == "pause" and pressed:
		if state == "playing":
			_pause()
		elif state == "paused" and ui.current_screen() == "pause":
			_resume()
		return
	if state != "playing":
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
			if pressed and ammo < magazine_size() and reserve > 0 and _reload_time <= 0.0:
				_reload_time = 1.5
				_sfx("reload")
		"jump":
			if pressed:
				player.request_jump()


func _fire() -> void:
	if _fire_cooldown > 0.0 or _reload_time > 0.0:
		return
	if ammo <= 0:
		_sfx("empty")
		set_hint("EMPTY  /  reload with {reload}", 2.0)
		_fire_cooldown = 0.2
		return
	ammo -= 1
	run_stats["shots"] = int(run_stats["shots"]) + 1
	_fire_cooldown = 0.22
	var camera: Camera3D = player.camera
	var hit: bool = level.apply_shot(camera.global_position, -camera.global_basis.z, float(loadout.get("sidearm_damage", 34.0)))
	_sfx("shot")
	player.shot_effect()
	if hit:
		_hitmarker = 1.0
		_sfx("hit")


func _release_controls() -> void:
	player.move_input = Vector2.ZERO
	tether.reeling = false
	tether.charging = false
	tether.charge = 0.0
	if is_instance_valid(hud):
		hud.move_vector = Vector2.ZERO


func _update_mouse() -> void:
	var capture: bool = state == "playing" and not hud.touch_enabled and not _capture
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if capture else Input.MOUSE_MODE_VISIBLE


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == "playing" and not _capture:
		_pause()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST and state == "playing":
		# Deferred so the UI root, which gets the same notification, does not close the new menu.
		_pause.call_deferred()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_flush_save()


# --- Events from the game ----------------------------------------------------------------------

func _on_loot(kind: String, _value: int) -> void:
	if state != "playing":
		return
	_sfx("loot")
	if kind == "case":
		set_hint("CASE SECURED  /  %d OF %d  /  extraction banks your haul" % [int(level.get("collected_loot")), int(level.get("total_loot"))], 3.0)
	else:
		set_hint("BONUS CACHE FOUND  /  pays when you extract", 3.0)


func _on_damage(amount: float, _source: String, _from_position: Vector3) -> void:
	_danger = 1.0
	run_stats["damage_taken"] = float(run_stats.get("damage_taken", 0.0)) + amount
	_sfx("hurt")
	if is_instance_valid(platform):
		platform.vibrate(100)


func _on_player_died(_source: String) -> void:
	_finish(false, _death_cause())


func _on_enemy_killed(_kind: String, by: String) -> void:
	run_stats["kills"] = int(run_stats["kills"]) + 1
	if by in ["smash", "weight"]:
		run_stats["smash_kills"] = int(run_stats["smash_kills"]) + 1
		_award("DEADWEIGHT")


## Tether events arrive as ids only (CONTRACT 4.9). Sounds play for every id; hints are picked here.
func _on_tether_event(event: String) -> void:
	_sfx(event)
	match event:
		"cast":
			run_stats["casts"] = int(run_stats["casts"]) + 1
			_award("FIRST_CAST")
			set_hint("WEIGHT AWAY  /  {lock} to take the pull", 2.5)
		"anchor":
			_award("FIRST_ANCHOR")
			set_hint("ANCHORED  /  {reel} pulls you in, {cut} lets go", 3.0)
		"recover":
			set_hint("WEIGHT RECOVERED  /  {cast} to throw again", 2.5)
		"spool_limit":
			set_hint("SPOOL LIMIT  /  {lock} holds the line, {reel} takes it in", 2.5)
		"severed":
			set_hint("LINE SEVERED  /  keep your line clear of concrete", 3.0)
		"overload":
			set_hint("LINE OVERLOAD  /  cast again", 3.0)
		"no_clearance":
			set_hint("NO CAST CLEARANCE  /  step back from cover", 3.0)
		"cut_first":
			set_hint("CUT FIRST  /  {cut} to prepare a new weight", 3.0)
		"auto_cut":
			set_hint("LINE CUT  /  charging the next weight", 2.0)


## The nearest living enemy decides the cause; otherwise the player fell.
func _death_cause() -> String:
	if _fell_out:
		return "fall"
	var best: String = "fall"
	var best_distance: float = 16.0
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var distance: float = (node as Node3D).global_position.distance_to(player.global_position)
		if distance < best_distance:
			best_distance = distance
			best = str(node.get("kind"))
	return best


func set_hint(message: String, duration: float = 3.0) -> void:
	_hint = _expand(message)
	_hint_time = duration


# --- Menus, profile and settings ---------------------------------------------------------------

func _on_setting_changed(key: String, value: Variant) -> void:
	profile.set_setting(key, value)
	_apply_settings()
	if state in ["playing", "paused"]:
		_apply_player_settings()
		level.apply_quality(int(profile.setting("quality")))
	ui.refresh()
	_save_soon()


func _on_upgrade_requested(upgrade_id: String) -> void:
	if not profile.purchase(upgrade_id):
		ui.sound("ui_denied")
		return
	ui.sound("ui_buy")
	for achievement_id: String in Achievements.progress_unlocks(profile):
		if profile.unlock_achievement(achievement_id):
			ui.show_toast(Achievements.title_of(achievement_id), str(Achievements.find(achievement_id).get("desc", "")))
			_platform_unlock(achievement_id)
	_flush_save_now()
	ui.refresh()


func _on_reset_requested() -> void:
	profile.reset_progress()
	_flush_save_now()
	ui.refresh()


func _quit() -> void:
	_flush_save()
	get_tree().quit()


func _load_profile() -> void:
	profile = ProfileScript.new()
	profile.unlock_all = "--unlock-all" in _args
	var path: String = _arg_value("--profile=", "")
	if path.is_empty():
		profile.load_profile()
	else:
		profile.load_profile(path)


## Awards the achievements implied by saved progress (catches up after an update).
func _catch_up_achievements() -> void:
	var changed: bool = false
	for achievement_id: String in Achievements.progress_unlocks(profile):
		changed = profile.unlock_achievement(achievement_id) or changed
	if changed:
		_save_soon()


func _save_soon() -> void:
	_save_pending = true
	_save_timer.start()


func _flush_save() -> void:
	if _save_pending:
		_save_pending = false
		_save_timer.stop()
		profile.save_profile()


func _flush_save_now() -> void:
	_save_pending = true
	_flush_save()


func _apply_settings() -> void:
	Settings.apply_engine(profile.settings, _allow_window_changes())
	Settings.apply_audio(profile.settings)
	if is_instance_valid(platform):
		platform.set_haptics(bool(profile.setting("haptics")))


func _apply_player_settings() -> void:
	player.look_sensitivity = BASE_LOOK_SENSITIVITY * float(profile.setting("look_sensitivity"))
	if player.has_method("apply_settings"):
		player.call("apply_settings", profile.settings)
	# Auto-cut decides whether CAST drops the attached weight or asks for a CUT first.
	if is_instance_valid(tether):
		tether.auto_cut = bool(profile.setting("auto_cut"))
	# The HUD reads show_telemetry and other display settings (G6).
	if is_instance_valid(hud):
		hud.apply_settings(profile.settings)
	elif is_instance_valid(player.camera):
		player.camera.fov = float(profile.setting("fov"))


## Window changes are off for captures, --windowed, the editor and --script runs.
func _allow_window_changes() -> bool:
	if "--windowed" in _args or "--capture" in _args or OS.has_feature("editor"):
		return false
	for argument: String in OS.get_cmdline_args():
		if argument == "--script" or argument == "-s":
			return false
	return true


func _arg_value(prefix: String, fallback: String) -> String:
	for argument: String in _args:
		if argument.begins_with(prefix):
			return argument.substr(prefix.length())
	return fallback


func _set_hud_visible(shown: bool) -> void:
	hud.visible = shown and not _hide_ui


# --- Title backdrop ----------------------------------------------------------------------------

## Menu sub screens (levels, workshop...) count as the "menu" state; the title as "title".
func _follow_menu_state() -> void:
	var current: String = ui.current_screen()
	if current != "" and current != "title" and state == "title":
		_set_state("menu")
	elif current == "title" and state == "menu":
		_set_state("title")


func _place_attract() -> void:
	var t: float = _attract_time
	_attract.global_position = Vector3(4.0 + sin(t * 0.11) * 5.0, 4.5 + sin(t * 0.07) * 0.8, 2.0 - (1.0 - cos(t * 0.05)) * 9.0)
	_attract.look_at(Vector3(6.0 + sin(t * 0.09) * 6.0, 3.0, -60.0), Vector3.UP)


# --- Input map ---------------------------------------------------------------------------------

func _register_inputs() -> void:
	if ResourceLoader.exists(INPUT_SETUP_PATH):
		var setup: Script = load(INPUT_SETUP_PATH) as Script
		if setup != null and setup.has_method("register"):
			setup.call("register")
			return
	var keys: Dictionary = {
		"move_left": KEY_A, "move_right": KEY_D, "move_forward": KEY_W,
		"move_back": KEY_S, "reel": KEY_E, "cut": KEY_Q, "weapon": KEY_F,
		"reload": KEY_R, "jump": KEY_SPACE, "pause": KEY_ESCAPE
	}
	for action_name: String in keys:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		var event := InputEventKey.new()
		event.physical_keycode = keys[action_name]
		InputMap.action_add_event(action_name, event)
	for action_name: String in {"cast": MOUSE_BUTTON_LEFT, "lock": MOUSE_BUTTON_RIGHT}:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT if action_name == "cast" else MOUSE_BUTTON_RIGHT
		InputMap.action_add_event(action_name, event)


# --- Captures ----------------------------------------------------------------------------------

func _capture_frame() -> void:
	var frames: int = int(_arg_value("--capture-delay=", str(DEFAULT_CAPTURE_FRAMES)))
	for frame in range(frames):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path: String = _arg_value("--capture-path=", "res://builds/capture.png")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var error: Error = get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURE ", path, " result=", error)
	get_tree().quit(0 if error == OK else 1)


## A made-up won result for --screen=result.
func _sample_result() -> Dictionary:
	return {
		"won": true, "level_id": "l01", "title": "Sluice Gate", "time": 92.4, "cases": 3, "total_cases": 3,
		"bonus": 1, "total_bonus": 2, "salvage": 85,
		"breakdown": [["CASES x3", 45], ["BONUS CACHES x1", 30], ["FIRST BRONZE MEDAL", 10]],
		"medal": 3, "previous_medal": 0, "best_time": 92.4, "new_best": true, "par_silver": 150.0, "par_gold": 95.0,
		"bank": int(profile.bank), "next_level": "", "achievements": [], "cause": "",
		"stats": {"max_speed": 31.0, "max_airtime": 6.5, "casts": 18, "kills": 2, "damage_taken": 0.0},
	}
