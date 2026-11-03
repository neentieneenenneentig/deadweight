extends "res://scripts/level_base.gd"
## PRACTICE RANGE (DESIGN: Practice Range): a flat sandbox for every tool before a raid. Grid and
## distance markers, platforms at 5/10/15/20/30 m, an anchor gantry, an updraft tower, a pillar
## slalom, three training dummies (E3), and one case by the extraction. Repeatable: an extraction banks the
## case and main calls reset_cases() so the run starts again.

const INFO := {
	"title": "PRACTICE RANGE",
	"zone": "floodworks",
	"number": -1,
	"blurb": "Anchors, updrafts, platforms at marked heights, a pillar slalom and dummies. No clock.",
	"par_silver": 0.0,
	"par_gold": 0.0,
	"cases": 1,
	"bonus": 0,
	"enemies": true,         # the training dummies are enemy nodes, so this must say so (levels_test)
	"practice": true,
	"repeatable": true,
}

const SPAWN := Vector3(0.0, 0.0, 20.0)
## Centre of the welcome hint zone. Tests use it to check that the zone fires once.
const HINT_ZONE_CENTER := Vector3(0.0, 1.2, 14.0)
const UPDRAFT_BASE := Vector3(22.0, 0.0, -55.0)
const UPDRAFT_SIZE := Vector3(3.6, 14.0, 3.6)
const GANTRY_Z := -70.0
## The beam's underside is at 8.7 m. A 0.12 m plate centred at 8.64 hangs flush against it.
const ANCHOR_Y := 8.64
## Distance is measured from spawn along -Z. Sides alternate so the centre lane stays open.
const PLATFORMS := [
	{"distance": 5, "height": 1.5, "x": -10.0},
	{"distance": 10, "height": 3.0, "x": 10.0},
	{"distance": 15, "height": 4.5, "x": -10.0},
	{"distance": 20, "height": 6.0, "x": 10.0},
	{"distance": 30, "height": 9.0, "x": -10.0},
]
const SLALOM := [
	Vector2(-5.0, -40.0), Vector2(5.0, -44.0), Vector2(-5.0, -48.0),
	Vector2(5.0, -52.0), Vector2(-5.0, -56.0), Vector2(5.0, -60.0),
]
## Training dummies on open floor beside the slalom, off the centre lane, clear of the gantry legs, the
## updraft tower's hint zone and the case and extraction on the far side.
const DUMMY_SPOTS := [Vector3(-16.0, 0.0, -36.0), Vector3(14.0, 0.0, -38.0), Vector3(-17.0, 0.0, -62.0)]


func _design() -> void:
	set_zone("floodworks")
	set_spawn(SPAWN)
	ground(Vector3(0.0, 0.0, -40.0), Vector2(60.0, 140.0))
	# Walls keep the player on the range; there is no drop-off to learn from here.
	perimeter(Vector3(0.0, 0.0, -40.0), Vector2(59.0, 139.0), 4.0)
	_build_grid()
	_build_distance_markers()
	_build_platforms()
	_build_gantry()
	_build_slalom()
	_build_dummies()
	_build_updraft_tower()
	_build_start()
	_build_extraction()
	_build_dressing()


## main.gd calls this after a repeatable extraction: the case is back on the floor.
func reset_cases() -> void:
	restock_cases()


## Grid lines every 5 m. The centre line is yellow so forward reads at a glance. Lines are
## non-solid and merge into the static geometry.
func _build_grid() -> void:
	for x: int in range(-25, 26, 5):
		box(Vector3(float(x), 0.015, -40.0), Vector3(0.05, 0.03, 139.0), "light_concrete", false)
	for z: int in range(-110, 31, 5):
		box(Vector3(0.0, 0.015, float(z)), Vector3(59.0, 0.03, 0.05), "light_concrete", false)
	box(Vector3(0.0, 0.017, -40.0), Vector3(0.14, 0.03, 139.0), "yellow", false)


## A post and a billboard label at each platform distance and at 40 m, so distances read off the
## ground. Closer than 5 m or between markers the labels would pile up on screen.
func _build_distance_markers() -> void:
	for distance: int in [5, 10, 15, 20, 30, 40]:
		var z: float = SPAWN.z - float(distance)
		box(Vector3(-7.0, 0.9, z), Vector3(0.14, 1.8, 0.14), "yellow", false)
		label("%d M" % distance, Vector3(-7.0, 2.1, z), 40, Color("ffc46b"), 0.02, true)


## Platforms at marked distances and heights. They are targets for the rod and a sense of scale,
## not a route the player must take.
func _build_platforms() -> void:
	for entry: Dictionary in PLATFORMS:
		var height: float = float(entry["height"])
		var top := Vector3(float(entry["x"]), height, SPAWN.z - float(entry["distance"]))
		platform(top, Vector2(4.0, 4.0), "dark", true)
		label("%d M  /  %.1f M UP" % [int(entry["distance"]), height], top + Vector3(0.0, 1.4, 0.0), 30, Color("e4ddbd"), 0.014, true)


## Anchor gantry: a beam 9 m up with cyan plates under it. Weights latch to the plates from below.
func _build_gantry() -> void:
	for x: float in [-14.0, 14.0]:
		box(Vector3(x, 4.5, GANTRY_Z), Vector3(0.9, 9.0, 0.9), "rust")
	box(Vector3(0.0, 9.0, GANTRY_Z), Vector3(30.0, 0.6, 1.2), "rust")
	for x: float in [-10.0, -4.0, 4.0, 10.0]:
		anchor(Vector3(x, ANCHOR_Y, GANTRY_Z), Vector3.DOWN)
	label("ANCHOR GANTRY  /  9 M", Vector3(0.0, 10.0, GANTRY_Z), 40, Color("67d5d2"), 0.02)


## Pillar slalom: solid pillars that force a zig-zag, so swings and wraps have things to hit.
func _build_slalom() -> void:
	for spot: Vector2 in SLALOM:
		pillar(Vector3(spot.x, 0.0, spot.y), 3.5, 0.9, "rust")
	label("PILLAR SLALOM", Vector3(0.0, 4.2, -36.0), 36, Color("e8d6a8"), 0.016, true)


## Three training dummies (E3): they never attack, flash when hit and stand back up after a kill.
func _build_dummies() -> void:
	for spot: Vector3 in DUMMY_SPOTS:
		enemy("dummy", spot)


## Updraft tower: a 14 m rising column with a catch platform on top. The platform's legs frame the
## column without standing inside it.
func _build_updraft_tower() -> void:
	updraft(UPDRAFT_BASE, UPDRAFT_SIZE, 26.0)
	platform(UPDRAFT_BASE + Vector3(0.0, UPDRAFT_SIZE.y, 0.0), Vector2(6.0, 6.0), "dark", true)
	label("UPDRAFT  /  14 M", UPDRAFT_BASE + Vector3(0.0, UPDRAFT_SIZE.y + 2.2, 0.0), 40, Color("67d5d2"), 0.02, true)


## Welcome sign and the hint zones: one at the start, one under the gantry, one by the tower.
func _build_start() -> void:
	# Set off to the left so the first view down the range stays clear of it.
	signboard("PRACTICE RANGE", Vector3(-23.0, 2.1, 12.0), "NO CLOCK   /   EXTRACT TO RESET THE CASE", "cyan", 30.0)
	hint_zone(HINT_ZONE_CENTER, Vector3(6.0, 3.0, 4.0), "PRACTICE RANGE  /  charge {cast}, release, then {lock} to ride the weight", 8.0)
	hint_zone(Vector3(0.0, 1.5, -50.0), Vector3(30.0, 3.0, 4.0), "CAST UP  /  the cyan plates under the gantry latch the weight", 6.0)
	hint_zone(Vector3(17.0, 1.5, -55.0), Vector3(6.0, 3.0, 8.0), "UPDRAFT  /  stand inside the column to rise", 6.0)


## One required case on the far side and the extraction pad by the perimeter wall.
func _build_extraction() -> void:
	case_at(Vector3(14.0, 0.0, -98.0), "01 / RANGE CASE")
	extraction(Vector3(-14.0, 0.0, -100.0))
	light(Vector3(0.0, 7.5, -64.0), Color("ffc46b"), 1.4, 18.0)
	light(Vector3(18.0, 3.0, -55.0), Color("9ff0e6"), 1.0, 12.0)
	light(Vector3(-14.0, 4.0, -100.0), Color("ffe3b0"), 1.0, 14.0)


## Distant city ring, well outside the perimeter walls.
func _build_dressing() -> void:
	skyline(4411, Vector3(0.0, 0.0, -40.0), 85.0, 130.0, 24)
