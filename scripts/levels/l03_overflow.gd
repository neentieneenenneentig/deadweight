extends "res://scripts/level_base.gd"
## L03 OVERFLOW (DESIGN: Floodworks): a sunken porcelain basin filled to the brim with deep water.
## Deep water hurts, so the way across is a dry causeway with two ramped islands off it. Two sentry
## towers watch the basin from the banks. Overflow vents (updrafts) rise out of the water; the two bonus
## caches sit where only the rod, or a ride up a vent, can reach. The four cases and the extraction are
## on foot: the plaza, the causeway, the ramps and the far bank are all walkable.

const INFO := {
	"title": "OVERFLOW",
	"zone": "floodworks",
	"number": 3,
	"blurb": "A flooded basin where deep water hurts. Dry causeway, two islands, overflow vents and sentry towers.",
	"par_silver": 75.0,
	"par_gold": 45.0,
	"cases": 4,
	"bonus": 2,
	"enemies": true,
	"practice": false,
}

## The basin is a sunken tank: its floor sits 3 m under the banks, and the water is 0.8 m under the rim.
const BASIN_FLOOR_Y := -3.0
const BASIN_WATER_Y := -0.8
## Gantries cross the basin at these depths; their beams hang at GANTRY_Y, anchors under the beam.
const GANTRY_Z := [-38.0, -68.0]
const GANTRY_Y := 9.0
const GANTRY_ANCHOR_Y := 8.54


func _design() -> void:
	set_zone("floodworks")
	set_spawn(Vector3(0, 0, 14))
	_build_ground()
	_build_gate()
	_build_basin()
	_build_causeway()
	_build_islands()
	_build_towers()
	_build_gantries()
	_build_vents()
	_build_far_bank()
	_build_extraction()
	_build_signal_block()
	_build_dressing()
	_place_objectives()
	_place_enemies()
	_place_hints()


## Plaza and far bank at the rim height, plus the two narrow banks that line the basin.
func _build_ground() -> void:
	ground(Vector3(0, 0, -2), Vector2(60, 56), "concrete", 1.2)
	ground(Vector3(-26, 0, -62), Vector2(8, 64), "concrete", 1.2)
	ground(Vector3(26, 0, -62), Vector2(8, 64), "concrete", 1.2)
	ground(Vector3(0, 0, -110), Vector2(60, 32), "concrete", 1.2)
	perimeter(Vector3(0, 0, -50), Vector2(60, 154), 6.0, "dark")
	# Plaza route cues lead from the gate to the causeway. Visual only.
	for z: float in [4.0, 0.0, -4.0, -8.0, -12.0, -16.0, -20.0, -24.0]:
		box(Vector3(0, 0.02, z), Vector3(0.5, 0.04, 2.2), "cyan", false)


## A porcelain arch at the start, echoing the other Floodworks gates. Its single anchor is the spawn's
## only plate, so the first cast has a target within a few metres.
func _build_gate() -> void:
	for side: float in [-1.0, 1.0]:
		box(Vector3(side * 8.5, 5.5, 8), Vector3(1.5, 11, 2), "light_concrete")
	box(Vector3(0, 10.4, 8), Vector3(18.5, 1.8, 2), "dark")
	box(Vector3(0, 10.65, 9.04), Vector3(15.2, 1.0, 0.1), "rust", false)
	label("O V E R F L O W", Vector3(0, 10.65, 9.12), 56, Color("f1e4c8"), 0.012)
	anchor(Vector3(0, 9.44, 8), Vector3.DOWN)


## The basin: a porcelain tank with a floor, four walls tucked under the rim, and deep water.
func _build_basin() -> void:
	box(Vector3(0, BASIN_FLOOR_Y - 0.6, -62), Vector3(44, 1.2, 64), "light_concrete")
	block(Vector3(-22.4, BASIN_FLOOR_Y, -62), Vector3(0.8, 1.8, 64), "light_concrete")
	block(Vector3(22.4, BASIN_FLOOR_Y, -62), Vector3(0.8, 1.8, 64), "light_concrete")
	block(Vector3(0, BASIN_FLOOR_Y, -30.4), Vector3(44.8, 1.8, 0.8), "light_concrete")
	block(Vector3(0, BASIN_FLOOR_Y, -94.4), Vector3(44.8, 1.8, 0.8), "light_concrete")
	# Deep water fills the whole tank; the causeway and islands stand above it.
	water(Vector3(0, BASIN_WATER_Y, -62), Vector2(44, 64), true)


## The dry route across the basin: a 4 m porcelain causeway, flush with both rims.
func _build_causeway() -> void:
	box(Vector3(0, -0.3, -62), Vector3(4, 0.6, 64), "light_concrete")
	for side: float in [-1.0, 1.0]:
		box(Vector3(side * 1.9, 0.01, -62), Vector3(0.15, 0.03, 64), "yellow", false)
	for z: float in [-34.0, -40.0, -46.0, -52.0, -58.0, -64.0, -70.0, -76.0, -82.0, -88.0]:
		box(Vector3(0, 0.02, z), Vector3(0.4, 0.04, 2.2), "cyan", false)


## Two islands off the causeway, each joined by a single ramp. Cistern Island is low; Signal Island is higher.
func _build_islands() -> void:
	_islet(Vector3(-13, 0, -45), Vector2(12, 10), 2.4)
	_islet(Vector3(13.5, 0, -63), Vector2(11, 10), 3.6)
	ramp(Vector3(-2, 0, -45), Vector3(-7, 2.4, -45), 4.0)
	ramp(Vector3(2, 0, -63), Vector3(8, 3.6, -63), 4.0)


## A flat porcelain slab over the water, held up by four posts that stand on the basin floor.
func _islet(center: Vector3, size: Vector2, top: float) -> void:
	platform(Vector3(center.x, top, center.z), size, "light_concrete", false)
	var inset := Vector2(size.x * 0.5 - 0.8, size.y * 0.5 - 0.8)
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			var base := Vector3(center.x + x * inset.x, BASIN_FLOOR_Y, center.z + z * inset.y)
			pillar(base, top - 0.3 - BASIN_FLOOR_Y, 0.8, "dark")


## Two sentry towers on the banks. Their red strips face the basin, so the threat reads from the causeway.
func _build_towers() -> void:
	block(Vector3(-26, 0, -52), Vector3(4, 7.0, 4), "dark")
	box(Vector3(-23.95, 5.2, -52), Vector3(0.1, 0.9, 3.0), "red", false)
	label("SENTRY  /  TOWER", Vector3(-26, 5.2, -49.9), 26, Color("ef654e"), 0.014)
	block(Vector3(26, 0, -84), Vector3(4, 5.0, 4), "dark")
	box(Vector3(23.95, 3.6, -84), Vector3(0.1, 0.9, 3.0), "red", false)


## Two anchor gantries cross the basin on pylons. The weights latch under the beams and swing across.
func _build_gantries() -> void:
	for z: float in GANTRY_Z:
		for x: float in [-26.0, 26.0]:
			box(Vector3(x, GANTRY_Y * 0.5, z), Vector3(1.2, GANTRY_Y, 1.2), "rust")
		box(Vector3(0, GANTRY_Y, z), Vector3(52, 0.8, 1.2), "rust")
		for x: float in [-12.0, 12.0]:
			anchor(Vector3(x, GANTRY_ANCHOR_Y, z), Vector3.DOWN)


## Overflow vents are rising air columns. The one at the cistern lifts the rider to the lid.
func _build_vents() -> void:
	updraft(Vector3(-14, BASIN_WATER_Y, -84), Vector3(5, 16, 5), 26.0)
	updraft(Vector3(6, BASIN_WATER_Y, -74), Vector3(4, 14, 4), 26.0)
	# The cistern lid: a porcelain cover over the north-west water, reached only by the vent.
	_islet(Vector3(-14, 0, -90), Vector2(8, 4), 8.0)
	# The nest rests on the gantry beam over the causeway, a tray raised above the beam's top.
	platform(Vector3(0, 9.6, -68), Vector2(5, 2.4), "light_concrete", false)


## The far bank: a dais for one case, reached by a ramp, and the extraction frame.
func _build_far_bank() -> void:
	block(Vector3(-12, 0, -108), Vector3(6, 3.0, 6), "light_concrete")
	ramp(Vector3(-4, 0, -108), Vector3(-9, 3.0, -108), 4.0)
	label("THE DAIS IS FOR CASES", Vector3(-12, 1.6, -104.9), 26, Color("f1e4c8"), 0.014)


func _build_extraction() -> void:
	extraction(Vector3(0, 0, -116))
	for x: float in [-6.0, 6.0]:
		box(Vector3(x, 3.0, -119), Vector3(0.6, 6.0, 0.6), "rust")
	box(Vector3(0, 6.04, -119), Vector3(13, 1.13, 0.7), "dark")
	# One anchor under the beam centre covers everyone who holds the extraction.
	anchor(Vector3(0, 5.415, -119), Vector3.DOWN)
	label("E X T R A C T I O N", Vector3(0, 6.22, -118.6), 38, Color("5ad6c8"), 0.012)
	label("BANK SALVAGE  /  HOLD POSITION", Vector3(0, 5.72, -118.6), 24, Color("d8dfca"), 0.011)


## The east bank has a signal block, reached by a long, low ramp from the plaza. Its case is on top.
func _build_signal_block() -> void:
	block(Vector3(26, 0, -40), Vector3(7, 4.5, 6), "light_concrete")
	ramp(Vector3(26, 0, -24), Vector3(26, 4.5, -37), 5.0)


## Porcelain teacups, a bathtub and two deadpan notices. The cups and the tub are solid.
func _build_dressing() -> void:
	for spot: Vector3 in [Vector3(-9, 0, 4), Vector3(10, 0, -8), Vector3(-6, 0, -22)]:
		cylinder(spot + Vector3.UP * 0.5, 0.8, 1.0, "light_concrete")
		cylinder(spot + Vector3.UP * 1.02, 0.85, 0.05, "yellow", false)
	# A porcelain bathtub with a brass tap on the west bank.
	box(Vector3(-26, 0.5, -76), Vector3(2.6, 1.0, 1.2), "light_concrete")
	cylinder(Vector3(-27.4, 1.3, -76), 0.12, 0.5, "yellow")
	signboard("03   OVERFLOW", Vector3(-8, 2.1, -4), "DEEP WATER HURTS   /   THE CAUSEWAY IS DRY", "cyan")
	signboard("NO SWIMMING", Vector3(14, 2.1, -26.5), "", "red")


func _place_objectives() -> void:
	# Declaration order is the route order: east signal block, cistern island, signal island, far dais.
	case_at(Vector3(26, 4.5, -40), "01 / SIGNAL BLOCK")
	case_at(Vector3(-13, 2.4, -45), "02 / CISTERN ISLAND")
	case_at(Vector3(13.5, 3.6, -63), "03 / SIGNAL ISLAND")
	case_at(Vector3(-12, 3.0, -108), "04 / THE DAIS")
	# Rod-only caches: the lid over the cistern, reached by riding the vent, and the nest on the beam.
	bonus_at(Vector3(-14, 8.0, -90), "CISTERN LID")
	bonus_at(Vector3(0, 9.6, -68), "RIGGING NEST")


func _place_enemies() -> void:
	enemy("hound", Vector3(9, 0.1, -14))
	enemy("hound", Vector3(-11, 2.5, -47))
	enemy("hound", Vector3(-8, 0.1, -101))
	enemy("sentry", Vector3(-26, 7.0, -52))
	enemy("sentry", Vector3(26, 5.0, -84))


func _place_hints() -> void:
	hint_zone(Vector3(0, 1.5, -24), Vector3(10, 3, 6), "DEEP WATER HURTS  /  the causeway is dry, {move} along it", 8.0)
	hint_zone(Vector3(0, 1.5, -42), Vector3(6, 3, 6), "ISLANDS  /  each has a ramp off the causeway, the rod is the shortcut", 6.0)
	hint_zone(Vector3(0, 1.5, -68), Vector3(10, 3, 6), "RIGGING  /  a weight latched to a cyan plate swings you; {lock} holds", 6.0)
	hint_zone(Vector3(0, 1.5, -84), Vector3(10, 3, 6), "OVERFLOW VENTS  /  rising air lifts you and cast weights, {reel} steers", 6.0)
