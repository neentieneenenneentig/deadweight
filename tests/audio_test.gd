extends SceneTree
## A2 audio engine checks (CONTRACT 4.16 and 5.11). Headless: playback is silent, so these
## checks read state (bus layout, stream resolution, live player counts, effect flags).

const AudioScript = preload("res://scripts/audio.gd")

## Every event id from CONTRACT 5.11, including the internal loops and drone_hum.
const EVENT_IDS := [
	"cast", "lock", "release", "cut", "anchor", "recover", "spool_limit", "severed",
	"weight_impact", "smash", "reel_stall",
	"jump", "land", "land_hard", "footstep", "hurt", "death",
	"shot", "hit", "kill", "reload", "empty", "switch",
	"loot", "bonus", "extract_ready", "extract_tick", "extract_break", "win", "lose", "medal", "checkpoint",
	"hound_alert", "hound_bite", "sentry_charge", "sentry_shot", "drone_charge", "drone_shot", "enemy_death",
	"hazard_zap", "updraft", "splash",
	"ui_move", "ui_accept", "ui_back", "ui_buy", "ui_denied", "ui_unlock", "ui_toggle",
	"wind", "reel", "tension", "drone_hum",
]
const LOOP_IDS := ["wind", "reel", "tension", "drone_hum"]
const SFX_PREFIX := "res://audio/sfx/"
## Plays of an event with no LIMITS entry; the audio node's DEFAULT_LIMIT must match.
const DEFAULT_LIMIT_PROBE := 3

var _failures: int = 0
var _checks: int = 0
var _audio: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_audio = AudioScript.new()
	root.add_child(_audio)
	_test_buses()
	_test_event_resolution()
	_test_loops_flagged()
	_test_volumes()
	_test_pause_filter()
	_test_concurrency()
	_test_positional()
	_test_motion()
	print("audio checks: %d, failures: %d" % [_checks, _failures])
	# Free the node so the run exits without leaking its voices and streams.
	root.remove_child(_audio)
	_audio.free()
	quit(1 if _failures > 0 else 0)


func _test_buses() -> void:
	for bus_name: String in ["Music", "SFX", "UI"]:
		var index: int = AudioServer.get_bus_index(bus_name)
		_check(index >= 0, "bus %s exists after startup" % bus_name)
		if index >= 0:
			_check(AudioServer.get_bus_send(index) == "Master", "bus %s routes to Master" % bus_name)


func _test_event_resolution() -> void:
	var unresolved: Array[String] = []
	for event_id: String in EVENT_IDS:
		if not _audio.has_event(event_id) or _audio.get_stream(event_id) == null:
			unresolved.append(event_id)
	_check(unresolved.is_empty(), "every CONTRACT 5.11 id resolves (unresolved: %s)" % str(unresolved))
	_check(not _audio.has_event("no_such_event"), "has_event is false for an unknown id")
	_check(_audio.get_stream("no_such_event") == null, "get_stream returns null for an unknown id")


func _test_loops_flagged() -> void:
	for loop_id: String in LOOP_IDS:
		var stream := _audio.get_stream(loop_id) as AudioStreamWAV
		_check(stream != null, "loop %s loads as AudioStreamWAV" % loop_id)
		if stream != null:
			_check(stream.loop_mode != AudioStreamWAV.LOOP_DISABLED, "loop %s is flagged to loop (mode %d)" % [loop_id, stream.loop_mode])
	var shot := _audio.get_stream("cast") as AudioStreamWAV
	_check(shot != null and shot.loop_mode == AudioStreamWAV.LOOP_DISABLED, "one-shot cast does not loop")


func _test_volumes() -> void:
	_audio.set_volumes(0.5, 0.25, 0.8)
	_check_db("Master", linear_to_db(0.5), "set_volumes master 0.5 maps to linear_to_db")
	_check_db("Music", linear_to_db(0.25), "set_volumes music 0.25 maps to linear_to_db")
	_check_db("SFX", linear_to_db(0.8), "set_volumes sfx 0.8 maps to linear_to_db")
	_check_db("UI", linear_to_db(0.8), "UI bus follows the sfx volume")
	_audio.set_volumes(0.0, 1.0, 1.0)
	var master_index: int = AudioServer.get_bus_index("Master")
	_check(AudioServer.is_bus_mute(master_index), "master 0.0 mutes the Master bus")
	_audio.set_volumes(1.0, 1.0, 1.0)
	_check(not AudioServer.is_bus_mute(master_index), "master 1.0 unmutes the Master bus")


func _check_db(bus_name: String, expected_db: float, description: String) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	var actual: float = AudioServer.get_bus_volume_db(index) if index >= 0 else NAN
	_check(absf(actual - expected_db) < 0.001, "%s (got %.3f dB, want %.3f dB)" % [description, actual, expected_db])


func _test_pause_filter() -> void:
	var sfx_index: int = AudioServer.get_bus_index("SFX")
	var effect_index: int = _find_low_pass(sfx_index)
	_check(effect_index >= 0, "SFX bus has a low-pass effect")
	if effect_index < 0:
		return
	_audio.set_paused(false)
	_check(not AudioServer.is_bus_effect_enabled(sfx_index, effect_index), "low-pass is off while playing")
	_audio.set_paused(true)
	_check(AudioServer.is_bus_effect_enabled(sfx_index, effect_index), "low-pass is on while paused")
	_audio.set_paused(false)
	_check(not AudioServer.is_bus_effect_enabled(sfx_index, effect_index), "low-pass is off again after resume")


func _find_low_pass(bus_index: int) -> int:
	for effect_index in range(AudioServer.get_bus_effect_count(bus_index)):
		if AudioServer.get_bus_effect(bus_index, effect_index) is AudioEffectLowPassFilter:
			return effect_index
	return -1


## Plays one event well past its limit and counts the players that are actually sounding.
func _test_concurrency() -> void:
	var limit: int = int(AudioScript.LIMITS["footstep"])
	for index in range(limit + 3):
		_audio.play("footstep")
	var active: int = _count_active("footstep")
	_check(active == limit, "footstep is capped at its limit of %d (sounding: %d)" % [limit, active])
	for index in range(DEFAULT_LIMIT_PROBE + 2):
		_audio.play("cut")
	var cut_active: int = _count_active("cut")
	_check(cut_active == DEFAULT_LIMIT_PROBE, "an event without an entry uses the default limit of %d (sounding: %d)" % [DEFAULT_LIMIT_PROBE, cut_active])
	_audio.play("no_such_event")
	_check(_count_active("no_such_event") == 0, "unknown ids play nothing")


## The 3D pool: play_at respects its own limit and places the voice where it was asked.
func _test_positional() -> void:
	var limit: int = int(AudioScript.LIMITS["hound_bite"])
	var target := Vector3(3.0, 1.0, -4.0)
	for index in range(limit + 2):
		_audio.play_at("hound_bite", target)
	var active: int = _count_active("hound_bite")
	_check(active == limit, "hound_bite is capped at its limit of %d on the 3D pool (sounding: %d)" % [limit, active])
	var placed: bool = false
	for voice: Node in _all_players():
		if voice is AudioStreamPlayer3D and (voice as AudioStreamPlayer3D).playing:
			placed = placed or (voice as AudioStreamPlayer3D).global_position.is_equal_approx(target)
	_check(placed, "a positional voice sits at the requested position")


## motion() keeps the v1 wind curve: full speed reaches -12 dB.
func _test_motion() -> void:
	_audio.motion(38.0, 0.0, false, true)
	var wind: AudioStreamPlayer = _loop_player("res://audio/sfx/wind.wav")
	_check(wind != null and absf(wind.volume_db - (-12.0)) < 0.001, "motion drives wind to -12 dB at full speed")
	_audio.motion(0.0, 0.0, false, false)
	_check(wind != null and absf(wind.volume_db - (-48.0)) < 0.001, "motion mutes wind when not playing")


## Counts voices sounding for one event by their stream file, so ambience loops never count.
func _count_active(event: String) -> int:
	var prefix: String = SFX_PREFIX + event + "_"
	var single: String = SFX_PREFIX + event + ".wav"
	var count: int = 0
	for voice: Node in _all_players():
		var stream: AudioStream = voice.get("stream") as AudioStream
		if stream == null or not bool(voice.get("playing")):
			continue
		var path: String = stream.resource_path
		# A variant is <event>_<number>.wav, so land_hard.wav does not count as land.
		var suffix: String = path.trim_prefix(prefix).trim_suffix(".wav")
		if path == single or (path.begins_with(prefix) and suffix.is_valid_int()):
			count += 1
	return count


func _all_players() -> Array[Node]:
	var found: Array[Node] = []
	_collect_players(_audio, found)
	return found


func _collect_players(node: Node, found: Array[Node]) -> void:
	for child: Node in node.get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer3D:
			found.append(child)
		_collect_players(child, found)


func _loop_player(path: String) -> AudioStreamPlayer:
	for voice: Node in _all_players():
		if voice is AudioStreamPlayer and (voice as AudioStreamPlayer).stream != null:
			if (voice as AudioStreamPlayer).stream.resource_path == path:
				return voice as AudioStreamPlayer
	return null


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("PASS: " + description)
	else:
		_failures += 1
		push_error("FAIL: " + description)
