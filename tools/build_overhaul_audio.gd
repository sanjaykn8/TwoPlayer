extends SceneTree
## Synthesises the overhaul's sound effects offline (the asset bundle has only six sounds).
## Deterministic: a fixed random seed, so rebuilding gives identical files.
##   godot --headless --path . --script res://tools/build_overhaul_audio.gd
##   godot --headless --path . --import
## Output: res://assets/created/sfx/*.wav (16-bit mono, 22050 Hz). Cues that use them are in
## resources/config/audio_config.tres.

const RATE := 22050
const OUT := "res://assets/created/sfx/"

var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 20261108
	DirAccess.make_dir_recursive_absolute(OUT)
	_write("swing", _swing(0.11, 2600.0, 900.0, 0.55))
	_write("swing_heavy", _mix(_swing(0.2, 1500.0, 350.0, 0.7), _thump(0.16, 95.0, 55.0, 0.55)))
	_write("charge_ready", _blips([880.0, 1320.0], 0.05, 0.35))
	_write("coop", _blips([1046.5, 1318.5, 1568.0, 2093.0], 0.055, 0.32))
	_write("clang", _metal(0.32, [1180.0, 1730.0, 2650.0, 3420.0], 0.6))
	_write("arrow", _swing(0.09, 4200.0, 2400.0, 0.45))
	_write("arrow_hit", _metal(0.08, [900.0, 1500.0], 0.35))
	_write("bat", _chirps(2, 0.045, 3200.0, 2100.0, 0.3))
	_write("spring", _boing(0.28, 180.0, 620.0, 0.5))
	_write("fire", _noise_burst(0.42, 0.18, 0.5, 0.35))
	_write("rock", _mix(_thump(0.22, 120.0, 45.0, 0.6), _noise_burst(0.18, 0.4, 0.2, 0.35)))
	_write("slam", _mix(_thump(0.36, 80.0, 32.0, 0.8), _noise_burst(0.3, 0.3, 0.25, 0.45)))
	_write("break", _crunch(0.24, 0.55))
	_write("roar", _roar(0.8, 120.0, 70.0, 0.55))
	_write("fuse", _fuse(0.6, 0.3))
	_write("blast", _mix(_thump(0.45, 70.0, 28.0, 0.8), _noise_burst(0.42, 0.55, 0.3, 0.6)))
	_write("orc_alert", _roar(0.22, 180.0, 140.0, 0.4))
	_write("shoot_draw", _creak(0.3, 0.22))
	quit()


# --- Building blocks ---------------------------------------------------------------------

func _samples(seconds: float) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(int(seconds * RATE))
	return buf


## Band-swept noise "whoosh": a one-pole low-pass whose cutoff glides from `f0` to `f1`.
func _swing(seconds: float, f0: float, f1: float, gain: float) -> PackedFloat32Array:
	var buf := _samples(seconds)
	var lp := 0.0
	var hp_prev := 0.0
	var hp := 0.0
	for i in buf.size():
		var t := float(i) / buf.size()
		var cutoff := lerpf(f0, f1, t)
		var a := 1.0 - exp(-TAU * cutoff / RATE)
		lp += a * (_rng.randf_range(-1.0, 1.0) - lp)
		hp = 0.92 * (hp + lp - hp_prev)
		hp_prev = lp
		var env := sin(PI * minf(t * 1.6, 1.0)) * (1.0 - t)
		buf[i] = hp * env * gain * 2.2
	return buf


## Low sine whose pitch drops from `f0` to `f1`, fast decay.
func _thump(seconds: float, f0: float, f1: float, gain: float) -> PackedFloat32Array:
	var buf := _samples(seconds)
	var phase := 0.0
	for i in buf.size():
		var t := float(i) / buf.size()
		phase += TAU * lerpf(f0, f1, t) / RATE
		buf[i] = sin(phase) * exp(-4.5 * t) * gain
	return buf


## Short square blips in sequence (bright interface-like confirmation).
func _blips(freqs: Array, each: float, gain: float) -> PackedFloat32Array:
	var buf := _samples(each * freqs.size() + 0.05)
	var n := int(each * RATE)
	for k in freqs.size():
		var phase := 0.0
		for j in n:
			var i := k * n + j
			if i >= buf.size():
				break
			phase += TAU * float(freqs[k]) / RATE
			var env := exp(-3.0 * float(j) / n)
			buf[i] += (1.0 if sin(phase) >= 0.0 else -1.0) * env * gain * 0.6
	return buf


## Inharmonic partials with exponential decay plus a click: struck metal.
func _metal(seconds: float, partials: Array, gain: float) -> PackedFloat32Array:
	var buf := _samples(seconds)
	for i in buf.size():
		var t := float(i) / RATE
		var v := 0.0
		for k in partials.size():
			v += sin(TAU * float(partials[k]) * t) * exp(-t * (9.0 + k * 4.0)) / (k + 1)
		if i < 60:
			v += _rng.randf_range(-1.0, 1.0) * (1.0 - i / 60.0)
		buf[i] = v * gain * 0.7
	return buf


func _chirps(count: int, each: float, f0: float, f1: float, gain: float) -> PackedFloat32Array:
	var buf := _samples(count * each * 1.8)
	var n := int(each * RATE)
	for k in count:
		var phase := 0.0
		var start := int(k * each * 1.8 * RATE)
		for j in n:
			var t := float(j) / n
			phase += TAU * lerpf(f0, f1, t) / RATE
			if start + j < buf.size():
				buf[start + j] = sin(phase) * sin(PI * t) * gain
	return buf


func _boing(seconds: float, f0: float, f1: float, gain: float) -> PackedFloat32Array:
	var buf := _samples(seconds)
	var phase := 0.0
	for i in buf.size():
		var t := float(i) / buf.size()
		var f := lerpf(f0, f1, sqrt(t)) * (1.0 + 0.06 * sin(t * 60.0))
		phase += TAU * f / RATE
		buf[i] = sin(phase) * (1.0 - t) * gain
	return buf


## Low-passed noise with a soft attack: fire, dust, rumble. `bright` 0..1 sets the cutoff.
func _noise_burst(seconds: float, bright: float, attack: float, gain: float) -> PackedFloat32Array:
	var buf := _samples(seconds)
	var lp := 0.0
	var a := clampf(bright, 0.02, 1.0)
	for i in buf.size():
		var t := float(i) / buf.size()
		lp += a * (_rng.randf_range(-1.0, 1.0) - lp)
		var env := minf(t / maxf(attack, 0.01), 1.0) * (1.0 - t)
		var crackle := 1.0 + (2.5 if _rng.randf() < 0.004 else 0.0)
		buf[i] = lp * env * gain * crackle * 1.8
	return buf


func _crunch(seconds: float, gain: float) -> PackedFloat32Array:
	var buf := _samples(seconds)
	var lp := 0.0
	for i in buf.size():
		var t := float(i) / buf.size()
		lp += 0.35 * (_rng.randf_range(-1.0, 1.0) - lp)
		var grain := 1.0 if int(t * 26.0) % 2 == 0 else 0.35
		buf[i] = lp * grain * (1.0 - t) * gain * 2.0
	return buf


## Sawtooth growl with tremolo and breath noise.
func _roar(seconds: float, f0: float, f1: float, gain: float) -> PackedFloat32Array:
	var buf := _samples(seconds)
	var phase := 0.0
	var lp := 0.0
	for i in buf.size():
		var t := float(i) / buf.size()
		phase = fmod(phase + lerpf(f0, f1, t) / RATE, 1.0)
		var saw := phase * 2.0 - 1.0
		lp += 0.25 * (saw + _rng.randf_range(-0.6, 0.6) - lp)
		var env := minf(t * 8.0, 1.0) * (1.0 - t * t) * (0.75 + 0.25 * sin(t * 70.0))
		buf[i] = lp * env * gain * 1.6
	return buf


## Hiss with rising sputter: a lit fuse.
func _fuse(seconds: float, gain: float) -> PackedFloat32Array:
	var buf := _samples(seconds)
	for i in buf.size():
		var t := float(i) / buf.size()
		var sputter := 1.0 if _rng.randf() < 0.25 + t * 0.5 else 0.3
		buf[i] = _rng.randf_range(-1.0, 1.0) * sputter * (0.4 + 0.6 * t) * gain * 0.5
	return buf


## Bow string creak: slow pulses of filtered noise rising in pitch.
func _creak(seconds: float, gain: float) -> PackedFloat32Array:
	var buf := _samples(seconds)
	var lp := 0.0
	for i in buf.size():
		var t := float(i) / buf.size()
		lp += 0.12 * (_rng.randf_range(-1.0, 1.0) - lp)
		var pulse := 0.5 + 0.5 * sin(TAU * lerpf(30.0, 70.0, t) * float(i) / RATE)
		buf[i] = lp * pulse * sin(PI * t) * gain * 3.0
	return buf


func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out := a.duplicate() if a.size() >= b.size() else b.duplicate()
	var other := b if a.size() >= b.size() else a
	for i in other.size():
		out[i] += other[i]
	return out


func _write(name: String, buf: PackedFloat32Array) -> void:
	var peak := 0.0
	for v in buf:
		peak = maxf(peak, absf(v))
	var scale := 0.89 / peak if peak > 0.89 else 1.0
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i] * scale, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	var path := OUT + name + ".wav"
	var err := wav.save_to_wav(ProjectSettings.globalize_path(path))
	print("%s %s (%.2f s)" % ["wrote" if err == OK else "FAILED", path, float(buf.size()) / RATE])
