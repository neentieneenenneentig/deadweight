extends SceneTree
## The sky's animation must obey gameplay pause and use a separate clock per level.
const Level = preload("res://scripts/level_base.gd")
var _failed: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	if not ok:
		_failed += 1
		push_error(label)

func _run() -> void:
	var first := Level.new()
	root.add_child(first)
	first.call("_build_environment")
	for i in range(4):
		await process_frame
	var before: float = first.get("_storm_time")
	_check(before > 0.0, "Sky clock advances while running")
	var material: ShaderMaterial = first.get("_sky_material")
	_check(is_equal_approx(float(material.get_shader_parameter("storm_time")), before), "Visible sky receives the level clock")
	paused = true
	for i in range(4):
		await process_frame
	_check(is_equal_approx(float(first.get("_storm_time")), before), "Sky freezes while paused")
	paused = false
	for i in range(4):
		await process_frame
	_check(float(first.get("_storm_time")) > before, "Sky resumes after pause")
	var second := Level.new()
	root.add_child(second)
	second.call("_build_environment")
	_check(is_zero_approx(float(second.get("_storm_time"))), "Fresh level starts a fresh sky clock")
	_check(second.get("_sky_material") != material, "Levels do not share mutable sky materials")
	first.queue_free()
	second.queue_free()
	await process_frame
	print("NIGHTMARE SKY: 6 checks, %d failures" % _failed)
	quit(1 if _failed else 0)
