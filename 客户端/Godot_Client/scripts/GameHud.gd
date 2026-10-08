class_name GameHud
extends Control

var world: GameWorld
var joystick: Vector2 = Vector2.ZERO
var joystick_id: int = -99
var skill_id: int = -99
var wheel_open: bool = false
var wheel_index: int = 0
var wheel_choices: Array[String] = []
var main_held: bool = false
var skill_button: Button
var main_button: Button
var item_buttons: Array[Button] = []
var accuse: Button
var timer_label: Label
var state_label: Label
var alive_button: Button
var ghost_panel: Panel
var ghost_label: Label
var event_label: Label
var hide_label: Label
var spectate_button: Button
var info_label: Label
var listed: bool = false
var listed_panel: Panel
var font: Font
var marks_panel: Panel
var last_state: String = ""
var item_aim: int = -1
var aim_origin: Vector2 = Vector2.ZERO
var aim_direction: Vector2 = Vector2.RIGHT
var explored: Dictionary = {}
var exit_armed_until: int = 0
# "下次事件 Ns" chip left of the minimap, hidden while an event banner is showing.
var next_event_label: Label
# Push-to-talk for 近距离语音 (visible only when the room enables voice).
var talk_button: Button
var final_label: Label
var warn_strip: Label
const NEXT_EVENT_RECT: Rect2 = Rect2(806,22,226,64)
# Whole-map minimap (structure outline), rebuilt once per match.
var minimap_tex: ImageTexture
var hunt_seen_ms: int = -1
var pause_panel: Panel
# Dark rounded backing for small captions over the scene (button names, hints).
static func caption_style() -> StyleBoxFlat:
	var st: StyleBoxFlat = StyleBoxFlat.new()
	st.bg_color = Color(0.05, 0.04, 0.12, 0.72)
	st.set_corner_radius_all(8)
	st.content_margin_left = 8
	st.content_margin_right = 8
	st.content_margin_top = 2
	st.content_margin_bottom = 2
	return st

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = load("res://assets/fonts/NotoSansSC-Regular.otf")
	_build()

func joy_center() -> Vector2:
	return Vector2(1160,610) if Config.settings.left_hand else Vector2(145,610)

func mirror(point: Vector2, extent: Vector2 = Vector2.ZERO) -> Vector2:
	return Vector2(1334-point.x-extent.x,point.y) if Config.settings.left_hand else point

func _build() -> void:
	alive_button = _button("存活",Vector2(25,18),Vector2(330,92),Color("786abe"))
	# The counter art and survivor dots are drawn in _draw (behind the button text), so the
	# button itself is transparent; the text starts right of the art's people icon.
	var clear: StyleBoxEmpty = StyleBoxEmpty.new()
	clear.content_margin_left = 18
	clear.content_margin_bottom = 40
	for s: String in ["normal","hover","pressed"]:
		alive_button.add_theme_stylebox_override(s,clear)
	alive_button.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	alive_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	alive_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	alive_button.add_theme_font_size_override("font_size",22)
	alive_button.pressed.connect(_toggle_list)
	timer_label = _label("05:00",Vector2(547,20),Vector2(240,70),40)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	event_label = _label("",Vector2(487,102),Vector2(360,56),26)
	event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	event_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	event_label.add_theme_color_override("font_color",Color("ffe3e3"))
	event_label.add_theme_color_override("font_outline_color",Color("3a0610"))
	event_label.add_theme_constant_override("outline_size",6)
	state_label = _label("",Vector2(30,118),Vector2(450,40),18)
	state_label.add_theme_stylebox_override("normal",caption_style())
	state_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	final_label = _label("",Vector2(567,94),Vector2(200,30),20)
	final_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	final_label.add_theme_color_override("font_color",Color("ff6b6b"))
	final_label.add_theme_color_override("font_outline_color",Color("2a0508"))
	final_label.add_theme_constant_override("outline_size",6)
	warn_strip = _label("",Vector2(367,590),Vector2(600,46),22)
	warn_strip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn_strip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	warn_strip.add_theme_color_override("font_color",Color("ffe3e3"))
	next_event_label = _label("",NEXT_EVENT_RECT.position+Vector2(18,6),Vector2(196,30),18)
	info_label = _label("",Vector2(335,660),Vector2(660,44),18)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	main_button = _button("交互\nSpace",mirror(Vector2(1160,565),Vector2(125,125)),Vector2(125,125),UiAssets.COLOR_GOLD)
	main_button.button_down.connect(func() -> void: _main(true))
	main_button.button_up.connect(func() -> void: _main(false))
	skill_button = _button("伪装\nQ",mirror(Vector2(1090,440),Vector2(100,100)),Vector2(100,100),UiAssets.COLOR_GOLD)
	skill_button.button_down.connect(_skill_down)
	skill_button.button_up.connect(_skill_up)
	for i: int in 2:
		var button: Button = _button("空\n%d"%(i+1),mirror(Vector2(1000,545+i*102),Vector2(84,84)),Vector2(84,84),Color("5a9df6"))
		button.button_down.connect(func() -> void:
			item_aim = i
			aim_origin = get_local_mouse_position()
			aim_direction = world.direction.normalized() if is_instance_valid(world) and world.direction.length() > 0 else Vector2.RIGHT)
		button.button_up.connect(func() -> void: _use_item(i))
		item_buttons.append(button)
	accuse = _button("指认\n按住 F",mirror(Vector2(1210,423),Vector2(92,92)),Vector2(92,92),Color("aa7ced"))
	accuse.button_down.connect(func() -> void: _accuse(true))
	accuse.button_up.connect(func() -> void: _accuse(false))
	talk_button = _button("按住说话",Vector2(28,256),Vector2(118,52),Color("4b5fae"))
	talk_button.icon = UiAssets.asset("icon/mic-icon")
	talk_button.expand_icon = true
	talk_button.add_theme_constant_override("icon_max_width",24)
	talk_button.button_down.connect(func() -> void: Voice.start_talking(); talk_button.text = "说话中…")
	talk_button.button_up.connect(func() -> void: Voice.stop_talking(); talk_button.text = "按住说话")
	spectate_button = _button("切换观战",Vector2(550,585),Vector2(230,58),Color("869bde"))
	spectate_button.pressed.connect(_spectate)
	spectate_button.visible = false
	var pause: Button = _button("",Vector2(1046,24),Vector2(58,58),Color("38345e"))
	for st: String in ["normal","hover","pressed"]:
		pause.add_theme_stylebox_override(st,UiAssets.tex_style("button/button_round_icon",UiAssets.button(Color("38345e")),Vector2(14,14),Vector2(6,6),Color(0.8,0.8,0.8) if st == "pressed" else Color.WHITE))
	pause.text = "II"
	pause.add_theme_font_size_override("font_size",22)
	pause.pressed.connect(_toggle_pause)
	var mini: Button = Button.new()
	mini.flat = true
	mini.position = Vector2(1114,18)
	mini.size = Vector2(192,136)
	mini.pressed.connect(_mark_menu)
	add_child(mini)
	ghost_panel = Panel.new()
	ghost_panel.position = Vector2(385,210)
	ghost_panel.size = Vector2(565,305)
	ghost_panel.add_theme_stylebox_override("panel",UiAssets.panel())
	add_child(ghost_panel)
	ghost_label = _label("选择幽灵阵营 · 10s",Vector2(410,230),Vector2(515,55),28)
	ghost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for i: int in 2:
		var b: Button = _button("守护灵\n制造假波纹" if i == 0 else "怨灵\n标记可见藏者",Vector2(415+i*260,312),Vector2(245,148),Color("729bff") if i == 0 else Color("b977db"))
		b.name = "Ghost%d"%i
		b.pressed.connect(func() -> void: Net.send("game.ghostSide",{"side":"guardian" if i == 0 else "wraith"}))
	ghost_panel.visible = false
	hide_label = _label("猎手准备中",Vector2(345,295),Vector2(645,100),32)
	hide_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hide_label.visible = false

# HUD art from 素材/UI拆分资产/11-HUD控件. A skinned button draws its texture as the whole
# background and moves its text into a small caption at the bottom; without the texture
# the flat fallback style and inline text stay as they were.
var captions: Dictionary = {}

func _skin(b: Button, asset_name: String) -> void:
	if b.get_meta("skin", "") == asset_name:
		return
	var tex: Texture2D = UiAssets.asset("hud/" + asset_name)
	if tex == null:
		return
	b.set_meta("skin", asset_name)
	for style: String in ["normal", "hover", "pressed", "disabled"]:
		var box: StyleBoxTexture = StyleBoxTexture.new()
		box.texture = tex
		box.modulate_color = {"pressed": Color(0.72, 0.72, 0.72), "disabled": Color(1, 1, 1, 0.45)}.get(style, Color.WHITE)
		b.add_theme_stylebox_override(style, box)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if not captions.has(b):
		var cap: Label = Label.new()
		cap.position = Vector2(0, b.size.y - 24)
		cap.size = Vector2(b.size.x, 22)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cap.add_theme_font_size_override("font_size", 14)
		cap.add_theme_color_override("font_color", UiAssets.COLOR_TEXT)
		cap.add_theme_color_override("font_outline_color", Color("0c0a1a"))
		cap.add_theme_constant_override("outline_size", 4)
		cap.add_theme_stylebox_override("normal", caption_style())
		cap.position = Vector2(b.size.x / 2 - 36, b.size.y - 14)
		cap.size = Vector2(72, 24)
		b.add_child(cap)
		captions[b] = cap
	b.text = ""

func _caption(b: Button, text: String) -> void:
	if captions.has(b):
		(captions[b] as Label).text = text.split("\n")[0]
	else:
		b.text = text

func _process(_delta: float) -> void:
	if not is_instance_valid(world):
		return
	_skin_hud()
	var me: Dictionary = Session.me()
	var state: String = str(me.get("state","normal"))
	var ghost: bool = state == "ghost"
	var hunter: bool = Session.role() == "hunter"
	var time_left: float = maxf(0,(Session.phase_ends-Net.now_ms())/1000.0)
	timer_label.text = "%02d:%02d"%[int(time_left)/60,int(time_left)%60]
	var final: bool = Session.phase == "final"
	timer_label.add_theme_color_override("font_color",UiAssets.COLOR_RED if final else UiAssets.COLOR_TEXT)
	timer_label.add_theme_font_size_override("font_size",48 if final else 40)
	var roster: Array = Session.snap.get("roster",[])
	if roster.is_empty():
		alive_button.text = "存活 %d / %d"%[int(Session.snap.get("alive",0)),int(Session.snap.get("totalHiders",0))]
	else:
		alive_button.text = "存活 %d / %d"%[roster.filter(func(r: Dictionary) -> bool: return not r.get("caught",false)).size(),roster.size()]
	if Session.phase in ["hunt","final"] and hunt_seen_ms < 0:
		hunt_seen_ms = Time.get_ticks_msec()
	var early: bool = Session.phase == "hide" or (hunt_seen_ms >= 0 and Time.get_ticks_msec() - hunt_seen_ms < 20000)
	state_label.text = "已抓 %d 人 · 手电 %s"%[int(Session.snap.get("caughtByMe",0)),"开" if me.get("flashlight",true) else "关"] if hunter else ("幽灵 · " + ("怨灵" if me.get("ghostSide") == "wraith" else "守护灵") if ghost else ("藏者 · 轻推走路，推到外圈奔跑" if early else ""))
	state_label.visible = not state_label.text.is_empty()
	state_label.size = Vector2(state_label.get_minimum_size().x, 40)
	var final_now: bool = Session.phase == "final"
	final_label.text = "最终 30 秒" if final_now and event_label.text.is_empty() else ""
	warn_strip.text = ("猎手加速！小心心跳波纹！" if not hunter else "最终 30 秒：你的速度提高 20%！") if final_now else ""
	_caption(main_button, "拍打\nSpace" if hunter else "交互\nSpace")
	main_button.visible = not ghost
	_caption(skill_button, "技能 %.0fs"%float(me.get("cooldowns",{}).get("ghostSkill",0)) if ghost else ("手电\nQ" if hunter else ("解除伪装\nQ" if state == "disguised" else "伪装\n按住 Q")))
	var target: String = _nearest_target()
	accuse.visible = not ghost and not hunter and not target.is_empty()
	if Session.role() == "mole":
		_caption(accuse, "报点\nF")
	spectate_button.visible = ghost
	talk_button.visible = Voice.available()
	var choose: bool = state == "caged" and me.get("ghostSide") == null
	ghost_panel.visible = choose
	ghost_label.visible = choose
	get_node("Ghost0").visible = choose
	get_node("Ghost1").visible = choose
	ghost_label.text = "选择幽灵阵营 · %ds"%maxi(0,ceili((float(me.get("ghostChoiceEndsAt",Net.now_ms()+10000))-Net.now_ms())/1000))
	hide_label.visible = hunter and Session.phase == "hide"
	hide_label.text = "请等待藏者躲好\n%d 秒后开始追捕"%ceili(time_left)
	var items: Array = me.get("items",[null,null])
	for i: int in item_buttons.size():
		item_buttons[i].visible = not ghost
		var item: String = str(items[i]) if i < items.size() and items[i] != null else ""
		_caption(item_buttons[i], _item_name(item) if not item.is_empty() else "")
		item_buttons[i].disabled = item.is_empty()
		var key: String = "item/"+("item-hunter-" if hunter else "item-hider-")+item.replace("_","-")
		item_buttons[i].icon = UiAssets.asset(key) if not item.is_empty() else null
		item_buttons[i].expand_icon = true
		item_buttons[i].icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_buttons[i].vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		item_buttons[i].add_theme_constant_override("icon_max_width",50)
	info_label.text = ""
	if me.get("progress") is Dictionary:
		info_label.text = {"repair":"修理发电机", "rescue":"解救队友", "accuse":"指认目标"}.get(me.progress.kind,"交互")+"  %d%%"%int(float(me.progress.value)*100)
	elif state == "disguised":
		info_label.text = "已伪装，移动将解除"
	elif not Net.connected and not Config.demo:
		info_label.text = "连接中断，正在重连…"
	else:
		# Standing on an elevator / escalator / stairs / hatch: the ride starts after its delay.
		var cell: Vector2i = Vector2i(world.local_position.floor())
		for portal: Dictionary in world.map.get("portals", []):
			if int(portal.x) == cell.x and int(portal.y) == cell.y and state != "ghost":
				info_label.text = {"elevator":"电梯运行中… 站稳别动","escalator":"乘扶梯换层…","stairs":"走楼梯换层…","hatch":"爬舱口梯…"}.get(str(portal.kind), "传送中…")
	# Snowfield cold: speed loss shown with a frosty hint.
	var cold: float = float(me.get("cold", 0))
	if cold > 0.01 and info_label.text.is_empty():
		info_label.text = "好冷！速度 -%d%%，回室内取暖" % int(cold * 100)
	var event: Dictionary = Session.event
	event_label.text = ""
	if not event.is_empty() and event.get("stage") != "end":
		var names: Dictionary = {"blackout":"全楼停电","emergency_light":"应急灯","adrenaline":"肾上腺素","broadcast":"广播点名"}
		var seconds: int = maxi(0,ceili((float(event.get("at",Net.now_ms()))-Net.now_ms())/1000))
		event_label.text = str(names.get(event.get("kind"),"事件"))+("  %ds"%seconds if event.get("stage") == "warn" else "  生效中")
	# Map events (ship tilt, blizzard) share the banner when no shared event is showing.
	var map_event: Dictionary = Session.snap.get("mapEvent") if Session.snap.get("mapEvent") is Dictionary else {}
	if event_label.text.is_empty() and not map_event.is_empty():
		var map_names: Dictionary = {"ship_tilt":"船身倾斜","blizzard":"暴风雪"}
		var left: int = maxi(0,ceili((float(map_event.get("at",Net.now_ms()))-Net.now_ms())/1000))
		event_label.text = str(map_names.get(map_event.get("kind"),"地图事件"))+("  %ds"%left if map_event.get("stage") == "warn" else "  生效中")
	var next_at: float = float(Session.snap.get("nextEventAt",0))
	next_event_label.visible = event_label.text.is_empty() and next_at > Net.now_ms() and Session.phase in ["hunt","final"]
	next_event_label.text = "下次事件  %ds"%ceili((next_at-Net.now_ms())/1000.0)
	var keyboard: Vector2 = Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
	world.direction = joystick if joystick_id != -99 else keyboard.normalized()
	if Config.autoplay:
		world.direction = Config.autoplay_dir
	world.run = joystick.length() > 0.72 if joystick_id != -99 else Input.is_physical_key_pressed(KEY_SHIFT)
	var p: Vector2i = Vector2i(world.local_position)
	for y: int in range(p.y-5,p.y+6):
		for x: int in range(p.x-5,p.x+6):
			explored[Vector2i(x,y)] = true
	if state != last_state and ghost:
		Router.toast("你已成为幽灵，仍然可以移动和使用技能")
	last_state = state
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not is_instance_valid(world):
		return
	if event is InputEventKey and not event.echo:
		match event.physical_keycode:
			KEY_SPACE: _main(event.pressed)
			KEY_Q:
				if event.pressed: _skill_down()
				else: _skill_up()
			KEY_1:
				if event.pressed: _use_item(0)
			KEY_2:
				if event.pressed: _use_item(1)
			KEY_F: _accuse(event.pressed)
			KEY_V:
				if event.pressed: Voice.start_talking()
				else: Voice.stop_talking()
		return
	var pos: Vector2
	var id: int = -1
	var pressed: bool = false
	var released: bool = false
	var moving: bool = false
	if event is InputEventScreenTouch:
		pos = get_global_transform_with_canvas().affine_inverse()*event.position
		id = event.index
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventScreenDrag:
		pos = get_global_transform_with_canvas().affine_inverse()*event.position
		id = event.index
		moving = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pos = get_local_mouse_position()
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventMouseMotion:
		pos = get_local_mouse_position()
		moving = true
	else:
		return
	if pressed and pos.distance_to(joy_center()) < 105 and joystick_id == -99:
		joystick_id = id
	if id == joystick_id:
		joystick = ((pos-joy_center())/80).limit_length(1.0)
		if released:
			joystick = Vector2.ZERO
			joystick_id = -99
	if wheel_open and (moving or released):
		var relative: Vector2 = pos-mirror(Vector2(1110,345))
		if relative.length()>18 and not wheel_choices.is_empty():
			wheel_index = posmod(int(round(relative.angle()/TAU*wheel_choices.size())),wheel_choices.size())
	if item_aim >= 0 and moving and (pos-aim_origin).length()>12:
		aim_direction = (pos-aim_origin).normalized()

func _main(pressed: bool) -> void:
	main_held = pressed
	if Session.role() == "hunter":
		if pressed:
			Net.action("slap")
			if is_instance_valid(world): world.slap_until = Time.get_ticks_msec() + 300
	else:
		Net.action("interact_start" if pressed else "interact_stop")

func _skill_down() -> void:
	var me: Dictionary = Session.me()
	if me.get("state") == "ghost":
		var target: String = _nearest_target(100)
		Net.action("ghost_skill",{"x":world.local_position.x+2,"y":world.local_position.y,"targetId":target})
	elif Session.role() == "hunter":
		Net.action("flashlight")
	elif me.get("state") == "disguised":
		Net.action("undisguise")
	else:
		wheel_choices.clear()
		for prop: Dictionary in world.map.get("props",[]):
			if world.local_position.distance_to(Vector2(float(prop.x),float(prop.y))) <= 2.0 and not wheel_choices.has(str(prop.prop)):
				wheel_choices.append(str(prop.prop))
		if wheel_choices.is_empty():
			Router.toast("靠近纸箱、椅子等物件后可以伪装")
			return
		wheel_index = 0
		wheel_open = true

func _skill_up() -> void:
	if wheel_open and not wheel_choices.is_empty():
		Net.action("disguise",{"prop":wheel_choices[wheel_index]})
	wheel_open = false

func _use_item(slot: int) -> void:
	Net.action("use_item",{"slot":slot,"dx":aim_direction.x,"dy":aim_direction.y})
	item_aim = -1

func _accuse(pressed: bool) -> void:
	var target: String = _nearest_target()
	if Session.role() == "mole":
		if pressed: Net.action("report",{"targetId":target})
	else:
		Net.action("accuse_start" if pressed else "accuse_stop",{"targetId":target})

func _nearest_target(limit: float = 2.0) -> String:
	var target: String = ""
	for p: Dictionary in Session.snap.get("players",[]):
		var distance: float = world.local_position.distance_to(Vector2(float(p.x),float(p.y)))
		if distance <= limit and p.get("state") != "ghost":
			limit = distance
			target = str(p.id)
	return target

func _spectate() -> void:
	var ids: Array[String] = [""]
	for p: Dictionary in Session.snap.get("players",[]):
		ids.append(str(p.id))
	world.spectating = ids[(ids.find(world.spectating)+1)%ids.size()]
	Router.toast("观战可见队友" if not world.spectating.is_empty() else "返回自身视角")

## Pause menu: resume, or leave the match (a second, explicit button; leaving costs credit).
func _toggle_pause() -> void:
	if is_instance_valid(pause_panel):
		pause_panel.queue_free()
		return
	pause_panel = Panel.new()
	pause_panel.position = Vector2(517,230)
	pause_panel.size = Vector2(300,250)
	pause_panel.add_theme_stylebox_override("panel",UiAssets.tex_style("panel/panel_modal",UiAssets.panel(),Vector2(24,24),Vector2.ZERO))
	add_child(pause_panel)
	var title: Label = Label.new()
	title.text = "暂停菜单"
	title.position = Vector2(0,22)
	title.size = Vector2(300,40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size",26)
	title.add_theme_color_override("font_color",UiAssets.COLOR_GOLD)
	pause_panel.add_child(title)
	for i: int in 2:
		var b: Button = Button.new()
		b.text = "继续游戏" if i == 0 else "退出本局（扣信誉分）"
		b.position = Vector2(30,80+i*80)
		b.size = Vector2(240,62)
		b.add_theme_font_size_override("font_size",20 if i == 0 else 17)
		var art: String = "button/button_primary_yellow" if i == 0 else "button/button_danger_red"
		for st: String in ["normal","hover","pressed"]:
			b.add_theme_stylebox_override(st,UiAssets.tex_style(art,UiAssets.button(UiAssets.COLOR_GOLD if i == 0 else UiAssets.COLOR_RED)))
		b.add_theme_color_override("font_color",UiAssets.COLOR_DARK_TEXT if i == 0 else UiAssets.COLOR_TEXT)
		b.pressed.connect(func() -> void:
			if i == 0:
				pause_panel.queue_free()
			else:
				Router.toast("已退出本局")
				Net.send("room.leave"))
		pause_panel.add_child(b)

func _toggle_list() -> void:
	if is_instance_valid(listed_panel):
		listed_panel.queue_free()
		return
	listed_panel = Panel.new()
	listed_panel.position = Vector2(25,112)
	listed_panel.size = Vector2(285,360)
	listed_panel.add_theme_stylebox_override("panel",UiAssets.panel())
	add_child(listed_panel)
	var content: Label = Label.new()
	content.position = Vector2(18,14)
	content.text = "本局名单（状态仅显示可见信息）\n"
	content.add_theme_font_size_override("font_size",15)
	for p: Dictionary in Session.game.get("players",[]):
		content.text += "\n"+str(p.nickname)+( "  AI" if p.get("isBot",false) else "")
	listed_panel.add_child(content)

func _mark_menu() -> void:
	if is_instance_valid(marks_panel):
		marks_panel.queue_free()
		return
	marks_panel = Panel.new()
	marks_panel.position = Vector2(1060,165)
	marks_panel.size = Vector2(245,245)
	marks_panel.add_theme_stylebox_override("panel",UiAssets.panel())
	add_child(marks_panel)
	var names: Array[String] = ["这里危险","需要救援","这里有道具","我怀疑他"]
	var kinds: Array[String] = ["danger","help","item","suspect"]
	for i: int in 4:
		var b: Button = Button.new()
		b.text = names[i]
		b.position = Vector2(12,12+i*56)
		b.size = Vector2(220,48)
		b.pressed.connect(func() -> void:
			Net.send("game.mark",{"kind":kinds[i],"x":world.local_position.x,"y":world.local_position.y})
			marks_panel.queue_free())
		marks_panel.add_child(b)

func _draw() -> void:
	if not is_instance_valid(world): return
	# Screen-wide overlays first, so HUD panels and buttons stay readable on top of them.
	var map_event: Dictionary = Session.snap.get("mapEvent") if Session.snap.get("mapEvent") is Dictionary else {}
	if map_event.get("kind") == "blizzard" and map_event.get("stage") == "start":
		# Whiteout: a snow veil with drifting streaks (the server also shrinks outdoor vision).
		draw_rect(Rect2(0,0,1334,750),Color(0.85,0.9,1.0,0.22))
		var t: float = Time.get_ticks_msec()*0.001
		for i: int in 60:
			var x: float = fmod(i*97.0 + t*(180.0 + i%7*30.0), 1400.0) - 30.0
			var y: float = fmod(i*53.0 + t*(60.0 + i%5*20.0), 780.0) - 15.0
			draw_line(Vector2(x,y),Vector2(x-14,y+5),Color(1,1,1,0.55),2)
	if float(Session.me().get("cold",0)) > 0.01:
		var frost: float = float(Session.me().get("cold",0))
		for i: int in 14:
			draw_rect(Rect2(i*3,i*3,1334-i*6,750-i*6),Color(0.6,0.8,1.0,(1-float(i)/14)*0.05*frost/0.3),false,3)
	if Session.phase == "final":
		var tex: Texture2D = UiAssets.asset("hud/hud-vignette-red")
		if tex: draw_texture_rect(tex,Rect2(0,0,1334,750),false)
		else:
			for i: int in 25:
				draw_rect(Rect2(i*2,i*2,1334-i*4,750-i*4),Color(.9,.07,.15,(1-float(i)/25)*.06),false,2)
	var timer_frame: StyleBox = UiAssets.tex_style("hud/hud-timer-frame",StyleBoxEmpty.new(),Vector2(18,12),Vector2.ZERO)
	# The frame art carries a clock on its left; widen it leftwards so the digits clear it.
	draw_style_box(timer_frame,Rect2(timer_label.position-Vector2(62,2),timer_label.size+Vector2(72,6)))
	draw_style_box(UiAssets.tex_style("panel/panel_top_resource_bar",UiAssets.button(Color("786abe")),Vector2(16,14),Vector2.ZERO),Rect2(alive_button.position,alive_button.size))
	if not warn_strip.text.is_empty():
		draw_style_box(UiAssets.tex_style("event/event-warning-banner",UiAssets.button(UiAssets.COLOR_RED),Vector2(24,12),Vector2.ZERO),Rect2(warn_strip.position-Vector2(10,4),warn_strip.size+Vector2(20,8)))
	if not event_label.text.is_empty():
		draw_style_box(UiAssets.tex_style("event/event-warning-banner",UiAssets.button(UiAssets.COLOR_RED),Vector2(24,12),Vector2.ZERO),Rect2(event_label.position-Vector2(10,4),event_label.size+Vector2(20,8)))
	# Survivor row: a dot per hider, skulls for the caught ones.
	var skull: Texture2D = UiAssets.asset("icon/skull-icon")
	var roster: Array = (Session.snap.get("roster",[]) as Array).duplicate()
	if roster.is_empty():
		for i: int in int(Session.snap.get("totalHiders",0)):
			roster.append({"color":UiAssets.HIDER_COLORS[i%8],"caught":i >= int(Session.snap.get("alive",0))})
	var shown: int = mini(roster.size(),12)
	var step: float = minf(34.0,296.0/maxf(1.0,float(shown)))
	for i: int in shown:
		var at: Vector2 = alive_button.position+Vector2(32+i*step,64)
		var r: Dictionary = roster[i]
		if r.get("caught",false):
			if skull: draw_texture_rect(skull,Rect2(at-Vector2(13,13),Vector2(26,26)),false,Color(0.8,0.8,0.85))
			else: draw_circle(at,10,Color(0.4,0.4,0.45))
			continue
		var face: Texture2D = UiAssets.asset("avatar/avatar-hider-"+str(r.get("color","blue")))
		if face: draw_texture_rect(face,Rect2(at-Vector2(15,15),Vector2(30,30)),false)
		else: draw_circle(at,9,UiAssets.player_color(str(r.get("color","blue"))))
	if next_event_label.visible:
		draw_style_box(UiAssets.tex_style("panel/panel_top_resource_bar",UiAssets.button(Color("2c2552")),Vector2(16,14),Vector2.ZERO),NEXT_EVENT_RECT)
		var left: float = clampf((float(Session.snap.get("nextEventAt",0))-Net.now_ms())/60000.0,0.0,1.0)
		var bar: Rect2 = Rect2(NEXT_EVENT_RECT.position+Vector2(18,40),Vector2(194,12))
		draw_style_box(UiAssets.tex_style("button/progress_bar_frame",UiAssets.button(Color("28223f")),Vector2(10,5),Vector2.ZERO),bar)
		if left > 0.02:
			draw_style_box(UiAssets.tex_style("button/progress_bar_fill",UiAssets.button(UiAssets.COLOR_GOLD),Vector2(8,3),Vector2.ZERO),Rect2(bar.position+Vector2(3,3),Vector2((bar.size.x-6)*(1.0-left),bar.size.y-6)))
	var joy: Vector2 = joy_center()
	var base_tex: Texture2D = UiAssets.asset("hud/hud-joystick-base")
	var knob_tex: Texture2D = UiAssets.asset("hud/hud-joystick-knob")
	if base_tex:
		draw_texture_rect(base_tex,Rect2(joy-Vector2(90,90),Vector2(180,180)),false)
	else:
		draw_circle(joy,85,Color(.13,.12,.26,.8))
		draw_arc(joy,85,0,TAU,64,Color("7973b2"),2)
		draw_arc(joy,57,0,TAU,48,Color(.6,.55,.9,.4),1)
	if knob_tex:
		draw_texture_rect(knob_tex,Rect2(joy+joystick*60-Vector2(34,34),Vector2(68,68)),false)
	else:
		draw_circle(joy+joystick*60,30,Color("a49bd8"))
	var stamina: float = clampf(float(Session.me().get("stamina",4))/4.0,0.0,1.0)
	var bar: Rect2 = Rect2(joy-Vector2(85,122),Vector2(170,20))
	draw_style_box(UiAssets.tex_style("hud/hud-stamina-frame",UiAssets.button(Color("28223f")),Vector2(12,8),Vector2.ZERO),bar)
	if stamina > 0.02:
		draw_style_box(UiAssets.tex_style("hud/hud-stamina-fill",UiAssets.button(Color("689bcf")),Vector2(10,5),Vector2.ZERO),Rect2(bar.position+Vector2(4,4),Vector2((bar.size.x-8)*stamina,bar.size.y-8)))
	draw_string(font,bar.position+Vector2(0,-6),"体力 %d%%"%int(stamina*100),HORIZONTAL_ALIGNMENT_LEFT,-1,15,UiAssets.COLOR_TEXT)
	var me: Dictionary = Session.me()
	if me.get("progress") is Dictionary:
		var center: Vector2 = main_button.position+main_button.size/2
		draw_arc(center,70,-PI/2,-PI/2+TAU*float(me.progress.value),64,UiAssets.COLOR_GOLD,5)
	var mini_rect: Rect2 = Rect2(1114,18,192,136)
	draw_style_box(UiAssets.tex_style("panel/panel_room_code_cell",UiAssets.panel(),Vector2(16,16),Vector2.ZERO),mini_rect)
	draw_rect(mini_rect.grow(-7),Color(0.06,0.05,0.14,0.92))
	if not world.map.is_empty():
		var mw: float = float(world.map.w)
		var mh: float = float(world.map.h)
		var k: float = minf(178.0/mw,122.0/mh)
		var scale: Vector2 = Vector2(k,k)
		var origin: Vector2 = mini_rect.position+(mini_rect.size-Vector2(mw,mh)*k)/2.0
		if minimap_tex == null:
			var img: Image = Image.create(int(mw),int(mh),false,Image.FORMAT_RGBA8)
			for y: int in int(mh):
				for x: int in int(mw):
					var t: int = world.tiles[y*int(mw)+x]
					img.set_pixel(x,y,Color(0,0,0,0) if t == 5 else (Color("6f679f") if t in GameWorld.STRUCTURE else Color(0.13,0.12,0.24,1)))
			minimap_tex = ImageTexture.create_from_image(img)
		draw_texture_rect(minimap_tex,Rect2(origin,Vector2(mw,mh)*k),false)
		for key: Vector2i in explored:
			if key.x >= 0 and key.y >= 0 and key.x < int(mw) and key.y < int(mh) and not (world.tiles[key.y*int(mw)+key.x] in GameWorld.STRUCTURE):
				draw_rect(Rect2(origin+Vector2(key)*scale,scale),Color(0.32,0.3,0.55,0.9))
		draw_circle(origin+world.local_position*scale,3.5,Color.WHITE)
		for gen: Dictionary in Session.snap.get("generators",[]):
			draw_rect(Rect2(origin+Vector2(float(gen.x),float(gen.y))*scale-Vector2(2,2),Vector2(4,4)),UiAssets.COLOR_GOLD)
		for drop: Dictionary in Session.drops:
			if drop.get("stage") != "taken":
				draw_circle(origin+Vector2(float(drop.x),float(drop.y))*scale,2,Color("68bde6"))
	if wheel_open:
		var center: Vector2 = mirror(Vector2(1110,345))
		draw_circle(center,102,Color(.12,.1,.26,.95))
		draw_arc(center,102,0,TAU,64,UiAssets.COLOR_GOLD,2)
		for i: int in wheel_choices.size():
			var at: Vector2 = center+Vector2.RIGHT.rotated(float(i)/wheel_choices.size()*TAU)*65
			draw_circle(at,30,Color("80612d") if i == wheel_index else Color("39315d"))
			draw_string(font,at+Vector2(-24,6),_prop_name(wheel_choices[i]),HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color.WHITE)
	var points: Array = Session.drops.duplicate()
	for ripple: Dictionary in Session.snap.get("ripples",[]):
		if float(ripple.get("r",0)) >= 5: points.append(ripple)
	for p: Dictionary in points:
		if p.get("stage") == "taken": continue
		var screen: Vector2 = world.screen_position(Vector2(float(p.x),float(p.y)))
		screen = get_global_transform_with_canvas().affine_inverse()*screen
		if not Rect2(35,35,1264,680).has_point(screen):
			_edge_marker(screen, p.has("r"), bool(p.get("hunter", false)))

## Off-screen sound / supply drop: a 64px half-disc hugging the screen edge (a full disc with
## a pointer when it is above or below the play area), ripple or star icon inside; fades
## with distance so far-away noises stay quiet.
func _edge_marker(screen: Vector2, is_sound: bool, from_hunter: bool) -> void:
	# Safe spots that avoid the HUD: side edges between the top panels and the thumb
	# controls, the top band under the timer, the bottom band between joystick and buttons.
	var at: Vector2
	if screen.y < 160:
		at = Vector2(clampf(screen.x,380,1040),160)
	elif screen.y > 470 and screen.x > 240 and screen.x < 1060:
		at = Vector2(clampf(screen.x,300,900),690)
	else:
		at = Vector2(0.0 if screen.x < 667 else 1334.0,clampf(screen.y,180,470))
	var angle: float = (screen-Vector2(667,375)).angle()
	var alpha: float = clampf(1.25 - (screen-Vector2(667,375)).length()/1800.0, 0.35, 1.0)
	var rim: Color = (UiAssets.COLOR_RED if from_hunter else UiAssets.COLOR_GOLD) if is_sound else Color("68bde6")
	var on_side: bool = at.x <= 0.0 or at.x >= 1334.0
	var inward: Vector2 = Vector2(-signf(at.x-667),0) if on_side else Vector2.ZERO
	draw_circle(at,32,Color(.06,.05,.14,.78*alpha))
	draw_arc(at,32,0,TAU,40,Color(rim,alpha),3)
	if not on_side:
		var tip: Vector2 = at+Vector2(44,0).rotated(angle)
		draw_colored_polygon(PackedVector2Array([tip,at+Vector2(32,-9).rotated(angle),at+Vector2(32,9).rotated(angle)]),Color(rim,alpha))
	var icon: Texture2D = UiAssets.asset("icon/ripple-icon" if is_sound else "icon/star-icon")
	var c: Vector2 = at+inward*15
	if icon: draw_texture_rect(icon,Rect2(c-Vector2(16,16),Vector2(32,32)),false,Color(rim.lightened(.3),alpha))

func _button(text: String, pos: Vector2, extent: Vector2, color: Color) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.position = pos
	b.size = extent
	b.add_theme_stylebox_override("normal",UiAssets.button(color))
	b.add_theme_stylebox_override("pressed",UiAssets.button(color.lightened(.2)))
	b.add_theme_font_size_override("font_size",18)
	add_child(b)
	return b

func _label(text: String, pos: Vector2, extent: Vector2, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.position = pos
	label.size = extent
	label.add_theme_font_size_override("font_size",font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _item_name(item: String) -> String:
	return {"":"空","smoke":"烟雾弹","banana":"香蕉皮","speed_shoes":"加速鞋","wood_board":"木板","strong_flashlight":"强光手电","net":"捕网","bell_trap":"铃铛","sprint_shoes":"冲刺鞋"}.get(item,item)

func _prop_name(prop: String) -> String:
	return {"cardboard_box":"纸箱","chair":"椅子","potted_plant":"盆栽","pillow":"枕头","desk_lamp":"台灯","trash_can":"垃圾桶","oil_drum":"油桶","food_tray":"餐盘"}.get(prop,prop)

func _skin_hud() -> void:
	var me: Dictionary = Session.me()
	var hunter: bool = Session.role() == "hunter"
	var ghost: bool = str(me.get("state", "normal")) == "ghost"
	_skin(main_button, "hud-btn-main-slap" if hunter else "hud-btn-main-interact")
	_skin(skill_button, "hud-btn-ghost-skill" if ghost else ("hud-btn-skill-flashlight" if hunter else "hud-btn-skill-disguise"))
	_skin(accuse, "hud-btn-skill-report" if Session.role() == "mole" else "hud-btn-accuse")
	for b: Button in item_buttons:
		_skin(b, "hud-btn-item-slot")