extends "res://scripts/level_base.gd"
## The highland valley (W1, W2): shared by the practice preview (valley.gd) and the raid (h01). A
## 1.4 km valley of meadows, forest and two frozen lakes inside a ring of snowy mountains, with no
## walls anywhere: the mountains are the edge.
##
## The absurd bit is the objective: Princess Capybara is in her hot tub on the eastern foothill and
## will not come out until someone brings back her rubber duck, which is somewhere in the far
## forest. A second duck, the size of a house, floats in the west lake.
##
## The floor is lava: thin ice over freezing lakes, teacup mines in the meadows and marbles waiting
## on the slopes. Subclasses choose how much of it, with the hostiles and the flood, in _populate().

const Terrain = preload("res://scripts/world/terrain.gd")
const Nature = preload("res://scripts/world/nature.gd")
const SEED := 7319
const SIZE := 1400.0
const SPAWN_XZ := Vector2(0.0, 60.0)
const TUB_XZ := Vector2(300.0, -260.0)
const TUB_HILL := Vector2(110.0, 30.0)          # radius, height of the princess's hill
const PAD_XZ := Vector2(282.0, -242.0)
const DUCK_XZ := Vector2(-250.0, -330.0)
const WEST_LAKE := Vector3(-200.0, -90.0, 75.0)    # x, z, radius
const PRINCESS_SCALE := 1.2                       # the painted princess model, in her tub
const EAST_LAKE := Vector3(190.0, 150.0, 55.0)
const BIG_DUCK_XZ := Vector2(-200.0, -90.0)

var land: Terrain
var keep_clear: Array[Vector3] = []
## Extra flat, tree-free spots (x, z, radius) a subclass sets before calling super._design().
var extra_spots: Array[Vector3] = []
## Hot-spring ground (x, z, radius): bare warm crust with no snow, set before super._design().
var hot_springs: Array[Vector3] = []
## Extra hills (x, z, radius, height), set before super._design().
var extra_mounds: Array[Vector4] = []
## Spots (x, z, radius) kept free of trees and rocks without flattening them (a structure's
## footprint on a slope), set before super._design().
var clear_spots: Array[Vector3] = []
## The navmesh's bake volume. A subclass whose errand reaches past it (into the northern foothills,
## say) widens it before super._design(); a bigger volume bakes slower.
var nav_area := AABB(Vector3(-420.0, -20.0, -420.0), Vector3(840.0, 160.0, 840.0))
## Which way the player faces at the spawn (degrees; 0 looks north, toward -z).
var spawn_facing: float = 0.0
## What the spawn hint and the sign by the tub say; a subclass with another errand changes them.
var intro_hint: String = "THE HIGHLANDS  /  find the princess's rubber duck in the far forest, then bring it to her hot tub on the eastern hill"
var tub_sign: String = "PRINCESS CAPYBARA\nIS NOT TO BE DISTURBED\n(UNLESS YOU HAVE THE DUCK)"


func _design() -> void:
	set_zone("highlands")
	dreamscape = false
	nav_cell_size = 1.0
	nav_max_climb = 0.8
	nav_bounds = nav_area
	set_kill_y(-30.0)
	land = Terrain.new(SEED, SIZE)
	land.mound(TUB_XZ, TUB_HILL.x, TUB_HILL.y)
	for hill: Vector4 in extra_mounds:
		land.mound(Vector2(hill.x, hill.y), hill.z, hill.w)
	land.flatten(SPAWN_XZ, 22.0)
	land.flatten(TUB_XZ, 12.0)
	land.flatten(PAD_XZ, 9.0)
	land.flatten(DUCK_XZ, 6.0)
	for spot: Vector3 in extra_spots:
		land.flatten(Vector2(spot.x, spot.y), spot.z)
	for hot: Vector3 in hot_springs:
		land.spring(Vector2(hot.x, hot.y), hot.z)
	land.lake(Vector2(WEST_LAKE.x, WEST_LAKE.y), WEST_LAKE.z)
	land.lake(Vector2(EAST_LAKE.x, EAST_LAKE.y), EAST_LAKE.z)
	land.generate()
	_build_ground()
	keep_clear = [
		Vector3(SPAWN_XZ.x, SPAWN_XZ.y, 26.0), Vector3(TUB_XZ.x, TUB_XZ.y, 20.0),
		Vector3(PAD_XZ.x, PAD_XZ.y, 12.0), Vector3(DUCK_XZ.x, DUCK_XZ.y, 8.0),
	]
	for spot: Vector3 in extra_spots:
		keep_clear.append(Vector3(spot.x, spot.y, spot.z + 2.0))
	keep_clear.append_array(clear_spots)
	Nature.scatter(self, land, SEED, keep_clear)
	var spawn_floor := Vector3(SPAWN_XZ.x, land.height_at(SPAWN_XZ.x, SPAWN_XZ.y), SPAWN_XZ.y)
	set_spawn(spawn_floor, spawn_facing)
	_build_hot_tub()
	_build_big_duck()
	_place_objectives()
	extraction(_floor(PAD_XZ))
	hint_zone(spawn_floor + Vector3(0.0, 1.2, -6.0), Vector3(16.0, 3.0, 10.0), intro_hint, 9.0)
	_freeze_lakes()
	_populate()


func _floor(xz: Vector2) -> Vector3:
	return Vector3(xz.x, land.height_at(xz.x, xz.y), xz.y)


## The terrain mesh and its exact collider. The border height continues as the outer plain.
func _build_ground() -> void:
	var view := MeshInstance3D.new()
	view.name = "Terrain"
	view.mesh = land.build_mesh()
	view.material_override = Alpine.surface_material(Color("dce9ef"), true)
	# 157k triangles drawn again in every shadow cascade cost more than the gentle hills' shadows
	# are worth; trees, rocks and props still cast onto it (V2b).
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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


## Princess Capybara, in a wooden hot tub, wearing a crown and a towel turban. She is solid (two
## boxes under the painted model); so is the tub. Steam rises off the water on Medium and High.
func _build_hot_tub() -> void:
	var base: Vector3 = _floor(TUB_XZ)
	cylinder(base + Vector3(0.0, 0.55, 0.0), 2.8, 1.1, "rust")
	cylinder(base + Vector3(0.0, 1.08, 0.0), 2.55, 0.06, "glass", false)
	# Two iron hoops round the staves, flush on the tub.
	for y: float in [0.22, 0.88]:
		cylinder(base + Vector3(0.0, y, 0.0), 2.84, 0.1, "dark", false)
	var princess := MeshInstance3D.new()
	princess.name = "PrincessCapybara"
	princess.mesh = DreamProps.princess_mesh()
	var painted := StandardMaterial3D.new()
	painted.vertex_color_use_as_albedo = true
	painted.vertex_color_is_srgb = true
	painted.roughness = 0.85
	princess.material_override = painted
	princess.position = base
	princess.scale = Vector3.ONE * PRINCESS_SCALE
	add_child(princess)
	var body := BoxShape3D.new()
	body.size = Vector3(1.8, 1.3, 2.6) * PRINCESS_SCALE
	add_world_collider(body, Transform3D(Basis.IDENTITY, base + Vector3(0.0, 0.95, -0.2) * PRINCESS_SCALE))
	var head := BoxShape3D.new()
	head.size = Vector3(1.0, 1.4, 1.7) * PRINCESS_SCALE
	add_world_collider(head, Transform3D(Basis.IDENTITY, base + Vector3(0.0, 2.2, 0.85) * PRINCESS_SCALE))
	if quality >= 1:
		add_child(_tub_steam(base + Vector3(0.0, 1.15, 0.0)))
	_sign(tub_sign, base + Vector3(-5.0, 0.0, 4.5), Vector2(5.4, 2.0))
	light(base + Vector3(0.0, 4.0, 0.0), Color("ffe3b0"), 1.2, 18.0)


## Soft puffs of steam off the tub: a few slow, fading spheres, no text and nothing to stand on.
func _tub_steam(at: Vector3) -> CPUParticles3D:
	var steam := CPUParticles3D.new()
	steam.name = "TubSteam"
	steam.position = at
	steam.amount = 18
	steam.lifetime = 3.2
	steam.preprocess = 3.2
	steam.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	steam.emission_box_extents = Vector3(1.7, 0.05, 1.7)
	steam.direction = Vector3.UP
	steam.spread = 12.0
	steam.gravity = Vector3(0.0, 0.25, 0.0)
	steam.initial_velocity_min = 0.25
	steam.initial_velocity_max = 0.5
	steam.scale_amount_min = 0.7
	steam.scale_amount_max = 1.3
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.4))
	grow.add_point(Vector2(1.0, 1.4))
	steam.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.0)])
	fade.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	steam.color_ramp = fade
	# A soft round puff: a camera-facing quad with a radial fade, so no hard edge shows.
	var soft := GradientTexture2D.new()
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5, 0.5)
	soft.fill_to = Vector2(1.0, 0.5)
	soft.width = 64
	soft.height = 64
	var edge := Gradient.new()
	edge.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	soft.gradient = edge
	var puff := QuadMesh.new()
	puff.size = Vector2(1.6, 1.6)
	var look := StandardMaterial3D.new()
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.vertex_color_use_as_albedo = true
	look.albedo_color = Color("eef4f6")
	look.albedo_texture = soft
	look.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	puff.material = look
	steam.mesh = puff
	steam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return steam


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
## yaw (degrees) turns the board about its base; 0 faces +z.
func _sign(text: String, base: Vector3, size: Vector2, yaw: float = 0.0) -> void:
	var turn := Basis(Vector3.UP, deg_to_rad(yaw))
	var center: Vector3 = base + Vector3(0.0, 1.2 + size.y * 0.5, 0.0)
	box(center, Vector3(size.x, size.y, 0.15), "rust", true, yaw)
	for side: float in [-1.0, 1.0]:
		var post: Vector3 = turn * Vector3(side * (size.x * 0.5 - 0.3), 0.0, -0.1)
		box(Vector3(center.x + post.x, base.y + 0.9, center.z + post.z), Vector3(0.18, 1.8 + size.y * 0.5, 0.18), "dark", true, yaw)
	var face: Label3D = label(text, center + turn * Vector3(0.0, 0.0, 0.1), 36, Color("fff4dc"), 0.012, false, yaw)
	face.double_sided = false

## The top of the giant duck's head, where something small and absurd can be left for the rod.
func big_duck_head() -> Vector3:
	return Vector3(BIG_DUCK_XZ.x, Terrain.WATER_Y + 13.7, BIG_DUCK_XZ.y + 3.5)


## Override: the errand's pickups. By default the rubber duck in the far forest.
func _place_objectives() -> void:
	case_at(_floor(DUCK_XZ), "01 / THE RUBBER DUCK", "duck")


## Override: traps, hostiles and the flood for this version of the valley.
func _populate() -> void:
	pass


## Both lakes are deep, freezing water under a sheet of thin ice that cracks under the player.
func _freeze_lakes() -> void:
	for lake: Vector3 in [WEST_LAKE, EAST_LAKE]:
		var reach: float = lake.z * 1.35
		hazard_box(AABB(Vector3(lake.x - reach, Terrain.WATER_Y - 9.0, lake.y - reach), Vector3(reach * 2.0, 9.0, reach * 2.0)), "water", WATER_DPS)
		var over_water := func(x: float, z: float) -> bool: return land.height_at(x, z) < Terrain.WATER_Y - 0.35
		traps().crack_field(Vector3(lake.x, Terrain.WATER_Y + 0.05, lake.y), Vector2(reach * 2.0, reach * 2.0), 6.0, "ice", over_water)


## Teacup mines on open meadow inside area: flat-ish, dry, and clear of the keep-clear spots.
func scatter_mines(area: Rect2, count: int, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var placed: int = 0
	var tries: int = 0
	while placed < count and tries < count * 40:
		tries += 1
		var x: float = rng.randf_range(area.position.x, area.end.x)
		var z: float = rng.randf_range(area.position.y, area.end.y)
		var h: float = land.height_at(x, z)
		if h < Terrain.WATER_Y + 0.8 or land.normal_at(x, z).y < 0.93 or land.forest_at(x, z) > 0.5:
			continue
		var clear: bool = true
		for spot: Vector3 in keep_clear:
			if Vector2(x - spot.x, z - spot.y).length() < spot.z + 6.0:
				clear = false
				break
		if not clear:
			continue
		traps().mine(Vector3(x, h, z))
		placed += 1


## A marble resting on the ground at xz, released when the player enters a box centred on
## trigger_xz (size metres across, the full valley height).
func marble(xz: Vector2, radius: float, trigger_xz: Vector2, size: float, push: Vector3) -> void:
	var rest: Vector3 = _floor(xz) + Vector3.UP * (radius + 0.3)
	var trigger := AABB(Vector3(trigger_xz.x - size * 0.5, -40.0, trigger_xz.y - size * 0.5), Vector3(size, 300.0, size))
	traps().boulder(rest, radius, trigger, push)
