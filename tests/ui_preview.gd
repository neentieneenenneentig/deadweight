extends SceneTree
## Captures every menu screen over a 3D backdrop with a fake mixed-progress profile.
## Run windowed but off-screen, once per resolution:
##   godot --path . --position 20000,20000 --resolution 1280x720 --script res://tests/ui_preview.gd
## Options after "--": --tag=<text> (file name suffix), --out=<folder>, --touch (touch UI),
## --only=<screen,...> (title_fresh title pause loading result_won result_lost levels workshop
## records settings credits). Add --rendering-method gl_compatibility for the mobile renderer.
## The profile is private to this script: nothing is read from or written to the real save.

const Catalog = preload("res://scripts/level_catalog.gd")
const Profile = preload("res://scripts/profile.gd")
const UiRoot = preload("res://scripts/ui/ui_root.gd")
const SETTLE_FRAMES := 26

var _tag: String = ""
var _out: String = "res://.tools/captures/F3"
var _only: Array[String] = []
var _ui: CanvasLayer
var _progress: RefCounted
var _fresh: RefCounted


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--tag="):
			_tag = argument.substr(6)
		elif argument.begins_with("--out="):
			_out = argument.substr(6)
		elif argument.begins_with("--only="):
			for part: String in argument.substr(7).split(","):
				_only.append(part)
	_run.call_deferred()


func _run() -> void:
	_build_backdrop()
	_progress = _make_profile(true)
	_fresh = _make_profile(false)
	_ui = UiRoot.new()
	root.add_child(_ui)
	await _frames(4)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var size: Vector2 = root.get_visible_rect().size
	var suffix: String = "%dx%d%s" % [int(size.x), int(size.y), ("_" + _tag) if not _tag.is_empty() else ""]
	var failures: int = 0
	_ui.call("bind", _fresh)
	failures += await _shot("title_fresh", suffix, func() -> void: _ui.call("show_title"))
	_ui.call("bind", _progress)
	failures += await _shot("title", suffix, func() -> void: _ui.call("show_title"))
	failures += await _shot("loading", suffix, func() -> void: _ui.call("show_loading", "Sluice Gate", "FLOODWORKS  /  RAID 01"))
	failures += await _shot("pause", suffix, func() -> void: _ui.call("show_pause", "Sluice Gate"))
	failures += await _shot("result_won", suffix, func() -> void: _ui.call("show_result", _won_result()))
	failures += await _shot("result_lost", suffix, func() -> void: _ui.call("show_result", _lost_result()))
	failures += await _shot("levels", suffix, func() -> void: _ui.call("show_level_select"))
	failures += await _shot("workshop", suffix, func() -> void: _ui.call("show_workshop"))
	failures += await _shot("records", suffix, func() -> void: _ui.call("show_records"))
	failures += await _shot("settings", suffix, func() -> void: _ui.call("show_settings"))
	failures += await _shot("credits", suffix, func() -> void: _ui.call("show_credits"))
	print("UI PREVIEW %s: %d problem(s)" % [suffix, failures])
	quit(1 if failures > 0 else 0)


## Shows one screen, waits for its animation, reports the focused control and saves a PNG.
func _shot(screen_name: String, suffix: String, show: Callable) -> int:
	if not _only.is_empty() and not _only.has(screen_name):
		return 0
	_ui.call("hide_all")
	await _frames(2)
	show.call()
	await _frames(SETTLE_FRAMES)
	var problems: int = 0
	var focus: Control = root.gui_get_focus_owner()
	var focus_text: String = "none"
	if focus != null:
		focus_text = "%s \"%s\"" % [focus.get_class(), str(focus.get("text"))]
	elif screen_name == "loading":
		focus_text = "none (loading takes no input)"
	else:
		problems += 1
		push_error("UI PREVIEW: %s opened without a focused control" % screen_name)
	var image: Image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("%s/%s_%s.png" % [_out, screen_name, suffix]))
	print("  %-12s focus: %s" % [screen_name, focus_text])
	return problems


func _build_backdrop() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var dummy := Node3D.new()
	scene.add_child(dummy)
	var level: Node3D = Catalog.create("l01")
	scene.add_child(level)
	level.call("build", dummy, true)
	var camera := Camera3D.new()
	camera.fov = 70.0
	camera.far = 400.0
	scene.add_child(camera)
	camera.make_current()
	camera.global_position = Vector3(4, 4.5, 2)
	camera.look_at(Vector3(6, 3.0, -60), Vector3.UP)


func _make_profile(with_progress: bool) -> RefCounted:
	var profile: RefCounted = Profile.new()
	profile.path = "user://ui_preview_unused.cfg"
	if not with_progress:
		return profile
	profile.bank = 245
	profile.lifetime_salvage = 610
	profile.tutorial_done = true
	profile.levels["l01"] = {"completed": true, "best_time": 118.4, "medal": 2, "bonus_found": [0], "attempts": 5, "extractions": 3}
	profile.upgrades["spool"] = 2
	profile.upgrades["reel"] = 1
	profile.achievements["FIRST_CAST"] = true
	profile.achievements["FIRST_ANCHOR"] = true
	profile.achievements["FIRST_EXTRACT"] = true
	profile.stats["play_time"] = 5230.0
	profile.stats["casts"] = 412
	profile.stats["max_speed"] = 38.5
	return profile


func _won_result() -> Dictionary:
	return {
		"won": true, "level_id": "l01", "title": "Sluice Gate", "time": 92.37, "cases": 3, "total_cases": 3,
		"bonus": 1, "total_bonus": 2, "salvage": 160,
		"breakdown": [["CASES x3", 45], ["BONUS CACHES x1", 30], ["FIRST GOLD MEDAL", 50], ["FIRST SILVER MEDAL", 25], ["FIRST BRONZE MEDAL", 10]],
		"medal": 3, "previous_medal": 2, "best_time": 92.37, "new_best": true, "par_silver": 150.0, "par_gold": 95.0,
		"bank": 405, "next_level": "l02",
		"achievements": ["Gold Standard", "Untouched", "Ghost", "Hang Time"],
		"cause": "", "stats": {"max_speed": 36.2, "max_airtime": 9.4, "casts": 31, "kills": 4, "damage_taken": 0.0},
	}


func _lost_result() -> Dictionary:
	return {
		"won": false, "level_id": "l01", "title": "Sluice Gate", "time": 64.8, "cases": 1, "total_cases": 3,
		"bonus": 0, "total_bonus": 2, "salvage": 0, "breakdown": [], "medal": 0, "previous_medal": 2,
		"best_time": 118.4, "new_best": false, "par_silver": 150.0, "par_gold": 95.0, "bank": 245, "next_level": "",
		"achievements": [], "cause": "sentry", "stats": {"max_speed": 24.0, "max_airtime": 3.2, "casts": 9, "kills": 0, "damage_taken": 100.0},
	}


func _frames(count: int) -> void:
	for i in range(count):
		await process_frame
