extends Node
signal authorized(code: String)
signal failed(reason: String)
var sdk: Object
var pending: bool = false

func native_available() -> bool:
	return Engine.has_singleton("WeChatSDK")

func login() -> Dictionary:
	var code: Dictionary = await authorize_code("mock_" + Config.device_id())
	if not code.get("ok", false):
		return code
	return await Api.login("wechat", {"code": code.code})

## WeChat OAuth code for login or account binding. Without the native SDK (desktop / dev)
## a mock code is returned; the server accepts mock_* codes outside production.
func authorize_code(mock: String) -> Dictionary:
	if not native_available():
		return {"ok":true, "code":mock}
	sdk = Engine.get_singleton("WeChatSDK")
	if not sdk.has_method("authorize") or not sdk.has_signal("auth_result"):
		return {"ok":false, "msg":"微信插件接口未配置，请使用其他登录方式"}
	if pending:
		return {"ok":false, "msg":"微信授权进行中"}
	pending = true
	sdk.connect("auth_result", _on_auth_result, CONNECT_ONE_SHOT)
	sdk.call("authorize")
	get_tree().create_timer(60).timeout.connect(func() -> void:
		if pending:
			_on_auth_result("", "授权超时，请重试")
	)
	var code: String = await authorized
	if code.is_empty():
		return {"ok":false, "msg":"微信授权取消或超时"}
	return {"ok":true, "code":code}

func _on_auth_result(code: String, error: String) -> void:
	if not pending:
		return
	pending = false
	if not error.is_empty():
		failed.emit(error)
	authorized.emit(code)
