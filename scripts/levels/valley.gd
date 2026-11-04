extends "res://scripts/level_base.gd"
## THE HIGHLANDS (W1 preview): the first open-world slice. A 1.4 km valley of meadows, forest and
## two lakes inside a ring of snowy mountains, with no walls anywhere: the mountains are the edge.
## Practice rules (no clock, no hostiles) while the look and the scale are judged.
##
## The absurd bit is the objective: Princess Capybara is in her hot tub on the hill and will not
## come out until someone brings back her rubber duck, which is somewhere in the far forest. A
## second duck, the size of a house, floats in the west lake.

const Terrain = preload("res://scripts/world/terrain.gd")
const Nature = preload("res://scripts/world/nature.gd")

const INFO := {
	"title": "THE HIGHLANDS",
	"zone": "highlands",
	"number": -2,
	"blurb": "Preview of the open world: meadows, forest, lakes and snowy peaks. Bring the princess her duck.",
	"par_silver": 0.0,
	"par_gold": 0.0,
	"cases": 1,
	"bonus": 0,
	"enemies": false,
	"practice": true,
	"repeatable": true,
}

const SEED := 7319
const SIZE := 1400.0
const SPAWN_XZ := Vector2(0.0, 60.0)
const TUB_XZ := Vector2(170.0, -250.0)
const PAD_XZ := Vector2(170.0, -232.0)
const DUCK_XZ := Vector2(-250.0, -330.0)
const WEST_LAKE := Vector3(-200.0, -90.0, 75.0)    # x, z, radius
const EAST_LAKE := Vector3(190.0, 150.0, 55.0)
const BIG_DUCK_XZ := Vector2(-200.0, -90.0)

var land: Terrain


func _design() -> void:
	set_zone("highlands")
	dreamscape = false
	nav_cell_size = 1.0
	nav_bounds = AABB(Vector3(-420.0, -20.0, -420.0), Vector3(840.0, 160.0, 840.0))
	set_kill_y(-30.0)
	land = Terrain.new(SEED, SIZE)
	land.flatten(SPAWN_XZ, 22.0)
	land.flatten(TUB_XZ, 12.0)
	land.flatten(PAD_XZ, 9.0)
	land.flatten(DUCK_XZ, 6.0)
	land.lake(Vector2(WEST_LAKE.x, WEST_LAKE.y), WEST_LAKE.z)
	land.lake(Vector2(EAST_LAKE.x, EAST_LAKE.y), EAST_LAKE.z)
	land.generate()
	_build_ground()
	var keep_clear: Array[Vector3] = [
		Vector3(SPAWN_XZ.x, SPAWN_XZ.y, 26.0), Vector3(TUB_XZ.x, TUB_XZ.y, 20.0),
		Vector3(PAD_XZ.x, PAD_XZ.y, 12.0), Vector3(DUCK_XZ.x, DUCK_XZ.y, 8.0),
	]
	Nature.scatter(self, land, SEED, keep_clear)
	var spawn_floor := Vector3(SPAWN_XZ.x, land.height_at(SPAWN_XZ.x, SPAWN_XZ.y), SPAWN_XZ.y)
	set_spawn(spawn_floor)
	_build_hot_tub()
	_build_big_duck()
	case_at(_floor(DUCK_XZ), "01 / THE RUBBER DUCK")
	extraction(_floor(PAD_XZ))
	hint_zone(spawn_floor + Vector3(0.0, 1.2, -6.0), Vector3(16.0, 3.0, 10.0), "THE HIGHLANDS  /  find the princess's rubber duck in the far forest, then bring it to her hot tub on the hill", 9.0)


func _floor(xz: Vector2) -> Vector3:
	return Vector3(xz.x, land.height_at(xz.x, xz.y), xz.y)


## The terrain mesh and its exact collider. The border height continues as the outer plain.
func _build_ground() -> void:
	var view := MeshInstance3D.new()
	view.name = "Terrain"
	view.mesh = land.build_mesh()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.95
	view.material_override = material
	add_child(view)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(land.collision_faces())
	var body: StaticBody3D = add_world_body(shape, Transform3D.IDENTITY, "TerrainBody")
	# The bake reads the same ground, but only inside nav_bounds, instead of parsing the full mesh.
	nav_skip_bodies.append(body)
	nav_extra_faces = land.nav_faces(nav_bounds, 1)
	var half: float = SIZE * 0.5
	set_footprint(Rect2(-half, -half, SIZE, SIZE), Terrain.WATER_Y - 8.0)
	outer_top = Terrain.EDGE_HEIGHT
	outer_material = "snow"
	water(Vector3(0.0, Terrain.WATER_Y, 0.0), Vector2(SIZE, SIZE), false)


## Princess Capybara, in a wooden hot tub, wearing a crown and a towel. She is solid; so is the tub.
func _build_hot_tub() -> void:
	var base: Vector3 = _floor(TUB_XZ)
	cylinder(base + Vector3(0.0, 0.55, 0.0), 2.8, 1.1, "rust")
	cylinder(base + Vector3(0.0, 1.08, 0.0), 2.55, 0.06, "glass", false)
	# Facing the pad (+z), half in the water.
	block(base + Vector3(0.0, 0.7, 0.0), Vector3(1.4, 1.0, 1.7), "fur")
	block(base + Vector3(0.0, 1.35, 0.95), Vector3(0.95, 0.8, 0.95), "fur")
	block(base + Vector3(0.0, 1.35, 1.55), Vector3(0.75, 0.55, 0.45), "fur_dark")
	for side: float in [-1.0, 1.0]:
		block(base + Vector3(side * 0.38, 2.15, 0.7), Vector3(0.18, 0.18, 0.12), "fur_dark")
		block(base + Vector3(side * 0.3, 1.78, 1.43), Vector3(0.1, 0.1, 0.04), "dark")
	block(base + Vector3(0.0, 2.15, 0.95), Vector3(0.8, 0.12, 0.8), "snow")
	block(base + Vector3(0.0, 2.27, 0.95), Vector3(0.5, 0.18, 0.5), "yellow")
	for x: float in [-0.18, 0.0, 0.18]:
		block(base + Vector3(x, 2.45, 1.18), Vector3(0.08, 0.2, 0.06), "yellow")
	_sign("PRINCESS CAPYBARA\nIS NOT TO BE DISTURBED\n(UNLESS YOU HAVE THE DUCK)", base + Vector3(-5.0, 0.0, 4.5), Vector2(5.4, 2.0))
	light(base + Vector3(0.0, 4.0, 0.0), Color("ffe3b0"), 1.2, 18.0)


## A rubber duck the size of a house, afloat in the west lake. Solid: land on it.
func _build_big_duck() -> void:
	var at := Vector3(BIG_DUCK_XZ.x, Terrain.WATER_Y, BIG_DUCK_XZ.y)
	_ball(at + Vector3(0.0, 2.0, 0.0), 7.0, "yellow")
	_ball(at + Vector3(0.0, 9.5, 3.5), 4.2, "yellow")
	block(at + Vector3(0.0, 8.6, 7.8), Vector3(2.6, 1.0, 2.2), "orange")
	for side: float in [-1.0, 1.0]:
		_ball(at + Vector3(side * 2.2, 10.6, 6.4), 0.55, "dark")


func _ball(center: Vector3, radius: float, material: String) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 20
	mesh.rings = 10
	_stage_mesh(mesh, Transform3D(Basis.IDENTITY, center), material)
	var shape := SphereShape3D.new()
	shape.radius = radius
	add_world_collider(shape, Transform3D(Basis.IDENTITY, center))


## A wooden board on two posts with text on its front (+z) face. Nothing floats.
func _sign(text: String, base: Vector3, size: Vector2) -> void:
	var center: Vector3 = base + Vector3(0.0, 1.2 + size.y * 0.5, 0.0)
	box(center, Vector3(size.x, size.y, 0.15), "rust")
	for side: float in [-1.0, 1.0]:
		box(Vector3(center.x + side * (size.x * 0.5 - 0.3), base.y + 0.9, center.z - 0.1), Vector3(0.18, 1.8 + size.y * 0.5, 0.18), "dark")
	var face: Label3D = label(text, center + Vector3(0.0, 0.0, 0.1), 36, Color("fff4dc"), 0.012)
	face.double_sided = false
