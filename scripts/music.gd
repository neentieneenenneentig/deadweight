extends Node
## Music player (CONTRACT 4.17, task A3). Plays the generated 16-bar loops (audio/music, made
## by tools/generate_audio.gd -- --music) on the Music bus and crossfades between tracks.
## Stingers play on their own player over the same bus. MVP: one stem per track, so
## set_intensity only stores its value until the layered version fades extra stems in.
## audio.gd creates the Music bus, so it must be in the tree first.

const MUSIC_DIR := "res://audio/music/"
const BUS_MUSIC := "Music"
const DEFAULT_FADE := 1.5
const SILENT_DB := -60.0
## Stems per track in layer order. The MVP has one stem each; layers are appended here later.
const STEMS := {
	"menu": ["menu"],
	"floodworks": ["floodworks"],
	"foundry": ["foundry"],
	"spillway": ["spillway"],
}
const STINGERS := ["victory", "defeat", "medal"]
## Zone id (as used by level_base `zone`) to track id.
const ZONE_TRACKS := {"floodworks": "floodworks", "foundry": "foundry", "spillway": "spillway"}

var _players: Array[AudioStreamPlayer] = []   # two loop players, swapped for each crossfade
var _active: int = 0                          # index of the player carrying the current track
var _stinger_player: AudioStreamPlayer
var _tweens: Dictionary = {}                  # AudioStreamPlayer -> Tween still fading it
var _current: String = ""
var _intensity: float = 0.0
var _warned: Dictionary = {}


func _ready() -> void:
	add_to_group("game_music")
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep fades running under the pause menu
	for index in range(2):
		_players.append(_make_player())
	_stinger_player = _make_player()


# --- Public API (CONTRACT 4.17, plus set_zone and current_track) -------------------------------

## Starts a track. The new track fades in while the old one fades out. Repeating the current
## track does nothing. Unknown ids are reported once and ignored.
func play_track(track: String, fade: float = DEFAULT_FADE) -> void:
	if not STEMS.has(track):
		_warn_once("track:" + track, "music: unknown track '%s'" % track)
		return
	if track == _current:
		return
	var stream: AudioStream = _load_file(MUSIC_DIR + String(STEMS[track][0]) + ".wav")
	if stream == null:
		return
	var outgoing: AudioStreamPlayer = _players[_active]
	var incoming: AudioStreamPlayer = _players[1 - _active]
	_active = 1 - _active
	incoming.stream = stream
	incoming.volume_db = SILENT_DB
	incoming.play()
	_current = track
	_fade(incoming, 0.0, fade, false)
	if outgoing.playing:
		_fade(outgoing, SILENT_DB, fade, true)


## Fades the current track out and stops it. A stinger that is already playing continues.
func stop(fade: float = 1.0) -> void:
	_current = ""
	for player in _players:
		if player.playing:
			_fade(player, SILENT_DB, fade, true)


## One-shot stinger on the Music bus: "victory", "defeat" or "medal". Replaces one still playing.
func stinger(id: String) -> void:
	if not STINGERS.has(id):
		_warn_once("stinger:" + id, "music: unknown stinger '%s'" % id)
		return
	var stream: AudioStream = _load_file(MUSIC_DIR + id + ".wav")
	if stream == null:
		return
	_stinger_player.stream = stream
	_stinger_player.volume_db = 0.0
	_stinger_player.play()


## Cross-fades to the track for a zone id (floodworks, foundry or spillway). Unknown zones
## are reported once and leave the current track alone.
func set_zone(zone_id: String) -> void:
	if not ZONE_TRACKS.has(zone_id):
		_warn_once("zone:" + zone_id, "music: no track for zone '%s'" % zone_id)
		return
	play_track(String(ZONE_TRACKS[zone_id]))


## 0 calm .. 1 chase. Stored for the layered version; the MVP has no layers to crossfade.
func set_intensity(value: float) -> void:
	_intensity = clampf(value, 0.0, 1.0)


## The id of the track now playing, or "" when stopped.
func current_track() -> String:
	return _current


# --- Players and fades -------------------------------------------------------------------------

func _make_player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = BUS_MUSIC
	player.volume_db = SILENT_DB
	add_child(player)
	return player


## Tweens one player's volume. A newer fade on the same player replaces the old one, and a
## fade that stops the player stops it only when it finishes.
func _fade(player: AudioStreamPlayer, target_db: float, duration: float, stop_at_end: bool) -> void:
	var old: Tween = _tweens.get(player) as Tween
	if old != null and old.is_valid():
		old.kill()
	if duration <= 0.0:
		player.volume_db = target_db
		if stop_at_end:
			player.stop()
		return
	var tween: Tween = create_tween()
	tween.tween_property(player, "volume_db", target_db, duration)
	if stop_at_end:
		tween.tween_callback(player.stop)
	_tweens[player] = tween


func _load_file(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		_warn_once("missing:" + path, "music: %s is missing (run tools/generate_audio.gd -- --music)" % path)
		return null
	return load(path) as AudioStream


func _warn_once(key: String, message: String) -> void:
	if _warned.has(key):
		return
	_warned[key] = true
	push_warning(message)
