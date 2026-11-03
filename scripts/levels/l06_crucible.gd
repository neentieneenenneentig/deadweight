extends "res://scripts/level_base.gd"
## L06 CRUCIBLE (DESIGN: Foundry): the foundry finale. A round furnace hall, approximated with
## segments, whose centre is a porcelain teapot standing in a red heat pool. Two floating ring
## catwalks climb the east side by ramps: the low ring at 4.5 m and the rim above the pool at 9 m.
## Eight anchors hang from the ceiling ring and four radial beams carry the rod-only caches, so a
## swing across the centre is the fast route. Five required cases and the extraction are on foot;
## the two caches need the rod. Two sentries watch the rings and a drone patrols the inner aisle.

const INFO := {
	"title": "CRUCIBLE",
	"zone": "foundry",
	"number": 6,
	"blurb": "A round furnace hall around a teapot that is too hot to pour. Two rings, a ceiling of anchors, and the last sentries.",
	"par_silver": 45.0,
	"par_gold": 25.0,
	"cases": 5,
	"bonus": 2,
	"enemies": true,
	"practice": false,
}

## Angles are in degrees from the hall centre: 0 is south (toward the gate and the spawn), 90 is
## east, 180 is north (toward the extraction). Radii are in metres from the centre.
const CENTER := Vector3(0.0, 0.0, -46.0)
const SPAWN := Vector3(0.0, 0.0, 4.0)
const WALL_RADIUS := 26.0
const WALL_HEIGHT := 9.0
## The gate is the wall gap around 0 degrees. Wall segments whose centre is closer than this are left out.
const GATE_HALF_ANGLE := 15.0
const POOL_DPS := 22.0
const RING_LOW_TOP := 4.5
const RING_HIGH_TOP := 9.0
const BEAM_Y := 15.0
const CEILING_TOP := 17.0
## Anchor plates hang under the ceiling ring, flush with its underside at 16.4 m.
const ANCHOR_Y := 16.34
const ANCHOR_ANGLES := [30.0, 120.0, 210.0, 300.0]
const BEAM_ANGLES := [60.0, 150.0, 240.0, 330.0]
## Rod-only caches sit on the beams at 60 and 240 degrees.
const CACHE_ANGLES := [60.0, 240.0]
const EXTRACT_RADIUS := 17.0


func _design() -> void:
	set_zone("foundry")
	set_spawn(SPAWN)
	_build_ground()
	_build_entrance()
	_build_wall()
	_build_crucible()
	_build_rings()
	_build_ramps()
	_build_ceiling()
	_build_extraction()
	_build_dressing()
	_place_objectives()
	_place_enemies()
	_place_lights()
	_place_hints()


## Point on the floor (or at height) at a radius and angle from the hall centre.
func _at(radius: float, degrees: float, height: float = 0.0) -> Vector3:
	var angle: float = deg_to_rad(degrees)
	return Vector3(CENTER.x + radius * sin(angle), height, CENTER.z + radius * cos(angle))


## A ring made of flat segments, each tangent to the circle. The top of each segment is at top and
## its radial width is width. Segments overlap a little so the ring reads as one curve.
func _ring(radius: float, width: float, top: float, thick: float, from_deg: float, to_deg: float, step: float, material: String, solid: bool = true) -> void:
	var length: float = 2.0 * radius * sin(deg_to_rad(step * 0.5)) + 0.4
	var degrees: float = from_deg
	while degrees <= to_deg + 0.01:
		box(_at(radius, degrees, top - thick * 0.5), Vector3(length, thick, width), material, solid, degrees)
		degrees += step


func _build_ground() -> void:
	ground(Vector3(0.0, 0.0, -32.0), Vector2(60.0, 86.0), "concrete", 1.2)
	perimeter(Vector3(0.0, 0.0, -32.0), Vector2(59.0, 84.0), 12.0, "dark")
	# Cyan route cues lead from the spawn to the gate. Visual only: no collision, no nav change.
	for z: float in [-2.0, -8.0, -14.0]:
		box(Vector3(0.0, 0.02, z), Vector3(0.5, 0.04, 2.2), "cyan", false)


## A kiln mouth at the start, with two anchors under the lintel for a first swing.
func _build_entrance() -> void:
	for side: float in [-1.0, 1.0]:
		box(Vector3(side * 8.5, 5.5, 1.5), Vector3(1.5, 11.0, 2.0), "light_concrete")
		box(Vector3(side * 8.5, 10.0, 1.5), Vector3(1.8, 0.3, 2.2), "yellow", false)
	box(Vector3(0.0, 10.4, 1.5), Vector3(18.5, 1.8, 2.0), "dark")
	box(Vector3(0.0, 10.3, 2.55), Vector3(15.2, 1.2, 0.1), "rust", false)
	label("C R U C I B L E", Vector3(0.0, 10.3, 2.63), 56, Color("f6e4c4"), 0.012)
	for x: float in [-4.0, 4.0]:
		anchor(Vector3(x, 9.44, 1.5), Vector3.DOWN)


## The hall wall: solid segments on a circle, with a gap at the gate.
func _build_wall() -> void:
	for i: int in range(36):
		var degrees: float = -180.0 + float(i) * 10.0
		if absf(degrees) < GATE_HALF_ANGLE:
			continue
		box(_at(WALL_RADIUS, degrees, WALL_HEIGHT * 0.5), Vector3(4.7, WALL_HEIGHT, 1.2), "dark", true, degrees)


## The crucible: a solid porcelain teapot at the centre, a 13 m heat pool around it, and a flue
## (non-solid) running up to the beams. The pool is one hazard volume, so the teapot body stands
## in it and the rim above keeps the route over the top.
func _build_crucible() -> void:
	cylinder(CENTER + Vector3(0.0, 1.4, 0.0), 3.0, 2.8, "light_concrete", true)
	cylinder(CENTER + Vector3(0.0, 2.95, 0.0), 1.3, 0.3, "yellow", false)
	cylinder(CENTER + Vector3(0.0, 3.4, 0.0), 0.35, 0.4, "yellow", false)
	pipe(CENTER + Vector3(2.8, 1.3, 0.0), CENTER + Vector3(4.8, 3.2, 0.0), 0.4, "light_concrete", false)
	pipe(CENTER + Vector3(-2.9, 1.2, 0.0), CENTER + Vector3(-4.2, 2.6, 0.0), 0.36, "light_concrete", false)
	pipe(CENTER + Vector3(-4.2, 2.6, 0.0), CENTER + Vector3(-2.9, 3.0, 0.0), 0.36, "light_concrete", false)
	pipe(CENTER + Vector3(0.0, 2.8, 0.0), CENTER + Vector3(0.0, BEAM_Y, 0.0), 0.45, "rust", false)
	hazard(CENTER + Vector3(0.0, 1.0, 0.0), Vector3(13.0, 2.0, 13.0), "heat", POOL_DPS)
	box(CENTER + Vector3(0.0, 0.03, 0.0), Vector3(13.0, 0.04, 13.0), "red", false)


## Two floating catwalk rings. The low ring is an east and a west arc at 4.5 m with brass rails
## on its outer edge. The rim is a full ring above the pool at 9 m, carried by four pillars.
func _build_rings() -> void:
	_ring(16.0, 6.0, RING_LOW_TOP, 0.3, 40.0, 140.0, 10.0, "light_concrete")
	_ring(16.0, 6.0, RING_LOW_TOP, 0.3, 220.0, 320.0, 10.0, "light_concrete")
	_ring(18.9, 0.2, RING_LOW_TOP + 0.9, 0.9, 50.0, 130.0, 10.0, "yellow", false)
	_ring(18.9, 0.2, RING_LOW_TOP + 0.9, 0.9, 230.0, 310.0, 10.0, "yellow", false)
	for degrees: float in [60.0, 120.0, 240.0, 300.0]:
		pillar(_at(16.0, degrees, 0.0), RING_LOW_TOP - 0.15, 0.7, "rust")
	_ring(8.0, 5.0, RING_HIGH_TOP, 0.3, 0.0, 350.0, 10.0, "light_concrete")
	for degrees: float in [30.0, 150.0, 210.0, 330.0]:
		pillar(_at(8.0, degrees, 0.0), RING_HIGH_TOP - 0.15, 0.7, "rust")


## Ramps: two climb the outer aisle to the low ring, and one climbs from the low ring to the rim.
## Each ramp finishes exactly on the outer edge of the catwalk it reaches. A finish inside the slab
## would leave the slab edge standing above the ramp, which is a step the agent cannot climb.
func _build_ramps() -> void:
	ramp(_at(23.5, 5.0, 0.0), _at(19.0, 40.0, RING_LOW_TOP), 3.0)
	ramp(_at(23.5, -5.0, 0.0), _at(19.0, -40.0, RING_LOW_TOP), 3.0)
	ramp(_at(18.0, 90.0, RING_LOW_TOP), _at(10.5, 90.0, RING_HIGH_TOP), 3.0)


## The ceiling ring, radial beams, support pillars, eight anchors and the two rod-only caches.
func _build_ceiling() -> void:
	_ring(22.0, 1.2, CEILING_TOP, 0.6, 0.0, 350.0, 10.0, "rust")
	for degrees: float in BEAM_ANGLES:
		box(_at(11.5, degrees, BEAM_Y), Vector3(0.6, 0.6, 21.0), "rust", true, degrees)
	for degrees: float in [50.0, 130.0, 230.0, 310.0]:
		pillar(_at(22.0, degrees, 0.0), CEILING_TOP - 0.6, 0.9, "rust")
	for degrees: float in ANCHOR_ANGLES:
		anchor(_at(22.0, degrees, ANCHOR_Y), Vector3.DOWN)
	for degrees: float in CACHE_ANGLES:
		platform(_at(12.0, degrees, BEAM_Y + 0.3), Vector2(3.0, 3.0), "light_concrete", false)


## The extraction pad on the north side of the hall, with a gantry at its far edge.
func _build_extraction() -> void:
	extraction(_at(EXTRACT_RADIUS, 180.0, 0.0))
	for x: float in [-6.0, 6.0]:
		box(Vector3(x, 3.0, -69.5), Vector3(0.6, 6.0, 0.6), "rust")
	box(Vector3(0.0, 5.8, -69.5), Vector3(13.0, 0.65, 0.7), "dark")
	label("E X T R A C T I O N", Vector3(0.0, 5.8, -69.1), 38, Color("5ad6c8"), 0.012)


## Foundry dressing: the teapot's notice, a deadpan board by the gate, kiln chimneys beyond the
## perimeter. Everything here is visual only.
func _build_dressing() -> void:
	label("THE CRUCIBLE\nDO NOT POUR", CENTER + Vector3(0.0, 5.2, 0.0), 30, Color("f6e4c4"), 0.014, true)
	signboard("06   CRUCIBLE", Vector3(-16.0, 2.1, 4.0), "THE KETTLE IS NOT A KETTLE   /   KEEP OFF", "amber")
	for z: float in [-18.0, -70.0]:
		for side: float in [-1.0, 1.0]:
			var cx: float = side * 36.0
			cylinder(Vector3(cx, 13.0, z), 2.2, 26.0, "light_concrete", false)
			cylinder(Vector3(cx, 26.2, z), 2.4, 0.4, "amber", false)


func _place_objectives() -> void:
	case_at(_at(16.0, 100.0, RING_LOW_TOP), "01 / EAST RING")
	case_at(_at(8.0, 200.0, RING_HIGH_TOP), "02 / CRUCIBLE RIM")
	case_at(_at(16.0, 250.0, RING_LOW_TOP), "03 / WEST RING")
	case_at(_at(21.0, 145.0, 0.0), "04 / NORTH AISLE")
	case_at(_at(10.0, 0.0, 0.0), "05 / KILN FLOOR")
	# Rod-only caches on the beams, reached by swinging from the ceiling anchors.
	bonus_at(_at(12.0, 60.0, BEAM_Y + 0.3), "KILN LID")
	bonus_at(_at(12.0, 240.0, BEAM_Y + 0.3), "FLUE CAP")


## A sentry on the low ring and one on the rim cover the centre. A drone patrols the inner aisle.
## The Compatibility spawn view is the limit: at spawn each sentry costs about 11 draw calls, a
## drone about 13 and a hound about 17, so the hall keeps to the two sentries and one drone.
func _place_enemies() -> void:
	enemy("sentry", _at(16.0, 120.0, RING_LOW_TOP))
	enemy("sentry", _at(8.0, 240.0, RING_HIGH_TOP))
	enemy("drone", _at(11.0, 25.0, 0.1))


## A red glow over the pool, amber over the gate and the east ring. Three lights plus the sun.
func _place_lights() -> void:
	light(Vector3(0.0, 3.2, CENTER.z), Color("ff5a40"), 1.3, 12.0)
	light(_at(16.0, 100.0, 7.0), Color("ffb347"), 1.4, 16.0)
	light(Vector3(0.0, 6.0, -20.0), Color("ffb347"), 1.3, 16.0)


func _place_hints() -> void:
	hint_zone(Vector3(0.0, 1.5, 6.0), Vector3(14.0, 3.0, 6.0), "RED IS HOT  /  go round the pool, or {cast} over it", 8.0)
	hint_zone(Vector3(0.0, 1.5, -22.0), Vector3(14.0, 3.0, 4.0), "ANCHORS HANG FROM THE CEILING RING  /  {cast} up, then {reel} to swing across the centre", 8.0)
	hint_zone(Vector3(7.0, 1.5, -28.0), Vector3(8.0, 3.0, 6.0), "RAMPS CLIMB TO THE RINGS  /  the sentries see the whole hall", 6.0)
	hint_zone(_at(14.0, 90.0, 1.5), Vector3(5.0, 3.0, 5.0), "UPPER RING  /  the rim is the high route over the pool", 6.0)
	hint_zone(_at(18.0, 240.0, 1.5), Vector3(6.0, 3.0, 6.0), "TWO CACHES HANG FROM THE BEAMS  /  the rod reaches them, feet do not", 6.0)
