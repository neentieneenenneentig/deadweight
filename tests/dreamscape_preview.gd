extends SceneTree
## Off-screen, real-level captures. Never loads or writes the player's profile.
const Catalog = preload("res://scripts/level_catalog.gd")
const Player = preload("res://scripts/player.gd")
const Enemy = preload("res://scripts/enemy.gd")
const HUD = preload("res://scripts/hud.gd")
var _out: String = "res://.tools/captures/dreamscape"
var _quality: int = 2

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out = argument.substr(6)
		elif argument.begins_with("--quality="):
			_quality = clampi(argument.substr(10).to_int(), 0, 2)
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	for id: String in ["l01", "range"]:
		var stage := Node3D.new()
		root.add_child(stage)
		var player := Player.new()
		stage.add_child(player)
		player.freeze = true
		var level: Node3D = Catalog.create(id)
		stage.add_child(level)
		level.set("quality", _quality)
		level.call("build", player, true)
		player.position = level.get("spawn_position")
		player.camera.far = 1000.0
		player.camera.make_current()
		for i in range(30):
			await process_frame
		await RenderingServer.frame_post_draw
		_capture(id + "_spawn")
		if id == "l01":
			var hud := HUD.new()
			stage.add_child(hud)
			hud.set_camera(player.camera)
			hud.set_objectives(level.call("get_objectives"))
			hud.set_active(true)
			hud.update_state({"health": 100.0, "speed": 0.0, "weapon": "ROD", "reel_state": "READY TO CAST", "loot": 0, "total_loot": 3, "bonus": 0, "total_bonus": 2, "time": 0.0, "par_gold": 95.0, "par_silver": 150.0, "hint": "CAST ABOVE THE GATE"})
			for i in range(8):
				await process_frame
			await RenderingServer.frame_post_draw
			_capture("gameplay_hud")
			hud.queue_free()
			player.set_process(false)
			player.rod_model.hide()
			player.gun_model.hide()
			var overlook := Camera3D.new()
			stage.add_child(overlook)
			overlook.far = 1000.0
			overlook.global_position = Vector3(19, 18, 19)
			overlook.look_at(Vector3(-3, 16, -55))
			overlook.make_current()
			for i in range(8):
				await process_frame
			await RenderingServer.frame_post_draw
			_capture("l01_overlook")
			overlook.global_position = Vector3(-12.6, 4.1, -14.5)
			overlook.look_at(Vector3(-15, 2.95, -18))
			for i in range(8):
				await process_frame
			await RenderingServer.frame_post_draw
			_capture("sky_case")
			var kinds: Array[String] = ["hound", "sentry", "drone"]
			for i in range(3):
				var inhabitant := Enemy.new()
				stage.add_child(inhabitant)
				inhabitant.setup(player, kinds[i], Vector3(float(i - 1) * 2.6, 1.5 if i == 2 else 0, 11))
				inhabitant.rotation.y = PI - 0.35
			overlook.global_position = Vector3(3, 3.2, 18)
			overlook.look_at(Vector3(0, 1.0, 11))
			for i in range(8):
				await process_frame
			await RenderingServer.frame_post_draw
			_capture("inhabitants")
		stage.queue_free()
		await process_frame
	quit()

func _capture(shot: String) -> void:
	var path: String = "%s/%s_%s.png" % [_out, shot, RenderingServer.get_current_rendering_method()]
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("CAPTURE " + path)
