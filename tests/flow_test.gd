extends SceneTree
## Game-flow checks (CONTRACT 4.7): boots the real main.gd with a private profile file and drives
## title -> practice -> pause -> raid -> objectives -> extraction -> result -> save, then a failed
## run and retry, the workshop, live settings, the command-line arguments and quitting.
## Run: godot --headless --fixed-fps 90 --quit-after 200000 --path . --script res://tests/flow_test.gd
## Only user://test_f10*.cfg (and their .bak/.tmp/.corrupt companions) are ever touched.

const MainScript = preload("res://scripts/main.gd")
const ProfileScript = preload("res://scripts/profile.gd")
const Catalog = preload("res://scripts/level_catalog.gd")
const InputSetup = preload("res://scripts/input_setup.gd")
const PATH := "user://test_f10.cfg"
const PATH_B := "user://test_f10b.cfg"
const CAUSES := ["hound", "sentry", "drone", "fall", "impact", "hazard"]

var _failures: int = 0
var _checks: int = 0
var _main: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_wipe(PATH)
	_wipe(PATH_B)
	await _test_boot_and_title()
	await _test_practice_and_pause()
	await _test_raid_to_result()
	await _test_failed_run_and_retry()
	await _test_menus_and_settings()
	await _test_arguments()
	_test_quit_saves()
	_wipe(PATH)
	_wipe(PATH_B)
	print("FLOW TEST: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _test_boot_and_title() -> void:
	_main = MainScript.new()
	_main.override_args = PackedStringArray(["--profile=" + PATH, "--windowed"])
	_check(_main.state == "boot", "main starts in the boot state")
	root.add_child(_main)
	await _frames(6)
	_check(_main.state == "title", "boot ends on the title")
	_check(_main.ui.current_screen() == "title" and _main.ui.visible, "the title screen is open")
	_check(not _main.hud.visible, "the in-game HUD is hidden on the title (its old menus never show)")
	_check(_main.level != null and _main.level.get("level_id") == "l01" and _main.practice, "the title sits over Sluice Gate in practice mode")
	_check(get_nodes_in_group("enemies").is_empty(), "the title backdrop has no enemies")
	_check(_main._attract.current, "the attract camera is the active camera")
	_check(Input.mouse_mode != Input.MOUSE_MODE_CAPTURED, "the mouse is free on the title")
	_check(_main.profile.path == PATH, "--profile selects the profile file")
	var before: Vector3 = _main._attract.global_position
	await _frames(90)
	_check(_main._attract.global_position.distance_to(before) > 0.02, "the attract camera drifts")
	# A level that does not exist is refused and the title stays.
	await _main.start_level("l09")
	_check(_main.state == "title", "an unavailable level (l09, v1.1) leaves the title alone")
	await _main.start_level("bogus")
	_check(_main.state == "title", "an unknown level leaves the title alone")
	# Opening a sub screen moves the state to menu, and back again.
	_main.ui.show_workshop()
	await _frames(4)
	_check(_main.state == "menu", "a sub screen counts as the menu state")
	_main.ui.back()
	await _frames(4)
	_check(_main.state == "title", "back from a sub screen returns to the title state")


func _test_practice_and_pause() -> void:
	var states: Array[String] = []
	_main.state_changed.connect(func(next: String) -> void: states.append(next))
	var starting: Signal = _main.level_started
	_main.start_level("l01", true)
	await _frames(2)
	_check(_main.state == "loading" and _main.ui.current_screen() == "loading", "starting a level shows the loading screen first")
	await starting
	await _frames(2)
	_check(_main.state == "playing" and not _main.ui.is_open(), "play begins with every menu closed")
	_check(states.size() >= 2 and states[0] == "loading" and states[1] == "playing", "states go loading then playing")
	_check(_main.practice and _main.level.get("practice") and get_nodes_in_group("enemies").is_empty(), "a forced practice run has no enemies")
	_check(_main.hud.visible and _main.player.active and _main.tether.active, "HUD, player and tether are live")
	_check(_main.player.camera.current, "the player camera takes over")
	if DisplayServer.get_name() != "headless":
		_check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "the mouse is captured while playing")
	_check(_main.player.global_position.distance_to(_main.level.get("spawn_position")) < 1.0, "the player starts at the level spawn")
	var start_time: float = _main.elapsed
	await _frames(45)
	_check(_main.elapsed > start_time + 0.4, "the raid clock runs while playing")
	# Pause with the action, then resume from the pause menu.
	_main._action("pause", true)
	await _frames(3)
	_check(_main.state == "paused" and paused and _main.ui.current_screen() == "pause", "pause freezes the tree and opens the pause menu")
	_check(not _main.hud.visible, "the HUD hides while paused (so touches reach the menu)")
	_check(Input.mouse_mode != Input.MOUSE_MODE_CAPTURED, "the mouse is free while paused")
	var frozen: float = _main.elapsed
	await _frames(20)
	_check(is_equal_approx(_main.elapsed, frozen), "the clock stops while paused")
	_main.ui.resume_requested.emit()
	await _frames(3)
	_check(_main.state == "playing" and not paused and not _main.ui.is_open() and _main.hud.visible, "resume returns to play")
	# Esc pauses and Esc inside the pause menu resumes.
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	await _frames(4)
	_check(_main.state == "paused", "Esc pauses")
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	await _frames(4)
	_check(_main.state == "playing", "Esc inside the pause menu resumes")
	# Android back and focus loss pause too.
	_main.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(4)
	_check(_main.state == "paused" and _main.ui.is_open(), "the Android back button pauses (and the menu stays open)")
	_main.ui.resume_requested.emit()
	await _frames(3)
	_main.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _frames(3)
	_check(_main.state == "paused", "losing focus pauses")
	# Restart from the pause menu.
	var restarted: Signal = _main.level_started
	_main.ui.restart_requested.emit()
	await restarted
	await _frames(2)
	_check(_main.state == "playing" and _main.practice and not paused, "restart rebuilds the level and plays (practice is kept)")
	# Quit to the title from the pause menu.
	_main._action("pause", true)
	await _frames(3)
	_main.ui.menu_requested.emit()
	await _frames(6)
	_check(_main.state == "title" and not paused and _main.ui.current_screen() == "title", "quit to title unpauses and shows the title")
	_check(not _main.player.active and not _main.hud.visible, "the title has no live player or HUD")


func _test_raid_to_result() -> void:
	var started: Signal = _main.level_started
	_main.ui.level_requested.emit("l01")
	await started
	await _frames(2)
	_check(_main.state == "playing" and not _main.practice, "a campaign level starts as a real raid")
	_check(get_nodes_in_group("enemies").size() == 5, "the raid has its five enemies")
	_check(_main.run_stats["casts"] == 0 and _main.elapsed < 0.2, "run counters start from zero")
	# Cast once so the cast counter and the sound/hint path run.
	_main._action("cast", true)
	await _frames(10)
	_main._action("cast", false)
	await _frames(10)
	_check(int(_main.run_stats["casts"]) == 1, "a cast is counted")
	_check(_main.profile.has_achievement("FIRST_CAST"), "the first cast unlocks Gone Fishing live")
	_check(_main._expand("charge {cast}") == "charge " + str(InputSetup.glyph("cast", "kbm")) and not str(_main._expand("{reload}")).contains("{"), "hint tokens expand to the device glyphs")
	_main._action("cut", true)
	# Clear the enemies so the teleport run is not interrupted, and count the kills.
	for node: Node in get_nodes_in_group("enemies"):
		node.call("take_damage", 9999.0, "smash")
	await _frames(4)
	_check(int(_main.run_stats["kills"]) == 5 and int(_main.run_stats["smash_kills"]) == 5, "enemy kills are counted")
	# A fall below the kill plane cuts the line, costs 35 and returns to the last safe ground; the run goes on.
	var checkpoint: Vector3 = _main._checkpoint
	var hurt_before: float = float(_main.run_stats["damage_taken"])
	var hp_before: float = _main.player.health
	_main.player.reset_at(checkpoint + Vector3(0, -60, 0))
	await _frames(6)
	_check(_main.state == "playing", "a fall does not end the raid")
	_check(_main.player.global_position.distance_to(checkpoint) < 3.0, "a fall returns the player to the last safe ground")
	_check(is_equal_approx(_main.player.health, hp_before - MainScript.FALL_DAMAGE), "a fall costs 35 condition")
	_check(is_equal_approx(float(_main.run_stats["damage_taken"]), hurt_before + MainScript.FALL_DAMAGE), "the fall counts as damage taken")
	_check(not _main.player.freeze and _main.player.active, "the player keeps control after a fall")
	var objectives: Array = _main.level.get_objectives()
	var pickups: int = 0
	for entry: Dictionary in objectives:
		if entry["kind"] == "extract":
			continue
		pickups += 1
		_main.player.reset_at(entry["position"] as Vector3)
		await _frames(6)
	_check(pickups == 5, "l01 has five pickups (3 cases, 2 bonus caches)")
	_check(int(_main.level.get("collected_loot")) == 3 and (_main.level.get("collected_bonus") as Array).size() == 2, "all cases and bonus caches were collected")
	# Standing on the pad before all cases are in does nothing; now every case is in.
	var pad: Vector3 = _main.level.get("extraction_position")
	_main.player.reset_at(pad + Vector3(0, 0.95, 0))
	await _frames(45)
	_check(_main.extraction_inside and _main.state == "playing" and _main.extraction_time > 0.3, "extraction starts counting on the pad")
	await _frames(int(MainScript.EXTRACTION_SECONDS * 90.0) + 20)
	_check(_main.state == "result", "holding the pad for six seconds ends the raid")
	_check(_main.ui.current_screen() == "result" and _main.ui.visible, "the result screen opens")
	_check(not _main.hud.visible and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED, "the HUD hides and the mouse frees on the result")
	var result: Dictionary = _main.last_result
	_check(result["won"] and result["level_id"] == "l01" and result["title"] == "SLUICE GATE", "the result names the level")
	_check(result["cases"] == 3 and result["total_cases"] == 3 and result["bonus"] == 2 and result["total_bonus"] == 2, "the result counts cases and bonus caches")
	_check(result["time"] > 6.0 and result["time"] < 40.0, "the result time is the raid time")
	_check(result["medal"] == 3, "a fast raid earns gold")
	_check(result["salvage"] == 3 * 15 + 2 * 30 + 10 + 25 + 50, "salvage = cases + bonus caches + the three first-time medal bonuses")
	_check(result["bank"] == result["salvage"] and _main.profile.bank == result["salvage"], "the bank holds the reward")
	_check(result["new_best"] and result["best_time"] == result["time"], "the first clear is a new best")
	_check(result["next_level"] == "l02", "the result offers the next campaign level")
	# The fall above cost condition, so Untouched is lost; Ghost (no sidearm shots) still awards.
	_check((result["achievements"] as Array).has("Ghost") and not (result["achievements"] as Array).has("Untouched"), "end-of-run achievements follow the run (the fall cost Untouched)")
	_check((result["achievements"] as Array).has("Bring Something Back"), "the first extraction unlocks Bring Something Back")
	_check(not _main.profile.unlock_achievement("FIRST_EXTRACT"), "FIRST_EXTRACT unlocks only once")
	_check(int(result["stats"]["kills"]) == 5 and int(result["stats"]["casts"]) == 1, "the result carries the run stats")
	_check(_main.player.freeze, "physics freezes in the result view")
	var record: Dictionary = _main.profile.level_record("l01")
	_check(record["completed"] and record["medal"] == 3 and record["attempts"] == 1 and record["extractions"] == 1, "the profile records the clear")
	# The reward was saved straight away.
	var reloaded: RefCounted = ProfileScript.new()
	reloaded.load_profile(PATH)
	_check(reloaded.bank == result["salvage"] and bool(reloaded.level_record("l01")["completed"]), "the reward and clear are on disk")
	_check(reloaded.has_achievement("FIRST_EXTRACT") and reloaded.has_achievement("GOLD_ANY"), "the achievements are on disk")
	# Playing the level again pays cases and bonus caches again, but no medal bonuses.
	var bank_before: int = _main.profile.bank
	var again: Signal = _main.level_started
	_main.ui.restart_requested.emit()
	await again
	await _frames(2)
	_check(_main.state == "playing" and not _main.practice and _main.profile.bank == bank_before, "replay starts a new raid without changing the bank")


func _test_failed_run_and_retry() -> void:
	var bank_before: int = _main.profile.bank
	_main.player.take_damage(1000.0)
	await _frames(4)
	_check(_main.state == "result", "dying ends the raid")
	var result: Dictionary = _main.last_result
	_check(not result["won"] and result["salvage"] == 0 and result["breakdown"].is_empty(), "a failed raid pays nothing")
	_check(CAUSES.has(str(result["cause"])), "a failed raid names a cause (%s)" % result["cause"])
	_check(_main.profile.bank == bank_before and _main.profile.bank == result["bank"], "the bank is untouched by a failure")
	_check(_main.profile.level_record("l01")["attempts"] == 2 and int(_main.profile.stats["deaths"]) == 1, "the failure counts an attempt and a death")
	_check(float(result["stats"]["damage_taken"]) > 0.0, "damage taken is counted")
	_check(_main.ui.current_screen() == "result", "the failed result screen is open")
	var retry: Signal = _main.level_started
	_main.ui.restart_requested.emit()
	await retry
	await _frames(2)
	_check(_main.state == "playing" and _main.player.health == 100.0 and _main.elapsed < 0.2, "retry starts a fresh raid at full health")
	_check(int(_main.level.get("collected_loot")) == 0 and float(_main.run_stats["damage_taken"]) == 0.0, "retry resets the pickups and the counters")
	_check(get_nodes_in_group("enemies").size() == 5, "retry brings the enemies back")
	# Sidearm: weapon switch, a shot and the magazine.
	_main._action("weapon", true)
	_main._action("cast", true)
	await _frames(4)
	_check(_main.weapon == "SIDEARM" and _main.ammo == _main.magazine_size() - 1 and _main.magazine_size() == 10 and int(_main.run_stats["shots"]) == 1, "the sidearm fires and counts the shot")
	_main._action("weapon", true)
	# Leave to the title from the result of this run via the menu signal.
	_main._action("pause", true)
	await _frames(3)
	_main.ui.menu_requested.emit()
	await _frames(6)
	_check(_main.state == "title" and _main.profile.level_record("l01")["attempts"] == 2, "leaving mid-raid records nothing")


func _test_menus_and_settings() -> void:
	var profile: RefCounted = _main.profile
	# Workshop purchases.
	profile.bank = 80
	_main.ui.upgrade_requested.emit("spool")
	await _frames(2)
	_check(profile.upgrade_tier("spool") == 1 and profile.bank == 50, "buying an upgrade spends the bank")
	_main.ui.upgrade_requested.emit("spool")
	await _frames(2)
	_check(profile.upgrade_tier("spool") == 1 and profile.bank == 50, "an unaffordable upgrade changes nothing")
	var reloaded: RefCounted = ProfileScript.new()
	reloaded.load_profile(PATH)
	_check(reloaded.upgrade_tier("spool") == 1 and reloaded.bank == 50, "a purchase is saved immediately")
	# Settings apply live and save after a short delay.
	_main.ui.setting_changed.emit("invert_y", true)
	_main.ui.setting_changed.emit("look_sensitivity", 2.0)
	_main.ui.setting_changed.emit("fov", 70.0)
	_check(profile.setting("fov") == 70.0 and profile.setting("invert_y") == true, "settings reach the profile")
	var disk: RefCounted = ProfileScript.new()
	disk.load_profile(PATH)
	_check(disk.setting("fov") != 70.0, "settings are not written on every change (debounced)")
	await _seconds(MainScript.SAVE_DELAY_SECONDS + 0.4)
	disk = ProfileScript.new()
	disk.load_profile(PATH)
	_check(disk.setting("fov") == 70.0 and disk.setting("invert_y") == true, "settings are saved after the delay")
	var started: Signal = _main.level_started
	_main.start_level("l01", true)
	await started
	await _frames(2)
	_check(is_equal_approx(_main.player.camera.fov, 70.0), "the saved FOV applies to the player camera")
	_check(is_equal_approx(_main.player.look_sensitivity, MainScript.BASE_LOOK_SENSITIVITY * 2.0), "look sensitivity applies")
	var yaw: float = _main.player.yaw
	var pitch: float = _main.player.pitch
	_main._look(Vector2(10, 10))
	_check(_main.player.yaw < yaw and _main.player.pitch > pitch, "invert Y flips the vertical look")
	_main.ui.setting_changed.emit("fov", 90.0)
	_main.ui.setting_changed.emit("difficulty", 2)
	_check(is_equal_approx(_main.player.camera.fov, 90.0), "FOV changes apply while playing")
	_check(is_equal_approx(float(_main.level.get("damage_scale")), 1.0), "difficulty applies to the next run, not the current one")
	# Reset progress keeps the settings.
	_main.ui.reset_progress_requested.emit()
	await _frames(2)
	_check(profile.bank == 0 and profile.upgrade_tier("spool") == 0 and profile.level_record("l01")["attempts"] == 0, "reset progress wipes the progress")
	_check(profile.setting("fov") == 90.0, "reset progress keeps the settings")
	# The next raid loads the magazine of the bought sidearm tier (stock 10, tier 1 = 12).
	profile.bank = 40
	_main.ui.upgrade_requested.emit("sidearm")
	await _frames(2)
	_check(profile.upgrade_tier("sidearm") == 1, "the sidearm upgrade is bought after the reset")
	# A raid reads the new difficulty.
	var raid: Signal = _main.level_started
	_main.start_level("l01")
	await raid
	_check(is_equal_approx(float(_main.level.get("damage_scale")), 1.5), "hard difficulty sets the level damage scale")
	_check(_main.magazine_size() == 12 and _main.ammo == 12, "the next raid loads the upgraded sidearm magazine (12)")
	_main.ui.setting_changed.emit("difficulty", 1)
	_main._action("pause", true)
	await _frames(3)
	_main.ui.menu_requested.emit()
	await _frames(6)


## Last step: quit_requested ends the tree, so the test's own quit() call must come after it.
func _test_quit_saves() -> void:
	_main.ui.setting_changed.emit("camera_shake", 0.25)
	var disk: RefCounted = ProfileScript.new()
	disk.load_profile(PATH_B)
	_check(disk.setting("camera_shake") != 0.25, "the setting is still waiting to be saved")
	_main.ui.quit_requested.emit()
	disk = ProfileScript.new()
	disk.load_profile(PATH_B)
	_check(disk.setting("camera_shake") == 0.25, "quitting saves pending changes")


func _test_arguments() -> void:
	_main.queue_free()
	await _frames(3)
	# --level + --cam + --hide-ui + --unlock-all skip the title and freeze the camera for shots.
	_main = MainScript.new()
	_main.override_args = PackedStringArray(["--profile=" + PATH, "--windowed", "--level=l01", "--cam=3,6,10,90,-20", "--hide-ui", "--unlock-all"])
	root.add_child(_main)
	await _main.level_started
	await _frames(6)
	_check(_main.state == "playing" and _main.level_id == "l01", "--level starts that level without the title")
	_check(_main.player.global_position.distance_to(Vector3(3, 6, 10)) < 0.3, "--cam places the player")
	_check(is_equal_approx(_main.player.yaw, deg_to_rad(90.0)) and is_equal_approx(_main.player.pitch, deg_to_rad(-20.0)), "--cam sets the view angles")
	_check(not _main.hud.visible and not _main.ui.visible, "--hide-ui hides the HUD and the menus")
	_check(_main.profile.is_unlocked("l05") and not FileAccess.get_file_as_string(PATH).contains("l05"), "--unlock-all unlocks levels without saving them")
	_main.queue_free()
	await _frames(3)
	# --screen opens a screen; a profile with a gold medal catches up on boot.
	var seeded: RefCounted = ProfileScript.new()
	seeded.load_profile(PATH_B)
	seeded.levels["l01"] = {"completed": true, "best_time": 80.0, "medal": 3, "bonus_found": [], "attempts": 1, "extractions": 1}
	seeded.tutorial_done = true
	seeded.save_profile()
	_main = MainScript.new()
	_main.override_args = PackedStringArray(["--profile=" + PATH_B, "--windowed", "--screen=settings"])
	root.add_child(_main)
	await _frames(8)
	_check(_main.state == "menu" or _main.state == "title", "--screen keeps the title world")
	_check(_main.ui.current_screen() == "settings", "--screen=settings opens the settings screen")
	_check(_main.profile.has_achievement("GOLD_ANY"), "boot awards achievements implied by saved progress")
	await _seconds(MainScript.SAVE_DELAY_SECONDS + 0.4)
	var disk: RefCounted = ProfileScript.new()
	disk.load_profile(PATH_B)
	_check(disk.has_achievement("GOLD_ANY"), "the caught-up achievement is saved")


# --- Helpers -----------------------------------------------------------------------------------

func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _wipe(path: String) -> void:
	for suffix: String in ["", ".bak", ".tmp", ".corrupt"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)


func _frames(count: int) -> void:
	for i in range(count):
		await process_frame


func _seconds(duration: float) -> void:
	await _frames(int(ceil(duration * 90.0)))


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		print("  FAIL: ", message)
