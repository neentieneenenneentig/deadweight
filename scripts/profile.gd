extends RefCounted
## The player's persistent profile: bank, upgrades, level records, settings, achievements, stats.
## Stored as a versioned ConfigFile. Saving writes <path>.tmp and renames it into place, keeping
## the previous save as <path>.bak. A missing or damaged file falls back to the backup, then to
## defaults; a damaged main file is set aside as <path>.corrupt on the next save. Nothing here
## ever stops the game: a broken disk just leaves the defaults in memory.

const SAVE_PATH := "user://profile.cfg"
const VERSION := 1
const FILE_HEADER := "; DEADWEIGHT profile. Values are validated on load.\n"
const FILE_TRAILER := "; end of profile\n"
const CATALOG_PATH := "res://scripts/level_catalog.gd"
const UpgradesScript = preload("res://scripts/upgrades.gd")
const AchievementsScript = preload("res://scripts/achievements.gd")

## Economy (DESIGN): per required case, per bonus cache, first-time medal bonus by medal tier.
const CASE_REWARD := 15
const BONUS_REWARD := 30
const MEDAL_BONUS := [0, 10, 25, 50]
const MEDAL_NAMES := ["NONE", "BRONZE", "SILVER", "GOLD"]
const ALWAYS_UNLOCKED := ["tutorial", "l01", "range"]

## Section 5.2 desktop defaults. Mobile overrides are applied in defaults().
const DEFAULT_SETTINGS := {
	"difficulty": 1,
	"look_sensitivity": 1.0,
	"gamepad_sensitivity": 1.0,
	"invert_y": false,
	"fov": 78.0,
	"camera_shake": 1.0,
	"auto_cut": true,
	"show_telemetry": true,
	"master_volume": 0.9,
	"music_volume": 0.6,
	"sfx_volume": 0.9,
	"window_mode": "fullscreen",
	"vsync": true,
	"max_fps": 0,
	"quality": 2,
	"render_scale": 1.0,
	"touch_scale": 1.0,
	"touch_opacity": 0.8,
	"touch_left_handed": false,
	"haptics": true,
}
const MOBILE_SETTINGS := {"max_fps": 60, "quality": 1, "render_scale": 0.85}
const SETTING_RANGES := {
	"difficulty": [0, 2],
	"look_sensitivity": [0.2, 3.0],
	"gamepad_sensitivity": [0.2, 3.0],
	"fov": [60.0, 95.0],
	"camera_shake": [0.0, 1.0],
	"master_volume": [0.0, 1.0],
	"music_volume": [0.0, 1.0],
	"sfx_volume": [0.0, 1.0],
	"quality": [0, 2],
	"render_scale": [0.5, 1.0],
	"touch_scale": [0.75, 1.35],
	"touch_opacity": [0.3, 1.0],
}
const MAX_FPS_OPTIONS := [0, 30, 60, 90, 120, 144]
const WINDOW_MODES := ["windowed", "fullscreen"]

var path: String = SAVE_PATH
var bank: int = 0                       # spendable salvage
var lifetime_salvage: int = 0
var tutorial_done: bool = false
var upgrades: Dictionary = {}           # upgrade id -> tier 0..4
var levels: Dictionary = {}             # level id -> record (5.4)
var settings: Dictionary = {}           # always complete
var achievements: Dictionary = {}       # achievement id -> true
var stats: Dictionary = {}              # lifetime counters (5.4)

## Picks the mobile defaults. Tests may flip it before load_profile().
var mobile: bool = OS.has_feature("mobile")
## --unlock-all: every level counts as unlocked. Never saved.
var unlock_all: bool = false
## level_catalog.gd (par times, campaign order). Tests may assign a stub script.
var catalog: Script
## True when the last load_profile() fell back to <path>.bak.
var restored_from_backup: bool = false
## Result of the last save_profile().
var last_error: Error = OK

var _main_file_ok: bool = false


func _init() -> void:
	if ResourceLoader.exists(CATALOG_PATH):
		catalog = load(CATALOG_PATH) as Script
	_apply_defaults()


# --- Defaults ---------------------------------------------------------------------------------

static func defaults_for(is_mobile: bool) -> Dictionary:
	var result: Dictionary = DEFAULT_SETTINGS.duplicate(true)
	if is_mobile:
		result.merge(MOBILE_SETTINGS, true)
	return result


## Complete default settings for this device (5.2, mobile overrides applied).
func defaults() -> Dictionary:
	return defaults_for(mobile)


static func default_record() -> Dictionary:
	return {"completed": false, "best_time": -1.0, "medal": 0, "bonus_found": [], "attempts": 0, "extractions": 0}


static func default_stats() -> Dictionary:
	return {
		"play_time": 0.0, "casts": 0, "kills": 0, "smash_kills": 0, "deaths": 0,
		"extractions": 0, "salvage_earned": 0, "max_speed": 0.0, "max_airtime": 0.0,
	}


func _apply_defaults() -> void:
	bank = 0
	lifetime_salvage = 0
	tutorial_done = false
	upgrades = {}
	for id: String in UpgradesScript.ORDER:
		upgrades[id] = 0
	levels = {}
	settings = defaults()
	achievements = {}
	stats = default_stats()


# --- Load / save ------------------------------------------------------------------------------

func load_profile(at_path: String = SAVE_PATH) -> void:
	path = at_path
	restored_from_backup = false
	_main_file_ok = false
	_apply_defaults()
	var config: ConfigFile = _read_file(path)
	if config != null:
		_read(config)
		_main_file_ok = true
		return
	# A .tmp only survives when the final rename failed, so it may be newer than the .bak.
	var newest_time: int = -1
	for candidate: String in [path + ".tmp", path + ".bak"]:
		var parsed: ConfigFile = _read_file(candidate)
		var modified: int = FileAccess.get_modified_time(candidate) if parsed != null else -1
		if parsed != null and modified > newest_time:
			config = parsed
			newest_time = modified
	if config != null:
		_read(config)
		restored_from_backup = true
		save_profile()


func save_profile() -> void:
	var config := ConfigFile.new()
	config.set_value("profile", "version", VERSION)
	config.set_value("profile", "bank", bank)
	config.set_value("profile", "lifetime_salvage", lifetime_salvage)
	config.set_value("profile", "tutorial_done", tutorial_done)
	for id: String in UpgradesScript.ORDER:
		config.set_value("upgrades", id, upgrade_tier(id))
	var level_ids: Array = levels.keys()
	level_ids.sort()
	for id: String in level_ids:
		config.set_value("levels", id, levels[id])
	for key: String in DEFAULT_SETTINGS:
		config.set_value("settings", key, setting(key))
	for id: String in AchievementsScript.ids():
		if achievements.has(id):
			config.set_value("achievements", id, true)
	for key: String in stats:
		config.set_value("stats", key, stats[key])
	last_error = _write_safely(FILE_HEADER + config.encode_to_text() + FILE_TRAILER)
	if last_error != OK:
		push_warning("Profile: could not save %s (error %d)." % [path, last_error])


## Writes the text beside the save, then swaps it in. The old save becomes the backup, unless it
## was unreadable, in which case it is kept as .corrupt so the good backup survives.
func _write_safely(text: String) -> Error:
	var folder: String = path.get_base_dir()
	if not folder.is_empty() and not DirAccess.dir_exists_absolute(folder):
		var made: Error = DirAccess.make_dir_recursive_absolute(folder)
		if made != OK:
			return made
	var temp_path: String = path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var stored: bool = file.store_string(text)
	file.close()
	if not stored:
		return ERR_FILE_CANT_WRITE
	if FileAccess.file_exists(path):
		var aside: String = path + (".bak" if _main_file_ok else ".corrupt")
		_replace_file(path, aside)
	var swapped: Error = _replace_file(temp_path, path)
	if swapped != OK:
		return swapped
	_main_file_ok = true
	return OK


static func _replace_file(from_path: String, to_path: String) -> Error:
	if FileAccess.file_exists(to_path):
		DirAccess.remove_absolute(to_path)
	return DirAccess.rename_absolute(from_path, to_path)


## The parsed profile at file_path, or null when missing, damaged or not a profile. Damage is
## detected before parsing (binary bytes, missing trailer from a cut-short write) so a broken
## file never reaches the engine parser.
static func _read_file(file_path: String) -> ConfigFile:
	if not FileAccess.file_exists(file_path):
		return null
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(file_path)
	if bytes.size() < 8 or not _is_plain_text(bytes):
		return null
	var text: String = bytes.get_string_from_ascii()
	var current: bool = text.contains("[profile]")
	if current and not text.strip_edges(false, true).ends_with(FILE_TRAILER.strip_edges()):
		return null
	if not current and not text.contains("[salvage]"):
		return null
	var config := ConfigFile.new()
	if config.parse(text) != OK:
		return null
	if current and not config.has_section_key("profile", "version"):
		return null
	return config


static func _is_plain_text(bytes: PackedByteArray) -> bool:
	for byte: int in bytes:
		if byte >= 0x80 or (byte < 0x20 and byte != 0x09 and byte != 0x0a and byte != 0x0d):
			return false
	return true


func _read(config: ConfigFile) -> void:
	if not config.has_section_key("profile", "version"):
		# Prototype save: only the salvage bank existed.
		bank = maxi(0, _int(config.get_value("salvage", "bank", 0)))
		lifetime_salvage = bank
		return
	bank = maxi(0, _int(config.get_value("profile", "bank", 0)))
	lifetime_salvage = maxi(0, _int(config.get_value("profile", "lifetime_salvage", 0)))
	tutorial_done = _to_bool(config.get_value("profile", "tutorial_done", false), false)
	for id: String in UpgradesScript.ORDER:
		upgrades[id] = UpgradesScript.tier_of({id: config.get_value("upgrades", id, 0)}, id)
	if config.has_section("levels"):
		for id: String in config.get_section_keys("levels"):
			var raw: Variant = config.get_value("levels", id, null)
			if raw is Dictionary:
				levels[id] = _normalize_record(raw)
	if config.has_section("settings"):
		for key: String in config.get_section_keys("settings"):
			if DEFAULT_SETTINGS.has(key):
				settings[key] = validate_setting(key, config.get_value("settings", key, null), settings[key])
	if config.has_section("achievements"):
		for id: String in config.get_section_keys("achievements"):
			if not AchievementsScript.find(id).is_empty() and _to_bool(config.get_value("achievements", id, false), false):
				achievements[id] = true
	for key: String in stats.keys():
		stats[key] = _clean_stat(stats[key], config.get_value("stats", key, stats[key]))


static func _normalize_record(raw: Dictionary) -> Dictionary:
	var record: Dictionary = default_record()
	record["completed"] = _to_bool(raw.get("completed", false), false)
	var best: float = _float(raw.get("best_time", -1.0))
	record["best_time"] = best if best > 0.0 else -1.0
	record["medal"] = clampi(_int(raw.get("medal", 0)), 0, 3)
	record["bonus_found"] = _index_set(raw.get("bonus_found", []))
	record["attempts"] = maxi(0, _int(raw.get("attempts", 0)))
	record["extractions"] = maxi(0, _int(raw.get("extractions", 0)))
	return record


## Keeps the default's type; negative, non-finite or non-numeric values reset to the default.
static func _clean_stat(default_value: Variant, raw: Variant) -> Variant:
	var number: float = _float(raw)
	if number < 0.0:
		return default_value
	if default_value is int:
		return int(number)
	return number


# --- Settings ---------------------------------------------------------------------------------

func setting(key: String) -> Variant:
	if settings.has(key):
		return settings[key]
	return defaults().get(key)


## Stores a validated value; unknown keys are ignored.
func set_setting(key: String, value: Variant) -> void:
	if not DEFAULT_SETTINGS.has(key):
		return
	var current: Variant = settings.get(key, defaults()[key])
	settings[key] = validate_setting(key, value, current)


## A valid value for key built from value: clamped to its range, snapped to its options, or
## `fallback` when value is unusable. Returns null for keys that are not settings.
static func validate_setting(key: String, value: Variant, fallback: Variant) -> Variant:
	if not DEFAULT_SETTINGS.has(key):
		return null
	var template: Variant = DEFAULT_SETTINGS[key]
	if template is bool:
		return _to_bool(value, _to_bool(fallback, bool(template)))
	if template is String:
		var text: String = str(value) if (value is String or value is StringName) else ""
		if key == "window_mode" and not WINDOW_MODES.has(text):
			return str(fallback) if WINDOW_MODES.has(str(fallback)) else str(template)
		return text
	var number: float = _float(value, NAN)
	if is_nan(number):
		number = _float(fallback, float(template))
	if key == "max_fps":
		return _nearest_fps(number)
	var limits: Array = SETTING_RANGES[key]
	if template is int:
		return clampi(roundi(number), int(limits[0]), int(limits[1]))
	return clampf(number, float(limits[0]), float(limits[1]))


static func _nearest_fps(value: float) -> int:
	if value <= 0.0:
		return 0
	var best: int = int(MAX_FPS_OPTIONS[1])
	for option: int in MAX_FPS_OPTIONS:
		if option > 0 and absf(value - option) < absf(value - best):
			best = option
	return best


# --- Levels -----------------------------------------------------------------------------------

## Complete record for a level (5.4); a copy, so editing it changes nothing.
func level_record(id: String) -> Dictionary:
	var record: Dictionary = default_record()
	if levels.has(id):
		record.merge(levels[id], true)
	return record.duplicate(true)


func is_unlocked(id: String) -> bool:
	if unlock_all or ALWAYS_UNLOCKED.has(id):
		return true
	var order: Array[String] = campaign_ids()
	var index: int = order.find(id)
	if index <= 0:
		return false
	return bool(level_record(order[index - 1])["completed"])


## Playable campaign levels in order (from the catalog, else the DESIGN list).
func campaign_ids() -> Array[String]:
	var result: Array[String] = []
	var from_catalog: Variant = _catalog_call("campaign_ids", [], null)
	var source: Array = from_catalog if from_catalog is Array else AchievementsScript.CAMPAIGN
	for id: Variant in source:
		result.append(str(id))
	return result


## The campaign level after id, or "" when id is last or not a campaign level.
func next_campaign_id(id: String) -> String:
	var order: Array[String] = campaign_ids()
	var index: int = order.find(id)
	if index < 0 or index + 1 >= order.size():
		return ""
	return order[index + 1]


## Catalog INFO for a level, or {} when the catalog is unavailable.
func level_info(id: String) -> Dictionary:
	var info: Variant = _catalog_call("info", [id], {})
	return info if info is Dictionary else {}


## 0 none, 1 bronze (extracted), 2 silver (time <= par_silver), 3 gold (time <= par_gold).
static func medal_for(time: float, par_silver: float, par_gold: float) -> int:
	if par_gold > 0.0 and time <= par_gold:
		return 3
	if par_silver > 0.0 and time <= par_silver:
		return 2
	return 1


func _catalog_call(method: String, args: Array, fallback: Variant) -> Variant:
	if catalog == null or not catalog.has_method(method):
		return fallback
	return catalog.callv(method, args)


# --- Upgrades ---------------------------------------------------------------------------------

func upgrade_tier(id: String) -> int:
	return UpgradesScript.tier_of(upgrades, id)


func upgrade_cost(id: String) -> int:
	return UpgradesScript.cost_for(id, upgrade_tier(id))


func can_purchase(id: String) -> bool:
	var cost: int = upgrade_cost(id)
	return cost >= 0 and bank >= cost


func purchase(id: String) -> bool:
	if not can_purchase(id):
		return false
	bank -= upgrade_cost(id)
	upgrades[id] = upgrade_tier(id) + 1
	return true


# --- Runs -------------------------------------------------------------------------------------

## Records a finished run (5.5 input) and pays its rewards. Returns the 5.5 output.
## Practice runs are not recorded; failed runs count an attempt and a death and pay nothing.
func record_run(run: Dictionary) -> Dictionary:
	var level_id: String = str(run.get("level_id", ""))
	var info: Dictionary = level_info(level_id)
	var record: Dictionary = level_record(level_id)
	var result: Dictionary = {
		"salvage": 0, "breakdown": [], "medal": 0, "previous_medal": int(record["medal"]),
		"best_time": float(record["best_time"]), "new_best": false, "first_clear": false,
		"next_unlocked": "",
	}
	if level_id.is_empty() or bool(info.get("practice", level_id == "range")):
		return result
	add_play_stats(run)
	record["attempts"] = int(record["attempts"]) + 1
	if not _to_bool(run.get("won", false), false):
		stats["deaths"] = int(stats["deaths"]) + 1
		levels[level_id] = record
		return result
	var next_id: String = next_campaign_id(level_id)
	var next_was_locked: bool = not next_id.is_empty() and not is_unlocked(next_id)
	var time: float = maxf(0.0, _float(run.get("time", 0.0)))
	var par_silver: float = _float(info.get("par_silver", run.get("par_silver", 0.0)))
	var par_gold: float = _float(info.get("par_gold", run.get("par_gold", 0.0)))
	var medal: int = medal_for(time, par_silver, par_gold)
	var breakdown: Array = []
	var cases: int = maxi(0, _int(run.get("cases", 0)))
	if cases > 0:
		breakdown.append(["CASES x%d" % cases, cases * CASE_REWARD])
	var bonus: Array = _index_set(run.get("bonus_indices", []))
	if not bonus.is_empty():
		breakdown.append(["BONUS CACHES x%d" % bonus.size(), bonus.size() * BONUS_REWARD])
	for tier in range(int(record["medal"]) + 1, medal + 1):
		breakdown.append(["FIRST %s MEDAL" % MEDAL_NAMES[tier], int(MEDAL_BONUS[tier])])
	var salvage: int = 0
	for line: Array in breakdown:
		salvage += int(line[1])
	var first_clear: bool = not bool(record["completed"])
	var previous_best: float = float(record["best_time"])
	var new_best: bool = previous_best < 0.0 or time < previous_best
	record["completed"] = true
	record["medal"] = maxi(int(record["medal"]), medal)
	record["extractions"] = int(record["extractions"]) + 1
	if new_best:
		record["best_time"] = time
	var found: Array = record["bonus_found"]
	found.append_array(bonus)
	record["bonus_found"] = _index_set(found)
	levels[level_id] = record
	bank += salvage
	lifetime_salvage += salvage
	stats["salvage_earned"] = int(stats["salvage_earned"]) + salvage
	stats["extractions"] = int(stats["extractions"]) + 1
	if level_id == "tutorial":
		tutorial_done = true
	result["salvage"] = salvage
	result["breakdown"] = breakdown
	result["medal"] = medal
	result["best_time"] = float(record["best_time"])
	result["new_best"] = new_best
	result["first_clear"] = first_clear
	if next_was_locked and is_unlocked(next_id):
		result["next_unlocked"] = next_id
	return result


## Adds a session's play time, casts, kills and records to the lifetime stats (no rewards).
## record_run() calls this; main.gd calls it directly for practice sessions.
func add_play_stats(run: Dictionary) -> void:
	stats["play_time"] = float(stats["play_time"]) + maxf(0.0, _float(run.get("time", 0.0)))
	for key: String in ["casts", "kills", "smash_kills"]:
		stats[key] = int(stats[key]) + maxi(0, _int(run.get(key, 0)))
	for key: String in ["max_speed", "max_airtime"]:
		stats[key] = maxf(float(stats[key]), _float(run.get(key, 0.0)))


# --- Achievements / reset ---------------------------------------------------------------------

## True only when the id is a known achievement that was not unlocked before.
func unlock_achievement(id: String) -> bool:
	if achievements.has(id) or AchievementsScript.find(id).is_empty():
		return false
	achievements[id] = true
	return true


func has_achievement(id: String) -> bool:
	return achievements.has(id)


## Wipes progress (bank, upgrades, records, achievements, stats) but keeps settings.
func reset_progress() -> void:
	var kept: Dictionary = settings.duplicate(true)
	_apply_defaults()
	settings = kept


# --- Conversion helpers (saved data and UI values arrive as any Variant) ----------------------

static func _float(value: Variant, fallback: float = 0.0) -> float:
	var number: float = fallback
	if value is float or value is int:
		number = float(value)
	elif (value is String or value is StringName) and str(value).is_valid_float():
		number = str(value).to_float()
	return number if is_finite(number) else fallback


static func _int(value: Variant, fallback: int = 0) -> int:
	var number: float = _float(value, NAN)
	return fallback if is_nan(number) else roundi(number)


static func _to_bool(value: Variant, fallback: bool) -> bool:
	if value is bool:
		return value
	if value is int or value is float:
		return float(value) != 0.0
	if value is String or value is StringName:
		var text: String = str(value).strip_edges().to_lower()
		if text in ["true", "1", "yes", "on"]:
			return true
		if text in ["false", "0", "no", "off"]:
			return false
	return fallback


## Sorted unique non-negative integers from any array-like value.
static func _index_set(value: Variant) -> Array:
	var result: Array = []
	if not (value is Array or value is PackedInt32Array or value is PackedInt64Array):
		return result
	for item: Variant in value:
		var index: int = _int(item, -1)
		if index >= 0 and not result.has(index):
			result.append(index)
	result.sort()
	return result
