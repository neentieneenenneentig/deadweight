extends CharacterBody3D

signal fired(origin: Vector3, end: Vector3)
signal alerted(text: String)

var target: Node3D
var kind: String = "hound"
var active: bool = false
var health: float = 70.0
var _dead: bool = false
var _home: Vector3
var _clock: float = 0.0
var _attack_cooldown: float = 0.0
var _aim_time: float = 0.0
var _last_seen: Vector3
var _memory: float = 0.0
var _telegraph: MeshInstance3D
var _eye_material: StandardMaterial3D
var _visual: Node3D
var _legs: Array[Node3D] = []
var _alert_sent: bool = false
var _hurt_flash: float = 0.0
var _body_material: StandardMaterial3D
var _ray_clock: float = 0.0
var _visible_target: bool = false
var _locked_aim: Vector3


func setup(player: Node3D, enemy_kind: String, location: Vector3) -> void:
	target = player
	kind = enemy_kind
	position = location
	_home = location
	_last_seen = location
	health = 70.0 if kind == "hound" else 105.0
	collision_layer = 8
	collision_mask = 1
	add_to_group("enemies")
	_build_body()


func set_active(value: bool) -> void:
	active = value
	if not value:
		velocity = Vector3.ZERO
		_aim_time = 0.0
		if is_instance_valid(_telegraph):
			_telegraph.visible = false


func _build_body() -> void:
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.46 if kind == "hound" else 0.65
	shape.height = 1.15 if kind == "hound" else 2.3
	collision.shape = shape
	collision.position.y = 0.62 if kind == "hound" else 1.15
	add_child(collision)
	_visual = Node3D.new()
	add_child(_visual)
	_body_material = _material(Color("252f33"))
	var armor := _material(Color("53605b"))
	var joints := _material(Color("101b20"))
	_eye_material = _material(Color("f7533c"), true)
	if kind == "hound":
		_mesh_box(Vector3(0, 0.7, 0), Vector3(0.7, 0.55, 1.35), _body_material)
		_mesh_box(Vector3(0, 0.9, 0.14), Vector3(0.76, 0.25, 0.86), armor)
		_mesh_box(Vector3(0, 0.77, -0.86), Vector3(0.52, 0.4, 0.6), _body_material)
		_mesh_box(Vector3(0, 0.68, -1.18), Vector3(0.39, 0.18, 0.16), joints)
		_mesh_box(Vector3(0, 0.87, -1.17), Vector3(0.38, 0.07, 0.035), _eye_material)
		for side in [-1.0, 1.0]:
			_mesh_box(Vector3(side * 0.2, 1.1, -0.79), Vector3(0.1, 0.25, 0.14), armor)
			for front in [-0.46, 0.46]:
				var leg := Node3D.new()
				leg.position = Vector3(side * 0.32, 0.57, front)
				_visual.add_child(leg)
				var upper := MeshInstance3D.new()
				var upper_mesh := BoxMesh.new()
				upper_mesh.size = Vector3(0.16, 0.45, 0.2)
				upper.mesh = upper_mesh
				upper.material_override = joints
				upper.position.y = -0.21
				leg.add_child(upper)
				_legs.append(leg)
		_mesh_box(Vector3(0, 0.91, 0.89), Vector3(0.12, 0.13, 0.65), joints).rotation.x = -0.45
	else:
		_mesh_box(Vector3(0, 0.23, 0), Vector3(1.45, 0.3, 1.45), joints)
		_mesh_box(Vector3(0, 0.95, 0), Vector3(0.3, 1.25, 0.3), armor)
		_mesh_box(Vector3(0, 1.62, 0), Vector3(1.13, 0.72, 0.8), _body_material)
		_mesh_box(Vector3(0, 1.65, -0.78), Vector3(0.24, 0.24, 1.25), joints)
		_mesh_box(Vector3(0, 1.91, -0.42), Vector3(0.72, 0.09, 0.06), _eye_material)
		_mesh_box(Vector3(-0.72, 1.5, 0.1), Vector3(0.28, 0.68, 0.48), armor)
		_mesh_box(Vector3(0.72, 1.5, 0.1), Vector3(0.28, 0.68, 0.48), armor)
		var line_mesh := CylinderMesh.new()
		line_mesh.top_radius = 0.018
		line_mesh.bottom_radius = 0.018
		line_mesh.height = 1.0
		line_mesh.radial_segments = 4
		_telegraph = MeshInstance3D.new()
		_telegraph.mesh = line_mesh
		_telegraph.material_override = _material(Color(1.0, 0.17, 0.09, 0.6), true)
		_telegraph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_telegraph.visible = false
		add_child(_telegraph)


func _physics_process(delta: float) -> void:
	if _dead or not active or not is_instance_valid(target):
		return
	_clock += delta
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_hurt_flash = maxf(0.0, _hurt_flash - delta)
	_body_material.albedo_color = Color("b44d37") if _hurt_flash > 0.0 else Color("252f33")
	var offset: Vector3 = target.global_position - global_position
	var distance: float = offset.length()
	_ray_clock -= delta
	if _ray_clock <= 0.0:
		_ray_clock = 0.12
		_visible_target = distance < (37.0 if kind == "hound" else 46.0) and _can_see_player()
	if _visible_target:
		_last_seen = target.global_position
		_memory = 5.0
		if not _alert_sent:
			_alert_sent = true
			alerted.emit("HOUND TRACKING" if kind == "hound" else "SENTRY ACQUIRING — FIND COVER")
	else:
		_memory = maxf(0.0, _memory - delta)
		if _memory <= 0.0:
			_alert_sent = false
	if kind == "hound":
		_tick_hound(delta, distance)
	else:
		_tick_sentry(delta)


func _tick_hound(delta: float, distance: float) -> void:
	var destination: Vector3 = _last_seen if _memory > 0.0 else _home + Vector3(sin(_clock * 0.28) * 4.0, 0, cos(_clock * 0.28) * 4.0)
	var direction: Vector3 = destination - global_position
	direction.y = 0.0
	var desired: Vector3 = Vector3.ZERO
	if direction.length() > 0.5:
		direction = direction.normalized()
		# Probe ahead and slide around crates rather than running through cover.
		var ray_start: Vector3 = global_position + Vector3.UP * 0.7
		var query := PhysicsRayQueryParameters3D.create(ray_start, ray_start + direction * 2.5, 1)
		var obstacle: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if not obstacle.is_empty():
			var normal: Vector3 = obstacle["normal"]
			var tangent: Vector3 = direction.slide(normal).normalized()
			if tangent.length_squared() < 0.1:
				tangent = Vector3(-normal.z, 0, normal.x)
			if tangent.dot(direction) < -0.1:
				tangent = -tangent
			direction = (direction * 0.15 + tangent).normalized()
		desired = direction * (5.1 if _memory > 0.0 else 1.8)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-direction.x, -direction.z), delta * 9.0)
	velocity.x = move_toward(velocity.x, desired.x, delta * 15.0)
	velocity.z = move_toward(velocity.z, desired.z, delta * 15.0)
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = -0.5
	move_and_slide()
	var walking: float = Vector2(velocity.x, velocity.z).length()
	for i in range(_legs.size()):
		_legs[i].rotation.x = sin(_clock * 15.0 + float(i % 2) * PI) * minf(walking * 0.12, 0.6)
	_visual.position.y = absf(sin(_clock * 15.0)) * minf(walking * 0.012, 0.05)
	if distance < 1.9 and _visible_target and _attack_cooldown <= 0.0:
		_attack_cooldown = 1.1
		target.call("take_damage", 12.0)
		if target is RigidBody3D:
			var push: Vector3 = (target.global_position - global_position).normalized() * 110.0
			(target as RigidBody3D).apply_central_impulse(push + Vector3.UP * 45.0)
		alerted.emit("HOUND ATTACK — GET AIRBORNE")


func _tick_sentry(delta: float) -> void:
	if not _visible_target or _attack_cooldown > 0.0:
		_aim_time = maxf(0.0, _aim_time - delta * 2.0)
		_telegraph.visible = false
		if _memory <= 0.0:
			_visual.rotation.y = sin(_clock * 0.4) * 0.8
		return
	_aim_time += delta
	var origin: Vector3 = global_position + Vector3(0, 1.68, 0)
	# The last fraction of the wind-up commits the aim: a dodge can evade the shot.
	if _aim_time < 1.22:
		_locked_aim = target.global_position + Vector3.UP * 0.2
	var aim: Vector3 = _locked_aim - origin
	_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-aim.x, -aim.z), delta * 5.0)
	_telegraph.visible = true
	_telegraph.global_position = origin + aim * 0.5
	_telegraph.quaternion = Quaternion(Vector3.UP, aim.normalized())
	_telegraph.scale = Vector3(1, aim.length(), 1)
	_eye_material.emission_energy_multiplier = 1.0 + _aim_time * 2.0
	if _aim_time >= 1.6:
		_aim_time = 0.0
		_attack_cooldown = 1.15
		_telegraph.visible = false
		var end: Vector3 = origin + aim.normalized() * 65.0
		var query := PhysicsRayQueryParameters3D.create(origin, end, 1 | 2 | 4)
		query.exclude = [get_rid()]
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			end = hit["position"]
			if hit["collider"] == target:
				target.call("take_damage", 16.0)
		fired.emit(origin, end)


func _can_see_player() -> bool:
	var origin: Vector3 = global_position + Vector3.UP * (0.8 if kind == "hound" else 1.68)
	var end: Vector3 = target.global_position + Vector3.UP * 0.2
	var query := PhysicsRayQueryParameters3D.create(origin, end, 1 | 2)
	query.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit["collider"] == target


func take_damage(amount: float) -> void:
	if _dead or amount <= 0.0:
		return
	health -= amount
	_hurt_flash = 0.16
	if is_instance_valid(target):
		_last_seen = target.global_position
		_memory = 8.0
	if health <= 0.0:
		_dead = true
		active = false
		collision_layer = 0
		collision_mask = 0
		remove_from_group("enemies")
		if is_instance_valid(_telegraph):
			_telegraph.visible = false
		_eye_material.emission_enabled = false
		_eye_material.albedo_color = Color("101a1c")
		var tween := create_tween()
		tween.tween_property(_visual, "rotation:z", 1.35, 0.35)
		tween.parallel().tween_property(_visual, "position:y", -0.2, 0.35)
		tween.tween_interval(12.0)
		tween.tween_callback(queue_free)


func _mesh_box(location: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = material
	instance.position = location
	_visual.add_child(instance)
	return instance


func _material(color: Color, glow: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.75
	if glow:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.4
		if color.a < 1.0:
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
