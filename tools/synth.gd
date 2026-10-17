extends RefCounted
## Synthesises every sound in the game. tools/bake_arena.gd writes them to audio/*.wav.

const RATE := 22050


static func all() -> Dictionary:
	# partials: [start Hz, end Hz, amplitude]; then noise amount, attack seconds, decay curve
	return {
		"gunshot": make(0.28, [[160, 45, 0.6]], 1.0, 0.001, 6.0),
		"reload": make(0.18, [[1800, 1400, 0.15], [900, 700, 0.1]], 0.35, 0.002, 3.0),
		"empty": make(0.06, [[2200, 2000, 0.25]], 0.2, 0.001, 3.0),
		"knife": make(0.28, [[1100, 300, 0.04]], 0.55, 0.06, 2.0),
		"punch": make(0.16, [[95, 40, 0.8]], 0.6, 0.002, 3.0),
		"hit": make(0.14, [[220, 110, 0.4]], 0.45, 0.002, 2.5),
		"roll": make(0.3, [[200, 120, 0.05]], 0.4, 0.05, 2.0),
		"fire_cast": make(0.6, [[180, 820, 0.25]], 0.6, 0.05, 1.5),
		"explode": make(1.0, [[85, 30, 0.8]], 1.0, 0.004, 2.5),
		"shadow_cast": make(0.9, [[300, 120, 0.3], [309, 115, 0.3]], 0.2, 0.1, 1.5),
		"shadow_hit": make(1.4, [[90, 55, 0.5], [94, 52, 0.4]], 0.3, 0.02, 1.2),
		"beep": make(0.16, [[880, 880, 0.4]], 0.0, 0.005, 1.0),
		"horn": make(1.0, [[220, 220, 0.4], [330, 330, 0.3], [440, 440, 0.2]], 0.0, 0.02, 1.0),
		"gong": make(2.6, [[110, 104, 0.5], [231, 224, 0.3], [367, 360, 0.2]], 0.05, 0.002, 1.4),
		"zone": make(0.7, [[620, 380, 0.3], [930, 570, 0.15]], 0.0, 0.01, 1.0),
		"click": make(0.06, [[900, 700, 0.3]], 0.0, 0.002),
		"battle": battle(),
		"ambient": ambient(),
	}


static func make(dur: float, partials: Array, noise: float, attack: float, decay := 2.0) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phases := []
	phases.resize(partials.size())
	phases.fill(0.0)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var k := t / dur
		var env := minf(t / attack, 1.0) * pow(1.0 - k, decay)
		var s := 0.0
		for j in partials.size():
			var pr = partials[j]
			phases[j] += TAU * lerpf(pr[0], pr[1], k) / RATE
			s += sin(phases[j]) * pr[2]
		if noise > 0.0:
			lp += (randf_range(-1.0, 1.0) - lp) * 0.3
			s += lp * noise
		data.encode_s16(i * 2, int(clampf(s * env, -1.0, 1.0) * 32000.0))
	return wav(data)


# 8 s at 120 BPM: kick on every beat, hat on the off-beats, a low pulsing bass. Loops cleanly.
static func battle() -> AudioStreamWAV:
	var n := 8 * RATE
	var data := PackedByteArray()
	data.resize(n * 2)
	var bass_notes := [55.0, 55.0, 65.5, 49.0]  # one per 2-second bar
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var beat := fmod(t, 0.5)
		var kick := sin(TAU * (60.0 - 40.0 * beat) * beat) * exp(-beat * 18.0) * 0.7
		var off := fmod(t + 0.25, 0.5)
		var hat := randf_range(-1.0, 1.0) * exp(-off * 60.0) * 0.12
		phase += TAU * bass_notes[int(t / 2.0) % 4] / RATE
		var bass := sin(phase) * 0.22 * (0.6 + 0.4 * exp(-fmod(t, 0.25) * 8.0))
		var s := kick + hat + bass
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32000.0))
	return wav(data)


static func ambient() -> AudioStreamWAV:
	var n := 8 * RATE
	var data := PackedByteArray()
	data.resize(n * 2)
	var wind := 0.0
	for i in n:
		var t := float(i) / RATE
		var s := sin(TAU * 55.0 * t) * 0.14 + sin(TAU * 82.5 * t) * 0.07
		wind += (randf_range(-1.0, 1.0) - wind) * 0.02
		s += wind * 0.9 * (0.6 + 0.4 * sin(TAU * 0.25 * t))
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32000.0))
	return wav(data)


static func wav(data: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	return w
