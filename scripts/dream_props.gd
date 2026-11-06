extends RefCounted
## Shared mesh for a portable office: brass suitcase, handle and a sealed piece of sky.
## Three surfaces replace the old box and two straps at the same draw cost.
static var _case: ArrayMesh
static var _sky: StandardMaterial3D

static func case_mesh() -> ArrayMesh:
	if _case != null:
		return _case
	_case = ArrayMesh.new()
	var brass := SurfaceTool.new()
	brass.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: float in [-1.0, 1.0]:
		_box(brass, Vector3(side * 0.55, 0, 0), Vector3(0.1, 0.62, 0.68))
		_box(brass, Vector3(0, side * 0.27, 0), Vector3(1.15, 0.08, 0.68))
		for x: float in [-0.43, 0.43]:
			_box(brass, Vector3(x, -0.34, side * 0.23), Vector3(0.13, 0.12, 0.13))
	_box(brass, Vector3(0, -0.22, 0.37), Vector3(0.17, 0.14, 0.08))
	brass.commit(_case)
	var leather := SurfaceTool.new()
	leather.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(leather, Vector3.ZERO, Vector3(1.08, 0.48, 0.62))
	for side: float in [-1.0, 1.0]:
		_box(leather, Vector3(side * 0.23, 0.37, 0), Vector3(0.065, 0.25, 0.1))
	_box(leather, Vector3(0, 0.48, 0), Vector3(0.5, 0.065, 0.1))
	leather.commit(_case)
	var window := SurfaceTool.new()
	window.begin(Mesh.PRIMITIVE_TRIANGLES)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.96, 0.36)
	window.append_from(quad, 0, Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.32)))
	window.commit(_case)
	return _case

static func sky_material() -> StandardMaterial3D:
	if _sky == null:
		_sky = StandardMaterial3D.new()
		_sky.albedo_texture = preload("res://assets/dreamscape/nightmare_sky.png")
		_sky.uv1_scale = Vector3(0.42, 0.28, 1)
		_sky.uv1_offset = Vector3(0.1, 0.22, 0)
		_sky.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_sky.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return _sky

static func _box(surface: SurfaceTool, at: Vector3, size: Vector3) -> void:
	var shape := BoxMesh.new()
	shape.size = size
	surface.append_from(shape, 0, Transform3D(Basis.IDENTITY, at))

static var _princess: ArrayMesh

## Princess Capybara in her hot tub, vertex coloured, in tub space: the tub floor is y 0, the water
## line is y 1.08 and she faces +z. A barrel body low in the water, the long square-nosed head
## resting above it, sleepy half-lidded eyes, small round ears, a towel turban and a gold crown
## with a red stone. About 1.9 m wide and 2.9 m tall at scale 1 (the tub shows her at 1.2, paws on
## the water); the level gives her box colliders.
static func princess_mesh() -> ArrayMesh:
	if _princess != null:
		return _princess
	var fur := Color("a9896c")
	var fur_light := Color("bb9b7a")
	var muzzle := Color("7a5a45")
	var dark := Color("231b18")
	var towel := Color("f1efe6")
	var stripe := Color("6f9fae")
	var gold := Color("e2b33c")
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Body: a wide barrel, its back just out of the water.
	_painted(tool, _ball(1.0), Transform3D(Basis.from_scale(Vector3(0.95, 0.72, 1.2)), Vector3(0, 0.95, -0.35)), fur)
	# Shoulders and neck rise toward the head.
	_painted(tool, _ball(0.7), Transform3D(Basis.from_scale(Vector3(1.05, 1.0, 0.9)), Vector3(0, 1.35, 0.3)), fur)
	# Head: long and box-like, the nose tipped a little down.
	var head := Basis(Vector3.RIGHT, 0.12).scaled(Vector3(0.82, 0.86, 1.35))
	_painted(tool, _ball(0.55), Transform3D(head, Vector3(0, 1.95, 0.75)), fur_light)
	# The broad, blunt muzzle and its two nostrils.
	_painted(tool, _ball(0.36), Transform3D(Basis.from_scale(Vector3(1.15, 0.85, 0.85)), Vector3(0, 1.8, 1.35)), muzzle)
	for side: float in [-1.0, 1.0]:
		_painted(tool, _ball(0.04), Transform3D(Basis.from_scale(Vector3(1.0, 0.6, 1.0)), Vector3(side * 0.15, 1.92, 1.62)), dark)
		# Sleepy eyes: a dark eye under a fur lid that covers its top half.
		_painted(tool, _ball(0.09), Transform3D(Basis.IDENTITY, Vector3(side * 0.39, 2.12, 1.02)), dark)
		_painted(tool, _ball(0.1), Transform3D(Basis.from_scale(Vector3(1.0, 0.45, 1.0)), Vector3(side * 0.4, 2.19, 1.02)), fur_light)
		# Small round ears, out from under the towel.
		_painted(tool, _ball(0.14), Transform3D(Basis.from_scale(Vector3(0.6, 1.0, 1.0)), Vector3(side * 0.45, 2.3, 0.45)), muzzle)
		# Front paws on the water, either side of the chin.
		_painted(tool, _ball(0.17), Transform3D(Basis.from_scale(Vector3(1.0, 0.55, 1.4)), Vector3(side * 0.38, 0.95, 1.05)), muzzle)
	# Towel turban: two folded rolls with a blue stripe, then the crown on top.
	_painted(tool, _ball(0.42), Transform3D(Basis.from_scale(Vector3(1.0, 0.45, 1.05)), Vector3(0, 2.42, 0.5)), towel)
	_painted(tool, _ball(0.33), Transform3D(Basis.from_scale(Vector3(1.0, 0.5, 1.0)), Vector3(0, 2.56, 0.48)), towel)
	var band := CylinderMesh.new()
	band.top_radius = 0.38
	band.bottom_radius = 0.4
	band.height = 0.05
	band.radial_segments = 14
	_painted(tool, band, Transform3D(Basis.IDENTITY, Vector3(0, 2.45, 0.5)), stripe)
	var ring := CylinderMesh.new()
	ring.top_radius = 0.24
	ring.bottom_radius = 0.22
	ring.height = 0.12
	ring.radial_segments = 12
	_painted(tool, ring, Transform3D(Basis.IDENTITY, Vector3(0, 2.72, 0.48)), gold)
	var point := CylinderMesh.new()
	point.top_radius = 0.0
	point.bottom_radius = 0.07
	point.height = 0.2
	point.radial_segments = 6
	for k in range(5):
		var angle: float = float(k) * TAU / 5.0 + PI * 0.5
		_painted(tool, point, Transform3D(Basis.IDENTITY, Vector3(cos(angle) * 0.21, 2.86, 0.48 + sin(angle) * 0.21)), gold)
	_painted(tool, _ball(0.06), Transform3D(Basis.IDENTITY, Vector3(0, 2.72, 0.72)), Color("c8243a"))
	_princess = tool.commit()
	return _princess


## Pickup models for absurd objectives (W4), vertex coloured, centred on the floor point's axis:
## "duck" (a rubber duck), "towel" (a folded striped towel), "firewood" (a bundle of logs),
## "salts" (a jar of pink bath salts), "sponge" (a sea sponge, holes and all), "yuzu" (a knobbly
## citrus with a leaf), "yuzu_gold" (the same, gilded), "duckling" (a small rubber duck with a tuft),
## "duckling_gold" (the same, gilded).
static var _looks: Dictionary = {}

static func pickup_mesh(look: String) -> ArrayMesh:
	if _looks.has(look):
		return _looks[look]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	match look:
		"duck":
			_painted(tool, _ball(0.36), Transform3D(Basis.from_scale(Vector3(1.0, 0.8, 1.25)), Vector3(0, 0, 0)), Color("f2c743"))
			_painted(tool, _ball(0.22), Transform3D(Basis.IDENTITY, Vector3(0, 0.34, 0.2)), Color("f2c743"))
			_painted(tool, _block(Vector3(0.16, 0.06, 0.16)), Transform3D(Basis.IDENTITY, Vector3(0, 0.31, 0.44)), Color("ed9647"))
			for side: float in [-1.0, 1.0]:
				_painted(tool, _ball(0.035), Transform3D(Basis.IDENTITY, Vector3(side * 0.1, 0.42, 0.38)), Color("1d1d22"))
		"duckling", "duckling_gold":
			var body: Color = Color("f6dc6a") if look == "duckling" else Color("ffc928")
			var beak: Color = Color("ed9647") if look == "duckling" else Color("f08a1c")
			_painted(tool, _ball(0.22), Transform3D(Basis.from_scale(Vector3(1.0, 0.8, 1.25)), Vector3(0, -0.06, 0)), body)
			_painted(tool, _ball(0.15), Transform3D(Basis.IDENTITY, Vector3(0, 0.17, 0.12)), body)
			_painted(tool, _block(Vector3(0.11, 0.04, 0.11)), Transform3D(Basis.IDENTITY, Vector3(0, 0.15, 0.29)), beak)
			_painted(tool, _block(Vector3(0.03, 0.09, 0.03)), Transform3D(Basis(Vector3.RIGHT, -0.4), Vector3(0, 0.33, 0.1)), body)
			for side: float in [-1.0, 1.0]:
				_painted(tool, _ball(0.025), Transform3D(Basis.IDENTITY, Vector3(side * 0.07, 0.22, 0.24)), Color("1d1d22"))
		"towel":
			for k in range(4):
				var stripe: Color = Color("e3e8e5") if k % 2 == 0 else Color("779ea9")
				_painted(tool, _block(Vector3(0.8, 0.08, 0.5)), Transform3D(Basis.IDENTITY, Vector3(0, -0.15 + float(k) * 0.085, 0)), stripe)
		"salts":
			# A squat glass jar, pink crystals inside, a cork lid and a paper label band.
			var jar := CylinderMesh.new()
			jar.top_radius = 0.24
			jar.bottom_radius = 0.27
			jar.height = 0.5
			jar.radial_segments = 12
			_painted(tool, jar, Transform3D(Basis.IDENTITY, Vector3(0, -0.05, 0)), Color("bcd9dd"))
			var crystals := CylinderMesh.new()
			crystals.top_radius = 0.255
			crystals.bottom_radius = 0.275
			crystals.height = 0.34
			crystals.radial_segments = 12
			_painted(tool, crystals, Transform3D(Basis.IDENTITY, Vector3(0, -0.12, 0)), Color("f08fb4"))
			var cork := CylinderMesh.new()
			cork.top_radius = 0.17
			cork.bottom_radius = 0.2
			cork.height = 0.12
			cork.radial_segments = 10
			_painted(tool, cork, Transform3D(Basis.IDENTITY, Vector3(0, 0.26, 0)), Color("b58a5e"))
			var band := CylinderMesh.new()
			band.top_radius = 0.28
			band.bottom_radius = 0.28
			band.height = 0.1
			band.radial_segments = 12
			_painted(tool, band, Transform3D(Basis.IDENTITY, Vector3(0, 0.02, 0)), Color("f4eedd"))
		"sponge":
			_painted(tool, _ball(0.34), Transform3D(Basis.from_scale(Vector3(1.25, 0.8, 1.0)), Vector3.ZERO), Color("e3b850"))
			for k in range(7):
				var angle: float = float(k) * 2.4
				var hole := Vector3(cos(angle) * 0.36, sin(float(k) * 1.7) * 0.16, sin(angle) * 0.29)
				_painted(tool, _ball(0.06), Transform3D(Basis.IDENTITY, hole), Color("8f6a2a"))
		"yuzu", "yuzu_gold":
			var peel: Color = Color("f0b62f") if look == "yuzu" else Color("ffd24a")
			var dimple: Color = Color("e09a1f") if look == "yuzu" else Color("f2b31d")
			_painted(tool, _ball(0.3), Transform3D(Basis.from_scale(Vector3(1.0, 0.86, 1.0)), Vector3.ZERO), peel)
			# The bumpy rind: a few low knobs around the middle.
			for k in range(6):
				var angle: float = float(k) * TAU / 6.0 + 0.3
				_painted(tool, _ball(0.09), Transform3D(Basis.IDENTITY, Vector3(cos(angle) * 0.27, sin(float(k) * 2.1) * 0.08, sin(angle) * 0.27)), dimple)
			_painted(tool, _block(Vector3(0.05, 0.1, 0.05)), Transform3D(Basis.IDENTITY, Vector3(0, 0.28, 0)), Color("6b5236"))
			_painted(tool, _ball(0.12), Transform3D(Basis(Vector3.FORWARD, 0.5).scaled(Vector3(1.6, 0.35, 0.8)), Vector3(0.13, 0.31, 0)), Color("5f8a45"))
		_:
			# Two logs below, one on top, tied with a red band.
			for at: Vector3 in [Vector3(-0.14, -0.1, 0), Vector3(0.14, -0.1, 0), Vector3(0, 0.12, 0)]:
				var log_mesh := CylinderMesh.new()
				log_mesh.top_radius = 0.13
				log_mesh.bottom_radius = 0.13
				log_mesh.height = 0.8
				log_mesh.radial_segments = 8
				_painted(tool, log_mesh, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), at), Color("735343"))
			_painted(tool, _block(Vector3(0.5, 0.04, 0.06)), Transform3D(Basis.IDENTITY, Vector3(0, 0.0, 0.0)), Color("d9403a"))
	_looks[look] = tool.commit()
	return _looks[look]

static func _ball(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	return mesh

static func _block(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh

static func _painted(tool: SurfaceTool, mesh: PrimitiveMesh, placement: Transform3D, color: Color) -> void:
	var arrays: Array = mesh.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var normal_basis: Basis = placement.basis.inverse().transposed()
	for index: int in indices:
		tool.set_color(color)
		tool.set_normal((normal_basis * normals[index]).normalized())
		tool.add_vertex(placement * vertices[index])
