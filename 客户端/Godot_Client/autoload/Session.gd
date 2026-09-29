extends Node
signal updated(type: String)
var token: String = ""
var user: Dictionary = {}
var room: Dictionary = {}
var game: Dictionary = {}
var snap: Dictionary = {}
var result: Dictionary = {}
var phase: String = ""
var phase_ends: float = 0.0
var vote: Dictionary = {}
var match_status: Dictionary = {}
var drops: Array = []
var event: Dictionary = {}
var last_caught: Dictionary = {}
var consent: bool = false

func _ready() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load("user://session.cfg") == OK:
		token = str(cfg.get_value("auth", "token", ""))
	Net.message.connect(receive)

func accept_login(data: Dictionary) -> void:
	token = str(data.token)
	user = data.user
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("auth", "token", token)
	cfg.save("user://session.cfg")
	Net.connect_session()

func logout() -> void:
	Net.disconnect_session()
	token = ""
	user.clear()
	room.clear()
	game.clear()
	snap.clear()
	var cfg: ConfigFile = ConfigFile.new()
	cfg.save("user://session.cfg")
	Router.go(2)

func receive(data: Dictionary) -> void:
	var type: String = str(data.get("t", ""))
	match type:
		"hello": user = data.user
		"room.state":
			room = data
			if data.phase == "waiting":
				phase = "waiting"
				Router.go(10)
		"room.left":
			room.clear()
			game.clear()
			snap.clear()
			Router.go(6)
		"match.status": match_status = data
		"vote.start":
			vote = data
			Router.go(11)
		"vote.update":
			vote["counts"] = data.counts
			vote["voters"] = data.get("voters", [])
		"game.start":
			game = data
			snap.clear()
			result.clear()
			drops.clear()
			event.clear()
			Router.go(12)
		"game.phase":
			phase = str(data.phase)
			phase_ends = float(data.endsAt)
			if phase in ["hide", "hunt", "final"] and Router.current not in [13,14,15,16]:
				Router.go(14 if role() == "hunter" else 13)
		"game.snap": snap = data
		"game.drop":
			for drop: Dictionary in data.drops:
				var found: bool = false
				for i: int in drops.size():
					if drops[i].id == drop.id:
						drops[i] = drop
						found = true
				if not found:
					drops.append(drop)
		"game.event": event = data
		"game.caught": last_caught = data
		"game.result":
			result = data
			Router.go(17)
		"invite": Router.invite(data)
		"error":
			Router.toast(error_text(str(data.get("code", "")), str(data.get("msg", "请求失败"))))
			if data.get("code") == "UNAUTHORIZED":
				logout()
	updated.emit(type)

func role() -> String:
	return str(game.get("you", {}).get("role", "hider"))

func me() -> Dictionary:
	return snap.get("you", {})

func is_host() -> bool:
	return not room.is_empty() and str(room.get("hostId", "")) == str(user.get("id", "?"))

func error_text(code: String, fallback: String) -> String:
	return {"NOT_READY":"还有玩家未准备", "NOT_ENOUGH":"至少需要 8 人，请添加 AI 或开启补位", "NOT_FOUND":"未找到房间或玩家", "ROOM_FULL":"房间已满", "ROOM_BUSY":"房间已开始", "ALREADY_IN_ROOM":"你已在房间中", "FRIEND_OFFLINE":"好友不在线", "AI_FILL_TOO_EARLY":"匹配满 60 秒后可 AI 补位", "HOST_ONLY":"仅房主可以操作"}.get(code, fallback)
