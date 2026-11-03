extends RefCounted
## Achievement table (DESIGN order) and the rules that award them.
## Local unlock state lives in profile.gd; Steam is told by platform.gd.
## Live achievements (FIRST_CAST, FIRST_ANCHOR, HANG_TIME, TERMINAL, DEADWEIGHT) are awarded by
## main.gd during play; end_of_run() covers everything decided by a finished run or saved progress.

const LIST := [
	{"id": "FIRST_CAST", "title": "Gone Fishing", "desc": "Cast your first weight."},
	{"id": "FIRST_ANCHOR", "title": "Magnetic Personality", "desc": "Latch a weight onto an anchor plate."},
	{"id": "GRADUATE", "title": "Inducted", "desc": "Complete the Induction."},
	{"id": "FIRST_EXTRACT", "title": "Bring Something Back", "desc": "Extract from any campaign level."},
	{"id": "HANG_TIME", "title": "Hang Time", "desc": "Stay airborne for 12 seconds straight."},
	{"id": "TERMINAL", "title": "Terminal Velocity", "desc": "Reach 45 m/s."},
	{"id": "DEADWEIGHT", "title": "Dead Weight", "desc": "Destroy an enemy with a swinging weight."},
	{"id": "UNTOUCHED", "title": "Untouched", "desc": "Extract from a level with enemies without taking damage."},
	{"id": "GHOST", "title": "Ghost", "desc": "Extract from a level with enemies without firing the sidearm."},
	{"id": "SCAVENGER", "title": "Scavenger", "desc": "Find every bonus cache in the campaign."},
	{"id": "ZONE_FLOODWORKS", "title": "Drained", "desc": "Complete every Floodworks level (tutorial excluded)."},
	{"id": "ZONE_FOUNDRY", "title": "Cooled Off", "desc": "Complete every Foundry level."},
	{"id": "ZONE_SPILLWAY", "title": "Over the Top", "desc": "Complete every Spillway level."},
	{"id": "GOLD_ANY", "title": "Gold Standard", "desc": "Earn any gold medal."},
	{"id": "GOLD_ALL", "title": "Master Angler", "desc": "Earn gold on every campaign level (tutorial excluded)."},
	{"id": "FULLY_RIGGED", "title": "Fully Rigged", "desc": "Max out every workshop upgrade."},
]

const HANG_TIME_SECONDS := 12.0
const TERMINAL_SPEED := 45.0
## The full campaign from DESIGN. Completion achievements need every one of these levels,
## so a build that is missing levels can never award them early.
const CAMPAIGN := ["tutorial", "l01", "l02", "l03", "l04", "l05", "l06", "l07", "l08", "l09"]
const ZONE_LEVELS := {
	"ZONE_FLOODWORKS": ["l01", "l02", "l03"],
	"ZONE_FOUNDRY": ["l04", "l05", "l06"],
	"ZONE_SPILLWAY": ["l07", "l08", "l09"],
}
const UpgradesScript = preload("res://scripts/upgrades.gd")


## The LIST entry for an id, or {} when unknown.
static func find(id: String) -> Dictionary:
	for entry: Dictionary in LIST:
		if entry["id"] == id:
			return entry
	return {}


static func ids() -> Array[String]:
	var result: Array[String] = []
	for entry: Dictionary in LIST:
		result.append(str(entry["id"]))
	return result


static func title_of(id: String) -> String:
	return str(find(id).get("title", id))


## Achievements satisfied by a finished run (5.5 summary). Call after profile.record_run(run)
## so medals and completions are already saved. Returns ids; the caller unlocks them.
static func end_of_run(run: Dictionary, profile: RefCounted) -> Array[String]:
	var earned: Array[String] = []
	var level_id: String = str(run.get("level_id", ""))
	if bool(run.get("won", false)) and CAMPAIGN.has(level_id):
		earned.append("FIRST_EXTRACT")
		if level_id == "tutorial":
			earned.append("GRADUATE")
		if bool(run.get("enemies_present", false)):
			if float(run.get("damage_taken", 0.0)) <= 0.0:
				earned.append("UNTOUCHED")
			if int(run.get("shots", 0)) <= 0:
				earned.append("GHOST")
	for id: String in progress_unlocks(profile):
		if not earned.has(id):
			earned.append(id)
	return earned


## Achievements implied by saved progress alone (medals, zones, bonus caches, upgrades).
## Safe to call at any time, e.g. at boot to catch up after an update.
static func progress_unlocks(profile: RefCounted) -> Array[String]:
	var earned: Array[String] = []
	if profile == null:
		return earned
	var all_gold: bool = true
	var any_gold: bool = false
	for id: String in CAMPAIGN:
		var medal: int = int(profile.level_record(id).get("medal", 0))
		any_gold = any_gold or medal >= 3
		if id != "tutorial" and medal < 3:
			all_gold = false
	if any_gold:
		earned.append("GOLD_ANY")
	if all_gold:
		earned.append("GOLD_ALL")
	for achievement: String in ZONE_LEVELS:
		if _all_completed(profile, ZONE_LEVELS[achievement]):
			earned.append(achievement)
	if _all_bonus_found(profile):
		earned.append("SCAVENGER")
	if UpgradesScript.all_maxed(profile.upgrades):
		earned.append("FULLY_RIGGED")
	return earned


static func _all_completed(profile: RefCounted, level_ids: Array) -> bool:
	for id: String in level_ids:
		if not bool(profile.level_record(id).get("completed", false)):
			return false
	return true


## Every campaign level must be known to the catalog (its bonus count comes from INFO).
static func _all_bonus_found(profile: RefCounted) -> bool:
	var catalog: Script = profile.get("catalog") as Script
	if catalog == null or not catalog.has_method("info"):
		return false
	var total: int = 0
	for id: String in CAMPAIGN:
		var info: Dictionary = catalog.call("info", id)
		if not bool(info.get("available", false)):
			return false
		var count: int = int(info.get("bonus", 0))
		total += count
		var found: Array = profile.level_record(id).get("bonus_found", [])
		for index in range(count):
			if not found.has(index):
				return false
	return total > 0
