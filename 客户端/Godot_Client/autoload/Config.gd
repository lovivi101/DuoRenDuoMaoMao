extends Node
signal changed
const VERSION: String = "0.1.0"
const DEFAULT_SERVER: String = "http://127.0.0.1:8787"
var server_url: String = DEFAULT_SERVER
var settings: Dictionary = {"volume": 0.7, "visual_audio": true, "colorblind": false, "vibration": true, "quality": 1, "left_hand": false, "shake": true}
var demo: bool = false
# Debug-only autoplay (--autoplay): AutoPlay.gd drives a real match and sets the move direction.
var autoplay: bool = false
var autoplay_dir: Vector2 = Vector2.ZERO

func _ready() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		for key: String in settings:
			settings[key] = cfg.get_value("settings", key, settings[key])
		server_url = str(cfg.get_value("debug", "server_url", DEFAULT_SERVER))
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--server="):
			server_url = arg.trim_prefix("--server=").trim_suffix("/")
		if arg.begins_with("--shot="):
			demo = true

func save() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	for key: String in settings:
		cfg.set_value("settings", key, settings[key])
	cfg.set_value("debug", "server_url", server_url)
	cfg.save("user://settings.cfg")
	changed.emit()

func ws_url() -> String:
	return server_url.replace("https://", "wss://").replace("http://", "ws://") + "/ws"

func device_id() -> String:
	var id: String = OS.get_unique_id()
	return id if id.length() >= 4 else "desktop_" + OS.get_user_data_dir().sha256_text().left(24)
