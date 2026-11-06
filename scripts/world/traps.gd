extends Node3D
## The floor is lava (W2). Four kinds of ground danger, built from a level's _design through
## level.traps(), and run here each physics step while the level is active:
##   crack_field  plates (thin ice, old paving) that crack under the player and break after
##                CRACK_TIME, dropping them into whatever is below; a hard landing breaks one at
##                once. Broken plates grow back after REGROW_TIME. A field may be turned (yaw) to
##                pave a diagonal deck, and crack_wave() brings whole fields down in a running wave.
##   mine         a teacup landmine. The player, a hound or the rod's weight within MINE_TRIGGER
##                arms it: it beeps and blinks for MINE_FUSE, then blows. The blast hurts and
##                throws, and it kills hounds, so luring them over a mine works.
##   boulder      a giant marble that waits up a slope until the player enters its trigger box,
##                then rolls. It hurts on contact at speed, flattens hounds, and resets later.
##   marble_run   a hopper of marbles at the top of a built run (H03): every few seconds the next
##                waiting marble is carried to the gate and rolls down. Same hurt and flatten as
##                a boulder; each marble goes back to its slot after its share of the cycle.
##   flood        water that rises from one height to another once start_flood() is called.
##                Under it the player takes FLOOD_DPS and hounds drown.
##   geyser       a vent on a solid stone mound that erupts on a cycle: it hisses for
##                GEYSER_WARN, then the column throws anything over the vent high into the air
##                (the player, the weight) and scalds hounds. A tool, not a damage source.
##   mud_pool     boiling mud on the ground: it hurts the player who wades in and cooks hounds.
##                A zero-damage hazard box keeps it off the hounds' navmesh.
##   starfall     stars that come down out of the sky (H05). A glowing ring marks the ground for
##                STAR_WARN, then the star strikes it: a blast like a mine's. Idle stars land far
##                from the player; once hunt_starfall() is called they aim where the player is
##                running, so the safe place is in the air.
## Everything is solid where it looks solid, and nothing here floats text.

const FX = preload("res://scripts/fx.gd")
const DreamPropsScript = preload("res://scripts/dream_props.gd")

const CRACK_TIME := 1.4              # seconds from first step to the plate giving way
const REGROW_TIME := 10.0
const HARD_LANDING := 9.0            # m/s: a landing this hard breaks the plate at once
const STAND_HEIGHT := 1.8            # the player centre must be this close above a plate to stand on it

const MINE_TRIGGER := 2.2
const MINE_FUSE := 0.7
const MINE_BLAST := 6.5
const MINE_DAMAGE := 55.0            # at the centre, before damage_scale; falls off to 0 at MINE_BLAST
const MINE_THROW := 14.0             # m/s of launch at the centre
const MINE_ENEMY_DAMAGE := 150.0
const MINE_SCAN := 0.1               # seconds between weight and hound scans

const BOULDER_HIT_SPEED := 4.0       # relative m/s before a boulder hurts
const BOULDER_DAMAGE := 40.0
const BOULDER_LIFETIME := 24.0       # seconds rolling before it resets
const BOULDER_MASS := 3000.0
const RUN_LOAD_TIME := 0.6           # seconds a run marble takes from its slot to the gate
const RUN_SETTLE := 1.2              # seconds a run marble must sit still (after 3 s rolling) to go home

const GEYSER_WARN := 1.4            # seconds of hissing before an eruption
const GEYSER_ERUPT := 2.4            # seconds the column stands
const GEYSER_RADIUS := 1.9           # metres from the vent's axis that the column catches
const GEYSER_MOUND := 0.7            # mound height above the floor point
const MUD_DPS := 35.0
const MUD_ENEMY_DPS := 60.0

const STAR_WARN := 1.6               # seconds the ring shows on the ground before the strike
const STAR_BLAST := 5.5
const STAR_DAMAGE := 45.0            # at the centre, before damage_scale; falls off to 0 at STAR_BLAST
const STAR_THROW := 12.0
const STAR_ENEMY_DAMAGE := 400.0
const STAR_DROP := 150.0             # metres from where a star appears to where it strikes
const STAR_LEAD := 1.0               # seconds of the player's ground velocity a hunting star leads by
const STAR_SCATTER := 3.5            # metres of random miss on a hunting star
const STAR_FAR := Vector2(45.0, 160.0)   # an idle star lands this far from the player
const STAR_POOL := 5                 # strikes in the air at once, at most
const SHAFT_LENGTH := 90.0           # the faint shaft of light that marks a strike from afar

const FLOOD_DPS := 30.0
const FLOOD_DROWN := 1.5             # seconds under the flood before a hound drowns

var level: Node3D
var _fields: Array[Dictionary] = []
var _mines: Array[Dictionary] = []
var _boulders: Array[Dictionary] = []
var _runs: Array[Dictionary] = []
var _run_tempo: float = 1.0            # marble runs release this many times as often (set_run_tempo)
var _flood: Dictionary = {}
var _geysers: Array[Dictionary] = []
var _muds: Array[Dictionary] = []
var _starfall: Dictionary = {}
var _strikes: Array[Dictionary] = []
var _star_rng := RandomNumberGenerator.new()
var _clock: float = 0.0
var _tempo: float = 1.0                # geysers erupt this many times as often (set_geyser_tempo)
var _scan_clock: float = 0.0
var _mine_mesh: ArrayMesh
var _mine_armed: StandardMaterial3D
var _mine_idle: StandardMaterial3D
var _connected: bool = false


func setup(owner_level: Node3D) -> void:
	level = owner_level
	name = "Traps"


# --- Builders ------------------------------------------------------------------------------------

## A grid of breakable plates with their tops at center.y. keep(x, z) -> bool (world x, z) may leave
## tiles out (a round lake, say). kind is "ice" or "paving". yaw (degrees) turns the grid about
## center: size.x runs across the turned x axis and size.y along its z axis. Returns the field's
## index, for crack_wave().
func crack_field(center: Vector3, size: Vector2, tile: float, kind: String, keep: Callable = Callable(), yaw: float = 0.0) -> int:
	var columns: int = maxi(1, int(round(size.x / tile)))
	var rows: int = maxi(1, int(round(size.y / tile)))
	var thickness: float = 0.3 if kind == "ice" else 0.5
	var turn := Basis(Vector3.UP, deg_to_rad(yaw))
	var field := {"center": center, "tile": tile, "columns": columns, "rows": rows, "kind": kind, "cells": {}, "thickness": thickness, "turn": turn}
	var shape := BoxShape3D.new()
	shape.size = Vector3(tile - 0.04, thickness, tile - 0.04)
	var origin: Vector2 = -Vector2(columns, rows) * tile * 0.5
	var placements: Array[Transform3D] = []
	for row in range(rows):
		for column in range(columns):
			var local := Vector3(origin.x + (float(column) + 0.5) * tile, -thickness * 0.5, origin.y + (float(row) + 0.5) * tile)
			var at: Vector3 = center + turn * local
			if keep.is_valid() and not bool(keep.call(at.x, at.z)):
				continue
			var body := StaticBody3D.new()
			body.transform = Transform3D(turn, at)
			body.collision_layer = 1
			body.collision_mask = 0
			var collision := CollisionShape3D.new()
			collision.shape = shape
			body.add_child(collision)
			add_child(body)
			var cell := {"body": body, "index": placements.size(), "at": at, "state": 0, "timer": 0.0, "due": -1.0}
			(field["cells"] as Dictionary)[Vector2i(column, row)] = cell
			placements.append(Transform3D(turn * Basis.from_scale(Vector3(tile - 0.08, thickness, tile - 0.08)), at))
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	var box := BoxMesh.new()
	multi.mesh = box
	multi.instance_count = placements.size()
	for i in range(placements.size()):
		multi.set_instance_transform(i, placements[i])
		multi.set_instance_color(i, _plate_color(kind, 0.0))
	var view := MultiMeshInstance3D.new()
	view.name = "CrackField_" + kind
	view.multimesh = multi
	view.material_override = _plate_material(kind)
	add_child(view)
	field["multimesh"] = multi
	field["placements"] = placements
	_fields.append(field)
	return _fields.size() - 1


## Brings the given fields down in a wave that runs out from origin at speed m/s, starting after
## delay seconds: each intact plate starts cracking when the wave reaches it (its horizontal
## distance from origin over speed), as if the player had stepped on it. Plates still grow back.
func crack_wave(field_indices: Array, origin: Vector3, speed: float, delay: float = 0.0) -> void:
	for index: int in field_indices:
		if index < 0 or index >= _fields.size():
			continue
		for cell: Dictionary in (_fields[index]["cells"] as Dictionary).values():
			var at: Vector3 = cell["at"]
			cell["due"] = delay + Vector2(at.x - origin.x, at.z - origin.z).length() / maxf(speed, 0.01)


func mine(floor_point: Vector3) -> void:
	if _mine_mesh == null:
		_build_mine_assets()
	var view := MeshInstance3D.new()
	view.mesh = _mine_mesh
	view.material_override = _mine_idle
	view.position = floor_point
	view.rotation.y = float(_mines.size()) * 1.7
	add_child(view)
	_mines.append({"at": floor_point, "view": view, "state": 0, "timer": 0.0})


## A marble of radius r waiting at rest_point. Entering trigger (an AABB in level space) releases it
## with an initial push (m/s).
func boulder(rest_point: Vector3, radius: float, trigger: AABB, push: Vector3 = Vector3.ZERO) -> void:
	var body: RigidBody3D = _marble_body(rest_point, radius, "Boulder%d" % _boulders.size())
	var record := {"body": body, "rest": rest_point, "trigger": trigger, "push": push, "state": 0, "timer": 0.0, "cooldown": 0.0}
	body.body_entered.connect(_on_boulder_hit.bind(record))
	_boulders.append(record)


## A marble run's hopper (H03). One marble waits frozen at each slot; every period seconds (the
## first phase seconds in) the next waiting one is carried to gate over RUN_LOAD_TIME and let go
## with push (m/s). It goes back to its slot once it has come to rest (RUN_SETTLE) or after lifetime
## seconds, whichever is first; a release with no marble waiting is skipped. Run marbles hurt and
## flatten like boulders. Returns the run's index.
func marble_run(slots: Array[Vector3], gate: Vector3, radius: float, period: float, push: Vector3, phase: float = 0.0, lifetime: float = BOULDER_LIFETIME) -> int:
	var marbles: Array[Dictionary] = []
	for i in range(slots.size()):
		var body: RigidBody3D = _marble_body(slots[i], radius, "RunMarble%d_%d" % [_runs.size(), i])
		var record := {"body": body, "rest": slots[i], "state": 0, "timer": 0.0, "cooldown": 0.0, "still": 0.0}
		body.body_entered.connect(_on_boulder_hit.bind(record))
		marbles.append(record)
	period = maxf(period, RUN_LOAD_TIME + 0.5)
	_runs.append({"gate": gate, "push": push, "period": period, "clock": fposmod(phase, period), "next": 0, "marbles": marbles, "lifetime": lifetime})
	return _runs.size() - 1


## Every marble run releases tempo times as often (1 is the built rhythm).
func set_run_tempo(tempo: float) -> void:
	_run_tempo = maxf(tempo, 0.1)


## A run's marble states (0 waiting, 3 loading, 1 rolling), in slot order. For tests.
func run_states(index: int = 0) -> Array[int]:
	var states: Array[int] = []
	if index < 0 or index >= _runs.size():
		return states
	for record: Dictionary in (_runs[index]["marbles"] as Array):
		states.append(int(record["state"]))
	return states


## A frozen marble body with its banded mesh, waiting at rest_point.
func _marble_body(rest_point: Vector3, radius: float, title: String) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = title
	body.mass = BOULDER_MASS
	body.collision_layer = 1
	body.collision_mask = 1 | 2 | 8
	body.contact_monitor = true
	body.max_contacts_reported = 6
	body.continuous_cd = true
	body.freeze = true
	body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	var material := PhysicsMaterial.new()
	material.friction = 0.9
	material.bounce = 0.1
	body.physics_material_override = material
	var shape := SphereShape3D.new()
	shape.radius = radius
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	var view := MeshInstance3D.new()
	view.mesh = _marble_mesh(radius)
	var look := StandardMaterial3D.new()
	look.vertex_color_use_as_albedo = true
	look.vertex_color_is_srgb = true
	look.roughness = 0.25
	look.metallic = 0.1
	view.material_override = look
	body.add_child(view)
	body.position = rest_point
	add_child(body)
	return body


## A flood over area (x/z) that will rise from start_y to end_y at speed m/s once started.
func flood(area: Rect2, start_y: float, end_y: float, speed: float) -> void:
	var view := MeshInstance3D.new()
	view.name = "Flood"
	var plane := PlaneMesh.new()
	plane.size = area.size
	view.mesh = plane
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.36, 0.62, 0.72, 0.78)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.05
	water.metallic = 0.2
	view.material_override = water
	view.position = Vector3(area.get_center().x, start_y, area.get_center().y)
	view.visible = false
	add_child(view)
	_flood = {"area": area, "y": start_y, "end": end_y, "speed": speed, "running": false, "view": view, "under": {}}


func start_flood() -> void:
	if _flood.is_empty() or bool(_flood["running"]):
		return
	_flood["running"] = true
	(_flood["view"] as MeshInstance3D).visible = true
	level.emit_signal("hint_requested", "THE MELTWATER IS RISING  /  get high and stay high", 6.0)


## A geyser on a solid stone mound at floor_point. It erupts for GEYSER_ERUPT every period seconds,
## phase seconds into its cycle, throwing what is over the vent up at power m/s (about
## power^2 / 20 metres of height). Returns the vent top, where the column starts.
func geyser(floor_point: Vector3, period: float = 7.0, phase: float = 0.0, power: float = 24.0) -> Vector3:
	var top: Vector3 = floor_point + Vector3.UP * GEYSER_MOUND
	var mound := CylinderMesh.new()
	mound.top_radius = GEYSER_RADIUS + 0.4
	mound.bottom_radius = GEYSER_RADIUS + 1.6
	mound.height = GEYSER_MOUND + 0.6
	mound.radial_segments = 12
	var rim := MeshInstance3D.new()
	rim.mesh = mound
	rim.material_override = _sinter_material()
	rim.position = floor_point + Vector3.UP * (GEYSER_MOUND - 0.6) * 0.5
	add_child(rim)
	var body := StaticBody3D.new()
	body.name = "GeyserMound"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CylinderShape3D.new()
	shape.radius = GEYSER_RADIUS + 1.0
	shape.height = GEYSER_MOUND + 0.6
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	body.position = rim.position
	add_child(body)
	# The vent: a dark wet disc just above the mound top.
	var vent_mesh := CylinderMesh.new()
	vent_mesh.top_radius = GEYSER_RADIUS * 0.55
	vent_mesh.bottom_radius = GEYSER_RADIUS * 0.55
	vent_mesh.height = 0.04
	vent_mesh.radial_segments = 12
	var vent := MeshInstance3D.new()
	vent.mesh = vent_mesh
	vent.material_override = _vent_material()
	vent.position = top + Vector3.UP * 0.02
	add_child(vent)
	# The column: unit height, scaled while it erupts. Steam is not solid, and does not look it.
	var column_mesh := CylinderMesh.new()
	column_mesh.top_radius = 1.5
	column_mesh.bottom_radius = 0.7
	column_mesh.height = 1.0
	column_mesh.radial_segments = 12
	column_mesh.cap_top = false
	column_mesh.cap_bottom = false
	var column := MeshInstance3D.new()
	column.mesh = column_mesh
	column.material_override = _steam_material()
	column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	column.position = top
	column.visible = false
	add_child(column)
	_geysers.append({
		"top": top, "period": maxf(period, GEYSER_WARN + GEYSER_ERUPT + 0.5), "phase": phase,
		"power": power, "column": column, "state": 0, "height": power * power / 20.0,
	})
	return top


## Boiling mud: a round pool on the ground, surface at center.y. Hurts the player who wades in and
## cooks hounds. A zero-damage hazard box keeps it off the navmesh and out of safe-ground respawns.
func mud_pool(center: Vector3, radius: float) -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.08
	disc.radial_segments = 20
	var view := MeshInstance3D.new()
	view.mesh = disc
	view.material_override = _mud_material()
	view.position = center
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(view)
	level.call("hazard_box", AABB(center - Vector3(radius, 1.2, radius), Vector3(radius * 2.0, 2.0, radius * 2.0)), "heat", 0.0)
	_muds.append({"center": center, "radius": radius, "view": view})


## Current flood height, or -INF before it starts.
## Stars fall inside area (level x/z) every period seconds while the level runs, landing far from
## the player, until hunt_starfall() makes them fall every hunt_period seconds where the player is
## heading.
func starfall(area: Rect2, period: float, hunt_period: float, seed_value: int = 9001) -> void:
	_star_rng.seed = seed_value
	_starfall = {"area": area, "period": maxf(period, 0.2), "hunt_period": maxf(hunt_period, 0.2), "hunting": false, "clock": period * 0.5}


## From now on stars aim at the player, every period seconds (the built hunt_period if period <= 0).
## Called again with a shorter period, the hunt quickens.
func hunt_starfall(period: float = -1.0) -> void:
	if _starfall.is_empty():
		return
	if period > 0.0:
		_starfall["hunt_period"] = maxf(period, 0.2)
	_starfall["hunting"] = true
	_starfall["clock"] = minf(float(_starfall["clock"]), 1.0)


func is_hunting() -> bool:
	return not _starfall.is_empty() and bool(_starfall["hunting"])


## Marks target (a point on the ground) and strikes it STAR_WARN seconds later. Returns false when
## STAR_POOL strikes are already in the air.
func strike_star(target: Vector3, normal: Vector3 = Vector3.UP) -> bool:
	var strike: Dictionary = {}
	for record: Dictionary in _strikes:
		if not bool(record["live"]):
			strike = record
			break
	if strike.is_empty():
		if _strikes.size() >= STAR_POOL:
			return false
		strike = _new_strike()
		_strikes.append(strike)
	# In from high up and off to one side, so the streak reads against the sky.
	var side: float = _star_rng.randf_range(0.0, TAU)
	var come_from: Vector3 = Vector3(cos(side) * 0.55, 1.0, sin(side) * 0.55).normalized()
	strike["live"] = true
	strike["target"] = target
	strike["from"] = target + come_from * STAR_DROP
	strike["timer"] = STAR_WARN
	var mark: MeshInstance3D = strike["mark"]
	mark.visible = true
	var up: Vector3 = normal.normalized() if normal.length() > 0.1 else Vector3.UP
	var across: Vector3 = up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	mark.global_transform = Transform3D(Basis(across, up, across.cross(up)) * Basis.from_scale(Vector3(1.0, 0.15, 1.0)), target + up * 0.08)
	var star: Node3D = strike["star"]
	star.visible = true
	star.global_position = strike["from"]
	(strike["trail"] as Node3D).visible = true
	# A faint ray of light from the ring up the way the star is coming, narrowing to nothing: it
	# shows a strike from far off. Light, not a pole: nothing to stand on and nothing that looks it.
	var shaft: MeshInstance3D = strike["shaft"]
	shaft.visible = true
	shaft.global_transform = Transform3D(_basis_along(come_from), target + come_from * SHAFT_LENGTH * 0.5)
	_sound("hazard_zap", target, -2.0)
	return true


## The strikes in the air now, as their targets. For tests.
func live_strikes() -> Array[Vector3]:
	var targets: Array[Vector3] = []
	for record: Dictionary in _strikes:
		if bool(record["live"]):
			targets.append(record["target"])
	return targets


func flood_level() -> float:
	if _flood.is_empty() or not bool(_flood["running"]):
		return -INF
	return float(_flood["y"])


# --- Runtime -------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if level == null or not bool(level.get("_active")):
		return
	var player: Node3D = level.get("_player")
	if not is_instance_valid(player):
		return
	if not _connected and player.has_signal("landed"):
		player.connect("landed", _on_player_landed)
		_connected = true
	_update_fields(player, delta)
	_update_mines(player, delta)
	_update_boulders(player, delta)
	_update_runs(delta)
	_update_flood(player, delta)
	_clock += delta
	_update_geysers(player)
	_update_muds(player, delta)
	_update_starfall(player, delta)


func _cell_under(field: Dictionary, point: Vector3) -> Dictionary:
	var center: Vector3 = field["center"]
	var tile: float = field["tile"]
	var local: Vector3 = (field["turn"] as Basis).inverse() * (point - center)
	var origin: Vector2 = -Vector2(int(field["columns"]), int(field["rows"])) * tile * 0.5
	var key := Vector2i(int(floor((local.x - origin.x) / tile)), int(floor((local.z - origin.y) / tile)))
	var cells: Dictionary = field["cells"]
	if not cells.has(key):
		return {}
	var height: float = point.y - center.y
	if height < -0.4 or height > STAND_HEIGHT:
		return {}
	return cells[key]


func _update_fields(player: Node3D, delta: float) -> void:
	var grounded: bool = bool(player.get("grounded"))
	for field: Dictionary in _fields:
		if grounded:
			var under: Dictionary = _cell_under(field, player.global_position)
			if not under.is_empty() and int(under["state"]) == 0:
				_start_crack(field, under)
		for cell: Dictionary in (field["cells"] as Dictionary).values():
			if float(cell["due"]) >= 0.0:
				cell["due"] = float(cell["due"]) - delta
				if float(cell["due"]) < 0.0 and int(cell["state"]) == 0:
					_start_crack(field, cell)
			match int(cell["state"]):
				1:
					cell["timer"] = float(cell["timer"]) - delta
					var shake: float = 1.0 - float(cell["timer"]) / CRACK_TIME
					var multi: MultiMesh = field["multimesh"]
					multi.set_instance_color(int(cell["index"]), _plate_color(str(field["kind"]), shake))
					if float(cell["timer"]) <= 0.0:
						_break(field, cell)
				2:
					cell["timer"] = float(cell["timer"]) - delta
					if float(cell["timer"]) <= 0.0 and not _player_over(player, field, cell):
						_restore(field, cell)


func _start_crack(field: Dictionary, cell: Dictionary) -> void:
	cell["state"] = 1
	cell["timer"] = CRACK_TIME
	_sound("weight_impact", cell["at"], -8.0)


func _break(field: Dictionary, cell: Dictionary) -> void:
	cell["state"] = 2
	cell["timer"] = REGROW_TIME
	(cell["body"] as StaticBody3D).collision_layer = 0
	var multi: MultiMesh = field["multimesh"]
	multi.set_instance_transform(int(cell["index"]), Transform3D(Basis.from_scale(Vector3.ONE * 0.001), cell["at"]))
	var color: Color = _plate_color(str(field["kind"]), 0.0)
	FX.burst(level, cell["at"], Vector3.UP, color, 18, 5.0, 0.6, 0.12)
	_sound("splash" if str(field["kind"]) == "ice" else "weight_impact", cell["at"])


func _restore(field: Dictionary, cell: Dictionary) -> void:
	cell["state"] = 0
	(cell["body"] as StaticBody3D).collision_layer = 1
	var multi: MultiMesh = field["multimesh"]
	multi.set_instance_transform(int(cell["index"]), (field["placements"] as Array)[int(cell["index"])])
	multi.set_instance_color(int(cell["index"]), _plate_color(str(field["kind"]), 0.0))


func _player_over(player: Node3D, field: Dictionary, cell: Dictionary) -> bool:
	var tile: float = field["tile"]
	var local: Vector3 = (field["turn"] as Basis).inverse() * (player.global_position - (cell["at"] as Vector3))
	return absf(local.x) < tile * 0.7 and absf(local.z) < tile * 0.7


## A hard landing on a plate breaks it on the spot and sets the ones around it cracking.
func _on_player_landed(impact: float) -> void:
	if impact < HARD_LANDING or not is_instance_valid(level):
		return
	var player: Node3D = level.get("_player")
	for field: Dictionary in _fields:
		var under: Dictionary = _cell_under(field, player.global_position)
		if under.is_empty() or int(under["state"]) == 2:
			continue
		_break(field, under)
		var tile: float = field["tile"]
		for cell: Dictionary in (field["cells"] as Dictionary).values():
			if int(cell["state"]) == 0 and (cell["at"] as Vector3).distance_to(under["at"]) < tile * 1.6:
				_start_crack(field, cell)


func _update_mines(player: Node3D, delta: float) -> void:
	_scan_clock -= delta
	var scan: bool = _scan_clock <= 0.0
	if scan:
		_scan_clock = MINE_SCAN
	for record: Dictionary in _mines:
		match int(record["state"]):
			0:
				var at: Vector3 = record["at"]
				var near: bool = player.global_position.distance_to(at + Vector3.UP * 0.9) < MINE_TRIGGER
				if not near and scan:
					near = _something_near(at, MINE_TRIGGER)
				if near:
					record["state"] = 1
					record["timer"] = MINE_FUSE
					_sound("sentry_charge", at)
			1:
				record["timer"] = float(record["timer"]) - delta
				var view: MeshInstance3D = record["view"]
				view.material_override = _mine_armed if fmod(float(record["timer"]), 0.16) < 0.08 else _mine_idle
				if float(record["timer"]) <= 0.0:
					_blow(record, player)


## True when the rod's weight (layer 4) or a hound (layer 8) is within radius of point.
func _something_near(point: Vector3, radius: float) -> bool:
	var ball := SphereShape3D.new()
	ball.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = ball
	query.transform = Transform3D(Basis.IDENTITY, point + Vector3.UP * 0.6)
	query.collision_mask = 4 | 8
	return not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _blow(record: Dictionary, player: Node3D) -> void:
	record["state"] = 2
	var at: Vector3 = record["at"]
	(record["view"] as MeshInstance3D).visible = false
	FX.explosion(level, at + Vector3.UP * 0.4, Color("ffb347"), 1.6)
	_sound("drone_shot", at, 4.0)
	var offset: Vector3 = player.global_position - at
	var distance: float = offset.length()
	if distance < MINE_BLAST:
		var falloff: float = 1.0 - distance / MINE_BLAST
		player.call("take_damage", MINE_DAMAGE * falloff * float(level.get("damage_scale")), "mine", at)
		var away: Vector3 = Vector3(offset.x, 0.0, offset.z).normalized() * 0.5 + Vector3.UP
		if player is RigidBody3D:
			var body := player as RigidBody3D
			body.linear_velocity += away.normalized() * MINE_THROW * falloff
		if player.has_method("add_shake"):
			player.call("add_shake", 0.7 * falloff)
	for hostile: Node in (level.get("_enemies") as Array):
		if is_instance_valid(hostile) and (hostile as Node3D).global_position.distance_to(at) < MINE_BLAST:
			hostile.call("take_damage", MINE_ENEMY_DAMAGE, "mine")


func _update_boulders(player: Node3D, delta: float) -> void:
	for record: Dictionary in _boulders:
		var body: RigidBody3D = record["body"]
		record["cooldown"] = maxf(0.0, float(record["cooldown"]) - delta)
		match int(record["state"]):
			0:
				if (record["trigger"] as AABB).has_point(player.global_position):
					record["state"] = 1
					record["timer"] = BOULDER_LIFETIME
					body.freeze = false
					body.linear_velocity = record["push"]
					level.emit_signal("hint_requested", "BOULDER  /  get off the slope", 3.0)
					_sound("weight_impact", body.global_position, 6.0)
			1:
				record["timer"] = float(record["timer"]) - delta
				if float(record["timer"]) <= 0.0 or body.global_position.y < float(level.get("kill_y")):
					_reset_boulder(record)
			2:
				# Waiting to re-arm until the player has left the trigger.
				if not (record["trigger"] as AABB).has_point(player.global_position):
					record["state"] = 0


func _update_runs(delta: float) -> void:
	for run: Dictionary in _runs:
		var marbles: Array = run["marbles"]
		var period: float = float(run["period"]) / _run_tempo
		run["clock"] = float(run["clock"]) + delta
		if float(run["clock"]) >= period:
			run["clock"] = fmod(float(run["clock"]), period)
			for k in range(marbles.size()):
				var index: int = (int(run["next"]) + k) % marbles.size()
				var waiting: Dictionary = marbles[index]
				if int(waiting["state"]) == 0:
					waiting["state"] = 3
					waiting["timer"] = RUN_LOAD_TIME
					run["next"] = (index + 1) % marbles.size()
					break
		for record: Dictionary in marbles:
			var body: RigidBody3D = record["body"]
			record["cooldown"] = maxf(0.0, float(record["cooldown"]) - delta)
			match int(record["state"]):
				3:
					record["timer"] = float(record["timer"]) - delta
					var t: float = clampf(1.0 - float(record["timer"]) / RUN_LOAD_TIME, 0.0, 1.0)
					body.global_position = (record["rest"] as Vector3).lerp(run["gate"], smoothstep(0.0, 1.0, t))
					if float(record["timer"]) <= 0.0:
						body.freeze = false
						body.linear_velocity = run["push"]
						body.angular_velocity = Vector3.ZERO
						record["state"] = 1
						record["timer"] = float(run["lifetime"])
						record["still"] = 0.0
				1:
					record["timer"] = float(record["timer"]) - delta
					var rolled: bool = float(run["lifetime"]) - float(record["timer"]) > 3.0
					record["still"] = float(record["still"]) + delta if rolled and body.linear_velocity.length() < 0.6 else 0.0
					if float(record["timer"]) <= 0.0 or float(record["still"]) > RUN_SETTLE or body.global_position.y < float(level.get("kill_y")):
						body.freeze = true
						body.linear_velocity = Vector3.ZERO
						body.angular_velocity = Vector3.ZERO
						body.global_position = record["rest"]
						record["state"] = 0


func _reset_boulder(record: Dictionary) -> void:
	var body: RigidBody3D = record["body"]
	body.freeze = true
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.global_position = record["rest"]
	record["state"] = 2


func _on_boulder_hit(other: Node, record: Dictionary) -> void:
	var body: RigidBody3D = record["body"]
	if int(record["state"]) != 1 or float(record["cooldown"]) > 0.0:
		return
	var other_velocity: Vector3 = (other as RigidBody3D).linear_velocity if other is RigidBody3D else Vector3.ZERO
	if other is CharacterBody3D:
		other_velocity = (other as CharacterBody3D).velocity
	var speed: float = (body.linear_velocity - other_velocity).length()
	if speed < BOULDER_HIT_SPEED:
		return
	if other == level.get("_player"):
		record["cooldown"] = 0.8
		other.call("take_damage", BOULDER_DAMAGE * float(level.get("damage_scale")), "boulder", body.global_position)
		if other.has_method("add_shake"):
			other.call("add_shake", 0.8)
	elif other.is_in_group("enemies"):
		other.call("take_damage", 500.0, "boulder")


func _update_flood(player: Node3D, delta: float) -> void:
	if _flood.is_empty() or not bool(_flood["running"]):
		return
	var y: float = minf(float(_flood["end"]), float(_flood["y"]) + float(_flood["speed"]) * delta)
	_flood["y"] = y
	(_flood["view"] as MeshInstance3D).position.y = y
	var area: Rect2 = _flood["area"]
	if player.global_position.y < y - 0.3 and area.has_point(Vector2(player.global_position.x, player.global_position.z)):
		player.call("take_damage", FLOOD_DPS * float(level.get("damage_scale")) * delta, "flood", Vector3.INF)
	var under: Dictionary = _flood["under"]
	for hostile: Node in (level.get("_enemies") as Array):
		if not is_instance_valid(hostile):
			continue
		var below: bool = (hostile as Node3D).global_position.y + 0.6 < y
		var time: float = float(under.get(hostile.get_instance_id(), 0.0))
		time = time + delta if below else 0.0
		under[hostile.get_instance_id()] = time
		if time >= FLOOD_DROWN:
			hostile.call("take_damage", 1000.0, "flood")
			under[hostile.get_instance_id()] = -1000.0


func _update_geysers(player: Node3D) -> void:
	for record: Dictionary in _geysers:
		var period: float = maxf(float(record["period"]) / _tempo, GEYSER_WARN + GEYSER_ERUPT + 0.6)
		var t: float = fmod(_clock + float(record["phase"]), period)
		var erupt_at: float = period - GEYSER_ERUPT
		var state: int = 2 if t >= erupt_at else (1 if t >= erupt_at - GEYSER_WARN else 0)
		var top: Vector3 = record["top"]
		var column: MeshInstance3D = record["column"]
		if state != int(record["state"]):
			record["state"] = state
			if state == 1:
				_sound("hazard_zap", top, -4.0)
			elif state == 2:
				_sound("splash", top, 6.0)
		var height: float = 1.0
		match state:
			0:
				column.visible = false
			1:
				# The tell: a low, swelling plume of steam over the vent.
				var swell: float = (t - (erupt_at - GEYSER_WARN)) / GEYSER_WARN
				height = 0.5 + swell * 2.0
				column.visible = true
				column.scale = Vector3(0.6 + swell * 0.3, height, 0.6 + swell * 0.3)
			2:
				var age: float = t - erupt_at
				var rise: float = clampf(age / 0.35, 0.0, 1.0) * (1.0 - smoothstep(GEYSER_ERUPT - 0.5, GEYSER_ERUPT, age) * 0.7)
				height = float(record["height"]) * 0.8 * rise + 1.0
				column.visible = true
				column.scale = Vector3(1.0, height, 1.0)
				_geyser_throw(record, player, height)
		column.position = top + Vector3.UP * height * 0.5


## Bodies over the vent and inside the column are thrown up; hounds are scalded.
func _geyser_throw(record: Dictionary, player: Node3D, height: float) -> void:
	var top: Vector3 = record["top"]
	var power: float = record["power"]
	var bodies: Array[Node] = [player]
	bodies.append_array(get_tree().get_nodes_in_group("cast_weight"))
	for node: Node in bodies:
		if not (node is RigidBody3D):
			continue
		var body := node as RigidBody3D
		var offset: Vector3 = body.global_position - top
		if Vector2(offset.x, offset.z).length() > GEYSER_RADIUS or offset.y < -1.0 or offset.y > height:
			continue
		body.sleeping = false
		if body.linear_velocity.y < power:
			body.linear_velocity.y = power
		if body == player:
			if player.has_method("add_shake"):
				player.call("add_shake", 0.25)
			# The throw comes with a soft landing, unless the player climbs higher on their own.
			# Ceiling: the column's reach plus a free climb at the throw speed, and a margin.
			if player.has_method("cushion_landing"):
				var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)) * maxf(body.gravity_scale, 0.1)
				player.call("cushion_landing", top.y + float(record["height"]) * 0.8 + power * power / (2.0 * gravity) + 5.0)
	for hostile: Node in (level.get("_enemies") as Array):
		if not is_instance_valid(hostile) or str(hostile.get("kind")) != "hound":
			continue
		var offset: Vector3 = (hostile as Node3D).global_position - top
		if Vector2(offset.x, offset.z).length() < GEYSER_RADIUS + 0.5 and offset.y > -1.5 and offset.y < height:
			hostile.call("take_damage", 500.0, "geyser")


func _update_muds(player: Node3D, delta: float) -> void:
	for record: Dictionary in _muds:
		var center: Vector3 = record["center"]
		var radius: float = record["radius"]
		var offset: Vector3 = player.global_position - center
		if Vector2(offset.x, offset.z).length() < radius and offset.y < 1.3:
			player.call("take_damage", MUD_DPS * float(level.get("damage_scale")) * delta, "mud", Vector3.INF)
		for hostile: Node in (level.get("_enemies") as Array):
			if not is_instance_valid(hostile):
				continue
			var at: Vector3 = (hostile as Node3D).global_position - center
			if Vector2(at.x, at.z).length() < radius and at.y < 1.0:
				hostile.call("take_damage", MUD_ENEMY_DPS * delta, "mud")
		# A slow boil: the surface breathes.
		(record["view"] as MeshInstance3D).scale.y = 1.0 + sin(_clock * 3.0 + center.x) * 0.5


func _update_starfall(player: Node3D, delta: float) -> void:
	for record: Dictionary in _strikes:
		if not bool(record["live"]):
			continue
		record["timer"] = float(record["timer"]) - delta
		var t: float = clampf(1.0 - float(record["timer"]) / STAR_WARN, 0.0, 1.0)
		var target: Vector3 = record["target"]
		var from: Vector3 = record["from"]
		var at: Vector3 = from.lerp(target, t)
		var back: Vector3 = (from - target).normalized()
		var spin: float = float(record["timer"]) * 9.0
		var star: Node3D = record["star"]
		star.global_transform = Transform3D(Basis(Vector3.UP, spin).scaled(Vector3.ONE * 4.0), at)
		var trail: Node3D = record["trail"]
		trail.global_transform = Transform3D(_basis_along(back), at + back * 9.0)
		var mark: MeshInstance3D = record["mark"]
		var pulse: float = 0.55 + 0.45 * sin(t * 26.0)
		(mark.material_override as StandardMaterial3D).albedo_color.a = 0.35 + 0.6 * t * pulse
		var shaft: MeshInstance3D = record["shaft"]
		(shaft.material_override as StandardMaterial3D).albedo_color.a = 0.03 + 0.12 * t
		if float(record["timer"]) <= 0.0:
			_star_land(record, player)
	if _starfall.is_empty():
		return
	_starfall["clock"] = float(_starfall["clock"]) - delta
	if float(_starfall["clock"]) > 0.0:
		return
	var hunting: bool = bool(_starfall["hunting"])
	_starfall["clock"] = float(_starfall["hunt_period" if hunting else "period"])
	var hit: Dictionary = _ground_at(_star_aim(player, hunting))
	if not hit.is_empty():
		strike_star(hit["position"], hit["normal"])


## Where the next star comes down (x, z): ahead of the player when hunting, else somewhere far off.
func _star_aim(player: Node3D, hunting: bool) -> Vector2:
	var area: Rect2 = _starfall["area"]
	var here := Vector2(player.global_position.x, player.global_position.z)
	var turn: float = _star_rng.randf_range(0.0, TAU)
	var aim: Vector2
	if hunting:
		var run := Vector2.ZERO
		if player is RigidBody3D:
			var velocity: Vector3 = (player as RigidBody3D).linear_velocity
			run = Vector2(velocity.x, velocity.z)
		aim = here + run * STAR_LEAD + Vector2(cos(turn), sin(turn)) * _star_rng.randf_range(0.0, STAR_SCATTER)
	else:
		aim = here + Vector2(cos(turn), sin(turn)) * _star_rng.randf_range(STAR_FAR.x, STAR_FAR.y)
	return Vector2(clampf(aim.x, area.position.x, area.end.x), clampf(aim.y, area.position.y, area.end.y))


## The first solid thing straight down at (x, z): {"position", "normal", ...}, or {} for nothing.
func _ground_at(xz: Vector2) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(Vector3(xz.x, 600.0, xz.y), Vector3(xz.x, -200.0, xz.y), 1)
	return get_world_3d().direct_space_state.intersect_ray(query)


func _star_land(record: Dictionary, player: Node3D) -> void:
	record["live"] = false
	(record["mark"] as Node3D).visible = false
	(record["star"] as Node3D).visible = false
	(record["trail"] as Node3D).visible = false
	(record["shaft"] as Node3D).visible = false
	var at: Vector3 = record["target"]
	FX.explosion(level, at + Vector3.UP * 0.5, Color("ffd36a"), 2.6)
	_sound("drone_shot", at, 6.0)
	var offset: Vector3 = player.global_position - at
	var distance: float = offset.length()
	if distance < STAR_BLAST:
		var falloff: float = 1.0 - distance / STAR_BLAST
		player.call("take_damage", STAR_DAMAGE * falloff * float(level.get("damage_scale")), "star", at)
		var away: Vector3 = Vector3(offset.x, 0.0, offset.z).normalized() * 0.6 + Vector3.UP
		if player is RigidBody3D:
			(player as RigidBody3D).linear_velocity += away.normalized() * STAR_THROW * falloff
		if player.has_method("add_shake"):
			player.call("add_shake", 0.8 * falloff)
	elif distance < STAR_BLAST * 6.0 and player.has_method("add_shake"):
		player.call("add_shake", 0.25 * (1.0 - distance / (STAR_BLAST * 6.0)))
	for hostile: Node in (level.get("_enemies") as Array):
		if is_instance_valid(hostile) and (hostile as Node3D).global_position.distance_to(at) < STAR_BLAST:
			hostile.call("take_damage", STAR_ENEMY_DAMAGE, "star")


## One strike's nodes: the ring on the ground, the star and its streak. Reused once it lands.
func _new_strike() -> Dictionary:
	var mark := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = STAR_BLAST - 0.8
	ring.outer_radius = STAR_BLAST
	ring.rings = 32
	ring.ring_segments = 4
	mark.mesh = ring
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.albedo_color = Color(1.0, 0.82, 0.4, 0.3)
	mark.material_override = glow
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mark.visible = false
	add_child(mark)
	var star := MeshInstance3D.new()
	star.mesh = DreamPropsScript.pickup_mesh("star")
	var shine := StandardMaterial3D.new()
	shine.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shine.vertex_color_use_as_albedo = true
	shine.vertex_color_is_srgb = true
	shine.cull_mode = BaseMaterial3D.CULL_DISABLED
	star.material_override = shine
	star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	star.visible = false
	add_child(star)
	var trail := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.9
	cone.height = 18.0
	cone.radial_segments = 8
	cone.rings = 1
	trail.mesh = cone
	var streak := StandardMaterial3D.new()
	streak.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	streak.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	streak.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	streak.albedo_color = Color(1.0, 0.8, 0.45, 0.55)
	trail.material_override = streak
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trail.visible = false
	add_child(trail)
	var shaft := MeshInstance3D.new()
	var column := CylinderMesh.new()
	column.top_radius = 0.0
	column.bottom_radius = 0.7
	column.height = SHAFT_LENGTH
	column.radial_segments = 8
	column.rings = 1
	column.cap_top = false
	column.cap_bottom = false
	shaft.mesh = column
	var beam := StandardMaterial3D.new()
	beam.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.albedo_color = Color(1.0, 0.85, 0.5, 0.1)
	shaft.material_override = beam
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shaft.visible = false
	add_child(shaft)
	return {"live": false, "mark": mark, "star": star, "trail": trail, "shaft": shaft, "target": Vector3.ZERO, "from": Vector3.ZERO, "timer": 0.0}


## A basis whose y axis runs along direction: the trail cone's point (its top) trails back along it.
static func _basis_along(direction: Vector3) -> Basis:
	var y: Vector3 = direction.normalized()
	var x: Vector3 = y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y))


## Every geyser erupts tempo times as often (1 is the built rhythm).
func set_geyser_tempo(tempo: float) -> void:
	_tempo = maxf(tempo, 0.1)


## Current geyser states (0 quiet, 1 hissing, 2 erupting), in build order. For tests.
func geyser_states() -> Array[int]:
	var states: Array[int] = []
	for record: Dictionary in _geysers:
		states.append(int(record["state"]))
	return states


# --- Looks and sounds ----------------------------------------------------------------------------

func _sinter_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("c9b58f")      # pale sinter crust, stained by minerals
	material.roughness = 0.95
	return material


func _vent_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("3c6f78")
	material.roughness = 0.1
	material.metallic = 0.3
	return material


func _steam_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/geyser_steam.gdshader")
	return material


func _mud_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("4a3327")
	material.roughness = 0.6
	material.emission_enabled = true
	material.emission = Color("b5532b")
	material.emission_energy_multiplier = 0.08
	return material


func _plate_color(kind: String, crack: float) -> Color:
	var base: Color = Color("cfeaf5") if kind == "ice" else Color("cbbfa4")
	var warn: Color = Color("ffffff") if kind == "ice" else Color("8a5a3c")
	var flicker: float = 0.5 + 0.5 * sin(crack * 40.0)
	return base.lerp(warn, clampf(crack * (0.6 + 0.4 * flicker), 0.0, 1.0))


func _plate_material(kind: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	if kind == "ice":
		material.albedo_color = Color(1, 1, 1, 0.82)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.roughness = 0.08
		material.metallic = 0.2
	else:
		material.roughness = 0.9
	return material


func _build_mine_assets() -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var saucer := CylinderMesh.new()
	saucer.top_radius = 0.55
	saucer.bottom_radius = 0.45
	saucer.height = 0.06
	saucer.radial_segments = 14
	_append(tool, saucer, Transform3D(Basis.IDENTITY, Vector3(0, 0.03, 0)), Color("f4efe4"))
	var cup := CylinderMesh.new()
	cup.top_radius = 0.34
	cup.bottom_radius = 0.24
	cup.height = 0.32
	cup.radial_segments = 14
	_append(tool, cup, Transform3D(Basis.IDENTITY, Vector3(0, 0.22, 0)), Color("f4efe4"))
	var handle := TorusMesh.new()
	handle.inner_radius = 0.07
	handle.outer_radius = 0.12
	handle.rings = 10
	handle.ring_segments = 6
	_append(tool, handle, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.38, 0.24, 0)), Color("f4efe4"))
	var fuse := SphereMesh.new()
	fuse.radius = 0.08
	fuse.height = 0.16
	fuse.radial_segments = 8
	fuse.rings = 4
	_append(tool, fuse, Transform3D(Basis.IDENTITY, Vector3(0, 0.4, 0)), Color("d9403a"))
	_mine_mesh = tool.commit()
	_mine_idle = StandardMaterial3D.new()
	_mine_idle.vertex_color_use_as_albedo = true
	_mine_idle.vertex_color_is_srgb = true
	_mine_idle.roughness = 0.3
	_mine_armed = _mine_idle.duplicate() as StandardMaterial3D
	_mine_armed.emission_enabled = true
	_mine_armed.emission = Color("ff3b2f")
	_mine_armed.emission_energy_multiplier = 2.5


## A sphere with coloured bands, so a rolling marble visibly turns.
func _marble_mesh(radius: float) -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 18
	sphere.rings = 10
	var arrays: Array = sphere.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors := PackedColorArray()
	colors.resize(vertices.size())
	for i in range(vertices.size()):
		var v: Vector3 = vertices[i] / radius
		var band: float = sin(atan2(v.z, v.x) * 3.0 + v.y * 4.0)
		colors[i] = Color("4aa3c9").lerp(Color("f2e6c8"), 0.5 + 0.5 * band)
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _append(tool: SurfaceTool, mesh: PrimitiveMesh, placement: Transform3D, color: Color) -> void:
	var arrays: Array = mesh.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for index: int in indices:
		tool.set_color(color)
		tool.set_normal((placement.basis * normals[index]).normalized())
		tool.add_vertex(placement * vertices[index])


func _sound(event: String, at: Vector3, volume_db: float = 0.0) -> void:
	var audio: Node = get_tree().get_first_node_in_group("game_audio")
	if is_instance_valid(audio) and audio.has_method("play_at"):
		audio.call("play_at", event, at, volume_db)
