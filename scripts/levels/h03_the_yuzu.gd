extends "res://scripts/levels/highlands_base.gd"
## H03 THE YUZU RUN (W2, W4): the third highland errand. Princess Capybara will only bathe with
## yuzu floating in the tub, and the only yuzu tree in the highlands grows on top of Marble Hill,
## south of the spawn, beside a giant toy marble run that somebody built down the hill's north face.
## The hopper at the top lets a marble go every few seconds; they roll the whole run and stop in the
## bin at the bottom. Two yuzu sit on ledges halfway up the run (walk up the trough between marbles,
## or come in over the wall with the rod), the third under the tree, inside a ring of teacup mines.
## A golden yuzu waits on the hopper's roof (a bonus: rod only). Once she has all three the hopper
## jams open, marbles pour down twice as often and the bin's front wall drops, so they roll out into
## the valley on the way back to the tub.

const INFO := {
	"title": "THE YUZU RUN",
	"zone": "highlands",
	"number": 9,
	"blurb": "The princess will only bathe with yuzu. The tree grows at the top of a giant marble run, and the marbles do not stop for anyone.",
	"par_silver": 330.0,
	"par_gold": 190.0,
	"cases": 3,
	"bonus": 1,
	"enemies": true,
	"practice": false,
	"loot_label": "FOR THE PRINCESS",
	"mission": "PICK THREE YUZU ON MARBLE HILL",
	"deliver": "TAKE THEM TO THE HOT TUB ON THE HILL",
	"deliver_hint": "THE HOPPER HAS JAMMED OPEN  /  marbles are loose in the valley: get to the hot tub",
}

const HILL := Vector2(80.0, 330.0)
const HILL_RADIUS := 130.0
const HILL_HEIGHT := 36.0
## Downhill, from the hopper on the summit toward the bin (and the spawn beyond it).
const RUN_DIR := Vector2(-0.196116, -0.980581)
const HOPPER := Vector2(79.8, 329.0)          # HILL + RUN_DIR * 1
const HOPPER_SIZE := Vector3(16.0, 7.0, 18.0)  # across, wall height, along
const BIN := Vector2(52.15, 190.76)            # HILL + RUN_DIR * 142
const BIN_SIZE := 18.0
const BIN_WALL := 3.8
const TREE := Vector2(105.5, 324.9)            # HILL + 26 m to the side (east)
## The trough: inner width, wall thickness and height, floor thickness. Every gap a player can use
## (the ledges, the bin door) has a bar across it at LINTEL: high enough to walk under, too low for
## a marble (4.6 m tall), so marbles stay in and players get out.
const INNER := 6.6
const WALL_T := 0.8
const WALL_H := 1.8
const FLOOR_T := 0.6
const CLEARANCE := 1.6       # the floor's top stays at least this far above the ground under it
const LEDGE_CLEARANCE := 0.5  # the same for a ledge, which only has to clear the ground
const FOOT_RISE := 0.7       # the run's last step up from the bin floor (the navmesh climbs 0.8)
const STILT_STEP := 11.0
const CHAIN_STEP := 10.0     # metres between the run's joints
const MAX_GRADE := 28.0      # degrees: the steepest piece of the run
const MAX_BEND := 0.45       # metres a joint may stand above the line between its neighbours
const GAP := 6.0             # wall gaps at the ledges (the hounds' navmesh needs them this wide)
const LINTEL := 3.2          # underside of the bar across a gap or a door, above the floor
const LEDGE := Vector2(5.0, 7.0)
## Ledges: fraction of the run's horizontal span from the top, side (+1 east, -1 west).
const STATIONS := [Vector2(0.36, -1.0), Vector2(0.66, 1.0)]
const MARBLE_RADIUS := 2.3
const RUN_PERIOD := 5.0      # seconds between marbles; halved once the hopper jams
const RUN_PUSH := 4.0
const HOUND_PACKS := [
	Vector2(10.0, 200.0), Vector2(110.0, 210.0), Vector2(150.0, 290.0), Vector2(20.0, 300.0),
	Vector2(160.0, 20.0), Vector2(230.0, -140.0), Vector2(120.0, -220.0),
]

var _run_top: Vector3
var _run_foot: Vector3
var _chain: Array[Vector3] = []     # the run's floor centre line, joint by joint, foot to top
var _bin_gate: StaticBody3D


func _design() -> void:
	extra_mounds = [Vector4(HILL.x, HILL.y, HILL_RADIUS, HILL_HEIGHT)]
	extra_spots = [Vector3(HOPPER.x, HOPPER.y, 11.0), Vector3(BIN.x, BIN.y, 12.0), Vector3(TREE.x, TREE.y, 7.0)]
	var top: Vector2 = HOPPER + RUN_DIR * HOPPER_SIZE.z * 0.5
	var foot: Vector2 = BIN - RUN_DIR * BIN_SIZE * 0.5
	var steps: int = int(top.distance_to(foot) / 9.0)
	for k in range(steps + 1):
		var at: Vector2 = top.lerp(foot, float(k) / float(steps))
		clear_spots.append(Vector3(at.x, at.y, 11.0))
	spawn_facing = 180.0
	intro_hint = "THE HIGHLANDS  /  she wants yuzu in her bath: pick three on Marble Hill to the south (mind the marble run), then bring them to her hot tub on the eastern hill"
	tub_sign = "PRINCESS CAPYBARA\nIS NOT TO BE DISTURBED\n(UNLESS YOU HAVE THE YUZU)"
	super()


func _place_objectives() -> void:
	_plan_run()
	var names := ["01 / YUZU, ON THE LOWER LEDGE", "02 / YUZU, ON THE UPPER LEDGE"]
	# Lower ledge first: the order a walker meets them coming up from the bin.
	for k in range(STATIONS.size()):
		var station: Vector2 = STATIONS[STATIONS.size() - 1 - k]
		case_at(_ledge_point(station), names[k], "yuzu")
	var toward: Vector2 = (HOPPER - TREE).normalized()
	case_at(_floor(TREE + toward * 2.8), "03 / YUZU, FROM THE TREE", "yuzu")


func _populate() -> void:
	_build_run()
	for station: Vector2 in STATIONS:
		_build_ledge(station)
	var gate: Vector3 = _build_hopper()
	_build_bin()
	_build_tree()
	var t: Node3D = traps()
	var flat := _flat_basis()
	var slots: Array[Vector3] = []
	for local: Vector2 in [Vector2(-5.0, 1.0), Vector2(0.0, 1.0), Vector2(5.0, 1.0), Vector2(-5.0, 6.0), Vector2(0.0, 6.0), Vector2(5.0, 6.0)]:
		slots.append(Vector3(HOPPER.x, _run_top.y + MARBLE_RADIUS + 0.03, HOPPER.y) + flat * Vector3(local.x, 0.0, local.y))
	t.call("marble_run", slots, gate, MARBLE_RADIUS, RUN_PERIOD, Vector3(RUN_DIR.x, 0.0, RUN_DIR.y) * RUN_PUSH, 1.0)
	_build_signs()
	scatter_mines(Rect2(-60.0, 100.0, 220.0, 80.0), 16, 3301)
	scatter_mines(Rect2(100.0, -200.0, 180.0, 220.0), 14, 3307)
	marble(TUB_XZ + Vector2(25.0, -25.0), 3.5, PAD_XZ + Vector2(-40.0, 40.0), 60.0, Vector3(-6.0, 0.0, 6.0))
	for spot: Vector2 in HOUND_PACKS:
		enemy("hound", _floor(spot) + Vector3.UP * 0.1)
	if not loot_collected.is_connected(_on_yuzu_taken):
		loot_collected.connect(_on_yuzu_taken)


## Where the run goes: from the bin's back wall up to the hopper's front on the summit, as a chain of
## straight pieces CHAIN_STEP long. Each joint first rides CLEARANCE above the highest ground under
## its stretch (centre line and both walls). Then joints are only ever raised, never lowered: no
## piece steeper than MAX_GRADE (it stays walkable), and no crest sharper than MAX_BEND (a marble at
## full speed would leave the floor there and could jump the wall). The foot may come up too, and
## the bin then stands on a plinth with a ramp to its door.
func _plan_run() -> void:
	var top: Vector2 = HOPPER + RUN_DIR * HOPPER_SIZE.z * 0.5
	var foot: Vector2 = BIN - RUN_DIR * BIN_SIZE * 0.5
	var side := Vector2(-RUN_DIR.y, RUN_DIR.x)
	var reach: float = INNER * 0.5 + WALL_T
	var span: float = foot.distance_to(top)
	var count: int = int(ceil(span / CHAIN_STEP))
	var step: float = span / float(count)
	var heights: Array[float] = []
	for i in range(count + 1):
		var height: float = land.height_at(foot.x, foot.y) + FOOT_RISE
		if i > 0:
			height = -INF
			for k in range(-2, 3):
				var probe: Vector2 = foot.lerp(top, clampf((float(i) + float(k) * 0.25) / float(count), 0.0, 1.0))
				for s: float in [-1.0, 0.0, 1.0]:
					var under: Vector2 = probe + side * reach * s
					height = maxf(height, land.height_at(under.x, under.y) + CLEARANCE)
			# A ledge reaches LEDGE.x further out on its side: its ground counts too.
			var from_top: float = span * (1.0 - float(i) / float(count))
			for station: Vector2 in STATIONS:
				if absf(station.x * span - from_top) > LEDGE.y * 0.5 + span / float(count):
					continue
				for k in range(-2, 3):
					var along: Vector2 = foot.lerp(top, 1.0 - clampf(station.x + float(k) * LEDGE.y * 0.25 / span, 0.0, 1.0))
					for out: float in [reach, reach + LEDGE.x * 0.5, reach + LEDGE.x]:
						var under: Vector2 = along + side * out * station.y
						height = maxf(height, land.height_at(under.x, under.y) + LEDGE_CLEARANCE)
		heights.append(height)
	var rise: float = tan(deg_to_rad(MAX_GRADE)) * step
	for _round in range(2000):
		var moved: bool = false
		for i in range(count, 0, -1):
			if heights[i - 1] < heights[i] - rise - 0.001:
				heights[i - 1] = heights[i] - rise
				moved = true
		for i in range(1, count):
			var bend: float = heights[i] - (heights[i - 1] + heights[i + 1]) * 0.5
			if bend > MAX_BEND + 0.001:
				heights[i - 1] += (bend - MAX_BEND) * 2.0
				moved = true
		if not moved:
			break
	_chain.clear()
	for i in range(count + 1):
		var at: Vector2 = foot.lerp(top, float(i) / float(count))
		_chain.append(Vector3(at.x, heights[i], at.y))
	_run_foot = _chain[0]
	_run_top = _chain[_chain.size() - 1]


## Level, facing down the run (-z toward the bin).
func _flat_basis() -> Basis:
	return Basis.looking_at(Vector3(RUN_DIR.x, 0.0, RUN_DIR.y), Vector3.UP)


## Horizontal length of the run, hopper to bin.
func run_span() -> float:
	return Vector2(_run_top.x, _run_top.z).distance_to(Vector2(_run_foot.x, _run_foot.z))


## The floor's centre line at a fraction of the run's horizontal span (0 the top, 1 the foot).
func floor_at(fraction: float) -> Vector3:
	var at: Vector2 = Vector2(_run_top.x, _run_top.z).lerp(Vector2(_run_foot.x, _run_foot.z), fraction)
	var from_foot: float = Vector2(_run_foot.x, _run_foot.z).distance_to(at)
	for k in range(_chain.size() - 1):
		var a: Vector3 = _chain[k]
		var b: Vector3 = _chain[k + 1]
		var a_s: float = Vector2(_run_foot.x, _run_foot.z).distance_to(Vector2(a.x, a.z))
		var b_s: float = Vector2(_run_foot.x, _run_foot.z).distance_to(Vector2(b.x, b.z))
		if from_foot <= b_s + 0.001 or k == _chain.size() - 2:
			return a.lerp(b, clampf((from_foot - a_s) / maxf(b_s - a_s, 0.001), 0.0, 1.0))
	return _run_top


## The tilt of the run's piece at a fraction of its span (-z down the run, x level).
func slope_basis(fraction: float) -> Basis:
	var below: Vector3 = floor_at(minf(fraction + 0.01, 1.0))
	var above: Vector3 = floor_at(maxf(fraction - 0.01, 0.0))
	return Basis.looking_at((below - above).normalized(), Vector3.UP)


## Steepest piece of the run, in degrees.
func run_grade() -> float:
	var steepest: float = 0.0
	for k in range(_chain.size() - 1):
		var d: Vector3 = _chain[k + 1] - _chain[k]
		steepest = maxf(steepest, rad_to_deg(atan2(d.y, Vector2(d.x, d.z).length())))
	return steepest


## The trough, piece by piece: an amber floor, red walls with gaps at the ledges, white stilts.
func _build_run() -> void:
	var reach: float = INNER * 0.5 + WALL_T
	var span: float = run_span()
	for k in range(_chain.size() - 1):
		var low: Vector3 = _chain[k]
		var high: Vector3 = _chain[k + 1]
		var length: float = high.distance_to(low)
		var frame := Transform3D(Basis.looking_at((low - high).normalized(), Vector3.UP), high)
		# Each piece runs 0.25 m past both joints, so no joint opens a crack.
		_box_at(frame * Transform3D(Basis.IDENTITY, Vector3(0.0, -FLOOR_T * 0.5, -length * 0.5)), Vector3(reach * 2.0, FLOOR_T, length + 0.5), "amber", true)
		# Station gaps, as distances along this piece from its upper end.
		var high_s: float = Vector2(_run_top.x, _run_top.z).distance_to(Vector2(high.x, high.z))
		var low_s: float = Vector2(_run_top.x, _run_top.z).distance_to(Vector2(low.x, low.z))
		var stretch: float = length / maxf(low_s - high_s, 0.001)
		for side: float in [-1.0, 1.0]:
			var start: float = 0.0
			for station: Vector2 in STATIONS:
				var at_s: float = station.x * span
				if station.y != side or at_s < high_s or at_s > low_s:
					continue
				var along: float = (at_s - high_s) * stretch
				_wall_piece(frame, side, start, along - GAP * 0.5)
				start = along + GAP * 0.5
			_wall_piece(frame, side, start, length)
		var posts: int = int(length / STILT_STEP)
		for p in range(posts + 1):
			var s: float = (float(p) + 0.5) * length / float(posts + 1)
			for side: float in [-1.0, 1.0]:
				_stilt(frame * Vector3(side * (reach - 0.45), -FLOOR_T, -s))


func _wall_piece(frame: Transform3D, side: float, from_s: float, to_s: float) -> void:
	if to_s - from_s < 0.3:
		return
	var x: float = side * (INNER * 0.5 + WALL_T * 0.5)
	_box_at(frame * Transform3D(Basis.IDENTITY, Vector3(x, WALL_H * 0.5, -(from_s + to_s) * 0.5)), Vector3(WALL_T, WALL_H, to_s - from_s), "red", true)


## A white post from the ground up to point (the underside of something).
func _stilt(point: Vector3) -> void:
	var ground: float = land.height_at(point.x, point.z)
	if point.y - ground > 0.4:
		pillar(Vector3(point.x, ground - 0.4, point.z), point.y - ground + 0.4, 0.7, "white")


## The floor point of a ledge's yuzu, just outside the wall gap.
func _ledge_point(station: Vector2) -> Vector3:
	var on_floor: Vector3 = floor_at(station.x)
	var out: Vector3 = _flat_basis().x * station.y
	return on_floor + out * (INNER * 0.5 + WALL_T + LEDGE.x * 0.4)


## A ledge outside a wall gap: a bay of the trough floor at the same tilt, so it meets the floor
## flush all across the gap, with a rail on its outer edge.
func _build_ledge(station: Vector2) -> void:
	var tilt: Basis = slope_basis(station.x)
	var on_floor: Vector3 = floor_at(station.x)
	var out: Vector3 = tilt.x * station.y
	# A red gateway over the gap: two posts and a bar a marble cannot roll under.
	var gate_x: float = station.y * (INNER * 0.5 + WALL_T * 0.5)
	for end: float in [-1.0, 1.0]:
		_box_at(Transform3D(tilt, on_floor + tilt * Vector3(gate_x, (LINTEL + 0.5) * 0.5, end * (GAP * 0.5 + 0.3))), Vector3(WALL_T, LINTEL + 0.5, 0.6), "red", true)
	_box_at(Transform3D(tilt, on_floor + tilt * Vector3(gate_x, LINTEL + 0.25, 0.0)), Vector3(WALL_T, 0.5, GAP + 1.2), "red", true)
	var centre: Vector3 = on_floor + out * (INNER * 0.5 + WALL_T + LEDGE.x * 0.5)
	_box_at(Transform3D(tilt, centre - tilt.y * FLOOR_T * 0.5), Vector3(LEDGE.x, FLOOR_T, LEDGE.y), "amber", true)
	_box_at(Transform3D(tilt, centre + out * (LEDGE.x * 0.5 - 0.2) + tilt.y * 0.5), Vector3(0.4, 1.0, LEDGE.y), "red", true)
	for a: float in [-1.0, 1.0]:
		for b: float in [-1.0, 1.0]:
			var corner: Vector3 = centre + tilt * Vector3(a * (LEDGE.x * 0.5 - 0.5), -FLOOR_T, b * (LEDGE.y * 0.5 - 0.5))
			_stilt(corner)


## The hopper on the summit: a white tower, yellow walls and a red roof around six marbles, with
## the gate (an opening as wide as the trough) facing down the run. Returns where a marble is let go.
func _build_hopper() -> Vector3:
	var flat: Basis = _flat_basis()
	var top_y: float = _run_top.y
	var half := Vector2(HOPPER_SIZE.x * 0.5, HOPPER_SIZE.z * 0.5)
	var ground: float = INF
	for a: float in [-1.0, 1.0]:
		for b: float in [-1.0, 1.0]:
			var corner: Vector3 = Vector3(HOPPER.x, 0.0, HOPPER.y) + flat * Vector3(a * half.x, 0.0, b * half.y)
			ground = minf(ground, land.height_at(corner.x, corner.z))
	var base: float = ground - 0.5
	_box_at(Transform3D(flat, Vector3(HOPPER.x, (base + top_y) * 0.5, HOPPER.y)), Vector3(HOPPER_SIZE.x, top_y - base, HOPPER_SIZE.z), "white", true)
	var frame := Transform3D(flat, Vector3(HOPPER.x, top_y, HOPPER.y))
	var tall: float = HOPPER_SIZE.y
	var t: float = 0.6
	_box_at(frame * Transform3D(Basis.IDENTITY, Vector3(0.0, tall * 0.5, half.y - t * 0.5)), Vector3(HOPPER_SIZE.x, tall, t), "yellow", true)
	for side: float in [-1.0, 1.0]:
		_box_at(frame * Transform3D(Basis.IDENTITY, Vector3(side * (half.x - t * 0.5), tall * 0.5, 0.0)), Vector3(t, tall, HOPPER_SIZE.z - t * 2.0), "yellow", true)
	var opening: float = (INNER * 0.5 + WALL_T) * 2.0
	var opening_high: float = 5.6
	var piece: float = (HOPPER_SIZE.x - opening) * 0.5
	for side: float in [-1.0, 1.0]:
		_box_at(frame * Transform3D(Basis.IDENTITY, Vector3(side * (opening * 0.5 + piece * 0.5), tall * 0.5, -half.y + t * 0.5)), Vector3(piece, tall, t), "yellow", true)
	_box_at(frame * Transform3D(Basis.IDENTITY, Vector3(0.0, (opening_high + tall) * 0.5, -half.y + t * 0.5)), Vector3(opening, tall - opening_high, t), "yellow", true)
	_box_at(frame * Transform3D(Basis.IDENTITY, Vector3(0.0, tall + 0.25, 0.0)), Vector3(HOPPER_SIZE.x + 0.6, 0.5, HOPPER_SIZE.z + 0.6), "red", true)
	bonus_at(frame * Vector3(0.0, tall + 0.5, 2.0), "BONUS / THE GOLDEN YUZU, ON THE HOPPER", "yuzu_gold")
	return frame * Vector3(0.0, MARBLE_RADIUS + 0.03, -half.y + 2.4)


## The bin at the bottom: cyan walls on three sides with the run coming in through the back, a door
## too narrow for a marble in the east wall, and a front wall that drops when the hopper jams.
func _build_bin() -> void:
	var flat: Basis = _flat_basis()
	var ground: float = land.height_at(BIN.x, BIN.y)
	var floor_y: float = _run_foot.y - FOOT_RISE
	var frame := Transform3D(flat, Vector3(BIN.x, floor_y, BIN.y))
	var half: float = BIN_SIZE * 0.5
	var t: float = 0.8
	if floor_y > ground + 0.3:
		# The run's foot had to come up: the bin stands on a solid white plinth, with a ramp
		# from the ground up to its door.
		var low: float = ground - 1.0
		for a: float in [-1.0, 1.0]:
			for b: float in [-1.0, 1.0]:
				var corner: Vector3 = frame * Vector3(a * half, 0.0, b * half)
				low = minf(low, land.height_at(corner.x, corner.z) - 0.5)
		_box_at(Transform3D(flat, Vector3(BIN.x, (low + floor_y) * 0.5, BIN.y)), Vector3(BIN_SIZE, floor_y - low, BIN_SIZE), "white", true)
		var out: Vector3 = flat.x
		var threshold: Vector3 = frame * Vector3(half, 0.0, 0.0)
		var length: float = (floor_y - ground) / tan(deg_to_rad(24.0)) + 1.0
		var landing: Vector3 = threshold + out * length
		landing.y = land.height_at(landing.x, landing.z)
		ramp(landing, threshold, 4.4, "amber")
	var sunk: float = 0.6
	var tall: float = BIN_WALL + sunk
	var y: float = BIN_WALL - tall * 0.5
	var opening: float = (INNER * 0.5 + WALL_T) * 2.0 + 0.4
	var piece: float = (BIN_SIZE - opening) * 0.5
	for side: float in [-1.0, 1.0]:
		_box_at(frame * Transform3D(Basis.IDENTITY, Vector3(side * (opening * 0.5 + piece * 0.5), y, half - t * 0.5)), Vector3(piece, tall, t), "cyan", true)
	_box_at(frame * Transform3D(Basis.IDENTITY, Vector3(-(half - t * 0.5), y, 0.0)), Vector3(t, tall, BIN_SIZE - t * 2.0), "cyan", true)
	var door: float = GAP
	var length: float = (BIN_SIZE - t * 2.0 - door) * 0.5
	for end: float in [-1.0, 1.0]:
		_box_at(frame * Transform3D(Basis.IDENTITY, Vector3(half - t * 0.5, y, end * (door * 0.5 + length * 0.5))), Vector3(t, tall, length), "cyan", true)
	_box_at(frame * Transform3D(Basis.IDENTITY, Vector3(half - t * 0.5, (LINTEL + BIN_WALL) * 0.5, 0.0)), Vector3(t, BIN_WALL - LINTEL, door + 0.2), "cyan", true)
	# The front wall is its own body, so it can drop into the ground later.
	_bin_gate = StaticBody3D.new()
	_bin_gate.name = "BinGate"
	var size := Vector3(BIN_SIZE, tall, t)
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	_bin_gate.add_child(collision)
	var view := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	view.mesh = mesh
	view.material_override = _materials["cyan"]
	_bin_gate.add_child(view)
	_bin_gate.transform = frame * Transform3D(Basis.IDENTITY, Vector3(0.0, y, -(half - t * 0.5)))
	adopt_world_body(_bin_gate)


## The yuzu tree: a bent trunk, two round crowns with fruit on them, and two rings of teacup mines.
func _build_tree() -> void:
	var base: Vector3 = _floor(TREE)
	pipe(base + Vector3(0.0, -0.3, 0.0), base + Vector3(0.4, 3.0, 0.2), 0.36, "rust")
	pipe(base + Vector3(0.4, 3.0, 0.2), base + Vector3(-0.2, 4.6, -0.1), 0.28, "rust")
	var crowns: Array[Vector4] = [Vector4(-0.2, 5.8, -0.1, 2.6), Vector4(1.6, 4.9, 0.9, 1.7)]
	for crown: Vector4 in crowns:
		_ball(base + Vector3(crown.x, crown.y, crown.z), crown.w, "grass")
	for k in range(10):
		var crown: Vector4 = crowns[k % 2]
		var angle: float = float(k) * 2.39996
		var lift: float = sin(float(k) * 1.3) * 0.5
		var at := Vector3(cos(angle) * sqrt(1.0 - lift * lift), lift, sin(angle) * sqrt(1.0 - lift * lift)) * crown.w
		_ball(base + Vector3(crown.x, crown.y, crown.z) + at, 0.32, "amber")
	var t: Node3D = traps()
	for ring: Vector3 in [Vector3(5.5, 8.0, 0.0), Vector3(9.5, 9.0, 0.35)]:
		for k in range(int(ring.y)):
			var angle: float = ring.z + float(k) * TAU / ring.y
			var spot: Vector2 = TREE + Vector2(cos(angle), sin(angle)) * ring.x
			t.call("mine", _floor(spot))


## Boards on posts, beside the bin door and below the tree. Nothing floats.
func _build_signs() -> void:
	var flat: Basis = _flat_basis()
	var east: Vector3 = flat.x
	var door: Vector3 = Vector3(BIN.x, 0.0, BIN.y) + east * (BIN_SIZE * 0.5 + 3.0) + flat * Vector3(0.0, 0.0, 5.0)
	var facing: float = rad_to_deg(atan2(east.x, east.z))
	_sign("THE MARBLE RUN\nPLEASE DO NOT WALK UP THE RUN\n(THE MARBLES WILL NOT STOP)", _floor(Vector2(door.x, door.z)), Vector2(6.2, 2.0), facing)
	var toward: Vector2 = (SPAWN_XZ - TREE).normalized()
	var below: Vector2 = TREE + toward * 13.5
	_sign("YUZU TREE\nTEA GARDEN, MIND THE CUPS\n(THROW SOMETHING IN FIRST)", _floor(below), Vector2(5.6, 2.0), rad_to_deg(atan2(toward.x, toward.y)))


## Once she has all three yuzu: marbles twice as often, and the bin's front wall sinks away.
func _on_yuzu_taken(kind: String, _value: int) -> void:
	if kind != "case" or collected_loot < total_loot:
		return
	traps().call("set_run_tempo", 2.0)
	if is_instance_valid(_bin_gate):
		var drop: Tween = create_tween()
		drop.tween_property(_bin_gate, "position:y", _bin_gate.position.y - (BIN_WALL + 1.0), 1.5)
