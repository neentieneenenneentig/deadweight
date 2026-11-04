extends Node3D
## The Department of Unfinished Gravity. Static scenery joins the level's material
## batches. Three dynamic draws add a pendulum, orbital ring and rising paper forms.
## Anything that looks solid is solid (S1): chairs, doors and their steps, arches, the clock, the
## sphere, the portrait frame and the pendulum all collide, on the level's scenery body, which the
## navmesh leaves out. Only the thin orbit ring and the paper forms are visual. No floating text.
## Animation inherits scene-tree pause.
const PORCELAIN = preload("res://assets/dreamscape/porcelain.png")
const SKY = preload("res://assets/dreamscape/afternoon_sky.png")
const PORTRAIT = preload("res://assets/dreamscape/vacant_chair.png")
const FLOOR = preload("res://shaders/dream_floor.gdshader")
const WATER = preload("res://shaders/dream_water.gdshader")

var _level: Node3D
var _time: float = 0.0
var _pendulum: Node3D
var _orbit: MeshInstance3D
var _papers: MultiMesh
var _paper_origins: PackedVector3Array = []
var _water: ShaderMaterial
const PAPER_COUNT: int = 32

static func water_material(color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = WATER
	material.set_shader_parameter("tint", color)
	return material

static func floor_material(color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = FLOOR
	material.set_shader_parameter("porcelain", PORCELAIN)
	material.set_shader_parameter("chalk", color)
	material.set_shader_parameter("ink", Color("526264"))
	return material

func dress(level: Node3D) -> void:
	_level = level
	if (level.get("info") as Dictionary).is_empty():
		set_process(false)
		return # Bare test arenas do not need scenery.
	# Materials are cached by zone; animate a level-local water instance so previews
	# or multiple live levels cannot fight over one shader's clock.
	var materials: Dictionary = level.get("_materials")
	materials = materials.duplicate()
	_water = (materials["water"] as ShaderMaterial).duplicate() as ShaderMaterial
	materials["water"] = _water
	level.set("_materials", materials)
	var bounds: AABB = _play_bounds()
	var left: float = bounds.position.x - 14.0
	var right: float = bounds.end.x + 14.0
	var middle: float = bounds.get_center().z
	# An empty seat is the department's highest authority.
	_chair(Vector3(left, 9, middle + 10), 7.0, 0.24)
	_chair(Vector3(right + 4, 28, middle - 43), 4.2, -0.3, true)
	# A clock with twelve identical marks and a pendulum that has nowhere to fall.
	_clock(Vector3(right, 29, middle + 12), 8.0)
	# Door frames visibly open onto the same sky on both sides.
	for i in range(3):
		_door(Vector3(left + 12 + float(i) * 17, 26 + float(i) * 5, middle - 25 - float(i) * 12), 4.8, -0.15 + float(i) * 0.14)
	# Repeated, purposeless architecture frames the horizon without blocking routes.
	for side: float in [left - 15, right + 15]:
		for i in range(4):
			_arch(Vector3(side, -2, middle + 46 - float(i) * 25), 7.0, 0.0)
	_sphere(Vector3(left - 3, 48, middle - 74), Vector3(14, 14, 14), "light_concrete")
	_orbit = _moving_ring(Vector3(left - 3, 48, middle - 74), 17.5)
	_portrait(Vector3(right - 2, 19, middle - 23), 15.0, -0.3)
	_make_papers(bounds)
	_animate(0.0)

func _process(delta: float) -> void:
	_time += delta
	_animate(_time)

func _animate(seconds: float) -> void:
	if _pendulum == null:
		return
	_pendulum.rotation.z = sin(seconds * 0.48) * 0.32
	_orbit.rotation = Vector3(0.4 + sin(seconds * 0.13) * 0.12, seconds * 0.025, -0.3)
	_water.set_shader_parameter("dream_time", seconds)
	# A single MultiMesh, fixed storage and deterministic positions. No particles
	# spawn, no tweens accumulate, and nothing drifts out of its declared bounds.
	for i in range(_paper_origins.size()):
		var phase: float = float(i) * 2.39996
		var at: Vector3 = _paper_origins[i]
		at.y = 3.0 + fposmod(at.y + seconds * 0.65, 26.0)
		at.x += sin(seconds * 0.3 + phase) * 0.7
		var basis: Basis = Basis.from_euler(Vector3(sin(seconds * 0.6 + phase) * 0.4, phase + seconds * 0.12, 0.2))
		_papers.set_instance_transform(i, Transform3D(basis, at))

func _moving_ring(at: Vector3, radius: float) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - 0.16
	mesh.outer_radius = radius + 0.16
	mesh.rings = 48
	mesh.ring_segments = 8
	return _moving_mesh(mesh, at, "yellow")

func _moving_mesh(mesh: Mesh, at: Vector3, key: String) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.position = at
	view.material_override = (_level.get("_materials") as Dictionary)[key]
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(view)
	return view

func _make_papers(bounds: AABB) -> void:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Two creased halves, like blank forms folded for an office nobody can find.
	for side: float in [-1.0, 1.0]:
		mesh.set_normal(Vector3(-side * 0.2, 1, 0).normalized())
		for point: Vector3 in [Vector3(0, 0.12, -0.45), Vector3(side * 0.34, 0, -0.45), Vector3(side * 0.34, 0, 0.45), Vector3(0, 0.12, -0.45), Vector3(side * 0.34, 0, 0.45), Vector3(0, 0.12, 0.45)]:
			mesh.add_vertex(point)
	_papers = MultiMesh.new()
	_papers.transform_format = MultiMesh.TRANSFORM_3D
	_papers.mesh = mesh.commit()
	_papers.instance_count = PAPER_COUNT
	var view := MultiMeshInstance3D.new()
	view.name = "UnfiledForms"
	view.multimesh = _papers
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("eee0c5")
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 1.0
	view.material_override = material
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Process animation has no physics source; do not interpolate the MultiMesh.
	view.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(view)
	for i in range(PAPER_COUNT):
		var fraction: float = float(i) / float(PAPER_COUNT)
		var x: float = bounds.position.x + 3.0 if i % 2 == 0 else bounds.end.x - 3.0
		_paper_origins.append(Vector3(x, fposmod(float(i) * 7.73, 26.0), lerpf(bounds.position.z, bounds.end.z, fraction)))
	_papers.custom_aabb = AABB(Vector3(bounds.position.x, 2, bounds.position.z - 1), Vector3(bounds.size.x, 29, bounds.size.z + 2))

func _play_bounds() -> AABB:
	var bounds := AABB(Vector3(-20, 0, -80), Vector3(40, 1, 100))
	var first: bool = true
	var body: StaticBody3D = _level.get("_body")
	for child: Node in body.get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			var size: Vector3 = child.shape.size
			var box: AABB = child.transform * AABB(-size * 0.5, size)
			bounds = box if first else bounds.merge(box)
			first = false
	return bounds

func _box(at: Vector3, size: Vector3, material: String, rotation: Vector3 = Vector3.ZERO) -> void:
	_level.call("scenery_box", Transform3D(Basis.from_euler(rotation), at), size, material)

func _part(frame: Transform3D, at: Vector3, size: Vector3, material: String) -> void:
	_level.call("scenery_box", frame * Transform3D(Basis.IDENTITY, at), size, material)

## A round sphere collides as a sphere; a flat disc (one short axis, the clock face) as a cylinder
## lying along z.
func _sphere(at: Vector3, size: Vector3, material: String) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 24
	mesh.rings = 12
	_level.call("_stage_mesh", mesh, Transform3D(Basis.from_scale(size), at), material)
	if is_equal_approx(size.x, size.y) and is_equal_approx(size.y, size.z):
		var ball := SphereShape3D.new()
		ball.radius = size.x * 0.5
		_level.call("add_scenery_collider", ball, Transform3D(Basis.IDENTITY, at))
	else:
		var disc := CylinderShape3D.new()
		disc.radius = size.x * 0.5
		disc.height = size.z
		_level.call("add_scenery_collider", disc, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), at))

func _ring(at: Vector3, radius: float, thickness: float, material: String, rotation: Vector3 = Vector3.ZERO) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - thickness
	mesh.outer_radius = radius + thickness
	mesh.rings = 48
	mesh.ring_segments = 8
	_level.call("_stage_mesh", mesh, Transform3D(Basis.from_euler(rotation), at), material)

func _chair(at: Vector3, size: float, yaw: float, inverted: bool = false) -> void:
	var rotation := Vector3(0, yaw, PI if inverted else 0.0)
	var frame := Transform3D(Basis.from_euler(rotation).scaled(Vector3.ONE * size), at)
	_part(frame, Vector3(0, 1.3, 0), Vector3(1.8, 0.18, 1.6), "rust")
	for x: float in [-0.72, 0.72]:
		for z: float in [-0.62, 0.62]:
			_part(frame, Vector3(x, 0.6, z), Vector3(0.15, 1.3, 0.15), "rust")
		_part(frame, Vector3(x, 2.3, -0.62), Vector3(0.15, 2.0, 0.15), "rust")
	_part(frame, Vector3(0, 3.2, -0.62), Vector3(1.6, 0.23, 0.2), "yellow")
	for x: float in [-0.35, 0.0, 0.35]:
		_part(frame, Vector3(x, 2.4, -0.62), Vector3(0.08, 1.45, 0.1), "rust")

func _arch(at: Vector3, radius: float, yaw: float) -> void:
	var frame := Transform3D(Basis(Vector3.UP, yaw), at)
	for x: float in [-radius, radius]:
		_part(frame, Vector3(x, radius, 0), Vector3(1.7, radius * 2, 2.8), "light_concrete")
	for i in range(18):
		var angle: float = (float(i) + 0.5) * PI / 18.0
		var pos := Vector3(cos(angle) * radius, radius * 2 + sin(angle) * radius, 0)
		var transform := Transform3D(Basis(Vector3.BACK, angle - PI * 0.5), pos)
		_level.call("scenery_box", frame * transform, Vector3(radius * PI / 18.0 + 0.08, 1.7, 2.8), "light_concrete")

func _door(at: Vector3, size: float, yaw: float) -> void:
	var frame := Transform3D(Basis(Vector3.UP, yaw), at)
	for x: float in [-size * 0.5, size * 0.5]:
		_part(frame, Vector3(x, size, 0), Vector3(0.38, size * 2, 0.5), "rust")
	_part(frame, Vector3(0, size * 2, 0), Vector3(size + 0.38, 0.4, 0.5), "rust")
	_part(frame, Vector3(0, 0, 0), Vector3(size + 1, 0.3, 2), "light_concrete")
	# An open leaf, hinged on the left. Its offset makes the empty threshold legible.
	var hinge: Transform3D = frame * Transform3D(Basis(Vector3.UP, -1.05), Vector3(-size * 0.5, 0, 0))
	_part(hinge, Vector3(size * 0.5, size, 0), Vector3(size * 0.9, size * 1.88, 0.18), "dark")
	_part(hinge, Vector3(size * 0.82, size, 0.18), Vector3(0.18, 0.18, 0.2), "yellow")
	for i in range(5):
		_part(frame, Vector3(0, -0.5 - float(i) * 0.65, float(i) * 1.1 + 1), Vector3(size, 0.25, 1.0), "light_concrete")

func _clock(at: Vector3, radius: float) -> void:
	_sphere(at, Vector3(radius * 2, radius * 2, 1.0), "light_concrete")
	_ring(at + Vector3(0, 0, 0.35), radius, 0.22, "yellow", Vector3(PI * 0.5, 0, 0))
	for i in range(12):
		var angle: float = float(i) * TAU / 12.0
		_box(at + Vector3(sin(angle), cos(angle), 0) * radius * 0.82 + Vector3(0, 0, 0.6), Vector3(0.17, 0.7, 0.1), "dark", Vector3(0, 0, -angle))
	# Both hands point down: an instrument insisting gravity is the time.
	_box(at + Vector3(0, -radius * 0.28, 0.7), Vector3(0.2, radius * 0.65, 0.15), "dark")
	_pendulum = Node3D.new()
	_pendulum.name = "UnfinishedPendulum"
	_pendulum.position = at + Vector3(0, -radius * 0.9, 0)
	add_child(_pendulum)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 20
	ball.rings = 10
	surface.append_from(ball, 0, Transform3D(Basis.IDENTITY, Vector3(0, -radius * 0.75, 0)))
	var stem := BoxMesh.new()
	stem.size = Vector3(0.08, radius * 0.75, 0.08)
	surface.append_from(stem, 0, Transform3D(Basis.IDENTITY, Vector3(0, -radius * 0.375, 0)))
	var moving: MeshInstance3D = _moving_mesh(surface.commit(), Vector3.ZERO, "yellow")
	moving.reparent(_pendulum, false)
	# The ball is solid too. The body rides the swing; the level keeps it out of the navmesh.
	var body := StaticBody3D.new()
	body.name = "PendulumBall"
	var ball_shape := SphereShape3D.new()
	ball_shape.radius = 1.0
	var collision := CollisionShape3D.new()
	collision.shape = ball_shape
	collision.position = Vector3(0, -radius * 0.75, 0)
	body.add_child(collision)
	_pendulum.add_child(body)
	_level.call("register_scenery_body", body)

func _portrait(at: Vector3, size: float, yaw: float) -> void:
	var frame := Transform3D(Basis(Vector3.UP, yaw), at)
	_part(frame, Vector3(0, 0, -0.3), Vector3(size + 0.7, size + 0.7, 0.4), "yellow")
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	var view := MeshInstance3D.new()
	view.name = "VacantChairPortrait"
	view.mesh = quad
	view.transform = frame
	var material := StandardMaterial3D.new()
	material.albedo_texture = PORTRAIT
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	view.material_override = material
	_level.add_child(view)
