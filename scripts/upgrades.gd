extends RefCounted
## Workshop upgrade tracks: static data plus the stat dictionary handed to player/tether.
## Usage: const Upgrades = preload("res://scripts/upgrades.gd"); Upgrades.stats(profile.upgrades)
## Tier 0 is the stock rig; tiers 1..4 are bought in order for COSTS[tier].

const ORDER := ["spool", "reel", "weight", "plating", "quickdraw", "sidearm"]
const COSTS := [30, 55, 85, 120]
## Cast assist force per kilogram of sinker: heavier weights keep the same launch feel.
const ASSIST_PER_KG := 60.0   # cut from 100 on 2026-11-04 (S1), along with tether's cast impulse

## "values" holds one entry per tier (0..4). Tracks that drive two stats store pairs in the
## order of their "stats" list. "stats" names the 5.1 keys a track changes.
const DEFS := {
	"spool": {
		"title": "SPOOL",
		"desc": "A deeper spool pays out more line: longer casts, wider swings, higher catches.",
		"stat_label": "MAX LINE",
		"stats": ["max_line"],
		"values": [40.0, 48.0, 56.0, 64.0, 72.0],
	},
	"reel": {
		"title": "REEL MOTOR",
		"desc": "A stronger motor reels in harder and faster before it stalls under load.",
		"stat_label": "REEL FORCE / SPEED",
		"stats": ["reel_force", "reel_speed"],
		"values": [[14000.0, 9.0], [16000.0, 10.5], [18500.0, 12.0], [21000.0, 13.5], [24000.0, 15.0]],
	},
	"weight": {
		"title": "SINKER",
		"desc": "Heavier weights smash harder and pull harder once the line goes taut.",
		"stat_label": "WEIGHT MASS",
		"stats": ["weight_mass", "assist_strength"],
		"values": [130.0, 145.0, 160.0, 175.0, 190.0],
	},
	"plating": {
		"title": "PLATING",
		"desc": "Armour plates under the jacket. Shrug off more bites, shots and bad landings.",
		"stat_label": "MAX HEALTH",
		"stats": ["max_health"],
		"values": [100.0, 120.0, 140.0, 165.0, 190.0],
	},
	"quickdraw": {
		"title": "QUICKDRAW",
		"desc": "A stiffer rod blank reaches a full-power cast sooner.",
		"stat_label": "FULL CHARGE",
		"stats": ["charge_time"],
		"values": [0.80, 0.68, 0.56, 0.46, 0.38],
	},
	"sidearm": {
		"title": "SIDEARM",
		"desc": "Extended magazine and hotter rounds for the backup pistol.",
		"stat_label": "MAGAZINE / DAMAGE",
		"stats": ["magazine", "sidearm_damage"],
		"values": [[10, 30.0], [12, 34.0], [14, 38.0], [16, 42.0], [20, 48.0]],
	},
}


static func max_tier() -> int:
	return COSTS.size()


## Section 5.1 stats for the given tiers (missing or invalid tiers count as 0).
static func stats(tiers: Dictionary) -> Dictionary:
	var reel: Array = _value("reel", tiers)
	var sidearm: Array = _value("sidearm", tiers)
	var mass: float = float(_value("weight", tiers))
	return {
		"max_line": float(_value("spool", tiers)),
		"reel_force": float(reel[0]),
		"reel_speed": float(reel[1]),
		"weight_mass": mass,
		"assist_strength": mass * ASSIST_PER_KG,
		"charge_time": float(_value("quickdraw", tiers)),
		"max_health": float(_value("plating", tiers)),
		"magazine": int(sidearm[0]),
		"sidearm_damage": float(sidearm[1]),
	}


## Short uppercase readout of a track at a tier, e.g. "48 M LINE".
static func describe(id: String, tier: int) -> String:
	if not DEFS.has(id):
		return ""
	var values: Array = DEFS[id]["values"]
	var value: Variant = values[clampi(tier, 0, max_tier())]
	match id:
		"spool":
			return "%d M LINE" % int(value)
		"reel":
			var pair: Array = value
			return "%s KN / %s M/S" % [_trim(float(pair[0]) / 1000.0), _trim(float(pair[1]))]
		"weight":
			return "%d KG SINKER" % int(value)
		"plating":
			return "%d MAX HEALTH" % int(value)
		"quickdraw":
			return "%.2f S FULL CHARGE" % float(value)
		"sidearm":
			var pair: Array = value
			return "%d ROUNDS / %d DMG" % [int(pair[0]), int(pair[1])]
	return ""


## Price of the next tier, or -1 when the track is maxed (or unknown).
static func cost_for(id: String, tier: int) -> int:
	if not DEFS.has(id) or tier < 0 or tier >= max_tier():
		return -1
	return int(COSTS[tier])


## Valid tier for a track from a tiers dictionary (saved data may be damaged).
static func tier_of(tiers: Dictionary, id: String) -> int:
	var raw: Variant = tiers.get(id, 0)
	if not (raw is int or raw is float):
		return 0
	return clampi(int(raw), 0, max_tier())


static func all_maxed(tiers: Dictionary) -> bool:
	for id: String in ORDER:
		if tier_of(tiers, id) < max_tier():
			return false
	return true


## Salvage needed to max every track from scratch.
static func total_cost() -> int:
	var per_track: int = 0
	for cost: int in COSTS:
		per_track += cost
	return per_track * ORDER.size()


static func _value(id: String, tiers: Dictionary) -> Variant:
	var values: Array = DEFS[id]["values"]
	return values[tier_of(tiers, id)]


## 14.0 -> "14", 18.5 -> "18.5".
static func _trim(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%.1f" % value
