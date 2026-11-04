extends "res://scripts/level_base.gd"
## PRACTICE RANGE (DESIGN: Practice Range): a sandbox for every tool before a raid. Grid and
## distance markers, platforms at 25 to 200 m, an anchor gantry, an updraft tower, a pillar
## slalom, three training dummies (E3), and one case by the extraction. Repeatable: an extraction banks the
## case and main calls reset_cases() so the run starts again.
##
## Scale (S1): a full cast carries the player 50 to 60 m to the first landing, at 27 to 30 m/s, and
## about 90 m in 8 s (measured on open ground on 2026-11-04). The range is 400 x 1000 m, so crossing
## it takes a dozen casts.

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
## Floor centre and size. The floor runs from z = +70 behind the spawn to z = -930.
const FLOOR_CENTER := Vector3(0.0, 0.0, -430.0)
const FLOOR_SIZE := Vector2(400.0, 1000.0)
## The walls. Beyond them the outer plain goes on (level_base), and a player who gets over is walked back.
const WALL_HEIGHT := 60.0
## Centre of the welcome hint zone. Tests use it to check that the zone fires once.
const HINT_ZONE_CENTER := Vector3(0.0, 1.2, 30.0)
const UPDRAFT_BASE := Vector3(130.0, 0.0, -480.0)
const UPDRAFT_SIZE := Vector3(12.0, 60.0, 12.0)
const GANTRY_Z := -300.0
const GANTRY_HEIGHT := 30.0
## The beam's underside is at 29.4 m. A 0.12 m plate centred at 29.34 hangs flush against it.
const ANCHOR_Y := 29.34
## Distance is measured from spawn along -Z. Sides alternate so the centre lane stays open.
const PLATFORMS := [
	{"distance": 25, "height": 5.0, "x": -30.0},
	{"distance": 50, "height": 8.0, "x": 30.0},
	{"distance": 100, "height": 12.0, "x": -30.0},
	{"distance": 150, "height": 15.0, "x": 30.0},
	{"distance": 200, "height": 30.0, "x": -30.0},
]
const MARKER_DISTANCES := [25, 50, 100, 150, 200, 300, 400, 500, 600, 700, 800, 900]
const SLALOM_HEIGHT := 30.0
const SLALOM := [
	Vector2(-30.0, -380.0), Vector2(30.0, -430.0), Vector2(-30.0, -480.0),
	Vector2(30.0, -530.0), Vector2(-30.0, -580.0), Vector2(30.0, -630.0),
]
## Training dummies on open floor beside the slalom, off the centre lane, clear of the gantry legs, the
## updraft tower's hint zone and the case and extraction on the far side.
const DUMMY_SPOTS := [Vector3(-80.0, 0.0, -400.0), Vector3(75.0, 0.0, -430.0), Vector3(-85.0, 0.0, -600.0)]
const CASE_SPOT := Vector3(80.0, 0.0, -860.0)
const EXTRACTION_SPOT := Vector3(-80.0, 0.0, -880.0)
## Text here is read from much further away than in a raid level.
const FAR_LABEL_RANGE := 500.0
## Sign plates are this thick. Text sits on the front (+z) face only.
const PLATE_DEPTH := 0.25


func _design() -> void:
	set_zone("floodworks")
	set_spawn(SPAWN)
	# 400 x 1000 m of floor: half-metre navmesh cells keep the bake near half a second. Only the dummies stand here.
	nav_cell_size = 0.5
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
	for x: int in range(-175, 176, 25):
		box(Vector3(float(x), 0.015, FLOOR_CENTER.z), Vector3(0.12, 0.03, FLOOR_SIZE.y - 2.0), "light_concrete", false)
	for z: int in range(50, -926, -25):
		box(Vector3(0.0, 0.015, float(z)), Vector3(half.x * 2.0, 0.03, 0.12), "light_concrete", false)
	box(Vector3(0.0, 0.017, FLOOR_CENTER.z), Vector3(0.4, 0.03, FLOOR_SIZE.y - 2.0), "yellow", false)


## Nothing in the range floats: every word is on a solid plate or painted on the floor.
## A solid plate with text on its front (+z) face, the side that faces the spawn. posts stands it on
## two solid legs down to the floor.
func _plate(text: String, center: Vector3, size: Vector2, font_size: int, color: Color, pixel_size: float, posts: bool = false) -> void:
	box(center, Vector3(size.x, size.y, PLATE_DEPTH), "dark")
	var face: Label3D = label(text, center + Vector3(0.0, 0.0, PLATE_DEPTH * 0.5 + 0.02), font_size, color, pixel_size)
	face.double_sided = false
	face.visibility_range_end = FAR_LABEL_RANGE
	if not posts:
		return
	var bottom: float = center.y - size.y * 0.5
	for side: float in [-1.0, 1.0]:
		box(Vector3(center.x + side * (size.x * 0.5 - 0.6), bottom * 0.5, center.z), Vector3(0.35, bottom, 0.35), "rust")


## Text painted flat on the floor. It reads upright to a player looking down the range (-z).
func _floor_paint(text: String, position: Vector3, font_size: int, color: Color, pixel_size: float) -> void:
	var paint: Label3D = label(text, position, font_size, color, pixel_size)
	paint.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	paint.double_sided = false
	paint.visibility_range_end = FAR_LABEL_RANGE


## At each marked distance: a yellow line across the floor, the number painted beside the centre
## line, and a solid post with a number plate, so distances read from the ground and from the air.
func _build_distance_markers() -> void:
	for distance: int in MARKER_DISTANCES:
		var z: float = SPAWN.z - float(distance)
		box(Vector3(0.0, 0.02, z), Vector3(60.0, 0.03, 0.35), "yellow", false)
		_floor_paint("%d" % distance, Vector3(14.0, 0.05, z - 4.0), 96, Color("ffc46b"), 0.06)
		box(Vector3(-12.0, 3.0, z), Vector3(0.5, 6.0, 0.5), "yellow")
		_plate("%d M" % distance, Vector3(-12.0, 6.8, z), Vector2(4.4, 1.6), 72, Color("ffc46b"), 0.016)


## Platforms at marked distances and heights. They are targets for the rod and a sense of scale,
## not a route the player must take. The distance and height are printed on a fascia under the
## deck's front edge, high enough to walk under.
func _build_platforms() -> void:
	for entry: Dictionary in PLATFORMS:
		var height: float = float(entry["height"])
		var top := Vector3(float(entry["x"]), height, SPAWN.z - float(entry["distance"]))
		platform(top, Vector2(10.0, 10.0), "dark", true)
		var fascia := Vector3(top.x, height - 0.3 - 0.65, top.z + 5.0 - PLATE_DEPTH * 0.5)
		_plate("%d M  /  %d M UP" % [int(entry["distance"]), int(height)], fascia, Vector2(9.6, 1.3), 48, Color("e4ddbd"), 0.016)


## Anchor gantry: a beam 30 m up with cyan plates under it. Weights latch to the plates from below.
func _build_gantry() -> void:
	for x: float in [-70.0, 70.0]:
		box(Vector3(x, GANTRY_HEIGHT * 0.5, GANTRY_Z), Vector3(2.5, GANTRY_HEIGHT, 2.5), "rust")
	box(Vector3(0.0, GANTRY_HEIGHT, GANTRY_Z), Vector3(145.0, 1.2, 3.0), "rust")
	for x: float in [-45.0, -15.0, 15.0, 45.0]:
		anchor(Vector3(x, ANCHOR_Y, GANTRY_Z), Vector3.DOWN)
	# A sign board stands on the beam, like a road gantry's, clear of the plates underneath.
	_plate("ANCHOR GANTRY\n30 M", Vector3(0.0, GANTRY_HEIGHT + 0.6 + 3.8, GANTRY_Z), Vector2(30.0, 7.6), 64, Color("67d5d2"), 0.045)


## Pillar slalom: tall pillars that force a zig-zag, so swings and wraps have things to hit.
func _build_slalom() -> void:
	for spot: Vector2 in SLALOM:
		pillar(Vector3(spot.x, 0.0, spot.y), SLALOM_HEIGHT, 3.0, "rust")
	_plate("PILLAR SLALOM", Vector3(-52.0, 4.0, SLALOM[0].y + 20.0), Vector2(16.0, 3.0), 64, Color("e8d6a8"), 0.026, true)


## Three training dummies (E3): they never attack, flash when hit and stand back up after a kill.
func _build_dummies() -> void:
	for spot: Vector3 in DUMMY_SPOTS:
		enemy("dummy", spot)


## Updraft tower: a 60 m rising column with a catch platform on top. The platform's legs frame the
## column without standing inside it.
func _build_updraft_tower() -> void:
	updraft(UPDRAFT_BASE, UPDRAFT_SIZE, 26.0)
	platform(UPDRAFT_BASE + Vector3(0.0, UPDRAFT_SIZE.y, 0.0), Vector2(18.0, 18.0), "dark", true)
	var deck_front: float = UPDRAFT_BASE.z + 9.0 - PLATE_DEPTH * 0.5
	_plate("UPDRAFT  /  60 M", Vector3(UPDRAFT_BASE.x, UPDRAFT_SIZE.y - 0.3 - 0.9, deck_front), Vector2(17.0, 1.8), 56, Color("67d5d2"), 0.024)
	_plate("UPDRAFT\n60 M", UPDRAFT_BASE + Vector3(-17.0, 4.5, 14.0), Vector2(11.0, 5.0), 64, Color("67d5d2"), 0.03, true)


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
	skyline(4411, FLOOR_CENTER, 580.0, 780.0, 32)
