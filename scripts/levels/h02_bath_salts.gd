extends "res://scripts/levels/highlands_base.gd"
## H02 THE BATH SALTS (W2, W4): the second highland errand. Princess Capybara's bath has gone flat
## and only the salts from the geyser basin in the south-west will do, all three jars. The basin is
## boiling mud between geysers; the geysers throw anything standing on a vent high into the air,
## which is the fast way across the mud and, in a chain of vents running north-east, the fast way
## back to her tub. Her sea sponge sits on top of a basalt stack beside the biggest geyser, the
## Kettle (a bonus: ride the Kettle, then the rod). Once she has all three jars the basin boils over:
## every geyser erupts twice as often.

const INFO := {
	"title": "THE BATH SALTS",
	"zone": "highlands",
	"number": 8,
	"blurb": "The princess's bath has gone flat. Fetch the salts from the geyser basin: boiling mud underfoot, hounds at your heels, and vents that throw you into the sky.",
	"par_silver": 340.0,
	"par_gold": 195.0,
	"cases": 3,
	"bonus": 1,
	"enemies": true,
	"practice": false,
	"loot_label": "FOR THE PRINCESS",
	"mission": "FETCH ALL THREE JARS OF BATH SALTS",
	"deliver": "TAKE THEM TO THE HOT TUB ON THE HILL",
	"deliver_hint": "THE BASIN IS BOILING OVER  /  ride the geysers north-east to the hot tub",
}

const BASIN := Vector2(-210.0, 250.0)
const BASIN_RADIUS := 46.0
## Jars, as offsets from the basin centre, on firm ground between the pools.
const JARS := [Vector2(-27.0, 8.0), Vector2(22.0, -20.0), Vector2(4.0, 31.0)]
## Mud pools: offset x, offset z, radius.
const MUD := [
	Vector3(-12.0, -14.0, 7.0), Vector3(16.0, 10.0, 6.0), Vector3(-30.0, 26.0, 6.5),
	Vector3(30.0, 24.0, 5.0), Vector3(-36.0, -12.0, 5.5), Vector3(6.0, -34.0, 6.0),
	Vector3(-16.0, 40.0, 4.5), Vector3(38.0, -6.0, 4.5),
]
## Basin geysers: offset x, offset z, period (s). Phases are spread so one is usually going.
const VENTS := [
	Vector3(-20.0, -2.0, 6.0), Vector3(10.0, -10.0, 7.0), Vector3(-8.0, 20.0, 6.5),
	Vector3(26.0, -30.0, 8.0), Vector3(-40.0, 4.0, 7.5), Vector3(20.0, 40.0, 7.0),
]
const KETTLE := Vector2(2.0, 4.0)            # the big one, beside the stack
const KETTLE_POWER := 33.0                   # about 54 m of throw
const STACK := Vector2(12.0, 6.0)            # the basalt stack with the sponge on top
const STACK_HEIGHT := 34.0
const STACK_RADIUS := 2.6
## The chain of vents from the basin to the tub hill, as fractions along the line and a sideways
## nudge (metres) that keeps each one off the spawn clearing and out of the lakes.
const CHAIN := [Vector2(0.14, 0.0), Vector2(0.26, 14.0), Vector2(0.38, 34.0), Vector2(0.52, 30.0), Vector2(0.64, 6.0), Vector2(0.77, 0.0)]
const HOUND_PACKS := [
	Vector2(-170.0, 210.0), Vector2(-250.0, 200.0), Vector2(-180.0, 300.0), Vector2(-260.0, 290.0),
	Vector2(-90.0, 140.0), Vector2(60.0, -60.0), Vector2(150.0, -150.0),
]


func _design() -> void:
	extra_spots = [Vector3(BASIN.x, BASIN.y, BASIN_RADIUS)]
	hot_springs = [Vector3(BASIN.x, BASIN.y, BASIN_RADIUS)]
	intro_hint = "THE HIGHLANDS  /  her bath has gone flat: fetch the salts from the geyser basin to the south-west, then bring them to her hot tub on the eastern hill"
	tub_sign = "PRINCESS CAPYBARA\nIS NOT TO BE DISTURBED\n(UNLESS YOU HAVE THE SALTS)"
	super()


func _place_objectives() -> void:
	var names := ["01 / BATH SALTS, LAVENDER", "02 / BATH SALTS, EUCALYPTUS", "03 / BATH SALTS, PLAIN BUT GOOD"]
	for i in range(JARS.size()):
		case_at(_floor(BASIN + (JARS[i] as Vector2)), names[i], "salts")


func _populate() -> void:
	var t: Node3D = traps()
	for pool: Vector3 in MUD:
		var at: Vector2 = BASIN + Vector2(pool.x, pool.y)
		t.call("mud_pool", _floor(at) + Vector3.UP * 0.04, pool.z)
	for i in range(VENTS.size()):
		var vent: Vector3 = VENTS[i]
		t.call("geyser", _floor(BASIN + Vector2(vent.x, vent.y)), vent.z, float(i) * 2.3, 22.0)
	t.call("geyser", _floor(BASIN + KETTLE), 11.0, 4.0, KETTLE_POWER)
	_build_stack()
	_build_chain(t)
	_build_basin_signs()
	scatter_mines(Rect2(-160.0, -40.0, 300.0, 200.0), 24, 4417)
	marble(TUB_XZ + Vector2(25.0, -25.0), 3.5, PAD_XZ + Vector2(-40.0, 40.0), 60.0, Vector3(-6.0, 0.0, 6.0))
	for spot: Vector2 in HOUND_PACKS:
		enemy("hound", _floor(spot) + Vector3.UP * 0.1)
	if not loot_collected.is_connected(_on_salts_taken):
		loot_collected.connect(_on_salts_taken)


## A solid basalt stack, five stepped drums, flat on top. The sponge waits up there.
func _build_stack() -> void:
	var base: Vector3 = _floor(BASIN + STACK)
	var drums: int = 5
	for k in range(drums):
		var height: float = STACK_HEIGHT / float(drums)
		var radius: float = STACK_RADIUS * (1.25 - float(k) * 0.07)
		var centre: Vector3 = base + Vector3(sin(float(k) * 1.9) * 0.25, height * (float(k) + 0.5), cos(float(k) * 2.3) * 0.25)
		cylinder(centre, radius, height + 0.02, "dark")
	bonus_at(base + Vector3(0.0, STACK_HEIGHT, 0.0), "BONUS / HER SEA SPONGE, ON THE STACK", "sponge")


## Vents from the basin toward the tub, timed so each erupts a little after the one before.
func _build_chain(t: Node3D) -> void:
	var start: Vector2 = BASIN
	var finish: Vector2 = PAD_XZ
	var along: Vector2 = (finish - start).normalized()
	var side := Vector2(-along.y, along.x)
	for i in range(CHAIN.size()):
		var step: Vector2 = CHAIN[i]
		var at: Vector2 = start.lerp(finish, step.x) + side * step.y
		if land.height_at(at.x, at.y) < Terrain.WATER_Y + 1.5:
			continue
		t.call("geyser", _floor(at), 8.0, float(i) * 1.4, 30.0)


## Boards on posts at the basin's edge, facing the way you come in. Nothing floats.
func _build_basin_signs() -> void:
	var toward: Vector2 = (SPAWN_XZ - BASIN).normalized()
	var edge: Vector2 = BASIN + toward * (BASIN_RADIUS + 6.0)
	# Face the board (+z at yaw 0) toward the spawn.
	_sign("GEYSER BASIN\nSTAND ON A VENT WHEN IT HISSES\n(THE MUD IS HOT. THE MUD IS ALWAYS HOT)", _floor(edge), Vector2(6.2, 2.0), rad_to_deg(atan2(toward.x, toward.y)))


func _on_salts_taken(kind: String, _value: int) -> void:
	if kind == "case" and collected_loot >= total_loot:
		traps().call("set_geyser_tempo", 2.0)
