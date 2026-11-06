extends "res://scripts/levels/highlands_base.gd"
## H04 THE DUCKLINGS (W2, W4): the fourth highland errand. Princess Capybara's rubber duck has had
## ducklings (nobody asks how), and all three have waddled off up the old aqueduct that once
## carried bath soap from the Soap Spring in the northern foothills down to her hill. The aqueduct
## still stands on its arches, but its paving is four hundred years old: every slab cracks under the
## player and gives way a moment later (a 15 to 25 m drop onto teacup mines and hounds), so the way
## along it is to keep moving and rest on the stone (the piers' ribs and the towers). One duckling
## sits at the spring, beside a soap bottle the size of a house, and two on the towers. A golden
## duckling waits on the bottle's pump (a bonus: rod only). Once she has all three, the aqueduct
## gives up: a wave of collapse runs out along the deck from wherever the last one was picked up.

const INFO := {
	"title": "THE DUCKLINGS",
	"zone": "highlands",
	"number": 10,
	"blurb": "Her rubber duck has had ducklings, and they have wandered up the old aqueduct. The paving is four hundred years old and it does not want you on it.",
	"par_silver": 250.0,
	"par_gold": 145.0,
	"cases": 3,
	"bonus": 1,
	"enemies": true,
	"practice": false,
	"loot_label": "FOR THE PRINCESS",
	"mission": "BRING BACK HER RUBBER DUCK'S THREE DUCKLINGS",
	"deliver": "TAKE THEM TO THE HOT TUB ON THE HILL",
	"deliver_hint": "THE AQUEDUCT IS GIVING WAY  /  keep moving and get the ducklings to the hot tub",
}

## The head of the deck (where the paving starts, at the spring) and the way it runs, downhill
## toward the princess's hill. Distances along the aqueduct (s) count from the head.
const HEAD := Vector2(146.7, -457.6)
const DOWN := Vector2(0.671512, 0.740994)       # toward (285, -305), normalised
const HEAD_PAD := 10.0       # the stone platform behind the head (s from -HEAD_PAD to 0)
const SPANS := 4             # paved spans, with a tower between each pair
const BAYS := 4              # paved bays in a span, with a rib between each pair
const TILE := 3.0
const PAVED := 9.0           # one bay of paving along the deck (three slabs)
const WIDTH := 6.0           # the paving across the deck (two slabs)
const RIB := 1.6             # stone strip across the deck on top of each pier
const PIER_WIDTH := 7.2
const TOWER := Vector2(10.0, 8.0)   # across, along
const ARCH_SIDE := 3.35      # arches run under the deck's two edges, outside the paving
const ARCH_RING := 0.7
const ARCH_DROP := 1.0       # the arches' crowns stand this far below the deck
const CAUSEWAY_MAX := 60.0   # the solid causeway at the tail runs on until it meets the hill
const CAUSEWAY_SOLID := 4.0  # where the ground is this close under the deck, the causeway is a solid wall
const BOTTLE_S := -17.0
const BOTTLE_RADIUS := 4.5
const BOTTLE_RISE := 14.0    # the bottle's shoulder above the deck
const WAVE_SPEED := 5.5      # m/s: a little slower than a run, so running ahead of it works
const WAVE_DELAY := 1.0
const HOUND_PACKS := [
	Vector2(100.0, -430.0), Vector2(200.0, -440.0), Vector2(230.0, -350.0), Vector2(160.0, -340.0),
	Vector2(250.0, -240.0), Vector2(80.0, -220.0), Vector2(170.0, -150.0),
]

var deck_y: float = 0.0
var causeway_end: float = 0.0     # s where the tail causeway meets the hill
var towers: Array[float] = []     # s of each tower's centre, head to tail
var ribs: Array[float] = []       # s of each rib's centre
var deck_fields: Array[int] = []  # the traps' crack fields that pave the deck
var _turn: Basis


func _design() -> void:
	_turn = Basis(Vector3.UP, atan2(DOWN.x, DOWN.y))
	nav_area = AABB(Vector3(-420.0, -20.0, -500.0), Vector3(840.0, 160.0, 920.0))
	var pad: Vector2 = HEAD - DOWN * (HEAD_PAD * 0.5)
	extra_spots = [Vector3(pad.x, pad.y, 9.0)]
	var s: float = BOTTLE_S - BOTTLE_RADIUS - 4.0
	while s < span_start(SPANS) + span_length() + CAUSEWAY_MAX:
		var at: Vector2 = HEAD + DOWN * s
		clear_spots.append(Vector3(at.x, at.y, 9.0))
		s += 8.0
	spawn_facing = -26.6
	intro_hint = "THE HIGHLANDS  /  her rubber duck has had ducklings, and they have wandered up the old aqueduct to the north-east: bring all three to her hot tub on the eastern hill"
	tub_sign = "PRINCESS CAPYBARA\nIS NOT TO BE DISTURBED\n(UNLESS YOU HAVE THE DUCKLINGS)"
	super()


## One span of paving: BAYS bays with a rib between each pair.
func span_length() -> float:
	return float(BAYS) * PAVED + float(BAYS - 1) * RIB


## Where span k (0 from the head) starts.
func span_start(k: int) -> float:
	return float(k) * (span_length() + TOWER.y)


## A world point on the aqueduct: s along it, x across it (+x to the right looking downhill), at y.
func on_line(s: float, x: float = 0.0, y: float = 0.0) -> Vector3:
	var flat: Vector3 = _turn * Vector3(x, 0.0, s)
	return Vector3(HEAD.x + flat.x, y, HEAD.y + flat.z)


## The lowest ground under a footprint on the aqueduct (s range, half width across).
func _ground_under(from_s: float, to_s: float, half: float) -> float:
	var low: float = INF
	var steps: int = maxi(1, int(ceil((to_s - from_s) / 2.0)))
	for i in range(steps + 1):
		var s: float = lerpf(from_s, to_s, float(i) / float(steps))
		for x: float in [-half, 0.0, half]:
			var at: Vector3 = on_line(s, x)
			low = minf(low, land.height_at(at.x, at.z))
	return low


func _place_objectives() -> void:
	var pad: Vector3 = on_line(-HEAD_PAD * 0.5)
	deck_y = land.height_at(pad.x, pad.z) + 0.7
	_build_aqueduct()
	_build_bottle()
	case_at(on_line(-HEAD_PAD * 0.5 + 1.5, 1.5, deck_y), "01 / DUCKLING, AT THE SOAP SPRING", "duckling")
	case_at(on_line(towers[1], 0.0, deck_y), "02 / DUCKLING, ON THE MIDDLE TOWER", "duckling")
	case_at(on_line(towers[2], 0.0, deck_y), "03 / DUCKLING, ON THE LAST TOWER", "duckling")


func _populate() -> void:
	_build_signs()
	scatter_mines(Rect2(110.0, -470.0, 180.0, 160.0), 22, 5101)
	scatter_mines(Rect2(40.0, -260.0, 200.0, 160.0), 14, 5107)
	marble(TUB_XZ + Vector2(25.0, -25.0), 3.5, PAD_XZ + Vector2(-40.0, 40.0), 60.0, Vector3(-6.0, 0.0, 6.0))
	for spot: Vector2 in HOUND_PACKS:
		enemy("hound", _floor(spot) + Vector3.UP * 0.1)
	if not loot_collected.is_connected(_on_duckling_taken):
		loot_collected.connect(_on_duckling_taken)


## The aqueduct, head to tail: the stone platform at the spring, then spans of cracking paving on
## arches, a tower between each pair of spans, and a solid causeway that runs on into the hill.
## Paving only ever has open air under it; the stone parts (platform, ribs, towers, causeway) are
## where a player can stand still.
func _build_aqueduct() -> void:
	var yaw: float = rad_to_deg(atan2(DOWN.x, DOWN.y))
	_stone(-HEAD_PAD, 0.0, TOWER.x, "concrete")
	towers.clear()
	ribs.clear()
	deck_fields.clear()
	var supports: Array[Vector2] = [Vector2(-HEAD_PAD, 0.0)]
	for k in range(SPANS):
		var s: float = span_start(k)
		for bay in range(BAYS):
			var field: int = traps().call("crack_field", on_line(s + PAVED * 0.5, 0.0, deck_y), Vector2(WIDTH, PAVED), TILE, "paving", Callable(), yaw)
			deck_fields.append(field)
			s += PAVED
			if bay < BAYS - 1:
				ribs.append(s + RIB * 0.5)
				_pier(s)
				supports.append(Vector2(s, s + RIB))
				s += RIB
		if k < SPANS - 1:
			towers.append(s + TOWER.y * 0.5)
			_build_tower(s)
			supports.append(Vector2(s, s + TOWER.y))
	# The causeway: the same arcade with sound stone slabs for a deck while the ground is low, then
	# solid stone until the ground comes up to meet the deck.
	var start: float = span_start(SPANS - 1) + span_length()
	var s: float = start
	while s < start + CAUSEWAY_MAX and deck_y - _ground_under(s + RIB, s + RIB + PAVED, WIDTH * 0.5) > CAUSEWAY_SOLID:
		_pier(s)
		supports.append(Vector2(s, s + RIB))
		var slab: Vector3 = on_line(s + RIB + PAVED * 0.5, 0.0, deck_y - 0.4)
		_box_at(Transform3D(_turn, slab), Vector3(PIER_WIDTH, 0.8, PAVED + 0.02), "concrete", true)
		s += RIB + PAVED
	causeway_end = s
	while causeway_end < start + CAUSEWAY_MAX:
		var at: Vector3 = on_line(causeway_end + 2.0)
		if land.height_at(at.x, at.z) >= deck_y - 0.3:
			break
		causeway_end += 2.0
	var s0: float = s
	while s0 < causeway_end - 0.01:
		var s1: float = minf(s0 + 4.0, causeway_end)
		_stone(s0, s1, PIER_WIDTH, "concrete")
		s0 = s1
	if causeway_end > s:
		supports.append(Vector2(s, causeway_end))
	for i in range(supports.size() - 1):
		_arches(supports[i].y, supports[i + 1].x)


## A solid block of the aqueduct from the ground (a little under it) up to the deck, s from from_s
## to to_s, width across.
func _stone(from_s: float, to_s: float, width: float, material: String) -> void:
	var low: float = _ground_under(from_s, to_s, width * 0.5) - 0.6
	var mid: Vector3 = on_line((from_s + to_s) * 0.5, 0.0, (low + deck_y) * 0.5)
	_box_at(Transform3D(_turn, mid), Vector3(width, deck_y - low, to_s - from_s), material, true)


## A pier under a rib: two square columns under the deck's edges and a capstone across them, its
## top flush with the deck (the rib a player can rest on).
func _pier(from_s: float) -> void:
	var to_s: float = from_s + RIB
	var mid: float = (from_s + to_s) * 0.5
	var cap: float = 1.2
	_box_at(Transform3D(_turn, on_line(mid, 0.0, deck_y - cap * 0.5)), Vector3(PIER_WIDTH, cap, RIB), "light_concrete", true)
	var column: float = 1.6
	for side: float in [-1.0, 1.0]:
		var x: float = side * (PIER_WIDTH * 0.5 - column * 0.5)
		var low: float = INF
		for corner: float in [-1.0, 1.0]:
			for along: float in [from_s, to_s]:
				var at: Vector3 = on_line(along, x + corner * column * 0.5)
				low = minf(low, land.height_at(at.x, at.z))
		low -= 0.6
		var top: float = deck_y - cap
		if top - low > 0.2:
			_box_at(Transform3D(_turn, on_line(mid, x, (low + top) * 0.5)), Vector3(column, top - low, RIB), "concrete", true)


## A tower between two spans, its top flush with the deck, with a cornice and a low wall along
## each side.
func _build_tower(from_s: float) -> void:
	var to_s: float = from_s + TOWER.y
	_stone(from_s, to_s, TOWER.x, "concrete")
	var mid: float = (from_s + to_s) * 0.5
	_box_at(Transform3D(_turn, on_line(mid, 0.0, deck_y - 0.9)), Vector3(TOWER.x + 0.8, 0.6, TOWER.y + 0.8), "dark", true)
	for side: float in [-1.0, 1.0]:
		_box_at(Transform3D(_turn, on_line(mid, side * (TOWER.x * 0.5 - 0.3), deck_y + 0.5)), Vector3(0.6, 1.0, TOWER.y), "light_concrete", true)


## A pair of round arches (one under each edge of the deck) across the gap from from_s to to_s.
## Each is a ring of solid stones; nothing lies under the paving between them.
func _arches(from_s: float, to_s: float) -> void:
	var radius: float = (to_s - from_s) * 0.5
	var spring: float = deck_y - ARCH_DROP - radius - ARCH_RING
	if spring + radius + ARCH_RING < _ground_under(from_s, to_s, ARCH_SIDE) + 0.5:
		return
	var middle: float = (from_s + to_s) * 0.5
	var stones: int = 6
	var ring: float = radius + ARCH_RING * 0.5
	var length: float = 2.0 * (radius + ARCH_RING) * tan(PI / float(stones * 2)) + 0.05
	for side: float in [-1.0, 1.0]:
		for i in range(stones):
			var angle: float = (float(i) + 0.5) * PI / float(stones)
			var at: Vector3 = on_line(middle - cos(angle) * ring, side * ARCH_SIDE, spring + sin(angle) * ring)
			var tilt := Basis(Vector3.RIGHT, angle - PI * 0.5)
			_box_at(Transform3D(_turn * tilt, at), Vector3(0.5, ARCH_RING, length), "light_concrete", true)


## The Soap Spring: a pump bottle of bath soap the size of a house behind the head platform, its
## pump spout reaching over the platform. Solid all through. The golden duckling sits on the pump.
func _build_bottle() -> void:
	var centre: Vector3 = on_line(BOTTLE_S)
	var low: float = INF
	for k in range(8):
		var angle: float = float(k) * TAU / 8.0
		var edge: Vector3 = centre + Vector3(cos(angle), 0.0, sin(angle)) * BOTTLE_RADIUS
		low = minf(low, land.height_at(edge.x, edge.z))
	low = minf(low, land.height_at(centre.x, centre.z)) - 1.0
	var top: float = deck_y + BOTTLE_RISE
	cylinder(Vector3(centre.x, (low + top) * 0.5, centre.z), BOTTLE_RADIUS, top - low, "orange")
	cylinder(Vector3(centre.x, deck_y + 5.5, centre.z), BOTTLE_RADIUS + 0.05, 4.0, "white")
	cylinder(Vector3(centre.x, top + 0.8, centre.z), BOTTLE_RADIUS * 0.7, 1.6, "orange")
	cylinder(Vector3(centre.x, top + 2.6, centre.z), 1.0, 2.0, "white")
	var head_y: float = top + 4.2
	var reach: float = -BOTTLE_S - HEAD_PAD + 2.5
	_box_at(Transform3D(_turn, on_line(BOTTLE_S + reach * 0.5 - 0.8, 0.0, head_y)), Vector3(1.6, 1.2, reach + 1.6), "white", true)
	_box_at(Transform3D(_turn, on_line(BOTTLE_S + reach - 0.6, 0.0, head_y - 1.2)), Vector3(0.7, 1.4, 0.7), "white", true)
	# A puddle of soap on the platform under the spout.
	cylinder(on_line(BOTTLE_S + reach - 0.6, 0.0, deck_y + 0.02), 1.6, 0.04, "white", false)
	var yaw: float = rad_to_deg(atan2(DOWN.x, DOWN.y))
	var face: Label3D = label("SOAP\nSPRING", on_line(BOTTLE_S + BOTTLE_RADIUS + 0.08, 0.0, deck_y + 5.5), 48, Color("35424b"), 0.02, false, yaw)
	face.double_sided = false
	bonus_at(on_line(BOTTLE_S + 1.0, 0.0, head_y + 0.6), "BONUS / THE GOLDEN DUCKLING, ON THE SOAP PUMP", "duckling_gold")


## A board on posts where the causeway meets the hill, facing a player coming down from the tub.
func _build_signs() -> void:
	var yaw: float = rad_to_deg(atan2(DOWN.x, DOWN.y))
	var spot: Vector3 = on_line(causeway_end + 4.0, 7.0)
	_sign("THE OLD AQUEDUCT\nTHE PAVING CRACKS UNDER YOU\n(KEEP MOVING. REST ON THE STONE)", _floor(Vector2(spot.x, spot.z)), Vector2(6.4, 2.0), yaw)
	var start: Vector3 = on_line(causeway_end - 6.0, 0.0, deck_y + 1.4)
	hint_zone(start, Vector3(10.0, 3.0, 10.0), "THE OLD AQUEDUCT  /  the paving cracks under you: keep moving, and rest on the stone ribs and towers", 7.0)


## Once she has all three ducklings the aqueduct gives up: a wave of collapse runs out along the
## deck from where the player stands.
func _on_duckling_taken(kind: String, _value: int) -> void:
	if kind != "case" or collected_loot < total_loot:
		return
	var origin: Vector3 = on_line(0.0, 0.0, deck_y)
	if is_instance_valid(_player):
		origin = _player.global_position
	traps().call("crack_wave", deck_fields, origin, WAVE_SPEED, WAVE_DELAY)
