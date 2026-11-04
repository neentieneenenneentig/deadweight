extends RefCounted
## Trees, rocks and grass for a Terrain (W1). Low-poly, vertex coloured, drawn with one MultiMesh
## per kind. Trees and rocks are solid (trunk, canopy and boulder colliders); grass and flowers are
## not, like the real thing. Deterministic for a seed.
##
## Usage: Nature.scatter(level, land, seed, keep_clear) after the terrain is generated, where
## keep_clear is an Array[Vector3] of (x, z, radius) spots that stay open (spawn, pads, paths).

const Terrain = preload("res://scripts/world/terrain.gd")

const PINE_TRUNK := Color("6b4a32")
const PINE_LEAF := Color("3f6f3a")
const PINE_LEAF_LIGHT := Color("5a8c45")
const OAK_TRUNK := Color("775338")
const OAK_LEAF := Color("6ea443")
const OAK_LEAF_LIGHT := Color("94c25a")
const ROCK := Color("9a968a")
const GRASS := Color("8cbd52")
const FLOWERS := [Color("f4e27a"), Color("f2f2f2"), Color("e98bb0"), Color("9ab8f2")]

const TREE_SPACING := 9.0            # metres between scatter candidates
const ROCK_SPACING := 26.0
const GRASS_RADIUS := 220.0          # tufts only grow this close to the centre of keep_clear[0]
const GRASS_COUNT := 5000


static func scatter(level: Node3D, land: Terrain, seed_value: int, keep_clear: Array[Vector3]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pines: Array[Transform3D] = []
	var oaks: Array[Transform3D] = []
	var rocks: Array[Transform3D] = []
	var half: float = land.size * 0.5 - 30.0
	var x: float = -half
	while x < half:
		var z: float = -half
		while z < half:
			var px: float = x + rng.randf_range(-3.5, 3.5)
			var pz: float = z + rng.randf_range(-3.5, 3.5)
			var roll: float = rng.randf()
			var scale: float = rng.randf_range(0.0, 1.0)
			var yaw: float = rng.randf() * TAU
			z += TREE_SPACING
			if _blocked(px, pz, keep_clear):
				continue
			var h: float = land.height_at(px, pz)
			var n: Vector3 = land.normal_at(px, pz)
			if h < Terrain.WATER_Y + 1.5 or n.y < 0.8 or h > Terrain.TREE_LINE:
				continue
			var forest: float = land.forest_at(px, pz)
			if roll > forest * 0.55 + 0.015:
				continue
			# Pines up high and in dense forest; broad trees in the open meadows.
			var pine: bool = h > 40.0 or forest > 0.7 or land.is_snow(px, pz, h + 20.0)
			var s: float = lerpf(1.2, 2.2, scale) if pine else lerpf(1.0, 1.7, scale)
			var placement := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), Vector3(px, h - 0.3, pz))
			if pine:
				pines.append(placement)
			else:
				oaks.append(placement)
		x += TREE_SPACING
	x = -half
	while x < half:
		var z: float = -half
		while z < half:
			var px: float = x + rng.randf_range(-9.0, 9.0)
			var pz: float = z + rng.randf_range(-9.0, 9.0)
			var keep: bool = rng.randf() < 0.45
			var s: float = rng.randf_range(0.8, 3.4)
			var tilt := Basis.from_euler(Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4)))
			z += ROCK_SPACING
			if not keep or _blocked(px, pz, keep_clear):
				continue
			var h: float = land.height_at(px, pz)
			if h < Terrain.WATER_Y - 1.0:
				continue
			rocks.append(Transform3D(tilt.scaled(Vector3.ONE * s), Vector3(px, h - s * 0.35, pz)))
		x += ROCK_SPACING
	_add_multimesh(level, "Pines", _pine_mesh(), pines, rng, 0.12)
	_add_multimesh(level, "Oaks", _oak_mesh(), oaks, rng, 0.14)
	_add_multimesh(level, "Rocks", _rock_mesh(), rocks, rng, 0.08)
	# Shapes go on a body outside the tree first, then the body joins the level in one step.
	var body := StaticBody3D.new()
	body.name = "Nature"
	for placement: Transform3D in pines:
		_pine_colliders(body, placement)
	for placement: Transform3D in oaks:
		_oak_colliders(body, placement)
	for placement: Transform3D in rocks:
		var ball := SphereShape3D.new()
		ball.radius = placement.basis.get_scale().x * 0.95
		_shape(body, ball, Transform3D(Basis.IDENTITY, placement.origin))
	level.call("adopt_world_body", body)
	# The bake skips these shapes; trunks carve round posts in the navmesh instead (crowns are overhead).
	var posts: Array[Vector4] = level.get("nav_posts")
	var skip: Array[CollisionObject3D] = level.get("nav_skip_bodies")
	skip.append(body)
	for placement: Transform3D in pines + oaks:
		posts.append(Vector4(placement.origin.x, placement.origin.y, placement.origin.z, 0.35 * placement.basis.get_scale().x))
	for placement: Transform3D in rocks:
		posts.append(Vector4(placement.origin.x, placement.origin.y, placement.origin.z, 0.8 * placement.basis.get_scale().x))
	_add_grass(level, land, rng, keep_clear)


static func _blocked(x: float, z: float, keep_clear: Array[Vector3]) -> bool:
	for spot: Vector3 in keep_clear:
		if Vector2(x - spot.x, z - spot.y).length() < spot.z:
			return true
	return false


# --- Meshes (unit size; instances scale them) ----------------------------------------------------

static func _pine_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append(tool, _cylinder(0.22, 0.28, 2.0, 6), Transform3D(Basis.IDENTITY, Vector3(0, 1.0, 0)), PINE_TRUNK)
	_append(tool, _cylinder(0.0, 2.2, 3.2, 8), Transform3D(Basis.IDENTITY, Vector3(0, 3.1, 0)), PINE_LEAF)
	_append(tool, _cylinder(0.0, 1.7, 2.8, 8), Transform3D(Basis.IDENTITY, Vector3(0, 4.5, 0)), PINE_LEAF.lerp(PINE_LEAF_LIGHT, 0.5))
	_append(tool, _cylinder(0.0, 1.1, 2.4, 8), Transform3D(Basis.IDENTITY, Vector3(0, 5.8, 0)), PINE_LEAF_LIGHT)
	return tool.commit()


static func _oak_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append(tool, _cylinder(0.26, 0.36, 3.2, 6), Transform3D(Basis.IDENTITY, Vector3(0, 1.6, 0)), OAK_TRUNK)
	_append(tool, _sphere(2.4), Transform3D(Basis.IDENTITY, Vector3(0, 4.4, 0)), OAK_LEAF)
	_append(tool, _sphere(1.8), Transform3D(Basis.IDENTITY, Vector3(1.5, 3.8, 0.6)), OAK_LEAF_LIGHT)
	_append(tool, _sphere(1.7), Transform3D(Basis.IDENTITY, Vector3(-1.3, 4.0, -0.7)), OAK_LEAF.lerp(OAK_LEAF_LIGHT, 0.5))
	return tool.commit()


static func _rock_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 7
	sphere.rings = 4
	_append(tool, sphere, Transform3D.IDENTITY, ROCK)
	return tool.commit()


static func _cylinder(top: float, bottom: float, height: float, sides: int) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	return mesh


static func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 9
	mesh.rings = 5
	return mesh


## Copies a primitive into the tool with a transform and one vertex colour.
static func _append(tool: SurfaceTool, mesh: PrimitiveMesh, placement: Transform3D, color: Color) -> void:
	var arrays: Array = mesh.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var normal_basis: Basis = placement.basis.inverse().transposed()
	for index: int in indices:
		tool.set_color(color)
		tool.set_normal((normal_basis * normals[index]).normalized())
		tool.add_vertex(placement * vertices[index])


static func _add_multimesh(level: Node3D, title: String, mesh: ArrayMesh, placements: Array[Transform3D], rng: RandomNumberGenerator, tint: float) -> void:
	if placements.is_empty():
		return
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = mesh
	multi.instance_count = placements.size()
	for i in range(placements.size()):
		multi.set_instance_transform(i, placements[i])
		var v: float = 1.0 + rng.randf_range(-tint, tint)
		multi.set_instance_color(i, Color(v, v * rng.randf_range(0.97, 1.03), v * 0.98))
	var view := MultiMeshInstance3D.new()
	view.name = title
	view.multimesh = multi
	view.material_override = _vertex_material()
	level.add_child(view)


static func _vertex_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.92
	return material


# --- Colliders: what looks solid is solid ---------------------------------------------------------

static func _pine_colliders(body: StaticBody3D, placement: Transform3D) -> void:
	var s: float = placement.basis.get_scale().x
	var trunk := CylinderShape3D.new()
	trunk.radius = 0.28 * s
	trunk.height = 2.0 * s
	_shape(body, trunk, Transform3D(Basis.IDENTITY, placement.origin + Vector3.UP * s))
	# The three foliage tiers as one hull: from the widest ring up to the tip.
	var points := PackedVector3Array()
	for k in range(8):
		var a: float = float(k) * TAU / 8.0
		points.append(Vector3(cos(a) * 2.2, 1.5, sin(a) * 2.2) * s)
	points.append(Vector3(0.0, 7.0, 0.0) * s)
	var crown := ConvexPolygonShape3D.new()
	crown.points = points
	_shape(body, crown, Transform3D(Basis.IDENTITY, placement.origin))


static func _oak_colliders(body: StaticBody3D, placement: Transform3D) -> void:
	var s: float = placement.basis.get_scale().x
	var trunk := CylinderShape3D.new()
	trunk.radius = 0.32 * s
	trunk.height = 3.2 * s
	_shape(body, trunk, Transform3D(Basis.IDENTITY, placement.origin + Vector3.UP * 1.6 * s))
	var spots: Array[Vector4] = [Vector4(0, 4.4, 0, 2.4), Vector4(1.5, 3.8, 0.6, 1.8), Vector4(-1.3, 4.0, -0.7, 1.7)]
	for spot: Vector4 in spots:
		var ball := SphereShape3D.new()
		ball.radius = spot.w * s
		var offset: Vector3 = placement.basis * Vector3(spot.x, spot.y, spot.z)
		_shape(body, ball, Transform3D(Basis.IDENTITY, placement.origin + offset))


static func _shape(body: StaticBody3D, shape: Shape3D, placement: Transform3D) -> void:
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.transform = placement
	body.add_child(collision)


# --- Grass and flowers: visual only --------------------------------------------------------------

static func _add_grass(level: Node3D, land: Terrain, rng: RandomNumberGenerator, keep_clear: Array[Vector3]) -> void:
	if keep_clear.is_empty():
		return
	var center := Vector2(keep_clear[0].x, keep_clear[0].y)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in range(3):
		var lean := Basis.from_euler(Vector3(0.25, float(k) * TAU / 3.0, 0.0))
		_append(tool, _cylinder(0.0, 0.07, 0.7, 3), Transform3D(lean, lean * Vector3(0, 0.3, 0)), GRASS)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = tool.commit()
	var placements: Array[Transform3D] = []
	var colors: Array[Color] = []
	for i in range(GRASS_COUNT):
		var angle: float = rng.randf() * TAU
		var distance: float = sqrt(rng.randf()) * GRASS_RADIUS
		var px: float = center.x + cos(angle) * distance
		var pz: float = center.y + sin(angle) * distance
		var h: float = land.height_at(px, pz)
		if h < Terrain.WATER_Y + 1.0 or land.is_snow(px, pz, h):
			continue
		var s: float = rng.randf_range(0.7, 1.5)
		placements.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(px, h, pz)))
		# One tuft in twelve is a flower.
		colors.append(FLOWERS[rng.randi() % FLOWERS.size()] * 1.6 if rng.randf() < 0.08 else Color(1, 1, 1).lerp(Color(0.85, 1.0, 0.7), rng.randf()))
	multi.instance_count = placements.size()
	for i in range(placements.size()):
		multi.set_instance_transform(i, placements[i])
		multi.set_instance_color(i, colors[i])
	var view := MultiMeshInstance3D.new()
	view.name = "Grass"
	view.multimesh = multi
	view.material_override = _vertex_material()
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level.add_child(view)
