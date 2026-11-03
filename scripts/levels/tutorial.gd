extends "res://scripts/level_base.gd"
## INDUCTION: the linear training course (DESIGN level 0). Every station has a hint zone that names
## one tool, in order: walk, cast, lock, reel, cut, a gap, an anchor, a swing, an updraft, the sidearm
## on a training dummy, one case, extraction. The gap is crossed by the rod or walked round at the side
## strips, so the required route is always on foot. The only enemy is a dummy, which never attacks.

const INFO := {
	"title": "INDUCTION",
	"zone": "floodworks",
	"number": 0,
	"blurb": "Linear training course: walk, cast, lock, reel, cut, a gap, an anchor swing, an updraft, a dummy, one case.",
	"par_silver": 60.0,
	"par_gold": 30.0,
	"cases": 1,
	"bonus": 0,
	"enemies": true,         # the training dummy is an enemy node, so this must say so (levels_test)
	"practice": false,
}

const SPAWN := Vector3(0.0, 0.0, 12.0)
const HALF_WIDTH := 14.0
## The pit sits in the middle of the corridor. Walkers use the strips on either side.
const PIT_X := 5.0
const PIT_Z_NEAR := -50.0
const PIT_Z_FAR := -56.0
const GANTRY_Z := -66.0
const LEDGE_CENTER := Vector3(-8.0, 3.5, -12.0)
const SWING_LEDGE := Vector3(10.0, 3.0, -80.0)
const UPDRAFT_BASE := Vector3(-8.0, 0.0, -92.0)
const UPDRAFT_SIZE := Vector3(3.6, 14.0, 3.6)
const DUMMY_SPOT := Vector3(5.0, 0.0, -102.0)
const CASE_SPOT := Vector3(-6.0, 0.0, -109.0)
const EXTRACTION_SPOT := Vector3(0.0, 0.0, -115.0)


func _design() -> void:
	set_zone("floodworks")
	set_spawn(SPAWN)
	_build_ground()
	_build_walk_and_cast()
	_build_lock_reel_cut()
	_build_gap()
	_build_anchor_swing()
	_build_updraft()
	_build_sidearm()
	_build_case_and_extraction()
	_build_route_cues()
	_build_dressing()
	_build_hints()


## Ground in pieces so the pit has no floor. The corridor is 28 m wide, 136 m long.
func _build_ground() -> void:
	ground(Vector3(0.0, 0.0, -18.0), Vector2(28.0, 64.0))
	ground(Vector3(0.0, 0.0, -88.0), Vector2(28.0, 64.0))
	ground(Vector3(-9.5, 0.0, -53.0), Vector2(9.0, 6.0))
	ground(Vector3(9.5, 0.0, -53.0), Vector2(9.0, 6.0))
	perimeter(Vector3(0.0, 0.0, -53.0), Vector2(28.0, 136.0), 6.0)


## Station 1 (walk) and station 2 (cast). A ramp gives the ledge an on-foot route.
func _build_walk_and_cast() -> void:
	signboard("INDUCTION", Vector3(-9.0, 2.1, 7.0), "ALL STATIONS ARE COMPULSORY", "cyan")
	platform(LEDGE_CENTER, Vector2(6.0, 6.0), "dark", true)
	ramp(Vector3(-8.0, 0.0, 2.0), Vector3(-8.0, 3.5, -9.5), 4.0)
	label("LEDGE  /  THE WEIGHT IS PERSUADED", LEDGE_CENTER + Vector3(0.0, 2.6, 0.0), 40, Color("67d5d2"), 0.02, true)


## Station 3 (lock) and station 4 (reel) and station 5 (cut).
func _build_lock_reel_cut() -> void:
	cylinder(Vector3(6.0, 0.0, -22.0), 0.7, 2.4, "yellow")
	label("POST  /  A WEIGHT WILL WANT IT", Vector3(6.0, 3.2, -22.0), 34, Color("e8d6a8"), 0.018, true)
	crate(Vector3(-7.0, 0.0, -31.0), Vector3(3.0, 2.3, 3.0))
	barrier(Vector3(-6.0, 0.0, -41.0), 4.0)


## Station 6: a gap. Sides strips give a walking detour; the rod can cross the middle.
func _build_gap() -> void:
	# Yellow rails along the pit edges, on the strip side, so the void reads as an edge.
	barrier(Vector3(-PIT_X - 0.6, 0.0, -53.0), 6.0, 90.0)
	barrier(Vector3(PIT_X + 0.6, 0.0, -53.0), 6.0, 90.0)
	signboard("GAP", Vector3(-9.0, 2.1, -46.0), "THE GAP IS PART OF THE PLAN", "amber")


## Station 7 (anchor) and station 8 (swing). The beam is 8 m up; the ledge is on foot via a ramp.
func _build_anchor_swing() -> void:
	for x: float in [-6.5, 6.5]:
		box(Vector3(x, 4.0, GANTRY_Z), Vector3(0.9, 8.0, 0.9), "rust")
	box(Vector3(0.0, 8.0, GANTRY_Z), Vector3(14.0, 0.4, 1.2), "rust")
	# Plates hang flush under the beam (its underside is at 7.8 m).
	for x: float in [-3.5, 3.5]:
		anchor(Vector3(x, 7.74, GANTRY_Z), Vector3.DOWN)
	label("ANCHOR  /  CYAN PLATES", Vector3(0.0, 9.3, GANTRY_Z), 46, Color("67d5d2"), 0.024, true)
	platform(SWING_LEDGE, Vector2(6.0, 6.0), "dark", true)
	ramp(Vector3(10.0, 0.0, -63.0), Vector3(10.0, 3.0, -78.0), 4.0)
	label("LEDGE  /  NOT A STAIR", SWING_LEDGE + Vector3(0.0, 1.6, 0.0), 38, Color("e4ddbd"), 0.02, true)


## Station 9: a 14 m updraft column with a catch platform on top, as in the range.
func _build_updraft() -> void:
	updraft(UPDRAFT_BASE, UPDRAFT_SIZE, 26.0)
	platform(UPDRAFT_BASE + Vector3(0.0, UPDRAFT_SIZE.y, 0.0), Vector2(6.0, 6.0), "dark", true)
	# Pale, not cyan: cyan disappears against the teal sky behind the column.
	label("UPDRAFT  /  14 M", UPDRAFT_BASE + Vector3(0.0, UPDRAFT_SIZE.y + 3.4, 0.0), 46, Color("ffe3b0"), 0.024, true)


## Station 10: the sidearm on one training dummy. Dummies never attack and are the only enemy here.
func _build_sidearm() -> void:
	enemy("dummy", DUMMY_SPOT)
	label("TRAINING DUMMY  /  DOES NOT FIGHT BACK", DUMMY_SPOT + Vector3(0.0, 2.6, 0.0), 34, Color("e4ddbd"), 0.016, true)


## Station 11 (one required case, on foot) and station 12 (extraction pad).
func _build_case_and_extraction() -> void:
	case_at(CASE_SPOT, "01 / TRAINING CASE")
	extraction(EXTRACTION_SPOT)
	for x: float in [-7.5, 7.5]:
		box(Vector3(x, 1.6, EXTRACTION_SPOT.z), Vector3(2.5, 3.2, 8.0), "light_concrete")
	label("EXTRACTION", Vector3(0.0, 4.6, -119.3), 60, Color("5ad6c8"), 0.024)


## Cyan route cues down the centre line. They are flat, non-solid, and skip the open pit.
func _build_route_cues() -> void:
	for z in range(8, -110, -6):
		var at: float = float(z)
		if at < PIT_Z_NEAR + 1.0 and at > PIT_Z_FAR - 1.0:
			continue
		box(Vector3(0.0, 0.02, at), Vector3(0.4, 0.03, 1.4), "cyan", false)


## Department notices and the sky ring. The shared dreamscape pass adds the rest.
func _build_dressing() -> void:
	skyline(5150, Vector3(0.0, 0.0, -53.0), 48.0, 75.0, 18)
	light(Vector3(0.0, 7.0, -34.0), Color("ffc46b"), 1.2, 16.0)
	light(Vector3(-8.0, 8.0, -90.0), Color("9ff0e6"), 1.0, 12.0)
	light(Vector3(0.0, 4.0, -115.0), Color("ffe3b0"), 1.0, 14.0)


## One hint zone per station. Zones span the corridor and abut each other, so every lesson fires as the
## player arrives. Each fires once per build (CONTRACT 4.11).
func _build_hints() -> void:
	_station(4.0, 14.0, "WALK  /  {move} to walk, {look} to turn, {jump} to hop", 8.0)
	_station(-16.0, 4.0, "CAST  /  hold {cast} to charge, release to throw the weight at the cyan ledge", 8.0)
	_station(-28.0, -16.0, "LOCK  /  {lock} stops the spool, so the weight pulls on the line", 8.0)
	_station(-36.0, -28.0, "REEL  /  hold {reel} to take the line in; reel all the way to recover the weight", 8.0)
	_station(-44.0, -36.0, "CUT  /  {cut} lets go; both ends keep their speed", 7.0)
	_station(-50.0, -44.0, "GAP  /  cast over the pit, or walk round the side strips", 7.0)
	_station(-68.0, -56.0, "ANCHOR  /  a weight that touches a cyan plate latches; {reel} pulls you in", 8.0)
	_station(-84.0, -68.0, "SWING  /  latch to a plate, {reel} to swing, {cut} to drop onto the ledge", 8.0)
	_station(-98.0, -84.0, "UPDRAFT  /  stand inside the column to rise", 7.0)
	_station(-106.0, -98.0, "SIDEARM  /  {weapon} draws it, {cast} fires, {reload} reloads", 8.0)
	_station(-112.0, -106.0, "CASE  /  walk into the brass case to take it", 7.0)
	_station(-118.0, -112.0, "EXTRACT  /  stand on the cyan pad with the case and hold position", 8.0)


## A full-width hint zone between two z values (z_near is the higher number, the one the player meets first).
func _station(z_near: float, z_far: float, text: String, duration: float) -> void:
	var depth: float = absf(z_near - z_far)
	var centre_z: float = (z_near + z_far) * 0.5
	hint_zone(Vector3(0.0, 1.5, centre_z), Vector3(2.0 * HALF_WIDTH, 3.0, depth), text, duration)
