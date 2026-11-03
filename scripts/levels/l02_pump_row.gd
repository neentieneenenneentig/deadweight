extends "res://scripts/level_base.gd"
## L02 PUMP ROW (DESIGN: Floodworks): six porcelain pump houses in two rows, under three pipe
## racks with cyan anchor plates. Swinging is the point: a weight latched to a rack plate carries the
## player over the lane. Hounds patrol the ground and one sentry watches from a roof. The three
## required cases and the extraction are on foot (ramps and open fronts); the two bonus caches sit
## on a rack beam and a roof and need the rod.

const INFO := {
	"title": "PUMP ROW",
	"zone": "floodworks",
	"number": 2,
	"blurb": "Six pump houses under pipe racks. Latch to the cyan plates and swing; hounds on the ground, one sentry on a roof.",
	"par_silver": 25.0,
	"par_gold": 15.0,
	"cases": 3,
	"bonus": 2,
	"enemies": true,
	"practice": false,
}

## Pump houses: the lane side is open, the back and sides are porcelain. "cache" moves the
## roof-top bonus onto this house (no dome on its roof).
const HOUSE_X := 15.0
const HOUSES := [
	{"side": -1.0, "z": -22.0},
	{"side": 1.0, "z": -22.0},
	{"side": -1.0, "z": -52.0},
	{"side": 1.0, "z": -52.0},
	{"side": -1.0, "z": -82.0, "cache": true},
	{"side": 1.0, "z": -82.0},
]
## Pipe racks cross the lane. Each beam's underside is ANCHOR_Y, so the plates hang flush with it.
const RACK_Z := [-37.0, -67.0, -97.0]
const RACK_Y := 9.0
const ANCHOR_Y := 8.64
## Roof top of every pump house (the roof slab is 0.5 m thick and centred at 5.0).
const ROOF_TOP := 5.25
## The plinth stands in the centre lane, reached by one ramp from the north.
const PLINTH_TOP := 3.4


func _design() -> void:
	set_zone("floodworks")
	set_spawn(Vector3(0, 0, 14))
	_build_ground()
	_build_gate()
	var number: int = 1
	for spec: Dictionary in HOUSES:
		_pump_house(float(spec["side"]), float(spec["z"]), number, bool(spec.get("cache", false)))
		number += 1
	_build_racks()
	_build_plinth()
	_build_extraction()
	_build_dressing()
	_place_objectives()
	_place_enemies()
	_place_hints()


func _build_ground() -> void:
	ground(Vector3(0, 0, -50), Vector2(60, 150), "concrete", 1.2)
	perimeter(Vector3(0, 0, -50), Vector2(59, 149), 6.0, "dark")
	# Cyan route cues run up the centre lane; they are visual only (no collision, no nav change).
	for z: float in [10.0, 2.0, -6.0, -14.0, -28.0, -44.0, -78.0, -88.0, -100.0]:
		box(Vector3(0, 0.02, z), Vector3(0.5, 0.04, 2.2), "cyan", false)
	for side: float in [-1.0, 1.0]:
		box(Vector3(side * 10.4, 0.02, -50), Vector3(0.15, 0.04, 140), "yellow", false)


func _build_gate() -> void:
	# A brass-trimmed porcelain arch at the start, echoing the l01 entrance.
	for side: float in [-1.0, 1.0]:
		box(Vector3(side * 8.5, 5.5, 8), Vector3(1.5, 11, 2), "light_concrete")
		box(Vector3(side * 8.5, 10.0, 8), Vector3(1.8, 0.3, 2.2), "yellow", false)
	box(Vector3(0, 10.4, 8), Vector3(18.5, 1.8, 2), "dark")
	box(Vector3(0, 10.3, 9.04), Vector3(15.2, 1.2, 0.1), "rust", false)
	label("P U M P   R O W", Vector3(0, 10.3, 9.12), 56, Color("f1e4c8"), 0.012)
	label("FLOODWORKS  /  DEPARTMENT OF UNFINISHED GRAVITY", Vector3(0, 8.7, 8.9), 26, Color("ffc46b"), 0.011)
	signboard("02   PUMP ROW", Vector3(-16, 2.1, 6), "DEPARTMENTAL PUMPING IS SUSPENDED", "cyan")


## One porcelain pump house: a three-sided shell open toward the lane, a plum roof, brass banding,
## a porcelain tank dome and a label on the spawn-facing wall.
func _pump_house(side: float, z: float, number: int, cache: bool) -> void:
	var cx: float = side * HOUSE_X
	# Back wall (away from the lane) and two side walls. The lane face stays open for entry.
	box(Vector3(cx + side * 4.0, 2.5, z), Vector3(0.9, 5.0, 8.8), "light_concrete")
	for side_z: float in [-1.0, 1.0]:
		box(Vector3(cx, 2.5, z + side_z * 3.95), Vector3(9.0, 5.0, 0.9), "light_concrete")
		box(Vector3(cx, 3.9, z + side_z * 4.42), Vector3(9.0, 0.22, 0.06), "yellow", false)
	box(Vector3(cx, 5.0, z), Vector3(9.6, 0.5, 9.0), "dark")
	if not cache:
		var dome_at: Vector3 = Vector3(cx + side * 2.2, ROOF_TOP + 0.8, z)
		cylinder(dome_at, 1.7, 1.6, "light_concrete", false)
		cylinder(dome_at + Vector3.UP * 0.9, 0.6, 0.25, "yellow", false)
	label("PUMP %02d  /  NOT PUMPING" % number, Vector3(cx, 2.2, z + 4.5), 30, Color("3b3146"), 0.014)


func _build_racks() -> void:
	for z: float in RACK_Z:
		box(Vector3(0, RACK_Y, z), Vector3(44, 0.6, 1.2), "rust")
		for side: float in [-1.0, 1.0]:
			cylinder(Vector3(side * 22, RACK_Y * 0.5, z), 0.45, RACK_Y, "rust")
			cylinder(Vector3(side * 22, 4.0, z), 0.6, 0.3, "yellow", false)
		# Two magnetic plates per rack, hanging from the beam underside.
		for x: float in [-5.0, 5.0]:
			anchor(Vector3(x, ANCHOR_Y, z), Vector3.DOWN)
		label("RIGGING  /  NOT FOR CLIMBING", Vector3(0, 10.2, z), 34, Color("e8d6a8"), 0.016)
	# Celadon mains run the length of the lane edges. Decoration only.
	for side: float in [-1.0, 1.0]:
		pipe(Vector3(side * 21, 7.8, 0), Vector3(side * 21, 7.8, -112), 0.35, "metal", false)


## Plinth in the centre lane: the middle case sits on it, reached by one long, low ramp.
func _build_plinth() -> void:
	platform(Vector3(0, PLINTH_TOP, -68), Vector2(6, 6), "light_concrete", true)
	# The ramp finishes on the plinth's north edge (z = -65), so its top meets the plinth top flush.
	ramp(Vector3(0, 0, -57), Vector3(0, PLINTH_TOP, -65), 4.0)
	label("THE PLINTH IS FOR CASES", Vector3(0, 4.4, -64.6), 30, Color("f1e4c8"), 0.014)


func _build_extraction() -> void:
	extraction(Vector3(0, 0, -112))
	for x: float in [-6.0, 6.0]:
		box(Vector3(x, 3.0, -119), Vector3(0.6, 6.0, 0.6), "rust")
	box(Vector3(0, 5.8, -119), Vector3(13, 0.65, 0.7), "dark")
	label("E X T R A C T I O N", Vector3(0, 5.8, -118.6), 38, Color("5ad6c8"), 0.012)
	label("BANK SALVAGE  /  HOLD POSITION", Vector3(0, 4.7, -118.6), 24, Color("d8dfca"), 0.011)
	signboard("03   RIGGING", Vector3(-7, 2.1, -104), "LAST SIGNAL   /   THEN EXTRACT", "cyan")


## Absurd domestic dressing: porcelain teacups on saucers, a red sentry marker and a deadpan notice.
## Everything here is visual only and adds no collision, light or navigation.
func _build_dressing() -> void:
	for spot: Vector3 in [Vector3(-7.5, 0, 4), Vector3(7.5, 0, -2), Vector3(8.0, 0, -40)]:
		cylinder(spot + Vector3.UP * 0.5, 0.8, 1.0, "light_concrete", false)
		cylinder(spot + Vector3.UP * 1.02, 0.85, 0.05, "yellow", false)
	box(Vector3(10.8, ROOF_TOP + 0.05, -52), Vector3(0.1, 0.1, 8.0), "red", false)
	label("SENTRY  /  ROOF", Vector3(12.5, 6.8, -49), 26, Color("ef654e"), 0.016, true)


func _place_objectives() -> void:
	case_at(Vector3(-13.5, 0, -22), "01 / PUMP HOUSE")
	case_at(Vector3(0, PLINTH_TOP, -68), "02 / THE PLINTH")
	case_at(Vector3(13.5, 0, -82), "03 / CISTERN ROW")
	# Rod-only caches: the nest rests on a rack beam, the lid on a pump-house roof with no ramp.
	platform(Vector3(0, RACK_Y + 0.32, RACK_Z[0]), Vector2(5, 2.4), "dark", false)
	bonus_at(Vector3(0, RACK_Y + 0.32, RACK_Z[0]), "RIGGING NEST")
	bonus_at(Vector3(-15, ROOF_TOP, -82), "CISTERN LID")


func _place_enemies() -> void:
	enemy("hound", Vector3(7, 0.1, -18))
	enemy("hound", Vector3(-7, 0.1, -62))
	enemy("hound", Vector3(5.5, 0.1, -100))
	enemy("sentry", Vector3(12.5, ROOF_TOP, -52))


func _place_hints() -> void:
	hint_zone(Vector3(0, 1.5, 9), Vector3(14, 3, 6), "PUMP ROW  /  charge {cast}, release, then {lock} to hold the weight", 8.0)
	hint_zone(Vector3(0, 1.5, -40), Vector3(14, 3, 6), "CYAN PLATES  /  a weight that touches one latches and swings", 6.0)
	hint_zone(Vector3(0, 1.5, -88), Vector3(14, 3, 6), "TWO CACHES ARE HIGHER UP  /  the rod reaches them, feet do not", 6.0)
