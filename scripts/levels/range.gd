extends "res://scripts/level_base.gd"
## PRACTICE RANGE (DESIGN: Practice Range): a sandbox for every tool before a raid. Grid and
## distance markers, platforms at 25 to 200 m, an anchor gantry, an updraft tower, a pillar
## slalom, three training dummies (E3), and one case by the extraction. Repeatable: an extraction banks the
## case and main calls reset_cases() so the run starts again.
##
## Scale: a full cast carries the player 95 to 170 m before the first landing, at up to 45 to 65 m/s
## (measured on open ground, 2026-11-04). The range is 320 x 720 m so that takes several casts.

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

const SPAWN := Vector3(0.0, 0.0, 40.0)
## Floor centre and size. The floor runs from z = +60 behind the spawn to z = -660.
const FLOOR_CENTER := Vector3(0.0, 0.0, -300.0)
const FLOOR_SIZE := Vector2(320.0, 720.0)
## Walls high enough that a full swing (peak about 38 m) stays inside the range.
const WALL_HEIGHT := 60.0
## Centre of the welcome hint zone. Tests use it to check that the zone fires once.
const HINT_ZONE_CENTER := Vector3(0.0, 1.2, 30.0)
const UPDRAFT_BASE := Vector3(100.0, 0.0, -350.0)
const UPDRAFT_SIZE := Vector3(12.0, 60.0, 12.0)
const GANTRY_Z := -230.0
const GANTRY_HEIGHT := 40.0
## The beam's underside is at 39.4 m. A 0.12 m plate centred at 39.34 hangs flush against it.
const ANCHOR_Y := 39.34
## Distance is measured from spawn along -Z. Sides alternate so the centre lane stays open.
const PLATFORMS := [
	{"distance": 25, "height": 5.0, "x": -30.0},
	{"distance": 50, "height": 10.0, "x": 30.0},
	{"distance": 100, "height": 20.0, "x": -30.0},
	{"distance": 150, "height": 30.0, "x": 30.0},
	{"distance": 200, "height": 45.0, "x": -30.0},
]
const MARKER_DISTANCES := [25, 50, 100, 150, 200, 300, 400, 500, 600]
const SLALOM_HEIGHT := 30.0
const SLALOM := [
	Vector2(-25.0, -290.0), Vector2(25.0, -330.0), Vector2(-25.0, -370.0),
	Vector2(25.0, -410.0), Vector2(-25.0, -450.0), Vector2(25.0, -490.0),
]
## Training dummies on open floor beside the slalom, off the centre lane, clear of the gantry legs, the
## updraft tower's hint zone and the case and extraction on the far side.
const DUMMY_SPOTS := [Vector3(-60.0, 0.0, -300.0), Vector3(55.0, 0.0, -320.0), Vector3(-65.0, 0.0, -460.0)]
const CASE_SPOT := Vector3(60.0, 0.0, -600.0)
const EXTRACTION_SPOT := Vector3(-60.0, 0.0, -620.0)
## Labels here are read from much further away than in a raid level.
const FAR_LABEL_RANGE := 450.0


func _design() -> void:
	set_zone("floodworks")
	set_spawn(SPAWN)
	ground(FLOOR_CENTER, FLOOR_SIZE)
	# Walls keep the player on the range; there is no drop-off to learn from here.
	perimeter(FLOOR_CENTER, FLOOR_SIZE - Vector2.ONE, WALL_HEIGHT)
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


## Grid lines every 25 m. The centre line is yellow so forward reads at a glance. Lines are
## non-solid and merge into the static geometry.
func _build_grid() -> void:
	var half: Vector2 = FLOOR_SIZE * 0.5 - Vector2.ONE
	for x: int in range(-150, 151, 25):
		box(Vector3(float(x), 0.015, FLOOR_CENTER.z), Vector3(0.12, 0.03, FLOOR_SIZE.y - 2.0), "light_concrete", false)
	for z: int in range(50, -651, -25):
		box(Vector3(0.0, 0.015, float(z)), Vector3(half.x * 2.0, 0.03, 0.12), "light_concrete", false)
	box(Vector3(0.0, 0.017, FLOOR_CENTER.z), Vector3(0.4, 0.03, FLOOR_SIZE.y - 2.0), "yellow", false)


func _far_label(text: String, position: Vector3, font_size: int, color: Color, pixel_size: float) -> void:
	var node: Label3D = label(text, position, font_size, color, pixel_size, true)
	node.visibility_range_end = FAR_LABEL_RANGE


## A tall post and a billboard label at each marked distance, so distances read off the ground.
func _build_distance_markers() -> void:
	for distance: int in MARKER_DISTANCES:
		var z: float = SPAWN.z - float(distance)
		box(Vector3(-12.0, 3.0, z), Vector3(0.5, 6.0, 0.5), "yellow", false)
		_far_label("%d M" % distance, Vector3(-12.0, 8.0, z), 48, Color("ffc46b"), 0.055)


## Platforms at marked distances and heights. They are targets for the rod and a sense of scale,
## not a route the player must take.
func _build_platforms() -> void:
	for entry: Dictionary in PLATFORMS:
		var height: float = float(entry["height"])
		var top := Vector3(float(entry["x"]), height, SPAWN.z - float(entry["distance"]))
		platform(top, Vector2(10.0, 10.0), "dark", true)
		_far_label("%d M  /  %d M UP" % [int(entry["distance"]), int(height)], top + Vector3(0.0, 3.0, 0.0), 36, Color("e4ddbd"), 0.035)


## Anchor gantry: a beam 40 m up with cyan plates under it. Weights latch to the plates from below.
func _build_gantry() -> void:
	for x: float in [-65.0, 65.0]:
		box(Vector3(x, GANTRY_HEIGHT * 0.5, GANTRY_Z), Vector3(2.5, GANTRY_HEIGHT, 2.5), "rust")
	box(Vector3(0.0, GANTRY_HEIGHT, GANTRY_Z), Vector3(135.0, 1.2, 3.0), "rust")
	for x: float in [-45.0, -15.0, 15.0, 45.0]:
		anchor(Vector3(x, ANCHOR_Y, GANTRY_Z), Vector3.DOWN)
	_far_label("ANCHOR GANTRY  /  40 M", Vector3(0.0, GANTRY_HEIGHT + 4.0, GANTRY_Z), 48, Color("67d5d2"), 0.09)


## Pillar slalom: tall pillars that force a zig-zag, so swings and wraps have things to hit.
func _build_slalom() -> void:
	for spot: Vector2 in SLALOM:
		pillar(Vector3(spot.x, 0.0, spot.y), SLALOM_HEIGHT, 3.0, "rust")
	_far_label("PILLAR SLALOM", Vector3(0.0, 12.0, SLALOM[0].y + 20.0), 44, Color("e8d6a8"), 0.07)


## Three training dummies (E3): they never attack, flash when hit and stand back up after a kill.
func _build_dummies() -> void:
	for spot: Vector3 in DUMMY_SPOTS:
		enemy("dummy", spot)


## Updraft tower: a 60 m rising column with a catch platform on top. The platform's legs frame the
## column without standing inside it.
func _build_updraft_tower() -> void:
	updraft(UPDRAFT_BASE, UPDRAFT_SIZE, 26.0)
	platform(UPDRAFT_BASE + Vector3(0.0, UPDRAFT_SIZE.y, 0.0), Vector2(18.0, 18.0), "dark", true)
	_far_label("UPDRAFT  /  60 M", UPDRAFT_BASE + Vector3(0.0, UPDRAFT_SIZE.y + 5.0, 0.0), 48, Color("67d5d2"), 0.08)


## Welcome sign and the hint zones: one at the start, one under the gantry, one by the tower.
func _build_start() -> void:
	# Set off to the left so the first view down the range stays clear of it.
	signboard("PRACTICE RANGE", Vector3(-28.0, 2.1, 36.0), "NO CLOCK   /   EXTRACT TO RESET THE CASE", "cyan", 30.0)
	hint_zone(HINT_ZONE_CENTER, Vector3(12.0, 3.0, 8.0), "PRACTICE RANGE  /  charge {cast}, release, then {lock} to ride the weight", 8.0)
	hint_zone(Vector3(0.0, 1.5, GANTRY_Z + 30.0), Vector3(130.0, 3.0, 10.0), "CAST UP  /  the cyan plates under the gantry latch the weight", 6.0)
	hint_zone(UPDRAFT_BASE + Vector3(-14.0, 1.5, 0.0), Vector3(12.0, 3.0, 24.0), "UPDRAFT  /  stand inside the column to rise", 6.0)


## One required case on the far side and the extraction pad by the far wall.
func _build_extraction() -> void:
	case_at(CASE_SPOT, "01 / RANGE CASE")
	extraction(EXTRACTION_SPOT)
	light(Vector3(0.0, GANTRY_HEIGHT - 4.0, GANTRY_Z - 10.0), Color("ffc46b"), 2.0, 70.0)
	light(UPDRAFT_BASE + Vector3(0.0, 20.0, 0.0), Color("9ff0e6"), 1.6, 50.0)
	light(EXTRACTION_SPOT + Vector3(0.0, 8.0, 0.0), Color("ffe3b0"), 1.6, 40.0)


## Distant city ring, well outside the perimeter walls.
func _build_dressing() -> void:
	skyline(4411, FLOOR_CENTER, 420.0, 600.0, 32)
