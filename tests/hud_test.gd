extends SceneTree
## Exercise routed touch events, lifecycle release, and scaled layout bounds.

var _hud: CanvasLayer
var _failures := 0
var _actions: Array[String] = []
var _looks: Array[Vector2] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("HUD TEST: " + message)


func _record_action(action: String, pressed: bool) -> void:
	_actions.append(action + (":down" if pressed else ":up"))


func _record_look(delta: Vector2) -> void:
	_looks.append(delta)


func _touch(index: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	root.push_input(event, true)


func _drag(index: int, position: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = position
	event.relative = relative
	root.push_input(event, true)


func _pad_center(action: String) -> Vector2:
	var pad: Control = _hud._touch_pads[action]
	return pad.global_position + pad.size * 0.5


func _run() -> void:
	Input.emulate_mouse_from_touch = false
	Input.use_accumulated_input = false
	_hud = load("res://scripts/hud.gd").new()
	root.add_child(_hud)
	_hud.touch_enabled = true
	_hud.action_requested.connect(_record_action)
	_hud.look_requested.connect(_record_look)
	await process_frame
	_hud._reflow()
	_hud.show_game()

	var stick: Control = _hud._stick
	var move_position: Vector2 = stick.global_position + stick.size * 0.5 + Vector2(42, -15)
	var cast_position: Vector2 = _pad_center("cast")
	_touch(0, move_position, true)
	_touch(1, cast_position, true)
	await process_frame
	_expect(_hud.move_vector.x > 0.4, "left thumb moves while right thumb charges")
	_expect(_actions.count("cast:down") == 1, "cast begins once")
	_drag(1, cast_position + Vector2(-16, -12), Vector2(-16, -12))
	await process_frame
	_expect(_looks.size() == 1 and _looks[0] == Vector2(-16, -12), "held cast still allows aiming")
	_touch(1, cast_position + Vector2(-16, -12), false)
	await process_frame
	_expect(_actions.count("cast:up") == 1, "cast releases once")
	_expect(_hud.move_vector.x > 0.4, "releasing cast preserves other finger movement")

	var reel_position: Vector2 = _pad_center("reel")
	_touch(1, reel_position, true)
	_drag(1, reel_position + Vector2(20, 6), Vector2(20, 6))
	await process_frame
	_expect(_actions.count("reel:down") == 1, "reused finger starts reeling")
	_expect(_looks.size() == 2 and _looks[1] == Vector2(20, 6), "held reel still allows aiming")
	_hud.show_pause()
	_expect(_actions.count("reel:up") == 1, "opening pause releases a held reel")
	_expect(_hud.move_vector == Vector2.ZERO, "pause clears movement")
	_expect(_hud._touch_roles.is_empty(), "pause clears all touch owners")
	_touch(0, move_position, false)
	_touch(1, reel_position, false)
	await process_frame
	_expect(_actions.count("reel:up") == 1, "late touch releases do not duplicate release actions")

	_hud.show_game()
	_touch(1, _pad_center("cast"), true)
	await process_frame
	_hud.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect(_actions.count("cast:up") == 2, "focus loss releases charged cast")
	_expect(_hud._touch_roles.is_empty(), "focus loss clears touch owners")
	_touch(1, _pad_center("cut"), true)
	_touch(1, _pad_center("cut"), false)
	await process_frame
	_expect(_actions.count("cut:down") == 1 and _actions.count("cut:up") == 1, "finger reuse works after focus release")

	_hud.update_state({"health": 32.0, "tension": 14000.0, "weapon": "SIDEARM", "ammo": 6, "reserve": 24, "extraction_inside": true, "loot": 3, "extraction": 0.5})
	_expect(_hud._extract_bar.visible and is_equal_approx(_hud._extract_bar.value, 0.5), "extraction progress appears with sufficient salvage")
	_expect(is_equal_approx(_hud._tension_bar.value, 0.56), "tension uses 25 kN gauge range")
	_expect(_hud._touch_pads["cast"].caption == "FIRE", "sidearm has a clear fire action")
	_hud.show_result(true, 3, 65.0, 6)
	_expect(_hud._result_title.text == "EXTRACTED", "successful extraction has a result screen")
	_hud.show_result(false, 2, 125.0, 6)
	_expect(_hud._result_title.text == "SIGNAL LOST", "death has a distinct result screen")

	for dimensions in [Vector2i(1280, 720), Vector2i(800, 450), Vector2i(960, 720), Vector2i(2400, 1080)]:
		root.size = dimensions
		await process_frame
		_hud._reflow()
		_hud.show_menu()
		await process_frame
		var logical_size: Vector2 = root.get_visible_rect().size
		var menu_rect: Rect2 = _hud._menu_right.get_rect()
		_expect(menu_rect.end.x <= logical_size.x + 1.0 and menu_rect.end.y <= logical_size.y + 1.0, "briefing stays visible at " + str(dimensions))
		_hud.show_game()
		for action in _hud._touch_pads:
			var rect: Rect2 = _hud._touch_pads[action].get_rect()
			_expect(rect.position.x >= 0 and rect.position.y >= 0 and rect.end.x <= logical_size.x and rect.end.y <= logical_size.y, action + " touch control stays visible at " + str(dimensions))
		print("HUD layout: physical ", dimensions, " / canvas ", logical_size)

	_hud.queue_free()
	await process_frame
	if _failures == 0:
		print("HUD TESTS PASSED: two-thumb aim, finger reuse, focus/pause release, state and four viewport sizes")
	else:
		push_error("HUD TESTS FAILED: %d checks" % _failures)
	quit(0 if _failures == 0 else 1)
