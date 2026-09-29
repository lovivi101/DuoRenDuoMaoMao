extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var router: Node = root.get_node("Router")
	var session: Node = root.get_node("Session")
	router.enabled = false
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(32 * 24)
	for y: int in 24:
		for x: int in 32:
			if x == 0 or y == 0 or x == 31 or y == 23:
				bytes[y * 32 + x] = 1
	session.game = {"you": {"id": "test", "role": "hider"}, "players": [], "map": {"w":32, "h":24, "tiles":Marshalls.raw_to_base64(bytes), "hunterSpawn":{"x":16,"y":12}, "hiderSpawns":[{"x":16,"y":12}], "props":[], "generators":[]}}
	session.user = {"id":"test", "nickname":"测试玩家", "color":"blue"}
	session.snap = {"you":{"x":16.0,"y":12.0,"state":"normal","visionRadius":5.0,"stamina":4.0,"items":[null,null]}, "players":[], "alive":1, "totalHiders":1}
	session.phase = "hunt"
	session.phase_ends = Time.get_unix_time_from_system() * 1000.0 + 300000.0
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	for page: int in range(1, 20):
		var path: String = "res://scenes/ui/%02d.tscn" % page
		var packed: PackedScene = load(path)
		if packed == null:
			fail("missing " + path)
			return
		var standalone: Node = packed.instantiate()
		root.add_child(standalone)
		await process_frame
		standalone.queue_free()
		main.call("show_page", page)
		for frame: int in 3:
			await process_frame
		if main.get("active_page") == null:
			fail("empty page %d" % page)
			return
	for path: String in ["res://scenes/game/GameWorld.tscn", "res://scenes/game/GameHud.tscn"]:
		var scene: PackedScene = load(path)
		if scene == null:
			fail("missing " + path)
			return
		var node: Node = scene.instantiate()
		root.add_child(node)
		for frame: int in 3:
			await process_frame
		node.queue_free()
	print("SCENE_LOAD PASS: 19 pages and 2 game scenes")
	quit(0)

func fail(reason: String) -> void:
	push_error("SCENE_LOAD FAIL: " + reason)
	quit(1)
