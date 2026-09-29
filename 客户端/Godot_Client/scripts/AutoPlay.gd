extends Node
class_name AutoPlay
## Debug driver started by `--autoplay`: plays a real match against the live
## server as a guest (room + AI fill), wanders the player around and captures
## screenshots of real game screens into res://docs/screenshots/live-*.png.

var hunt_started_ms: int = -1
var shots_taken: Dictionary = {}
var wander: Vector2 = Vector2.RIGHT
var next_turn_ms: int = 0
var result_seen_ms: int = -1
const HUNT_SHOTS: Array[int] = [3, 12, 25, 45]

func _ready() -> void:
	Config.autoplay = true
	Net.message.connect(_on_message)
	_start.call_deferred()

func _start() -> void:
	var login: Dictionary = await Api.login("guest", {"deviceId": "autoplay_" + str(Time.get_unix_time_from_system())})
	if not login.get("ok", false):
		_quit("guest login failed: " + str(login)); return
	var profile: Dictionary = await Api.request("/profile", {"nickname": "试玩夜猫", "color": "cyan"})
	if profile.get("ok", false):
		Session.user = profile.user
	Router.go(6)
	await get_tree().create_timer(1.0).timeout
	_shot("live-06-main")
	while not Net.connected:
		await get_tree().process_frame
	Net.send("room.create", {"settings": {"map": "old_dorm", "durationSec": 300, "hunterCount": "auto", "moleEnabled": false, "voiceEnabled": false, "aiFill": true, "maxPlayers": 8}})

func _on_message(data: Dictionary) -> void:
	if str(data.get("t", "")) != "game.snap": print("AUTOPLAY MSG ", data.get("t"), " ", data.get("phase", ""))
	match str(data.get("t", "")):
		"room.state":
			if data.phase == "waiting" and result_seen_ms < 0:
				if data.players.size() < 8:
					Net.send("room.addBot")
				else:
					await get_tree().create_timer(0.6).timeout
					_shot("live-10-room")
					Net.send("room.start")
		"vote.start":
			await get_tree().create_timer(0.5).timeout
			_shot("live-11-vote")
			Net.send("vote.cast", {"mapId": "old_dorm"})
		"game.start":
			await get_tree().create_timer(1.5).timeout
			_shot("live-12-role-" + str(data.you.role))
		"game.phase":
			if data.phase == "hunt" and hunt_started_ms < 0:
				hunt_started_ms = Time.get_ticks_msec()
		"game.caught":
			if str(data.get("victimId", "")) == str(Session.user.get("id", "")):
				await get_tree().create_timer(0.8).timeout
				_shot("live-15-caught")
		"game.result":
			result_seen_ms = Time.get_ticks_msec()
			print("AUTOPLAY result received, page=", Router.current)
			await get_tree().create_timer(1.2).timeout
			await _shot("live-17-result")
			_quit("")

func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	if now >= next_turn_ms:
		next_turn_ms = now + 1500 + randi() % 1500
		wander = Vector2.from_angle(randf() * TAU)
	Config.autoplay_dir = wander
	if hunt_started_ms >= 0:
		var secs: int = (now - hunt_started_ms) / 1000
		for s: int in HUNT_SHOTS:
			if secs >= s and not shots_taken.has(s):
				shots_taken[s] = true
				_shot("live-hunt-%02ds-%s" % [s, Session.role()])

func _shot(name: String) -> void:
	# Force a draw: when the window is hidden, minimized or the screen is locked the OS stops
	# presenting frames and frame_post_draw would never fire.
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	var image: Image = get_viewport().get_texture().get_image()
	if image == null:
		print("AUTOPLAY SHOT FAILED (no image) ", name)
		return
	var path: String = "res://docs/screenshots/%s.png" % name
	print("AUTOPLAY SHOT ", path, " err=", image.save_png(path))

func _quit(reason: String) -> void:
	if not reason.is_empty():
		push_error("AUTOPLAY FAIL: " + reason)
	print("AUTOPLAY DONE")
	get_tree().quit(0 if reason.is_empty() else 1)
