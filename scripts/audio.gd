extends Node
## Audio engine v2 (CONTRACT 4.16, task A2). Plays the generated SFX from audio/sfx (task A1)
## through three buses (Music, SFX, UI): a 2D voice pool for UI and one-shots, a 3D pool for
## positional sounds, per-event variance, concurrency limits, looping ambience driven by
## motion(), and a low-pass on SFX while paused. Missing files fall back to the runtime
## synthesis at the bottom of this script, so a broken import never silences a cue.

const SFX_DIR := "res://audio/sfx/"
const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"
const BUS_UI := "UI"
const VOICES_2D := 12
const VOICES_3D := 8
const MAX_VARIANTS := 9              # <id>_1.wav .. <id>_9.wav, stopping at the first gap
const DEFAULT_LIMIT := 3             # simultaneous plays of one event when it has no entry below
const PAUSE_CUTOFF_HZ := 900.0       # muffle SFX while the game is paused
const MUTE_BELOW := 0.001            # linear volumes at or under this mute the bus (as settings.gd)
const VOLUME_JITTER_DB := 1.5        # random +/- volume per play so repeats do not sound copied
const DEFAULT_PITCH_JITTER := 0.06   # random +/- pitch fraction per play
const POSITIONAL_UNIT_SIZE := 6.0    # metres at which a 3D voice is at its base level
const POSITIONAL_MAX_DISTANCE := 60.0

## Most plays of one event that may sound at once. Rapid events are capped low so that a
## crowd of enemies or a run of footsteps does not stack into a wall of noise.
const LIMITS := {
	"footstep": 2, "weight_impact": 2, "hit": 3, "shot": 2, "hurt": 2, "hound_bite": 2,
	"sentry_shot": 2, "drone_shot": 2, "enemy_death": 2, "ui_move": 2, "hazard_zap": 2,
	"splash": 2, "extract_tick": 2,
}
## Per-event pitch jitter. Footsteps and impacts vary more so they do not read as samples.
const PITCH_JITTER := {"footstep": 0.08, "weight_impact": 0.08, "hit": 0.05, "shot": 0.05, "hurt": 0.05}
## Stingers play on the Music bus so the music volume controls them too.
const MUSIC_EVENTS := ["win", "lose", "medal"]
## Ambience loops that motion() drives (CONTRACT 5.11). drone_hum is not here: drone enemies
## get it through get_stream() and run their own player.
const MOTION_LOOPS := ["wind", "reel", "tension"]

var _voices_2d: Array[AudioStreamPlayer] = []
var _events_2d: Array[String] = []
var _voices_3d: Array[AudioStreamPlayer3D] = []
var _events_3d: Array[String] = []
var _spatial: Node3D
var _loops: Dictionary = {}          # loop id -> AudioStreamPlayer
var _variants: Dictionary = {}       # event id -> Array of AudioStream (empty when unresolved)
var _warned: Dictionary = {}         # keys already warned about, so each warning prints once
var _pause_effect: int = -1          # index of the low-pass on the SFX bus, -1 when absent
var _paused: bool = false


func _ready() -> void:
	add_to_group("game_audio")
	_ensure_buses()
	_build_loops()
	_build_pools()


# --- Public API (CONTRACT 4.16) ----------------------------------------------------------------

## One-shot on the 2D pool. Unknown ids are ignored silently; extra plays past the event's
## concurrency limit, or with every voice busy, are dropped.
func play(event: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var stream: AudioStream = _pick_variant(event)
	if stream == null or _active_count(event) >= _limit_for(event):
		return
	var index: int = _idle_index_2d()
	if index < 0:
		return
	var voice: AudioStreamPlayer = _voices_2d[index]
	voice.stream = stream
	voice.bus = _bus_for(event)
	voice.volume_db = volume_db + _volume_jitter()
	voice.pitch_scale = pitch * _pitch_jitter(event)
	_events_2d[index] = event
	voice.play()


## One-shot on the 3D pool, heard from `position` (world space).
func play_at(event: String, position: Vector3, volume_db: float = 0.0) -> void:
	var stream: AudioStream = _pick_variant(event)
	if stream == null or _active_count(event) >= _limit_for(event):
		return
	var index: int = _idle_index_3d()
	if index < 0:
		return
	var voice: AudioStreamPlayer3D = _voices_3d[index]
	voice.stream = stream
	voice.bus = _bus_for(event)
	voice.volume_db = volume_db + _volume_jitter()
	voice.pitch_scale = _pitch_jitter(event)
	voice.global_position = position
	_events_3d[index] = event
	voice.play()


## A variant picked at random for multi-file ids, or the single file. Null for unknown ids.
func get_stream(event: String) -> AudioStream:
	var stream: AudioStream = _pick_variant(event)
	if stream == null:
		_warn_once("unknown:" + event, "audio: no stream for event '%s'" % event)
	return stream


## Drives the ambience loops from the player's state. Wind follows speed, reel follows the
## line when reeling, and tension creaks as the line loads up.
func motion(speed: float, tension: float, reeling: bool, playing: bool) -> void:
	var speed_t: float = clampf(speed / 38.0, 0.0, 1.0)
	var tension_t: float = clampf(tension / 16000.0, 0.0, 1.0)
	_set_loop_volume("wind", lerpf(-40.0, -12.0, speed_t) if playing else -48.0)
	_set_loop_volume("reel", -22.0 if reeling and playing else -55.0)
	_set_loop_pitch("reel", lerpf(1.25, 0.65, tension_t))
	_set_loop_volume("tension", lerpf(-60.0, -24.0, tension_t) if playing else -60.0)


## Linear 0..1 per bus. The UI bus follows the SFX volume, as settings.gd does without this node.
func set_volumes(master: float, music: float, sfx: float) -> void:
	_set_bus_linear(BUS_MASTER, master)
	_set_bus_linear(BUS_MUSIC, music)
	_set_bus_linear(BUS_SFX, sfx)
	_set_bus_linear(BUS_UI, sfx)


## Enables the SFX low-pass while the game is paused. main.gd calls this on every state change.
func set_paused(paused: bool) -> void:
	_paused = paused
	if _pause_effect >= 0:
		AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index(BUS_SFX), _pause_effect, paused)


func has_event(event: String) -> bool:
	return not _variants_for(event).is_empty()


# --- Buses -------------------------------------------------------------------------------------

## Creates any missing bus under Master, then makes sure the SFX bus carries the pause filter.
func _ensure_buses() -> void:
	for bus_name: String in [BUS_MUSIC, BUS_SFX, BUS_UI]:
		if AudioServer.get_bus_index(bus_name) >= 0:
			continue
		AudioServer.add_bus()
		var index: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, BUS_MASTER)
	_ensure_pause_filter()


## Reuses a low-pass already on the SFX bus, otherwise adds one. It starts disabled.
func _ensure_pause_filter() -> void:
	var index: int = AudioServer.get_bus_index(BUS_SFX)
	for effect_index in range(AudioServer.get_bus_effect_count(index)):
		if AudioServer.get_bus_effect(index, effect_index) is AudioEffectLowPassFilter:
			_pause_effect = effect_index
			return
	var filter := AudioEffectLowPassFilter.new()
	filter.cutoff_hz = PAUSE_CUTOFF_HZ
	AudioServer.add_bus_effect(index, filter)
	_pause_effect = AudioServer.get_bus_effect_count(index) - 1
	AudioServer.set_bus_effect_enabled(index, _pause_effect, _paused)


func _set_bus_linear(bus_name: String, linear: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	var clamped: float = clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_mute(index, clamped <= MUTE_BELOW)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(clamped, MUTE_BELOW)))


## UI ids go to the UI bus, stingers to Music, and everything else to SFX.
func _bus_for(event: String) -> String:
	if event.begins_with("ui_"):
		return BUS_UI
	if event in MUSIC_EVENTS:
		return BUS_MUSIC
	return BUS_SFX


# --- Voices and loops --------------------------------------------------------------------------

func _build_loops() -> void:
	for loop_id: String in MOTION_LOOPS + ["drone_hum"]:
		var player := AudioStreamPlayer.new()
		player.bus = BUS_SFX
		player.volume_db = -60.0
		player.stream = _pick_variant(loop_id)
		add_child(player)
		_loops[loop_id] = player
		if player.stream != null:
			player.play()


func _build_pools() -> void:
	for index in range(VOICES_2D):
		var voice := AudioStreamPlayer.new()
		voice.bus = BUS_SFX
		add_child(voice)
		_voices_2d.append(voice)
		_events_2d.append("")
	# Positional voices sit under their own Node3D so their world transform is explicit.
	_spatial = Node3D.new()
	add_child(_spatial)
	for index in range(VOICES_3D):
		var voice := AudioStreamPlayer3D.new()
		voice.bus = BUS_SFX
		voice.unit_size = POSITIONAL_UNIT_SIZE
		voice.max_distance = POSITIONAL_MAX_DISTANCE
		_spatial.add_child(voice)
		_voices_3d.append(voice)
		_events_3d.append("")


func _set_loop_volume(loop_id: String, volume_db: float) -> void:
	var player := _loops.get(loop_id) as AudioStreamPlayer
	if player != null:
		player.volume_db = volume_db


func _set_loop_pitch(loop_id: String, pitch: float) -> void:
	var player := _loops.get(loop_id) as AudioStreamPlayer
	if player != null:
		player.pitch_scale = pitch


## Counts voices still sounding for one event across both pools. This is what the
## concurrency limit compares against.
func _active_count(event: String) -> int:
	var count: int = 0
	for index in range(_voices_2d.size()):
		if _voices_2d[index].playing and _events_2d[index] == event:
			count += 1
	for index in range(_voices_3d.size()):
		if _voices_3d[index].playing and _events_3d[index] == event:
			count += 1
	return count


func _idle_index_2d() -> int:
	for index in range(_voices_2d.size()):
		if not _voices_2d[index].playing:
			return index
	return -1


func _idle_index_3d() -> int:
	for index in range(_voices_3d.size()):
		if not _voices_3d[index].playing:
			return index
	return -1


func _limit_for(event: String) -> int:
	return int(LIMITS.get(event, DEFAULT_LIMIT))


func _pitch_jitter(event: String) -> float:
	var span: float = float(PITCH_JITTER.get(event, DEFAULT_PITCH_JITTER))
	return randf_range(1.0 - span, 1.0 + span)


func _volume_jitter() -> float:
	return randf_range(-VOLUME_JITTER_DB, VOLUME_JITTER_DB)


# --- Stream lookup -----------------------------------------------------------------------------

func _pick_variant(event: String) -> AudioStream:
	var variants: Array = _variants_for(event)
	if variants.is_empty():
		return null
	return variants[randi() % variants.size()] as AudioStream


## Resolves an id once: <id>_1..N.wav when present, else <id>.wav, else the synthesized
## fallback. Ids that resolve to nothing cache an empty list, so they are looked up once.
func _variants_for(event: String) -> Array:
	if _variants.has(event):
		return _variants[event]
	var found: Array = []
	for index in range(1, MAX_VARIANTS + 1):
		var variant: AudioStream = _load_stream("%s%s_%d.wav" % [SFX_DIR, event, index])
		if variant == null:
			break
		found.append(variant)
	if found.is_empty():
		var single: AudioStream = _load_stream("%s%s.wav" % [SFX_DIR, event])
		if single != null:
			found.append(single)
	if found.is_empty():
		var synth: AudioStream = _synth_stream(event)
		if synth != null:
			_warn_once("missing:" + event, "audio: %s.wav missing, using the synthesized fallback" % event)
			found.append(synth)
	_variants[event] = found
	return found


func _load_stream(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream


func _warn_once(key: String, message: String) -> void:
	if _warned.has(key):
		return
	_warned[key] = true
	push_warning(message)


# --- Runtime synthesis fallback ----------------------------------------------------------------
# Used only when a generated file is missing. The recipes are the original v1 synth, plus
# two loops for tension and drone_hum so the fallback covers every loop id.

func _synth_stream(event: String) -> AudioStreamWAV:
	match event:
		"cast": return _make_sound(0.24, 140.0, 45.0, 0.6, 0.4)
		"lock": return _make_sound(0.11, 340.0, 85.0, 0.65, 0.4)
		"release": return _make_sound(0.12, 200.0, 500.0, 0.35, 0.25)
		"cut": return _make_sound(0.13, 750.0, 100.0, 0.7, 0.25)
		"shot": return _make_sound(0.20, 130.0, 40.0, 0.85, 0.75)
		"hit": return _make_sound(0.07, 1700.0, 1000.0, 0.2, 0.2)
		"hurt": return _make_sound(0.24, 85.0, 38.0, 0.5, 0.4)
		"loot": return _make_sound(0.32, 640.0, 1200.0, 0.02, 0.28)
		"reload": return _make_sound(0.28, 250.0, 600.0, 0.55, 0.2)
		"empty": return _make_sound(0.07, 160.0, 120.0, 0.5, 0.25)
		"win": return _make_sound(0.8, 380.0, 900.0, 0.03, 0.32)
		"lose": return _make_sound(0.65, 160.0, 40.0, 0.25, 0.36)
		"wind": return _make_sound(2.0, 42.0, 42.0, 0.92, 0.12, true)
		"reel": return _make_sound(0.5, 115.0, 115.0, 0.28, 0.12, true)
		"tension": return _make_sound(1.5, 900.0, 700.0, 0.6, 0.08, true)
		"drone_hum": return _make_sound(2.0, 60.0, 60.0, 0.3, 0.1, true)
	return null


func _make_sound(duration: float, from_hz: float, to_hz: float, noise_amount: float, volume: float, looping: bool = false) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var count: int = int(duration * sample_rate)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var phase: float = 0.0
	var smoothed_noise: float = 0.0
	var random := RandomNumberGenerator.new()
	random.seed = int(from_hz * 717.0)
	for i in range(count):
		var progress: float = float(i) / float(count)
		phase += lerpf(from_hz, to_hz, progress) / float(sample_rate)
		smoothed_noise = lerpf(smoothed_noise, random.randf_range(-1.0, 1.0), 0.35)
		var envelope: float = 1.0 if looping else pow(1.0 - progress, 2.2) * minf(1.0, progress * 80.0)
		var value: float = lerpf(sin(phase * TAU), smoothed_noise, noise_amount) * envelope * volume
		bytes.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 32767.0))
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = sample_rate
	sound.data = bytes
	if looping:
		sound.loop_mode = AudioStreamWAV.LOOP_FORWARD
		sound.loop_begin = 0
		sound.loop_end = count
	return sound
