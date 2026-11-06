extends "res://scripts/levels/highlands_base.gd"
## H05 STARFALL (W2, W4): the last highland errand, at night. The Department of Unfinished Gravity
## has, for once, finished something: gravity. It now applies to the stars as well, and they have
## started coming down over the highlands. Princess Capybara would like three of them in her bath.
##   - one is on top of the Gravity Works, the department's own unfinished tower in the south-west:
##     a ramp winds twice round a concrete core to a deck 36 m up (the long way on foot), and
##     a geyser beside it, signed PUBLIC LIFT, throws you past the deck (the short way, with the rod);
##   - one came down on Star Hill to the east, and knocked loose the marbles resting on its crown,
##     which roll at whoever climbs;
##   - one is still smoking in its crater in the north meadow, inside two rings of teacup mines.
## The North Star itself is on the crow's nest at the top of the Works' mast (a bonus: rod only).
## Stars fall far off the whole time (a glowing ring on the ground, then the strike). Each star the
## player picks up draws the others: they start falling where the player is running, faster with
## every star carried, so the way back to the tub is in the air.
## The sky is the Foundry's: the department's night has come over the hills.

const INFO := {
	"title": "STARFALL",
	"zone": "highlands",
	"number": 11,
	"blurb": "The department has finally finished gravity, and now it works on the stars. Three have come down in the highlands. She would like them in her bath.",
	"par_silver": 345.0,
	"par_gold": 195.0,
	"cases": 3,
	"bonus": 1,
	"enemies": true,
	"practice": false,
	"loot_label": "FOR THE PRINCESS",
	"mission": "FETCH THREE FALLEN STARS",
	"deliver": "TAKE THEM TO THE HOT TUB ON THE HILL",
	"deliver_hint": "THE STARS ARE AIMING AT YOU  /  keep moving, stay off the ground and get to the hot tub",
}

## The Gravity Works: a concrete core with a ramp winding round it to the top deck.
const WORKS_XZ := Vector2(-60.0, 130.0)
const CORE_RADIUS := 7.0
const WORKS_TOP := 36.0           # the deck, above the Works' floor
const RAMP_OUTER := 12.5
const RAMP_THICKNESS := 0.7
const RAMP_SLOPE := 16.0          # degrees, along the ramp's centre line
const RAMP_STEP := 6.0            # degrees of turn per piece of the ramp's mesh
const MAST := 14.0                # the crow's nest above the deck
const NEST := Vector3(4.0, 0.4, 4.0)
const LIFT_RADIUS := 17.0         # the geyser lift, out from the core's axis
const LIFT_POWER := 28.0          # about 40 m of throw: past the deck, not up to the mast
## Star Hill: a new round hill east of the spawn, its crown flattened, three marbles on it.
const HILL := Vector4(120.0, -60.0, 75.0, 32.0)
const HILL_MARBLES := [
	# angle on the crown (degrees, 0 = +x), and the slope box that lets it go (its distance out).
	Vector2(180.0, 42.0), Vector2(110.0, 42.0), Vector2(250.0, 42.0),
]
## The crater in the north meadow.
const CRATER := Vector3(170.0, -200.0, 19.0)     # x, z, radius
const CRATER_DEPTH := 6.0
const MINE_RINGS := [Vector2(12.0, 8.0), Vector2(20.0, 12.0)]   # radius, count
const HOUND_PACKS := [
	Vector2(-10.0, 170.0), Vector2(-130.0, 100.0), Vector2(60.0, 40.0), Vector2(110.0, -110.0),
	Vector2(200.0, 40.0), Vector2(20.0, -200.0), Vector2(120.0, -300.0), Vector2(240.0, -140.0),
]
const STAR_PERIOD := 5.0          # an idle star somewhere far off, this often
## Seconds between stars aimed at the player while carrying one, two and three stars.
const STAR_HUNT := [5.0, 3.0, 1.6]
## Night over the highlands: the Foundry's sky, a cold violet moon for the sun.
const NIGHT := {
	"sky": "nightmare",
	"ambient": "a69ae6", "ambient_energy": 0.4, "fog": "4e3f80", "fog_density": 0.0011,
	"sun": "c9c4ff", "sun_energy": 0.5, "sun_rotation": Vector3(-34, 150, 0),
}

var works_floor: Vector3          # the Works' floor at the core's axis
var ramp_turn: float = 0.0        # radians the ramp turns from its foot to the deck
var ramp_start: float = 0.0       # the angle of the ramp's foot about the core
var _ramp_faces := PackedVector3Array()


func _design() -> void:
	look_override = NIGHT
	# The ramp winds round the Works' core: watershed regions would overlap themselves there.
	nav_partition = NavigationMesh.SAMPLE_PARTITION_MONOTONE
	# Star Hill, and the crater pressed into the north meadow (a sunken mound).
	extra_mounds = [HILL, Vector4(CRATER.x, CRATER.y, CRATER.z, -CRATER_DEPTH)]
	extra_spots = [Vector3(WORKS_XZ.x, WORKS_XZ.y, 26.0), Vector3(HILL.x, HILL.y, 7.0)]
	clear_spots = [Vector3(HILL.x, HILL.y, 22.0), Vector3(CRATER.x, CRATER.y, CRATER.z + 22.0)]
	spawn_facing = 140.0             # toward the Gravity Works, to the south-west
	intro_hint = "THE HIGHLANDS, AT NIGHT  /  the department has finished gravity and the stars are coming down: bring her three, to the hot tub on the eastern hill"
	tub_sign = "PRINCESS CAPYBARA\nIS NOT TO BE DISTURBED\n(UNLESS YOU HAVE THE STARS)"
	super()


func _place_objectives() -> void:
	# Built here, before the cases, because the deck and the hill's crown carry them.
	_build_works()
	case_at(works_floor + Vector3(3.5, WORKS_TOP, 0.0), "01 / A FALLEN STAR, ON THE GRAVITY WORKS", "star")
	case_at(_floor(Vector2(HILL.x, HILL.y)), "02 / A FALLEN STAR, ON STAR HILL", "star")
	case_at(_floor(Vector2(CRATER.x, CRATER.y)) + Vector3.UP * 0.1, "03 / A FALLEN STAR, STILL SMOKING", "star")
	bonus_at(works_floor + Vector3(0.0, WORKS_TOP + MAST + NEST.y, 0.0), "BONUS / THE NORTH STAR, ON THE MAST", "star_north")


func _populate() -> void:
	var t: Node3D = traps()
	_build_lift(t)
	_build_crater(t)
	_build_hill_marbles()
	scatter_mines(Rect2(-320.0, -320.0, 600.0, 440.0), 28, 5813)
	marble(TUB_XZ + Vector2(25.0, -25.0), 3.5, PAD_XZ + Vector2(-40.0, 40.0), 60.0, Vector3(-6.0, 0.0, 6.0))
	for spot: Vector2 in HOUND_PACKS:
		enemy("hound", _floor(spot) + Vector3.UP * 0.1)
	var half: float = SIZE * 0.5 - 60.0
	t.call("starfall", Rect2(-half, -half, half * 2.0, half * 2.0), STAR_PERIOD, float(STAR_HUNT[0]), 7741)
	if not loot_collected.is_connected(_on_star_taken):
		loot_collected.connect(_on_star_taken)


func _on_star_taken(kind: String, _value: int) -> void:
	if kind != "case":
		return
	var carried: int = clampi(collected_loot, 1, STAR_HUNT.size())
	traps().call("hunt_starfall", float(STAR_HUNT[carried - 1]))
	if carried == 1:
		hint_requested.emit("THE OTHER STARS HAVE NOTICED  /  a gold ring is where one will land: keep moving, or be in the air", 6.0)


# --- The Gravity Works ---------------------------------------------------------------------------

## The ramp's height above the Works' floor at turn a (radians from its foot), along its centre line.
func ramp_height(turn: float) -> float:
	var middle: float = (CORE_RADIUS + RAMP_OUTER) * 0.5
	return turn * middle * tan(deg_to_rad(RAMP_SLOPE))


## A point on the ramp's walking surface, turn radians from its foot, radius r from the core's axis.
func ramp_point(turn: float, r: float) -> Vector3:
	var angle: float = ramp_start + turn
	return works_floor + Vector3(cos(angle) * r, ramp_height(turn), sin(angle) * r)


func _build_works() -> void:
	works_floor = _floor(WORKS_XZ)
	var toward: Vector2 = (SPAWN_XZ - WORKS_XZ).normalized()
	var facing: float = atan2(toward.y, toward.x)
	# The ramp's foot faces a little round from the spawn; the lift stands on the spawn side.
	ramp_start = facing + 0.7
	ramp_turn = WORKS_TOP / ramp_height(1.0)
	cylinder(works_floor + Vector3(0.0, WORKS_TOP * 0.5, 0.0), CORE_RADIUS, WORKS_TOP, "concrete")
	# A dark band round the top of the core, and the deck's kerb: both solid.
	cylinder(works_floor + Vector3(0.0, WORKS_TOP - 0.65, 0.0), CORE_RADIUS + 0.12, 1.2, "stripe")
	_build_ramp()
	# Amber studs set into the ramp's outer face every eighth of a turn, so its spiral reads at night.
	var stud: float = 0.0
	while stud < ramp_turn:
		var at: Vector3 = ramp_point(stud, RAMP_OUTER) - Vector3.UP * RAMP_THICKNESS * 0.5
		box(at, Vector3(0.5, 0.3, 0.5), "amber", true, -rad_to_deg(ramp_start + stud))
		stud += TAU / 8.0
	# The mast and its crow's nest: a stone column and a plate, both solid.
	var deck: Vector3 = works_floor + Vector3(0.0, WORKS_TOP, 0.0)
	cylinder(deck + Vector3(0.0, MAST * 0.5, 0.0), 0.45, MAST, "dark")
	box(deck + Vector3(0.0, MAST + NEST.y * 0.5, 0.0), NEST, "rust")
	light(deck + Vector3(0.0, 3.0, 0.0), Color("ffe0a0"), 1.4, 16.0)
	var foot: Vector3 = ramp_point(0.0, RAMP_OUTER + 4.0)
	var away: Vector2 = Vector2(cos(ramp_start), sin(ramp_start))
	_sign("THE GRAVITY WORKS\nGRAVITY: FINISHED\nRAILINGS: PENDING", Vector3(foot.x, _floor(Vector2(foot.x, foot.z)).y, foot.z), Vector2(5.6, 2.2), rad_to_deg(atan2(away.x, away.y)))


## The ramp: one mesh, winding from the floor to the deck, solid as a trimesh (top, outer face and
## underside), its inner edge against the core.
func _build_ramp() -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps: int = ceili(rad_to_deg(ramp_turn) / RAMP_STEP)
	var down := Vector3.DOWN * RAMP_THICKNESS
	for k in range(steps):
		var a0: float = ramp_turn * float(k) / float(steps)
		var a1: float = ramp_turn * float(k + 1) / float(steps)
		var in0: Vector3 = ramp_point(a0, CORE_RADIUS - 0.05)
		var out0: Vector3 = ramp_point(a0, RAMP_OUTER)
		var in1: Vector3 = ramp_point(a1, CORE_RADIUS - 0.05)
		var out1: Vector3 = ramp_point(a1, RAMP_OUTER)
		_ramp_quad(tool, in0, out0, out1, in1)                          # walking surface
		_ramp_quad(tool, out0, out0 + down, out1 + down, out1)          # outer face
		_ramp_quad(tool, in0 + down, in1 + down, out1 + down, out0 + down)   # underside
		if k == 0:
			_ramp_quad(tool, in0 + down, out0 + down, out0, in0)        # the foot's end
		if k == steps - 1:
			_ramp_quad(tool, in1, out1, out1 + down, in1 + down)        # the top's end
	tool.generate_normals()
	var mesh: ArrayMesh = tool.commit()
	_stage_mesh(mesh, Transform3D.IDENTITY, "light_concrete")
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(_ramp_faces)
	add_world_body(shape, Transform3D.IDENTITY, "GravityRamp")


## Two triangles a b c, a c d, wound so the face points out when the corners run clockwise seen from
## outside (Godot's front face).
func _ramp_quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for corner: Vector3 in [a, b, c, a, c, d]:
		tool.add_vertex(corner)
		_ramp_faces.append(corner)


## The public lift: a geyser beside the Works that throws the player past the deck.
func _build_lift(t: Node3D) -> void:
	var toward: Vector2 = (SPAWN_XZ - WORKS_XZ).normalized()
	var at: Vector2 = WORKS_XZ + toward.rotated(-0.35) * LIFT_RADIUS
	t.call("geyser", _floor(at), 7.0, 1.0, LIFT_POWER)
	var board: Vector2 = at + toward.rotated(-0.35) * 5.5 + Vector2(-toward.y, toward.x) * 3.0
	_sign("PUBLIC LIFT\nSTAND ON THE VENT WHEN IT HISSES\n(GRAVITY APPLIES)", _floor(board), Vector2(5.8, 2.0), rad_to_deg(atan2(toward.x, toward.y)))


# --- The crater and Star Hill ---------------------------------------------------------------------

func _build_crater(t: Node3D) -> void:
	var middle: Vector3 = _floor(Vector2(CRATER.x, CRATER.y))
	# Embers: glowing lumps of star sunk in the crater floor. Solid.
	var rng := RandomNumberGenerator.new()
	rng.seed = 6120
	for k in range(10):
		var angle: float = float(k) * TAU / 10.0 + rng.randf_range(-0.25, 0.25)
		var reach: float = rng.randf_range(3.0, CRATER.z * 0.5)
		var xz := Vector2(CRATER.x + cos(angle) * reach, CRATER.y + sin(angle) * reach)
		var size := Vector3(rng.randf_range(1.0, 2.2), rng.randf_range(0.6, 1.3), rng.randf_range(1.0, 2.0))
		block(_floor(xz) - Vector3.UP * 0.35, size, "orange", rng.randf_range(0.0, 90.0))
	light(middle + Vector3.UP * 3.0, Color("ffcf7a"), 1.6, 24.0)
	if quality >= 1:
		add_child(_smoke(middle + Vector3.UP * 1.0))
	for ring: Vector2 in MINE_RINGS:
		for k in range(int(ring.y)):
			var angle: float = float(k) * TAU / ring.y + ring.x * 0.1
			var xz := Vector2(CRATER.x + cos(angle) * ring.x, CRATER.y + sin(angle) * ring.x)
			if land.height_at(xz.x, xz.y) > Terrain.WATER_Y + 0.8:
				t.call("mine", _floor(xz))
	var toward: Vector2 = (SPAWN_XZ - Vector2(CRATER.x, CRATER.y)).normalized()
	var board: Vector2 = Vector2(CRATER.x, CRATER.y) + toward * (CRATER.z + 12.0)
	_sign("PLEASE KEEP OFF THE CRATER\n(IT IS NEW)", _floor(board), Vector2(5.4, 1.6), rad_to_deg(atan2(toward.x, toward.y)))


## Smoke from the crater: a tall, slow plume of soft violet puffs (no text, nothing to stand on).
func _smoke(at: Vector3) -> CPUParticles3D:
	var smoke: CPUParticles3D = _tub_steam(at)
	smoke.name = "CraterSmoke"
	smoke.amount = 32
	smoke.lifetime = 10.0
	smoke.preprocess = 10.0
	smoke.emission_box_extents = Vector3(4.0, 0.2, 4.0)
	smoke.initial_velocity_min = 2.2
	smoke.initial_velocity_max = 3.4
	smoke.scale_amount_min = 4.0
	smoke.scale_amount_max = 6.5
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.0)])
	fade.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	smoke.color_ramp = fade
	var puff: QuadMesh = (smoke.mesh as QuadMesh).duplicate() as QuadMesh
	var look: StandardMaterial3D = (puff.material as StandardMaterial3D).duplicate() as StandardMaterial3D
	look.albedo_color = Color("c4bbe0")
	puff.material = look
	smoke.mesh = puff
	return smoke


## Three marbles resting on Star Hill's crown, each let go down its own slope when the player climbs
## that side.
func _build_hill_marbles() -> void:
	for spec: Vector2 in HILL_MARBLES:
		var dir := Vector2(cos(deg_to_rad(spec.x)), sin(deg_to_rad(spec.x)))
		var rest: Vector2 = Vector2(HILL.x, HILL.y) + dir * 9.0
		var trigger: Vector2 = Vector2(HILL.x, HILL.y) + dir * spec.y
		marble(rest, 3.0, trigger, 44.0, Vector3(dir.x, 0.0, dir.y) * 5.0)
