extends Node2D

var canvas: Control
var active_page: Control
var toast_layer: Control
var pages: Dictionary = {}
var nickname_edit: LineEdit
var phone_edit: LineEdit
var code_edit: LineEdit
var account_edit: LineEdit
var password_edit: LineEdit
var room_code_edit: LineEdit
var consent_box: CheckBox
var countdown: float = 0.0
var screenshot_done: bool = false
var register_mode: bool = false
var game_world: GameWorld
var page_layer: CanvasLayer
# Scene art per page (素材 01-背景); pages without art keep the plain dark colour.
const PAGE_BACKGROUNDS: Dictionary = {1: "bg-splash-dorm-night", 2: "bg-login-dorm-gate", 3: "bg-login-dorm-gate", 4: "bg-login-dorm-gate", 5: "bg-lobby-dorm-hall", 6: "bg-lobby-dorm-hall", 7: "bg-matching-corridor", 8: "bg-room-waiting-hall", 9: "bg-room-waiting-hall", 10: "bg-room-waiting-hall", 11: "bg-map-vote-blueprint", 12: "bg-role-reveal-dark", 17: "bg-result-dawn", 18: "bg-menu-dim", 19: "bg-menu-dim"}
# Form-heavy pages get a dark veil over the scene so text stays readable.
const DIMMED_PAGES: Array[int] = [3, 4, 8, 9, 10, 17, 18, 19]

func _ready() -> void:
	Router.navigate.connect(show_page)
	Router.toast_requested.connect(show_toast)
	Net.status_changed.connect(_on_net_status)
	Session.updated.connect(_on_session_update)
	page_layer = CanvasLayer.new()
	add_child(page_layer)
	canvas = Control.new()
	canvas.size = Vector2(1334, 750)
	page_layer.add_child(canvas)
	get_viewport().size_changed.connect(_fit_canvas)
	_fit_canvas()
	toast_layer = Control.new()
	toast_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	toast_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(toast_layer)
	var initial: int = 1
	Router.current = -1
	show_page(initial)
	call_deferred("startup_check")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			call_deferred("prepare_debug_shot", arg.trim_prefix("--shot="))
		if arg == "--autoplay":
			add_child(load("res://scripts/AutoPlay.gd").new())

func refresh_me() -> void:
	var response: Dictionary = await Api.get_json("/me")
	if response.get("ok", false):
		Session.user = response.user
		Router.go(5 if Session.user.get("needsProfile", false) else 6)
	else:
		Session.logout()

func startup_check() -> void:
	if Config.demo:
		return
	var response: Dictionary = await Api.get_json("/notice")
	if response.get("ok", false) and not response.get("notices", []).is_empty():
		var notice: Dictionary = response.notices[0]
		show_toast(str(notice.get("title", "公告")) + " · " + str(notice.get("body", "")))
	if not Session.token.is_empty():
		Net.connect_session()
		await refresh_me()

func _fit_canvas() -> void:
	if not is_instance_valid(canvas): return
	var viewport_size: Vector2 = get_viewport_rect().size
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var margin: float = 22.0 if safe.size.x <= 0 else clampf(float(safe.position.x), 16.0, 72.0)
	var usable: Vector2 = viewport_size - Vector2(margin * 2.0, 16.0)
	var scale_factor: float = minf(usable.x / 1334.0, usable.y / 750.0)
	canvas.scale = Vector2.ONE * scale_factor
	canvas.position = (viewport_size - Vector2(1334, 750) * scale_factor) * 0.5

func _process(delta: float) -> void:
	if countdown > 0:
		countdown -= delta
		if is_instance_valid(active_page):
			var label: Label = active_page.find_child("Countdown", true, false) as Label
			if label:
				label.text = "%02ds 后重发" % ceili(countdown)
	# Screenshot capture is scheduled after the requested page is fully rendered.

func show_page(page: int) -> void:
	if not is_instance_valid(canvas):
		return
	if page not in [13, 14, 15, 16] and is_instance_valid(game_world):
		game_world.queue_free()
		game_world = null
	for child: Node in canvas.get_children():
		if child != toast_layer:
			child.queue_free()
	var scene: PackedScene = load(Router.page_path(page))
	active_page = scene.instantiate() as Control
	active_page.name = "Page%02d" % page
	active_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(active_page)
	canvas.move_child(toast_layer, -1)
	Router.current = page
	_build_page(page)

func _build_page(page: int) -> void:
	if page in [13, 14, 16]:
		if not is_instance_valid(game_world):
			game_world = GameWorld.new()
			add_child(game_world)
			move_child(game_world, 0)
		var hud: GameHud = GameHud.new()
		hud.world = game_world
		hud.size = Vector2(1334, 750)
		active_page.add_child(hud)
		return
	var bg: ColorRect = ColorRect.new()
	# The ghost choice overlays the live match: the world stays visible underneath.
	bg.color = Color(0.03, 0.02, 0.08, 0.55) if page == 15 else UiAssets.bg_for(page)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	active_page.add_child(bg)
	var bg_name: String = PAGE_BACKGROUNDS.get(page, "")
	var bg_tex: Texture2D = UiAssets.asset("bg/" + bg_name)
	if bg_tex:
		var backdrop: TextureRect = TextureRect.new()
		backdrop.texture = bg_tex
		backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		backdrop.size = Vector2(1334, 750)
		backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		active_page.add_child(backdrop)
		if page in DIMMED_PAGES:
			var dim: ColorRect = ColorRect.new()
			dim.color = Color(0.03, 0.02, 0.08, 0.45)
			dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
			active_page.add_child(dim)
	if page <= 6 or page in [8, 9, 10, 11, 12, 17, 18, 19]:
		_build_backdrop(page)
	match page:
		1: _build_splash()
		2: _build_login()
		3: _build_sms()
		4: _build_account()
		5: _build_profile()
		6: _build_lobby()
		7: _build_match()
		8: _build_create_room()
		9: _build_join_room()
		10: _build_waiting()
		11: _build_vote()
		12: _build_role_reveal()
		13, 14: _build_hud(page)
		15: _build_ghost()
		16: _build_event()
		17: _build_result()
		18: _build_friends()
		19: _build_settings()

func _build_backdrop(page: int) -> void:
	var logo_tex: Texture2D = UiAssets.asset("logo/game_logo_title")
	if logo_tex:
		var logo: TextureRect = TextureRect.new(); logo.texture = logo_tex
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; logo.position = Vector2(36, 18); logo.size = Vector2(230, 78); logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		active_page.add_child(logo)
	else:
		var title: Label = _label("熄灯", Vector2(42, 28), Vector2(250, 70), 42, UiAssets.COLOR_GOLD)
		active_page.add_child(title)
	var sub: Label = _label("当灯光熄灭，第一缕脚步声开始", Vector2(48, 92), Vector2(380, 30), 14, UiAssets.COLOR_MUTED)
	active_page.add_child(sub)
	var moon: Label = _label("☾", Vector2(1160, 26), Vector2(100, 100), 80, Color("b7c5ff"))
	active_page.add_child(moon)

func _build_splash() -> void:
	var logo: Label = _label("熄灯", Vector2(0, 175), Vector2(1334, 100), 82, UiAssets.COLOR_GOLD)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_page.add_child(logo)
	var slogan: Label = _label("当灯光熄灭，第一缕脚步声开始。", Vector2(0, 275), Vector2(1334, 35), 18, UiAssets.COLOR_TEXT)
	slogan.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_page.add_child(slogan)
	var progress: ProgressBar = ProgressBar.new()
	progress.position = Vector2(430, 575); progress.size = Vector2(474, 20); progress.value = 68
	progress.add_theme_stylebox_override("background", UiAssets.button(Color("493b72"))); progress.add_theme_stylebox_override("fill", UiAssets.button(UiAssets.COLOR_GOLD)); active_page.add_child(progress)
	var status: Label = _label("正在更新资源… 68%", Vector2(0, 610), Vector2(1334, 30), 16, UiAssets.COLOR_MUTED); status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; active_page.add_child(status)
	get_tree().create_timer(1.1).timeout.connect(func() -> void:
		if Router.current == 1 and Session.token.is_empty(): Router.go(2))

func _build_login() -> void:
	var panel: Panel = _panel(Vector2(770, 125), Vector2(490, 510)); active_page.add_child(panel)
	var title: Label = _label("登录熄灯", Vector2(0, 24), Vector2(490, 60), 34, UiAssets.COLOR_TEXT); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; panel.add_child(title)
	var note: Label = _label("和朋友一起，关灯后见", Vector2(0, 80), Vector2(490, 30), 15, UiAssets.COLOR_MUTED); note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; panel.add_child(note)
	var wechat: Button = _button("  微信快捷登录  ", Vector2(50, 135), Vector2(390, 68), UiAssets.COLOR_GREEN); wechat.pressed.connect(_wechat_login); panel.add_child(wechat)
	if not WeChat.native_available():
		var dev: Label = _label("开发模式 · 微信 Mock", Vector2(0, 207), Vector2(490, 25), 13, UiAssets.COLOR_GREEN); dev.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; panel.add_child(dev)
	var phone: Button = _button("手机号登录", Vector2(50, 255), Vector2(185, 55), Color("3959b8")); phone.pressed.connect(func() -> void: if _consented(): Router.go(3)); panel.add_child(phone)
	var account: Button = _button("账号密码登录", Vector2(255, 255), Vector2(185, 55), Color("7047b9")); account.pressed.connect(func() -> void: if _consented(): Router.go(4)); panel.add_child(account)
	var guest: Button = _button("游客体验", Vector2(50, 325), Vector2(390, 55), Color("373653")); guest.pressed.connect(_guest_login); panel.add_child(guest)
	consent_box = CheckBox.new(); consent_box.text = "我已阅读并同意《用户协议》和《隐私政策》"; consent_box.position = Vector2(44, 402); consent_box.size = Vector2(410, 35); consent_box.button_pressed = Session.consent; consent_box.toggled.connect(func(value: bool) -> void: Session.consent = value); consent_box.add_theme_font_size_override("font_size", 14); panel.add_child(consent_box)
	var age: Label = _label("适龄提示 12+", Vector2(44, 455), Vector2(150, 25), 13, UiAssets.COLOR_MUTED); panel.add_child(age)

func _consented() -> bool:
	if Session.consent: return true
	show_toast("请先阅读并同意用户协议")
	if is_instance_valid(consent_box):
		var tween: Tween = create_tween(); tween.tween_property(consent_box, "position:x", 50.0, 0.04); tween.tween_property(consent_box, "position:x", 38.0, 0.04); tween.tween_property(consent_box, "position:x", 44.0, 0.04)
	return false

func _wechat_login() -> void:
	if not _consented(): return
	var response: Dictionary = await WeChat.login()
	if response.get("ok", false): _after_login(response)
	else: show_toast(str(response.get("msg", "微信登录失败")))

func _guest_login() -> void:
	if not _consented(): return
	var response: Dictionary = await Api.login("guest", {"deviceId": Config.device_id()})
	if response.get("ok", false): _after_login(response)
	else: show_toast(str(response.get("msg", "登录失败")))

func _after_login(response: Dictionary) -> void:
	if response.user.get("needsProfile", false): Router.go(5)
	else: Router.go(6)

func _build_sms() -> void:
	_build_form_header("手机号登录", 3)
	var panel: Panel = _panel(Vector2(430, 145), Vector2(474, 470)); active_page.add_child(panel)
	phone_edit = _edit("请输入手机号", Vector2(38, 85), Vector2(398, 52)); panel.add_child(phone_edit)
	code_edit = _edit("请输入验证码", Vector2(38, 155), Vector2(230, 52)); panel.add_child(code_edit)
	var send: Button = _button("获取验证码", Vector2(280, 155), Vector2(156, 52), Color("3959b8")); send.pressed.connect(_send_sms); panel.add_child(send)
	var countdown_label: Label = _label("", Vector2(285, 211), Vector2(140, 28), 14, UiAssets.COLOR_MUTED); countdown_label.name = "Countdown"; panel.add_child(countdown_label)
	var login: Button = _button("登 录", Vector2(38, 260), Vector2(398, 62), UiAssets.COLOR_GOLD); login.pressed.connect(_sms_login); panel.add_child(login)
	var hint: Label = _label("未配置短信服务时，验证码会以开发提示显示", Vector2(38, 345), Vector2(398, 45), 13, UiAssets.COLOR_MUTED); hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; panel.add_child(hint)

func _send_sms() -> void:
	if countdown > 0:
		show_toast("请稍后再发送")
		return
	var response: Dictionary = await Api.request("/auth/sms/send", {"phone": phone_edit.text})
	if response.get("ok", false):
		countdown = float(response.get("cooldown", 60))
		show_toast("开发验证码：" + str(response.devCode) if response.has("devCode") else "验证码已发送")
	else: show_toast(str(response.get("msg", "发送失败")))

func _sms_login() -> void:
	if not _consented(): return
	var response: Dictionary = await Api.login("sms/login", {"phone": phone_edit.text, "code": code_edit.text})
	if response.get("ok", false): _after_login(response)
	else: show_toast(str(response.get("msg", "登录失败")))

func _build_account() -> void:
	_build_form_header("账号密码登录", 4)
	var panel: Panel = _panel(Vector2(430, 120), Vector2(474, 515)); active_page.add_child(panel)
	var login_tab: Button = _button("登录", Vector2(40, 24), Vector2(190, 42), UiAssets.COLOR_GOLD if not register_mode else Color("4c3d80")); login_tab.pressed.connect(func() -> void: register_mode = false; Router.go(4); show_page(4)); panel.add_child(login_tab)
	var register_tab: Button = _button("注册", Vector2(244, 24), Vector2(190, 42), UiAssets.COLOR_GOLD if register_mode else Color("4c3d80")); register_tab.pressed.connect(func() -> void: register_mode = true; show_page(4)); panel.add_child(register_tab)
	account_edit = _edit("请输入账号", Vector2(40, 100), Vector2(394, 55)); panel.add_child(account_edit)
	password_edit = _edit("请输入密码", Vector2(40, 175), Vector2(394, 55)); password_edit.secret = true; panel.add_child(password_edit)
	var reveal: Button = _button("显示", Vector2(347, 178), Vector2(85, 48), Color("4c3d80")); reveal.pressed.connect(func() -> void: password_edit.secret = not password_edit.secret); panel.add_child(reveal)
	var login: Button = _button("注 册" if register_mode else "登 录", Vector2(40, 290), Vector2(394, 62), UiAssets.COLOR_GOLD); login.pressed.connect(_account_login); panel.add_child(login)

func _account_login() -> void:
	if not _consented(): return
	var response: Dictionary = await Api.login("register" if register_mode else "password", {"account": account_edit.text, "password": password_edit.text})
	if response.get("ok", false): _after_login(response)
	else: show_toast(str(response.get("msg", "登录失败")))

func _random_name() -> void:
	var response: Dictionary = await Api.get_json("/profile/random-name")
	if response.get("ok", false) and is_instance_valid(nickname_edit):
		nickname_edit.text = str(response.get("nickname", "小夜猫"))

func _build_profile() -> void:
	_build_form_header("创建角色", 5)
	var panel: Panel = _panel(Vector2(420, 105), Vector2(500, 575)); active_page.add_child(panel)
	var name_label: Label = _label("昵称", Vector2(34, 34), Vector2(100, 30), 18, UiAssets.COLOR_GOLD); panel.add_child(name_label)
	nickname_edit = _edit("输入 2–12 字昵称", Vector2(34, 72), Vector2(360, 52)); nickname_edit.text = "小夜猫"; panel.add_child(nickname_edit)
	var dice: Button = _button("🎲", Vector2(405, 72), Vector2(60, 52), Color("4d4385")); dice.pressed.connect(_random_name); panel.add_child(dice)
	var color_label: Label = _label("选择形象", Vector2(34, 150), Vector2(150, 30), 18, UiAssets.COLOR_GOLD); panel.add_child(color_label)
	for i: int in 8:
		var b: Button = _button("", Vector2(34 + (i % 4) * 108, 200 + (i / 4) * 78), Vector2(82, 58), UiAssets.COLORS[i]); b.tooltip_text = ["红","橙","黄","绿","青","蓝","紫","粉"][i]; b.pressed.connect(func() -> void: Session.user["color"] = ["red","orange","yellow","green","cyan","blue","purple","pink"][i]); panel.add_child(b)
	var enter: Button = _button("进入游戏  ▶", Vector2(34, 395), Vector2(432, 68), UiAssets.COLOR_GOLD); enter.pressed.connect(_create_profile); panel.add_child(enter)

func _create_profile() -> void:
	var response: Dictionary = await Api.request("/profile", {"nickname": nickname_edit.text, "color": str(Session.user.get("color", "blue"))})
	if response.get("ok", false): Session.user = response.user; Router.go(6)
	else: show_toast(str(response.get("msg", "创建失败")))

func _build_lobby() -> void:
	var user_panel: Panel = _panel(Vector2(45, 130), Vector2(315, 84)); active_page.add_child(user_panel)
	var nickname: Label = _label(str(Session.user.get("nickname", "游客")) + "  Lv." + str(Session.user.get("level", 1)), Vector2(70, 146), Vector2(250, 35), 19, UiAssets.COLOR_TEXT); active_page.add_child(nickname)
	var center: Label = _label("☾", Vector2(430, 190), Vector2(450, 190), 170, Color("b7c5ff")); center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; active_page.add_child(center)
	var hint: Label = _label("今晚也要安全回家", Vector2(430, 380), Vector2(450, 40), 20, UiAssets.COLOR_MUTED); hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; active_page.add_child(hint)
	var quick: Button = _button("快速匹配  ▶", Vector2(965, 180), Vector2(300, 72), UiAssets.COLOR_GOLD); quick.add_theme_font_size_override("font_size", 25); quick.pressed.connect(_match_start); active_page.add_child(quick)
	var create: Button = _button("创建房间", Vector2(965, 270), Vector2(145, 58), Color("3b65c2")); create.pressed.connect(func() -> void: Router.go(8)); active_page.add_child(create)
	var join: Button = _button("加入房间", Vector2(1120, 270), Vector2(145, 58), Color("7047b9")); join.pressed.connect(func() -> void: Router.go(9)); active_page.add_child(join)
	var bottom: Panel = _panel(Vector2(30, 640), Vector2(1274, 78)); active_page.add_child(bottom)
	for i: int in 5:
		var labels: Array[String] = ["好友", "衣柜", "商店", "战绩", "任务"]
		var b: Button = _button(labels[i], Vector2(35 + i * 245, 652), Vector2(180, 50), Color("302857")); b.pressed.connect(func() -> void: if i == 0: Router.go(18)
		else: show_toast("敬请期待")); active_page.add_child(b)
	var setting: Button = _button("⚙", Vector2(1210, 28), Vector2(72, 54), Color("302857")); setting.pressed.connect(func() -> void: Router.go(19)); active_page.add_child(setting)

func _match_start() -> void:
	Net.send("match.start"); Router.go(7)

func _build_match() -> void:
	var panel: Panel = _panel(Vector2(350, 95), Vector2(634, 550)); active_page.add_child(panel)
	var title: Label = _label("快速匹配中 ☾", Vector2(0, 28), Vector2(634, 45), 30, UiAssets.COLOR_GOLD); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; panel.add_child(title)
	var timer: Label = _label("01:05", Vector2(0, 83), Vector2(634, 68), 48, UiAssets.COLOR_TEXT); timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; panel.add_child(timer)
	var status: Label = _label("正在寻找玩家…  已找到 %d/8" % int(Session.match_status.get("found", 1)), Vector2(0, 165), Vector2(634, 35), 18, UiAssets.COLOR_MUTED); status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; panel.add_child(status)
	for i: int in 12:
		var slot: Button = _button("●" if i < int(Session.match_status.get("found", 1)) else "?", Vector2(80 + (i % 6) * 82, 235 + (i / 6) * 82), Vector2(64, 64), UiAssets.COLORS[i % 8] if i < 8 else Color("393454")); panel.add_child(slot)
	var cancel: Button = _button("取消匹配", Vector2(80, 440), Vector2(210, 58), Color("4b426d")); cancel.pressed.connect(func() -> void: Net.send("match.cancel"); Router.go(6)); panel.add_child(cancel)
	var ai: Button = _button("AI 补位开局", Vector2(344, 440), Vector2(210, 58), UiAssets.COLOR_GOLD); ai.pressed.connect(func() -> void: Net.send("match.aiFill")); panel.add_child(ai)
	if not bool(Session.match_status.get("canAiFill", false)): ai.disabled = true

func _build_create_room() -> void:
	_build_form_header("创建房间", 8)
	var panel: Panel = _panel(Vector2(330, 110), Vector2(674, 570)); active_page.add_child(panel)
	var map_title: Label = _label("选择地图", Vector2(35, 35), Vector2(200, 35), 20, UiAssets.COLOR_GOLD); panel.add_child(map_title)
	var map_card: Button = _button("旧宿舍楼\n\n3×3  中心辐射", Vector2(35, 85), Vector2(260, 230), Color("30406f")); map_card.add_theme_font_size_override("font_size", 20); panel.add_child(map_card)
	var settings: Label = _label("房间设置", Vector2(340, 35), Vector2(250, 35), 20, UiAssets.COLOR_GOLD); panel.add_child(settings)
	var opts: Label = _label("对局时长   5分钟   8分钟   10分钟\n\n猎手人数   自动\n\n卧底模式   关\n\n近距离语音   关\n\nAI 补位     开", Vector2(340, 85), Vector2(290, 260), 17, UiAssets.COLOR_TEXT); panel.add_child(opts)
	var create: Button = _button("创建房间  ▶", Vector2(190, 465), Vector2(294, 65), UiAssets.COLOR_GOLD); create.pressed.connect(_create_room); panel.add_child(create)

func _create_room() -> void:
	Net.send("room.create", {"settings": {"map":"old_dorm", "durationSec":300, "hunterCount":"auto", "moleEnabled":false, "voiceEnabled":false, "aiFill":true, "maxPlayers":8}})
	Router.go(10)

func _build_join_room() -> void:
	_build_form_header("加入房间", 9)
	var panel: Panel = _panel(Vector2(420, 125), Vector2(494, 525)); active_page.add_child(panel)
	var title: Label = _label("输入 6 位房间码", Vector2(0, 35), Vector2(494, 45), 24, UiAssets.COLOR_GOLD); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; panel.add_child(title)
	room_code_edit = _edit("六位数字", Vector2(47, 105), Vector2(400, 60)); room_code_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER; room_code_edit.add_theme_font_size_override("font_size", 26); panel.add_child(room_code_edit)
	room_code_edit.max_length = 6
	var paste: Button = _button("粘贴", Vector2(340, 108), Vector2(100, 54), Color("4b426d")); paste.pressed.connect(func() -> void: room_code_edit.text = DisplayServer.clipboard_get().strip_edges().left(6)); panel.add_child(paste)
	var keypad: Array[String] = ["1","2","3","4","5","6","7","8","9","清空","0","删除"]
	for i: int in 12:
		var b: Button = _button(keypad[i], Vector2(47 + (i % 3) * 135, 195 + (i / 3) * 58), Vector2(125, 48), Color("39345f")); b.pressed.connect(func() -> void: _keypad_press(keypad[i])); panel.add_child(b)
	var join: Button = _button("加入房间  ▶", Vector2(47, 420), Vector2(400, 62), UiAssets.COLOR_GOLD); join.pressed.connect(_join_room); panel.add_child(join)

func _keypad_press(key: String) -> void:
	if not room_code_edit: return
	if key == "清空": room_code_edit.text = ""
	elif key == "删除": room_code_edit.text = room_code_edit.text.left(-1)
	elif room_code_edit.text.length() < 6: room_code_edit.text += key

func _join_room() -> void:
	if room_code_edit.text.length() != 6 or not room_code_edit.text.is_valid_int():
		show_toast("请输入 6 位数字房间码")
		return
	Net.send("room.join", {"code": room_code_edit.text}); Router.go(10)

func _build_waiting() -> void:
	_build_form_header("房间等待", 10)
	var code: Button = _button("房间码  " + str(Session.room.get("code", "------")) + "   ⧉", Vector2(465, 95), Vector2(420, 45), Color("45406d")); code.pressed.connect(func() -> void: DisplayServer.clipboard_set(str(Session.room.get("code", ""))); show_toast("房间码已复制")); active_page.add_child(code)
	var players: Array = Session.room.get("players", [])
	for i: int in 12:
		var p: Dictionary = players[i] if i < players.size() else {}
		var name: String = str(p.get("nickname", "等待加入"))
		var card: Panel = _panel(Vector2(350 + (i % 6) * 112, 160 + (i / 6) * 155), Vector2(100, 125)); card.add_theme_stylebox_override("panel", UiAssets.panel()); active_page.add_child(card)
		card.add_child(_avatar(p, Vector2(24, 20), 52))
		var label: Label = _label(("♛ " if p.get("isHost", false) else "") + name.left(6), Vector2(5, 72), Vector2(90, 24), 13, UiAssets.COLOR_TEXT); label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; card.add_child(label)
		var ready: Label = _label("✓ 已准备" if p.get("ready", false) else "等待中", Vector2(5, 96), Vector2(90, 22), 11, UiAssets.COLOR_GREEN if p.get("ready", false) else UiAssets.COLOR_MUTED); ready.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; card.add_child(ready)
		if Session.is_host() and p.get("isBot", false):
			var kick: Button = _button("踢出", Vector2(62, 2), Vector2(36, 18), UiAssets.COLOR_RED); kick.add_theme_font_size_override("font_size", 10); kick.pressed.connect(func() -> void: Net.send("room.kick", {"playerId":str(p.get("id", ""))})); card.add_child(kick)
	var invite: Button = _button("邀请好友", Vector2(400, 535), Vector2(170, 58), Color("5941a5")); invite.pressed.connect(func() -> void: Router.go(18)); active_page.add_child(invite)
	var my_ready: bool = false
	for p: Dictionary in players:
		if p.get("id") == Session.user.get("id"): my_ready = bool(p.get("ready", false))
	var ready_btn: Button = _button("取消准备" if my_ready else "准备", Vector2(590, 535), Vector2(170, 58), UiAssets.COLOR_GOLD); ready_btn.pressed.connect(func() -> void: Net.send("room.ready", {"ready":not my_ready})); active_page.add_child(ready_btn)
	var start: Button = _button("开始游戏  ▶", Vector2(780, 535), Vector2(190, 58), UiAssets.COLOR_GOLD); start.pressed.connect(func() -> void: Net.send("room.start")); start.disabled = not Session.is_host(); active_page.add_child(start)
	var add_ai: Button = _button("+ AI", Vector2(1030, 535), Vector2(110, 58), Color("4b629c")); add_ai.pressed.connect(func() -> void: Net.send("room.addBot")); add_ai.visible = Session.is_host(); active_page.add_child(add_ai)
	var leave: Button = _button("离开房间", Vector2(1170, 535), Vector2(120, 58), Color("654364")); leave.pressed.connect(func() -> void: Net.send("room.leave")); active_page.add_child(leave)

func _build_vote() -> void:
	_build_form_header("地图投票", 11)
	var timer: Label = _label("10s", Vector2(1120, 60), Vector2(130, 50), 34, UiAssets.COLOR_GOLD); active_page.add_child(timer); countdown = maxf(0, (float(Session.vote.get("endsAt", 0)) - Net.now_ms()) / 1000.0)
	for i: int in 3:
		var map: Button = _button("旧宿舍楼\n\n推荐地图\n" + str(Session.vote.get("counts", {}).get("old_dorm", 0)) + " 票", Vector2(120 + i * 380, 180), Vector2(300, 270), Color("283a68")); map.add_theme_font_size_override("font_size", 22); map.pressed.connect(func() -> void: Net.send("vote.cast", {"mapId":"old_dorm"})); active_page.add_child(map)

func _build_role_reveal() -> void:
	var title: Label = _label("你的身份是…", Vector2(0, 75), Vector2(1334, 60), 34, UiAssets.COLOR_GOLD); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; active_page.add_child(title)
	var role: String = Session.role(); var role_name: String = {"hunter":"猎手", "hider":"藏者", "mole":"卧底"}.get(role, "藏者")
	var card: Panel = _panel(Vector2(457, 180), Vector2(420, 390)); active_page.add_child(card)
	var role_label: Label = _label(role_name, Vector2(0, 105), Vector2(420, 75), 54, UiAssets.COLOR_RED if role == "hunter" else UiAssets.COLOR_GOLD); role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; card.add_child(role_label)
	var desc: Label = _label("利用黑暗与脚步声，活到最后！" if role != "hunter" else "找到并拍打所有藏者！", Vector2(30, 220), Vector2(360, 50), 17, UiAssets.COLOR_TEXT); desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; card.add_child(desc)
	var timer: Label = _label("5s", Vector2(1100, 55), Vector2(150, 55), 40, UiAssets.COLOR_GOLD); active_page.add_child(timer); countdown = 5.0

func _build_hud(page: int) -> void:
	var modulate: ColorRect = ColorRect.new(); modulate.color = Color("0c0a1a"); modulate.color.a = 0.82; modulate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); active_page.add_child(modulate); active_page.move_child(modulate, 1)
	var role: String = "猎手" if page == 14 else ("卧底" if Session.role() == "mole" else "藏者")
	var alive: Label = _label("存活 %d/%d" % [int(Session.snap.get("alive", 6)), int(Session.snap.get("totalHiders", 8))], Vector2(34, 28), Vector2(180, 45), 24, UiAssets.COLOR_TEXT); active_page.add_child(alive)
	var time_left: float = maxf(0, (float(Session.phase_ends) - Net.now_ms()) / 1000.0); var timer: Label = _label("%02d:%02d" % [int(time_left) / 60, int(time_left) % 60], Vector2(575, 26), Vector2(185, 55), 34, UiAssets.COLOR_RED if time_left < 30 else UiAssets.COLOR_GOLD); timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; active_page.add_child(timer)
	var minimap: Panel = _panel(Vector2(1080, 30), Vector2(220, 150)); active_page.add_child(minimap); var mini: Label = _label("┌────────┐\n│  ▪  ⚡  │\n│    ●   │\n│ ⚡   ▪ │\n└────────┘", Vector2(20, 18), Vector2(180, 115), 20, Color("9da8d9")); minimap.add_child(mini)
	var joystick: Panel = _panel(Vector2(65, 535), Vector2(200, 150)); active_page.add_child(joystick); var joy: Label = _label("◉", Vector2(40, 24), Vector2(120, 100), 72, Color("8991bf")); joystick.add_child(joy)
	var stamina: ProgressBar = ProgressBar.new(); stamina.position = Vector2(80, 510); stamina.size = Vector2(170, 15); stamina.value = float(Session.me().get("stamina", 3.0)) / 4.0 * 100.0; stamina.add_theme_stylebox_override("background", UiAssets.button(Color("384266"))); stamina.add_theme_stylebox_override("fill", UiAssets.button(Color("65c466"))); active_page.add_child(stamina)
	var main: Button = _button("拍打" if page == 14 else "交互", Vector2(1090, 535), Vector2(150, 150), UiAssets.COLOR_RED if page == 14 else UiAssets.COLOR_GOLD); main.add_theme_font_size_override("font_size", 25); main.pressed.connect(func() -> void: Net.action("slap" if page == 14 else "interact_start")); active_page.add_child(main)
	var skill: Button = _button("手电" if page == 14 else "伪装", Vector2(975, 565), Vector2(100, 100), Color("3959b8")); skill.pressed.connect(func() -> void: Net.action("flashlight" if page == 14 else "disguise", {"prop":"cardboard_box"})); active_page.add_child(skill)
	for i: int in 2:
		var item: Button = _button("道具%d" % (i + 1), Vector2(1225, 420 + i * 98), Vector2(90, 76), Color("35557c")); item.pressed.connect(func() -> void: Net.action("use_item", {"slot":i})); active_page.add_child(item)
	var role_label: Label = _label(role, Vector2(34, 90), Vector2(120, 35), 15, UiAssets.COLOR_RED if page == 14 else UiAssets.COLOR_GOLD); active_page.add_child(role_label)
	if Session.event:
		var event_label: Label = _label("⚡ " + str(Session.event.get("kind", "事件")) + "  " + str(Session.event.get("stage", "warn")), Vector2(480, 90), Vector2(370, 38), 16, UiAssets.COLOR_RED); event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; active_page.add_child(event_label)

func _build_ghost() -> void:
	var title: Label = _label("抓到了！", Vector2(0, 80), Vector2(1334, 70), 54, UiAssets.COLOR_RED); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; active_page.add_child(title)
	var hint: Label = _label("选择你的幽灵阵营（10 秒内）", Vector2(0, 160), Vector2(1334, 35), 19, UiAssets.COLOR_TEXT); hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; active_page.add_child(hint)
	for i: int in 2:
		var b: Button = _button("守护灵\n\n制造假波纹" if i == 0 else "怨灵\n\n标记一名藏者", Vector2(300 + i * 390, 250), Vector2(330, 260), Color("415fb8") if i == 0 else Color("8a3c83")); b.add_theme_font_size_override("font_size", 24); b.pressed.connect(func() -> void: Net.send("game.ghostSide", {"side":"guardian" if i == 0 else "wraith"}); _leave_ghost_choice()); active_page.add_child(b)
	# The server defaults to guardian when the window lapses; follow it back into play.
	var ends_at: float = float(Session.me().get("ghostChoiceEndsAt", Net.now_ms() + 10000.0))
	get_tree().create_timer(maxf(0.5, (ends_at - Net.now_ms()) / 1000.0 + 0.3)).timeout.connect(_leave_ghost_choice)

func _leave_ghost_choice() -> void:
	if Router.current == 15:
		Router.go(14 if Session.role() == "hunter" else 13)

func _build_event() -> void:
	_build_hud(13)
	var banner: Panel = _panel(Vector2(360, 65), Vector2(614, 80)); active_page.add_child(banner); var label: Label = _label("⚡ 全楼停电   5s", Vector2(0, 17), Vector2(614, 50), 28, UiAssets.COLOR_RED); label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; banner.add_child(label)

func _build_result() -> void:
	var winner: String = str(Session.result.get("winner", "hider"))
	var title: Label = _label("猎手胜利" if winner == "hunter" else "藏者胜利", Vector2(0, 56), Vector2(1334, 70), 48, UiAssets.COLOR_GOLD); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; active_page.add_child(title)
	var players: Array = Session.result.get("players", [])
	for side: int in 2:
		var panel: Panel = _panel(Vector2(180 + side * 544, 170), Vector2(430, 365)); active_page.add_child(panel)
		var role: String = "hunter" if side == 1 else "hider"
		var lines: String = "猎手阵营" if side == 1 else "藏者阵营"
		lines += "\n\n"
		for player: Dictionary in players:
			if (str(player.get("role", "hider")) == "hunter") == (side == 1):
				lines += "%s  %d 分%s\n" % [str(player.get("nickname", "玩家")), int(player.get("score", 0)), " · 已抓" if player.get("caught", false) else ""]
				if player.get("id") == Session.user.get("id"):
					for entry: Dictionary in player.get("breakdown", []):
						lines += "  %s  %+d\n" % [str(entry.get("label", "")), int(entry.get("pts", 0))]
		var mvp: Dictionary = Session.result.get("mvp", {})
		# The server names the MVP by player id; show the nickname.
		var mvp_id: String = str(mvp.get(role, ""))
		var mvp_name: String = "—"
		for player: Dictionary in players:
			if str(player.get("id", "")) == mvp_id:
				mvp_name = str(player.get("nickname", "玩家"))
		lines += "\nMVP  " + mvp_name
		var label: Label = _label(lines, Vector2(28, 24), Vector2(375, 320), 15, UiAssets.COLOR_TEXT); label.clip_text = true; panel.add_child(label)
	var reward: Dictionary = Session.result.get("rewards", {})
	var reward_label: Label = _label("奖励  经验 +%d   金币 +%d   段位 %+d" % [int(reward.get("exp", 0)), int(reward.get("coins", 0)), int(reward.get("rankDelta", 0))], Vector2(410, 540), Vector2(515, 40), 18, UiAssets.COLOR_GOLD); reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; active_page.add_child(reward_label)
	var again: Button = _button("再来一局", Vector2(375, 615), Vector2(180, 60), UiAssets.COLOR_GOLD); again.pressed.connect(func() -> void: Net.send("room.again")); active_page.add_child(again)
	var back: Button = _button("返回主界面", Vector2(578, 615), Vector2(180, 60), Color("4b426d")); back.pressed.connect(func() -> void: Net.send("room.leave")); active_page.add_child(back)
	var share: Button = _button("分享战绩", Vector2(781, 615), Vector2(180, 60), Color("4b426d")); share.pressed.connect(func() -> void: DisplayServer.clipboard_set("《熄灯》%s！房间 %s" % ["猎手胜利" if winner == "hunter" else "藏者胜利", str(Session.room.get("code", ""))]); show_toast("战绩已复制")); active_page.add_child(share)

func _build_friends() -> void:
	_build_form_header("好友与邀请", 18)
	var panel: Panel = _panel(Vector2(170, 130), Vector2(1000, 500)); active_page.add_child(panel)
	var list: Label = _label("好友列表（4/50）\n\n🌸 小桃      ● 在线            邀请到房间\n\n🔵 阿青      ● 在线            邀请到房间\n\n🟣 小鹿      ◐ 游戏中         游戏中\n\n🟠 橘子      ○ 离线            离线", Vector2(35, 35), Vector2(930, 350), 19, UiAssets.COLOR_TEXT); panel.add_child(list)
	var add: Button = _button("添加好友", Vector2(765, 425), Vector2(170, 52), UiAssets.COLOR_GOLD); add.pressed.connect(func() -> void: show_toast("已打开添加好友")); panel.add_child(add)

func _build_settings() -> void:
	_build_form_header("设置", 19)
	var panel: Panel = _panel(Vector2(300, 105), Vector2(734, 580)); active_page.add_child(panel)
	var volume_label: Label = _label("音量", Vector2(40, 34), Vector2(210, 38), 19, UiAssets.COLOR_TEXT); panel.add_child(volume_label)
	var volume: HSlider = HSlider.new(); volume.position = Vector2(410, 38); volume.size = Vector2(250, 30); volume.min_value = 0; volume.max_value = 100; volume.value = float(Config.settings.volume) * 100; volume.value_changed.connect(func(value: float) -> void: Config.settings.volume = value / 100.0; Audio.apply_settings()); panel.add_child(volume)
	var names: Array[String] = ["静音视觉增强", "色弱模式", "震动反馈", "左手模式", "屏幕震动"]
	var keys: Array[String] = ["visual_audio", "colorblind", "vibration", "left_hand", "shake"]
	for i: int in names.size():
		var y: float = 99 + i * 67
		var label: Label = _label(names[i], Vector2(40, y), Vector2(300, 38), 19, UiAssets.COLOR_TEXT); panel.add_child(label)
		var toggle: CheckButton = CheckButton.new(); toggle.position = Vector2(500, y - 8); toggle.button_pressed = bool(Config.settings[keys[i]]); toggle.toggled.connect(func(value: bool) -> void: Config.settings[keys[i]] = value); panel.add_child(toggle)
	var quality_label: Label = _label("画质", Vector2(40, 440), Vector2(300, 38), 19, UiAssets.COLOR_TEXT); panel.add_child(quality_label)
	var quality: OptionButton = OptionButton.new(); quality.position = Vector2(470, 435); quality.size = Vector2(200, 48); quality.add_item("省电", 0); quality.add_item("标准", 1); quality.add_item("高", 2); quality.select(clampi(int(Config.settings.quality), 0, 2)); quality.item_selected.connect(func(index: int) -> void: Config.settings.quality = index); panel.add_child(quality)
	var out: Button = _button("退出登录", Vector2(40, 518), Vector2(185, 48), UiAssets.COLOR_RED); out.pressed.connect(func() -> void: Session.logout()); panel.add_child(out)
	var save: Button = _button("保存设置", Vector2(500, 518), Vector2(190, 48), UiAssets.COLOR_GOLD); save.pressed.connect(func() -> void: Config.save(); show_toast("设置已保存")); panel.add_child(save)
	var debug: Button = _button("v" + Config.VERSION, Vector2(8, 520), Vector2(68, 35), Color("2a2350")); debug.modulate.a = 0.35; debug.pressed.connect(_show_server_debug); active_page.add_child(debug)

func _show_server_debug() -> void:
	var edit: LineEdit = _edit("http://127.0.0.1:8787", Vector2(445, 660), Vector2(390, 48)); edit.text = Config.server_url; active_page.add_child(edit)
	var save: Button = _button("连接", Vector2(845, 660), Vector2(100, 48), UiAssets.COLOR_GOLD); save.pressed.connect(func() -> void:
		Config.server_url = edit.text.strip_edges().trim_suffix("/")
		Config.save()
		Net.disconnect_session()
		Net.connect_session()
		show_toast("服务器地址已保存")); active_page.add_child(save)

func _setting_changed(index: int, value: bool) -> void:
	var key: String = ["volume", "visual_audio", "colorblind", "vibration", "quality", "left_hand"][index]
	Config.settings[key] = value

func _build_form_header(title: String, back_page: int) -> void:
	var back: Button = _button("‹ 返回", Vector2(42, 38), Vector2(118, 50), Color("38345e")); back.pressed.connect(func() -> void: Router.go(2 if back_page in [3,4,5,9] else 6)); active_page.add_child(back)
	var label: Label = _label(title, Vector2(0, 28), Vector2(1334, 65), 35, UiAssets.COLOR_GOLD); label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; active_page.add_child(label)

func _panel(pos: Vector2, size: Vector2) -> Panel:
	var panel: Panel = Panel.new(); panel.position = pos; panel.size = size; panel.add_theme_stylebox_override("panel", UiAssets.nine_patch("panel/panel_content_large", UiAssets.panel(), 16)); return panel

func _button(text: String, pos: Vector2, size: Vector2, color: Color = UiAssets.COLOR_GOLD) -> Button:
	var b: Button = Button.new(); b.text = text; b.position = pos; b.size = size; b.add_theme_font_size_override("font_size", 17); b.add_theme_color_override("font_color", UiAssets.COLOR_TEXT); b.add_theme_stylebox_override("normal", UiAssets.nine_patch("button/button_primary_yellow", UiAssets.button(color), 12) if color == UiAssets.COLOR_GOLD else UiAssets.button(color)); b.add_theme_stylebox_override("hover", UiAssets.button(color.lightened(0.15))); b.add_theme_stylebox_override("pressed", UiAssets.nine_patch("button/button_primary_yellow_pressed", UiAssets.button(color.darkened(0.15)), 12) if color == UiAssets.COLOR_GOLD else UiAssets.button(color.darkened(0.15))); return b

func _label(text: String, pos: Vector2, size: Vector2, font_size: int, color: Color) -> Label:
	var l: Label = Label.new(); l.text = text; l.position = pos; l.size = size; l.add_theme_font_size_override("font_size", font_size); l.add_theme_color_override("font_color", color); return l

func _edit(placeholder: String, pos: Vector2, size: Vector2) -> LineEdit:
	var e: LineEdit = LineEdit.new(); e.placeholder_text = placeholder; e.position = pos; e.size = size; e.add_theme_font_size_override("font_size", 17); e.add_theme_stylebox_override("normal", UiAssets.button(Color("3e376a"))); return e

func show_toast(text: String) -> void:
	for child: Node in toast_layer.get_children(): child.queue_free()
	var label: Label = _label(text, Vector2(390, 650), Vector2(554, 46), 17, UiAssets.COLOR_TEXT); label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; label.add_theme_stylebox_override("normal", UiAssets.button(Color("55467d"))); toast_layer.add_child(label)
	# Bound to the label itself so the connection dies with it (no freed-lambda capture).
	get_tree().create_timer(2.5).timeout.connect(label.queue_free)

func _on_net_status(text: String) -> void:
	if not text.is_empty():
		show_toast(text)
		return
	# Connected: drop any lingering "connecting…" toast right away.
	for child: Node in toast_layer.get_children():
		if child is Label and "连接" in (child as Label).text:
			child.queue_free()

func _on_session_update(type: String) -> void:
	# In-match pages read Session live every frame; rebuilding them would reset the HUD.
	var in_match: bool = Router.current in [13, 14, 15, 16]
	if type in ["room.state", "game.phase", "match.status", "vote.update", "game.event"] and Router.current > 0 and not in_match:
		show_page(Router.current)
	if type == "game.caught" and str(Session.last_caught.get("victimId", "")) == str(Session.user.get("id", "")):
		Router.go(15)

func save_debug_shot(name: String) -> void:
	if screenshot_done: return
	var image: Image = get_viewport().get_texture().get_image()
	if image == null:
		push_error("Screenshot viewport is unavailable")
		return
	screenshot_done = true
	var path: String = "res://docs/screenshots/" + name + ".png"
	var error: Error = image.save_png(path)
	print("SHOT ", path, " result=", error)
	get_tree().quit(0 if error == OK else 1)

func prepare_debug_shot(name: String) -> void:
	var page: int = int(name)
	Session.user = {"id":"demo", "nickname":"小夜猫", "level":8, "color":"blue", "coins":1280, "gems":60}
	if page == 10:
		var players: Array[Dictionary] = []
		for i: int in 6:
			players.append({"id":"demo" if i == 0 else "bot_%d" % i, "nickname":"小夜猫" if i == 0 else "AI-%d" % i, "color":"blue", "ready":i != 0, "isHost":i == 0, "isBot":i != 0})
		Session.room = {"code":"483921", "hostId":"demo", "players":players, "phase":"waiting"}
	if page in [13, 14]:
		var bytes: PackedByteArray = PackedByteArray()
		bytes.resize(64 * 40)
		for y: int in 40:
			for x: int in 64:
				if x == 0 or x == 63 or y == 0 or y == 39 or (x == 27 and y > 8 and y < 33 and y != 19): bytes[y * 64 + x] = 1
		Session.game = {"you":{"id":"demo", "role":"hunter" if page == 14 else "hider"}, "players":[{"id":"demo", "color":"blue", "nickname":"小夜猫"}], "map":{"w":64,"h":40,"tiles":Marshalls.raw_to_base64(bytes),"hunterSpawn":{"x":32,"y":20},"hiderSpawns":[{"x":32,"y":20}],"props":[{"x":35,"y":20,"prop":"cardboard_box"}],"generators":[{"id":0,"x":36,"y":22}]}}
		Session.snap = {"you":{"x":32.0,"y":20.0,"state":"normal","visionRadius":5.0,"stamina":3.0,"items":["smoke","banana"],"flashlight":true},"players":[],"alive":7,"totalHiders":9,"generators":[{"id":0,"x":36,"y":22,"progress":0.4,"fixed":false}]}
		Session.phase = "hunt"
		Session.phase_ends = Net.now_ms() + 402000.0
	if page == 17:
		Session.result = {"winner":"hider","players":[{"id":"demo","nickname":"小夜猫","role":"hider","score":200,"caught":false,"breakdown":[{"label":"存活","pts":100},{"label":"发电机","pts":40},{"label":"救援","pts":60}]},{"id":"hunter","nickname":"夜巡者","role":"hunter","score":70,"caught":false}],"mvp":{"hider":"小夜猫","hunter":"夜巡者"},"rewards":{"exp":80,"coins":120,"rankDelta":16}}
	show_page(page)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.8).timeout
	save_debug_shot(name)

# Player portrait from 06-头像: hider colour for people, robot for AI, silhouette for an
# empty seat. Returns an empty control when the art is missing so layouts stay intact.
func _avatar(p: Dictionary, pos: Vector2, size: float) -> Control:
	var name: String = "avatar-empty-slot"
	if not p.is_empty():
		name = "avatar-ai-bot" if p.get("isBot", false) else "avatar-hider-" + str(p.get("color", "blue"))
	var rect: TextureRect = TextureRect.new()
	rect.texture = UiAssets.asset("avatar/" + name)
	# expand_mode must precede size, or the size is clamped up to the texture's native size.
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.position = pos
	rect.size = Vector2(size, size)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect