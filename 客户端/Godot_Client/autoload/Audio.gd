extends Node
var player: AudioStreamPlayer = AudioStreamPlayer.new()

func _ready() -> void:
	add_child(player)
	Config.changed.connect(apply_settings)
	apply_settings()

func apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, float(Config.settings.volume))))
	AudioServer.set_bus_mute(0, float(Config.settings.volume) <= 0.0)

func cue(high: bool = false) -> void:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var samples: PackedByteArray = PackedByteArray()
	samples.resize(4410)
	for i: int in 2205:
		var amplitude: float = sin(float(i) / 22050.0 * TAU * (640.0 if high else 320.0)) * 0.15 * (1.0 - float(i) / 2205.0)
		samples.encode_s16(i * 2, int(amplitude * 32767))
	stream.data = samples
	player.stream = stream
	player.play()

func vibrate() -> void:
	if Config.settings.vibration and OS.has_feature("mobile"):
		Input.vibrate_handheld(150)
