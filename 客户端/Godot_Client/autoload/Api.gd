extends Node
signal busy_changed(busy: bool)
var pending: int = 0

func request(path: String, body: Dictionary = {}, method: int = HTTPClient.METHOD_POST) -> Dictionary:
	var http: HTTPRequest = HTTPRequest.new()
	http.timeout = 12.0
	add_child(http)
	pending += 1
	busy_changed.emit(true)
	var headers: PackedStringArray = ["Content-Type: application/json"]
	if not Session.token.is_empty():
		headers.append("Authorization: Bearer " + Session.token)
	var err: Error = http.request(Config.server_url + "/api" + path, headers, method, "" if method == HTTPClient.METHOD_GET else JSON.stringify(body))
	var data: Dictionary = {"ok": false, "code": "NETWORK", "msg": "无法连接服务器，请检查网络或服务器地址"}
	if err == OK:
		var response: Array = await http.request_completed
		if int(response[0]) == HTTPRequest.RESULT_SUCCESS:
			var decoded: Variant = JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
			if decoded is Dictionary:
				data = decoded
		else:
			data.msg = "请求超时或连接中断，请重试"
	http.queue_free()
	pending -= 1
	busy_changed.emit(pending > 0)
	return data

func get_json(path: String) -> Dictionary:
	return await request(path, {}, HTTPClient.METHOD_GET)

func login(kind: String, fields: Dictionary) -> Dictionary:
	var response: Dictionary = await request("/auth/" + kind, fields)
	if response.get("ok", false):
		Session.accept_login(response)
	return response
