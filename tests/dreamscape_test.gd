extends SceneTree
## Integration: decoration pauses with play, has independent clocks and frees with a level.
const Catalog = preload("res://scripts/level_catalog.gd")
var _failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var player := Node3D.new()
	root.add_child(player)
	var level: Node3D = Catalog.create("l04")
	root.add_child(level)
	level.call("build", player, true)
	var dream: Node3D = level.get_node("DreamAtmosphere")
	var pendulum: Node3D = dream.get_node("UnfinishedPendulum")
	var water: ShaderMaterial = (level.get("_materials") as Dictionary)["water"]
	var start: float = pendulum.rotation.z
	await _frames(40)
	_check(not is_equal_approx(start, pendulum.rotation.z), "pendulum animates while the world runs")
	paused = true
	var held: float = pendulum.rotation.z
	var held_water: float = water.get_shader_parameter("dream_time")
	await _frames(15)
	_check(is_equal_approx(held, pendulum.rotation.z), "pendulum stays still during pause")
	_check(is_equal_approx(held_water, float(water.get_shader_parameter("dream_time"))), "water stays still during pause")
	paused = false
	await _frames(10)
	_check(not is_equal_approx(held, pendulum.rotation.z), "animation resumes after pause")
	var second: Node3D = Catalog.create("l05")
	root.add_child(second)
	second.call("build", player, true)
	var other_water: ShaderMaterial = (second.get("_materials") as Dictionary)["water"]
	_check(water != other_water, "simultaneous levels have independent water clocks")
	# Anything that looks solid is solid (S1): the props collide on the level's scenery body, the
	# pendulum ball on its own, and neither is parsed into the navmesh. No floating notices remain.
	var scenery: StaticBody3D = level.get_node_or_null("Scenery")
	_check(scenery != null and scenery.get_child_count() > 50, "dream props are solid on the scenery body")
	var ball: StaticBody3D = pendulum.get_node_or_null("PendulumBall")
	_check(ball != null and ball.collision_layer == 1, "the pendulum ball is solid")
	var notices: int = 0
	for text: Node in level.find_children("*", "Label3D", true, false):
		if (text as Label3D).text.contains("IN MOTION") or (text as Label3D).text.contains("YESTERDAY"):
			notices += 1
	_check(notices == 0, "dream decoration adds no floating notices")
	var forms: MultiMeshInstance3D = dream.get_node("UnfiledForms")
	var count: int = forms.multimesh.instance_count
	await _frames(90)
	_check(forms.multimesh.instance_count == count, "paper population remains bounded")
	level.queue_free()
	second.queue_free()
	player.queue_free()
	await _frames(2)
	_check(not is_instance_valid(dream), "animated scenery is freed with its level")
	print("DREAMSCAPE TEST: 10 checks, %d failures" % _failures)
	quit(0 if _failures == 0 else 1)

func _frames(count: int) -> void:
	for i in range(count):
		await process_frame

func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
