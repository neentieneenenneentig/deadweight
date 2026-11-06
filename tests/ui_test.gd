extends SceneTree
## F6 UI test suite (headless). Checks that every screen opens with a focused control, that
## ui_cancel goes back, that buttons emit the right signals, that settings emit typed values, that
## workshop buttons show the right states, that locked levels never emit level_requested, that the
## layouts stay inside the viewport at five sizes, that title and settings buttons do not overlap,
## and that toasts never take focus.
## Uses a private profile path (user://test_f6.cfg). The suite never saves a profile, so the real
## save is not touched. Run: godot --headless --fixed-fps 90 --path . --script res://tests/ui_test.gd

const UiRootScript = preload("res://scripts/ui/ui_root.gd")
const ProfileScript = preload("res://scripts/profile.gd")
const SettingsScript = preload("res://scripts/ui/settings_screen.gd")

const PROFILE_PATH := "user://test_f6.cfg"
## Every view the suite opens. "result_lost" is the result screen after a failed raid.
const VIEWS := ["title", "levels", "workshop", "records", "settings", "credits", "pause", "result", "result_lost", "loading"]
const SUB_SCREENS := ["levels", "workshop", "records", "settings", "credits"]
## Viewport sizes for the layout checks, in canvas pixels.
const LAYOUT_SIZES := [Vector2i(1280, 720), Vector2i(1280, 800), Vector2i(960, 720), Vector2i(800, 450), Vector2i(2400, 1080)]
const EDGE_TOLERANCE := 0.5
## Two buttons may touch, but not overlap by more than this many pixels on both axes.
const OVERLAP_TOLERANCE := 1.0
const FOCUS_FRAMES := 3
const SETTLE_FRAMES := 30
## Expected BUY button of each track with the progress profile (bank 115): [disabled, text].
## Tiers: spool 2, reel 1, weight 4 (maxed), quickdraw 3 (120 needed), plating and sidearm 0.
const WORKSHOP_STATES := {
	"spool": [false, "BUY  85"],
	"reel": [false, "BUY  55"],
	"weight": [true, "MAXED"],
	"plating": [false, "BUY  30"],
	"quickdraw": [true, "NEED 5 MORE"],
	"sidearm": [false, "BUY  30"],
}

var _checks: int = 0
var _failures: int = 0
var _ui: UiRootScript
var _profile: ProfileScript
var _real_catalog: Variant
## Every ui_root signal emission in order: [signal name, argument array].
var _emitted: Array = []
## While true the suite stands in for main.gd: it spends salvage on upgrade_requested.
var _stand_in_main: bool = false


## Stand-in level catalog: l02 and l03 are built but locked on a fresh profile; tutorial is built.
class StubCatalog extends RefCounted:
	const ORDER := ["tutorial", "l01", "l02", "l03", "range"]
	const DATA := {
		"tutorial": {"available": true, "title": "INDUCTION", "number": 0, "blurb": "Training course with no hostiles."},
		"l01": {"available": true, "title": "SLUICE GATE", "zone": "floodworks", "number": 1, "blurb": "Canal yard.", "par_silver": 150.0, "par_gold": 95.0, "bonus": 2},
		"l02": {"available": true, "title": "PUMP ROW", "zone": "floodworks", "number": 2, "blurb": "Pumps and hounds.", "par_silver": 180.0, "par_gold": 120.0, "bonus": 2},
		"l03": {"available": true, "title": "OVERFLOW", "zone": "floodworks", "number": 3, "blurb": "The spillway.", "par_silver": 210.0, "par_gold": 140.0, "bonus": 1},
		"range": {"available": true, "title": "PRACTICE RANGE", "number": -1, "practice": true, "blurb": "Nothing here is saved."},
	}

	func all_ids() -> Array[String]:
		var ids: Array[String] = []
		for id: String in ORDER:
			ids.append(id)
		return ids

	func campaign_ids() -> Array[String]:
		return ["l01", "l02", "l03"]

	func info(id: String) -> Dictionary:
		var result: Dictionary = {"id": id, "script": ""}
		result.merge(DATA.get(id, {}), true)
		return result

	func next_id(_id: String) -> String:
		return ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _setup()
	await _test_focus_on_open()
	await _test_cancel_goes_back()
	await _test_back_buttons()
	await _test_title_buttons()
	await _test_pause_and_result_buttons()
	await _test_settings_types()
	await _test_workshop()
	await _test_level_locks()
	await _test_toasts()
	await _test_layouts()
	_teardown()
	print("ui_test: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


# --- Setup and helpers -------------------------------------------------------------------------

func _setup() -> void:
	# A stale temp profile from an earlier run goes first. The suite never saves one.
	if FileAccess.file_exists(PROFILE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_PATH))
	_ui = UiRootScript.new()
	root.add_child(_ui)
	_real_catalog = _ui.get("catalog")
	_watch_signals()
	_use_profile(_fresh_profile())
	await _frames(4)


func _teardown() -> void:
	root.remove_child(_ui)
	_ui.free()
	if FileAccess.file_exists(PROFILE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_PATH))


## Records every ui_root signal so the tests can count and read what was emitted.
func _watch_signals() -> void:
	_ui.level_requested.connect(func(id: String) -> void: _record_emit("level_requested", [id]))
	_ui.resume_requested.connect(func() -> void: _record_emit("resume_requested", []))
	_ui.restart_requested.connect(func() -> void: _record_emit("restart_requested", []))
	_ui.next_level_requested.connect(func() -> void: _record_emit("next_level_requested", []))
	_ui.menu_requested.connect(func() -> void: _record_emit("menu_requested", []))
	_ui.quit_requested.connect(func() -> void: _record_emit("quit_requested", []))
	_ui.reset_progress_requested.connect(func() -> void: _record_emit("reset_progress_requested", []))
	_ui.setting_changed.connect(func(key: String, value: Variant) -> void: _record_emit("setting_changed", [key, value]))
	_ui.upgrade_requested.connect(func(id: String) -> void:
		_record_emit("upgrade_requested", [id])
		# Stands in for main.gd: spend the salvage, then refresh the workshop.
		if _stand_in_main and _profile.purchase(id):
			_ui.refresh())


func _record_emit(signal_name: String, args: Array) -> void:
	_emitted.append([signal_name, args])


func _clear_emits() -> void:
	_emitted.clear()


func _count_emits(signal_name: String) -> int:
	var count: int = 0
	for entry: Array in _emitted:
		if entry[0] == signal_name:
			count += 1
	return count


func _last_args(signal_name: String) -> Array:
	for index in range(_emitted.size() - 1, -1, -1):
		var entry: Array = _emitted[index]
		if entry[0] == signal_name:
			return entry[1]
	return []


func _check(passed: bool, check_name: String) -> void:
	_checks += 1
	if passed:
		print("PASS " + check_name)
	else:
		_failures += 1
		print("FAIL " + check_name)


func _frames(count: int) -> void:
	for i in range(count):
		await process_frame


func _focus_owner() -> Control:
	return root.gui_get_focus_owner()


## A profile for the suite: no progress, nothing saved.
func _fresh_profile() -> ProfileScript:
	var profile: ProfileScript = ProfileScript.new()
	profile.path = PROFILE_PATH
	return profile


## A mixed-progress profile: l01 cleared, spool/reel/weight/quickdraw upgraded, 115 salvage banked.
func _progress_profile() -> ProfileScript:
	var profile: ProfileScript = _fresh_profile()
	profile.bank = 115
	profile.lifetime_salvage = 610
	profile.tutorial_done = true
	profile.levels["l01"] = {"completed": true, "best_time": 118.4, "medal": 2, "bonus_found": [0], "attempts": 5, "extractions": 3}
	profile.upgrades["spool"] = 2
	profile.upgrades["reel"] = 1
	profile.upgrades["weight"] = 4
	profile.upgrades["quickdraw"] = 3
	profile.achievements["FIRST_CAST"] = true
	profile.achievements["FIRST_EXTRACT"] = true
	profile.stats["play_time"] = 5230.0
	profile.stats["casts"] = 412
	profile.stats["kills"] = 37
	profile.stats["extractions"] = 4
	profile.stats["max_speed"] = 38.5
	profile.stats["max_airtime"] = 12.4
	return profile


func _use_profile(profile: ProfileScript) -> void:
	_profile = profile
	_ui.bind(profile)


## Shows a view the way the game does: root screens replace the stack, sub screens stack on title.
func _open(view: String) -> void:
	match view:
		"title":
			_ui.show_title()
		"levels":
			_ui.show_level_select()
		"workshop":
			_ui.show_workshop()
		"records":
			_ui.show_records()
		"settings":
			_ui.show_settings()
		"credits":
			_ui.show_credits()
		"pause":
			_ui.show_pause("Sluice Gate")
		"result":
			_ui.show_result(_won_result())
		"result_lost":
			_ui.show_result(_lost_result())
		"loading":
			_ui.show_loading("Sluice Gate", "FLOODWORKS  /  RAID 01")


func _screen_of(view: String) -> String:
	return "result" if view == "result_lost" else view


## Sends one InputEventAction press and release, the way a key or pad button would arrive.
func _press_action(action_name: String) -> void:
	var down := InputEventAction.new()
	down.action = action_name
	down.pressed = true
	Input.parse_input_event(down)
	await _frames(2)
	var up := InputEventAction.new()
	up.action = action_name
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(2)


## Finds the first Button under node with this text (or containing it when contains is true).
func _find_button(node: Node, text: String, contains: bool = false) -> Button:
	for child: Node in node.get_children():
		if child is Button:
			var button: Button = child
			if button.text == text or (contains and text in button.text):
				return button
		var found: Button = _find_button(child, text, contains)
		if found != null:
			return found
	return null


## Presses the button with this text on screen and lets the press settle. False when it is missing.
func _press(screen: Node, text: String) -> bool:
	var button: Button = _find_button(screen, text)
	if button == null:
		_check(false, "button '%s' is on screen" % text)
		return false
	button.pressed.emit()
	await _frames(2)
	return true


func _won_result() -> Dictionary:
	return {
		"won": true, "level_id": "l01", "title": "Sluice Gate", "time": 92.37, "cases": 3, "total_cases": 3,
		"bonus": 1, "total_bonus": 2, "salvage": 160,
		"breakdown": [["CASES x3", 45], ["BONUS CACHES x1", 30], ["FIRST GOLD MEDAL", 50]],
		"medal": 3, "previous_medal": 2, "best_time": 92.37, "new_best": true, "par_silver": 150.0, "par_gold": 95.0,
		"bank": 405, "next_level": "l02", "achievements": ["Gold Standard", "Untouched"],
		"cause": "", "stats": {"max_speed": 36.2, "max_airtime": 9.4, "casts": 31, "kills": 4, "damage_taken": 0.0},
	}


func _lost_result() -> Dictionary:
	return {
		"won": false, "level_id": "l01", "title": "Sluice Gate", "time": 64.8, "cases": 1, "total_cases": 3,
		"bonus": 0, "total_bonus": 2, "salvage": 0, "breakdown": [], "medal": 0, "previous_medal": 2,
		"best_time": 118.4, "new_best": false, "par_silver": 150.0, "par_gold": 95.0, "bank": 245, "next_level": "",
		"achievements": [], "cause": "sentry", "stats": {"max_speed": 24.0, "max_airtime": 3.2, "casts": 9, "kills": 0, "damage_taken": 100.0},
	}


# --- Focus ---------------------------------------------------------------------------------------

func _test_focus_on_open() -> void:
	_use_profile(_progress_profile())
	for view: String in VIEWS:
		_ui.hide_all()
		_open(view)
		await _frames(FOCUS_FRAMES)
		var owner: Control = _focus_owner()
		if view == "loading":
			# Loading takes no input, so it has nothing to focus. The check is that nothing grabs focus.
			_check(owner == null, "loading opens with no focus target (it takes no input)")
		else:
			var screen: Control = _ui.get_screen(_screen_of(view))
			_check(owner != null and screen.is_ancestor_of(owner), "%s opens with a focused control" % view)


# --- ui_cancel and BACK --------------------------------------------------------------------------

func _test_cancel_goes_back() -> void:
	_use_profile(_progress_profile())
	# Pause: ui_cancel resumes the raid.
	_ui.hide_all()
	_ui.show_pause("Sluice Gate")
	await _frames(FOCUS_FRAMES)
	_clear_emits()
	await _press_action("ui_cancel")
	_check(_count_emits("resume_requested") == 1, "pause: ui_cancel emits resume_requested")
	# Root screens that cannot be dismissed with ui_cancel.
	for view: String in ["title", "result", "loading"]:
		_ui.hide_all()
		_open(view)
		await _frames(FOCUS_FRAMES)
		await _press_action("ui_cancel")
		_check(_ui.current_screen() == _screen_of(view), "%s: ui_cancel keeps the screen" % view)
	# Sub screens return to the title.
	for view: String in SUB_SCREENS:
		_ui.hide_all()
		_ui.show_title()
		await _frames(FOCUS_FRAMES)
		_open(view)
		await _frames(FOCUS_FRAMES)
		await _press_action("ui_cancel")
		_check(_ui.current_screen() == "title", "%s: ui_cancel goes back to title" % view)
	# Nested: credits over settings over title goes back one step at a time.
	_ui.hide_all()
	_ui.show_settings()
	_ui.open_sub("credits")
	await _frames(FOCUS_FRAMES)
	await _press_action("ui_cancel")
	_check(_ui.current_screen() == "settings", "nested: ui_cancel from credits returns to settings")
	await _press_action("ui_cancel")
	_check(_ui.current_screen() == "title", "nested: second ui_cancel returns to title")
	# Quit to title asks first; ui_cancel closes the question and keeps the pause menu.
	_ui.hide_all()
	_ui.show_pause("Sluice Gate")
	await _frames(FOCUS_FRAMES)
	await _press(_ui.get_screen("pause"), "QUIT TO TITLE")
	_check(_ui.is_confirm_open(), "pause: QUIT TO TITLE asks for confirmation")
	await _press_action("ui_cancel")
	_check(not _ui.is_confirm_open() and _ui.current_screen() == "pause", "confirm: ui_cancel closes the dialog and keeps pause")


## The BACK button in each sub screen's footer goes back to the title.
func _test_back_buttons() -> void:
	for view: String in SUB_SCREENS:
		_ui.hide_all()
		_ui.show_title()
		await _frames(FOCUS_FRAMES)
		_open(view)
		await _frames(FOCUS_FRAMES)
		var back: Button = _find_button(_ui.get_screen(view), "BACK", true)
		_check(back != null, "%s has a BACK button" % view)
		if back == null:
			continue
		back.pressed.emit()
		await _frames(2)
		_check(_ui.current_screen() == "title", "%s: BACK button goes to title" % view)


# --- Buttons and the signals they emit -----------------------------------------------------------

func _test_title_buttons() -> void:
	_use_profile(_fresh_profile())
	var navigation: Array = [["WORKSHOP", "workshop"], ["RECORDS", "records"], ["SETTINGS", "settings"], ["CREDITS", "credits"], ["CAMPAIGN", "levels"]]
	for pair: Array in navigation:
		_ui.hide_all()
		_ui.show_title()
		await _frames(FOCUS_FRAMES)
		var button: Button = _find_button(_ui.get_screen("title"), pair[0])
		_check(button != null and not button.disabled, "title: %s button is there and enabled" % pair[0])
		if button == null:
			continue
		button.pressed.emit()
		await _frames(2)
		_check(_ui.current_screen() == pair[1], "title: %s opens %s" % [pair[0], pair[1]])
	# PRACTICE RANGE starts the range; QUIT asks ui_root to quit (desktop build).
	_ui.hide_all()
	_ui.show_title()
	await _frames(FOCUS_FRAMES)
	_clear_emits()
	await _press(_ui.get_screen("title"), "PRACTICE RANGE")
	_check(_last_args("level_requested") == ["range"], "title: PRACTICE RANGE emits level_requested(range)")
	_ui.hide_all()
	_ui.show_title()
	await _frames(FOCUS_FRAMES)
	var quit_button: Button = _find_button(_ui.get_screen("title"), "QUIT")
	_check(quit_button != null and quit_button.is_visible_in_tree(), "title: QUIT is shown on desktop")
	_clear_emits()
	await _press(_ui.get_screen("title"), "QUIT")
	_check(_count_emits("quit_requested") == 1, "title: QUIT emits quit_requested")
	# Callout: the tutorial is only offered when the catalog has it built (stand-in catalog here).
	_ui.set_sources(StubCatalog.new(), null, null)
	_use_profile(_fresh_profile())
	_ui.hide_all()
	_ui.show_title()
	await _frames(FOCUS_FRAMES)
	_clear_emits()
	await _press(_ui.get_screen("title"), "START INDUCTION")
	_check(_last_args("level_requested") == ["tutorial"], "title: START INDUCTION emits level_requested(tutorial)")
	_ui.set("catalog", _real_catalog)
	_ui.refresh()


func _test_pause_and_result_buttons() -> void:
	_use_profile(_progress_profile())
	_ui.hide_all()
	_ui.show_pause("Sluice Gate")
	await _frames(FOCUS_FRAMES)
	var pause: Control = _ui.get_screen("pause")
	_clear_emits()
	await _press(pause, "RESUME")
	_check(_count_emits("resume_requested") == 1, "pause: RESUME emits resume_requested")
	await _press(pause, "RESTART")
	_check(_count_emits("restart_requested") == 1, "pause: RESTART emits restart_requested")
	_ui.hide_all()
	_ui.show_pause("Sluice Gate")
	await _frames(FOCUS_FRAMES)
	await _press(_ui.get_screen("pause"), "SETTINGS")
	_check(_ui.current_screen() == "settings", "pause: SETTINGS opens settings over pause")
	_ui.hide_all()
	_ui.show_pause("Sluice Gate")
	await _frames(FOCUS_FRAMES)
	_clear_emits()
	await _press(_ui.get_screen("pause"), "QUIT TO TITLE")
	var confirm_yes: Button = _ui.get("_confirm_yes")
	_check(_ui.is_confirm_open() and _count_emits("menu_requested") == 0, "pause: QUIT TO TITLE waits for confirmation")
	confirm_yes.pressed.emit()
	await _frames(2)
	_check(_count_emits("menu_requested") == 1, "confirm: QUIT emits menu_requested once confirmed")

	# Won raid: NEXT RAID has the focus and emits next_level_requested.
	_ui.hide_all()
	_ui.show_result(_won_result())
	await _frames(FOCUS_FRAMES)
	var result: Control = _ui.get_screen("result")
	var next_button: Button = _find_button(result, "NEXT RAID")
	_check(next_button != null and _focus_owner() == next_button, "won result: NEXT RAID has the focus")
	_clear_emits()
	await _press(result, "NEXT RAID")
	_check(_count_emits("next_level_requested") == 1, "won result: NEXT RAID emits next_level_requested")
	_ui.hide_all()
	_ui.show_result(_won_result())
	await _frames(FOCUS_FRAMES)
	_clear_emits()
	await _press(_ui.get_screen("result"), "TITLE")
	_check(_count_emits("menu_requested") == 1, "result: TITLE emits menu_requested")
	_ui.hide_all()
	_ui.show_result(_won_result())
	await _frames(FOCUS_FRAMES)
	_clear_emits()
	await _press(_ui.get_screen("result"), "REPLAY")
	_check(_count_emits("restart_requested") == 1, "won result: REPLAY emits restart_requested")
	_ui.hide_all()
	_ui.show_result(_won_result())
	await _frames(FOCUS_FRAMES)
	await _press(_ui.get_screen("result"), "LEVELS")
	_check(_ui.current_screen() == "levels", "result: LEVELS opens level select")

	# Lost raid: no NEXT RAID, RETRY restarts.
	_ui.hide_all()
	_ui.show_result(_lost_result())
	await _frames(FOCUS_FRAMES)
	var next_hidden: Button = _find_button(_ui.get_screen("result"), "NEXT RAID")
	_check(next_hidden != null and not next_hidden.is_visible_in_tree(), "lost result: NEXT RAID is hidden")
	_clear_emits()
	await _press(_ui.get_screen("result"), "RETRY")
	_check(_count_emits("restart_requested") == 1, "lost result: RETRY emits restart_requested")

	# The last errand won: the ending, and CREDITS in place of NEXT RAID.
	_ui.hide_all()
	var ending: Dictionary = _won_result()
	ending["next_level"] = ""
	ending["campaign_end"] = true
	_ui.show_result(ending)
	await _frames(FOCUS_FRAMES)
	var final_screen: Control = _ui.get_screen("result")
	var credits_button: Button = _find_button(final_screen, "CREDITS")
	var hidden_next: Button = _find_button(final_screen, "NEXT RAID")
	_check(credits_button != null and credits_button.is_visible_in_tree() and _focus_owner() == credits_button and not hidden_next.is_visible_in_tree(), "ending result: CREDITS replaces NEXT RAID and has the focus")
	var told: bool = false
	for node: Node in final_screen.find_children("*", "Label", true, false):
		told = told or (node as Label).text.begins_with("Princess Capybara has her rubber duck")
	_check(told, "ending result: the epilogue is shown")
	await _press(final_screen, "CREDITS")
	_check(_ui.current_screen() == "credits", "ending result: CREDITS opens the credits")
	_ui.hide_all()
	_ui.show_result(_won_result())
	await _frames(FOCUS_FRAMES)
	_check(not _find_button(_ui.get_screen("result"), "CREDITS").is_visible_in_tree(), "an ordinary won result has no CREDITS button")


# --- Settings ------------------------------------------------------------------------------------

func _expected_type(spec: Dictionary) -> int:
	match str(spec["kind"]):
		"slider":
			return TYPE_FLOAT
		"toggle":
			return TYPE_BOOL
	var options: Array = spec["options"]
	return typeof(options[0][1])


## Changes every row of the four desktop tabs once and checks the emitted value's type and range.
func _test_settings_types() -> void:
	_use_profile(_progress_profile())
	_ui.hide_all()
	_ui.show_settings()
	await _frames(FOCUS_FRAMES)
	var settings: Control = _ui.get_screen("settings")
	var tab_ids: Array = settings.get("_tab_ids")
	_check(not tab_ids.has("touch"), "settings: TOUCH tab is hidden without touch controls")
	for tab_id: String in ["gameplay", "controls", "video", "audio"]:
		settings.call("show_tab", tab_id)
		await _frames(2)
		var fields: Dictionary = settings.get("_fields")
		for spec: Dictionary in SettingsScript.ROWS[tab_id]:
			var key: String = spec["key"]
			_check(fields.has(key), "settings %s: row %s is on screen" % [tab_id, key])
			if not fields.has(key):
				continue
			var field: Dictionary = fields[key]
			var control: Control = field["control"]
			_clear_emits()
			match str(spec["kind"]):
				"slider":
					var slider: HSlider = control
					var target: float = float(spec["max"]) if slider.value < float(spec["max"]) else float(spec["min"])
					slider.value = target
				"toggle":
					var check_box: CheckButton = control
					check_box.button_pressed = not check_box.button_pressed
				_:
					var cycle: Button = control
					cycle.pressed.emit()
			var args: Array = _last_args("setting_changed")
			_check(_count_emits("setting_changed") == 1 and args.size() == 2 and args[0] == key, "settings %s: %s emits setting_changed once" % [tab_id, key])
			if args.size() != 2:
				continue
			var expected: int = _expected_type(spec)
			_check(typeof(args[1]) == expected, "settings %s: %s emits type %d (got %d)" % [tab_id, key, expected, typeof(args[1])])
			if str(spec["kind"]) == "cycle":
				var values: Array = []
				for option: Array in spec["options"]:
					values.append(option[1])
				_check(values.has(args[1]), "settings %s: %s emits one of its options" % [tab_id, key])


# --- Workshop ------------------------------------------------------------------------------------

func _test_workshop() -> void:
	_use_profile(_progress_profile())
	_ui.hide_all()
	_ui.show_workshop()
	await _frames(FOCUS_FRAMES)
	var workshop: Control = _ui.get_screen("workshop")
	var entries: Dictionary = workshop.get("_entries")
	for id: String in WORKSHOP_STATES.keys():
		var expected: Array = WORKSHOP_STATES[id]
		var buy: Button = entries[id]["buy"] if entries.has(id) else null
		var state: String = "disabled" if expected[0] else "enabled"
		_check(buy != null and buy.disabled == expected[0] and buy.text == expected[1], "workshop %s: BUY %s with '%s'" % [id, state, expected[1]])
	# With no salvage, every open track names the shortfall.
	_profile.bank = 0
	_ui.refresh()
	var plating: Button = entries["plating"]["buy"]
	_check(plating.disabled and plating.text == "NEED 30 MORE", "workshop, bank 0: plating says NEED 30 MORE")
	var spool: Button = entries["spool"]["buy"]
	_check(spool.disabled and spool.text == "NEED 85 MORE", "workshop, bank 0: spool says NEED 85 MORE")
	_profile.bank = 115
	_ui.refresh()
	# An unaffordable card is denied, never sent to main.
	_clear_emits()
	var quick_press: Button = entries["quickdraw"]["press"]
	quick_press.pressed.emit()
	await _frames(2)
	var status: Label = workshop.get("_status")
	_check(_count_emits("upgrade_requested") == 0 and _profile.upgrade_tier("quickdraw") == 3, "workshop: an unaffordable track sends no upgrade_requested")
	_check("5 MORE NEEDED" in status.text, "workshop: denial names the missing salvage")
	# A maxed card is denied with its own message.
	_clear_emits()
	var weight_press: Button = entries["weight"]["press"]
	weight_press.pressed.emit()
	await _frames(2)
	status = workshop.get("_status")
	_check(_count_emits("upgrade_requested") == 0 and "FULLY UPGRADED" in status.text, "workshop: a maxed track is denied as fully upgraded")
	# An affordable card goes through upgrade_requested and the stand-in main.gd buys it.
	_stand_in_main = true
	_clear_emits()
	var plating_press: Button = entries["plating"]["press"]
	plating_press.pressed.emit()
	await _frames(2)
	_stand_in_main = false
	_check(_last_args("upgrade_requested") == ["plating"] and _profile.upgrade_tier("plating") == 1, "workshop: an affordable track is bought through upgrade_requested")
	_check(_profile.bank == 85, "workshop: the purchase spends 30 salvage")
	status = workshop.get("_status")
	_check("RAISED TO TIER 1" in status.text, "workshop: purchase feedback names the new tier")


# --- Level select -------------------------------------------------------------------------------

func _test_level_locks() -> void:
	# Real catalog: levels without a script (l09 is v1.1) show as coming soon. Range and l01 are open.
	_use_profile(_fresh_profile())
	_ui.hide_all()
	_ui.show_level_select()
	await _frames(FOCUS_FRAMES)
	var levels: Control = _ui.get_screen("levels")
	var cards: Dictionary = levels.get("_cards")
	var states: Dictionary = levels.get("_states")
	_check(states.get("l01") == "open", "levels: l01 is playable on a fresh profile")
	_check(states.get("range") == "open", "levels: PRACTICE RANGE is playable")
	_check(states.get("l09") == "soon", "levels: unbuilt l09 shows as coming soon")
	for id: String in cards.keys():
		if states[id] == "open":
			continue
		_clear_emits()
		var press: Button = cards[id]
		press.pressed.emit()
		await _frames(2)
		_check(_count_emits("level_requested") == 0, "levels: %s (%s) never emits level_requested" % [id, states[id]])
	_clear_emits()
	var playable: Button = cards["l01"]
	playable.pressed.emit()
	await _frames(2)
	_check(_last_args("level_requested") == ["l01"], "levels: playable l01 emits level_requested(l01)")

	# Stand-in catalog: l02 and l03 are built but locked behind l01's clear.
	_ui.set_sources(StubCatalog.new(), null, null)
	_use_profile(_fresh_profile())
	_ui.hide_all()
	_ui.show_level_select()
	await _frames(FOCUS_FRAMES)
	cards = levels.get("_cards")
	states = levels.get("_states")
	_check(states.get("l02") == "locked" and states.get("l03") == "locked", "levels, stand-in: built l02 and l03 show as locked")
	for id: String in ["l02", "l03"]:
		_clear_emits()
		var locked_press: Button = cards[id]
		locked_press.pressed.emit()
		await _frames(2)
		_check(_count_emits("level_requested") == 0, "levels, stand-in: locked %s never emits level_requested" % id)
	_ui.set("catalog", _real_catalog)
	_ui.refresh()


# --- Toasts ---------------------------------------------------------------------------------------

func _test_toasts() -> void:
	_use_profile(_progress_profile())
	_ui.hide_all()
	_ui.show_title()
	await _frames(FOCUS_FRAMES)
	var before: Control = _focus_owner()
	_check(before != null, "toast: title starts with a focused control")
	_ui.show_toast("ACHIEVEMENT TEST", "Toast subtitle")
	await _frames(FOCUS_FRAMES)
	_check(_ui.find_children("Toast*", "PanelContainer", true, false).size() >= 1, "toast: a toast is on screen")
	_check(_focus_owner() == before, "toast: showing a toast on title leaves focus where it was")
	_ui.hide_all()
	_ui.show_level_select()
	await _frames(FOCUS_FRAMES)
	before = _focus_owner()
	_ui.show_toast("ACHIEVEMENT TEST", "Second toast")
	_ui.show_toast("ACHIEVEMENT TEST", "Queued toast")
	await _frames(FOCUS_FRAMES)
	_check(before != null and _focus_owner() == before, "toast: a toast on level select leaves focus where it was")


# --- Layout --------------------------------------------------------------------------------------

## Every view stays inside the viewport at each layout size. Title and settings are also checked
## for overlapping buttons. The viewport is the canvas the game really draws on: the project uses
## canvas_items stretch with aspect "expand", so a window keeps at least the 1280x720 design size
## and grows along its longer side. A 800x450 window therefore lays out at 1280x720, and a
## 960x720 window at 1280x960. The check uses the visible rect and verifies it against that rule.
func _test_layouts() -> void:
	var original_size: Vector2i = root.size
	_use_profile(_progress_profile())
	for size: Vector2i in LAYOUT_SIZES:
		root.size = size
		await _frames(4)
		var bounds: Rect2 = root.get_visible_rect()
		var size_text: String = "%dx%d" % [size.x, size.y]
		var scale: float = minf(float(size.x) / 1280.0, float(size.y) / 720.0)
		var expected: Vector2 = Vector2(size) / scale
		_check(bounds.size.is_equal_approx(expected), "layout: canvas for %s is %s (got %s)" % [size_text, str(expected), str(bounds.size)])
		for view: String in VIEWS:
			_ui.hide_all()
			_open(view)
			await _frames(SETTLE_FRAMES)
			var outside: Array[String] = []
			_collect_outside(_ui.get_screen(_screen_of(view)), bounds, outside)
			_check(outside.is_empty(), "layout %s: %s stays inside the viewport%s" % [size_text, view, _list_suffix(outside)])
		for view: String in ["title", "settings"]:
			_ui.hide_all()
			_open(view)
			await _frames(SETTLE_FRAMES)
			var overlaps: Array[String] = []
			_collect_overlaps(_ui.get_screen(view), overlaps)
			_check(overlaps.is_empty(), "layout %s: %s buttons do not overlap%s" % [size_text, view, _list_suffix(overlaps)])
	root.size = original_size
	await _frames(2)


## Adds every visible control under node whose global rect leaves the viewport rect. A
## ScrollContainer is checked itself, but its content is not: scrolled content may lie outside
## the visible area by design.
func _collect_outside(node: Node, bounds: Rect2, out: Array[String]) -> void:
	for child: Node in node.get_children():
		if not (child is Control):
			continue
		var control: Control = child
		if not control.is_visible_in_tree():
			continue
		if not _inside(control.get_global_rect(), bounds):
			out.append(_describe(control))
		if control is ScrollContainer:
			continue
		_collect_outside(control, bounds, out)


func _inside(rect: Rect2, bounds: Rect2) -> bool:
	return rect.position.x >= bounds.position.x - EDGE_TOLERANCE \
		and rect.position.y >= bounds.position.y - EDGE_TOLERANCE \
		and rect.end.x <= bounds.end.x + EDGE_TOLERANCE \
		and rect.end.y <= bounds.end.y + EDGE_TOLERANCE


## Compares the visible buttons and sliders that share a container. Labels, keycaps and value
## readouts are not compared, and neither are the transparent press buttons laid over card panels:
## a card's press button is never a sibling of another button, so that overlay is skipped too.
func _collect_overlaps(node: Node, out: Array[String]) -> void:
	var controls: Array[Control] = []
	for child: Node in node.get_children():
		if child is Control and (child as Control).is_visible_in_tree() and (child is BaseButton or child is Range):
			controls.append(child)
	for i in range(controls.size()):
		for j in range(i + 1, controls.size()):
			var common: Rect2 = controls[i].get_global_rect().intersection(controls[j].get_global_rect())
			if common.size.x > OVERLAP_TOLERANCE and common.size.y > OVERLAP_TOLERANCE:
				out.append("%s / %s" % [_describe(controls[i]), _describe(controls[j])])
	for child: Node in node.get_children():
		_collect_overlaps(child, out)


func _describe(control: Control) -> String:
	var text: Variant = control.get("text")
	var detail: String = " '%s'" % str(text) if (text is String and not str(text).is_empty()) else ""
	return "%s%s at %s" % [control.get_class(), detail, str(control.get_global_rect())]


func _list_suffix(items: Array[String]) -> String:
	if items.is_empty():
		return ""
	var shown: PackedStringArray = []
	for i in range(mini(3, items.size())):
		shown.append(items[i])
	return " (%s%s)" % ["; ".join(shown), "; ..." if items.size() > 3 else ""]
