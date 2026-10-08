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
var confirm_edit: LineEdit
var consent_box: CheckBox
var countdown: float = 0.0
var screenshot_done: bool = false
var register_mode: bool = false
var game_world: GameWorld
var page_layer: CanvasLayer
# Room-creation choices (page 08), sent with room.create.
var room_settings: Dictionary = {"map":"old_dorm", "durationSec":600, "hunterCount":"auto", "moleEnabled":false, "voiceEnabled":false, "aiFill":true, "maxPlayers":12}
# Six-digit room code typed on page 09 and the labels that show it.
var join_code: String = ""
var code_cells: Array[Label] = []
# Index of the map card this player voted for on page 11.
var my_vote: int = -1
# Announcement fetched at startup; shown as a modal on the splash / login page.
var notice: Dictionary = {}
# Economy pages (20-23): server data cached per visit; cleared when leaving the lobby flow.
var shop_cache: Dictionary = {}
var records_cache: Dictionary = {}
var tasks_cache: Dictionary = {}
var shop_slot: String = "hat"
# Scene art per page (素材 01-背景); pages without art keep the plain dark colour.
const PAGE_BACKGROUNDS: Dictionary = {1: "bg-splash-dorm-night", 2: "bg-login-dorm-gate", 3: "bg-login-dorm-gate", 4: "bg-login-dorm-gate", 5: "bg-lobby-dorm-hall", 6: "bg-lobby-dorm-hall", 7: "bg-matching-corridor", 8: "bg-room-waiting-hall", 9: "bg-room-waiting-hall", 10: "bg-room-waiting-hall", 11: "bg-map-vote-blueprint", 12: "bg-role-reveal-dark", 17: "bg-result-dawn", 18: "bg-menu-dim", 19: "bg-menu-dim", 20: "bg-lobby-dorm-hall", 21: "bg-menu-dim", 22: "bg-menu-dim", 23: "bg-menu-dim"}
# Form-heavy pages get a dark veil over the scene so text stays readable.
const DIMMED_PAGES: Array[int] = [3, 4, 8, 9, 10, 18, 19, 21, 22, 23]
const MAP_INFO: Dictionary = {"old_dorm": {"name":"旧宿舍楼", "card":"map-old-dorm", "desc":"中心辐射 · 8～12 人", "feature":"基准图：无专属机制，适合新手"},
	"night_hospital": {"name":"深夜医院", "card":"map-night-hospital", "desc":"两翼长走廊 · 8～10 人", "feature":"电梯 3 秒穿越两翼；跑过心电监护仪会响；X 光室会暴露进入者"},
	"night_mall": {"name":"夜间商场", "card":"map-night-mall", "desc":"双层天井 · 10～12 人", "feature":"扶梯和楼梯换层；试衣间帘子挡视线；广播室可放一次假警报"},
	"midnight_cruise": {"name":"午夜游轮", "card":"map-midnight-cruise", "desc":"甲板 + 船舱 · 8～12 人", "feature":"甲板月光看得远；每 90 秒船身倾斜，伪装者不会滑动"},
	"snow_lodge": {"name":"雪山山庄", "card":"map-snow-lodge", "desc":"木屋 + 雪地 · 10～12 人", "feature":"雪地脚印留 15 秒；暴风雪遮挡视线；室外太久会冻得变慢"},
	"random": {"name":"随机地图", "card":"map-old-dorm", "desc":"投票时三张图随机出现", "feature":"每局由投票决定去哪张图"}}
const MAP_ORDER: Array[String] = ["old_dorm", "night_hospital", "night_mall", "midnight_cruise", "snow_lodge", "random"]
const ROLE_INFO: Dictionary = {"hider": {"name":"藏者", "goal":"存活到最后！", "desc":"利用伪装躲开猎手，\n修好发电机缩短倒计时", "art":"role/role-hider", "color":Color("7fb2ff")}, "hunter": {"name":"猎手", "goal":"抓住所有藏者！", "desc":"打开手电追踪脚印与波纹，\n拍打可疑的物件", "art":"role/role-hunter", "color":Color("e5383b")}, "mole": {"name":"卧底", "goal":"暗中帮助猎手！", "desc":"混在藏者中报点，\n别被识破身份", "art":"role/role-mole", "color":Color("b98cff")}}
# Type scale at the 1334x750 base resolution.
const FS_TITLE: int = 40
const FS_BUTTON: int = 24
const FS_BODY: int = 20
const FS_SMALL: int = 16

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
		notice = response.notices[0]
		if Router.current in [1, 2]:
			_show_notice()
	if not Session.token.is_empty():
		Net.connect_session()
		await refresh_me()

## Stretch a full-page background past the 1334x750 design canvas to the real screen edges.
func _bleed(node: Control) -> void:
	var view: Vector2 = get_viewport_rect().size
	var k: float = maxf(canvas.scale.x, 0.001)
	node.set_anchors_preset(Control.PRESET_TOP_LEFT)
	node.position = -canvas.position / k
	node.size = view / k

func _fit_canvas() -> void:
	if not is_instance_valid(canvas): return
	var viewport_size: Vector2 = get_viewport_rect().size
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var margin: float = 22.0 if safe.size.x <= 0 else clampf(float(safe.position.x), 16.0, 72.0)
	var usable: Vector2 = viewport_size - Vector2(margin * 2.0, 16.0)
	var scale_factor: float = minf(usable.x / 1334.0, usable.y / 750.0)
	canvas.scale = Vector2.ONE * scale_factor
	canvas.position = (viewport_size - Vector2(1334, 750) * scale_factor) * 0.5
	if is_instance_valid(active_page):
		for child: Node in active_page.get_children():
			if child is ColorRect or (child is TextureRect and (child as TextureRect).stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED):
				_bleed(child)

func _process(delta: float) -> void:
	if Router.current == 15 and is_instance_valid(active_page):
		var hint: Label = active_page.find_child("GhostHint", true, false) as Label
		if hint:
			var left: int = maxi(0, ceili((float(Session.me().get("ghostChoiceEndsAt", 0)) - Net.now_ms()) / 1000.0))
			hint.text = "出局不下线 · 选择你的幽灵阵营（%d 秒）" % (left if left > 0 and left <= 10 else 10)
	if countdown > 0:
		countdown -= delta
		if is_instance_valid(active_page):
			var send_button: Button = active_page.find_child("SendCode", true, false) as Button
			if send_button:
				send_button.text = "%ds 后重发" % ceili(countdown) if countdown > 0.05 else "获取验证码"
				send_button.disabled = countdown > 0.05
			var timer: Label = active_page.find_child("Timer", true, false) as Label
			if timer:
				timer.text = "%ds" % ceili(countdown)

func _unhandled_input(event: InputEvent) -> void:
	# Physical keyboard for the room-code keypad (page 09).
	if Router.current != 9 or not (event is InputEventKey) or not event.pressed:
		return
	var key: InputEventKey = event
	if key.keycode >= KEY_0 and key.keycode <= KEY_9:
		_keypad_press(str(key.keycode - KEY_0))
	elif key.keycode >= KEY_KP_0 and key.keycode <= KEY_KP_9:
		_keypad_press(str(key.keycode - KEY_KP_0))
	elif key.keycode == KEY_BACKSPACE:
		_keypad_press("删除")
	elif key.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		_join_room()

func show_page(page: int) -> void:
	if not is_instance_valid(canvas):
		return
	if page == 6:
		shop_cache = {}
		records_cache = {}
		tasks_cache = {}
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
	_bleed(bg)
	var bg_tex: Texture2D = UiAssets.asset("bg/" + str(PAGE_BACKGROUNDS.get(page, "")))
	if bg_tex:
		var backdrop: TextureRect = TextureRect.new()
		backdrop.texture = bg_tex
		backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		backdrop.size = Vector2(1334, 750)
		backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		active_page.add_child(backdrop)
		_bleed(backdrop)
		if page in DIMMED_PAGES:
			var dim: ColorRect = ColorRect.new()
			dim.color = Color(0.03, 0.02, 0.08, 0.45)
			dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
			active_page.add_child(dim)
			_bleed(dim)
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
		15: _build_ghost()
		17: _build_result()
		18: _build_friends()
		19: _build_settings()
		20: _build_wardrobe()
		21: _build_shop()
		22: _build_records()
		23: _build_tasks()

# ---------------------------------------------------------------- 01 启动闪屏

func _build_splash() -> void:
	var logo: TextureRect = UiAssets.picture("logo/game_logo_title", Vector2(40, 36), Vector2(560, 270))
	if logo.texture: active_page.add_child(logo)
	else: _add(_title_label("熄灯", Vector2(60, 90), Vector2(460, 120), 96, UiAssets.COLOR_GOLD))
	_add(_label("当灯光熄灭，另一场游戏开始。", Vector2(70, 300), Vector2(520, 40), 24, UiAssets.COLOR_TEXT))
	_add(_progress(Vector2(417, 600), Vector2(500, 26), 0.68))
	_add(_label("正在更新资源… 68%", Vector2(0, 634), Vector2(1334, 30), FS_SMALL, UiAssets.COLOR_MUTED, true))
	_add(_label("v" + Config.VERSION, Vector2(1200, 700), Vector2(110, 26), 14, UiAssets.COLOR_MUTED))
	if not notice.is_empty():
		_show_notice()
	else:
		get_tree().create_timer(1.6).timeout.connect(_leave_splash)

func _leave_splash() -> void:
	if Router.current == 1 and Session.token.is_empty(): Router.go(2)

func _show_notice() -> void:
	if notice.is_empty() or not is_instance_valid(active_page) or active_page.find_child("Notice", true, false):
		return
	var modal: Panel = _panel(Vector2(860, 110) if Router.current == 1 else Vector2(417, 170), Vector2(420, 330), "panel/panel_modal")
	modal.name = "Notice"
	_add(modal)
	modal.add_child(UiAssets.picture("icon/notice-icon", Vector2(84, 34), Vector2(38, 38)))
	modal.add_child(_title_label(str(notice.get("title", "公告")), Vector2(0, 28), Vector2(420, 50), 30, UiAssets.COLOR_GOLD, true))
	var close: Button = _icon_button("icon/close-icon", Vector2(356, 18), Vector2(48, 48), Color("38345e"))
	close.pressed.connect(func() -> void:
		notice = {}
		modal.queue_free()
		_leave_splash())
	modal.add_child(close)
	var body: Label = _label(str(notice.get("body", "")), Vector2(40, 100), Vector2(340, 120), FS_BODY, UiAssets.COLOR_TEXT, true)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal.add_child(body)
	var ok: Button = _button("我知道了", Vector2(90, 240), Vector2(240, 64))
	ok.pressed.connect(func() -> void:
		notice = {}
		modal.queue_free()
		_leave_splash())
	modal.add_child(ok)

# ---------------------------------------------------------------- 02 登录

func _build_login() -> void:
	var logo: TextureRect = UiAssets.picture("logo/game_logo_title", Vector2(40, 40), Vector2(520, 250))
	if logo.texture: active_page.add_child(logo)
	else: _add(_title_label("熄灯", Vector2(60, 70), Vector2(400, 120), 96, UiAssets.COLOR_GOLD))
	_add(_label("当灯光熄灭，另一场游戏开始", Vector2(70, 290), Vector2(460, 34), 22, UiAssets.COLOR_TEXT))
	_add(_sprite_figure(str(Session.user.get("color", "blue")), Vector2(90, 420), 230))
	var age: Panel = _panel(Vector2(28, 626), Vector2(96, 96), "panel/panel_room_code_cell")
	_add(age)
	age.add_child(_label("适龄提示", Vector2(0, 12), Vector2(96, 22), 13, UiAssets.COLOR_TEXT, true))
	age.add_child(_title_label("12+", Vector2(0, 36), Vector2(96, 44), 32, Color("7fd3ff"), true))

	var panel: Panel = _panel(Vector2(700, 150), Vector2(590, 510))
	_add(panel)
	panel.add_child(_title_label("登录熄灯", Vector2(0, 26), Vector2(590, 52), 36, UiAssets.COLOR_GOLD, true))
	var wechat: Button = _button("微信快捷登录", Vector2(50, 100), Vector2(490, 96), UiAssets.COLOR_GREEN, 30)
	var wechat_art: String = "button/button_wechat_green"
	if UiAssets.asset(wechat_art):
		# The WeChat art carries its own logo on the left: push the label past it.
		for state: String in ["normal", "hover", "pressed"]:
			wechat.add_theme_stylebox_override(state, UiAssets.tex_style(wechat_art if state != "pressed" else "button/button_wechat_green_pressed", UiAssets.button(UiAssets.COLOR_GREEN), Vector2(90, 20), Vector2(20, 6), Color(1.12, 1.12, 1.12) if state == "hover" else Color.WHITE))
		wechat.add_theme_constant_override("h_separation", 0)
		wechat.alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		wechat.icon = UiAssets.asset("icon/wechat-icon")
	wechat.pressed.connect(_wechat_login)
	panel.add_child(wechat)
	if not WeChat.native_available() and OS.is_debug_build():
		panel.add_child(_label("开发模式 · 微信 Mock", Vector2(0, 198), Vector2(590, 22), 14, Color("6fe39b"), true))
	var phone: Button = _button("手机号登录", Vector2(50, 232), Vector2(238, 72), Color("3959b8"), FS_BUTTON, "icon/phone-icon")
	phone.pressed.connect(func() -> void: if _consented(): Router.go(3))
	panel.add_child(phone)
	var account: Button = _button("账号密码登录", Vector2(302, 232), Vector2(238, 72), Color("7047b9"), FS_BUTTON, "icon/lock-icon")
	account.pressed.connect(func() -> void: if _consented(): Router.go(4))
	panel.add_child(account)
	var guest: Button = _button("游客体验", Vector2(150, 322), Vector2(290, 56), Color("38345e"), 20, "icon/user-icon")
	guest.pressed.connect(_guest_login)
	panel.add_child(guest)
	consent_box = CheckBox.new()
	consent_box.text = "我已阅读并同意"
	for i: int in 2:
		var link: Button = _link_button(["《用户协议》", "《隐私政策》"][i], Vector2(268 + i * 130, 410), Vector2(126, 44))
		link.add_theme_font_size_override("font_size", 17)
		link.add_theme_color_override("font_color", Color("8fc4ff"))
		link.pressed.connect(func() -> void: _show_agreement(i))
		panel.add_child(link)
	consent_box.position = Vector2(50, 410)
	consent_box.size = Vector2(490, 44)
	consent_box.button_pressed = Session.consent
	consent_box.add_theme_font_size_override("font_size", 17)
	var on: Texture2D = _scaled_icon("button/checkbox_on", 30)
	var off: Texture2D = _scaled_icon("button/checkbox_off", 30)
	if on and off:
		consent_box.add_theme_icon_override("checked", on)
		consent_box.add_theme_icon_override("unchecked", off)
	consent_box.toggled.connect(func(value: bool) -> void: Session.consent = value)
	panel.add_child(consent_box)
	if not notice.is_empty():
		_show_notice()

func _show_agreement(which: int) -> void:
	var veil: ColorRect = ColorRect.new()
	veil.color = Color(0.02, 0.01, 0.06, 0.72)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_add(veil)
	var panel: Panel = _panel(Vector2(267, 80), Vector2(800, 590), "panel/panel_modal")
	veil.add_child(panel)
	panel.add_child(_title_label(["用户协议", "隐私政策"][which], Vector2(0, 24), Vector2(800, 50), 32, UiAssets.COLOR_GOLD, true))
	var text: Label = _label(["欢迎来到《熄灯》。使用本游戏即表示你同意：遵守游戏规则与社区公约，不使用外挂、不恶意中途退出、不在语音中发表违法或骚扰内容；账号仅限本人使用；虚拟道具（金币、钻石、装扮）仅在游戏内使用，不可兑换现金。\n\n我们可能因违规行为限制账号功能。正式上线前本协议将由运营方发布完整版本。",
		"我们只收集提供服务所必需的信息：账号标识（微信 OpenID / 手机号 / 账号名）、昵称与对局数据。手机号仅用于登录与找回密码，展示时会脱敏；近距离语音只做实时转发，服务器不录音、不存储。\n\n你可以在设置中解绑或注销账号。正式上线前本政策将由运营方发布完整版本。"][which], Vector2(50, 96), Vector2(700, 380), FS_BODY, UiAssets.COLOR_TEXT)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	panel.add_child(text)
	var ok: Button = _button("我知道了", Vector2(280, 500), Vector2(240, 64), UiAssets.COLOR_GOLD, 24)
	ok.pressed.connect(veil.queue_free)
	panel.add_child(ok)

func _consented() -> bool:
	if Session.consent: return true
	show_toast("请先阅读并同意用户协议")
	if is_instance_valid(consent_box):
		var x: float = consent_box.position.x
		var tween: Tween = create_tween(); tween.tween_property(consent_box, "position:x", x + 8.0, 0.04); tween.tween_property(consent_box, "position:x", x - 8.0, 0.04); tween.tween_property(consent_box, "position:x", x, 0.04)
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

# ---------------------------------------------------------------- 03 手机验证码登录

func _build_sms() -> void:
	_header("手机号登录", 2)
	var panel: Panel = _panel(Vector2(357, 130), Vector2(620, 500))
	_add(panel)
	panel.add_child(_title_label("熄灯", Vector2(0, 26), Vector2(620, 60), 44, UiAssets.COLOR_GOLD, true))
	panel.add_child(_label("一条验证码，送你回宿舍", Vector2(0, 90), Vector2(620, 28), FS_SMALL, UiAssets.COLOR_MUTED, true))
	panel.add_child(_field_icon("icon/phone-icon", Vector2(50, 152)))
	panel.add_child(_label("手机号", Vector2(96, 146), Vector2(90, 70), FS_BODY, UiAssets.COLOR_TEXT))
	phone_edit = _edit("请输入手机号", Vector2(190, 146), Vector2(380, 70))
	phone_edit.add_theme_constant_override("minimum_character_width", 0)
	var prefix: Label = _label("+86", Vector2(22, 0), Vector2(46, 70), 18, UiAssets.COLOR_GOLD)
	phone_edit.add_child(prefix)
	(phone_edit.get_theme_stylebox("normal") as StyleBox).content_margin_left = 70
	(phone_edit.get_theme_stylebox("focus") as StyleBox).content_margin_left = 70
	phone_edit.max_length = 11
	panel.add_child(phone_edit)
	panel.add_child(_field_icon("icon/lock-icon", Vector2(50, 242)))
	panel.add_child(_label("验证码", Vector2(96, 236), Vector2(90, 70), FS_BODY, UiAssets.COLOR_TEXT))
	code_edit = _edit("6 位数字", Vector2(190, 236), Vector2(180, 70))
	code_edit.max_length = 6
	panel.add_child(code_edit)
	var send: Button = _button("获取验证码", Vector2(384, 236), Vector2(186, 70), UiAssets.COLOR_GOLD, 22)
	send.name = "SendCode"
	send.pressed.connect(_send_sms)
	panel.add_child(send)
	var countdown_label: Label = _label("", Vector2(384, 310), Vector2(186, 26), 15, UiAssets.COLOR_MUTED, true)
	countdown_label.name = "Countdown"
	panel.add_child(countdown_label)
	var login: Button = _button("登录", Vector2(50, 360), Vector2(520, 84), UiAssets.COLOR_GOLD, 32)
	login.pressed.connect(_sms_login)
	panel.add_child(login)
	if OS.is_debug_build():
		panel.add_child(_label("未配置短信服务时，验证码会以开发提示显示", Vector2(0, 452), Vector2(620, 26), 14, UiAssets.COLOR_MUTED, true))

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

# ---------------------------------------------------------------- 04 账号密码登录

func _build_account() -> void:
	_header("账号密码登录", 2)
	var panel: Panel = _panel(Vector2(357, 110), Vector2(620, 590))
	_add(panel)
	panel.add_child(_title_label("熄灯", Vector2(0, 22), Vector2(620, 56), 40, UiAssets.COLOR_GOLD, true))
	var tabs: HBoxContainer = _tabs(["登录", "注册"], 1 if register_mode else 0, Vector2(60, 90), Vector2(500, 60), func(index: int) -> void:
		register_mode = index == 1
		show_page(4))
	panel.add_child(tabs)
	panel.add_child(_field_icon("icon/user-icon", Vector2(60, 180)))
	account_edit = _edit("请输入账号（4–20 位字母数字）", Vector2(110, 172), Vector2(450, 68))
	panel.add_child(account_edit)
	panel.add_child(_field_icon("icon/lock-icon", Vector2(60, 262)))
	password_edit = _edit("请输入密码", Vector2(110, 254), Vector2(450, 68))
	password_edit.secret = true
	panel.add_child(password_edit)
	var reveal: Button = _icon_button("icon/eye-open-icon", Vector2(500, 264), Vector2(50, 48))
	reveal.pressed.connect(func() -> void:
		password_edit.secret = not password_edit.secret
		if is_instance_valid(confirm_edit): confirm_edit.secret = password_edit.secret)
	panel.add_child(reveal)
	var y: float = 340.0
	if register_mode:
		panel.add_child(_field_icon("icon/lock-icon", Vector2(60, y + 8)))
		confirm_edit = _edit("再次输入密码", Vector2(110, y), Vector2(450, 68))
		confirm_edit.secret = true
		panel.add_child(confirm_edit)
		y += 82.0
	else:
		var forgot: Button = _link_button("忘记密码？", Vector2(430, y), Vector2(130, 32))
		forgot.pressed.connect(_forgot_password)
		panel.add_child(forgot)
		y += 44.0
	var submit: Button = _button("注册" if register_mode else "登录", Vector2(60, y + 20), Vector2(500, 84), UiAssets.COLOR_GOLD, 32)
	submit.pressed.connect(_account_login)
	panel.add_child(submit)
	if register_mode:
		panel.add_child(_label("注册后即可登录", Vector2(0, y + 110), Vector2(620, 24), 14, UiAssets.COLOR_MUTED, true))

func _account_login() -> void:
	if not _consented(): return
	if register_mode and is_instance_valid(confirm_edit) and confirm_edit.text != password_edit.text:
		show_toast("两次输入的密码不一致")
		return
	var response: Dictionary = await Api.login("register" if register_mode else "password", {"account": account_edit.text, "password": password_edit.text})
	if response.get("ok", false): _after_login(response)
	else: show_toast(str(response.get("msg", "登录失败")))

# ---------------------------------------------------------------- 05 创建角色

func _random_name() -> void:
	var response: Dictionary = await Api.get_json("/profile/random-name")
	if response.get("ok", false) and is_instance_valid(nickname_edit):
		nickname_edit.text = str(response.get("nickname", "小夜猫"))

func _build_profile() -> void:
	_header("创建角色", 2)
	var color: String = str(Session.user.get("color", "blue"))
	_add(_floor_glow(Vector2(302, 482), Vector2(420, 100)))
	_add(_sprite_figure(color, Vector2(160, 170), 380))
	var panel: Panel = _panel(Vector2(640, 110), Vector2(650, 590))
	_add(panel)
	panel.add_child(_label("昵称", Vector2(56, 30), Vector2(200, 32), 22, UiAssets.COLOR_GOLD))
	var keep: String = nickname_edit.text if is_instance_valid(nickname_edit) else str(Session.user.get("nickname", "小夜猫"))
	nickname_edit = _edit("输入 2–12 字昵称", Vector2(44, 72), Vector2(470, 70))
	nickname_edit.text = keep
	nickname_edit.max_length = 12
	panel.add_child(nickname_edit)
	var dice: Button = _icon_button("icon/dice-icon", Vector2(528, 72), Vector2(78, 70), Color("4d4385"))
	dice.pressed.connect(_random_name)
	panel.add_child(dice)
	panel.add_child(_label("选择形象", Vector2(44, 166), Vector2(200, 32), 22, UiAssets.COLOR_GOLD))
	for i: int in 8:
		var key: String = UiAssets.HIDER_COLORS[i]
		var selected: bool = key == color
		var cell: Button = _card_button(Vector2(44 + (i % 4) * 142, 210 + (i / 4) * 142), Vector2(128, 128), selected)
		cell.add_child(_avatar({"color": key}, Vector2(10, 10), 108))
		if selected:
			cell.add_child(UiAssets.picture("icon/check-icon", Vector2(92, 4), Vector2(32, 32)))
		cell.pressed.connect(func() -> void:
			Session.user["color"] = key
			show_page(5))
		panel.add_child(cell)
	var enter: Button = _button("进入游戏  ▶", Vector2(44, 500), Vector2(562, 76), UiAssets.COLOR_GOLD, 30)
	enter.pressed.connect(_create_profile)
	panel.add_child(enter)

func _create_profile() -> void:
	var response: Dictionary = await Api.request("/profile", {"nickname": nickname_edit.text, "color": str(Session.user.get("color", "blue"))})
	if response.get("ok", false): Session.user = response.user; Router.go(6)
	else: show_toast(str(response.get("msg", "创建失败")))

# ---------------------------------------------------------------- 06 主界面

func _build_lobby() -> void:
	var user: Dictionary = Session.user
	# Top-left player card: avatar, nickname, level and experience bar.
	var card: Panel = _panel(Vector2(24, 20), Vector2(330, 96), "panel/panel_top_resource_bar")
	_add(card)
	card.add_child(_avatar(user, Vector2(12, 10), 76))
	card.add_child(_label(str(user.get("nickname", "游客")), Vector2(98, 12), Vector2(220, 32), 22, UiAssets.COLOR_TEXT))
	card.add_child(_label("Lv.%d" % int(user.get("level", 1)), Vector2(98, 46), Vector2(70, 24), FS_SMALL, UiAssets.COLOR_GOLD))
	card.add_child(_progress(Vector2(160, 48), Vector2(150, 22), float(int(user.get("exp", 0)) % 100) / 100.0))
	# Top-centre currencies, top-right settings.
	for i: int in 2:
		var chip: Control = _resource_chip(["icon/coin-icon", "icon/gem-icon"][i], str(int(user.get(["coins", "gems"][i], 0))), Vector2(470 + i * 230, 30), Vector2(210, 60))
		chip.add_child(UiAssets.picture("icon/plus-icon", Vector2(168, 16), Vector2(28, 28)))
		_add(chip)
	var setting: Button = _icon_button("icon/settings-icon", Vector2(1216, 24), Vector2(84, 84), Color("2c2552"))
	setting.pressed.connect(func() -> void: Router.go(19))
	_add(setting)
	# Centre: the player's own hider on the dorm floor.
	_add(_floor_glow(Vector2(590, 502), Vector2(460, 110)))
	_add(_sprite_figure(str(user.get("color", "blue")), Vector2(440, 170), 400))
	# Right: primary actions, largest first.
	var quick: Button = _button("快速匹配  ▶", Vector2(920, 190), Vector2(380, 120), UiAssets.COLOR_GOLD, 40)
	quick.pressed.connect(_match_start)
	_add(quick)
	var create: Button = _button("创建房间", Vector2(920, 326), Vector2(380, 84), Color("3959b8"), 28, "icon/plus-icon")
	create.pressed.connect(func() -> void: Router.go(8))
	_add(create)
	var join: Button = _button("加入房间", Vector2(920, 424), Vector2(380, 84), Color("7047b9"), 28, "icon/friends-icon")
	join.pressed.connect(func() -> void: Router.go(9))
	_add(join)
	# Bottom navigation.
	var nav: Panel = _panel(Vector2(100, 632), Vector2(800, 100), "panel/panel_bottom_nav")
	_add(nav)
	var items: Array = [["好友", "icon/friends-icon"], ["衣柜", "icon/wardrobe-icon"], ["商店", "icon/shop-icon"], ["战绩", "icon/trophy-icon"], ["任务", "icon/task-icon"]]
	for i: int in items.size():
		var b: Button = _nav_button(str(items[i][0]), str(items[i][1]), Vector2(30 + i * 150, 8), Vector2(140, 84))
		b.pressed.connect(func() -> void:
			Router.go([18, 20, 21, 22, 23][i]))
		nav.add_child(b)

func _match_start() -> void:
	Net.send("match.start"); Router.go(7)

# ---------------------------------------------------------------- 07 快速匹配中

func _build_match() -> void:
	var panel: Panel = _panel(Vector2(307, 60), Vector2(720, 630))
	_add(panel)
	panel.add_child(_title_label("快速匹配中", Vector2(0, 28), Vector2(720, 56), 40, UiAssets.COLOR_GOLD, true))
	var elapsed: int = int(Session.match_status.get("elapsedSec", 0))
	panel.add_child(_title_label("%02d:%02d" % [elapsed / 60, elapsed % 60], Vector2(0, 88), Vector2(720, 70), 64, UiAssets.COLOR_TEXT, true))
	var found: int = int(Session.match_status.get("found", 1))
	var needed: int = int(Session.match_status.get("needed", 8))
	panel.add_child(_label("已找到 %d / %d" % [found, needed], Vector2(0, 166), Vector2(720, 30), 22, UiAssets.COLOR_GOLD, true))
	for i: int in 12:
		var slot: Panel = _panel(Vector2(60 + (i % 6) * 102, 216 + (i / 6) * 112), Vector2(94, 100), "panel/panel_room_code_cell")
		if i < found:
			var p: Dictionary = {"color": UiAssets.HIDER_COLORS[(i + 5) % 8]}
			if i == 0: p = Session.user
			slot.add_child(_avatar(p, Vector2(9, 12), 76))
		else:
			slot.add_child(_title_label("?", Vector2(0, 22), Vector2(94, 56), 40, UiAssets.COLOR_MUTED, true))
		panel.add_child(slot)
	var can_fill: bool = bool(Session.match_status.get("canAiFill", false))
	panel.add_child(_label("匹配超过 60 秒可由 AI 补位开局" if not can_fill else "已等待超过 60 秒，可以 AI 补位开局", Vector2(0, 450), Vector2(720, 26), FS_SMALL, UiAssets.COLOR_MUTED, true))
	var cancel: Button = _button("取消匹配", Vector2(90, 500), Vector2(250, 80), Color("38345e"), 26)
	cancel.pressed.connect(func() -> void: Net.send("match.cancel"); Router.go(6))
	panel.add_child(cancel)
	var ai: Button = _button("AI 补位开局", Vector2(380, 500), Vector2(250, 80), UiAssets.COLOR_GOLD, 26)
	ai.pressed.connect(func() -> void: Net.send("match.aiFill"))
	ai.disabled = not can_fill
	panel.add_child(ai)

# ---------------------------------------------------------------- 08 创建房间

func _build_create_room() -> void:
	_header("创建房间", 6)
	var map_panel: Panel = _panel(Vector2(90, 120), Vector2(420, 540))
	_add(map_panel)
	_section_title(map_panel, "选择地图", "icon/map-icon")
	var map_index: int = maxi(0, MAP_ORDER.find(str(room_settings.map)))
	var info: Dictionary = MAP_INFO[MAP_ORDER[map_index]]
	var frame: Panel = _panel(Vector2(64, 80), Vector2(292, 190), "button/card_map_frame")
	map_panel.add_child(frame)
	var card: TextureRect = UiAssets.picture("mapcard/" + str(info.card), Vector2(10, 10), Vector2(272, 170))
	if MAP_ORDER[map_index] == "random":
		card.modulate = Color(0.35, 0.35, 0.45)
		frame.add_child(card)
		frame.add_child(_title_label("?", Vector2(0, 30), Vector2(292, 120), 96, UiAssets.COLOR_GOLD, true))
	else:
		frame.add_child(card)
	# Arrows cycle through the five maps and "random".
	for side: int in 2:
		var arrow: Button = _button("◀" if side == 0 else "▶", Vector2(8 if side == 0 else 364, 150), Vector2(48, 64), Color("38345e"), 26)
		arrow.pressed.connect(func() -> void:
			room_settings.map = MAP_ORDER[posmod(map_index + (-1 if side == 0 else 1), MAP_ORDER.size())]
			show_page(8))
		map_panel.add_child(arrow)
	map_panel.add_child(_title_label(str(info.name), Vector2(0, 284), Vector2(420, 44), 32, UiAssets.COLOR_TEXT, true))
	map_panel.add_child(_label(str(info.desc), Vector2(0, 330), Vector2(420, 28), FS_BODY, UiAssets.COLOR_MUTED, true))
	var feature: Label = _label(str(info.feature), Vector2(36, 366), Vector2(348, 90), FS_SMALL, UiAssets.COLOR_TEXT, true)
	feature.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_panel.add_child(feature)
	for i: int in MAP_ORDER.size():
		var dot: Panel = Panel.new()
		dot.position = Vector2(210 - MAP_ORDER.size() * 10 + i * 20, 470)
		dot.size = Vector2(10, 10)
		var dot_style: StyleBoxFlat = StyleBoxFlat.new()
		dot_style.bg_color = UiAssets.COLOR_GOLD if i == map_index else Color("4a4470")
		dot_style.set_corner_radius_all(5)
		dot.add_theme_stylebox_override("panel", dot_style)
		map_panel.add_child(dot)

	var panel: Panel = _panel(Vector2(530, 120), Vector2(714, 540))
	_add(panel)
	_section_title(panel, "房间设置", "icon/settings-icon")
	var durations: Array = [300, 480, 600]
	panel.add_child(_label("对局时长", Vector2(40, 90), Vector2(170, 52), FS_BODY, UiAssets.COLOR_TEXT))
	panel.add_child(_tabs(["5 分钟", "8 分钟", "10 分钟"], durations.find(int(room_settings.durationSec)), Vector2(220, 86), Vector2(450, 58), func(i: int) -> void:
		room_settings.durationSec = durations[i]
		show_page(8)))
	var hunters: Array = ["auto", 1, 2]
	panel.add_child(_label("猎手人数", Vector2(40, 164), Vector2(170, 52), FS_BODY, UiAssets.COLOR_TEXT))
	panel.add_child(_tabs(["自动", "1 人", "2 人"], hunters.find(room_settings.hunterCount), Vector2(220, 160), Vector2(450, 58), func(i: int) -> void:
		room_settings.hunterCount = hunters[i]
		show_page(8)))
	var toggles: Array = [["卧底模式", "moleEnabled"], ["近距离语音", "voiceEnabled"], ["AI 补位", "aiFill"]]
	for i: int in toggles.size():
		var y: float = 244 + i * 64
		var key: String = str(toggles[i][1])
		panel.add_child(_label(str(toggles[i][0]), Vector2(40, y), Vector2(250, 52), FS_BODY, UiAssets.COLOR_TEXT))
		panel.add_child(_toggle(Vector2(560, y + 4), bool(room_settings[key]), func(value: bool) -> void: room_settings[key] = value))
	var create: Button = _button("创建房间  ▶", Vector2(187, 444), Vector2(340, 80), UiAssets.COLOR_GOLD, 30)
	create.pressed.connect(_create_room)
	panel.add_child(create)

func _create_room() -> void:
	Net.send("room.create", {"settings": room_settings.duplicate()})
	Router.go(10)

# ---------------------------------------------------------------- 09 加入房间

func _build_join_room() -> void:
	_header("加入房间", 6)
	var panel: Panel = _panel(Vector2(357, 100), Vector2(620, 620))
	_add(panel)
	panel.add_child(_title_label("输入 6 位房间码", Vector2(0, 24), Vector2(620, 48), 34, UiAssets.COLOR_GOLD, true))
	panel.add_child(_label("好友分享的房间码，或点「粘贴」", Vector2(0, 74), Vector2(620, 26), FS_SMALL, UiAssets.COLOR_MUTED, true))
	code_cells.clear()
	for i: int in 6:
		var cell: Panel = _panel(Vector2(46 + i * 70, 116), Vector2(62, 82), "panel/panel_room_code_cell")
		var digit: Label = _title_label("", Vector2(0, 10), Vector2(62, 60), 44, UiAssets.COLOR_TEXT, true)
		cell.add_child(digit)
		code_cells.append(digit)
		panel.add_child(cell)
	var paste: Button = _button("粘贴", Vector2(470, 120), Vector2(104, 74), Color("38345e"), 20, "icon/copy-icon")
	paste.pressed.connect(func() -> void:
		var text: String = DisplayServer.clipboard_get().strip_edges()
		var digits: String = ""
		for c: String in text:
			if c.is_valid_int(): digits += c
		join_code = digits.left(6)
		_refresh_code_cells())
	panel.add_child(paste)
	var keypad: Array[String] = ["1","2","3","4","5","6","7","8","9","清空","0","删除"]
	for i: int in 12:
		var k: String = keypad[i]
		var b: Button = _button(k, Vector2(46 + (i % 3) * 180, 222 + (i / 3) * 70), Vector2(168, 60), Color("38345e"), 28 if k.is_valid_int() else 22)
		b.pressed.connect(func() -> void: _keypad_press(k))
		panel.add_child(b)
	var join: Button = _button("加入房间  ▶", Vector2(46, 512), Vector2(528, 76), UiAssets.COLOR_GOLD, 30)
	join.name = "JoinButton"
	join.pressed.connect(_join_room)
	panel.add_child(join)
	_refresh_code_cells()

func _refresh_code_cells() -> void:
	for i: int in code_cells.size():
		if is_instance_valid(code_cells[i]):
			code_cells[i].text = join_code[i] if i < join_code.length() else ("_" if i == join_code.length() else "")
			(code_cells[i].get_parent() as Control).self_modulate = Color(1.4, 1.2, 0.6) if i == join_code.length() else Color.WHITE
	var join_button: Button = active_page.find_child("JoinButton", true, false) as Button if is_instance_valid(active_page) else null
	if join_button:
		join_button.disabled = join_code.length() != 6

func _keypad_press(key: String) -> void:
	if key == "清空": join_code = ""
	elif key == "删除": join_code = join_code.left(-1)
	elif join_code.length() < 6: join_code += key
	_refresh_code_cells()

func _join_room() -> void:
	if join_code.length() != 6:
		show_toast("请输入 6 位数字房间码")
		return
	Net.send("room.join", {"code": join_code}); Router.go(10)

# ---------------------------------------------------------------- 10 房间等待

func _build_waiting() -> void:
	_header("房间等待", 6, func() -> void: Net.send("room.leave"))
	var code: String = str(Session.room.get("code", "------"))
	var chip: Panel = _panel(Vector2(760, 26), Vector2(330, 64), "panel/panel_top_resource_bar")
	_add(chip)
	chip.add_child(_label("房间码", Vector2(20, 0), Vector2(90, 64), FS_SMALL, UiAssets.COLOR_MUTED))
	chip.add_child(_title_label(code, Vector2(100, 4), Vector2(210, 56), 36, UiAssets.COLOR_GOLD))
	var copy: Button = _button("复制", Vector2(1100, 28), Vector2(100, 62), Color("38345e"), 20, "icon/copy-icon")
	copy.pressed.connect(func() -> void: DisplayServer.clipboard_set(code); show_toast("房间码已复制"))
	_add(copy)
	var share: Button = _button("分享", Vector2(1208, 28), Vector2(100, 62), Color("38345e"), 20, "icon/share-icon")
	if bool(Session.room.get("settings", {}).get("voiceEnabled", false)):
		var talk: Button = _button("按住说话", Vector2(580, 28), Vector2(166, 62), Color("3959b8"), 20, "icon/mic-icon")
		talk.button_down.connect(Voice.start_talking)
		talk.button_up.connect(Voice.stop_talking)
		_add(talk)
	share.pressed.connect(func() -> void: DisplayServer.clipboard_set("来《熄灯》一起躲猫猫！房间码 %s" % code); show_toast("邀请文字已复制"))
	_add(share)

	var players: Array = Session.room.get("players", [])
	var max_players: int = int(Session.room.get("settings", {}).get("maxPlayers", 12))
	for i: int in 12:
		var p: Dictionary = players[i] if i < players.size() else {}
		var card: Panel = _panel(Vector2(70 + (i % 6) * 202, 116 + (i / 6) * 206), Vector2(190, 194), "panel/panel_player_card")
		_add(card)
		if i >= max_players:
			card.modulate.a = 0.35
		card.add_child(_avatar(p, Vector2(45, 16), 100))
		if p.is_empty():
			card.add_child(_label("等待加入", Vector2(0, 124), Vector2(190, 30), FS_BODY, UiAssets.COLOR_MUTED, true))
			continue
		var name: String = str(p.get("nickname", "玩家")).left(7)
		card.add_child(_label(name, Vector2(0, 120), Vector2(190, 30), FS_BODY, UiAssets.COLOR_TEXT, true))
		if p.get("isHost", false):
			var host_tag: Panel = _panel(Vector2(10, 10), Vector2(86, 34), "button/tab_active")
			host_tag.add_child(UiAssets.picture("icon/crown-icon", Vector2(8, 4), Vector2(26, 26)))
			var host_text: Label = _label("房主", Vector2(36, 0), Vector2(46, 34), 16, UiAssets.COLOR_DARK_TEXT)
			host_text.add_theme_constant_override("outline_size", 0)
			host_tag.add_child(host_text)
			card.add_child(host_tag)
		var ready: bool = bool(p.get("ready", false))
		card.add_child(_label("✓ 已准备" if ready else "等待中", Vector2(0, 152), Vector2(190, 26), 18, UiAssets.COLOR_GREEN if ready else UiAssets.COLOR_MUTED, true))
		if Session.is_host() and p.get("isBot", false):
			var kick: Button = _icon_button("icon/close-icon", Vector2(138, 8), Vector2(44, 44), Color("38345e"))
			for state: String in ["normal", "hover", "pressed"]:
				kick.add_theme_stylebox_override(state, UiAssets.tex_style("button/button_round_icon", UiAssets.button(Color("38345e")), Vector2(12, 12), Vector2(4, 4), Color(1.2, 1.2, 1.2) if state == "hover" else Color.WHITE))
			kick.tooltip_text = "踢出"
			kick.pressed.connect(func() -> void: Net.send("room.kick", {"playerId": str(p.get("id", ""))}))
			card.add_child(kick)

	# Rules summary bar.
	var s: Dictionary = Session.room.get("settings", room_settings)
	var hunters: String = "自动" if str(s.get("hunterCount", "auto")) == "auto" else str(s.get("hunterCount")) + " 人"
	var rules: Panel = _panel(Vector2(70, 530), Vector2(1204, 58), "panel/panel_list_row")
	_add(rules)
	var summary: String = "地图 %s   ·   %d 分钟   ·   猎手 %s   ·   卧底%s   ·   语音%s   ·   AI补位%s   ·   %d / %d 人" % [str(MAP_INFO.get(str(s.get("map", "old_dorm")), MAP_INFO.old_dorm).name), int(s.get("durationSec", 600)) / 60, hunters, "开" if s.get("moleEnabled", false) else "关", "开" if s.get("voiceEnabled", false) else "关", "开" if s.get("aiFill", true) else "关", players.size(), max_players]
	rules.add_child(_label(summary, Vector2(0, 0), Vector2(1204, 58), 18, UiAssets.COLOR_TEXT, true))

	var my_ready: bool = false
	for p: Dictionary in players:
		if p.get("id") == Session.user.get("id"): my_ready = bool(p.get("ready", false))
	var invite: Button = _button("邀请好友", Vector2(70, 612), Vector2(220, 72), Color("38345e"), 24, "icon/invite-icon")
	invite.pressed.connect(func() -> void: Router.go(18))
	_add(invite)
	if Session.is_host():
		var start: Button = _button("开始游戏  ▶", Vector2(520, 604), Vector2(320, 88), UiAssets.COLOR_GOLD, 32)
		start.pressed.connect(func() -> void: Net.send("room.start"))
		_add(start)
	else:
		var ready_btn: Button = _button("取消准备" if my_ready else "准备", Vector2(520, 604), Vector2(320, 88), Color("38345e") if my_ready else UiAssets.COLOR_GOLD, 32, "icon/check-icon")
		ready_btn.pressed.connect(func() -> void: Net.send("room.ready", {"ready": not my_ready}))
		_add(ready_btn)
	if Session.is_host():
		var add_ai: Button = _button("+ AI", Vector2(310, 612), Vector2(190, 72), Color("38345e"), 24, "icon/robot-icon")
		add_ai.pressed.connect(func() -> void: Net.send("room.addBot"))
		_add(add_ai)
	var leave: Button = _button("离开", Vector2(1124, 618), Vector2(150, 62), Color("38345e"), 22, "icon/exit-icon")
	leave.pressed.connect(func() -> void: Net.send("room.leave"))
	_add(leave)

# ---------------------------------------------------------------- 11 地图投票

func _build_vote() -> void:
	_add(_title_label("地图投票", Vector2(0, 30), Vector2(1334, 64), 52, UiAssets.COLOR_GOLD, true))
	_add(_label("不同的夜晚，不同的故事。这一次，你会去哪？", Vector2(0, 112), Vector2(1334, 28), 18, UiAssets.COLOR_TEXT, true))
	var ring: Panel = _panel(Vector2(1160, 24), Vector2(130, 110), "panel/panel_room_code_cell")
	_add(ring)
	var timer: Label = _title_label("10s", Vector2(0, 20), Vector2(130, 70), 46, UiAssets.COLOR_GOLD, true)
	timer.name = "Timer"
	ring.add_child(timer)
	countdown = maxf(0, (float(Session.vote.get("endsAt", 0)) - Net.now_ms()) / 1000.0)
	var maps: Array = Session.vote.get("maps", ["old_dorm", "night_hospital", "night_mall"])
	var available: Array = Session.vote.get("available", ["old_dorm"])
	var counts: Dictionary = Session.vote.get("counts", {})
	for i: int in maps.size():
		var id: String = str(maps[i])
		var info: Dictionary = MAP_INFO.get(id, MAP_INFO.old_dorm)
		var open: bool = id in available
		var chosen: bool = i == my_vote and open
		var card: Button = _card_button(Vector2(72 + i * 406, 150), Vector2(378, 340), chosen)
		var picture: TextureRect = UiAssets.picture("mapcard/" + str(info.card), Vector2(16, 16), Vector2(346, 186))
		card.add_child(picture)
		var text_color: Color = UiAssets.COLOR_DARK_TEXT if chosen else UiAssets.COLOR_TEXT
		card.add_child(_title_label(str(info.name), Vector2(0, 208), Vector2(378, 50), 36, text_color, true))
		card.add_child(_label(str(info.desc), Vector2(0, 256), Vector2(378, 24), 17, UiAssets.COLOR_DARK_TEXT if chosen else UiAssets.COLOR_MUTED, true))
		if open:
			card.add_child(_title_label("%d 票" % int(counts.get(id, 0)), Vector2(0, 280), Vector2(378, 52), 40, UiAssets.COLOR_DARK_TEXT if chosen else UiAssets.COLOR_GOLD, true))
			card.pressed.connect(func() -> void:
				my_vote = i
				Net.send("vote.cast", {"mapId": id})
				show_page(11))
		else:
			# Maps from the design doc that are not built yet: shown, but not votable.
			picture.modulate = Color(0.45, 0.45, 0.55)
			card.add_child(UiAssets.picture("icon/lock-icon", Vector2(159, 74), Vector2(60, 60)))
			card.add_child(_label("即将开放", Vector2(0, 286), Vector2(378, 40), 22, UiAssets.COLOR_MUTED, true))
			card.disabled = true
			card.modulate = Color(0.85, 0.85, 0.9)
		if chosen:
			var tag: Panel = _panel(Vector2(16, 16), Vector2(116, 36), "button/tab_active")
			var tag_text: Label = _label("当前选择", Vector2(0, 0), Vector2(116, 36), 17, UiAssets.COLOR_DARK_TEXT, true)
			tag_text.add_theme_constant_override("outline_size", 0)
			tag.add_child(tag_text)
			card.add_child(tag)
		_add(card)
	# Who has voted: the room's players with a badge once their vote is in.
	var players: Array = Session.room.get("players", [])
	var voters: Array = Session.vote.get("voters", [])
	var shown: int = mini(players.size(), 12)
	var x0: float = (1334.0 - shown * 92.0 + 12.0) / 2.0
	for i: int in shown:
		var p: Dictionary = players[i]
		var slot: Panel = _panel(Vector2(x0 + i * 92, 510), Vector2(80, 96), "panel/panel_room_code_cell")
		slot.add_child(_avatar(p, Vector2(6, 6), 68))
		slot.add_child(_label(str(p.get("nickname", "玩家")).left(4), Vector2(0, 72), Vector2(80, 22), 13, UiAssets.COLOR_TEXT, true))
		if str(p.get("id", "")) in voters:
			var badge: Panel = _panel(Vector2(22, -22), Vector2(70, 30), "button/tab_active")
			var badge_text: Label = _label("投了!", Vector2(0, 0), Vector2(70, 30), 16, UiAssets.COLOR_DARK_TEXT, true)
			badge_text.add_theme_constant_override("outline_size", 0)
			badge.add_child(badge_text)
			slot.add_child(badge)
		_add(slot)
	_add(_label("点击地图卡投票，可以改票 · 票数最高的地图将被选中", Vector2(0, 640), Vector2(1334, 30), FS_BODY, UiAssets.COLOR_TEXT, true))

# ---------------------------------------------------------------- 12 角色分配

func _build_role_reveal() -> void:
	my_vote = -1
	_add(_title_label("你的身份是…", Vector2(60, 30), Vector2(660, 64), 52, UiAssets.COLOR_GOLD, true))
	var box: Panel = _panel(Vector2(1160, 24), Vector2(130, 110), "panel/panel_room_code_cell")
	_add(box)
	var timer: Label = _title_label("5s", Vector2(0, 20), Vector2(130, 70), 46, UiAssets.COLOR_GOLD, true)
	timer.name = "Timer"
	box.add_child(timer)
	countdown = 5.0
	var role: String = Session.role()
	var others: Array = ["hunter", "hider", "mole"]
	others.erase(role)
	# Left: dimmed backs of the other identities on each side, the player's card in front.
	for i: int in 2:
		var back: Panel = _panel(Vector2(80 + i * 460, 210), Vector2(190, 290), "button/card_role_back")
		back.modulate = Color(0.55, 0.55, 0.65, 0.8)
		back.rotation = -0.12 if i == 0 else 0.12
		var info_b: Dictionary = ROLE_INFO[others[i]]
		back.add_child(UiAssets.picture(str(info_b.art), Vector2(30, 40), Vector2(130, 130)))
		back.add_child(_title_label(str(info_b.name), Vector2(0, 190), Vector2(190, 50), 30, info_b.color, true))
		_add(back)
	var info: Dictionary = ROLE_INFO.get(role, ROLE_INFO.hider)
	var card: Panel = _panel(Vector2(200, 130), Vector2(380, 520), "button/card_role_front")
	card.self_modulate = {"hider": Color(0.75, 0.9, 1.35), "hunter": Color(1.35, 0.7, 0.7), "mole": Color(1.15, 0.8, 1.35)}.get(role, Color.WHITE)
	_add(card)
	card.add_child(UiAssets.picture(str(info.art), Vector2(70, 30), Vector2(240, 240)))
	card.add_child(_title_label(str(info.name), Vector2(0, 280), Vector2(380, 72), 64, info.color, true))
	var goal: Panel = _panel(Vector2(60, 360), Vector2(260, 52), "panel/panel_toast")
	card.add_child(goal)
	goal.add_child(_label(str(info.goal), Vector2(0, 0), Vector2(260, 52), 22, UiAssets.COLOR_GOLD, true))
	card.add_child(_label(str(info.desc), Vector2(20, 422), Vector2(340, 70), 18, UiAssets.COLOR_TEXT, true))
	# Right: overview of this match's map, so everyone knows the layout before hiding.
	var map_id: String = str(Session.game.get("mapId", "old_dorm"))
	var map_info: Dictionary = MAP_INFO.get(map_id, MAP_INFO.old_dorm)
	var map_panel: Panel = _panel(Vector2(760, 150), Vector2(530, 420))
	_add(map_panel)
	_section_title(map_panel, str(map_info.name), "icon/map-icon")
	var overview: String = "mapcard/" + str(map_info.card) + "-overview"
	if UiAssets.asset(overview) == null:
		overview = "mapcard/" + str(map_info.card)
	var frame: Panel = _panel(Vector2(26, 72), Vector2(478, 310), "button/card_map_frame")
	map_panel.add_child(frame)
	frame.add_child(UiAssets.picture(overview, Vector2(10, 10), Vector2(458, 290)))
	var hint: Panel = _panel(Vector2(760, 590), Vector2(530, 64), "panel/panel_top_resource_bar")
	_add(hint)
	hint.add_child(UiAssets.picture("icon/eye-closed-icon", Vector2(22, 16), Vector2(32, 32)))
	hint.add_child(_label("身份仅自己可见  ·  准备进入躲藏期", Vector2(64, 0), Vector2(440, 64), FS_BODY, UiAssets.COLOR_TEXT))

# ---------------------------------------------------------------- 15 幽灵阵营选择

func _build_ghost() -> void:
	var burst: TextureRect = UiAssets.picture("decor/decor-caught-burst", Vector2(417, 30), Vector2(500, 140))
	burst.modulate = Color(1, 1, 1, 0.3)
	if burst.texture: active_page.add_child(burst)
	_add(_title_label("抓到了！", Vector2(0, 62), Vector2(1334, 80), 64, UiAssets.COLOR_RED, true))
	var hint: Label = _label("出局不下线 · 选择你的幽灵阵营", Vector2(0, 170), Vector2(1334, 34), 22, UiAssets.COLOR_TEXT, true)
	hint.name = "GhostHint"
	_add(hint)
	var sides: Array = [["守护灵", "制造一次假波纹，帮藏者误导猎手", "role/role-ghost-guardian", Color("7fb2ff"), "guardian"], ["怨灵", "标记一名藏者 2 秒，让猎手看见", "role/role-ghost-wraith", Color("d77cff"), "wraith"]]
	for i: int in 2:
		var side: Array = sides[i]
		var card: Button = _card_button(Vector2(297 + i * 400, 226), Vector2(340, 440), false)
		card.self_modulate = Color(0.75, 0.9, 1.35) if i == 0 else Color(1.2, 0.75, 1.35)
		card.add_child(UiAssets.picture(str(side[2]), Vector2(70, 20), Vector2(200, 200)))
		card.add_child(_title_label(str(side[0]), Vector2(0, 230), Vector2(340, 56), 44, side[3], true))
		var desc: Label = _label(str(side[1]), Vector2(30, 294), Vector2(280, 56), 18, UiAssets.COLOR_TEXT, true)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(desc)
		var pick: Button = _button("选择" + str(side[0]), Vector2(50, 364), Vector2(240, 60), UiAssets.COLOR_GOLD, 24)
		var choose: Callable = func() -> void:
			Net.send("game.ghostSide", {"side": str(side[4])})
			_leave_ghost_choice()
		pick.pressed.connect(choose)
		card.pressed.connect(choose)
		card.add_child(pick)
		_add(card)
	# The server defaults to guardian when the window lapses; follow it back into play.
	# The snapshot that carries the deadline can arrive after game.caught; until then the
	# field is still 0, so fall back to the full 10 s window instead of leaving at once.
	var ends_at: float = float(Session.me().get("ghostChoiceEndsAt", 0))
	if ends_at < Net.now_ms() + 1000.0:
		ends_at = Net.now_ms() + 10000.0
	get_tree().create_timer((ends_at - Net.now_ms()) / 1000.0 + 0.3).timeout.connect(_leave_ghost_choice)

func _leave_ghost_choice() -> void:
	if Router.current == 15:
		Router.go(14 if Session.role() == "hunter" else 13)

# ---------------------------------------------------------------- 17 游戏结算

func _build_result() -> void:
	var winner: String = str(Session.result.get("winner", "hider"))
	var banner: TextureRect = UiAssets.picture("decor/banner_victory_" + winner, Vector2(387, 12), Vector2(560, 130))
	if banner.texture: active_page.add_child(banner)
	_add(_title_label("猎手胜利" if winner == "hunter" else "藏者胜利", Vector2(0, 32), Vector2(1334, 84), 64, UiAssets.COLOR_GOLD, true))
	var players: Array = Session.result.get("players", [])
	var mvp: Dictionary = Session.result.get("mvp", {})
	# Personal outcome right under the banner: which side you were on and whether it won.
	var mine: Dictionary = {}
	for p: Dictionary in players:
		if str(p.get("id", "")) == str(Session.user.get("id", "")): mine = p
	var my_side: String = "hunter" if str(mine.get("role", Session.role())) in ["hunter", "mole"] else "hider"
	var won: bool = my_side == winner
	_add(_title_label("你赢了！" if won else "惜败，下局再来", Vector2(0, 134), Vector2(1334, 32), 26, UiAssets.COLOR_GOLD if won else Color("c9c4e6"), true))
	var me: Dictionary = {}
	for p: Dictionary in players:
		if str(p.get("id", "")) == str(Session.user.get("id", "")): me = p
	for side: int in 2:
		var role: String = "hunter" if side == 1 else "hider"
		var mvp_player: Dictionary = {}
		for p: Dictionary in players:
			if str(p.get("id", "")) == str(mvp.get(role, "")): mvp_player = p
		var card: Panel = _panel(Vector2(46 + side * 944, 170), Vector2(298, 412), "panel/panel_player_card")
		card.self_modulate = Color(1.35, 0.72, 0.72) if side == 1 else Color(0.75, 0.9, 1.35)
		_add(card)
		card.add_child(_title_label("猎手阵营" if side == 1 else "藏者阵营", Vector2(0, 20), Vector2(298, 40), 28, UiAssets.COLOR_RED if side == 1 else Color("7fb2ff"), true))
		var portrait: Dictionary = mvp_player.duplicate()
		if side == 1: portrait["avatar"] = "avatar-hunter-warden"
		card.add_child(_avatar(portrait, Vector2(59, 70), 180))
		var medal: TextureRect = UiAssets.picture("decor/decor-mvp-ribbon", Vector2(62, 256), Vector2(56, 50))
		if medal.texture: card.add_child(medal)
		card.add_child(_title_label("MVP", Vector2(110, 254), Vector2(120, 52), 34, UiAssets.COLOR_GOLD))
		card.add_child(_label(str(mvp_player.get("nickname", "—")), Vector2(0, 318), Vector2(298, 32), 24, UiAssets.COLOR_TEXT, true))
		card.add_child(_label("得分 %d" % int(mvp_player.get("score", 0)), Vector2(0, 356), Vector2(298, 32), 22, UiAssets.COLOR_GOLD, true))

	# Centre: my score breakdown and rewards.
	var panel: Panel = _panel(Vector2(364, 170), Vector2(606, 412))
	_add(panel)
	var my_role: String = str(me.get("role", Session.role()))
	panel.add_child(_label("个人得分 · %s%s" % [ROLE_INFO.get(my_role, ROLE_INFO.hider).name, "（已被抓）" if me.get("caught", false) else ""], Vector2(36, 22), Vector2(540, 32), 22, UiAssets.COLOR_GOLD))
	var y: float = 64.0
	var breakdown: Array = me.get("breakdown", [])
	if breakdown.is_empty():
		panel.add_child(_label("本局没有得分项", Vector2(36, y), Vector2(540, 36), FS_BODY, UiAssets.COLOR_MUTED))
		y += 40
	for entry: Dictionary in breakdown.slice(0, 5):
		var row: Panel = _panel(Vector2(30, y), Vector2(546, 44), "panel/panel_score_row")
		row.add_child(_label(str(entry.get("label", "")), Vector2(20, 0), Vector2(360, 44), FS_BODY, UiAssets.COLOR_TEXT))
		var pts: Label = _label("%+d" % int(entry.get("pts", 0)), Vector2(380, 0), Vector2(146, 44), 22, UiAssets.COLOR_GOLD)
		pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(pts)
		panel.add_child(row)
		y += 48
	panel.add_child(_label("合计", Vector2(50, 312), Vector2(200, 40), 24, UiAssets.COLOR_TEXT))
	var total: Label = _title_label(str(int(me.get("score", 0))), Vector2(380, 306), Vector2(176, 50), 40, UiAssets.COLOR_GOLD)
	total.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel.add_child(total)
	var reward: Dictionary = Session.result.get("rewards", {})
	var rewards: Array = [["icon/star-icon", "经验", "+%d" % int(reward.get("exp", 0))], ["icon/coin-icon", "金币", "+%d" % int(reward.get("coins", 0))], ["icon/trophy-icon", "段位", "%+d" % int(reward.get("rankDelta", 0))]]
	for i: int in 3:
		var chip: Control = _resource_chip(str(rewards[i][0]), str(rewards[i][1]) + " " + str(rewards[i][2]), Vector2(30 + i * 186, 360), Vector2(176, 50))
		panel.add_child(chip)

	var back: Button = _button("返回主界面", Vector2(300, 600), Vector2(260, 88), Color("7047b9"), 26)
	back.pressed.connect(func() -> void: Net.send("room.leave"))
	_add(back)
	var again: Button = _button("再来一局  ▶", Vector2(577, 594), Vector2(300, 100), UiAssets.COLOR_GOLD, 34)
	again.pressed.connect(func() -> void: Net.send("room.again"))
	_add(again)
	var share: Button = _button("分享战绩", Vector2(894, 600), Vector2(220, 88), Color("7047b9"), 26, "icon/share-icon")
	share.pressed.connect(func() -> void: DisplayServer.clipboard_set("《熄灯》%s！我得了 %d 分，房间 %s" % ["猎手胜利" if winner == "hunter" else "藏者胜利", int(me.get("score", 0)), str(Session.room.get("code", ""))]); show_toast("战绩已复制，可粘贴到微信 / QQ"))
	_add(share)

# ---------------------------------------------------------------- 18 好友与邀请

func _build_friends() -> void:
	_header("好友与邀请", 6)
	var panel: Panel = _panel(Vector2(40, 110), Vector2(820, 610))
	_add(panel)
	var search: LineEdit = _edit("输入好友 ID 添加", Vector2(30, 26), Vector2(560, 64))
	panel.add_child(_label("我的 ID：%s（发给好友即可添加你）" % str(Session.user.get("shortId", "--------")), Vector2(400, 100), Vector2(390, 30), FS_SMALL, UiAssets.COLOR_GOLD))
	panel.add_child(search)
	var add: Button = _button("添加好友", Vector2(604, 26), Vector2(186, 64), UiAssets.COLOR_GOLD, 22, "icon/add-friend-icon")
	add.pressed.connect(func() -> void: _add_friend(search.text.strip_edges()))
	panel.add_child(add)
	var title: Label = _label("好友列表", Vector2(34, 102), Vector2(400, 30), 24, UiAssets.COLOR_GOLD)
	title.name = "FriendTitle"
	panel.add_child(title)
	var list: VBoxContainer = VBoxContainer.new()
	list.name = "FriendList"
	list.position = Vector2(30, 140)
	list.size = Vector2(760, 450)
	list.add_theme_constant_override("separation", 8)
	panel.add_child(list)
	list.add_child(_label("正在加载好友…", Vector2.ZERO, Vector2(760, 40), FS_BODY, UiAssets.COLOR_MUTED))

	# Right: my room code and share buttons.
	var room: Panel = _panel(Vector2(880, 110), Vector2(414, 610))
	_add(room)
	_section_title(room, "我的房间", "icon/invite-icon")
	var code: String = str(Session.room.get("code", ""))
	var code_box: Panel = _panel(Vector2(30, 76), Vector2(354, 110), "panel/panel_room_code_cell")
	room.add_child(code_box)
	code_box.add_child(_title_label(code if not code.is_empty() else "——", Vector2(0, 16), Vector2(354, 78), 60, UiAssets.COLOR_GOLD, true))
	room.add_child(_label("在房间里才能邀请好友" if code.is_empty() else "好友点击邀请即可加入", Vector2(0, 196), Vector2(414, 28), FS_SMALL, UiAssets.COLOR_MUTED, true))
	room.add_child(_sprite_figure(str(Session.user.get("color", "blue")), Vector2(137, 228), 190))
	var share_text: String = "来《熄灯》一起躲猫猫！" + ("房间码 " + code if not code.is_empty() else "")
	var wechat: Button = _button("微信分享", Vector2(30, 510), Vector2(170, 72), UiAssets.COLOR_GREEN, 22, "icon/wechat-icon")
	wechat.pressed.connect(func() -> void: DisplayServer.clipboard_set(share_text); show_toast("邀请文字已复制，去微信粘贴"))
	room.add_child(wechat)
	var qq: Button = _button("QQ 分享", Vector2(214, 510), Vector2(170, 72), Color("3959b8"), 22, "icon/qq-icon")
	qq.pressed.connect(func() -> void: DisplayServer.clipboard_set(share_text); show_toast("邀请文字已复制，去 QQ 粘贴"))
	room.add_child(qq)
	_load_friends()

func _load_friends() -> void:
	var response: Dictionary = await Api.get_json("/friends")
	if Router.current != 18 or not is_instance_valid(active_page):
		return
	var list: VBoxContainer = active_page.find_child("FriendList", true, false) as VBoxContainer
	var title: Label = active_page.find_child("FriendTitle", true, false) as Label
	if list == null: return
	for child: Node in list.get_children(): child.queue_free()
	var friends: Array = response.get("friends", [])
	if title: title.text = "好友列表（%d/50）" % friends.size()
	if friends.is_empty():
		var empty: Label = _label("还没有好友\n把你的 ID 发给朋友，或输入对方的 ID 添加", Vector2.ZERO, Vector2(760, 300), 22, UiAssets.COLOR_MUTED, true)
		empty.custom_minimum_size = Vector2(760, 300)
		list.add_child(empty)
		return
	var in_room: bool = not Session.room.is_empty()
	for f: Dictionary in friends.slice(0, 6):
		var user: Dictionary = f.get("user", {})
		var status: String = str(f.get("status", "offline"))
		var row: Panel = _panel(Vector2.ZERO, Vector2(760, 70), "panel/panel_list_row")
		row.custom_minimum_size = Vector2(760, 70)
		row.add_child(_avatar(user, Vector2(14, 7), 56))
		row.add_child(_label(str(user.get("nickname", "玩家")), Vector2(86, 6), Vector2(300, 32), FS_BODY, UiAssets.COLOR_TEXT))
		var status_text: String = {"online": "● 在线", "in_game": "● 游戏中"}.get(status, "○ 离线")
		var status_color: Color = {"online": UiAssets.COLOR_GREEN, "in_game": UiAssets.COLOR_GOLD}.get(status, UiAssets.COLOR_MUTED)
		row.add_child(_label(status_text, Vector2(86, 36), Vector2(200, 26), FS_SMALL, status_color))
		var invite: Button = _button("邀请到房间" if status == "online" else ("游戏中" if status == "in_game" else "离线"), Vector2(560, 10), Vector2(180, 50), UiAssets.COLOR_GOLD if status == "online" else Color("38345e"), 20)
		invite.disabled = status != "online"
		var fid: String = str(user.get("id", ""))
		invite.pressed.connect(func() -> void:
			if not in_room:
				show_toast("先创建或加入房间，再邀请好友")
				return
			Net.send("room.invite", {"friendId": fid})
			show_toast("邀请已发送"))
		row.add_child(invite)
		list.add_child(row)

func _add_friend(short_id: String) -> void:
	if short_id.is_empty():
		show_toast("请输入好友 ID")
		return
	var response: Dictionary = await Api.request("/friends/add", {"shortId": short_id})
	if response.get("ok", false):
		show_toast("已添加好友")
		_load_friends()
	else:
		show_toast(str(response.get("msg", "添加失败")))

# ---------------------------------------------------------------- 19 设置

func _build_settings() -> void:
	_header("设置", 6)
	var columns: Array = [["声音与辅助", 40.0, "icon/sound-on-icon"], ["画面与操作", 468.0, "icon/vibration-icon"], ["账号与安全", 896.0, "icon/user-icon"]]
	var panels: Array[Panel] = []
	for c: Array in columns:
		var p: Panel = _panel(Vector2(float(c[1]), 110), Vector2(398, 560))
		_add(p)
		_section_title(p, str(c[0]), str(c[2]))
		panels.append(p)
	# Column 1: sound and accessibility.
	var sound: Panel = panels[0]
	sound.add_child(_label("音量", Vector2(30, 84), Vector2(90, 40), FS_BODY, UiAssets.COLOR_TEXT))
	var pct: Label = _label("%d%%" % int(float(Config.settings.volume) * 100), Vector2(300, 84), Vector2(70, 40), 18, UiAssets.COLOR_GOLD)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sound.add_child(pct)
	sound.add_child(_slider(Vector2(110, 90), Vector2(190, 30), float(Config.settings.volume) * 100, func(value: float) -> void:
		Config.settings.volume = value / 100.0
		pct.text = "%d%%" % int(value)
		Audio.apply_settings()
		Config.save()))
	var rows: Array = [["静音视觉增强", "visual_audio", "加大波纹与边缘提示"], ["色弱模式", "colorblind", "用形状区分阵营与品质"], ["震动反馈", "vibration", "被追踪、被抓时震动"], ["屏幕震动", "shake", "抓捕瞬间镜头晃动"]]
	for i: int in rows.size():
		var y: float = 150 + i * 92
		var key: String = str(rows[i][1])
		sound.add_child(_label(str(rows[i][0]), Vector2(30, y), Vector2(250, 32), FS_BODY, UiAssets.COLOR_TEXT))
		sound.add_child(_label(str(rows[i][2]), Vector2(30, y + 32), Vector2(260, 24), 14, UiAssets.COLOR_MUTED))
		sound.add_child(_toggle(Vector2(290, y + 6), bool(Config.settings[key]), func(value: bool) -> void:
			Config.settings[key] = value
			Config.save()))
	# Column 2: graphics and controls.
	var gfx: Panel = panels[1]
	gfx.add_child(_label("画质档位", Vector2(30, 84), Vector2(300, 32), FS_BODY, UiAssets.COLOR_TEXT))
	gfx.add_child(_tabs(["省电", "标准", "高"], clampi(int(Config.settings.quality), 0, 2), Vector2(30, 122), Vector2(338, 58), func(i: int) -> void:
		Config.settings.quality = i
		Config.save()
		show_page(19)))
	gfx.add_child(_label("左手模式", Vector2(30, 216), Vector2(250, 32), FS_BODY, UiAssets.COLOR_TEXT))
	gfx.add_child(_label("交换摇杆与按钮位置", Vector2(30, 248), Vector2(260, 24), 14, UiAssets.COLOR_MUTED))
	gfx.add_child(_toggle(Vector2(290, 222), bool(Config.settings.left_hand), func(value: bool) -> void:
		Config.settings.left_hand = value
		Config.save()))
	gfx.add_child(UiAssets.picture("hud/hud-joystick-base", Vector2(40, 310) if not Config.settings.left_hand else Vector2(250, 310), Vector2(110, 110)))
	gfx.add_child(UiAssets.picture("hud/hud-btn-main-interact", Vector2(250, 316) if not Config.settings.left_hand else Vector2(40, 316), Vector2(100, 100)))
	gfx.add_child(_label("按钮布局预览", Vector2(0, 430), Vector2(398, 26), FS_SMALL, UiAssets.COLOR_MUTED, true))
	gfx.add_child(_label("设置自动保存", Vector2(0, 500), Vector2(398, 26), FS_SMALL, UiAssets.COLOR_MUTED, true))
	# Column 3: account.
	var acct: Panel = panels[2]
	var user: Dictionary = Session.user
	acct.add_child(_avatar(user, Vector2(30, 76), 90))
	acct.add_child(_label(str(user.get("nickname", "游客")), Vector2(134, 84), Vector2(240, 34), 24, UiAssets.COLOR_TEXT))
	acct.add_child(_label("ID " + str(user.get("shortId", "--------")), Vector2(134, 122), Vector2(240, 28), FS_SMALL, UiAssets.COLOR_MUTED))
	acct.add_child(_label("账号绑定", Vector2(30, 196), Vector2(300, 30), FS_BODY, UiAssets.COLOR_GOLD))
	var bindings: Dictionary = user.get("bindings", {})
	var has_phone: bool = bindings.get("phone") != null and str(bindings.get("phone", "")) != ""
	var binds: Array = [["icon/wechat-icon", "微信", bool(bindings.get("wechat", false)), _bind_wechat],
		["icon/phone-icon", str(bindings.phone) if has_phone else "手机号", has_phone, _bind_phone],
		["icon/user-icon", str(bindings.get("account")) if bindings.get("account") else "账号密码", bindings.get("account") != null and str(bindings.get("account", "")) != "", _bind_account]]
	for i: int in binds.size():
		var y: float = 232 + i * 68
		acct.add_child(UiAssets.picture(str(binds[i][0]), Vector2(30, y + 8), Vector2(40, 40)))
		acct.add_child(_label(str(binds[i][1]), Vector2(82, y), Vector2(156, 56), FS_BODY, UiAssets.COLOR_TEXT))
		var bound: bool = bool(binds[i][2])
		var bind: Button = _button("已绑定" if bound else "去绑定", Vector2(244, y + 4), Vector2(124, 50), Color("38345e") if bound else UiAssets.COLOR_GREEN, 20)
		bind.disabled = bound
		bind.pressed.connect(binds[i][3])
		acct.add_child(bind)
	var out: Button = _button("退出登录", Vector2(30, 460), Vector2(338, 72), UiAssets.COLOR_RED, 26, "icon/exit-icon")
	out.pressed.connect(func() -> void: Session.logout())
	acct.add_child(out)
	var debug: Button = _button("v" + Config.VERSION, Vector2(8, 700), Vector2(84, 40), Color("2a2350"), 14)
	debug.modulate.a = 0.35
	debug.pressed.connect(_show_server_debug)
	_add(debug)

# ---------------------------------------------------------------- 账号绑定 / 找回密码

## Modal form over the current page. `fields` = [[key, placeholder, secret]]; a field named
## "code" gets a 获取验证码 button that sends an SMS to the "phone" field.
func _form_modal(title: String, fields: Array, submit_text: String, on_submit: Callable) -> void:
	var veil: ColorRect = ColorRect.new()
	veil.color = Color(0.02, 0.01, 0.06, 0.7)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.name = "FormModal"
	_add(veil)
	var height: float = 190.0 + fields.size() * 80.0
	var panel: Panel = _panel(Vector2(367, (750.0 - height) / 2.0), Vector2(600, height), "panel/panel_modal")
	veil.add_child(panel)
	panel.add_child(_title_label(title, Vector2(0, 24), Vector2(600, 50), 32, UiAssets.COLOR_GOLD, true))
	var edits: Dictionary = {}
	for i: int in fields.size():
		var f: Array = fields[i]
		var is_code: bool = str(f[0]) == "code"
		var e: LineEdit = _edit(str(f[1]), Vector2(50, 92 + i * 80), Vector2(320 if is_code else 500, 64))
		e.secret = bool(f[2])
		panel.add_child(e)
		edits[str(f[0])] = e
		if is_code:
			var send: Button = _button("获取验证码", Vector2(384, 92 + i * 80), Vector2(166, 64), UiAssets.COLOR_GOLD, 20)
			send.pressed.connect(func() -> void:
				var phone: LineEdit = edits.get("phone")
				var response: Dictionary = await Api.request("/auth/sms/send", {"phone": phone.text if phone else ""})
				show_toast(("开发验证码：" + str(response.devCode)) if response.has("devCode") else str(response.get("msg", "验证码已发送")) if not response.get("ok", false) else "验证码已发送"))
			panel.add_child(send)
	var cancel: Button = _button("取消", Vector2(50, height - 92), Vector2(230, 66), Color("38345e"), 24)
	cancel.pressed.connect(veil.queue_free)
	panel.add_child(cancel)
	var ok: Button = _button(submit_text, Vector2(320, height - 92), Vector2(230, 66), UiAssets.COLOR_GOLD, 24)
	ok.pressed.connect(func() -> void:
		var values: Dictionary = {}
		for key: String in edits: values[key] = (edits[key] as LineEdit).text.strip_edges()
		var response: Dictionary = await on_submit.call(values)
		if response.get("ok", false):
			if is_instance_valid(veil): veil.queue_free()
		else:
			show_toast(str(response.get("msg", "操作失败"))))
	panel.add_child(ok)

func _after_bind(response: Dictionary, done: String) -> Dictionary:
	if response.get("ok", false):
		Session.user = response.user
		show_toast(done)
		show_page(Router.current)
	return response

func _bind_wechat() -> void:
	var code: Dictionary = await WeChat.authorize_code("mock_bind_" + str(Session.user.get("id", "")))
	if not code.get("ok", false):
		show_toast(str(code.get("msg", "微信授权失败")))
		return
	var response: Dictionary = await Api.request("/bind/wechat", {"code": code.code})
	if not _after_bind(response, "微信已绑定").get("ok", false):
		show_toast(str(response.get("msg", "绑定失败")))

func _bind_phone() -> void:
	_form_modal("绑定手机号", [["phone", "请输入手机号", false], ["code", "请输入验证码", false]], "绑定", func(v: Dictionary) -> Dictionary:
		return _after_bind(await Api.request("/bind/phone", {"phone": v.phone, "code": v.code}), "手机号已绑定"))

func _bind_account() -> void:
	_form_modal("设置账号密码", [["account", "账号（4–20 位字母数字）", false], ["password", "密码（6–32 位）", true], ["confirm", "再次输入密码", true]], "保存", func(v: Dictionary) -> Dictionary:
		if v.password != v.confirm:
			return {"ok": false, "msg": "两次输入的密码不一致"}
		return _after_bind(await Api.request("/bind/account", {"account": v.account, "password": v.password}), "账号密码已设置"))

func _forgot_password() -> void:
	_form_modal("找回密码", [["phone", "账号绑定的手机号", false], ["code", "请输入验证码", false], ["password", "新密码（6–32 位）", true]], "重置密码", func(v: Dictionary) -> Dictionary:
		var response: Dictionary = await Api.request("/auth/password/reset", {"phone": v.phone, "code": v.code, "password": v.password})
		if response.get("ok", false):
			show_toast("密码已重置，请用账号 %s 登录" % str(response.get("account", "")))
			if is_instance_valid(account_edit): account_edit.text = str(response.get("account", ""))
		return response)

func _show_server_debug() -> void:
	var edit: LineEdit = _edit("http://127.0.0.1:8787", Vector2(445, 684), Vector2(390, 56)); edit.text = Config.server_url; active_page.add_child(edit)
	var save: Button = _button("连接", Vector2(845, 684), Vector2(110, 56), UiAssets.COLOR_GOLD, 22); save.pressed.connect(func() -> void:
		Config.server_url = edit.text.strip_edges().trim_suffix("/")
		Config.save()
		Net.disconnect_session()
		Net.connect_session()
		show_toast("服务器地址已保存")); active_page.add_child(save)

# ---------------------------------------------------------------- 20 衣柜 / 21 商店

const SLOT_TABS: Array = [["hat", "帽子"], ["footprint", "脚印"], ["effect", "变身特效"]]

## Icon for a cosmetic: hat front overlay cropped to the hat, footprint print, effect mid-frame.
func _item_icon(slot: String, id: String) -> Texture2D:
	var tex: Texture2D
	var region: Rect2
	match slot:
		"hat":
			tex = CharacterArt.hat(id, "down")
			region = UiAssets.used_rect("sprite/hat-%s-down" % id)
		"footprint":
			tex = UiAssets.asset("sprite/footprint-" + id) if id != "plain" else UiAssets.asset("decor/decor-footprints")
			return tex
		_:
			tex = CharacterArt.strip("poof-" + id) if id != "poof" else CharacterArt.strip("disguise-poof")
			region = Rect2(128, 0, 128, 128)
	if tex == null:
		return null
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = region if region.size.x > 0 else Rect2(Vector2.ZERO, tex.get_size())
	return atlas

## Loads /shop once per visit, then rebuilds the page with the data.
func _with_shop(page: int) -> bool:
	if not shop_cache.is_empty():
		return true
	_add(_label("正在加载…", Vector2(0, 360), Vector2(1334, 40), FS_BODY, UiAssets.COLOR_MUTED, true))
	var response: Dictionary = await Api.get_json("/shop")
	if response.get("ok", false) and Router.current == page:
		shop_cache = response
		show_page(page)
	elif Router.current == page:
		show_toast(str(response.get("msg", "加载失败")))
	return false

func _slot_tabs(page: int) -> void:
	var tabs: HBoxContainer = _tabs(SLOT_TABS.map(func(t: Array) -> String: return str(t[1])), SLOT_TABS.map(func(t: Array) -> String: return str(t[0])).find(shop_slot), Vector2(560, 120), Vector2(540, 56), func(i: int) -> void:
		shop_slot = str(SLOT_TABS[i][0])
		show_page(page))
	_add(tabs)

func _build_wardrobe() -> void:
	_header("衣柜", 6)
	var look: Dictionary = Session.user.get("look", {}) if Session.user.get("look") is Dictionary else {}
	var preview_hat: String = str(look.get("hat", "nightcap"))
	_add(_floor_glow(Vector2(270, 600), Vector2(420, 100)))
	_add(CharacterArt.figure(str(Session.user.get("color", "blue")), preview_hat, Vector2(110, 170), 384))
	var worn: Panel = _panel(Vector2(70, 630), Vector2(420, 70), "panel/panel_list_row")
	_add(worn)
	var names: Array = []
	for slot: String in ["hat", "footprint", "effect"]:
		for item: Dictionary in shop_cache.get("items", []):
			if item.slot == slot and item.id == str(look.get(slot, "")):
				names.append(item.name)
	worn.add_child(_label("当前穿戴：" + (" · ".join(names) if not names.is_empty() else "默认"), Vector2(20, 0), Vector2(380, 70), FS_SMALL, UiAssets.COLOR_TEXT))
	if not await _with_shop(20):
		return
	_slot_tabs(20)
	_item_grid(20)

func _build_shop() -> void:
	_header("商店", 6)
	for i: int in 2:
		_add(_resource_chip(["icon/coin-icon", "icon/gem-icon"][i], str(int(Session.user.get(["coins", "gems"][i], 0))), Vector2(860 + i * 230, 26), Vector2(210, 60)))
	if not await _with_shop(21):
		return
	_slot_tabs(21)
	_add(_label("皮肤只改外观，不影响体型、速度和在黑暗中的可见度", Vector2(560, 690), Vector2(700, 26), FS_SMALL, UiAssets.COLOR_MUTED))
	_item_grid(21)

## Item cards: the wardrobe shows everything (owned ones equip, others link to the shop);
## the shop shows prices and buys.
func _item_grid(page: int) -> void:
	var look: Dictionary = Session.user.get("look", {}) if Session.user.get("look") is Dictionary else {}
	var items: Array = shop_cache.get("items", []).filter(func(i: Dictionary) -> bool: return i.slot == shop_slot)
	var x0: float = 560.0 if page == 20 else 120.0
	var columns: int = 4 if page == 20 else 6
	for n: int in items.size():
		var item: Dictionary = items[n]
		var owned: bool = bool(item.get("owned", false))
		var worn: bool = owned and str(look.get(shop_slot, "")) == str(item.id)
		var card: Button = _card_button(Vector2(x0 + (n % columns) * 180, 196 + (n / columns) * 236), Vector2(168, 224), worn)
		var icon: TextureRect = TextureRect.new()
		icon.texture = _item_icon(shop_slot, str(item.id))
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.position = Vector2(24, 18)
		icon.size = Vector2(120, 104)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if page == 20 and not owned:
			icon.modulate = Color(0.45, 0.45, 0.55)
		card.add_child(icon)
		card.add_child(_label(str(item.name), Vector2(0, 126), Vector2(168, 30), 18, UiAssets.COLOR_GOLD if worn else UiAssets.COLOR_TEXT, true))
		var action_text: String
		var action_color: Color = UiAssets.COLOR_GOLD
		if page == 20:
			action_text = "已穿戴" if worn else ("穿戴" if owned else "去商店")
			if worn or not owned: action_color = Color("38345e")
		else:
			action_text = "已拥有" if owned else ("%d %s" % [int(item.price), "金币" if item.currency == "coins" else "钻石"] if int(item.price) > 0 else "免费")
			if owned: action_color = Color("38345e")
		var act: Button = _button(action_text, Vector2(14, 166), Vector2(140, 46), action_color, 18)
		act.disabled = worn or (page == 21 and owned)
		var slot: String = shop_slot
		var id: String = str(item.id)
		act.pressed.connect(func() -> void:
			if page == 20 and not owned:
				Router.go(21)
				return
			_shop_action("/wardrobe/equip" if page == 20 else "/shop/buy", slot, id, page))
		card.pressed.connect(func() -> void: act.pressed.emit())
		card.add_child(act)
		if bool(item.get("rare", false)):
			card.add_child(_label("稀有", Vector2(108, 6), Vector2(54, 24), 14, UiAssets.COLOR_GOLD, true))
		_add(card)

func _shop_action(path: String, slot: String, id: String, page: int) -> void:
	var response: Dictionary = await Api.request(path, {"slot": slot, "id": id})
	if response.get("ok", false):
		Session.user = response.user
		shop_cache = {}
		show_toast("已穿戴" if "equip" in path else "购买成功，去衣柜穿上吧")
		show_page(page)
	else:
		show_toast(str(response.get("msg", "操作失败")))

# ---------------------------------------------------------------- 22 战绩

func _build_records() -> void:
	_header("战绩", 6)
	if records_cache.is_empty():
		_add(_label("正在加载…", Vector2(0, 360), Vector2(1334, 40), FS_BODY, UiAssets.COLOR_MUTED, true))
		var response: Dictionary = await Api.get_json("/records")
		if response.get("ok", false) and Router.current == 22:
			records_cache = response
			show_page(22)
		return
	var stats: Dictionary = records_cache.get("stats", {})
	var games: int = int(stats.get("games", 0))
	var tiles: Array = [["总场次", str(games)], ["胜场", str(int(stats.get("wins", 0)))], ["胜率", "%d%%" % (int(stats.get("wins", 0)) * 100 / games) if games > 0 else "—"],
		["抓到", str(int(stats.get("captures", 0)))], ["救出", str(int(stats.get("rescues", 0)))], ["修发电机", str(int(stats.get("repairs", 0)))], ["MVP", str(int(stats.get("mvp", 0)))]]
	for i: int in tiles.size():
		var tile: Panel = _panel(Vector2(60 + i * 174, 110), Vector2(162, 110), "panel/panel_room_code_cell")
		tile.add_child(_title_label(str(tiles[i][1]), Vector2(0, 14), Vector2(162, 52), 38, UiAssets.COLOR_GOLD, true))
		tile.add_child(_label(str(tiles[i][0]), Vector2(0, 66), Vector2(162, 28), FS_SMALL, UiAssets.COLOR_TEXT, true))
		_add(tile)
	var panel: Panel = _panel(Vector2(60, 240), Vector2(1214, 470))
	_add(panel)
	_section_title(panel, "最近对局", "icon/record-icon")
	var records: Array = records_cache.get("records", [])
	if records.is_empty():
		panel.add_child(_label("还没有对局记录，去打一局吧", Vector2(0, 200), Vector2(1214, 40), FS_BODY, UiAssets.COLOR_MUTED, true))
		return
	for i: int in mini(records.size(), 6):
		var r: Dictionary = records[i]
		var row: Panel = _panel(Vector2(30, 70 + i * 64), Vector2(1154, 58), "panel/panel_list_row")
		var won: bool = bool(r.get("win", false))
		row.add_child(_title_label("胜" if won else "负", Vector2(16, 0), Vector2(50, 58), 30, UiAssets.COLOR_GOLD if won else Color("8f8aa8"), true))
		row.add_child(_label(str(MAP_INFO.get(str(r.get("mapId", "old_dorm")), MAP_INFO.old_dorm).name), Vector2(80, 0), Vector2(160, 58), FS_BODY, UiAssets.COLOR_TEXT))
		row.add_child(_label(str(ROLE_INFO.get(str(r.get("role", "hider")), ROLE_INFO.hider).name), Vector2(250, 0), Vector2(90, 58), FS_BODY, ROLE_INFO.get(str(r.get("role", "hider")), ROLE_INFO.hider).color))
		var detail: String = "抓 %d 人" % int(r.get("captures", 0)) if r.get("role") == "hunter" else "修 %d · 救 %d%s" % [int(r.get("repairs", 0)), int(r.get("rescues", 0)), " · 存活" if r.get("survived", false) else ""]
		row.add_child(_label(detail, Vector2(350, 0), Vector2(320, 58), FS_SMALL, UiAssets.COLOR_MUTED))
		row.add_child(_label("%d 分%s" % [int(r.get("score", 0)), "  MVP" if r.get("mvp", false) else ""], Vector2(680, 0), Vector2(200, 58), FS_BODY, UiAssets.COLOR_GOLD))
		var minutes: int = int((Time.get_unix_time_from_system() * 1000.0 - float(r.get("at", 0))) / 60000.0)
		var ago: String = "刚刚" if minutes < 1 else ("%d 分钟前" % minutes if minutes < 60 else ("%d 小时前" % (minutes / 60) if minutes < 1440 else "%d 天前" % (minutes / 1440)))
		var when: Label = _label(ago, Vector2(900, 0), Vector2(230, 58), FS_SMALL, UiAssets.COLOR_MUTED)
		when.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(when)
		panel.add_child(row)

# ---------------------------------------------------------------- 23 每日任务

func _build_tasks() -> void:
	_header("每日任务", 6)
	_add(_label("每天 0 点（北京时间）刷新", Vector2(900, 40), Vector2(380, 30), FS_SMALL, UiAssets.COLOR_MUTED))
	if tasks_cache.is_empty():
		_add(_label("正在加载…", Vector2(0, 360), Vector2(1334, 40), FS_BODY, UiAssets.COLOR_MUTED, true))
		var response: Dictionary = await Api.get_json("/tasks")
		if response.get("ok", false) and Router.current == 23:
			tasks_cache = response
			show_page(23)
		return
	var tasks: Array = tasks_cache.get("tasks", [])
	for i: int in tasks.size():
		var t: Dictionary = tasks[i]
		var row: Panel = _panel(Vector2(120, 110 + i * 96), Vector2(1094, 86), "panel/panel_list_row")
		var goal: int = int(t.get("goal", 1))
		var progress: int = int(t.get("progress", 0))
		row.add_child(_label(str(t.get("name", "")), Vector2(30, 6), Vector2(420, 40), 22, UiAssets.COLOR_TEXT))
		row.add_child(_progress(Vector2(30, 50), Vector2(360, 22), float(progress) / goal))
		row.add_child(_label("%d / %d" % [progress, goal], Vector2(400, 44), Vector2(100, 32), FS_SMALL, UiAssets.COLOR_MUTED))
		var reward: Dictionary = t.get("reward", {})
		var rx: float = 560.0
		for kind: Array in [["coins", "icon/coin-icon"], ["gems", "icon/gem-icon"], ["exp", "icon/star-icon"]]:
			if int(reward.get(kind[0], 0)) > 0:
				row.add_child(UiAssets.picture(str(kind[1]), Vector2(rx, 24), Vector2(36, 36)))
				row.add_child(_label("+%d" % int(reward.get(kind[0], 0)), Vector2(rx + 40, 0), Vector2(80, 86), FS_BODY, UiAssets.COLOR_GOLD))
				rx += 130
		var done: bool = progress >= goal
		var claimed: bool = bool(t.get("claimed", false))
		var claim: Button = _button("已领取" if claimed else ("领取" if done else "未完成"), Vector2(900, 14), Vector2(168, 58), UiAssets.COLOR_GOLD if done and not claimed else Color("38345e"), 22)
		claim.disabled = claimed or not done
		var id: String = str(t.get("id", ""))
		claim.pressed.connect(func() -> void:
			var response: Dictionary = await Api.request("/tasks/claim", {"id": id})
			if response.get("ok", false):
				Session.user = response.user
				tasks_cache = {"tasks": response.tasks}
				show_toast("奖励已领取")
				show_page(23)
			else:
				show_toast(str(response.get("msg", "领取失败"))))
		row.add_child(claim)
		_add(row)

# ---------------------------------------------------------------- widgets

func _add(node: Control) -> void:
	active_page.add_child(node)

## Secondary-page header: back button (icon) and a large pixel-font title, top-left.
func _header(title: String, back_page: int, before_back: Callable = Callable()) -> void:
	var back: Button = _icon_button("icon/back-icon", Vector2(28, 22), Vector2(76, 68), Color("38345e"))
	back.pressed.connect(func() -> void:
		if before_back.is_valid(): before_back.call()
		Router.go(back_page))
	_add(back)
	_add(_title_label(title, Vector2(120, 18), Vector2(600, 76), FS_TITLE + 8, UiAssets.COLOR_GOLD))

func _panel(pos: Vector2, size: Vector2, art: String = "panel/panel_content_large") -> Panel:
	var panel: Panel = Panel.new()
	panel.position = pos
	panel.size = size
	panel.add_theme_stylebox_override("panel", UiAssets.tex_style(art, UiAssets.panel(), Vector2(28, 28), Vector2(20, 20)))
	return panel

func _button(text: String, pos: Vector2, size: Vector2, color: Color = UiAssets.COLOR_GOLD, font_size: int = FS_BUTTON, icon: String = "") -> Button:
	var b: Button = Button.new()
	b.text = text
	b.position = pos
	b.size = size
	var art: String = UiAssets.button_art(color)
	var flat: StyleBoxFlat = UiAssets.button(color)
	var pressed_art: String = art + "_pressed" if UiAssets.asset(art + "_pressed") else art
	b.add_theme_stylebox_override("normal", UiAssets.tex_style(art, flat))
	b.add_theme_stylebox_override("hover", UiAssets.tex_style(art, UiAssets.button(color.lightened(0.15)), Vector2(22, 14), Vector2(18, 6), Color(1.12, 1.12, 1.12)))
	b.add_theme_stylebox_override("pressed", UiAssets.tex_style(pressed_art, UiAssets.button(color.darkened(0.15)), Vector2(22, 14), Vector2(18, 6), Color(0.85, 0.85, 0.85)))
	b.add_theme_stylebox_override("disabled", UiAssets.tex_style(art, UiAssets.button(color.darkened(0.4)), Vector2(22, 14), Vector2(18, 6), Color(0.55, 0.55, 0.6, 0.75)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size", font_size)
	# Light art (yellow, green) takes dark text; dark art takes light text with an outline.
	var light: bool = color == UiAssets.COLOR_GOLD or color == UiAssets.COLOR_GREEN
	var text_color: Color = UiAssets.COLOR_DARK_TEXT if color == UiAssets.COLOR_GOLD else UiAssets.COLOR_TEXT
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(key, text_color)
	b.add_theme_color_override("font_disabled_color", text_color.darkened(0.3))
	if not light or color == UiAssets.COLOR_GREEN:
		b.add_theme_color_override("font_outline_color", Color("140e28"))
		b.add_theme_constant_override("outline_size", 5)
	if not icon.is_empty():
		var tex: Texture2D = UiAssets.asset(icon)
		if tex:
			b.icon = tex
			b.expand_icon = true
			b.add_theme_constant_override("icon_max_width", int(minf(size.y * 0.5, 40)))
			b.add_theme_constant_override("h_separation", 10)
	return b

func _icon_button(icon: String, pos: Vector2, size: Vector2, color: Color = Color("38345e")) -> Button:
	var b: Button = _button("", pos, size, color)
	var tex: Texture2D = UiAssets.asset(icon)
	if tex:
		b.icon = tex
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_constant_override("icon_max_width", int(minf(size.x, size.y) * 0.62))
	else:
		b.text = "‹" if "back" in icon else "·"
	return b

## Selectable card (map vote, avatar pick, ghost side) on the player-card frame art;
## the chosen one is lit gold.
func _card_button(pos: Vector2, size: Vector2, chosen: bool) -> Button:
	var b: Button = Button.new()
	b.position = pos
	b.size = size
	var tint: Color = Color(1.35, 1.1, 0.45) if chosen else Color.WHITE
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var t: Color = tint * (Color(1.12, 1.12, 1.12) if state == "hover" else (Color(0.85, 0.85, 0.85) if state == "pressed" else Color.WHITE))
		b.add_theme_stylebox_override(state, UiAssets.tex_style("panel/panel_player_card", UiAssets.panel(), Vector2(26, 26), Vector2(8, 8), t))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b

## Icon above a small caption, for the lobby's bottom navigation.
func _nav_button(text: String, icon: String, pos: Vector2, size: Vector2) -> Button:
	var b: Button = Button.new()
	b.flat = true
	b.position = pos
	b.size = size
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_child(UiAssets.picture(icon, Vector2((size.x - 48) / 2, 4), Vector2(48, 48)))
	b.add_child(_label(text, Vector2(0, 52), Vector2(size.x, 28), 18, UiAssets.COLOR_TEXT, true))
	return b

func _link_button(text: String, pos: Vector2, size: Vector2) -> Button:
	var b: Button = Button.new()
	b.flat = true
	b.text = text
	b.position = pos
	b.size = size
	b.add_theme_font_size_override("font_size", FS_SMALL)
	b.add_theme_color_override("font_color", Color("9fb6ff"))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b

func _label(text: String, pos: Vector2, size: Vector2, font_size: int, color: Color, centered: bool = false) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.position = pos
	l.size = size
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if centered:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color("0c0a1a"))
	l.add_theme_constant_override("outline_size", 4)
	return l

## Large pixel-font label for titles, timers and big numbers.
func _title_label(text: String, pos: Vector2, size: Vector2, font_size: int, color: Color, centered: bool = false) -> Label:
	var l: Label = _label(text, pos, size, font_size, color, centered)
	l.add_theme_font_override("font", UiAssets.pixel_font())
	l.add_theme_color_override("font_outline_color", Color("140e28"))
	l.add_theme_constant_override("outline_size", maxi(6, font_size / 6))
	return l

func _edit(placeholder: String, pos: Vector2, size: Vector2) -> LineEdit:
	var e: LineEdit = LineEdit.new()
	e.placeholder_text = placeholder
	e.position = pos
	e.size = size
	e.add_theme_font_size_override("font_size", 22)
	var style: StyleBox = UiAssets.tex_style("panel/panel_input_field", UiAssets.button(Color("3e376a")), Vector2(28, 20), Vector2(24, 8))
	e.add_theme_stylebox_override("normal", style)
	e.add_theme_stylebox_override("focus", UiAssets.tex_style("panel/panel_input_field", UiAssets.button(Color("5a4f95")), Vector2(28, 20), Vector2(24, 8), Color(1.15, 1.1, 1.3)))
	return e

func _field_icon(icon: String, pos: Vector2) -> TextureRect:
	return UiAssets.picture(icon, pos, Vector2(40, 40))

## Segmented choice row built from tab_active / tab_inactive art.
func _tabs(options: Array, selected: int, pos: Vector2, size: Vector2, on_pick: Callable) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.position = pos
	row.size = size
	row.add_theme_constant_override("separation", 8)
	var w: float = (size.x - 8 * (options.size() - 1)) / options.size()
	for i: int in options.size():
		var active: bool = i == selected
		var t: Button = Button.new()
		t.text = str(options[i])
		t.custom_minimum_size = Vector2(w, size.y)
		var art: String = "button/tab_active" if active else "button/tab_inactive"
		for state: String in ["normal", "hover", "pressed"]:
			t.add_theme_stylebox_override(state, UiAssets.tex_style(art, UiAssets.button(UiAssets.COLOR_GOLD if active else Color("2c2552")), Vector2(20, 16), Vector2(8, 4), Color(1.1, 1.1, 1.1) if state == "hover" else Color.WHITE))
		t.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		t.add_theme_font_size_override("font_size", 22)
		var c: Color = UiAssets.COLOR_DARK_TEXT if active else UiAssets.COLOR_TEXT
		for key: String in ["font_color", "font_hover_color", "font_pressed_color"]:
			t.add_theme_color_override(key, c)
		t.pressed.connect(func() -> void: on_pick.call(i))
		row.add_child(t)
	return row

func _toggle(pos: Vector2, value: bool, on_change: Callable) -> Control:
	var on: Texture2D = UiAssets.asset("button/toggle_on")
	var off: Texture2D = UiAssets.asset("button/toggle_off")
	if on == null or off == null:
		var check: CheckButton = CheckButton.new()
		check.position = pos
		check.button_pressed = value
		check.toggled.connect(func(v: bool) -> void: on_change.call(v))
		return check
	var t: TextureButton = TextureButton.new()
	t.toggle_mode = true
	t.texture_normal = off
	t.texture_pressed = on
	t.ignore_texture_size = true
	t.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	t.position = pos - Vector2(4, 2)
	t.size = Vector2(92, 46)
	t.button_pressed = value
	var state: Label = Label.new()
	state.size = Vector2(46, 46)
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	state.add_theme_font_size_override("font_size", 16)
	state.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paint: Callable = func(on: bool) -> void:
		state.text = "开" if on else "关"
		state.position = Vector2(4, 0) if on else Vector2(44, 0)
		state.add_theme_color_override("font_color", UiAssets.COLOR_DARK_TEXT if on else UiAssets.COLOR_TEXT)
	paint.call(value)
	t.toggled.connect(paint)
	t.add_child(state)
	t.toggled.connect(func(v: bool) -> void: on_change.call(v))
	return t

func _slider(pos: Vector2, size: Vector2, value: float, on_change: Callable) -> HSlider:
	var s: HSlider = HSlider.new()
	s.position = pos
	s.size = size
	s.min_value = 0
	s.max_value = 100
	s.value = value
	s.add_theme_stylebox_override("slider", UiAssets.tex_style("button/slider_track", UiAssets.button(Color("2c2552")), Vector2(12, 6), Vector2(0, 5)))
	s.add_theme_stylebox_override("grabber_area", UiAssets.tex_style("button/slider_fill", UiAssets.button(UiAssets.COLOR_GOLD), Vector2(12, 6), Vector2(0, 5)))
	s.add_theme_stylebox_override("grabber_area_highlight", UiAssets.tex_style("button/slider_fill", UiAssets.button(UiAssets.COLOR_GOLD), Vector2(12, 6), Vector2(0, 5)))
	var knob: Texture2D = _scaled_icon("button/slider_knob", 30)
	if knob:
		s.add_theme_icon_override("grabber", knob)
		s.add_theme_icon_override("grabber_highlight", knob)
	s.value_changed.connect(func(v: float) -> void: on_change.call(v))
	return s

func _progress(pos: Vector2, size: Vector2, ratio: float) -> Control:
	var frame: Panel = Panel.new()
	frame.position = pos
	frame.size = size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", UiAssets.tex_style("button/progress_bar_frame", UiAssets.button(Color("2c2552")), Vector2(14, 8), Vector2.ZERO))
	var fill: Panel = Panel.new()
	fill.position = Vector2(4, 4)
	fill.size = Vector2(maxf(0, (size.x - 8) * clampf(ratio, 0, 1)), size.y - 8)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.add_theme_stylebox_override("panel", UiAssets.tex_style("button/progress_bar_fill", UiAssets.button(UiAssets.COLOR_GOLD), Vector2(10, 4), Vector2.ZERO))
	frame.add_child(fill)
	return frame

## Icon + value chip on the top resource bar art (coins, gems, rewards).
func _resource_chip(icon: String, text: String, pos: Vector2, size: Vector2 = Vector2(200, 60)) -> Control:
	var chip: Panel = _panel(pos, size, "panel/panel_top_resource_bar")
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(UiAssets.picture(icon, Vector2(10, (size.y - 40) / 2), Vector2(40, 40)))
	chip.add_child(_label(text, Vector2(56, 0), Vector2(size.x - 66, size.y), 22, UiAssets.COLOR_TEXT, true))
	return chip

## Full-body standing hider (T6 idle frame, pajama-only tint, equipped hat) at `height` px tall.
func _sprite_figure(color: String, pos: Vector2, height: float) -> Control:
	var look: Dictionary = Session.user.get("look", {}) if Session.user.get("look") is Dictionary else {}
	return CharacterArt.figure(color, str(look.get("hat", "nightcap")), pos, height)

## Warm elliptical spotlight on the floor under a standing figure (05 / 06).
func _floor_glow(center: Vector2, size: Vector2) -> TextureRect:
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(1.0, 0.8, 0.35, 0.55))
	gradient.set_color(1, Color(1.0, 0.8, 0.35, 0.0))
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 64
	var rect: TextureRect = TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.position = center - size / 2
	rect.size = size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

## Section title inside a panel: small icon + gold caption at the panel's top-left.
func _section_title(parent: Control, text: String, icon: String = "") -> void:
	var x: float = 32.0
	if not icon.is_empty() and UiAssets.asset(icon):
		parent.add_child(UiAssets.picture(icon, Vector2(30, 26), Vector2(30, 30)))
		x = 70.0
	parent.add_child(_label(text, Vector2(x, 24), Vector2(320, 34), 24, UiAssets.COLOR_GOLD))

## A texture resized to `px` square (theme icons ignore control size).
func _scaled_icon(filename: String, px: int) -> Texture2D:
	var tex: Texture2D = UiAssets.asset(filename)
	if tex == null: return null
	var img: Image = tex.get_image()
	if img.is_compressed(): img.decompress()
	img = img.get_region(Rect2i(UiAssets.used_rect(filename)))
	img.resize(px, px, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)

func show_toast(text: String) -> void:
	for child: Node in toast_layer.get_children(): child.queue_free()
	var box: Panel = _panel(Vector2(347, 626), Vector2(640, 64), "panel/panel_toast")
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label: Label = _label(text, Vector2(10, 0), Vector2(620, 64), FS_BODY, UiAssets.COLOR_TEXT, true)
	label.name = "ToastText"
	box.add_child(label)
	toast_layer.add_child(box)
	# Bound to the box itself so the connection dies with it (no freed-lambda capture).
	get_tree().create_timer(2.5).timeout.connect(box.queue_free)

func _on_net_status(text: String) -> void:
	if not text.is_empty():
		show_toast(text)
		return
	# Connected: drop any lingering "connecting…" toast right away.
	for child: Node in toast_layer.get_children():
		var label: Label = child.find_child("ToastText", true, false) as Label
		if label and "连接" in label.text:
			child.queue_free()

func _on_session_update(type: String) -> void:
	# In-match pages read Session live every frame; rebuilding them would reset the HUD.
	var in_match: bool = Router.current in [13, 14, 15, 16]
	if type in ["room.state", "game.phase", "match.status", "vote.update", "game.event"] and Router.current > 0 and not in_match:
		show_page(Router.current)
	if type == "vote.start":
		my_vote = -1
	if type == "game.caught" and str(Session.last_caught.get("victimId", "")) == str(Session.user.get("id", "")):
		Router.go(15)

func save_debug_shot(name: String) -> void:
	if screenshot_done: return
	await get_tree().process_frame
	RenderingServer.force_draw(false)
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
	# "13" or "13-night_mall": page number, optionally the map to load for in-match pages.
	var page: int = int(name.get_slice("-", 0))
	var map_id: String = name.get_slice("-", 1) if "-" in name else "old_dorm"
	Session.user = {"id":"demo", "shortId":"10238471", "nickname":"小夜猫", "level":8, "exp":62, "color":"blue", "coins":1280, "gems":60, "look":{"hat":"cat", "footprint":"paw", "effect":"sparkle"}, "bindings":{"wechat":true, "phone":null}}
	Session.consent = true
	var players: Array[Dictionary] = []
	for i: int in 8:
		players.append({"id":"demo" if i == 0 else "bot_%d" % i, "nickname":"小夜猫" if i == 0 else "AI-%d" % i, "color":UiAssets.HIDER_COLORS[(i + 5) % 8], "ready":i != 0, "isHost":i == 0, "isBot":i != 0})
	Session.room = {"code":"483921", "hostId":"demo", "players":players, "phase":"waiting", "settings":room_settings}
	Session.match_status = {"elapsedSec":65, "found":8, "needed":12, "canAiFill":true}
	Session.vote = {"maps":["old_dorm","night_hospital","night_mall"], "available":["old_dorm"], "counts":{"old_dorm":5}, "voters":["bot_1","bot_2","bot_3","bot_5","bot_6"], "endsAt":Net.now_ms() + 8000}
	join_code = "6281"
	if page == 1:
		notice = {"title":"宿舍公告", "body":"欢迎来到熄灯！
躲好，今晚一起开局！"}
	Session.game = {"you":{"id":"demo", "role":"hunter" if page == 14 else "hider"}}
	if page in [13, 14, 16]:
		# The real 旧宿舍楼 map (exported from the server's wireMap) so shots show furniture and decor.
		var map: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/%s_map.json" % map_id))
		Session.game = {"mapId":map_id, "you":{"id":"demo", "role":"hunter" if page == 14 else "hider"}, "players":[{"id":"demo", "color":"blue", "nickname":"小夜猫"}], "map":map}
		var spawns: Array = map.get("hiderSpawns", [])
		var at: Vector2 = Vector2(float(map.hunterSpawn.x), float(map.hunterSpawn.y)) if page == 14 else (Vector2(12.5, 6.2) if map_id == "old_dorm" else Vector2(float(spawns[0].x), float(spawns[0].y)))
		var roster: Array = []
		for i: int in 9:
			roster.append({"color":UiAssets.HIDER_COLORS[(i + 5) % 8], "caught":i >= 7})
		var gens: Array = []
		for g: Dictionary in map.generators:
			gens.append({"id":g.id, "x":g.x, "y":g.y, "progress":0.4 if int(g.id) == 0 else 0.0, "fixed":false})
		Session.snap = {"you":{"x":at.x,"y":at.y,"state":"normal","visionRadius":5.0,"stamina":3.0,"items":["smoke","banana"],"flashlight":true},"players":[],"alive":7,"totalHiders":9,"roster":roster,"nextEventAt":Net.now_ms() + 12000,"generators":gens}
		Session.phase = "final" if page == 16 else "hunt"
		Session.phase_ends = Net.now_ms() + (28000.0 if page == 16 else 402000.0)
		if page == 16:
			Session.event = {"kind":"blackout", "stage":"warn", "at":Net.now_ms() + 5000}
	if page in [20, 21]:
		var items: Array = []
		var catalog: Array = [["hat","nightcap","蓝色睡帽",0,"coins"],["hat","cat","猫耳帽",800,"coins"],["hat","bear","小熊帽",800,"coins"],["hat","dino","恐龙帽",1200,"coins"],["hat","bunny","兔耳帽",1200,"coins"],["hat","fox","狐狸帽",1500,"coins"],["hat","pumpkin","南瓜帽",60,"gems"],["hat","crown","小皇冠",200,"gems"],
			["footprint","plain","普通脚印",0,"coins"],["footprint","paw","猫爪脚印",600,"coins"],["footprint","star","星星脚印",900,"coins"],["effect","poof","烟雾变身",0,"coins"],["effect","sparkle","星光变身",1000,"coins"]]
		for c: Array in catalog:
			items.append({"slot":c[0],"id":c[1],"name":c[2],"price":c[3],"currency":c[4],"owned":c[3] == 0 or c[1] in ["cat","paw","sparkle"],"rare":c[1] == "crown"})
		shop_cache = {"ok":true,"items":items}
	if page == 22:
		var now: float = Time.get_unix_time_from_system() * 1000.0
		records_cache = {"stats":{"games":23,"wins":13,"captures":9,"rescues":7,"repairs":18,"mvp":4},"records":[
			{"mapId":"night_hospital","role":"hider","win":true,"score":390,"captures":0,"repairs":2,"rescues":1,"survived":true,"mvp":true,"at":now-600000},
			{"mapId":"old_dorm","role":"hunter","win":false,"score":210,"captures":3,"at":now-3600000},
			{"mapId":"snow_lodge","role":"hider","win":false,"score":120,"repairs":1,"rescues":0,"at":now-7200000},
			{"mapId":"midnight_cruise","role":"hider","win":true,"score":330,"repairs":1,"rescues":2,"survived":true,"at":now-90000000}]}
	if page == 23:
		tasks_cache = {"tasks":[{"id":"play","name":"完成 3 局对局","goal":3,"progress":3,"reward":{"coins":100},"claimed":false},{"id":"win","name":"赢下 1 局","goal":1,"progress":1,"reward":{"coins":80,"exp":30},"claimed":true},
			{"id":"repair","name":"修好 2 台发电机","goal":2,"progress":1,"reward":{"coins":60},"claimed":false},{"id":"rescue","name":"救出 1 名队友","goal":1,"progress":0,"reward":{"coins":60},"claimed":false},
			{"id":"catch","name":"作为猎手抓到 3 人","goal":3,"progress":2,"reward":{"coins":80},"claimed":false},{"id":"survive","name":"作为藏者存活到结束","goal":1,"progress":0,"reward":{"gems":5},"claimed":false}]}
	if page == 17:
		Session.result = {"winner":"hider","players":[{"id":"demo","nickname":"小夜猫","color":"blue","role":"hider","score":390,"caught":false,"breakdown":[{"label":"存活到结束","pts":100},{"label":"存活分钟","pts":150},{"label":"修理发电机","pts":80},{"label":"解救队友","pts":60}]},{"id":"hunter","nickname":"夜巡者","role":"hunter","score":250,"caught":false}],"mvp":{"hider":"demo","hunter":"hunter"},"rewards":{"exp":200,"coins":120,"rankDelta":18}}
	show_page(page)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.8).timeout
	save_debug_shot(name)

# Player portrait from 06-头像: hider colour for people, robot for AI, silhouette for an
# empty seat. `p.avatar` overrides the choice (e.g. the hunter warden on the result page).
func _avatar(p: Dictionary, pos: Vector2, size: float) -> Control:
	var name: String = "avatar-empty-slot"
	if p.has("avatar"):
		name = str(p.avatar)
	elif not p.is_empty():
		name = "avatar-ai-bot" if p.get("isBot", false) else "avatar-hider-" + str(p.get("color", "blue"))
	return UiAssets.picture("avatar/" + name, pos, Vector2(size, size))
