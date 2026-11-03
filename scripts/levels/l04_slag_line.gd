extends "res://scripts/level_base.gd"
## L04 SLAG LINE (DESIGN: Foundry): a porcelain kiln hall that bakes teacups nobody ordered. Two
## conveyor runs divide a long central lane. Red heat strips cross the lane; the cross gaps in the
## conveyors and the side aisles let the player go around them. A catwalk deck spans the hall on
## ramps, and two overhead beams carry the rod-only caches. The first drone flies alone in the lane;
## the second drone and a sentry come later, on the deck side. Three required cases and the
## extraction are on foot; the two caches need the rod.

const INFO := {
	"title": "SLAG LINE",
	"zone": "foundry",
	"number": 4,
	"blurb": "A kiln hall of conveyors and heat strips. Catwalks and the first drones; the caches hang from overhead beams.",
	"par_silver": 35.0,
	"par_gold": 20.0,
	"cases": 4,
	"bonus": 2,
	"enemies": true,
	"practice": false,
}

const SPAWN := Vector3(0, 0, 14)
## Conveyor runs on both sides of the central lane, as (from z, to z). The gaps between them are
## the cross passages into the side aisles.
const CONVEYOR_X := 7.5
const CONVEYOR_SPANS := [Vector2(-30.0, -40.0), Vector2(-46.0, -70.0), Vector2(-76.0, -100.0), Vector2(-106.0, -126.0)]
## Heat strips across the whole central lane (12 m). The first one sits before the conveyors start.
const HEAT_Z := [-24.0, -52.0, -82.0]
const HEAT_DPS := 18.0
## Catwalk deck crossing the hall: top at DECK_TOP, centre at DECK_Z. Ramps climb the side aisles.
const DECK_Z := -60.0
const DECK_TOP := 4.5
## Overhead beams: top-of-beam height is BEAM_Y + 0.3; the anchor plates hang under each beam.
const BEAM_Y := 9.9
const BEAM_Z := [-88.0, -111.0]
const BEAM_BOTTOM := 9.6
const ANCHOR_Y := 9.54
## The extraction pad at the far end, with its frame just beyond it.
const EXTRACT := Vector3(0, 0, -119)


func _design() -> void:
	set_zone("foundry")
	set_spawn(SPAWN)
	_build_ground()
	_build_entrance()
	_build_conveyors()
	_build_heat()
	_build_catwalk()
	_build_beams()
	_build_extraction()
	_build_dressing()
	_place_objectives()
	_place_enemies()
	_place_lights()
	_place_hints()


func _build_ground() -> void:
	ground(Vector3(0, 0, -57.5), Vector2(44, 155), "concrete", 1.2)
	perimeter(Vector3(0, 0, -57.5), Vector2(43, 155), 8.0, "dark")
	# Cyan route cues run up the central lane. Visual only: no collision, no nav change.
	for z: float in [2.0, -8.0, -14.0, -34.0, -40.0, -62.0, -68.0, -90.0, -96.0, -114.0]:
		box(Vector3(0, 0.02, z), Vector3(0.5, 0.04, 2.2), "cyan", false)


## A porcelain kiln mouth at the start, with brass trim and the title board, echoing the other levels.
func _build_entrance() -> void:
	for side: float in [-1.0, 1.0]:
		box(Vector3(side * 8.5, 5.5, 8), Vector3(1.5, 11, 2), "light_concrete")
		box(Vector3(side * 8.5, 10.0, 8), Vector3(1.8, 0.3, 2.2), "yellow", false)
		box(Vector3(side * 8.5, 2.5, 9.05), Vector3(0.9, 1.6, 0.06), "amber", false)
	box(Vector3(0, 10.4, 8), Vector3(18.5, 1.8, 2), "dark")
	box(Vector3(0, 10.3, 9.04), Vector3(15.2, 1.2, 0.1), "rust", false)
	label("S L A G   L I N E", Vector3(0, 10.3, 9.12), 56, Color("f6e4c4"), 0.012)
	label("FOUNDRY  /  DEPARTMENT OF UNFINISHED GRAVITY", Vector3(0, 8.7, 8.9), 26, Color("ffc46b"), 0.011)
	signboard("04   SLAG LINE", Vector3(-16, 2.1, 6), "THE CUPS ARE NOT READY, BUT THEY ARE HOT", "orange")
	# Two anchors under the lintel give the start a swing to learn on.
	for x: float in [-4.0, 4.0]:
		anchor(Vector3(x, 9.44, 8), Vector3.DOWN)


## Two conveyor runs of solid plum blocks with brass rails, broken by cross gaps. Teacups sit on them.
func _build_conveyors() -> void:
	for side: float in [-1.0, 1.0]:
		var cx: float = side * CONVEYOR_X
		for span: Vector2 in CONVEYOR_SPANS:
			var near: float = maxf(span.x, span.y)
			var far: float = minf(span.x, span.y)
			var length: float = near - far
			var zc: float = (near + far) * 0.5
			box(Vector3(cx, 0.55, zc), Vector3(3.0, 1.1, length), "dark")
			box(Vector3(cx, 1.16, zc), Vector3(3.1, 0.12, length), "yellow", false)
			_teacups_along(cx, near - 2.0, far + 2.0)


## Teacups and saucers at fixed intervals on a conveyor top. Visual only (non-solid).
func _teacups_along(cx: float, from_z: float, to_z: float) -> void:
	var z: float = from_z
	while z >= to_z:
		cylinder(Vector3(cx, 1.235, z), 0.36, 0.03, "yellow", false)
		cylinder(Vector3(cx, 1.40, z), 0.22, 0.30, "light_concrete", false)
		z -= 6.0


## Heat strips: a hazard volume the full width of the lane, plus a red glow strip on the floor.
func _build_heat() -> void:
	for z: float in HEAT_Z:
		hazard(Vector3(0, 1.0, z), Vector3(12.0, 2.0, 2.6), "heat", HEAT_DPS)
		box(Vector3(0, 0.03, z), Vector3(12.0, 0.04, 2.6), "red", false)
		for edge: float in [-1.0, 1.0]:
			box(Vector3(0, 0.06, z + edge * 1.25), Vector3(12.0, 0.02, 0.1), "amber", false)
		# Heat lamp posts at both ends of the strip make it readable from across the hall.
		for side: float in [-1.0, 1.0]:
			box(Vector3(side * 6.0, 0.7, z), Vector3(0.25, 1.4, 2.6), "red", false)


## Catwalk deck over the hall, reached by two ramps in the side aisles. Pillars stand in the aisles
## and inside the conveyors. Rails run along the far edge. The deck is solid; the rails are not.
func _build_catwalk() -> void:
	box(Vector3(0, DECK_TOP - 0.15, DECK_Z), Vector3(42, 0.3, 6), "light_concrete")
	box(Vector3(0, DECK_TOP + 0.5, DECK_Z - 3.0), Vector3(42, 1.0, 0.12), "yellow", false)
	ramp(Vector3(14, 0, -47), Vector3(14, DECK_TOP, -57), 4.5)
	ramp(Vector3(-14, 0, -47), Vector3(-14, DECK_TOP, -57), 4.5)
	for x: float in [-18.5, 18.5]:
		for z: float in [-58.5, -61.5]:
			pillar(Vector3(x, 0, z), DECK_TOP - 0.3, 0.5, "rust")
	for side: float in [-1.0, 1.0]:
		pillar(Vector3(side * CONVEYOR_X, 0, DECK_Z), DECK_TOP - 0.3, 0.9, "rust")
	# Two plates under the deck let the rod swing through the middle of the lane.
	for x: float in [-3.0, 3.0]:
		anchor(Vector3(x, DECK_TOP - 0.21, DECK_Z), Vector3.DOWN)


## Overhead beams across the hall. Plates hang under each beam, and each beam carries a rod-only
## cache on a small nest.
func _build_beams() -> void:
	for z: float in BEAM_Z:
		box(Vector3(0, BEAM_Y, z), Vector3(42, 0.6, 1.2), "rust")
		for x: float in [-20.0, 20.0]:
			pillar(Vector3(x, 0, z), BEAM_BOTTOM, 0.8, "rust")
		for x: float in [-6.0, 6.0]:
			anchor(Vector3(x, ANCHOR_Y, z), Vector3.DOWN)
	platform(Vector3(0, BEAM_Y + 0.3, BEAM_Z[0]), Vector2(3.0, 2.4), "light_concrete", false)
	platform(Vector3(-12, BEAM_Y + 0.3, BEAM_Z[1]), Vector2(3.0, 2.4), "light_concrete", false)


func _build_extraction() -> void:
	extraction(EXTRACT)
	for x: float in [-6.0, 6.0]:
		box(Vector3(x, 3.0, -127), Vector3(0.6, 6.0, 0.6), "rust")
	box(Vector3(0, 5.8, -127), Vector3(13, 0.65, 0.7), "dark")
	label("E X T R A C T I O N", Vector3(0, 5.8, -126.6), 38, Color("5ad6c8"), 0.012)
	label("BANK SALVAGE  /  HOLD POSITION", Vector3(0, 4.7, -126.6), 24, Color("f0e3c8"), 0.011)
	signboard("03   COOLING ROOM", Vector3(16, 2.1, -104), "LAST SIGNAL   /   THEN EXTRACT", "cyan")


## Foundry dressing: kiln chimneys beyond the walls, a deadpan notice on the first conveyor, and a
## cooling-rack notice above the first heat strip. Everything is visual only.
func _build_dressing() -> void:
	for z: float in [-18.0, -74.0, -118.0]:
		for side: float in [-1.0, 1.0]:
			var cx: float = side * 26.0
			cylinder(Vector3(cx, 13.0, z), 2.2, 26.0, "light_concrete", false)
			cylinder(Vector3(cx, 19.5, z), 2.3, 0.8, "yellow", false)
			cylinder(Vector3(cx, 26.2, z), 2.4, 0.4, "amber", false)
	label("NO ONE ORDERED\nTHESE CUPS", Vector3(-CONVEYOR_X, 2.2, -29.4), 24, Color("f4e6c8"), 0.014)
	label("PLEASE MIND THE HEAT\n(IT IS FOR THE CUPS)", Vector3(0, 3.6, -20.5), 26, Color("f4e6c8"), 0.014)


func _place_objectives() -> void:
	case_at(Vector3(-15, 0, -16), "01 / TEACUP PRESS")
	case_at(Vector3(0, DECK_TOP, DECK_Z), "02 / CATWALK KILN")
	case_at(Vector3(14, 0, -90), "03 / CONVEYOR SIX")
	case_at(Vector3(-15, 0, -116), "04 / COOLING RACK")
	# Rod-only caches on the overhead beams.
	bonus_at(Vector3(0, BEAM_Y + 0.3, BEAM_Z[0]), "KILN LID")
	bonus_at(Vector3(-12, BEAM_Y + 0.3, BEAM_Z[1]), "FLUE CAP")


## One drone alone in the lane first. The sentry and the second drone come later, on the deck side.
func _place_enemies() -> void:
	enemy("drone", Vector3(-2, 0.1, -30))
	enemy("sentry", Vector3(-16, DECK_TOP, DECK_Z))
	enemy("drone", Vector3(10, 0.1, -68))
	enemy("drone", Vector3(-2, 0.1, -102))


## Warm amber over the entrance and the beam, a red fitting over the heat strip. Three lights plus the sun.
func _place_lights() -> void:
	light(Vector3(0, 6.0, 4), Color("ffb347"), 1.6, 18.0)
	light(Vector3(0, 3.0, HEAT_Z[1]), Color("ff5a40"), 1.2, 10.0)
	light(Vector3(0, 6.0, BEAM_Z[0]), Color("ffb347"), 1.4, 18.0)


func _place_hints() -> void:
	hint_zone(Vector3(0, 1.5, 9), Vector3(14, 3, 6), "RED STRIPS BURN  /  go around them: the gaps in the conveyors are side doors", 8.0)
	hint_zone(Vector3(0, 1.5, -16), Vector3(14, 3, 6), "DRONE  /  it telegraphs an orb: leave its aim line, or {weapon} for the sidearm, then {cast}", 8.0)
	hint_zone(Vector3(0, 1.5, -43), Vector3(14, 3, 6), "CATWALK  /  ramps climb to the deck; the sentry sees all of it", 6.0)
	hint_zone(Vector3(0, 1.5, -84), Vector3(14, 3, 6), "TWO CACHES HANG FROM THE BEAMS  /  the rod reaches them, feet do not", 6.0)
