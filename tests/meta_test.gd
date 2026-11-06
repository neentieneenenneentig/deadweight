extends SceneTree
## F1 data layer: profile persistence, settings, upgrades, unlocks, rewards and achievements.
## Uses only user://test_f1.cfg (and its .bak/.tmp/.corrupt companions), never the real save.

const Profile = preload("res://scripts/profile.gd")
const Upgrades = preload("res://scripts/upgrades.gd")
const Achievements = preload("res://scripts/achievements.gd")
const Settings = preload("res://scripts/settings.gd")
const TEST_PATH := "user://test_f1.cfg"

## Stands in for scripts/level_catalog.gd, which does not exist yet.
const STUB_CATALOG := """extends RefCounted
static func campaign_ids() -> Array[String]:
	return ["tutorial", "l01", "l02", "l03", "l04", "l05", "l06", "l07", "l08", "l09"]
static func info(id: String) -> Dictionary:
	if id == "range":
		return {"practice": true, "available": true}
	var result := {"available": true, "bonus": 2, "cases": 3, "practice": false, "par_silver": 150.0, "par_gold": 95.0}
	return result
"""

var _failures := 0
var _checks := 0


func _initialize() -> void:
	_test_upgrades()
	_test_achievement_table()
	_test_settings()
	_test_persistence()
	_test_purchases()
	_test_unlocks_and_runs()
	_test_run_rewards()
	_test_achievement_rules()
	_test_engine_helpers()
	_cleanup()
	if _failures == 0:
		print("META TESTS PASSED: %d checks" % _checks)
	else:
		push_error("META TESTS FAILED: %d of %d checks" % [_failures, _checks])
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("META TEST: " + message)


func _eq(actual: Variant, expected: Variant, message: String) -> void:
	_expect(actual == expected, "%s (got %s, expected %s)" % [message, str(actual), str(expected)])


func _cleanup() -> void:
	for suffix: String in ["", ".bak", ".tmp", ".corrupt"]:
		if FileAccess.file_exists(TEST_PATH + suffix):
			DirAccess.remove_absolute(TEST_PATH + suffix)


func _fresh(with_catalog: bool = false) -> RefCounted:
	_cleanup()
	var profile: RefCounted = Profile.new()
	profile.mobile = false
	profile.load_profile(TEST_PATH)
	if with_catalog:
		profile.catalog = _stub_catalog()
	return profile


func _stub_catalog() -> Script:
	var script := GDScript.new()
	script.source_code = STUB_CATALOG
	script.reload()
	return script


func _run(level_id: String, won: bool, time: float, extra: Dictionary = {}) -> Dictionary:
	var run := {
		"level_id": level_id, "won": won, "time": time, "cases": 3, "bonus_indices": [],
		"total_bonus": 2, "damage_taken": 0.0, "shots": 0, "kills": 0, "smash_kills": 0,
		"enemies_present": true, "max_speed": 10.0, "max_airtime": 2.0, "casts": 5,
	}
	run.merge(extra, true)
	return run


# --- Upgrades ---------------------------------------------------------------------------------

func _test_upgrades() -> void:
	var stock: Dictionary = Upgrades.stats({})
	_eq(stock["max_line"], 40.0, "tier 0 max_line")
	_eq(stock["reel_force"], 14000.0, "tier 0 reel_force")
	_eq(stock["reel_speed"], 9.0, "tier 0 reel_speed")
	_eq(stock["weight_mass"], 130.0, "tier 0 weight_mass")
	_eq(stock["assist_strength"], 130.0 * Upgrades.ASSIST_PER_KG, "tier 0 assist_strength = mass x ASSIST_PER_KG")
	_eq(stock["charge_time"], 0.8, "tier 0 charge_time")
	_eq(stock["max_health"], 100.0, "tier 0 max_health")
	_eq(stock["magazine"], 10, "tier 0 magazine")
	_eq(stock["sidearm_damage"], 30.0, "tier 0 sidearm_damage")
	var maxed_tiers := {}
	for id: String in Upgrades.ORDER:
		maxed_tiers[id] = 4
	var maxed: Dictionary = Upgrades.stats(maxed_tiers)
	_eq(maxed["max_line"], 72.0, "tier 4 max_line")
	_eq(maxed["reel_force"], 24000.0, "tier 4 reel_force")
	_eq(maxed["reel_speed"], 15.0, "tier 4 reel_speed")
	_eq(maxed["weight_mass"], 190.0, "tier 4 weight_mass")
	_eq(maxed["assist_strength"], 190.0 * Upgrades.ASSIST_PER_KG, "tier 4 assist_strength")
	_eq(maxed["charge_time"], 0.38, "tier 4 charge_time")
	_eq(maxed["max_health"], 190.0, "tier 4 max_health")
	_eq(maxed["magazine"], 20, "tier 4 magazine")
	_eq(maxed["sidearm_damage"], 48.0, "tier 4 sidearm_damage")
	var damaged: Dictionary = Upgrades.stats({"spool": 99, "reel": -3, "weight": "x", "plating": 2.0})
	_eq(damaged["max_line"], 72.0, "tier above max clamps")
	_eq(damaged["reel_force"], 14000.0, "negative tier clamps to 0")
	_eq(damaged["weight_mass"], 130.0, "non-numeric tier counts as 0")
	_eq(damaged["max_health"], 140.0, "float tier is accepted")
	_eq(Upgrades.COSTS, [30, 55, 85, 120], "tier costs")
	_eq(Upgrades.max_tier(), 4, "max tier")
	_eq(Upgrades.ORDER.size(), 6, "six tracks")
	_eq(Upgrades.total_cost(), 290 * 6, "cost to max everything")
	_eq(Upgrades.describe("spool", 1), "48 M LINE", "describe spool")
	_eq(Upgrades.describe("reel", 0), "14 KN / 9 M/S", "describe reel stock")
	_eq(Upgrades.describe("reel", 2), "18.5 KN / 12 M/S", "describe reel tier 2")
	_eq(Upgrades.describe("weight", 4), "190 KG SINKER", "describe weight")
	_eq(Upgrades.describe("quickdraw", 3), "0.46 S FULL CHARGE", "describe quickdraw")
	_eq(Upgrades.describe("sidearm", 4), "20 ROUNDS / 48 DMG", "describe sidearm")
	_eq(Upgrades.describe("nope", 1), "", "unknown track describes as empty")
	_eq(Upgrades.cost_for("spool", 4), -1, "maxed track has no cost")
	_eq(Upgrades.cost_for("nope", 0), -1, "unknown track has no cost")
	for id: String in Upgrades.ORDER:
		var def: Dictionary = Upgrades.DEFS[id]
		_eq((def["values"] as Array).size(), 5, "%s has five tier values" % id)
		_expect(not str(def["title"]).is_empty() and not str(def["desc"]).is_empty(), "%s has text" % id)


# --- Achievements table -----------------------------------------------------------------------

func _test_achievement_table() -> void:
	_eq(Achievements.LIST.size(), 17, "seventeen achievements")
	_eq(Achievements.find("FIRST_CAST")["title"], "Gone Fishing", "find known id")
	_expect(Achievements.find("NOPE").is_empty(), "unknown id finds nothing")
	var design: Array[Dictionary] = _design_achievements()
	_expect(not design.is_empty(), "DESIGN.md achievements table was read")
	_eq(design.size(), Achievements.LIST.size(), "DESIGN and code list the same count")
	for index in range(mini(design.size(), Achievements.LIST.size())):
		var entry: Dictionary = Achievements.LIST[index]
		_eq(entry["id"], design[index]["id"], "achievement %d id matches DESIGN" % index)
		_eq(entry["title"], design[index]["title"], "achievement %s title matches DESIGN" % entry["id"])
		_eq(entry["desc"], design[index]["desc"], "achievement %s text matches DESIGN" % entry["id"])


func _design_achievements() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var text: String = FileAccess.get_file_as_string("res://docs/DESIGN.md")
	var in_table: bool = false
	for line: String in text.split("\n"):
		if line.begins_with("## Achievements"):
			in_table = true
			continue
		if in_table and line.begins_with("## "):
			break
		if not in_table or not line.begins_with("|"):
			continue
		var cells: PackedStringArray = line.split("|")
		if cells.size() < 5:
			continue
		var id: String = cells[1].strip_edges()
		if id == "ID" or id.begins_with("-") or id.is_empty():
			continue
		rows.append({"id": id, "title": cells[2].strip_edges(), "desc": cells[3].strip_edges()})
	return rows


# --- Settings ---------------------------------------------------------------------------------

func _test_settings() -> void:
	var desktop: Dictionary = Profile.defaults_for(false)
	var mobile: Dictionary = Profile.defaults_for(true)
	_eq(desktop.size(), 20, "twenty setting keys")
	_eq(desktop["window_mode"], "fullscreen", "desktop window mode")
	_eq(desktop["max_fps"], 0, "desktop fps unlimited")
	_eq(desktop["quality"], 2, "desktop quality high")
	_eq(desktop["render_scale"], 1.0, "desktop render scale")
	_eq(mobile["max_fps"], 60, "mobile fps cap")
	_eq(mobile["quality"], 1, "mobile quality medium")
	_eq(mobile["render_scale"], 0.85, "mobile render scale")
	_eq(mobile["fov"], 78.0, "mobile keeps other defaults")
	_eq(Profile.DEFAULT_SETTINGS["max_fps"], 0, "defaults_for does not change the constant")
	var profile: RefCounted = _fresh()
	for key: String in Profile.DEFAULT_SETTINGS:
		_eq(profile.setting(key), desktop[key], "fresh profile default for %s" % key)
	profile.set_setting("fov", 200.0)
	_eq(profile.setting("fov"), 95.0, "fov clamps high")
	profile.set_setting("fov", 10)
	_eq(profile.setting("fov"), 60.0, "fov clamps low (int input becomes float)")
	_expect(profile.setting("fov") is float, "fov stays a float")
	profile.set_setting("difficulty", 7)
	_eq(profile.setting("difficulty"), 2, "difficulty clamps")
	profile.set_setting("difficulty", 0.6)
	_eq(profile.setting("difficulty"), 1, "difficulty rounds to int")
	_expect(profile.setting("difficulty") is int, "difficulty stays an int")
	profile.set_setting("max_fps", 100)
	_eq(profile.setting("max_fps"), 90, "max_fps snaps to the nearest option")
	profile.set_setting("max_fps", 0)
	_eq(profile.setting("max_fps"), 0, "max_fps 0 means unlimited")
	profile.set_setting("max_fps", 5000)
	_eq(profile.setting("max_fps"), 144, "max_fps snaps to the top option")
	profile.set_setting("window_mode", "bogus")
	_eq(profile.setting("window_mode"), "fullscreen", "bad window mode keeps the old value")
	profile.set_setting("window_mode", "windowed")
	_eq(profile.setting("window_mode"), "windowed", "valid window mode accepted")
	profile.set_setting("invert_y", "yes")
	_eq(profile.setting("invert_y"), true, "string bool parses")
	profile.set_setting("invert_y", "garbage")
	_eq(profile.setting("invert_y"), true, "garbage bool keeps the old value")
	profile.set_setting("look_sensitivity", "abc")
	_eq(profile.setting("look_sensitivity"), 1.0, "non-numeric float keeps the old value")
	profile.set_setting("look_sensitivity", "2.5")
	_eq(profile.setting("look_sensitivity"), 2.5, "numeric string parses")
	profile.set_setting("music_volume", NAN)
	_eq(profile.setting("music_volume"), 0.6, "NaN keeps the old value")
	profile.set_setting("touch_scale", 99.0)
	_eq(profile.setting("touch_scale"), 1.35, "touch scale clamps")
	profile.set_setting("not_a_setting", 5)
	_expect(not profile.settings.has("not_a_setting"), "unknown keys are ignored")
	_eq(profile.settings.size(), 20, "settings stay complete")
	_expect(profile.setting("not_a_setting") == null, "unknown setting reads as null")
	# A mobile profile starts from the mobile defaults.
	_cleanup()
	var phone: RefCounted = Profile.new()
	phone.mobile = true
	phone.load_profile(TEST_PATH)
	_eq(phone.setting("max_fps"), 60, "mobile profile fps")
	_eq(phone.setting("render_scale"), 0.85, "mobile profile render scale")


# --- Persistence ------------------------------------------------------------------------------

func _test_persistence() -> void:
	var profile: RefCounted = _fresh()
	_eq(profile.bank, 0, "missing file gives defaults")
	_eq(profile.upgrade_tier("spool"), 0, "default tier")
	_expect(not profile.restored_from_backup, "missing file is not a restore")
	_expect(not FileAccess.file_exists(TEST_PATH), "loading does not create a file")
	# Round trip of every field.
	profile.bank = 123
	profile.lifetime_salvage = 456
	profile.tutorial_done = true
	profile.upgrades["spool"] = 2
	profile.upgrades["sidearm"] = 4
	profile.levels["l01"] = {"completed": true, "best_time": 88.5, "medal": 3, "bonus_found": [1, 0], "attempts": 4, "extractions": 2}
	profile.set_setting("fov", 82.0)
	profile.set_setting("quality", 0)
	profile.set_setting("window_mode", "windowed")
	profile.achievements["FIRST_CAST"] = true
	profile.stats["casts"] = 77
	profile.stats["max_speed"] = 31.5
	profile.save_profile()
	_eq(profile.last_error, OK, "save succeeds")
	_expect(FileAccess.file_exists(TEST_PATH), "save writes the file")
	var again: RefCounted = Profile.new()
	again.mobile = false
	again.load_profile(TEST_PATH)
	_eq(again.bank, 123, "round trip bank")
	_eq(again.lifetime_salvage, 456, "round trip lifetime")
	_eq(again.tutorial_done, true, "round trip tutorial flag")
	_eq(again.upgrade_tier("spool"), 2, "round trip spool")
	_eq(again.upgrade_tier("sidearm"), 4, "round trip sidearm")
	_eq(again.upgrade_tier("reel"), 0, "round trip untouched track")
	_eq(again.level_record("l01")["best_time"], 88.5, "round trip best time")
	_eq(again.level_record("l01")["medal"], 3, "round trip medal")
	_eq(again.level_record("l01")["bonus_found"], [0, 1], "round trip sorted bonus list")
	_eq(again.level_record("l01")["attempts"], 4, "round trip attempts")
	_eq(again.setting("fov"), 82.0, "round trip fov")
	_eq(again.setting("quality"), 0, "round trip quality")
	_eq(again.setting("window_mode"), "windowed", "round trip window mode")
	_expect(again.has_achievement("FIRST_CAST"), "round trip achievement")
	_eq(again.stats["casts"], 77, "round trip int stat")
	_expect(again.stats["casts"] is int, "int stat stays int")
	_eq(again.stats["max_speed"], 31.5, "round trip float stat")
	_expect(not FileAccess.file_exists(TEST_PATH + ".tmp"), "no leftover temp file")
	_expect(not again.restored_from_backup, "clean load is not a restore")
	# A second save keeps the first as the backup.
	again.bank = 200
	again.save_profile()
	_expect(FileAccess.file_exists(TEST_PATH + ".bak"), "second save keeps a backup")
	# Corrupt main file: restore from .bak.
	var junk := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	junk.store_buffer(PackedByteArray([0x00, 0x01, 0xff, 0xfe, 0x80, 0x41, 0x42, 0x43, 0x00, 0x99]))
	junk.close()
	var recovered: RefCounted = Profile.new()
	recovered.mobile = false
	recovered.load_profile(TEST_PATH)
	_expect(recovered.restored_from_backup, "corrupt file restores from the backup")
	_eq(recovered.bank, 123, "backup holds the previous save")
	_eq(recovered.upgrade_tier("sidearm"), 4, "backup keeps upgrades")
	var after: RefCounted = Profile.new()
	after.mobile = false
	after.load_profile(TEST_PATH)
	_eq(after.bank, 123, "restored profile was written back")
	_expect(not after.restored_from_backup, "next load is clean")
	_expect(FileAccess.file_exists(TEST_PATH + ".corrupt"), "damaged file is set aside")
	# A write cut short (no trailer) is treated as damaged.
	var good_text: String = FileAccess.get_file_as_string(TEST_PATH)
	_write_text(TEST_PATH, good_text.substr(0, good_text.length() / 2))
	var cut: RefCounted = Profile.new()
	cut.mobile = false
	cut.load_profile(TEST_PATH)
	_expect(cut.restored_from_backup, "truncated file restores from the backup")
	# No file and no backup at all: defaults, no crash.
	_cleanup()
	_write_text(TEST_PATH, "garbage that is not a profile at all")
	var lost: RefCounted = Profile.new()
	lost.mobile = false
	lost.load_profile(TEST_PATH)
	_eq(lost.bank, 0, "corrupt file without backup gives defaults")
	_expect(not lost.restored_from_backup, "nothing to restore from")
	# Hand-edited values are validated on load.
	_cleanup()
	_write_text(TEST_PATH, "[profile]\nversion=1\nbank=-50\nlifetime_salvage=\"x\"\n[upgrades]\nspool=99\nreel=\"two\"\n[settings]\nfov=500.0\ndifficulty=\"hard\"\nmax_fps=77\nwindow_mode=\"tiny\"\nstray=1\n[levels]\nl01={\"medal\": 9, \"best_time\": -4.0, \"bonus_found\": [3, 3, -1, \"x\"], \"attempts\": -2}\nl02=5\n[achievements]\nFIRST_CAST=true\nBOGUS=true\nGHOST=false\n[stats]\ncasts=-5\nmax_speed=12.5\n\n; end of profile\n")
	var edited: RefCounted = Profile.new()
	edited.mobile = false
	edited.load_profile(TEST_PATH)
	_eq(edited.bank, 0, "negative bank resets")
	_eq(edited.lifetime_salvage, 0, "junk lifetime resets")
	_eq(edited.upgrade_tier("spool"), 4, "tier above max clamps on load")
	_eq(edited.upgrade_tier("reel"), 0, "junk tier resets on load")
	_eq(edited.setting("fov"), 95.0, "fov clamps on load")
	_eq(edited.setting("difficulty"), 1, "junk difficulty falls back to the default")
	_eq(edited.setting("max_fps"), 90, "off-list fps snaps on load")
	_eq(edited.setting("window_mode"), "fullscreen", "bad window mode falls back")
	_expect(not edited.settings.has("stray"), "unknown setting dropped")
	_eq(edited.level_record("l01")["medal"], 3, "medal clamps on load")
	_eq(edited.level_record("l01")["best_time"], -1.0, "negative best time means none")
	_eq(edited.level_record("l01")["bonus_found"], [3], "bonus list cleaned on load")
	_eq(edited.level_record("l01")["attempts"], 0, "negative attempts reset")
	_expect(not edited.levels.has("l02"), "non-record level entry ignored")
	_expect(edited.has_achievement("FIRST_CAST"), "valid achievement loads")
	_expect(not edited.has_achievement("BOGUS"), "unknown achievement dropped")
	_expect(not edited.has_achievement("GHOST"), "false achievement not unlocked")
	_eq(edited.stats["casts"], 0, "negative stat resets")
	_eq(edited.stats["max_speed"], 12.5, "valid stat loads")
	# The prototype's save only held the salvage bank.
	_cleanup()
	_write_text(TEST_PATH, "[salvage]\nbank=75\n")
	var legacy: RefCounted = Profile.new()
	legacy.mobile = false
	legacy.load_profile(TEST_PATH)
	_eq(legacy.bank, 75, "prototype save migrates its bank")
	_eq(legacy.lifetime_salvage, 75, "prototype save sets lifetime")
	# Reset keeps settings only.
	legacy.set_setting("fov", 70.0)
	legacy.upgrades["spool"] = 3
	legacy.achievements["GHOST"] = true
	legacy.levels["l01"] = {"completed": true}
	legacy.reset_progress()
	_eq(legacy.bank, 0, "reset clears the bank")
	_eq(legacy.upgrade_tier("spool"), 0, "reset clears upgrades")
	_expect(legacy.achievements.is_empty() and legacy.levels.is_empty(), "reset clears records and achievements")
	_eq(legacy.setting("fov"), 70.0, "reset keeps settings")
	# Saving to an impossible location reports an error but never throws.
	_write_text("user://test_f1_blocker", "a file where a folder is needed")
	var nowhere: RefCounted = Profile.new()
	nowhere.load_profile("user://test_f1_blocker/profile.cfg")
	nowhere.save_profile()
	_expect(nowhere.last_error != OK, "unwritable path reports an error")
	DirAccess.remove_absolute("user://test_f1_blocker")


func _write_text(file_path: String, text: String) -> void:
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()


# --- Purchases --------------------------------------------------------------------------------

func _test_purchases() -> void:
	var profile: RefCounted = _fresh()
	_eq(profile.upgrade_cost("spool"), 30, "first tier costs 30")
	profile.bank = 29
	_expect(not profile.can_purchase("spool"), "29 salvage cannot buy a 30 upgrade")
	_expect(not profile.purchase("spool"), "purchase fails when short")
	_eq(profile.bank, 29, "failed purchase keeps the bank")
	_eq(profile.upgrade_tier("spool"), 0, "failed purchase keeps the tier")
	profile.bank = 30 + 55 + 85 + 120 + 7
	var expected_costs: Array[int] = [30, 55, 85, 120]
	for tier in range(4):
		_eq(profile.upgrade_cost("spool"), expected_costs[tier], "cost of tier %d" % (tier + 1))
		_expect(profile.purchase("spool"), "buy tier %d" % (tier + 1))
		_eq(profile.upgrade_tier("spool"), tier + 1, "tier after purchase %d" % (tier + 1))
	_eq(profile.bank, 7, "bank after buying all four tiers")
	_eq(profile.upgrade_cost("spool"), -1, "maxed track has no cost")
	_expect(not profile.can_purchase("spool"), "maxed track cannot be bought")
	profile.bank = 9999
	_expect(not profile.purchase("spool"), "maxed track purchase fails")
	_eq(profile.bank, 9999, "maxed purchase keeps the bank")
	_expect(not profile.purchase("nonsense"), "unknown track purchase fails")
	_eq(profile.upgrade_tier("nonsense"), 0, "unknown track reads as tier 0")


# --- Unlocks and records ----------------------------------------------------------------------

func _test_unlocks_and_runs() -> void:
	# Without the catalog script: the DESIGN campaign order is the fallback.
	var bare: RefCounted = _fresh()
	bare.catalog = null
	_expect(bare.is_unlocked("tutorial"), "tutorial open from the start")
	_expect(bare.is_unlocked("l01"), "l01 open from the start")
	_expect(bare.is_unlocked("range"), "range always open")
	_expect(not bare.is_unlocked("l02"), "l02 locked at first")
	_expect(not bare.is_unlocked("l09"), "l09 locked at first")
	_expect(not bare.is_unlocked("unknown_level"), "unknown level is locked")
	_eq(bare.level_info("l01"), {}, "no catalog means empty info")
	var plain: Dictionary = bare.record_run(_run("l01", true, 100.0))
	_eq(plain["medal"], 1, "no par data still gives bronze")
	_eq(plain["next_unlocked"], "l02", "completing l01 unlocks l02")
	_expect(bare.is_unlocked("l02"), "l02 unlocked after l01")
	_expect(not bare.is_unlocked("l03"), "l03 still locked")
	# With the stub catalog.
	var profile: RefCounted = _fresh(true)
	_eq(profile.campaign_ids().size(), 10, "campaign has ten levels")
	_eq(profile.next_campaign_id("tutorial"), "l01", "next after tutorial")
	_eq(profile.next_campaign_id("l09"), "", "nothing after the last level")
	_eq(profile.next_campaign_id("range"), "", "range has no next level")
	var failed: Dictionary = profile.record_run(_run("l01", false, 30.0, {"cases": 2}))
	_eq(failed["salvage"], 0, "failed run pays nothing")
	_eq(failed["medal"], 0, "failed run has no medal")
	_eq(profile.bank, 0, "failed run leaves the bank alone")
	_eq(profile.level_record("l01")["attempts"], 1, "failed run counts an attempt")
	_expect(not profile.level_record("l01")["completed"], "failed run does not complete")
	_eq(profile.stats["deaths"], 1, "failed run counts a death")
	_eq(profile.stats["casts"], 5, "failed run counts casts")
	_expect(not profile.is_unlocked("l02"), "failed run unlocks nothing")
	var practice: Dictionary = profile.record_run(_run("range", true, 60.0))
	_eq(practice["salvage"], 0, "practice pays nothing")
	_expect(not profile.levels.has("range"), "practice is not recorded")
	var unknown: Dictionary = profile.record_run(_run("", true, 60.0))
	_eq(unknown["salvage"], 0, "run without a level id pays nothing")
	# Unlock chain through the whole campaign.
	var chain: RefCounted = _fresh(true)
	var order: Array[String] = chain.campaign_ids()
	for index in range(order.size() - 1):
		var following: String = order[index + 1]
		if index >= 1:
			_expect(not chain.is_unlocked(following), "%s locked before %s is done" % [following, order[index]])
		chain.record_run(_run(order[index], true, 200.0))
		_expect(chain.is_unlocked(following), "%s unlocked after %s" % [following, order[index]])
	var all_open: RefCounted = _fresh()
	all_open.unlock_all = true
	_expect(all_open.is_unlocked("l09"), "unlock_all opens everything")
	all_open.save_profile()
	var reloaded: RefCounted = Profile.new()
	reloaded.load_profile(TEST_PATH)
	_expect(not reloaded.is_unlocked("l09"), "unlock_all is never saved")
	# Level records are copies.
	var copy: Dictionary = chain.level_record("l01")
	copy["completed"] = false
	copy["bonus_found"].append(9)
	_expect(chain.level_record("l01")["completed"], "editing a record copy changes nothing")
	_expect(not chain.level_record("l01")["bonus_found"].has(9), "record arrays are copies")
	_eq(chain.level_record("never_played"), Profile.default_record(), "unplayed level reads as default")
	_eq(Profile.medal_for(150.0, 150.0, 95.0), 2, "time equal to silver par is silver")
	_eq(Profile.medal_for(95.0, 150.0, 95.0), 3, "time equal to gold par is gold")
	_eq(Profile.medal_for(150.1, 150.0, 95.0), 1, "slower than silver is bronze")
	_eq(Profile.medal_for(5.0, 0.0, 0.0), 1, "no pars means bronze")


func _test_run_rewards() -> void:
	var profile: RefCounted = _fresh(true)
	# First clear in silver time: 3 cases, 1 bonus, bronze + silver bonuses.
	var first: Dictionary = profile.record_run(_run("l01", true, 120.0, {"bonus_indices": [0]}))
	_eq(first["medal"], 2, "silver time gives silver")
	_eq(first["previous_medal"], 0, "previous medal was none")
	_eq(first["salvage"], 45 + 30 + 10 + 25, "salvage: cases + bonus + bronze + silver")
	_eq(first["breakdown"].size(), 4, "breakdown has four lines")
	var summed: int = 0
	for line: Array in first["breakdown"]:
		summed += int(line[1])
	_eq(summed, int(first["salvage"]), "breakdown adds up to the salvage")
	_expect(first["first_clear"], "first clear flagged")
	_expect(first["new_best"], "first time is a best")
	_eq(first["best_time"], 120.0, "best time recorded")
	_eq(first["next_unlocked"], "l02", "first clear unlocks l02")
	_eq(profile.bank, 110, "bank paid")
	_eq(profile.lifetime_salvage, 110, "lifetime paid")
	_eq(profile.stats["salvage_earned"], 110, "salvage stat paid")
	_eq(profile.stats["extractions"], 1, "extraction counted")
	_eq(profile.level_record("l01")["bonus_found"], [0], "bonus remembered")
	# Gold time: only the gold bonus is new; cases and bonuses pay every extraction.
	var second: Dictionary = profile.record_run(_run("l01", true, 90.0, {"bonus_indices": [0, 1]}))
	_eq(second["medal"], 3, "gold time gives gold")
	_eq(second["previous_medal"], 2, "previous medal was silver")
	_eq(second["salvage"], 45 + 60 + 50, "salvage: cases + two bonuses + gold bonus only")
	_expect(not second["first_clear"], "second clear is not a first clear")
	_expect(second["new_best"], "faster time is a new best")
	_eq(second["next_unlocked"], "", "l02 was already unlocked")
	_eq(profile.level_record("l01")["bonus_found"], [0, 1], "bonus list merges")
	# A slower run never lowers the medal or best time, and pays no medal bonus.
	var third: Dictionary = profile.record_run(_run("l01", true, 140.0))
	_eq(third["medal"], 2, "this run earned silver")
	_eq(third["salvage"], 45, "slower run pays cases only")
	_expect(not third["new_best"], "slower time is not a best")
	_eq(third["best_time"], 90.0, "best time is kept")
	_eq(profile.level_record("l01")["medal"], 3, "saved medal never drops")
	_eq(profile.level_record("l01")["extractions"], 3, "three extractions recorded")
	_eq(profile.level_record("l01")["attempts"], 3, "three attempts recorded")
	# Bronze only on a level that is not l01.
	var bronze: Dictionary = profile.record_run(_run("l02", true, 400.0, {"cases": 0}))
	_eq(bronze["medal"], 1, "slow clear is bronze")
	_eq(bronze["salvage"], 10, "bronze bonus only")
	# Tutorial sets the tutorial flag and unlocks nothing new (l01 is always open).
	var tutorial: Dictionary = profile.record_run(_run("tutorial", true, 100.0, {"cases": 1, "enemies_present": false}))
	_expect(profile.tutorial_done, "tutorial flag set")
	_eq(tutorial["next_unlocked"], "", "l01 is already open")
	# Play stats accumulate; max values only grow.
	profile.add_play_stats({"time": 10.0, "casts": 2, "kills": 3, "smash_kills": 1, "max_speed": 50.0, "max_airtime": 20.0})
	profile.add_play_stats({"time": 5.0, "max_speed": 20.0, "max_airtime": 4.0})
	_eq(profile.stats["max_speed"], 50.0, "max speed keeps the highest")
	_eq(profile.stats["max_airtime"], 20.0, "max airtime keeps the highest")
	_eq(profile.stats["smash_kills"], 1, "smash kills counted")
	_expect(profile.stats["play_time"] >= 15.0, "play time accumulates")
	# Everything survives a save and load.
	profile.save_profile()
	var reloaded: RefCounted = Profile.new()
	reloaded.mobile = false
	reloaded.load_profile(TEST_PATH)
	_eq(reloaded.bank, profile.bank, "bank survives a reload")
	_eq(reloaded.level_record("l01")["medal"], 3, "medal survives a reload")
	_eq(reloaded.level_record("l01")["best_time"], 90.0, "best time survives a reload")
	_expect(reloaded.tutorial_done, "tutorial flag survives a reload")
	# Hostile run data never breaks the profile.
	var hostile: RefCounted = _fresh(true)
	var odd: Dictionary = hostile.record_run({"level_id": "l01", "won": true, "time": -5.0, "cases": -2, "bonus_indices": "no", "casts": "x"})
	_expect(int(odd["salvage"]) >= 0, "hostile run pays no negative salvage")
	_expect(hostile.bank >= 0, "bank never goes negative")


# --- Achievements -----------------------------------------------------------------------------

func _test_achievement_rules() -> void:
	var profile: RefCounted = _fresh(true)
	_expect(profile.unlock_achievement("FIRST_CAST"), "first unlock is new")
	_expect(not profile.unlock_achievement("FIRST_CAST"), "second unlock has no effect")
	_eq(profile.achievements.size(), 1, "still one achievement")
	_expect(not profile.unlock_achievement("NOT_REAL"), "unknown id is rejected")
	_eq(profile.achievements.size(), 1, "unknown id adds nothing")
	# End-of-run rules.
	var tutorial_run: Dictionary = _run("tutorial", true, 90.0, {"enemies_present": false})
	var earned: Array[String] = Achievements.end_of_run(tutorial_run, profile)
	_expect(earned.has("FIRST_EXTRACT") and earned.has("GRADUATE"), "tutorial extraction earns two")
	_expect(not earned.has("UNTOUCHED") and not earned.has("GHOST"), "no stealth awards without enemies")
	var clean: Array[String] = Achievements.end_of_run(_run("l01", true, 90.0), profile)
	_expect(clean.has("UNTOUCHED") and clean.has("GHOST"), "clean run earns both")
	var with_errands: RefCounted = Profile.new()
	with_errands.catalog = load("res://scripts/level_catalog.gd")
	var errand: Array[String] = Achievements.end_of_run(_run("h05", true, 90.0), with_errands)
	_expect(errand.has("FIRST_EXTRACT") and errand.has("UNTOUCHED"), "a highland errand counts as a campaign extraction")
	var hit: Array[String] = Achievements.end_of_run(_run("l01", true, 90.0, {"damage_taken": 12.0, "shots": 4}), profile)
	_expect(not hit.has("UNTOUCHED") and not hit.has("GHOST"), "damaged shooter earns neither")
	var lost: Array[String] = Achievements.end_of_run(_run("l01", false, 90.0), profile)
	_expect(not lost.has("FIRST_EXTRACT"), "a failed run earns nothing")
	var practice: Array[String] = Achievements.end_of_run(_run("range", true, 90.0), profile)
	_expect(not practice.has("FIRST_EXTRACT"), "practice earns no extraction award")
	# Progress-based awards.
	_expect(Achievements.progress_unlocks(profile).is_empty(), "no progress, no awards")
	profile.levels["l01"] = {"completed": true, "medal": 3, "bonus_found": [0, 1]}
	_expect(Achievements.progress_unlocks(profile).has("GOLD_ANY"), "any gold medal")
	_expect(not Achievements.progress_unlocks(profile).has("GOLD_ALL"), "one gold is not all gold")
	for id: String in ["l01", "l02", "l03"]:
		profile.levels[id] = {"completed": true, "medal": 3, "bonus_found": [0, 1]}
	_expect(Achievements.progress_unlocks(profile).has("ZONE_FLOODWORKS"), "floodworks cleared")
	_expect(not Achievements.progress_unlocks(profile).has("ZONE_FOUNDRY"), "foundry not cleared")
	for id: String in ["h01", "h02", "h03", "h04"]:
		profile.levels[id] = {"completed": true, "medal": 1}
	_expect(not Achievements.progress_unlocks(profile).has("ZONE_HIGHLANDS"), "four errands of five are not Bath Time")
	profile.levels["h05"] = {"completed": true, "medal": 1}
	_expect(Achievements.progress_unlocks(profile).has("ZONE_HIGHLANDS"), "every errand for the princess earns Bath Time")
	for id: String in Achievements.CAMPAIGN:
		profile.levels[id] = {"completed": true, "medal": 3, "bonus_found": [0, 1]}
	var all: Array[String] = Achievements.progress_unlocks(profile)
	for id: String in ["GOLD_ANY", "GOLD_ALL", "ZONE_FLOODWORKS", "ZONE_FOUNDRY", "ZONE_SPILLWAY", "SCAVENGER"]:
		_expect(all.has(id), "full campaign earns %s" % id)
	_expect(not all.has("FULLY_RIGGED"), "upgrades not maxed")
	profile.levels["l05"] = {"completed": true, "medal": 3, "bonus_found": [0]}
	_expect(not Achievements.progress_unlocks(profile).has("SCAVENGER"), "a missing bonus cache blocks SCAVENGER")
	for id: String in Upgrades.ORDER:
		profile.upgrades[id] = 4
	_expect(Achievements.progress_unlocks(profile).has("FULLY_RIGGED"), "all upgrades maxed")
	# Without the catalog, bonus achievements cannot be earned early.
	var bare: RefCounted = _fresh()
	bare.catalog = null
	for id: String in Achievements.CAMPAIGN:
		bare.levels[id] = {"completed": true, "medal": 3, "bonus_found": [0, 1]}
	_expect(not Achievements.progress_unlocks(bare).has("SCAVENGER"), "SCAVENGER needs catalog data")
	_expect(Achievements.progress_unlocks(null).is_empty(), "null profile is safe")


# --- Settings helpers -------------------------------------------------------------------------

func _test_engine_helpers() -> void:
	var settings: Dictionary = Profile.defaults_for(false)
	Settings.apply_engine(settings, false)
	Settings.apply_audio(settings)
	_eq(Settings.scaling_mode_for(1.0, "forward_plus"), Viewport.SCALING_3D_MODE_BILINEAR, "full scale uses bilinear")
	_eq(Settings.scaling_mode_for(0.8, "forward_plus"), Viewport.SCALING_3D_MODE_FSR, "reduced scale uses FSR on Forward+")
	_eq(Settings.scaling_mode_for(0.8, "gl_compatibility"), Viewport.SCALING_3D_MODE_BILINEAR, "Compatibility only has bilinear")
	_eq(Engine.max_fps, 0, "unlimited fps applied")
	var capped: Dictionary = Profile.defaults_for(true)
	Settings.apply_engine(capped, false)
	_eq(Engine.max_fps, 60, "mobile fps cap applied")
	Engine.max_fps = 0
