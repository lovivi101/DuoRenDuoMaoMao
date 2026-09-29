extends Node
signal message(data: Dictionary)
signal status_changed(text: String)
var peer: WebSocketPeer = WebSocketPeer.new()
var connected: bool = false
var desired: bool = false
var retry_at: float = 0.0
var attempt_at: float = 0.0
var clock_offset: float = 0.0
var queue: Array[Dictionary] = []
var ping_at: float = 0.0
var seq: int = 0
var retry_count: int = 0

func connect_session() -> void:
	if Config.demo or Session.token.is_empty():
		return
	desired = true
	peer = WebSocketPeer.new()
	connected = false
	attempt_at = Time.get_ticks_msec() * 0.001
	var err: Error = peer.connect_to_url(Config.ws_url() + "?token=" + Session.token.uri_encode())
	status_changed.emit("正在连接…" if err == OK else "连接失败，正在重试…")

func disconnect_session() -> void:
	desired = false
	connected = false
	queue.clear()
	peer.close()

func send(type: String, fields: Dictionary = {}) -> void:
	var data: Dictionary = fields.duplicate(true)
	data["t"] = type
	if connected and peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		peer.send_text(JSON.stringify(data))
	elif desired and not type.begins_with("game."):
		if queue.size() < 16:
			queue.append(data)

func input_vector(direction: Vector2, running: bool) -> int:
	seq += 1
	send("game.input", {"seq": seq, "mx": direction.x, "my": direction.y, "run": running})
	return seq

func action(kind: String, fields: Dictionary = {}) -> void:
	var data: Dictionary = fields.duplicate()
	data["kind"] = kind
	send("game.action", data)

func now_ms() -> float:
	return Time.get_unix_time_from_system() * 1000.0 + clock_offset

func _process(_delta: float) -> void:
	if not desired:
		return
	peer.poll()
	var now: float = Time.get_ticks_msec() * 0.001
	var state: int = peer.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		while peer.get_available_packet_count() > 0:
			var parsed: Variant = JSON.parse_string(peer.get_packet().get_string_from_utf8())
			if not parsed is Dictionary:
				continue
			var data: Dictionary = parsed
			if data.get("t") == "hello":
				connected = true
				retry_count = 0
				clock_offset = float(data.serverNow) - Time.get_unix_time_from_system() * 1000.0
				status_changed.emit("")
				for queued: Dictionary in queue:
					peer.send_text(JSON.stringify(queued))
				queue.clear()
			if data.get("t") == "pong":
				var local_now: float = Time.get_unix_time_from_system() * 1000.0
				clock_offset = float(data.s) - (float(data.c) + local_now) * 0.5
			if data.get("t") == "game.snap":
				seq = maxi(seq, int(data.you.get("ackSeq", 0)))
			message.emit(data)
		if connected and now > ping_at:
			ping_at = now + 5.0
			send("ping", {"c": Time.get_unix_time_from_system() * 1000.0})
	elif state == WebSocketPeer.STATE_CLOSED:
		if connected:
			connected = false
			status_changed.emit("连接中断，正在重连…")
		if now > retry_at:
			retry_count += 1
			retry_at = now + minf(5.0, retry_count * 1.0)
			connect_session()
	elif state == WebSocketPeer.STATE_CONNECTING and now - attempt_at > 10.0:
		peer.close()
