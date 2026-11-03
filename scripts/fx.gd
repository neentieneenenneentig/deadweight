extends RefCounted
## Shared one-shot visual effects. Static helpers only; every effect frees itself.
## Usage: const FX = preload("res://scripts/fx.gd") then FX.burst(parent, ...).
## All helpers are safe in headless tests (they only create nodes) and accept any
## Node parent that lives in the 3D scene (a level, the tether, an enemy's parent).

const _UNSHADED := BaseMaterial3D.SHADING_MODE_UNSHADED

static var _material_cache: Dictionary = {}


static func glow_material(color: Color, energy: float = 1.6) -> StandardMaterial3D:
	var key: String = "%s/%.2f" % [color.to_html(true), energy]
	if _material_cache.has(key):
		return _material_cache[key]
	var material := StandardMaterial3D.new()
	material.shading_mode = _UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color, 1.0)
	material.emission_energy_multiplier = energy
	material.vertex_color_use_as_albedo = true
	if color.a < 0.999:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material_cache[key] = material
	return material


## Sparks/debris spraying away from a surface normal.
static func burst(parent: Node, position: Vector3, normal: Vector3, color: Color, amount: int = 14, speed: float = 7.0, lifetime: float = 0.45, size: float = 0.06) -> void:
	if not _usable(parent):
		return
	var particles := CPUParticles3D.new()
	particles.one_shot = true
	particles.emitting = false
	particles.amount = maxi(1, amount)
	particles.lifetime = maxf(0.05, lifetime)
	particles.explosiveness = 0.95
	particles.randomness = 0.4
	particles.local_coords = false
	var direction: Vector3 = normal.normalized() if normal.length_squared() > 0.0001 else Vector3.UP
	particles.direction = direction
	particles.spread = 55.0
	particles.initial_velocity_min = speed * 0.45
	particles.initial_velocity_max = speed
	particles.gravity = Vector3(0, -14.0, 0)
	particles.damping_min = 1.0
	particles.damping_max = 3.0
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.2
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * size
	mesh.material = glow_material(color)
	particles.mesh = mesh
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	particles.color_ramp = fade
	parent.add_child(particles)
	particles.global_position = position
	particles.emitting = true
	_free_later(particles, lifetime + 0.3)


## Brief glowing sphere (muzzle flash, impact pop, pickup sparkle).
static func flash(parent: Node, position: Vector3, color: Color, radius: float = 0.25, duration: float = 0.08) -> void:
	if not _usable(parent):
		return
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	node.mesh = mesh
	node.material_override = glow_material(color, 2.2)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	node.global_position = position
	var tween := node.create_tween()
	tween.tween_property(node, "scale", Vector3.ONE * 1.8, duration)
	tween.tween_callback(node.queue_free)


## Expanding flat ring on the ground (landing shockwave, extraction pulse, explosion).
static func ring(parent: Node, position: Vector3, color: Color, radius: float = 1.5, duration: float = 0.4) -> void:
	if not _usable(parent):
		return
	var node := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.82
	mesh.outer_radius = 1.0
	mesh.rings = 24
	mesh.ring_segments = 4
	node.mesh = mesh
	node.material_override = glow_material(Color(color, 0.85), 1.8)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	node.global_position = position
	node.scale = Vector3(0.2, 0.05, 0.2)
	var tween := node.create_tween()
	tween.tween_property(node, "scale", Vector3(radius, 0.05, radius), duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(node, "transparency", 1.0, duration)
	tween.tween_callback(node.queue_free)


## Thin glowing beam between two points (bullet tracer, laser shot).
static func tracer(parent: Node, from: Vector3, to: Vector3, color: Color, width: float = 0.025, duration: float = 0.09) -> void:
	if not _usable(parent):
		return
	var distance: float = from.distance_to(to)
	if distance < 0.01:
		return
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = width
	mesh.bottom_radius = width
	mesh.height = distance
	mesh.radial_segments = 5
	mesh.rings = 1
	node.mesh = mesh
	node.material_override = glow_material(color, 2.4)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	node.global_position = (from + to) * 0.5
	node.quaternion = Quaternion(Vector3.UP, (to - from).normalized())
	var tween := node.create_tween()
	tween.tween_property(node, "transparency", 1.0, duration)
	tween.tween_callback(node.queue_free)


## Larger compound effect: flash + sparks + ring. For enemy deaths and heavy impacts.
static func explosion(parent: Node, position: Vector3, color: Color, scale: float = 1.0) -> void:
	flash(parent, position, color, 0.45 * scale, 0.14)
	burst(parent, position, Vector3.UP, color, int(26 * scale), 9.0 * scale, 0.7, 0.09 * scale)
	ring(parent, position, color, 3.2 * scale, 0.5)


static func _usable(parent: Node) -> bool:
	return is_instance_valid(parent) and parent.is_inside_tree()


## The timer is a child of the node, so it disappears with it when a level is freed early
## (a SceneTreeTimer lambda would log "Lambda capture was freed" in that case).
static func _free_later(node: Node, seconds: float) -> void:
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = maxf(seconds, 0.01)
	node.add_child(timer)
	timer.timeout.connect(node.queue_free)
	timer.start()
