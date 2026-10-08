extends Node
## 近距离语音 (push to talk). The microphone is captured on a muted bus, downsampled to
## 8 kHz mono, G.711 μ-law encoded and sent in 100 ms chunks (`voice` messages). The server
## decides who hears whom (distance, ghosts only hear ghosts) and attaches a volume.

const RATE: int = 8000
const CHUNK: int = 800  # samples per message = 100 ms
var talking: bool = false
var capture: AudioEffectCapture
var mic: AudioStreamPlayer
var pending: PackedByteArray = PackedByteArray()
var phase: float = 0.0
var speakers: Dictionary = {}  # id -> {player: AudioStreamPlayer, playback: AudioStreamGeneratorPlayback, last: int}

func _ready() -> void:
	Net.message.connect(_on_message)

## Voice is on when the current room allows it.
func available() -> bool:
	return bool(Session.room.get("settings", {}).get("voiceEnabled", false))

func start_talking() -> void:
	if talking or not available():
		return
	if OS.get_name() == "Android":
		OS.request_permissions()
	_ensure_mic()
	if capture:
		capture.clear_buffer()
	pending.clear()
	talking = true

func stop_talking() -> void:
	talking = false
	_flush(true)

func _ensure_mic() -> void:
	if capture != null:
		return
	var bus: int = AudioServer.get_bus_index("VoiceMic")
	if bus < 0:
		AudioServer.add_bus()
		bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, "VoiceMic")
		AudioServer.set_bus_mute(bus, true)  # never play our own voice back
		AudioServer.add_bus_effect(bus, AudioEffectCapture.new())
	capture = AudioServer.get_bus_effect(bus, 0) as AudioEffectCapture
	mic = AudioStreamPlayer.new()
	mic.stream = AudioStreamMicrophone.new()
	mic.bus = "VoiceMic"
	add_child(mic)
	mic.play()

func _process(_delta: float) -> void:
	if talking and capture:
		var frames: PackedVector2Array = capture.get_buffer(capture.get_frames_available())
		var step: float = AudioServer.get_mix_rate() / RATE
		for f: Vector2 in frames:
			phase += 1.0
			if phase >= step:
				phase -= step
				pending.append(encode((f.x + f.y) * 0.5))
		_flush(false)
	var now: int = Time.get_ticks_msec()
	for id: String in speakers.keys():
		if now - int(speakers[id].last) > 5000:
			(speakers[id].player as Node).queue_free()
			speakers.erase(id)

func _flush(all: bool) -> void:
	while pending.size() >= CHUNK or (all and pending.size() > 0):
		var n: int = mini(CHUNK, pending.size())
		Net.send("voice", {"d": Marshalls.raw_to_base64(pending.slice(0, n))})
		pending = pending.slice(n)

func _on_message(data: Dictionary) -> void:
	if str(data.get("t", "")) != "voice":
		return
	var id: String = str(data.get("from", ""))
	if not speakers.has(id):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		var gen: AudioStreamGenerator = AudioStreamGenerator.new()
		gen.mix_rate = RATE
		gen.buffer_length = 0.6
		player.stream = gen
		add_child(player)
		player.play()
		speakers[id] = {"player": player, "playback": player.get_stream_playback(), "last": 0}
	var s: Dictionary = speakers[id]
	s.last = Time.get_ticks_msec()
	var playback: AudioStreamGeneratorPlayback = s.playback
	var vol: float = clampf(float(data.get("vol", 1.0)), 0.0, 1.0) * float(Config.settings.get("volume", 0.7))
	var bytes: PackedByteArray = Marshalls.base64_to_raw(str(data.get("d", "")))
	if playback.get_frames_available() < bytes.size():
		return  # falling behind: drop this chunk rather than add latency
	for b: int in bytes:
		var v: float = decode(b) * vol
		playback.push_frame(Vector2(v, v))

## G.711 μ-law: 14-bit linear sample in, 8-bit code out (and back).
static func encode(sample: float) -> int:
	var pcm: int = clampi(int(sample * 32767.0), -32768, 32767) >> 2
	var sgn: int = 0x80 if pcm < 0 else 0
	var mag: int = mini(absi(pcm), 8158) + 33
	var segment: int = 0
	var v: int = mag >> 6
	while v > 0 and segment < 7:
		segment += 1
		v >>= 1
	var mantissa: int = (mag >> (segment + 1)) & 0x0F
	return ~(sgn | (segment << 4) | mantissa) & 0xFF

static func decode(code: int) -> float:
	var u: int = ~code & 0xFF
	var magnitude: int = ((((u & 0x0F) << 3) + 0x84) << ((u & 0x70) >> 4)) - 0x84
	return float(-magnitude if (u & 0x80) != 0 else magnitude) / 32768.0
