extends Node
## Short original synthesized effects, generated once. No external audio assets.

var _sounds: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _voice_index: int = 0
var _wind: AudioStreamPlayer
var _reel: AudioStreamPlayer

func _ready() -> void:
	_sounds["cast"] = _make_sound(0.24, 140.0, 45.0, 0.6, 0.4)
	_sounds["lock"] = _make_sound(0.11, 340.0, 85.0, 0.65, 0.4)
	_sounds["release"] = _make_sound(0.12, 200.0, 500.0, 0.35, 0.25)
	_sounds["cut"] = _make_sound(0.13, 750.0, 100.0, 0.7, 0.25)
	_sounds["shot"] = _make_sound(0.20, 130.0, 40.0, 0.85, 0.75)
	_sounds["hit"] = _make_sound(0.07, 1700.0, 1000.0, 0.2, 0.2)
	_sounds["hurt"] = _make_sound(0.24, 85.0, 38.0, 0.5, 0.4)
	_sounds["loot"] = _make_sound(0.32, 640.0, 1200.0, 0.02, 0.28)
	_sounds["reload"] = _make_sound(0.28, 250.0, 600.0, 0.55, 0.2)
	_sounds["empty"] = _make_sound(0.07, 160.0, 120.0, 0.5, 0.25)
	_sounds["win"] = _make_sound(0.8, 380.0, 900.0, 0.03, 0.32)
	_sounds["lose"] = _make_sound(0.65, 160.0, 40.0, 0.25, 0.36)
	for index in range(8):
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -8.0
		add_child(voice)
		_voices.append(voice)
	_wind = AudioStreamPlayer.new()
	_wind.stream = _make_sound(2.0, 42.0, 42.0, 0.92, 0.12, true)
	_wind.volume_db = -40.0
	add_child(_wind)
	_wind.play()
	_reel = AudioStreamPlayer.new()
	_reel.stream = _make_sound(0.5, 115.0, 115.0, 0.28, 0.12, true)
	_reel.volume_db = -50.0
	add_child(_reel)
	_reel.play()

func play(event: String) -> void:
	if not _sounds.has(event):
		return
	var voice: AudioStreamPlayer = _voices[_voice_index]
	_voice_index = (_voice_index + 1) % _voices.size()
	voice.stream = _sounds[event]
	voice.pitch_scale = randf_range(0.94, 1.06)
	voice.play()

func motion(speed: float, tension: float, reeling: bool, playing: bool) -> void:
	_wind.volume_db = lerpf(-40.0, -12.0, clampf(speed / 38.0, 0.0, 1.0)) if playing else -48.0
	_reel.volume_db = -22.0 if reeling and playing else -55.0
	_reel.pitch_scale = lerpf(1.25, 0.65, clampf(tension / 16000.0, 0.0, 1.0))

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
