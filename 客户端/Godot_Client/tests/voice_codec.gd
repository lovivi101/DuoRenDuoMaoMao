extends SceneTree
## μ-law voice codec round trip: quiet and loud samples survive within G.711 precision.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var codec: GDScript = load("res://autoload/Voice.gd")
	var worst: float = 0.0
	for i: int in 2001:
		var x: float = (float(i) - 1000.0) / 1000.0
		var y: float = codec.decode(codec.encode(x))
		var tolerance: float = 0.004 + absf(x) * 0.07
		worst = maxf(worst, absf(y - x) - tolerance)
	if worst > 0.0:
		print("VOICE_CODEC FAIL: error exceeds tolerance by %f" % worst)
		quit(1)
		return
	print("VOICE_CODEC PASS: 2001 samples round-trip within μ-law precision")
	quit(0)
