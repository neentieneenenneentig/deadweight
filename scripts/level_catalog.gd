extends RefCounted
## The list of levels (CONTRACT 4.12): campaign order, zones, and how to make a level.
## A level that has no script yet is still listed (so menus can show it as coming soon) but is
## "available": false and never appears in campaign_ids().
## Usage: const Catalog = preload("res://scripts/level_catalog.gd"); Catalog.create("l01")

const ZONES := {
	"floodworks": {"title": "FLOODWORKS", "accent": Color("8cbdd2")},
	"foundry": {"title": "FOUNDRY", "accent": Color("d353c9")},
	"spillway": {"title": "SPILLWAY", "accent": Color("8fbccb")},
	"highlands": {"title": "HIGHLANDS", "accent": Color("accdda")},
}

## Campaign order, then the practice range. "practice" is known here too so the profile can tell
## the range apart before its script exists.
const LEVELS := [
	{"id": "tutorial", "script": "res://scripts/levels/tutorial.gd"},
	{"id": "l01", "script": "res://scripts/levels/l01_sluice.gd"},
	{"id": "l02", "script": "res://scripts/levels/l02_pump_row.gd"},
	{"id": "l03", "script": "res://scripts/levels/l03_overflow.gd"},
	{"id": "l04", "script": "res://scripts/levels/l04_slag_line.gd"},
	{"id": "l05", "script": "res://scripts/levels/l05_crane_yard.gd"},
	{"id": "l06", "script": "res://scripts/levels/l06_crucible.gd"},
	{"id": "h01", "script": "res://scripts/levels/h01_the_duck.gd"},
	{"id": "l07", "script": "res://scripts/levels/l07_the_steps.gd"},
	{"id": "l08", "script": "res://scripts/levels/l08_damwall.gd"},
	{"id": "l09", "script": "res://scripts/levels/l09_headwater.gd"},
	{"id": "range", "script": "res://scripts/levels/range.gd", "practice": true},
	{"id": "valley", "script": "res://scripts/levels/valley.gd", "practice": true},
]


## Campaign level ids (tutorial..l09) whose script exists, in order.
static func campaign_ids() -> Array[String]:
	var result: Array[String] = []
	for entry: Dictionary in LEVELS:
		if not bool(entry.get("practice", false)) and _exists(entry):
			result.append(str(entry["id"]))
	return result


## Every listed level id, available or not, campaign order then the range.
static func all_ids() -> Array[String]:
	var result: Array[String] = []
	for entry: Dictionary in LEVELS:
		result.append(str(entry["id"]))
	return result


## The catalog entry merged with the level script's INFO (CONTRACT 5.6) plus "id", "script" and
## "available". An unknown id gives {}. Reads the script's constants; it builds nothing.
static func info(id: String) -> Dictionary:
	var entry: Dictionary = _entry(id)
	if entry.is_empty():
		return {}
	var result: Dictionary = entry.duplicate(true)
	result["available"] = _exists(entry)
	if bool(result["available"]):
		var script: Script = load(str(entry["script"])) as Script
		var declared: Variant = script.get_script_constant_map().get("INFO", {}) if script != null else {}
		if declared is Dictionary:
			result.merge(declared, true)
	return result


## A new level instance with level_id set, or null when the level has no script.
static func create(id: String) -> Node3D:
	var entry: Dictionary = _entry(id)
	if entry.is_empty() or not _exists(entry):
		return null
	var script: Script = load(str(entry["script"])) as Script
	if script == null:
		return null
	var level: Node3D = script.new()
	level.set("level_id", id)
	return level


## The level after id in campaign order ("" for the last level, the range or unknown ids).
static func next_id(id: String) -> String:
	var order: Array[String] = campaign_ids()
	var index: int = order.find(id)
	if index < 0 or index + 1 >= order.size():
		return ""
	return order[index + 1]


## Available levels in a zone, in campaign order (the tutorial and the range count as floodworks
## only when their INFO says so).
static func zone_ids(zone: String) -> Array[String]:
	var result: Array[String] = []
	for id: String in all_ids():
		var details: Dictionary = info(id)
		if bool(details.get("available", false)) and str(details.get("zone", "")) == zone:
			result.append(id)
	return result


static func _entry(id: String) -> Dictionary:
	for entry: Dictionary in LEVELS:
		if entry["id"] == id:
			return entry
	return {}


static func _exists(entry: Dictionary) -> bool:
	return ResourceLoader.exists(str(entry["script"]))
