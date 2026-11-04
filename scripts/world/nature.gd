extends RefCounted
## Trees, rocks and grass for a Terrain (W1). Low-poly, vertex coloured, drawn with one MultiMesh
## per kind. Trees and rocks are solid (trunk, canopy and boulder colliders); grass and flowers are
## not, like the real thing. Deterministic for a seed.
##
## Usage: Nature.scatter(level, land, seed, keep_clear) after the terrain is generated, where
## keep_clear is an Array[Vector3] of (x, z, radius) spots that stay open (spawn, pads, paths).

const Alpine = preload("res://scripts/world/alpine.gd")
static var _pine_model: ArrayMesh
static var _pine_hulls: Array[Shape3D] = []
static var _rock_model: ArrayMesh
static var _rock_hull: Shape3D
static var _oak_model: ArrayMesh
static var _oak_parts: Array[Array] = []
static var _pine_far: ArrayMesh
static var _oak_far: ArrayMesh
static var _rock_far: ArrayMesh

const Terrain = preload("res://scripts/world/terrain.gd")

const PINE_TRUNK := Color("514b48")
const PINE_LEAF := Color("294b50")
const PINE_LEAF_LIGHT := Color("4b7472")
const OAK_TRUNK := Color("65594d")
const OAK_LEAF := Color("4e7170")
const OAK_LEAF_LIGHT := Color("82a09a")
const ROCK := Color("8295a5")
const GRASS := Color("7d9466")
# Small alpine flowers in the thawed hollows: saxifrage white, gentian blue, cinquefoil, heather.
const FLOWERS := [Color("e8ecef"), Color("8fa6dc"), Color("d9c46a"), Color("c9a6c8")]

const TREE_SPACING := 9.0            # metres between scatter candidates
const ROCK_SPACING := 26.0
const GRASS_RADIUS := 220.0          # tufts only grow this close to the centre of keep_clear[0]
const GRASS_COUNT := 9000           # candidates; only those on thawed ground grow
const CHUNK := 350.0                 # metres per MultiMesh cell, so culling and shadow cascades can skip cells
## W6: a cell whose centre is further than this from the camera swaps to a far mesh with about a
## tenth of the triangles and no shadow. Scaled by quality (level_base.apply_quality). The margin
## is hysteresis, so a cell on the line does not flicker. Nothing is culled: every tree and rock
## that is solid is always drawn, near or far.
const LOD_RANGE := 420.0
const LOD_MARGIN := 40.0
const LOD_SCALE := [0.6, 0.85, 1.0]


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
	for landmark: Vector3 in [Vector3(-34, 3.8, 39), Vector3(-39, 2.3, 34), Vector3(38, 4.2, 16), Vector3(43, 2.0, 21)]:
		if not _blocked(landmark.x, landmark.z, keep_clear):
			var h: float = land.height_at(landmark.x, landmark.z)
			var frame := Basis.from_euler(Vector3(0.1, landmark.x * 0.2, -0.15)).scaled(Vector3.ONE * landmark.y)
			rocks.append(Transform3D(frame, Vector3(landmark.x, h - landmark.y * 0.25, landmark.z)))
	_add_multimesh(level, "Pines", _pine_mesh(), pines, rng, 0.12, CHUNK, _pine_far_mesh())
	_add_multimesh(level, "Oaks", _oak_mesh(), oaks, rng, 0.14, CHUNK, _oak_far_mesh())
	_add_multimesh(level, "Rocks", _rock_mesh(), rocks, rng, 0.08, CHUNK, _rock_far_mesh())
	# Shapes go on a body outside the tree first, then the body joins the level in one step.
	var body := StaticBody3D.new()
	body.name = "Nature"
	for placement: Transform3D in pines:
		_pine_colliders(body, placement)
	for placement: Transform3D in oaks:
		_oak_colliders(body, placement)
	for placement: Transform3D in rocks:
		_shape(body, _rock_hull, placement)
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


## Pine groves on the flat snow between a compact level and its mountain ring (V2b). Solid like
## every other tree, on a body the route navmesh skips. ring = (inner, outer) distance from centre;
## margin keeps the trees that far outside the footprint.
static func grove(level: Node3D, centre: Vector3, ring: Vector2, footprint: Rect2, margin: float, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var clumps := FastNoiseLite.new()
	clumps.seed = seed_value
	clumps.frequency = 0.02
	var keep: Rect2 = footprint.grow(margin)
	var pines: Array[Transform3D] = []
	var x: float = centre.x - ring.y
	while x < centre.x + ring.y:
		var z: float = centre.z - ring.y
		while z < centre.z + ring.y:
			var p := Vector2(x + rng.randf_range(-3.5, 3.5), z + rng.randf_range(-3.5, 3.5))
			var roll: float = rng.randf()
			var s: float = rng.randf_range(1.1, 2.3)
			var yaw: float = rng.randf() * TAU
			z += TREE_SPACING
			var d: float = p.distance_to(Vector2(centre.x, centre.z))
			if d < ring.x or d > ring.y or keep.has_point(p):
				continue
			var dense: float = clumps.get_noise_2d(p.x, p.y) * 0.5 + 0.5
			if roll < smoothstep(0.45, 0.8, dense) * 0.7:
				pines.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), Vector3(p.x, centre.y - 0.3, p.y)))
		x += TREE_SPACING
	if pines.is_empty():
		return
	# A grove is small: one MultiMesh is cheaper than cells. Pines only, to spare draw calls.
	_add_multimesh(level, "Pines", _pine_mesh(), pines, rng, 0.12, 0.0)
	var body := StaticBody3D.new()
	body.name = "Grove"
	for placement: Transform3D in pines:
		_pine_colliders(body, placement)
	level.call("adopt_world_body", body)
	(level.get("nav_skip_bodies") as Array).append(body)


static func _blocked(x: float, z: float, keep_clear: Array[Vector3]) -> bool:
	for spot: Vector3 in keep_clear:
		if Vector2(x - spot.x, z - spot.y).length() < spot.z:
			return true
	return false


# --- Meshes (unit size; instances scale them) ----------------------------------------------------

static func _pine_mesh() -> ArrayMesh:
	if _pine_model != null:
		return _pine_model
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append(tool, _cylinder(0.18, 0.3, 2.5, 7), Transform3D(Basis.IDENTITY, Vector3(0, 1.25, 0)), PINE_TRUNK)
	# Unequal, drooping skirts with notched rims; each tier has a separate solid hull.
	for tier in range(3):
		var radius: float = 2.3 - float(tier) * 0.62
		var height: float = 2.7 - float(tier) * 0.25
		var origin := Vector3(sin(float(tier) * 2.1) * 0.24, 1.45 + float(tier) * 1.65, cos(float(tier)) * 0.16)
		var rings: Array[PackedVector3Array] = []
		var all_points := PackedVector3Array()
		var profile: Array[Vector2] = [Vector2(0.05, 1.0), Vector2(0.48, 0.62), Vector2(1.0, 0.10), Vector2(0.64, 0.0)]
		for ring in range(profile.size()):
			var row := PackedVector3Array()
			for spoke in range(12):
				var angle: float = float(spoke) * TAU / 12.0 + float(tier) * 0.47
				var jag: float = 0.92 + sin(float(spoke * 7 + tier * 13)) * 0.16 + (0.18 if spoke % 2 == 0 else -0.22)
				var r: float = radius * profile[ring].x * jag
				var droop: float = sin(angle * 3.0 + float(tier)) * 0.32 * profile[ring].x
				var point: Vector3 = origin + Vector3(cos(angle) * r, height * profile[ring].y + droop, sin(angle) * r)
				row.append(point)
				all_points.append(point)
			rings.append(row)
		for ring in range(3):
			for spoke in range(12):
				var next: int = (spoke + 1) % 12
				_facet(tool, rings[ring][spoke], rings[ring + 1][spoke], rings[ring][next], origin + Vector3.UP * 0.6, PINE_LEAF, true)
				_facet(tool, rings[ring][next], rings[ring + 1][spoke], rings[ring + 1][next], origin + Vector3.UP * 0.6, PINE_LEAF, true)
		for spoke in range(12):
			var next: int = (spoke + 1) % 12
			_facet(tool, origin + Vector3.UP * height, rings[0][spoke], rings[0][next], origin, PINE_LEAF_LIGHT, true)
			_facet(tool, origin, rings[3][next], rings[3][spoke], origin + Vector3.UP, PINE_LEAF, false)
		var hull := ConvexPolygonShape3D.new()
		hull.points = all_points
		_pine_hulls.append(hull)
	_pine_model = tool.commit()
	return _pine_model


## The far pine: the same three tiers as six-sided cones, no trunk (36 triangles, not 328).
static func _pine_far_mesh() -> ArrayMesh:
	if _pine_far != null:
		return _pine_far
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tier in range(3):
		var radius: float = 2.3 - float(tier) * 0.62
		var height: float = 2.7 - float(tier) * 0.25
		var origin := Vector3(sin(float(tier) * 2.1) * 0.24, 1.45 + float(tier) * 1.65, cos(float(tier)) * 0.16)
		var tip: Vector3 = origin + Vector3.UP * height
		for spoke in range(6):
			var a: float = float(spoke) * TAU / 6.0 + float(tier) * 0.47
			var b: float = float(spoke + 1) * TAU / 6.0 + float(tier) * 0.47
			var rim_a: Vector3 = origin + Vector3(cos(a) * radius * 0.95, height * 0.1, sin(a) * radius * 0.95)
			var rim_b: Vector3 = origin + Vector3(cos(b) * radius * 0.95, height * 0.1, sin(b) * radius * 0.95)
			_facet(tool, tip, rim_a, rim_b, origin, PINE_LEAF, true)
			_facet(tool, origin, rim_b, rim_a, origin + Vector3.UP, PINE_LEAF, false)
	_pine_far = tool.commit()
	return _pine_far


## The far broadleaf: the bent trunk and the five main limbs, three-sided, no twigs.
static func _oak_far_mesh() -> ArrayMesh:
	if _oak_far != null:
		return _oak_far
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var limbs: Array[Array] = [
		[Vector3.ZERO, Vector3(0.16, 1.8, 0.1), 0.38, 0.28],
		[Vector3(0.16, 1.8, 0.1), Vector3(-0.25, 3.5, 0.0), 0.28, 0.18],
		[Vector3(-0.25, 3.5, 0.0), Vector3(0.3, 5.5, 0.2), 0.18, 0.035],
	]
	for i in range(5):
		var angle: float = float(i) * 2.39996
		var start := Vector3(0, 1.7 + float(i) * 0.45, 0)
		var joint: Vector3 = start + Vector3(cos(angle) * 1.15, 0.45, sin(angle) * 1.15)
		var tip: Vector3 = joint + Vector3(cos(angle + 0.3) * 0.95, 1.2, sin(angle + 0.3) * 0.95)
		limbs.append([start, tip, 0.15 - float(i) * 0.015, 0.025])
	for limb: Array in limbs:
		var a: Vector3 = limb[0]
		var b: Vector3 = limb[1]
		var frame := Transform3D(Basis(Quaternion(Vector3.UP, (b - a).normalized())), (a + b) * 0.5)
		_append(tool, _cylinder(limb[3], limb[2], (b - a).length(), 3), frame, OAK_TRUNK)
	_oak_far = tool.commit()
	return _oak_far


static func _oak_mesh() -> ArrayMesh:
	if _oak_model != null:
		return _oak_model
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Winter broadleaf: bent wood and forked branches instead of three spheres.
	_branch(tool, Vector3.ZERO, Vector3(0.16, 1.8, 0.1), 0.38, 0.28)
	_branch(tool, Vector3(0.16, 1.8, 0.1), Vector3(-0.25, 3.5, 0.0), 0.28, 0.18)
	_branch(tool, Vector3(-0.25, 3.5, 0.0), Vector3(0.3, 5.5, 0.2), 0.18, 0.035)
	for i in range(5):
		var angle: float = float(i) * 2.39996
		var start := Vector3(0, 1.7 + float(i) * 0.45, 0)
		var joint: Vector3 = start + Vector3(cos(angle) * 1.15, 0.45, sin(angle) * 1.15)
		var tip: Vector3 = joint + Vector3(cos(angle + 0.3) * 0.95, 1.2, sin(angle + 0.3) * 0.95)
		_branch(tool, start, joint, 0.15 - float(i) * 0.015, 0.09)
		_branch(tool, joint, tip, 0.09, 0.025)
		_branch(tool, joint, joint + Vector3(cos(angle - 0.7) * 0.8, 0.7, sin(angle - 0.7) * 0.8), 0.065, 0.015)
	_oak_model = tool.commit()
	return _oak_model


static func _branch(tool: SurfaceTool, a: Vector3, b: Vector3, bottom: float, top: float) -> void:
	var delta: Vector3 = b - a
	var frame := Transform3D(Basis(Quaternion(Vector3.UP, delta.normalized())), (a + b) * 0.5)
	var branch_mesh: CylinderMesh = _cylinder(top, bottom, delta.length(), 6)
	_append(tool, branch_mesh, frame, OAK_TRUNK)
	_oak_parts.append([branch_mesh.create_convex_shape(true, false), frame])


static func _rock_mesh() -> ArrayMesh:
	if _rock_model != null:
		return _rock_model
	_rock_model = _chipped_rock(9, 5)
	_rock_hull = _rock_model.create_convex_shape(true, false)
	return _rock_model


## The far rock: the same chipped boulder from a coarser sphere.
static func _rock_far_mesh() -> ArrayMesh:
	if _rock_far == null:
		_rock_far = _chipped_rock(5, 2)
	return _rock_far


static func _chipped_rock(segments: int, rings: int) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = segments
	sphere.rings = rings
	var arrays: Array = sphere.get_mesh_arrays()
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i in range(points.size()):
		var v: Vector3 = points[i]
		var chip: float = 1.0 + sin(v.dot(Vector3(5.3, 7.1, 3.7))) * 0.14 + sin(v.dot(Vector3(13.1, 4.7, 9.3))) * 0.07
		v *= chip
		v.y = minf(v.y, 0.67 + sin(v.x * 4.0) * 0.12)
		v.x += v.y * 0.19
		points[i] = v
	for i in range(0, indices.size(), 3):
		_facet(tool, points[indices[i]], points[indices[i + 1]], points[indices[i + 2]], Vector3.ZERO, ROCK, true)
	return tool.commit()


## Broad painted facets rather than smooth primitive shading. Snow rests on upper planes.
static func _facet(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, centre: Vector3, color: Color, snowy: bool) -> void:
	var normal: Vector3 = (b - a).cross(c - a)
	if normal.length_squared() < 0.000001:
		return
	normal = normal.normalized()
	if normal.dot((a + b + c) / 3.0 - centre) < 0.0:
		var swap: Vector3 = b
		b = c
		c = swap
		normal = -normal
	var brush: float = 0.5 + sin((a.x + c.z) * 4.7 + b.y * 2.1) * 0.5
	var painted: Color = color * (0.85 + brush * 0.25)
	if snowy:
		painted = painted.lerp(Color("d8e7ee"), smoothstep(0.35, 0.8, normal.y + brush * 0.1))
	tool.set_color(painted)
	tool.set_normal(normal)
	tool.add_vertex(a)
	tool.add_vertex(c)
	tool.add_vertex(b)


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


static func _add_multimesh(level: Node3D, title: String, mesh: ArrayMesh, placements: Array[Transform3D], rng: RandomNumberGenerator, tint: float, chunk: float = CHUNK, far: ArrayMesh = null) -> void:
	# chunk <= 0: a single MultiMesh. far: a cheap mesh each cell swaps to past LOD_RANGE.
	if placements.is_empty():
		return
	# One MultiMesh per CHUNK cell: a single valley-wide AABB would be drawn whole in the main
	# view and again in every shadow cascade.
	var cells: Dictionary = {}
	for placement: Transform3D in placements:
		var key := Vector2i.ZERO if chunk <= 0.0 else Vector2i(floori(placement.origin.x / chunk), floori(placement.origin.z / chunk))
		if not cells.has(key):
			cells[key] = [] as Array[Transform3D]
		(cells[key] as Array[Transform3D]).append(placement)
	var material: Material = Alpine.surface_material(Color("dce9ef"), true) if title.begins_with("Rocks") else _vertex_material()
	var keys: Array = cells.keys()
	keys.sort()
	for key: Vector2i in keys:
		var group: Array[Transform3D] = cells[key]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = mesh
		multi.instance_count = group.size()
		# The far twin gets the same transforms and tints, so the swap only changes the shape.
		var far_multi: MultiMesh = null
		if far != null:
			far_multi = MultiMesh.new()
			far_multi.transform_format = MultiMesh.TRANSFORM_3D
			far_multi.use_colors = true
			far_multi.mesh = far
			far_multi.instance_count = group.size()
		for i in range(group.size()):
			var v: float = 1.0 + rng.randf_range(-tint, tint)
			var tint_color := Color(v, v * rng.randf_range(0.97, 1.03), v * 0.98)
			multi.set_instance_transform(i, group[i])
			multi.set_instance_color(i, tint_color)
			if far_multi != null:
				far_multi.set_instance_transform(i, group[i])
				far_multi.set_instance_color(i, tint_color)
		var view := MultiMeshInstance3D.new()
		view.name = title if key == keys[0] else "%s_%d_%d" % [title, key.x, key.y]
		view.multimesh = multi
		view.material_override = material
		level.add_child(view)
		if far_multi == null:
			continue
		var far_view := MultiMeshInstance3D.new()
		far_view.name = "%sFar_%d_%d" % [title, key.x, key.y]
		far_view.multimesh = far_multi
		far_view.material_override = material
		far_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		level.add_child(far_view)
		# Near cells cast their shadows from the far shape: in every cascade it is the same cone
		# silhouette for a ninth of the triangles. Shadow-only, so it is never seen itself.
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var caster := MultiMeshInstance3D.new()
		caster.name = "%sShadow_%d_%d" % [title, key.x, key.y]
		caster.multimesh = far_multi
		caster.material_override = material
		caster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		level.add_child(caster)
		for near: GeometryInstance3D in [view, caster]:
			near.set_meta("lod", "near")
			set_lod_range(near, LOD_RANGE)
		far_view.set_meta("lod", "far")
		set_lod_range(far_view, LOD_RANGE)


## Moves every near/far switch under level to the range for a quality (0 Low, 1 Medium, 2 High).
static func apply_lod(level: Node, quality: int) -> void:
	var range_m: float = LOD_RANGE * float(LOD_SCALE[clampi(quality, 0, LOD_SCALE.size() - 1)])
	for child: Node in level.get_children():
		if child is GeometryInstance3D and child.has_meta("lod"):
			set_lod_range(child as GeometryInstance3D, range_m)


## Puts a near or far cell's switch at range metres (W6). Views without "lod" meta are left alone.
static func set_lod_range(view: GeometryInstance3D, range_m: float) -> void:
	match str(view.get_meta("lod", "")):
		"near":
			view.visibility_range_end = range_m
			view.visibility_range_end_margin = LOD_MARGIN
		"far":
			view.visibility_range_begin = range_m
			view.visibility_range_begin_margin = LOD_MARGIN


static func _vertex_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.92
	return material


# --- Colliders: what looks solid is solid ---------------------------------------------------------

static func _pine_colliders(body: StaticBody3D, placement: Transform3D) -> void:
	var trunk := CylinderShape3D.new()
	trunk.radius = 0.3
	trunk.height = 2.5
	_shape(body, trunk, placement * Transform3D(Basis.IDENTITY, Vector3.UP * 1.25))
	for hull: Shape3D in _pine_hulls:
		_shape(body, hull, placement)


static func _oak_colliders(body: StaticBody3D, placement: Transform3D) -> void:
	for part: Array in _oak_parts:
		_shape(body, part[0], placement * (part[1] as Transform3D))


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
		# Tufts grow only where the snow has thawed (V2b); none poke out of a snowfield.
		if h < Terrain.WATER_Y + 1.0 or land.thaw_at(px, pz, h) < 0.6:
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
