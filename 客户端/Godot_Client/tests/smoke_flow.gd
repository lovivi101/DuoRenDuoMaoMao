extends SceneTree
var session: Node
var net: Node
var api: Node
var got_start: bool = false
var got_snap: bool = false
var got_result: bool = false
var again_sent: bool = false
var deadline: int = 0
var last_status: int = 0
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.get_node("Router").enabled = false
	session = root.get_node("Session")
	net = root.get_node("Net")
	api = root.get_node("Api")
	net.message.connect(on_message)
	var login: Dictionary = await api.login("guest", {"deviceId":"godot_smoke_" + str(Time.get_ticks_usec())})
	if not login.get("ok", false):
		fail("guest login: " + str(login)); return
	var profile: Dictionary = await api.request("/profile", {"nickname":"联调夜猫", "color":"cyan"})
	if not profile.get("ok", false):
		fail("profile: " + str(profile)); return
	session.user = profile.user
	while not net.connected:
		await process_frame
	net.send("room.create", {"settings":{"map":"old_dorm", "durationSec":300, "hunterCount":"auto", "moleEnabled":false, "voiceEnabled":false, "aiFill":true, "maxPlayers":8}})
	deadline = Time.get_ticks_msec() + 400000
	print("SMOKE login/profile OK; full real-time 300s match")
	while Time.get_ticks_msec() < deadline:
		if Time.get_ticks_msec() - last_status > 30000:
			last_status = Time.get_ticks_msec()
			print("SMOKE phase=", session.phase, " start=", got_start, " snap=", got_snap, " result=", got_result)
		await process_frame
	fail("timeout")
func on_message(data: Dictionary) -> void:
	match str(data.get("t", "")):
		"room.state":
			if data.phase == "waiting" and got_result and again_sent:
				if not got_start or not got_snap:
					fail("missing game packets"); return
				print("SMOKE PASS: guest -> profile -> room -> 8 players -> vote -> game.start -> game.snap -> game.result -> room.again -> waiting")
				net.send("room.leave")
				net.disconnect_session()
				quit(0)
			elif data.phase == "waiting" and not got_start:
				if data.players.size() < 8: net.send("room.addBot")
				else: net.send("room.start")
		"vote.start": net.send("vote.cast", {"mapId":"old_dorm"})
		"game.start":
			got_start = true
			print("SMOKE game.start role=", data.you.role)
		"game.snap":
			got_snap = true
			if data.you.state == "caged" and data.you.ghostSide == null:
				net.send("game.ghostSide", {"side":"guardian"})
		"game.result":
			got_result = true
			again_sent = true
			print("SMOKE game.result winner=", data.winner)
			net.send("room.again")
		"error": fail(str(data))
func fail(reason: String) -> void:
	push_error("SMOKE FAIL: " + reason)
	quit(1)
