extends Node
## Tiny original synthesized sounds. No downloads or licensed asset dependencies.
var sounds: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var voice: int = 0
var muted: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 10:
		var player := AudioStreamPlayer.new()
		player.volume_db = -16.0
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

func play(id: String) -> void:
	if muted or not sounds.has(id):
		return
	var player: AudioStreamPlayer = voices[voice % voices.size()]
	voice += 1
	player.stream = sounds[id]
	player.play()

func toggle_mute() -> void:
	muted = not muted
	if muted:
		for player in voices:
			player.stop()

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
