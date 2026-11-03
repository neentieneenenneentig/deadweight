extends SceneTree
## Offline synthesizer for DEADWEIGHT sound effects (task A1, contract 5.11).
##
## Generate (run from the project root):
##   <godot> --headless --path . --script res://tools/generate_audio.gd
## Check that every generated file loads (run after an --import pass):
##   <godot> --headless --path . --script res://tools/generate_audio.gd -- --check
##
## Each sound is a spec: layers (oscillators or noise, each with an envelope and an
## optional filter and LFO) followed by a global filter, saturation, a feedback delay
## and a small Schroeder reverb. Every file is seeded from its own name, so reruns
## produce identical bytes. Output is 44.1 kHz mono 16-bit WAV. Loops carry a WAV
## smpl chunk and a .import file that sets loop_mode to forward.

const OUT_DIR := "res://audio/sfx"
const RATE := 44100
const PEAK_LIMIT := 0.88        # about -1.1 dBFS, which keeps every file at or below -1 dBFS
const SHOT_RMS_DB := -20.0      # one loudness target for all one-shots
const LOOP_RMS_DB := -26.0      # ambient loops sit lower than one-shots
const LOOP_LEN := 3.0           # loop period in seconds; LFO and drone frequencies fit whole cycles
const LOOP_PRE := 0.5           # pre-roll so filters and LFOs reach steady state before the loop
const LOOP_XFADE := 0.5         # seam crossfade length
const VERB_TAIL := 0.7          # extra ring-out for reverbed one-shots
const SPREAD_LIMIT_DB := 6.0    # max RMS spread inside one category
const DC_LIMIT := 0.001         # max mean offset as a fraction of full scale
const SUSTAIN := Vector4(0.001, 0.01, 1.0, 0.0)  # attack, decay, sustain, release for loops
const COMB_LENGTHS := [1116, 1188, 1277, 1356]   # Freeverb-style comb lengths at 44.1 kHz
const ALLPASS_LENGTHS := [556, 225]

## Every one-shot id from contract 5.11: [id, category, variant count (0 = single file)].
const ONE_SHOTS := [
	["cast", "rod", 0], ["lock", "rod", 0], ["release", "rod", 0], ["cut", "rod", 0],
	["anchor", "rod", 0], ["recover", "rod", 0], ["spool_limit", "rod", 0], ["severed", "rod", 0],
	["weight_impact", "rod", 3], ["smash", "rod", 0], ["reel_stall", "rod", 0],
	["jump", "player", 0], ["land", "player", 0], ["land_hard", "player", 0],
	["footstep", "player", 3], ["hurt", "player", 3], ["death", "player", 0],
	["shot", "weapon", 3], ["hit", "weapon", 3], ["kill", "weapon", 0], ["reload", "weapon", 0],
	["empty", "weapon", 0], ["switch", "weapon", 0],
	["loot", "objective", 0], ["bonus", "objective", 0], ["extract_ready", "objective", 0],
	["extract_tick", "objective", 0], ["extract_break", "objective", 0], ["win", "objective", 0],
	["lose", "objective", 0], ["medal", "objective", 0], ["checkpoint", "objective", 0],
	["hound_alert", "enemy", 0], ["hound_bite", "enemy", 0], ["sentry_charge", "enemy", 0],
	["sentry_shot", "enemy", 0], ["drone_charge", "enemy", 0], ["drone_shot", "enemy", 0],
	["enemy_death", "enemy", 0],
	["hazard_zap", "world", 0], ["updraft", "world", 0], ["splash", "world", 0],
	["ui_move", "ui", 0], ["ui_accept", "ui", 0], ["ui_back", "ui", 0], ["ui_buy", "ui", 0],
	["ui_denied", "ui", 0], ["ui_unlock", "ui", 0], ["ui_toggle", "ui", 0],
]

## Loops: [id, crossfade mode]. "power" suits noise, "linear" suits exactly periodic tones.
const LOOPS := [
	["wind", "power"], ["reel", "power"], ["tension", "power"], ["drone_hum", "linear"],
]


func _init() -> void:
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	var code: int = 0
	if user_args.has("--check"):
		code = _check()
	else:
		code = _generate()
	quit(code)


## Renders every file, writes WAV plus .import, then prints the analysis table.
func _generate() -> int:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var rows: Array = []
	for item in _catalog():
		rows.append(_build_item(item))
	return _report(rows)


## Verifies that every catalog file loads as the expected AudioStreamWAV.
func _check() -> int:
	var failures: int = 0
	var count: int = 0
	for item in _catalog():
		count += 1
		var path: String = "%s/%s.wav" % [OUT_DIR, String(item["file"])]
		var wav: AudioStreamWAV = load(path) as AudioStreamWAV
		if wav == null:
			print("FAIL load %s" % path)
			failures += 1
			continue
		var expect_loop: int = AudioStreamWAV.LOOP_FORWARD if bool(item["loop"]) else AudioStreamWAV.LOOP_DISABLED
		if wav.mix_rate != RATE or wav.stereo or wav.format != AudioStreamWAV.FORMAT_16_BITS:
			print("FAIL format %s" % path)
			failures += 1
		if wav.loop_mode != expect_loop:
			print("FAIL loop_mode %s (got %d)" % [path, wav.loop_mode])
			failures += 1
		if not FileAccess.file_exists(path + ".import"):
			print("FAIL missing .import %s" % path)
			failures += 1
	print("CHECK: %d files, %d failures" % [count, failures])
	return 1 if failures > 0 else 0


## The full list of files to produce, with variants expanded.
func _catalog() -> Array:
	var items: Array = []
	for row in ONE_SHOTS:
		var id: String = row[0]
		var cat: String = row[1]
		var variants: int = row[2]
		if variants == 0:
			items.append({"file": id, "id": id, "cat": cat, "loop": false, "variant": 0, "xfade": ""})
		else:
			for v in range(1, variants + 1):
				items.append({"file": "%s_%d" % [id, v], "id": id, "cat": cat, "loop": false, "variant": v, "xfade": ""})
	for row in LOOPS:
		var loop_id: String = row[0]
		var mode: String = row[1]
		items.append({"file": loop_id, "id": loop_id, "cat": "loop", "loop": true, "variant": 0, "xfade": mode})
	return items


## Renders one catalog item, writes its WAV and .import, and returns its analysis row.
func _build_item(item: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	var variant: int = int(item["variant"])
	var id: String = String(item["id"])
	rng.seed = _seed_for("%s#%d" % [id, variant])
	# Variants get a small random pitch offset on top of their own noise seed.
	var pitch: float = 1.0
	if variant > 0:
		pitch = 1.0 + rng.randf_range(-0.035, 0.035)
	var samples := PackedInt32Array()
	var loop_end: int = 0
	var seam: Dictionary = {}
	if bool(item["loop"]):
		var loop_spec: Dictionary = _loop_spec(id)
		var raw: PackedFloat32Array = _render_loop(loop_spec, rng)
		var p: int = int(LOOP_PRE * RATE)
		var n: int = int(LOOP_LEN * RATE)
		var x: int = int(LOOP_XFADE * RATE)
		var folded: PackedFloat32Array = _fold_loop(raw, p, n, x, String(item["xfade"]))
		samples = _finish(folded, false, LOOP_RMS_DB)
		loop_end = n
		seam = _seam(samples)
	else:
		var spec: Dictionary = _spec_for(id)
		var buf: PackedFloat32Array = _render(spec, rng, pitch)
		samples = _finish(buf, true, SHOT_RMS_DB)
	var file_path: String = "%s/%s.wav" % [OUT_DIR, String(item["file"])]
	_write_bytes(file_path, _wav_bytes(samples, loop_end))
	_write_bytes(file_path + ".import", _import_text(file_path, loop_end).to_utf8_buffer())
	var stats: Dictionary = _stats(samples)
	stats["file"] = String(item["file"])
	stats["cat"] = String(item["cat"])
	stats["loop"] = bool(item["loop"])
	stats["sec"] = float(samples.size()) / float(RATE)
	stats["seam"] = seam
	return stats


## Prints the analysis table and checks every rule. Returns 0 when nothing is violated.
func _report(rows: Array) -> int:
	var violations: int = 0
	var cat_low: Dictionary = {}
	var cat_high: Dictionary = {}
	var worst_peak: float = -200.0
	var worst_peak_file: String = ""
	var worst_dc: float = 0.0
	var worst_dc_file: String = ""
	var worst_seam: float = 0.0
	print("%-17s %-9s %6s %9s %10s %9s  %s" % ["file", "category", "sec", "peak_dBFS", "dc_mean", "rms_dBFS", "seam jump/step  d2/max"])
	for item in rows:
		var row: Dictionary = item
		var file_name: String = row["file"]
		var cat: String = row["cat"]
		var peak_db: float = row["peak_db"]
		var dc: float = row["dc"]
		var rms_db: float = row["rms_db"]
		var seam_text: String = "-"
		if bool(row["loop"]):
			var seam: Dictionary = row["seam"]
			var ratio_step: float = seam["ratio_step"]
			var ratio_d2: float = seam["ratio_d2"]
			seam_text = "%5.3f  %5.3f" % [ratio_step, ratio_d2]
			worst_seam = maxf(worst_seam, maxf(ratio_step, ratio_d2))
			if ratio_step > 1.0 or ratio_d2 > 1.0:
				violations += 1
				print("VIOLATION seam %s" % file_name)
		print("%-17s %-9s %6.3f %9.2f %10.6f %9.2f  %s" % [file_name, cat, float(row["sec"]), peak_db, dc, rms_db, seam_text])
		if peak_db > -1.0:
			violations += 1
			print("VIOLATION peak %s" % file_name)
		if absf(dc) > DC_LIMIT:
			violations += 1
			print("VIOLATION dc %s" % file_name)
		if peak_db > worst_peak:
			worst_peak = peak_db
			worst_peak_file = file_name
		if absf(dc) > absf(worst_dc):
			worst_dc = dc
			worst_dc_file = file_name
		cat_low[cat] = minf(float(cat_low.get(cat, 999.0)), rms_db)
		cat_high[cat] = maxf(float(cat_high.get(cat, -999.0)), rms_db)
	print("")
	for key in cat_low.keys():
		var cat_name: String = key
		var spread: float = float(cat_high[cat_name]) - float(cat_low[cat_name])
		print("category %-9s rms %6.2f .. %6.2f dB  spread %5.2f dB (limit %.1f)" % [cat_name, float(cat_low[cat_name]), float(cat_high[cat_name]), spread, SPREAD_LIMIT_DB])
		if spread > SPREAD_LIMIT_DB:
			violations += 1
			print("VIOLATION spread %s" % cat_name)
	print("worst peak %.2f dBFS (%s)" % [worst_peak, worst_peak_file])
	print("worst |dc| %.6f (%s)" % [absf(worst_dc), worst_dc_file])
	print("worst loop seam ratio %.3f (limit 1.000)" % worst_seam)
	print("files: %d   violations: %d" % [rows.size(), violations])
	return 0 if violations == 0 else 1


# ---------------------------------------------------------------------------
# Spec helpers. A layer is a Dictionary built by _osc/_noi and refined by _flt/_lfo.
# ---------------------------------------------------------------------------

## Attack, decay, sustain, release packed into a Vector4.
func _ad(attack: float, decay: float, sustain: float, release: float) -> Vector4:
	return Vector4(attack, decay, sustain, release)


## Percussive envelope: near-instant attack, exponential decay over `decay` seconds.
func _pc(decay: float) -> Vector4:
	return Vector4(0.002, decay, 0.0, 0.0)


## hold < 0 means the layer covers the whole buffer (used by loops). hold = 0 means
## the length is the envelope length plus a little tail.
func _mk(kind: String, wave: String, f0: float, f1: float, amp: float, t0: float, env: Vector4, hold: float) -> Dictionary:
	var length: float = 0.0
	if hold > 0.0:
		length = hold
	elif hold == 0.0:
		length = env.x + env.y + env.w + 0.01
	return {
		"kind": kind, "wave": wave, "f0": f0, "f1": f1, "amp": amp, "t0": t0, "len": length,
		"env": env, "ftype": "", "ff0": 0.0, "ff1": 0.0, "fq": 0.7,
		"amd": 0.0, "arate": 0.0, "fmd": 0.0, "frate": 0.0,
	}


func _osc(wave: String, f0: float, f1: float, amp: float, t0: float, env: Vector4, hold: float = 0.0) -> Dictionary:
	return _mk("osc", wave, f0, f1, amp, t0, env, hold)


func _noi(amp: float, t0: float, env: Vector4, hold: float = 0.0) -> Dictionary:
	return _mk("noise", "", 0.0, 0.0, amp, t0, env, hold)


## Puts a state-variable filter on a layer. f0 and f1 sweep exponentially in cutoff.
func _flt(layer: Dictionary, ftype: String, f0: float, f1: float, q: float) -> Dictionary:
	layer["ftype"] = ftype
	layer["ff0"] = f0
	layer["ff1"] = f1
	layer["fq"] = q
	return layer


## Adds slow amplitude (amd, arate) and filter-cutoff (fmd, frate) wobble to a layer.
func _lfo(layer: Dictionary, amd: float, arate: float, fmd: float, frate: float) -> Dictionary:
	layer["amd"] = amd
	layer["arate"] = arate
	layer["fmd"] = fmd
	layer["frate"] = frate
	return layer


## Spec for a one-shot or loop. opts may hold: filter [type, f0, f1, q], drive,
## verb, delay [time, feedback, mix].
func _sp(dur: float, layers: Array, opts: Dictionary = {}) -> Dictionary:
	var spec: Dictionary = {
		"dur": dur, "layers": layers, "ftype": "", "ff0": 0.0, "ff1": 0.0, "fq": 0.7,
		"drive": 0.0, "verb": 0.0, "dly_t": 0.01, "dly_fb": 0.0, "dly_mix": 0.0,
	}
	if opts.has("filter"):
		var f: Array = opts["filter"]
		spec["ftype"] = f[0]
		spec["ff0"] = f[1]
		spec["ff1"] = f[2]
		spec["fq"] = f[3]
	if opts.has("drive"):
		spec["drive"] = opts["drive"]
	if opts.has("verb"):
		spec["verb"] = opts["verb"]
	if opts.has("delay"):
		var d: Array = opts["delay"]
		spec["dly_t"] = d[0]
		spec["dly_fb"] = d[1]
		spec["dly_mix"] = d[2]
	return spec


# ---------------------------------------------------------------------------
# Sound design. Times are seconds, frequencies are Hz.
# ---------------------------------------------------------------------------

func _spec_for(id: String) -> Dictionary:
	match id:
		# Rod
		"cast":
			return _sp(0.25, [
				_flt(_noi(0.5, 0.0, _ad(0.05, 0.1, 0.5, 0.1), 0.25), "bp", 400.0, 2400.0, 2.0),
				_osc("sine", 180.0, 90.0, 0.35, 0.0, _ad(0.01, 0.12, 0.4, 0.08), 0.25),
			], {"verb": 0.15})
		"lock":
			return _sp(0.1, [
				_osc("square", 1800.0, 1200.0, 0.25, 0.0, _pc(0.05), 0.07),
				_flt(_noi(0.6, 0.0, _pc(0.01), 0.02), "hp", 4000.0, 4000.0, 0.7),
			])
		"release":
			return _sp(0.15, [
				_osc("tri", 500.0, 180.0, 0.5, 0.0, _ad(0.02, 0.1, 0.2, 0.03), 0.15),
				_flt(_noi(0.25, 0.0, _pc(0.06), 0.1), "bp", 800.0, 1600.0, 2.0),
			])
		"cut":
			return _sp(0.12, [
				_osc("saw", 900.0, 300.0, 0.4, 0.0, _pc(0.08), 0.1),
				_flt(_noi(0.7, 0.0, _pc(0.03), 0.05), "hp", 4000.0, 4000.0, 0.7),
			], {"filter": ["lp", 3000.0, 3000.0, 0.7]})
		"anchor":
			return _sp(0.2, [
				_osc("sine", 120.0, 60.0, 0.9, 0.0, _pc(0.15), 0.2),
				_flt(_noi(0.4, 0.0, _pc(0.1), 0.14), "lp", 600.0, 600.0, 0.7),
			], {"drive": 0.3})
		"recover":
			return _sp(0.25, [
				_osc("tri", 300.0, 700.0, 0.5, 0.0, _ad(0.03, 0.15, 0.3, 0.03), 0.22),
				_flt(_noi(0.2, 0.0, _pc(0.02), 0.03), "bp", 2000.0, 2000.0, 3.0),
			])
		"spool_limit":
			return _sp(0.3, [
				_osc("saw", 220.0, 200.0, 0.35, 0.0, _ad(0.02, 0.1, 0.8, 0.08), 0.3),
				_flt(_noi(0.4, 0.0, _ad(0.02, 0.1, 0.6, 0.1), 0.3), "bp", 1500.0, 1500.0, 4.0),
			], {"drive": 0.2})
		"severed":
			return _sp(0.3, [
				_osc("saw", 300.0, 60.0, 0.5, 0.0, _pc(0.15), 0.16),
				_flt(_noi(0.6, 0.0, _pc(0.02), 0.03), "hp", 2000.0, 2000.0, 0.7),
			], {"delay": [0.08, 0.3, 0.25]})
		"weight_impact":
			return _sp(0.25, [
				_osc("sine", 90.0, 40.0, 0.9, 0.0, _pc(0.18), 0.2),
				_flt(_noi(0.5, 0.0, _pc(0.06), 0.08), "lp", 500.0, 500.0, 0.7),
			], {"drive": 0.3})
		"smash":
			return _sp(0.5, [
				_flt(_noi(0.8, 0.0, _pc(0.4), 0.45), "lp", 3000.0, 500.0, 0.7),
				_osc("sine", 70.0, 35.0, 0.9, 0.0, _pc(0.3), 0.35),
			], {"drive": 0.5, "verb": 0.2})
		"reel_stall":
			return _sp(0.35, [
				_osc("saw", 150.0, 60.0, 0.4, 0.0, _pc(0.3), 0.32),
				_flt(_noi(0.4, 0.0, _pc(0.2), 0.3), "bp", 900.0, 900.0, 3.0),
			])
		# Player
		"jump":
			return _sp(0.15, [
				_osc("sine", 220.0, 440.0, 0.5, 0.0, _ad(0.01, 0.12, 0.0, 0.02), 0.13),
				_flt(_noi(0.2, 0.0, _pc(0.06), 0.07), "bp", 1200.0, 1200.0, 2.0),
			])
		"land":
			return _sp(0.18, [
				_osc("sine", 110.0, 55.0, 0.8, 0.0, _pc(0.12), 0.14),
				_flt(_noi(0.4, 0.0, _pc(0.08), 0.1), "lp", 700.0, 700.0, 0.7),
			])
		"land_hard":
			return _sp(0.3, [
				_osc("sine", 90.0, 35.0, 0.9, 0.0, _pc(0.22), 0.25),
				_flt(_noi(0.7, 0.0, _pc(0.12), 0.16), "lp", 700.0, 400.0, 0.7),
			], {"drive": 0.4, "verb": 0.08})
		"footstep":
			return _sp(0.12, [
				_flt(_noi(0.6, 0.0, _pc(0.07), 0.09), "lp", 1200.0, 600.0, 0.8),
				_osc("sine", 150.0, 80.0, 0.35, 0.0, _pc(0.05), 0.07),
			])
		"hurt":
			return _sp(0.26, [
				_osc("saw", 260.0, 180.0, 0.4, 0.0, _ad(0.02, 0.15, 0.6, 0.05), 0.24),
				_flt(_noi(0.25, 0.0, _ad(0.02, 0.12, 0.5, 0.05), 0.24), "bp", 1200.0, 1000.0, 2.0),
			], {"filter": ["lp", 2000.0, 2000.0, 0.7], "drive": 0.3})
		"death":
			return _sp(1.0, [
				_osc("tri", 300.0, 50.0, 0.7, 0.0, _ad(0.01, 0.6, 0.2, 0.3), 0.9),
				_flt(_noi(0.3, 0.0, _ad(0.05, 0.5, 0.2, 0.3), 0.9), "lp", 800.0, 300.0, 0.7),
			], {"verb": 0.2})
		# Weapon
		"shot":
			return _sp(0.3, [
				_flt(_noi(1.0, 0.0, _pc(0.012), 0.02), "hp", 2500.0, 2500.0, 0.7),
				_osc("sine", 130.0, 40.0, 0.9, 0.0, _pc(0.2), 0.22),
				_flt(_noi(0.35, 0.0, _pc(0.25), 0.27), "lp", 1500.0, 600.0, 0.7),
			], {"drive": 0.6, "verb": 0.15})
		"hit":
			return _sp(0.08, [
				_osc("sine", 1700.0, 1200.0, 0.6, 0.0, _pc(0.05), 0.06),
				_flt(_noi(0.3, 0.0, _pc(0.02), 0.03), "hp", 3000.0, 3000.0, 0.7),
			])
		"kill":
			return _sp(0.2, [
				_osc("square", 600.0, 1200.0, 0.3, 0.0, _ad(0.005, 0.12, 0.0, 0.0), 0.14),
				_osc("sine", 1200.0, 1200.0, 0.35, 0.06, _pc(0.12), 0.14),
			], {"delay": [0.1, 0.25, 0.15]})
		"reload":
			return _sp(0.3, [
				_flt(_noi(0.8, 0.0, _pc(0.02), 0.03), "hp", 3000.0, 3000.0, 0.7),
				_flt(_noi(0.6, 0.22, _pc(0.03), 0.04), "bp", 1200.0, 1200.0, 3.0),
				_osc("square", 400.0, 400.0, 0.3, 0.22, _pc(0.03), 0.05),
			])
		"empty":
			return _sp(0.06, [
				_osc("square", 1000.0, 1000.0, 0.3, 0.0, _pc(0.02), 0.03),
				_flt(_noi(0.5, 0.0, _pc(0.01), 0.015), "hp", 4000.0, 4000.0, 0.7),
			])
		"switch":
			return _sp(0.15, [
				_flt(_noi(0.4, 0.0, _ad(0.04, 0.04, 0.3, 0.03), 0.1), "bp", 1000.0, 3000.0, 2.5),
				_osc("square", 800.0, 800.0, 0.25, 0.09, _pc(0.02), 0.03),
			])
		# Objective
		"loot":
			return _sp(0.35, [
				_osc("sine", 1320.0, 1320.0, 0.6, 0.0, _pc(0.25), 0.27),
				_osc("sine", 1980.0, 1980.0, 0.35, 0.04, _pc(0.2), 0.22),
			], {"verb": 0.2})
		"bonus":
			return _sp(0.5, [
				_osc("sine", 880.0, 880.0, 0.5, 0.0, _pc(0.2), 0.22),
				_osc("sine", 1175.0, 1175.0, 0.5, 0.07, _pc(0.2), 0.22),
				_osc("sine", 1480.0, 1480.0, 0.5, 0.14, _pc(0.25), 0.27),
			], {"delay": [0.1, 0.3, 0.25]})
		"extract_ready":
			return _sp(0.4, [
				_osc("tri", 440.0, 440.0, 0.6, 0.0, _ad(0.005, 0.1, 0.5, 0.03), 0.14),
				_osc("tri", 660.0, 660.0, 0.6, 0.14, _ad(0.005, 0.15, 0.4, 0.05), 0.22),
			], {"verb": 0.2})
		"extract_tick":
			return _sp(0.05, [
				_osc("sine", 2000.0, 2000.0, 0.5, 0.0, _pc(0.02), 0.03),
				_flt(_noi(0.4, 0.0, _pc(0.005), 0.008), "hp", 5000.0, 5000.0, 0.7),
			])
		"extract_break":
			return _sp(0.35, [
				_osc("saw", 500.0, 200.0, 0.5, 0.0, _pc(0.25), 0.27),
				_flt(_noi(0.4, 0.0, _pc(0.2), 0.25), "bp", 1500.0, 1500.0, 4.0),
			], {"drive": 0.3})
		"win":
			return _sp(0.9, [
				_osc("sine", 523.0, 523.0, 0.5, 0.0, _ad(0.005, 0.3, 0.3, 0.1), 0.4),
				_osc("sine", 659.0, 659.0, 0.5, 0.12, _ad(0.005, 0.3, 0.3, 0.1), 0.4),
				_osc("sine", 784.0, 784.0, 0.5, 0.24, _ad(0.005, 0.3, 0.3, 0.15), 0.5),
				_osc("square", 1046.0, 1046.0, 0.2, 0.36, _ad(0.005, 0.4, 0.2, 0.2), 0.55),
			], {"verb": 0.3})
		"lose":
			return _sp(0.8, [
				_osc("tri", 392.0, 196.0, 0.6, 0.0, _ad(0.01, 0.3, 0.3, 0.1), 0.4),
				_osc("tri", 196.0, 98.0, 0.6, 0.3, _ad(0.01, 0.4, 0.2, 0.2), 0.5),
			], {"filter": ["lp", 1500.0, 1500.0, 0.7], "verb": 0.2})
		"medal":
			return _sp(0.7, [
				_osc("sine", 1568.0, 1568.0, 0.5, 0.0, _pc(0.4), 0.42),
				_osc("sine", 2093.0, 2093.0, 0.4, 0.1, _pc(0.35), 0.37),
				_osc("sine", 2637.0, 2637.0, 0.35, 0.2, _pc(0.3), 0.32),
			], {"verb": 0.3})
		"checkpoint":
			return _sp(0.4, [
				_osc("sine", 660.0, 660.0, 0.5, 0.0, _pc(0.3), 0.32),
				_osc("sine", 990.0, 990.0, 0.4, 0.08, _pc(0.3), 0.32),
			], {"verb": 0.15})
		# Enemy (positional)
		"hound_alert":
			return _sp(0.4, [
				_osc("saw", 180.0, 120.0, 0.5, 0.0, _ad(0.05, 0.1, 0.6, 0.1), 0.3),
				_flt(_noi(0.4, 0.0, _ad(0.05, 0.1, 0.6, 0.1), 0.3), "bp", 500.0, 500.0, 3.0),
			], {"drive": 0.5})
		"hound_bite":
			return _sp(0.2, [
				_flt(_noi(0.8, 0.0, _pc(0.05), 0.06), "bp", 1800.0, 1800.0, 2.0),
				_osc("sine", 220.0, 90.0, 0.6, 0.0, _pc(0.1), 0.11),
			], {"drive": 0.4})
		"sentry_charge":
			return _sp(0.6, [
				_osc("sine", 300.0, 1200.0, 0.5, 0.0, _ad(0.1, 0.1, 0.8, 0.1), 0.6),
				_osc("tri", 150.0, 600.0, 0.2, 0.0, _ad(0.1, 0.1, 0.8, 0.1), 0.6),
			], {"filter": ["lp", 3000.0, 3000.0, 0.7]})
		"sentry_shot":
			return _sp(0.25, [
				_osc("saw", 1800.0, 300.0, 0.5, 0.0, _pc(0.15), 0.17),
			], {"delay": [0.08, 0.3, 0.2]})
		"drone_charge":
			return _sp(0.5, [
				_osc("square", 150.0, 400.0, 0.4, 0.0, _ad(0.05, 0.1, 0.8, 0.1), 0.5),
			], {"filter": ["lp", 1500.0, 1500.0, 1.0]})
		"drone_shot":
			return _sp(0.12, [
				_osc("sine", 700.0, 250.0, 0.7, 0.0, _pc(0.08), 0.09),
				_flt(_noi(0.4, 0.0, _pc(0.02), 0.03), "hp", 3000.0, 3000.0, 0.7),
			])
		"enemy_death":
			return _sp(0.45, [
				_flt(_noi(0.7, 0.0, _pc(0.3), 0.32), "bp", 1200.0, 300.0, 3.0),
				_osc("saw", 200.0, 40.0, 0.5, 0.0, _pc(0.3), 0.32),
			], {"drive": 0.6})
		# World
		"hazard_zap":
			return _sp(0.25, [
				_osc("saw", 900.0, 300.0, 0.4, 0.0, _pc(0.18), 0.2),
				_flt(_noi(0.4, 0.0, _ad(0.005, 0.1, 0.5, 0.05), 0.2), "hp", 4000.0, 4000.0, 0.7),
			], {"drive": 0.5})
		"updraft":
			return _sp(1.0, [
				_flt(_noi(0.6, 0.0, _ad(0.3, 0.3, 0.7, 0.3), 0.9), "bp", 300.0, 1200.0, 1.5),
				_osc("sine", 160.0, 220.0, 0.25, 0.0, _ad(0.3, 0.3, 0.7, 0.3), 0.9),
			], {"verb": 0.3})
		"splash":
			return _sp(0.5, [
				_flt(_noi(0.7, 0.0, _pc(0.4), 0.45), "lp", 2500.0, 400.0, 0.7),
				_flt(_noi(0.4, 0.02, _pc(0.15), 0.17), "bp", 800.0, 800.0, 1.5),
			], {"verb": 0.1})
		# UI
		"ui_move":
			return _sp(0.05, [
				_osc("sine", 1200.0, 1200.0, 0.4, 0.0, _pc(0.02), 0.03),
				_flt(_noi(0.3, 0.0, _pc(0.005), 0.008), "hp", 6000.0, 6000.0, 0.7),
			])
		"ui_accept":
			return _sp(0.2, [
				_osc("sine", 1047.0, 1047.0, 0.5, 0.0, _ad(0.003, 0.07, 0.3, 0.03), 0.1),
				_osc("sine", 1568.0, 1568.0, 0.5, 0.06, _ad(0.003, 0.08, 0.3, 0.05), 0.13),
			])
		"ui_back":
			return _sp(0.15, [
				_osc("sine", 660.0, 440.0, 0.5, 0.0, _ad(0.003, 0.1, 0.2, 0.03), 0.13),
			])
		"ui_buy":
			return _sp(0.2, [
				_osc("sine", 1320.0, 1320.0, 0.5, 0.0, _pc(0.1), 0.11),
				_osc("sine", 1760.0, 1760.0, 0.5, 0.07, _pc(0.15), 0.16),
			])
		"ui_denied":
			return _sp(0.45, [
				_osc("square", 180.0, 170.0, 0.3, 0.0, _ad(0.005, 0.15, 0.5, 0.03), 0.2),
				_osc("square", 150.0, 140.0, 0.3, 0.22, _ad(0.005, 0.15, 0.5, 0.03), 0.2),
			], {"filter": ["lp", 1500.0, 1500.0, 0.7]})
		"ui_unlock":
			return _sp(0.6, [
				_osc("sine", 523.0, 523.0, 0.5, 0.0, _ad(0.003, 0.15, 0.2, 0.04), 0.22),
				_osc("sine", 659.0, 659.0, 0.5, 0.08, _ad(0.003, 0.15, 0.2, 0.04), 0.22),
				_osc("sine", 784.0, 784.0, 0.5, 0.16, _ad(0.003, 0.15, 0.2, 0.04), 0.22),
				_osc("sine", 1046.0, 1046.0, 0.5, 0.24, _ad(0.003, 0.15, 0.2, 0.04), 0.22),
			], {"delay": [0.1, 0.3, 0.2]})
		"ui_toggle":
			return _sp(0.04, [
				_flt(_noi(0.5, 0.0, _pc(0.012), 0.02), "bp", 2500.0, 2500.0, 2.0),
				_osc("sine", 900.0, 900.0, 0.4, 0.0, _pc(0.02), 0.03),
			])
		_:
			push_error("generate_audio: no spec for id %s" % id)
			return _sp(0.1, [])


## Loop specs. Layers use hold -1 so they fill the whole raw buffer. Frequencies and
## LFO rates are whole cycles per LOOP_LEN, so the drone is exactly periodic.
func _loop_spec(id: String) -> Dictionary:
	match id:
		"wind":
			return _sp(LOOP_LEN, [
				_lfo(_flt(_noi(0.6, 0.0, SUSTAIN, -1.0), "lp", 450.0, 450.0, 0.8), 0.35, 0.3333, 200.0, 0.3333),
				_lfo(_flt(_noi(0.35, 0.0, SUSTAIN, -1.0), "bp", 1200.0, 1200.0, 1.0), 0.3, 0.6667, 0.0, 0.0),
			])
		"reel":
			return _sp(LOOP_LEN, [
				_lfo(_osc("square", 110.0, 110.0, 0.3, 0.0, SUSTAIN, -1.0), 0.5, 5.0, 0.0, 0.0),
				_lfo(_osc("saw", 220.0, 220.0, 0.15, 0.0, SUSTAIN, -1.0), 0.4, 5.0, 0.0, 0.0),
				_flt(_lfo(_noi(0.25, 0.0, SUSTAIN, -1.0), 0.5, 5.0, 0.0, 0.0), "bp", 1500.0, 1500.0, 6.0),
			], {"filter": ["lp", 1200.0, 1200.0, 0.7]})
		"tension":
			return _sp(LOOP_LEN, [
				_flt(_lfo(_noi(0.5, 0.0, SUSTAIN, -1.0), 0.8, 0.3333, 160.0, 0.6667), "bp", 320.0, 320.0, 9.0),
				_osc("saw", 55.0, 55.0, 0.12, 0.0, SUSTAIN, -1.0),
			], {"drive": 0.2})
		"drone_hum":
			return _sp(LOOP_LEN, [
				_osc("sine", 55.0, 55.0, 0.5, 0.0, SUSTAIN, -1.0),
				_osc("sine", 110.0, 110.0, 0.22, 0.0, SUSTAIN, -1.0),
				_osc("sine", 165.0, 165.0, 0.09, 0.0, SUSTAIN, -1.0),
				_osc("sine", 58.0, 58.0, 0.14, 0.0, SUSTAIN, -1.0),
				_osc("tri", 220.0, 220.0, 0.04, 0.0, SUSTAIN, -1.0),
			], {"drive": 0.15})
		_:
			push_error("generate_audio: no loop spec for id %s" % id)
			return _sp(LOOP_LEN, [])


# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

## Renders a one-shot: layers into a buffer with a tail for reverb and delay, then post effects.
func _render(spec: Dictionary, rng: RandomNumberGenerator, pitch: float) -> PackedFloat32Array:
	var tail: float = 0.0
	if float(spec["verb"]) > 0.0:
		tail = VERB_TAIL
	if float(spec["dly_mix"]) > 0.0:
		tail = maxf(tail, float(spec["dly_t"]) * 5.0)
	var total: int = int((float(spec["dur"]) + tail) * RATE)
	var buf := PackedFloat32Array()
	buf.resize(total)
	for item in spec["layers"]:
		var layer: Dictionary = item
		_mix_layer(buf, layer, rng, pitch)
	_apply_post(buf, spec)
	return buf


## Renders the whole raw loop buffer: pre-roll, body and crossfade tail.
func _render_loop(spec: Dictionary, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var total: int = int(LOOP_PRE * RATE) + int(LOOP_LEN * RATE) + int(LOOP_XFADE * RATE)
	var buf := PackedFloat32Array()
	buf.resize(total)
	for item in spec["layers"]:
		var layer: Dictionary = item
		_mix_layer(buf, layer, rng, 1.0)
	_apply_post(buf, spec)
	return buf


## Adds one layer into the target buffer, starting at its t0 offset.
func _mix_layer(target: PackedFloat32Array, layer: Dictionary, rng: RandomNumberGenerator, pitch: float) -> void:
	var start: int = int(float(layer["t0"]) * RATE)
	var count: int = int(float(layer["len"]) * RATE)
	if count <= 0:
		count = target.size() - start
	count = mini(count, target.size() - start)
	if start < 0 or count <= 0:
		return
	var seg := PackedFloat32Array()
	seg.resize(count)
	var is_noise: bool = String(layer["kind"]) == "noise"
	var wave_mode: int = _wave_mode(String(layer["wave"]))
	var f0: float = float(layer["f0"]) * pitch
	var f1: float = float(layer["f1"]) * pitch
	var env: Vector4 = layer["env"]
	var amp: float = float(layer["amp"])
	var amd: float = float(layer["amd"])
	var arate: float = float(layer["arate"])
	var total: float = float(count) / float(RATE)
	var phase: float = 0.0
	for i in range(count):
		var t: float = float(i) / float(RATE)
		var source: float = 0.0
		if is_noise:
			source = rng.randf_range(-1.0, 1.0)
		else:
			var freq: float = _sweep(f0, f1, t / total)
			phase = fposmod(phase + freq / float(RATE), 1.0)
			source = _wave_value(wave_mode, phase)
		var gain: float = amp * _env_at(t, total, env)
		if amd > 0.0:
			gain *= 1.0 - amd * (0.5 + 0.5 * sin(TAU * arate * t))
		seg[i] = source * gain
	var ftype: String = String(layer["ftype"])
	if ftype != "":
		_svf_inplace(seg, _filter_mode(ftype), float(layer["ff0"]), float(layer["ff1"]),
			float(layer["fq"]), float(layer["fmd"]), float(layer["frate"]))
	for i in range(count):
		target[start + i] += seg[i]


## Global post chain shared by one-shots and loops.
func _apply_post(buf: PackedFloat32Array, spec: Dictionary) -> void:
	var ftype: String = String(spec["ftype"])
	if ftype != "":
		_svf_inplace(buf, _filter_mode(ftype), float(spec["ff0"]), float(spec["ff1"]), float(spec["fq"]), 0.0, 0.0)
	var drive: float = float(spec["drive"])
	if drive > 0.0:
		_drive(buf, drive)
	var dly_mix: float = float(spec["dly_mix"])
	if dly_mix > 0.0:
		_delay(buf, float(spec["dly_t"]), float(spec["dly_fb"]), dly_mix)
	var verb: float = float(spec["verb"])
	if verb > 0.0:
		_reverb(buf, verb)


## Builds the seamless loop. raw[p .. p+n+x) is steady state. The first x output samples
## blend the head with the continuation that follows the loop end, so the wrap from
## output[n-1] to output[0] continues the waveform. Periodic content is unchanged.
func _fold_loop(raw: PackedFloat32Array, p: int, n: int, x: int, mode: String) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	for i in range(n):
		var head: float = raw[p + i]
		if i < x:
			var w: float = float(i) / float(x)
			var cont: float = raw[p + n + i]
			var wa: float = 1.0 - w
			var wb: float = w
			if mode == "power":
				wa = cos(w * PI * 0.5)
				wb = sin(w * PI * 0.5)
			out[i] = wa * cont + wb * head
		else:
			out[i] = head
	return out


## Chamberlin state-variable filter, run in place. mode: 0 lp, 1 bp, 2 hp. The cutoff
## sweeps linearly from f0 to f1 and can wobble by fmd Hz at frate Hz.
func _svf_inplace(buf: PackedFloat32Array, mode: int, f0: float, f1: float, q: float, fmd: float, frate: float) -> void:
	var low: float = 0.0
	var band: float = 0.0
	var damp: float = 1.0 / maxf(q, 0.3)
	var n: int = buf.size()
	for i in range(n):
		var progress: float = float(i) / float(maxi(n, 1))
		var t: float = float(i) / float(RATE)
		var fc: float = lerpf(f0, f1, progress) + fmd * sin(TAU * frate * t)
		fc = clampf(fc, 20.0, 7000.0)  # Chamberlin form is only stable below about fs/6
		var f: float = 2.0 * sin(PI * fc / float(RATE))
		var x: float = buf[i]
		low += f * band
		var high: float = x - low - damp * band
		band += f * high
		var y: float = low
		if mode == 1:
			y = band
		elif mode == 2:
			y = high
		buf[i] = y


## Tanh saturation, normalised so a full-scale input still maps to full scale.
func _drive(buf: PackedFloat32Array, amount: float) -> void:
	var k: float = 1.0 + amount * 8.0
	var norm: float = tanh(k)
	for i in range(buf.size()):
		buf[i] = tanh(k * buf[i]) / norm


## Feedback delay: dry plus mix * echo, with the echo fed back at fb.
func _delay(buf: PackedFloat32Array, time: float, fb: float, mix: float) -> void:
	var n: int = maxi(1, int(time * RATE))
	var line := PackedFloat32Array()
	line.resize(n)
	var idx: int = 0
	for i in range(buf.size()):
		var echo: float = line[idx]
		var dry: float = buf[i]
		buf[i] = dry + echo * mix
		line[idx] = dry + echo * fb
		idx = (idx + 1) % n


## Small Schroeder reverb: four combs in parallel, then two allpasses.
func _reverb(buf: PackedFloat32Array, mix: float) -> void:
	var n: int = buf.size()
	var wet := PackedFloat32Array()
	wet.resize(n)
	for length in COMB_LENGTHS:
		var comb_out: PackedFloat32Array = _comb(buf, int(length), 0.8, 0.2)
		for i in range(n):
			wet[i] += comb_out[i] * 0.25
	for length in ALLPASS_LENGTHS:
		wet = _allpass(wet, int(length))
	for i in range(n):
		buf[i] += wet[i] * mix


func _comb(input: PackedFloat32Array, length: int, feedback: float, damp: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(input.size())
	var line := PackedFloat32Array()
	line.resize(length)
	var idx: int = 0
	var store: float = 0.0
	for i in range(input.size()):
		var y: float = line[idx]
		out[i] = y
		store = y * (1.0 - damp) + store * damp
		line[idx] = input[i] + store * feedback
		idx = (idx + 1) % length
	return out


func _allpass(input: PackedFloat32Array, length: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(input.size())
	var line := PackedFloat32Array()
	line.resize(length)
	var idx: int = 0
	for i in range(input.size()):
		var buf_out: float = line[idx]
		var x: float = input[i]
		out[i] = -x + buf_out
		line[idx] = x + buf_out * 0.5
		idx = (idx + 1) % length
	return out


func _edge_fade(buf: PackedFloat32Array) -> void:
	var n: int = buf.size()
	var fade_in: int = mini(44, n)
	for i in range(fade_in):
		buf[i] *= float(i) / float(fade_in)
	var fade_out: int = mini(882, n)
	for k in range(fade_out):
		buf[n - 1 - k] *= float(k) / float(fade_out)


## Removes the DC offset, normalises RMS to target_db, then limits the peak to PEAK_LIMIT.
## Returns the quantised 16-bit samples.
func _finish(buf: PackedFloat32Array, edges: bool, target_db: float) -> PackedInt32Array:
	var n: int = buf.size()
	if edges:
		_edge_fade(buf)
	var mean: float = 0.0
	for v in buf:
		mean += v
	mean /= float(maxi(n, 1))
	var energy: float = 0.0
	var peak: float = 0.0
	for i in range(n):
		buf[i] -= mean
		energy += buf[i] * buf[i]
		peak = maxf(peak, absf(buf[i]))
	var rms: float = _gated_rms(buf)
	var gain: float = pow(10.0, target_db / 20.0) / maxf(rms, 1e-9)
	if peak * gain > PEAK_LIMIT:
		gain = PEAK_LIMIT / peak
	var out := PackedInt32Array()
	out.resize(n)
	for i in range(n):
		out[i] = clampi(roundi(buf[i] * gain * 32767.0), -32767, 32767)
	return out


# ---------------------------------------------------------------------------
# Analysis
# ---------------------------------------------------------------------------

## RMS over the active part of a sound. 10 ms blocks more than 40 dB below the loudest
## block are ignored, so long quiet delay or reverb tails do not pull the loudness down.
func _gated_rms(buf: PackedFloat32Array) -> float:
	var block: int = 441
	var blocks: int = buf.size() / block
	if blocks < 1:
		return 0.0
	var levels := PackedFloat32Array()
	levels.resize(blocks)
	var max_level: float = 0.0
	for b in range(blocks):
		var e: float = 0.0
		for i in range(b * block, (b + 1) * block):
			e += buf[i] * buf[i]
		levels[b] = e / float(block)
		max_level = maxf(max_level, levels[b])
	var gate: float = max_level * 1e-4  # -40 dB in power
	var energy: float = 0.0
	var count: int = 0
	for b in range(blocks):
		if levels[b] >= gate:
			energy += levels[b] * float(block)
			count += block
	return sqrt(energy / float(maxi(count, 1)))


## Peak and gated RMS in dBFS, and the mean as a fraction of full scale.
func _stats(samples: PackedInt32Array) -> Dictionary:
	var peak: int = 0
	var total: float = 0.0
	var as_float := PackedFloat32Array()
	as_float.resize(samples.size())
	for i in range(samples.size()):
		var s: int = samples[i]
		peak = maxi(peak, absi(s))
		total += float(s)
		as_float[i] = float(s) / 32768.0
	var n: float = float(maxi(samples.size(), 1))
	var peak_f: float = float(peak) / 32768.0
	var rms_f: float = _gated_rms(as_float)
	return {
		"peak_db": 20.0 * log(maxf(peak_f, 1e-9)) / log(10.0),
		"dc": total / n / 32768.0,
		"rms_db": 20.0 * log(maxf(rms_f, 1e-9)) / log(10.0),
	}


## Seam metrics for a loop. ratio_step = |y0 - y(n-1)| / max internal step.
## ratio_d2 = |second difference at the seam| / max internal second difference.
## Both must be at most 1 for the seam to be no rougher than the loop body.
func _seam(samples: PackedInt32Array) -> Dictionary:
	var n: int = samples.size()
	var max_step: int = 1
	var max_d2: int = 1
	for i in range(n - 1):
		max_step = maxi(max_step, absi(samples[i + 1] - samples[i]))
	for i in range(1, n - 1):
		max_d2 = maxi(max_d2, absi(samples[i + 1] - 2 * samples[i] + samples[i - 1]))
	var jump: int = absi(samples[0] - samples[n - 1])
	var seam_d2: int = absi(samples[1] - 2 * samples[0] + samples[n - 1])
	return {
		"jump": jump,
		"ratio_step": float(jump) / float(max_step),
		"ratio_d2": float(seam_d2) / float(max_d2),
	}


# ---------------------------------------------------------------------------
# Small utilities
# ---------------------------------------------------------------------------

## Cutoff or pitch sweep between f0 and f1 (exponential for pitch).
func _sweep(f0: float, f1: float, progress: float) -> float:
	if f0 <= 0.0 or f1 <= 0.0:
		return f0
	return f0 * pow(f1 / f0, progress)


## Envelope value at time t (seconds) in a layer lasting total seconds.
func _env_at(t: float, total: float, env: Vector4) -> float:
	var attack: float = env.x
	var decay: float = env.y
	var sustain: float = env.z
	var release: float = env.w
	var level: float = sustain
	if t < attack:
		level = t / attack
	elif t < attack + decay:
		level = sustain + (1.0 - sustain) * exp(-5.0 * (t - attack) / decay)
	if release > 0.0 and t > total - release:
		level *= clampf((total - t) / release, 0.0, 1.0)
	return level


func _wave_mode(wave: String) -> int:
	match wave:
		"tri":
			return 1
		"saw":
			return 2
		"square":
			return 3
	return 0


func _wave_value(mode: int, phase: float) -> float:
	if mode == 1:
		return 4.0 * absf(phase - 0.5) - 1.0
	if mode == 2:
		return 2.0 * phase - 1.0
	if mode == 3:
		return 1.0 if phase < 0.5 else -1.0
	return sin(TAU * phase)


func _filter_mode(ftype: String) -> int:
	if ftype == "bp":
		return 1
	if ftype == "hp":
		return 2
	return 0


## FNV-1a 32-bit hash of the text. It does not depend on the engine, so seeds are stable.
func _seed_for(text: String) -> int:
	var hash_value: int = 2166136261
	for b in text.to_utf8_buffer():
		hash_value = ((hash_value ^ int(b)) * 16777619) & 0xFFFFFFFF
	return hash_value


func _import_text(wav_path: String, loop_end: int) -> String:
	var loop_mode: int = 2 if loop_end > 0 else 1  # 2 = forward, 1 = disabled
	var lines: PackedStringArray = PackedStringArray([
		"[remap]", "", "importer=\"wave\"", "type=\"AudioStreamWAV\"", "",
		"[deps]", "", "source_file=\"%s\"" % wav_path, "",
		"[params]", "",
		"compress/mode=0",
		"edit/trim=false",
		"edit/normalize=false",
		"edit/loop_mode=%d" % loop_mode,
		"edit/loop_begin=0",
		"edit/loop_end=%d" % loop_end,
		"force/8_bit=false",
		"force/mono=false",
		"force/max_rate=false",
		"force/max_rate_hz=44100",
		"",
	])
	return "\n".join(lines)


## RIFF/WAVE mono 16-bit at RATE. When loop_end > 0 an smpl chunk marks the loop.
func _wav_bytes(samples: PackedInt32Array, loop_end: int) -> PackedByteArray:
	var body := PackedByteArray()
	body.append_array("WAVE".to_ascii_buffer())
	body.append_array("fmt ".to_ascii_buffer())
	body.append_array(_u32(16))
	body.append_array(_u16(1))          # PCM
	body.append_array(_u16(1))          # mono
	body.append_array(_u32(RATE))
	body.append_array(_u32(RATE * 2))   # byte rate
	body.append_array(_u16(2))          # block align
	body.append_array(_u16(16))         # bits per sample
	if loop_end > 0:
		body.append_array("smpl".to_ascii_buffer())
		body.append_array(_u32(60))
		body.append_array(_u32(0))      # manufacturer
		body.append_array(_u32(0))      # product
		body.append_array(_u32(0))      # sample period
		body.append_array(_u32(60))     # midi unity note
		body.append_array(_u32(0))      # midi pitch fraction
		body.append_array(_u32(0))      # smpte format
		body.append_array(_u32(0))      # smpte offset
		body.append_array(_u32(1))      # number of loops
		body.append_array(_u32(0))      # sampler data
		body.append_array(_u32(0))      # loop cue id
		body.append_array(_u32(0))      # loop type 0 = forward
		body.append_array(_u32(0))      # loop start
		body.append_array(_u32(loop_end - 1))  # loop end (inclusive)
		body.append_array(_u32(0))      # fraction
		body.append_array(_u32(0))      # play count, 0 = infinite
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in range(samples.size()):
		data.encode_s16(i * 2, samples[i])
	body.append_array("data".to_ascii_buffer())
	body.append_array(_u32(data.size()))
	body.append_array(data)
	var file := PackedByteArray()
	file.append_array("RIFF".to_ascii_buffer())
	file.append_array(_u32(body.size()))
	file.append_array(body)
	return file


func _u16(value: int) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(2)
	bytes.encode_u16(0, value)
	return bytes


func _u32(value: int) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(4)
	bytes.encode_u32(0, value)
	return bytes


func _write_bytes(path: String, data: PackedByteArray) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("generate_audio: cannot write %s" % path)
		return
	file.store_buffer(data)
	file.close()
