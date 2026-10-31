extends Node

## Procedurally synthesised sound effects and per-room background loops.
## No audio files are shipped; everything is generated at runtime.

const RATE := 22050
const MUSIC_RATE := 16000

var _sfx := {}
var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _music_cache := {}
var _pending := {}
var _current := ""
var muted := false


func _ready() -> void:
	for i in range(5):
		var p := AudioStreamPlayer.new()
		p.volume_db = -7.0
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -17.0
	add_child(_music)
	_sfx = {
		"select": _notes([[1046.5, 0.0, 0.07, 0.32]]),
		"move": _notes([[880.0, 0.0, 0.05, 0.18]]),
		"inspect": _notes([[784.0, 0.0, 0.09, 0.3], [1174.7, 0.07, 0.16, 0.3]]),
		"success": _notes([[523.3, 0.0, 0.32, 0.26], [659.3, 0.07, 0.32, 0.26], [784.0, 0.14, 0.34, 0.26], [1046.5, 0.21, 0.45, 0.28]]),
		"fail": _notes([[311.1, 0.0, 0.2, 0.32], [233.1, 0.13, 0.34, 0.32]], 0.35),
		"locked": _notes([[220.0, 0.0, 0.09, 0.25], [220.0, 0.11, 0.09, 0.25]], 0.3),
		"open": _swoosh(),
		"coin": _notes([[1318.5, 0.0, 0.08, 0.22], [1760.0, 0.06, 0.2, 0.22]]),
	}


func play(name: String) -> void:
	if muted or not _sfx.has(name):
		return
	for p in _players:
		if not p.playing:
			p.stream = _sfx[name]
			p.play()
			return
	_players[0].stream = _sfx[name]
	_players[0].play()


func play_music(room: String) -> void:
	if room == _current:
		return
	_current = room
	if _music_cache.has(room):
		_start_music(_music_cache[room])
		return
	if _pending.has(room):
		return
	_pending[room] = true
	if OS.has_feature("web") and not OS.has_feature("threads"):
		# Single-threaded web build: compose on the main thread after the room appears.
		call_deferred("_generate_music", room)
	else:
		WorkerThreadPool.add_task(_generate_music.bind(room))


func _generate_music(room: String) -> void:
	var stream := _compose(room)
	call_deferred("_music_ready", room, stream)


func _music_ready(room: String, stream: AudioStreamWAV) -> void:
	_music_cache[room] = stream
	_pending.erase(room)
	if room == _current:
		_start_music(stream)


func _start_music(stream: AudioStreamWAV) -> void:
	if muted:
		return
	_music.stream = stream
	_music.volume_db = -40.0
	_music.play()
	var tween := create_tween()
	tween.tween_property(_music, "volume_db", -17.0, 1.2)


# --- Synthesis -----------------------------------------------------------

func _wav(samples: PackedFloat32Array, rate: int, loop: bool = false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in range(samples.size()):
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 30000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav


## notes: [freq, start, duration, amplitude]; `grit` adds odd harmonics.
func _notes(notes: Array, grit: float = 0.0) -> AudioStreamWAV:
	var length := 0.0
	for n in notes:
		length = maxf(length, float(n[1]) + float(n[2]))
	var count := int(length * RATE) + 64
	var samples := PackedFloat32Array()
	samples.resize(count)
	for n in notes:
		var f := float(n[0])
		var start := int(float(n[1]) * RATE)
		var dur := int(float(n[2]) * RATE)
		var amp := float(n[3])
		for i in range(dur):
			var t := float(i) / RATE
			var env := minf(1.0, t / 0.006) * exp(-t * 5.5 / float(n[2]))
			var w := sin(TAU * f * t) + 0.25 * sin(TAU * f * 2.0 * t) + grit * sin(TAU * f * 3.0 * t)
			samples[start + i] += w * env * amp
	return _wav(samples, RATE)


func _swoosh() -> AudioStreamWAV:
	var count := int(0.2 * RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var lp := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for i in range(count):
		var t := float(i) / count
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.08 + t * 0.2)
		samples[i] = lp * sin(t * PI) * 0.5
	return _wav(samples, RATE)


func _midi(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)


func _compose(room: String) -> AudioStreamWAV:
	var progressions := {
		"city": [[60, 64, 67, 71], [57, 60, 64, 67], [53, 57, 60, 64], [55, 59, 62, 67]],
		"office": [[53, 57, 60, 65], [50, 53, 57, 62], [46, 50, 53, 58], [48, 52, 55, 60]],
		"review": [[57, 60, 64, 69], [53, 57, 60, 65], [48, 52, 55, 60], [55, 59, 62, 67]],
		"showroom": [[62, 66, 69, 74], [59, 62, 66, 71], [55, 59, 62, 67], [57, 61, 64, 69]],
	}
	var bpm: float = {"city": 92.0, "office": 100.0, "review": 84.0, "showroom": 108.0}.get(room, 96.0)
	var chords: Array = progressions.get(room, progressions.city)
	var beat := 60.0 / bpm
	var bar := beat * 4.0
	var total := bar * chords.size()
	var count := int(total * MUSIC_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var eighth := beat * 0.5
	var pattern := [0, 2, 1, 3, 2, 1, 3, 2]
	var pad_f := []
	var bass_f := []
	var arp_f := []
	for chord in chords:
		pad_f.append([TAU * _midi(float(chord[0]) - 12.0), TAU * _midi(float(chord[1]) - 12.0), TAU * _midi(float(chord[2]) - 12.0)])
		bass_f.append(TAU * _midi(float(chord[0]) - 24.0))
		var arp := []
		for k in range(4):
			arp.append(TAU * _midi(float(chord[k]) + 12.0))
		arp_f.append(arp)
	for i in range(count):
		var t := float(i) / MUSIC_RATE
		var ci := int(t / bar) % chords.size()
		var pf: Array = pad_f[ci]
		var local := fmod(t, bar) / bar
		var pad := (sin(pf[0] * t) + sin(pf[1] * t) + sin(pf[2] * t)) * 0.045 * (0.55 + 0.45 * sin(local * PI))
		var step := int(t / eighth)
		var st := fmod(t, eighth)
		var w: float = arp_f[ci][pattern[step % 8]]
		var pluck := (sin(w * t) + 0.3 * sin(w * 2.0 * t)) * exp(-st * 9.0) * minf(1.0, st / 0.004) * 0.07
		var bass := sin(bass_f[ci] * t) * 0.06 * (0.6 + 0.4 * exp(-fmod(t, beat * 2.0) * 3.0))
		samples[i] = pad + pluck + bass
	# Short fades at the loop seam to avoid clicks.
	var fade := int(0.02 * MUSIC_RATE)
	for i in range(fade):
		var g := float(i) / fade
		samples[i] *= g
		samples[count - 1 - i] *= g
	return _wav(samples, MUSIC_RATE, true)
