extends Node

# Audio singleton (autoloaded as "Sound").
# Both SFX and music are generated in memory, so the project has no external audio files.

## Original synthesized SFX plus a lightweight looping chiptune.
## No downloads, licensed tracks, or external audio dependencies.

# A small player pool allows overlapping effects (for example hit + coin) without
# creating/destroying AudioStreamPlayer nodes during gameplay.
var sounds: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var voice: int = 0
var muted: bool = false
var music_player: AudioStreamPlayer


# Build all audio streams once at startup, then begin the background loop.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 10:
		var player := AudioStreamPlayer.new()
		player.volume_db = -16.0
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		voices.append(player)
	sounds["shot"] = _tone(620, 160, 0.09)
	sounds["hit"] = _tone(190, 65, 0.08)
	sounds["dash"] = _tone(130, 520, 0.15)
	sounds["coin"] = _tone(920, 1480, 0.13)
	sounds["hurt"] = _tone(145, 40, 0.26)
	sounds["buy"] = _tone(420, 840, 0.23)
	sounds["deny"] = _tone(170, 130, 0.17)
	sounds["win"] = _tone(523, 1046, 0.85)
	sounds["lose"] = _tone(300, 45, 0.9)

	music_player = AudioStreamPlayer.new()
	music_player.name = "Music"
	music_player.volume_db = -25.0
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	music_player.stream = _music_loop()
	add_child(music_player)
	music_player.finished.connect(_restart_music)
	music_player.play()


# Round-robin through the voice pool; assigning a new stream to one voice only replaces
# that voice, leaving other simultaneous effects untouched.
func play(id: String) -> void:
	if muted or not sounds.has(id):
		return
	var player: AudioStreamPlayer = voices[voice % voices.size()]
	voice += 1
	player.stream = sounds[id]
	player.play()


# Muting stops existing audio as well as blocking new SFX. Unmuting restarts music.
func toggle_mute() -> void:
	muted = not muted
	if muted:
		for player in voices:
			player.stop()
		if is_instance_valid(music_player):
			music_player.stop()
	elif is_instance_valid(music_player) and not music_player.playing:
		music_player.play()

func _restart_music() -> void:
	if not muted and is_instance_valid(music_player):
		music_player.play()


# Generate a short two-oscillator WAV with a fast attack/decay envelope.
# Frequency sweeps create different arcade-style effects from the same function.
func _tone(start: float, finish: float, duration: float) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var count: int = int(duration * wav.mix_rate)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var phase: float = 0.0
	for i in count:
		var t: float = float(i) / count
		phase += TAU * lerpf(start, finish, t) / wav.mix_rate
		var envelope: float = minf(t * 25, 1.0) * pow(1.0 - t, 1.7)
		var value: float = (sin(phase) + sin(phase * 2.01) * 0.2) * envelope
		bytes.encode_s16(i * 2, int(value * 16000))
	wav.data = bytes
	return wav


# Helpers used by the procedural music synthesizer.
func _note_hz(midi_note: int) -> float:
	return 440.0 * pow(2.0, (float(midi_note) - 69.0) / 12.0)

func _square(phase: float) -> float:
	return 1.0 if sin(phase) >= 0.0 else -1.0


# Render the whole music loop into one WAV at startup. Runtime playback is therefore
# cheap: Godot simply plays the finished buffer and restarts it when it ends.
func _music_loop() -> AudioStreamWAV:
	# 16 seconds at 120 BPM: four compact retro-finance bars.
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var step_seconds: float = 0.25
	var total_steps: int = 64
	var duration: float = step_seconds * total_steps
	var count: int = int(duration * wav.mix_rate)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)

	var roots: Array[int] = [48, 44, 41, 43] # C, Ab, F, G
	var arp: Array[int] = [0, 7, 12, 7]
	var melody: Array[int] = [12, -1, 15, -1, 19, -1, 15, -1, 12, -1, 10, -1, 7, 10, 12, -1]

	for i in count:
		var seconds: float = float(i) / float(wav.mix_rate)
		var step: int = int(seconds / step_seconds) % total_steps
		var bar: int = (step / 16) % 4
		var local_step: int = step % 16
		var within_step: float = fmod(seconds, step_seconds) / step_seconds
		var envelope: float = pow(1.0 - within_step, 1.8)
		var root: int = roots[bar]

		var bass_hz: float = _note_hz(root - 12)
		var arp_hz: float = _note_hz(root + arp[local_step % arp.size()])
		var value: float = _square(TAU * bass_hz * seconds) * 0.14
		value += _square(TAU * arp_hz * seconds) * 0.095 * envelope

		var melody_offset: int = melody[local_step]
		if melody_offset >= 0:
			var melody_hz: float = _note_hz(root + melody_offset)
			value += _square(TAU * melody_hz * seconds) * 0.065 * envelope

		# A soft synthesized kick every beat gives the loop motion without
		# competing with gameplay sound effects.
		if local_step % 2 == 0:
			var beat_time: float = fmod(seconds, step_seconds * 2.0)
			if beat_time < 0.12:
				var kick_env: float = 1.0 - beat_time / 0.12
				var kick_hz: float = lerpf(105.0, 52.0, 1.0 - kick_env)
				value += sin(TAU * kick_hz * beat_time) * 0.10 * kick_env

		bytes.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 15000.0))

	wav.data = bytes
	return wav
