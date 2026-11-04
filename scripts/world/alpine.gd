extends RefCounted
## Snowy surroundings for the compact opening levels. Terrain is real, with an exact collider.
const SKY = preload("res://assets/dreamscape/alpine_sky.png")
const SLATE = preload("res://assets/dreamscape/alpine_slate.png")
const SURFACE = preload("res://shaders/alpine_surface.gdshader")

static func surface_material(color: Color, vertices: bool = false) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SURFACE
	material.set_shader_parameter("slate", SLATE)
	material.set_shader_parameter("tint", color)
	material.set_shader_parameter("vertex_tint", vertices)
	return material

## Unequal chamfers remove the factory-perfect corners of short stone blocks.
## Both the rendered surface and solid hull use these same corner points.
static func block_mesh(size: Vector3) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half: Vector3 = size * 0.5
	var bevel: float = minf(0.18, minf(size.x, minf(size.y, size.z)) * 0.14)
	for axis in range(3):
		var u: int = (axis + 1) % 3
		var v: int = (axis + 2) % 3
		for side: float in [-1.0, 1.0]:
			var points: Array[Vector3] = []
			for corner: Vector2 in [Vector2(-1,-1), Vector2(1,-1), Vector2(1,1), Vector2(-1,1)]:
				var signs := Vector3.ZERO
				signs[axis] = side
				signs[u] = corner.x
				signs[v] = corner.y
				points.append(_corner(signs, axis, half, bevel))
			_block_face(tool, points[0], points[1], points[2])
			_block_face(tool, points[0], points[2], points[3])
	# Twelve chamfered edges, along each of the three axes.
	for along in range(3):
		var u: int = (along + 1) % 3
		var v: int = (along + 2) % 3
		for su: float in [-1.0, 1.0]:
			for sv: float in [-1.0, 1.0]:
				var signs := Vector3.ZERO
				signs[u] = su
				signs[v] = sv
				signs[along] = -1.0
				var a: Vector3 = _corner(signs, u, half, bevel)
				var b: Vector3 = _corner(signs, v, half, bevel)
				signs[along] = 1.0
				var c: Vector3 = _corner(signs, v, half, bevel)
				var d: Vector3 = _corner(signs, u, half, bevel)
				_block_face(tool, a, b, c)
				_block_face(tool, a, c, d)
	for x: float in [-1.0, 1.0]:
		for y: float in [-1.0, 1.0]:
			for z: float in [-1.0, 1.0]:
				var signs := Vector3(x,y,z)
				_block_face(tool, _corner(signs, 0, half, bevel), _corner(signs, 1, half, bevel), _corner(signs, 2, half, bevel))
	return tool.commit()

static func _corner(signs: Vector3, face: int, half: Vector3, bevel: float) -> Vector3:
	var chip: float = bevel * (0.85 + sin(signs.dot(Vector3(2.7, 4.1, 7.3))) * 0.15)
	var point: Vector3 = signs * (half - Vector3.ONE * chip)
	point[face] = signs[face] * half[face]
	return point

static func _block_face(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal: Vector3 = (b-a).cross(c-a).normalized()
	if normal.dot((a+b+c)/3.0) < 0.0:
		var swap: Vector3 = b
		b = c
		c = swap
		normal = -normal
	tool.set_normal(normal)
	tool.add_vertex(a)
	tool.add_vertex(c)
	tool.add_vertex(b)

static func dress(level: Node3D, footprint: Rect2, floor_y: float) -> void:
	if footprint.size == Vector2.ZERO:
		return
	var centre := Vector3(footprint.get_center().x, floor_y - 0.12, footprint.get_center().y)
	var inner: float = footprint.size.length() * 0.5 + 48.0
	var noise := FastNoiseLite.new()
	noise.seed = 7041
	noise.frequency = 0.013
	noise.fractal_octaves = 3
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SECTORS := 96
	const RINGS := 9
	var rows: Array[PackedVector3Array] = []
	for ring in range(RINGS + 1):
		var row := PackedVector3Array()
		var t: float = float(ring) / float(RINGS)
		for spoke in range(SECTORS):
			var angle: float = float(spoke) * TAU / float(SECTORS)
			var distance: float = inner + t * 460.0
			var x: float = cos(angle) * distance
			var z: float = sin(angle) * distance
			var ridge: float = 105.0 + 85.0 * sin(angle * 5.0 + 0.6) + 35.0 * cos(angle * 11.0)
			var h: float = pow(sin(t * PI), 1.6) * maxf(55.0, ridge + noise.get_noise_2d(x, z) * 75.0)
			row.append(centre + Vector3(x, h, z))
		rows.append(row)
	for ring in range(RINGS):
		for spoke in range(SECTORS):
			var next: int = (spoke + 1) % SECTORS
			_triangle(tool, rows[ring][spoke], rows[ring + 1][spoke], rows[ring][next])
			_triangle(tool, rows[ring][next], rows[ring + 1][spoke], rows[ring + 1][next])
	var mesh: ArrayMesh = tool.commit()
	var view := MeshInstance3D.new()
	view.name = "AlpineRidges"
	view.mesh = mesh
	view.material_override = surface_material(Color("dce9ef"), true)
	level.add_child(view)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(mesh.get_faces())
	var body: StaticBody3D = level.call("add_world_body", shape, Transform3D.IDENTITY, "AlpineRidgesBody")
	(level.get("nav_skip_bodies") as Array).append(body)

static func _triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal: Vector3 = (b - a).cross(c - a).normalized()
	if normal.y < 0.0:
		var swap: Vector3 = b
		b = c
		c = swap
		normal = -normal
	var shade: float = 0.95 + sin((a.x + b.z) * 0.047) * 0.05
	tool.set_normal(normal)
	tool.set_color(Color("e3edf3") * shade)
	# Godot front faces use clockwise winding.
	tool.add_vertex(a)
	tool.add_vertex(c)
	tool.add_vertex(b)
