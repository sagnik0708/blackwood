extends Node
## Tiny procedural sound engine. Every sound is synthesized at startup from
## raw PCM samples - zero external audio assets.
## On the web, browsers require a user gesture before audio can start,
## so ambience begins on the first input (see start_ambience()).

const SAMPLE_RATE := 22050

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _heartbeat: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _ambience_started := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_synthesize_all()
	for i in 12:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)
	_heartbeat = AudioStreamPlayer.new()
	_heartbeat.stream = _streams["heartbeat"]
	_heartbeat.volume_db = -7.0
	add_child(_heartbeat)
	_wind = AudioStreamPlayer.new()
	_wind.stream = _streams["wind"]
	_wind.volume_db = -13.0
	add_child(_wind)


func play(sound_name: String, volume_db: float = -4.0, pitch: float = 1.0) -> void:
	if not _streams.has(sound_name):
		return
	var p := _grab_player()
	p.stream = _streams[sound_name]
	p.volume_db = volume_db
	p.pitch_scale = clampf(pitch, 0.55, 1.8)
	p.play()


func start_ambience() -> void:
	if _ambience_started:
		return
	_ambience_started = true
	if _wind != null and not _wind.playing:
		_wind.play()


func set_heartbeat(active: bool) -> void:
	if _heartbeat == null:
		return
	if active and not _heartbeat.playing:
		_heartbeat.play()
	elif not active and _heartbeat.playing:
		_heartbeat.stop()


func _grab_player() -> AudioStreamPlayer:
	for p in _pool:
		if not p.playing:
			return p
	return _pool[0]


# ---------------------------------------------------------------- synthesis

func _synthesize_all() -> void:
	_streams["swing"] = _wav(_sfx_swing())
	_streams["hit"] = _wav(_sfx_hit())
	_streams["hurt"] = _wav(_sfx_hurt())
	_streams["pickup"] = _wav(_sfx_pickup())
	_streams["door"] = _wav(_sfx_door())
	_streams["step"] = _wav(_sfx_step())
	_streams["chest"] = _wav(_sfx_chest())
	_streams["growl"] = _wav(_sfx_growl())
	_streams["death"] = _wav(_sfx_death())
	_streams["heartbeat"] = _wav(_sfx_heartbeat(), true)
	_streams["wind"] = _wav(_sfx_wind(), true)


func _wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(round(clampf(samples[i], -1.0, 1.0) * 32000.0))
		bytes.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size() - 1
	return wav


func _noise(n: int, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = rng.randf_range(-1.0, 1.0)
	return out


func _sfx_swing() -> PackedFloat32Array:
	var n := int(0.13 * SAMPLE_RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 101
	var noise := _noise(n, rng)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / float(n)
		# crude high-pass (first difference) gives the "whoosh" air
		var hp: float = noise[i] - (noise[i - 1] if i > 0 else 0.0)
		var swoosh := sin(t * PI)
		swoosh = swoosh * swoosh
		out[i] = hp * 2.2 * swoosh
	return out


func _sfx_hit() -> PackedFloat32Array:
	var n := int(0.16 * SAMPLE_RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 202
	var noise := _noise(n, rng)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / float(n)
		var freq: float = 120.0 * pow(1.0 - t, 1.6) + 42.0
		var thump: float = sin(TAU * freq * float(i) / SAMPLE_RATE) * pow(1.0 - t, 2.4)
		var crunch: float = noise[i] * pow(1.0 - t, 6.0) * 0.7
		out[i] = (thump * 0.9 + crunch) * 0.9
	return out


func _sfx_hurt() -> PackedFloat32Array:
	var n := int(0.28 * SAMPLE_RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 808
	var noise := _noise(n, rng)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / float(n)
		var tt := float(i) / SAMPLE_RATE
		var tone: float = sin(TAU * (150.0 - 80.0 * t) * tt) * pow(1.0 - t, 1.8) * 0.7
		var grunt: float = noise[i] * pow(1.0 - t, 3.0) * 0.4
		out[i] = tone + grunt
	return out


func _sfx_pickup() -> PackedFloat32Array:
	var n := int(0.34 * SAMPLE_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var tt := float(i) / SAMPLE_RATE
		var s := 0.0
		if tt < 0.16:
			s = sin(TAU * 523.25 * tt) * pow(1.0 - tt / 0.16, 1.5) * 0.5
		else:
			var u := (tt - 0.16) / 0.18
			s = sin(TAU * 783.99 * (tt - 0.16)) * pow(1.0 - u, 1.5) * 0.55
		out[i] = s
	return out


func _sfx_door() -> PackedFloat32Array:
	var n := int(0.55 * SAMPLE_RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 303
	var noise := _noise(n, rng)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / float(n)
		# band-passed noise with a wandering resonance = hinge creak
		lp += 0.18 * (noise[i] - lp)
		var band: float = noise[i] - lp
		var wobble: float = 0.55 + 0.45 * sin(TAU * 3.0 * t + 0.7)
		out[i] = band * wobble * sin(PI * minf(t * 1.15, 1.0)) * 1.6
	return out


func _sfx_step() -> PackedFloat32Array:
	var n := int(0.07 * SAMPLE_RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var noise := _noise(n, rng)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / float(n)
		out[i] = noise[i] * 0.35 * pow(1.0 - t, 2.0)
	return out


func _sfx_chest() -> PackedFloat32Array:
	var n := int(0.4 * SAMPLE_RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 606
	var noise := _noise(n, rng)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / float(n)
		var tt := float(i) / SAMPLE_RATE
		var thunk: float = sin(TAU * (95.0 - 40.0 * t) * tt) * pow(1.0 - t, 2.2) * 0.8
		var creak: float = noise[i] * pow(1.0 - t, 1.5) * 0.25
		out[i] = thunk + creak
	return out


func _sfx_growl() -> PackedFloat32Array:
	var n := int(0.45 * SAMPLE_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / float(n)
		var f := 58.0 + 22.0 * sin(TAU * 2.4 * t)
		phase += TAU * f / SAMPLE_RATE
		var saw := fmod(phase, TAU) / PI - 1.0
		out[i] = saw * 0.35 * sin(PI * minf(t * 1.2, 1.0))
	return out


func _sfx_death() -> PackedFloat32Array:
	var n := int(0.7 * SAMPLE_RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 505
	var noise := _noise(n, rng)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / float(n)
		var f := 80.0 * pow(1.0 - t, 1.3) + 24.0
		phase += TAU * f / SAMPLE_RATE
		var saw := fmod(phase, TAU) / PI - 1.0
		var burst: float = noise[i] * pow(maxf(0.0, 1.0 - t * 1.6), 2.0) * 0.5
		out[i] = (saw * 0.4 + burst) * sin(PI * minf(t * 1.05, 1.0))
	return out


func _sfx_heartbeat() -> PackedFloat32Array:
	var n := int(0.9 * SAMPLE_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for beat in 2:
		var start_s := 0.06 if beat == 0 else 0.34
		var amp := 0.9 if beat == 0 else 0.55
		var i0 := int(start_s * SAMPLE_RATE)
		var i1 := mini(i0 + int(0.16 * SAMPLE_RATE), n)
		for i in range(i0, i1):
			var u := float(i - i0) / float(i1 - i0)
			var f := 58.0 * (1.0 - 0.35 * u)
			out[i] += sin(TAU * f * u * 0.16) * pow(1.0 - u, 2.0) * amp
	return out


func _sfx_wind() -> PackedFloat32Array:
	var n := int(4.0 * SAMPLE_RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 707
	var noise := _noise(n, rng)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / float(n)
		# cascaded one-pole lowpass = soft breathy wind
		lp += 0.045 * (noise[i] - lp)
		var gust: float = 0.55 + 0.45 * sin(TAU * t * 1.7 + sin(TAU * t * 0.9) * 1.2)
		# fade the loop ends into each other
		var loop_f: float = minf(t / 0.08, 1.0) * minf((1.0 - t) / 0.08, 1.0)
		out[i] = lp * 1.8 * gust * loop_f
	return out
