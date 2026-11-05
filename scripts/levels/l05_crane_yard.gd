extends "res://scripts/level_base.gd"
## L05 CRANE YARD (DESIGN: Foundry): a night container yard under three gantry cranes. Each gantry
## arm crosses the whole yard and carries two anchor plates over the central lane, so the rod swings
## from arm to arm, the fast route. Container stacks (2-3 high) line the lane with gaps; the outer
## alleys are open ground. Hounds run the alleys and drones hover over the yard. The four required
## cases are on foot (one up a loading dock ramp). The two caches are rod-only: one on the first
## gantry arm and one on the top of a three-high stack.

const INFO := {
	"title": "CRANE YARD",
	"zone": "foundry",
	"number": 5,
	"blurb": "Night crane yard: anchors on the gantry arms, container stacks in the alleys, hounds and drones.",
	"par_silver": 65.0,
	"par_gold": 40.0,
	"cases": 4,
	"bonus": 2,
	"enemies": true,
	"practice": false,
}

const SPAWN := Vector3(0, 0, 14)
const EXTRACT := Vector3(0, 0, -117)

## Containers are 2.6 m high, 2.6 m wide and 6 m long, long axis along z. Two columns stand at
## x = +-9 (their lane faces at +-7.7 leave a 15.4 m central lane). Each slot is a z position; the
## stack tables give the height per slot, and 0 is an empty slot, a gap that opens a cross passage.
const CONTAINER_SIZE := Vector3(2.6, 2.6, 6.0)
const CONTAINER_H := 2.6
const COLUMN_X := 9.0
const SLOT_Z := [-23.0, -32.5, -42.0, -51.5, -61.0, -70.5, -80.0, -89.5, -99.0, -108.5]
const WEST_STACKS := [3, 0, 2, 1, 2, 0, 3, 1, 2, 1]
const EAST_STACKS := [0, 2, 1, 3, 0, 2, 1, 0, 3, 2]
const STACK_MATERIALS := ["light_concrete", "rust", "light_concrete", "dark"]

## Gantry cranes at GANTRY_Z: legs stand in the outer apron, the arm spans the yard at ARM_Y.
## Anchor plates hang flush under the arm's underside (ARM_Y - 0.45), 0.06 m below the plate centre.
const GANTRY_Z := [-22.0, -60.0, -98.0]
const LEG_X := 19.5
const ARM_Y := 15.5
const ARM_SIZE := Vector3(39.0, 0.9, 1.6)
const ANCHOR_X := 5.0
const ANCHOR_Y := 14.99

## The loading dock: a 4.5 m deck in the east alley, reached by a ramp from the plaza.
const DOCK_CENTER := Vector3(13.0, 4.5, -44.0)
const DOCK_SIZE := Vector2(5.0, 8.0)
const DOCK_RAMP_START := Vector3(13.0, 0.0, -27.0)
const DOCK_RAMP_END := Vector3(13.0, 4.5, -39.6)


func _design() -> void:
	set_zone("foundry")
	set_spawn(SPAWN)
	_build_ground()
	_build_entrance()
	_build_containers()
	_build_gantries()
	_build_dock()
	_build_extraction()
	_place_objectives()
	_place_enemies()
	_place_lights()
	_place_hints()


func _build_ground() -> void:
	ground(Vector3(0, 0, -57.5), Vector2(44, 155), "concrete", 1.2)
	perimeter(Vector3(0, 0, -57.5), Vector2(43, 155), 8.0, "dark")
	# Cyan route cues run up the central lane. Visual only: no collision, no nav change.
	for z: float in [2.0, -8.0, -28.0, -38.0, -48.0, -58.0, -68.0, -78.0, -88.0, -98.0, -106.0]:
		box(Vector3(0, 0.02, z), Vector3(0.5, 0.04, 2.2), "cyan", false)


## A gate frame at the start and the yard title board. The first plates are on the gantry arms.
func _build_entrance() -> void:
	for side: float in [-1.0, 1.0]:
		box(Vector3(side * 8.5, 5.5, 8), Vector3(1.5, 11, 2), "light_concrete")
		box(Vector3(side * 8.5, 10.0, 8), Vector3(1.8, 0.3, 2.2), "yellow", false)
	box(Vector3(0, 10.4, 8), Vector3(18.5, 1.8, 2), "dark")
	box(Vector3(0, 10.65, 9.04), Vector3(15.2, 1.0, 0.1), "rust", false)
	label("C R A N E   Y A R D", Vector3(0, 10.65, 9.12), 56, Color("f6e4c4"), 0.012)
	label("FOUNDRY  /  DEPARTMENT OF UNFINISHED GRAVITY", Vector3(0, 9.82, 9.03), 26, Color("ffc46b"), 0.011)
	signboard("05   CRANE YARD", Vector3(-16, 2.1, 6), "THE ARMS HOLD THE PLATES   /   THE BOXES HOLD NOTHING", "amber")


## Both columns of containers: porcelain, dusty rose and plum boxes, each with a brass lane stripe.
func _build_containers() -> void:
	for index in range(SLOT_Z.size()):
		var z: float = SLOT_Z[index]
		_stack(-COLUMN_X, z, WEST_STACKS[index], index)
		_stack(COLUMN_X, z, EAST_STACKS[index], index + 1)
	# Deadpan contents on the lane faces of a few containers, one per column stack.
	_label_container(-COLUMN_X, SLOT_Z[2], "CONTENTS\nONE (1) SAUCER")
	_label_container(COLUMN_X, SLOT_Z[3], "CONTENTS\nTEA, COLD, FOR GUESTS")


## The lane faces toward the centre: +1 for the west column, -1 for the east column.
func _lane_side(x: float) -> float:
	return 1.0 if x < 0.0 else -1.0


func _stack(x: float, z: float, height: int, index: int) -> void:
	var lane: float = _lane_side(x)
	for tier in range(height):
		var base_y: float = float(tier) * CONTAINER_H
		var material: String = str(STACK_MATERIALS[(index + tier) % STACK_MATERIALS.size()])
		box(Vector3(x, base_y + CONTAINER_H * 0.5, z), CONTAINER_SIZE, material)
		# A brass stripe on the lane face, just outside the box. Visual only.
		box(Vector3(x + lane * 1.32, base_y + 2.2, z), Vector3(0.03, 0.14, 5.4), "yellow", false)


func _label_container(x: float, z: float, text: String) -> void:
	var lane: float = _lane_side(x)
	label(text, Vector3(x + lane * 1.36, 1.3, z), 26, Color("f4e6c8"), 0.011, false, 90.0 * lane)


## Three gantry cranes: two legs in the outer apron, an arm across the yard, and two anchor plates
## under each arm over the central lane.
func _build_gantries() -> void:
	for index in range(GANTRY_Z.size()):
		var z: float = GANTRY_Z[index]
		for side: float in [-1.0, 1.0]:
			pillar(Vector3(side * LEG_X, 0, z), ARM_Y - ARM_SIZE.y * 0.5, 1.2, "rust")
		box(Vector3(0, ARM_Y, z), ARM_SIZE, "rust")
		for x: float in [-ANCHOR_X, ANCHOR_X]:
			anchor(Vector3(x, ANCHOR_Y, z), Vector3.DOWN)
	# Rod-only cache nest on the middle arm, on top of the arm.
	platform(Vector3(0, 16.1, GANTRY_Z[1]), Vector2(4.0, 2.4), "light_concrete", false)


## The loading dock: a deck with posts, reached by one long ramp from the plaza.
func _build_dock() -> void:
	platform(DOCK_CENTER, DOCK_SIZE, "light_concrete", true)
	ramp(DOCK_RAMP_START, DOCK_RAMP_END, 4.5)


func _build_extraction() -> void:
	extraction(EXTRACT)
	for x: float in [-6.0, 6.0]:
		box(Vector3(x, 3.0, -124), Vector3(0.6, 6.0, 0.6), "rust")
	box(Vector3(0, 6.04, -124), Vector3(13, 1.13, 0.7), "dark")
	label("E X T R A C T I O N", Vector3(0, 6.22, -123.6), 38, Color("5ad6c8"), 0.012)
	label("BANK SALVAGE  /  HOLD POSITION", Vector3(0, 5.72, -123.6), 24, Color("f0e3c8"), 0.011)
	signboard("EXIT   >", Vector3(16, 2.1, -117), "LAST SIGNAL   /   THEN EXTRACT", "cyan")


func _place_objectives() -> void:
	case_at(Vector3(-14, 0, -12), "01 / SPARE HOOK")
	case_at(Vector3(13, DOCK_CENTER.y, -44), "02 / LOADING DOCK")
	case_at(Vector3(15, 0, -86), "03 / TEA CONTAINER")
	case_at(Vector3(-15, 0, -112), "04 / COLD CRANE")
	# Rod-only caches: one on the middle gantry arm, one on top of the first three-high stack.
	bonus_at(Vector3(0, 16.1, GANTRY_Z[1]), "ARM NEST")
	bonus_at(Vector3(-COLUMN_X, 3.0 * CONTAINER_H, SLOT_Z[0]), "STACK LID")


## Hounds in the outer alleys and the lane; drones over the open yard.
func _place_enemies() -> void:
	enemy("hound", Vector3(-14, 0.1, -40))
	enemy("hound", Vector3(14, 0.1, -66))
	enemy("hound", Vector3(0, 0.1, -84))
	enemy("drone", Vector3(0, 0.1, -46))
	enemy("drone", Vector3(-16, 0.1, -76))


## Amber lamps at the entrance and under the middle arm, a red fitting over the lane hound. Plus the sun.
func _place_lights() -> void:
	light(Vector3(0, 6.0, 4), Color("ffb347"), 1.6, 18.0)
	light(Vector3(0, 12.8, GANTRY_Z[1]), Color("ffb347"), 1.4, 16.0)
	light(Vector3(0, 3.0, -84.0), Color("ff5a40"), 1.2, 10.0)


func _place_hints() -> void:
	hint_zone(Vector3(0, 1.5, 9), Vector3(14, 3, 6), "CRANE ARMS HOLD THE PLATES  /  {cast} at a plate overhead, then {reel} to swing", 8.0)
	hint_zone(Vector3(0, 1.5, -18), Vector3(14, 3, 6), "HOUNDS RUN THE ALLEYS  /  keep moving, or {weapon} for the sidearm", 6.0)
	hint_zone(Vector3(0, 1.5, -44), Vector3(14, 3, 6), "DRONE  /  it telegraphs an orb: leave its aim line, or {weapon} for the sidearm, then {cast}", 8.0)
	hint_zone(Vector3(13, 1.5, -30), Vector3(8, 3, 6), "LOADING DOCK  /  the east ramp climbs to case 02 on foot", 6.0)
	hint_zone(Vector3(0, 1.5, -30), Vector3(14, 3, 6), "TWO CACHES  /  one hangs on the arm, one on a stack: the rod reaches them, feet do not", 6.0)
