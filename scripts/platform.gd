extends Node
## Platform services: optional GodotSteam, mobile detection, achievement unlocks and vibration.
## Steam is used only when the GodotSteam singleton exists. Without it every call is a safe no-op.
## Local achievement state lives in the profile, not here.

const JOY_RUMBLE := 0.6  # gamepad motor strength, 0..1

var _steam: Object = null
var _steam_ready := false
var _haptics := true


func _process(_delta: float) -> void:
	if _steam_ready and _steam.has_method("run_callbacks"):
		_steam.call("run_callbacks")


## Starts GodotSteam when it is present. Does nothing when it is absent.
func setup() -> void:
	_steam_ready = false
	if not Engine.has_singleton("Steam"):
		return
	_steam = Engine.get_singleton("Steam")
	if _steam == null or not _steam.has_method("steamInitEx"):
		return
	var result: Variant = _steam.call("steamInitEx")
	if result is Dictionary:
		_steam_ready = int((result as Dictionary).get("status", -1)) == 0


func is_steam() -> bool:
	return _steam_ready


func is_mobile() -> bool:
	return OS.has_feature("mobile")


## Unlocks an achievement on Steam and stores the stats. No-op without Steam.
func unlock_achievement(id: String) -> void:
	if not _steam_ready or id.is_empty():
		return
	if _steam.has_method("setAchievement"):
		_steam.call("setAchievement", id)
	if _steam.has_method("storeStats"):
		_steam.call("storeStats")


func set_haptics(enabled: bool) -> void:
	_haptics = enabled


## Rumbles the handheld (mobile only) and every connected gamepad. Silent when haptics is off.
func vibrate(milliseconds: int) -> void:
	if not _haptics or milliseconds <= 0:
		return
	if is_mobile():
		Input.vibrate_handheld(milliseconds)
	var seconds: float = milliseconds / 1000.0
	for pad: int in Input.get_connected_joypads():
		Input.start_joy_vibration(pad, JOY_RUMBLE, JOY_RUMBLE, seconds)
