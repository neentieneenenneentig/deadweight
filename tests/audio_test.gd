extends SceneTree
## A2 audio engine checks (CONTRACT 4.16 and 5.11). Headless: playback is silent, so these
## checks read state (bus layout, stream resolution, live player counts, effect flags).

const AudioScript = preload("res://scripts/audio.gd")
const MusicScript = preload("res://scripts/music.gd")
const MainScript = preload("res://scripts/main.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const ROUTING_PROFILE := "user://test_a4.cfg"

## A3 music (CONTRACT 4.17). Tempos and stinger lengths match tools/generate_audio.gd.
const MUSIC_DIR := "res://audio/music/"
const MUSIC_RATE := 32000
const BARS := 16
const TRACK_TEMPOS := {"menu": 84.0, "floodworks": 104.0, "foundry": 80.0, "spillway": 92.0}
const STINGER_SECONDS := {"victory": 3.0, "defeat": 3.0, "medal": 2.5}

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
	_test_music_files()
	_test_music_node()
	await _test_routing()
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


## Every track is a 16-bar seamless loop; every stinger is a one-shot. Lengths are checked
## to the frame: a track is BARS bars of four beats at its tempo.
func _test_music_files() -> void:
	for track_id: String in TRACK_TEMPOS:
		var frames: int = roundi(float(BARS * 4) * 60.0 * float(MUSIC_RATE) / float(TRACK_TEMPOS[track_id]))
		var wav := load(MUSIC_DIR + track_id + ".wav") as AudioStreamWAV
		_check(wav != null, "track %s loads as AudioStreamWAV" % track_id)
		if wav == null:
			continue
		_check(wav.loop_mode == AudioStreamWAV.LOOP_FORWARD, "track %s is a forward loop" % track_id)
		_check(wav.stereo and wav.mix_rate == MUSIC_RATE, "track %s is 32 kHz stereo" % track_id)
		_check(absf(wav.get_length() * MUSIC_RATE - frames) < 0.5, "track %s is 16 bars at %.0f BPM (%.3f s)" % [track_id, TRACK_TEMPOS[track_id], float(frames) / MUSIC_RATE])
	for stinger_id: String in STINGER_SECONDS:
		var wav := load(MUSIC_DIR + stinger_id + ".wav") as AudioStreamWAV
		_check(wav != null, "stinger %s loads as AudioStreamWAV" % stinger_id)
		if wav == null:
			continue
		_check(wav.loop_mode == AudioStreamWAV.LOOP_DISABLED, "stinger %s does not loop" % stinger_id)
		_check(absf(wav.get_length() - float(STINGER_SECONDS[stinger_id])) < 1.0 / MUSIC_RATE, "stinger %s is %.1f s" % [stinger_id, float(STINGER_SECONDS[stinger_id])])


## music.gd plays, switches zones and stops without errors. Fades are zero so the state
## checks run at once. The Audio node runs first so the Music bus exists.
func _test_music_node() -> void:
	var music = MusicScript.new()
	root.add_child(music)
	music.play_track("menu", 0.0)
	_check(music.current_track() == "menu", "play_track sets the current track to menu")
	music.set_zone("foundry")
	_check(music.current_track() == "foundry", "set_zone changes the track id to foundry")
	music.set_zone("no_such_zone")
	_check(music.current_track() == "foundry", "an unknown zone leaves the track unchanged")
	music.stinger("victory")
	music.stinger("no_such_stinger")
	music.set_intensity(0.5)
	music.stop(0.0)
	_check(music.current_track() == "", "stop clears the current track")
	root.remove_child(music)
	music.free()


## A4 event routing: every id routed in this task is sent by its source. A spy stands in for the
## audio node in group game_audio, so the calls can be counted. Nothing here touches the real save.
class SpyAudio extends Node:
	var calls: Array = []   # each entry: [event, position or null]

	func play(event: String, _volume_db: float = 0.0, _pitch: float = 1.0) -> void:
		calls.append([event, null])

	func play_at(event: String, position: Vector3, _volume_db: float = 0.0) -> void:
		calls.append([event, position])

	# main.gd also drives the loops and the pause filter through the node.
	func motion(_speed: float, _tension: float, _reeling: bool, _playing: bool) -> void:
		pass

	func set_paused(_paused: bool) -> void:
		pass

	func count(event: String) -> int:
		var total: int = 0
		for entry: Array in calls:
			if entry[0] == event:
				total += 1
		return total


## A stand-in enemy that always reports tracking, so the HUD alert can be switched on.
class FakeFoe extends Node3D:
	var kind: String = "hound"

	func is_tracking() -> bool:
		return true


## A level with one deep-water pool, built through the normal _design builder.
class WaterLevel extends "res://scripts/level_base.gd":
	func _design() -> void:
		water(Vector3.ZERO, Vector2(6.0, 6.0), true)


func _test_routing() -> void:
	# The real audio node leaves the group while the spy stands in for it.
	_audio.remove_from_group("game_audio")
	var spy := SpyAudio.new()
	spy.add_to_group("game_audio")
	root.add_child(spy)
	_test_splash(spy)
	_test_sentry_sounds(spy)
	await _test_main_routing(spy)
	root.remove_child(spy)
	spy.free()
	_audio.add_to_group("game_audio")


## Deep water sounds its splash once on entry. Standing in it for many frames adds nothing.
func _test_splash(spy: SpyAudio) -> void:
	var player := Node3D.new()
	root.add_child(player)
	var pool := WaterLevel.new()
	root.add_child(pool)
	pool.build(player)
	pool.set_active(true)
	player.global_position = Vector3(0.0, -1.0, 0.0)
	for index in range(30):
		pool.call("_update_features", 1.0 / 90.0)
	_check(spy.count("splash") == 1, "splash plays once while the player is in deep water (sounding: %d over 30 frames)" % spy.count("splash"))
	player.global_position = Vector3(0.0, 2.0, 0.0)
	pool.call("_update_features", 1.0 / 90.0)
	player.global_position = Vector3(0.0, -1.0, 0.0)
	pool.call("_update_features", 1.0 / 90.0)
	_check(spy.count("splash") == 2, "splash plays again when the player re-enters the water")
	root.remove_child(pool)
	pool.free()
	root.remove_child(player)
	player.free()


## The sentry's charge cue fires when the wind-up starts and its shot cue when the shot leaves,
## both positional at the turret. Ticks in between add nothing.
func _test_sentry_sounds(spy: SpyAudio) -> void:
	var target := Node3D.new()
	target.position = Vector3(0.0, 0.0, -12.0)
	root.add_child(target)
	var sentry: Node3D = EnemyScript.new()
	sentry.call("setup", target, "sentry", Vector3(0.0, 0.0, 0.0))
	root.add_child(sentry)
	sentry.set("_visible_target", true)
	for index in range(3):
		sentry.call("_tick_sentry", 0.1)
	_check(spy.count("sentry_charge") == 1, "sentry_charge plays once when the wind-up starts (sounding: %d)" % spy.count("sentry_charge"))
	_check(spy.count("sentry_shot") == 0, "sentry_shot waits for the shot")
	sentry.call("_tick_sentry", 1.5)
	_check(spy.count("sentry_shot") == 1, "sentry_shot plays when the shot leaves")
	var shot_at: Vector3 = Vector3.ZERO
	for entry: Array in spy.calls:
		if entry[0] == "sentry_shot":
			shot_at = entry[1] as Vector3
	_check(shot_at.is_equal_approx(sentry.global_position), "sentry sounds are positional at the turret")
	sentry.call("_tick_sentry", 0.1)
	_check(spy.count("sentry_charge") == 1 and spy.count("sentry_shot") == 1, "the cooldown after a shot adds no sentry cues")
	root.remove_child(sentry)
	sentry.free()
	root.remove_child(target)
	target.free()


## Boots the real main.gd on l01 in practice mode and checks each routed id: switch, kill (not
## dummies), land and land_hard, footstep, extract_ready, extract_tick, extract_break, checkpoint,
## the HUD alert and death.
func _test_main_routing(spy: SpyAudio) -> void:
	_wipe_profile()
	var main = MainScript.new()
	main.override_args = PackedStringArray(["--profile=" + ROUTING_PROFILE, "--windowed"])
	root.add_child(main)
	await _frames(6)
	main.sound = spy
	var starting: Signal = main.level_started
	main.start_level("l01", true)
	await _frames(2)
	await starting
	await _frames(2)
	_check(main.state == "playing", "routing run is live on l01")
	_check(main.level.get("level_id") == "l01", "routing run started the real l01 level")

	main._action("weapon", true)
	_check(spy.count("switch") == 1, "swapping rod to sidearm sounds switch")
	main._action("weapon", true)
	_check(spy.count("switch") == 2, "swapping back sounds switch again")

	main._on_enemy_killed("dummy", "shot")
	_check(spy.count("kill") == 0, "a training dummy going down does not sound kill")
	main._on_enemy_killed("hound", "shot")
	_check(spy.count("kill") == 1, "a real kill sounds kill")

	main.player.landed.emit(1.0)
	_check(spy.count("land") == 0 and spy.count("land_hard") == 0, "a step under the landing minimum is silent")
	main.player.landed.emit(5.0)
	_check(spy.count("land") == 1, "a normal landing sounds land")
	main.player.landed.emit(14.0)
	_check(spy.count("land_hard") == 1, "a hard landing sounds land_hard")
	main.player.footstep.emit()
	_check(spy.count("footstep") == 1, "a footstep from the player sounds footstep")

	var total: int = int(main.level.get("total_loot"))
	main.level.set("collected_loot", total - 1)
	main._on_loot("case", 0)
	_check(spy.count("extract_ready") == 0, "extract_ready waits for the last case")
	main.level.set("collected_loot", total)
	main._on_loot("case", 0)
	_check(spy.count("extract_ready") == 1, "the last case sounds extract_ready")

	# Holding the pad: 20 steps of 0.25 s is 5 s, which gives one tick per second and no completion.
	main.extraction_inside = true
	var ticks_before: int = spy.count("extract_tick")
	for index in range(20):
		main._physics_process(0.25)
	_check(spy.count("extract_tick") - ticks_before == 5, "the hold ticks once a second, not every frame (ticks: %d)" % (spy.count("extract_tick") - ticks_before))
	_check(main.state == "playing", "five seconds on the pad does not finish the raid")
	main.level.extraction_changed.emit(false)
	_check(spy.count("extract_break") == 1, "leaving the pad mid-hold sounds extract_break")
	_check(is_equal_approx(main.extraction_time, 0.0), "leaving the pad clears the hold")

	# The HUD alert (CONTRACT 5.9): a tracking enemy turns the reticle red; with none it goes back.
	var reticle: Label = main.hud.get("_reticle_state") as Label
	main._process(0.0)
	var calm: Color = reticle.get_theme_color("font_color")
	var foe := FakeFoe.new()
	foe.add_to_group("enemies")
	root.add_child(foe)
	main.level._enemies.append(foe)
	main._process(0.0)
	_check(reticle.get_theme_color("font_color") != calm, "a tracking enemy sets the HUD alert")
	main.level._enemies.erase(foe)
	root.remove_child(foe)
	foe.free()
	main._process(0.0)
	_check(reticle.get_theme_color("font_color") == calm, "with no tracking enemy the HUD alert is off")

	# Checkpoints: a grounded spot far from the last cue sounds once; re-recording the same spot does not.
	main.player.global_position = main._checkpoint + Vector3(20.0, 0.0, 0.0)
	main.player.grounded = true
	main._checkpoint_timer = 0.0
	main._track_checkpoint(0.0)
	_check(spy.count("checkpoint") == 1, "a new checkpoint 20 m on sounds checkpoint")
	main._checkpoint_timer = 0.0
	main._track_checkpoint(0.0)
	_check(spy.count("checkpoint") == 1, "the same checkpoint does not sound again")

	main._on_player_died("hound")
	_check(spy.count("death") == 1, "a death sounds death")

	root.remove_child(main)
	main.free()
	_wipe_profile()


func _frames(count: int) -> void:
	for index in range(count):
		await process_frame


func _wipe_profile() -> void:
	for suffix: String in ["", ".bak", ".tmp", ".corrupt"]:
		if FileAccess.file_exists(ROUTING_PROFILE + suffix):
			DirAccess.remove_absolute(ROUTING_PROFILE + suffix)


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("PASS: " + description)
	else:
		_failures += 1
		push_error("FAIL: " + description)
