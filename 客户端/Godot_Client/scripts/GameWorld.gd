class_name GameWorld
extends Node2D

var map: Dictionary = {}
var tiles: PackedByteArray = PackedByteArray()
var layer: TileMapLayer = TileMapLayer.new()
# Walls, furniture and shelves draw on their own layer: lit by the vision light but never
# shadowed by their own occluders, so room structure stays readable inside the light.
var wall_layer: TileMapLayer = TileMapLayer.new()
# Tile ids from map.legend: 0 floor 1 wall_solid 2 wall_cracked 3 door 4 rubble 5 void 6 furniture 7 shelf.
const BLOCKING: Array[int] = [1, 2, 5, 6, 7]
const SIGHT_BLOCKING: Array[int] = [1, 2, 5, 7]
const STRUCTURE: Array[int] = [1, 2, 5, 6, 7]
var camera: Camera2D = Camera2D.new()
var darkness: CanvasModulate = CanvasModulate.new()
var light: PointLight2D = PointLight2D.new()
var flashlight: PointLight2D = PointLight2D.new()
var walls: Dictionary = {}
var local_position: Vector2 = Vector2.ZERO
var correction: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.ZERO
var run: bool = false
var last_direction: Vector2 = Vector2.ZERO
var last_run: bool = false
var send_time: float = 0.0
var pending: Array[Dictionary] = []
var snapshots: Array[Dictionary] = []
var actors: Node2D = Node2D.new()
var signals_layer: Node2D = Node2D.new()
var actor_nodes: Dictionary = {}
var initialized: bool = false
var freeze_until: int = 0
var shake_until: int = 0
var spectating: String = ""
var fx: Array[Dictionary] = []
# Floor decor, furniture art, props, generators, cage and drops. The node's own _draw runs
# before its TileMapLayer children, so anything drawn there would sit under the floor.
var objects: Node2D = Node2D.new()
# Blocking cells covered by a furniture sprite (map.furniture) render as plain floor.
var furniture_cells: Dictionary = {}
# Atlas columns 8 / 9 hold the tile and concrete floors; zones pick their floor (map.zones).
const FLOOR_COLUMN: Dictionary = {"wood": 0, "tile": 8, "concrete": 9}
# Decor footprints in cells; anything unlisted is 1x1.
const DECOR_SIZE: Dictionary = {"rug_dorm": Vector2(3, 2), "puddle": Vector2(2, 1), "bath_mat": Vector2(2, 1)}

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map = Session.game.get("map", {})
	if map.is_empty():
		return
	tiles = Marshalls.base64_to_raw(str(map.get("tiles", "")))
	if tiles.size() != int(map.w) * int(map.h):
		push_error("Invalid map tile byte count")
		return
	for f: Dictionary in map.get("furniture", []):
		if UiAssets.asset("sprite/furn-" + str(f.kind).replace("_", "-")):
			for y: int in range(int(f.y), int(f.y) + int(f.h)):
				for x: int in range(int(f.x), int(f.x) + int(f.w)):
					furniture_cells[Vector2i(x, y)] = true
	_build_tiles()
	add_child(layer)
	wall_layer.light_mask = 2
	add_child(wall_layer)
	objects.z_index = 1
	objects.draw.connect(_draw_objects)
	add_child(objects)
	add_child(actors)
	add_child(signals_layer)
	signals_layer.z_index = 5
	signals_layer.draw.connect(_draw_signals)
	var material: CanvasItemMaterial = CanvasItemMaterial.new()
	material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	signals_layer.material = material
	darkness.color = Color("0c0a1a")
	add_child(darkness)
	light.texture = _light_texture(false)
	light.shadow_enabled = true
	light.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	light.range_item_cull_mask = 1 | 2
	light.shadow_item_cull_mask = 1
	light.color = Color("d8d8ff")
	light.energy = 1.2
	add_child(light)
	flashlight.texture = _light_texture(true)
	flashlight.shadow_enabled = true
	flashlight.range_item_cull_mask = 1 | 2
	flashlight.shadow_item_cull_mask = 1
	flashlight.color = Color("ffe6a4")
	flashlight.energy = 0.85
	add_child(flashlight)
	camera.zoom = Vector2(1.6, 1.6)
	add_child(camera)
	var spawn: Dictionary = map.get("hunterSpawn", {"x":32,"y":20}) if Session.role() == "hunter" else map.get("hiderSpawns", [{"x":30,"y":22}])[0]
	local_position = _xy(Session.me()) if not Session.me().is_empty() else _xy(spawn)
	camera.position = local_position * 32
	Net.message.connect(_message)
	initialized = true
	_snap(Session.snap)
	objects.queue_redraw()

func _build_tiles() -> void:
	var set: TileSet = TileSet.new()
	set.tile_size = Vector2i(32,32)
	var atlas: Image = Image.create(320,32,false,Image.FORMAT_RGBA8)
	var names: Array[String] = ["tile-floor-wood","tile-wall-solid","tile-wall-cracked","tile-door","tile-rubble","tile-wall-solid","tile-furniture","tile-shelf","tile-floor-tile","tile-floor-concrete"]
	var colors: Array[Color] = [Color("3a3f5c"),Color("9a9cc0"),Color("a594ac"),Color("b88a5f"),Color("5e566c"),Color("151424"),Color("8a6a4a"),Color("6d5a48"),Color("3b4462"),Color("403f4f")]
	for i: int in 10:
		var texture: Texture2D = UiAssets.asset("sprite/" + names[i])
		# Always paint the procedural base first, then blend the art on top: tile art with
		# keyed-out (transparent) edges would otherwise leave dark seams between cells.
		if true:
			for y: int in 32:
				for x: int in 32:
					var c: Color = colors[i]
					if i in [0, 8, 9]:
						# Floorboards: soft seams with staggered joints, never mistaken for brick walls.
						if y % 8 == 7 or (x + (y / 8) * 11) % 32 == 0:
							c = c.darkened(0.18)
					elif y % 8 == 0 or (x + (16 if (y / 8) % 2 == 0 else 0)) % 32 == 0:
						c = c.darkened(0.3)
					if i in [1,2] and y < 4:
						c = c.lightened(0.15)
					if i == 2 and absi(x-16-int(sin(y)*3)) < 2:
						c = Color("28283d")
					atlas.set_pixel(i*32+x,y,c)
		if texture:
			var im: Image = texture.get_image()
			im.convert(Image.FORMAT_RGBA8)
			im.resize(32,32,Image.INTERPOLATE_NEAREST)
			atlas.blend_rect(im,Rect2i(0,0,32,32),Vector2i(i*32,0))
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(atlas)
	source.texture_region_size = Vector2i(32,32)
	for i: int in 10:
		source.create_tile(Vector2i(i,0))
	set.add_source(source,0)
	layer.tile_set = set
	wall_layer.tile_set = set
	for y: int in int(map.h):
		for x: int in int(map.w):
			_update_cell(x,y,tiles[y*int(map.w)+x])

func _update_cell(x: int, y: int, tile: int) -> void:
	var key: Vector2i = Vector2i(x,y)
	if walls.has(key):
		(walls[key] as Node).queue_free()
		walls.erase(key)
	var floor_cell: Vector2i = Vector2i(_floor_column(x,y),0)
	var atlas_tile: Vector2i = floor_cell if tile == 0 else Vector2i(clampi(tile,0,7),0)
	if tile in STRUCTURE and not furniture_cells.has(key):
		layer.set_cell(key,0,floor_cell)
		wall_layer.set_cell(key,0,atlas_tile)
	else:
		layer.set_cell(key,0,floor_cell if furniture_cells.has(key) else atlas_tile)
		wall_layer.erase_cell(key)
	if tile in BLOCKING:
		var wall: StaticBody2D = StaticBody2D.new()
		wall.position = Vector2(x*32,y*32)
		var collider: CollisionShape2D = CollisionShape2D.new()
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = Vector2(32,32)
		collider.shape = shape
		collider.position = Vector2(16,16)
		wall.add_child(collider)
		if tile not in SIGHT_BLOCKING:
			add_child(wall)
			walls[key] = wall
			return
		var occluder: LightOccluder2D = LightOccluder2D.new()
		var polygon: OccluderPolygon2D = OccluderPolygon2D.new()
		polygon.polygon = PackedVector2Array([Vector2(0,0),Vector2(32,0),Vector2(32,32),Vector2(0,32)])
		occluder.occluder = polygon
		wall.add_child(occluder)
		add_child(wall)
		walls[key] = wall

func _floor_column(x: int, y: int) -> int:
	for zone: Dictionary in map.get("zones", []):
		if x >= int(zone.x) and y >= int(zone.y) and x < int(zone.x) + int(zone.w) and y < int(zone.y) + int(zone.h):
			return int(FLOOR_COLUMN.get(str(zone.get("floor", "wood")), 0))
	return 0

func _light_texture(cone: bool) -> Texture2D:
	var im: Image = Image.create(256,256,false,Image.FORMAT_RGBA8)
	for y: int in 256:
		for x: int in 256:
			var v: Vector2 = Vector2(x-128,y-128)/128.0
			var strength: float = pow(clampf(1.0-v.length(),0,1),0.5)
			if cone and absf(v.angle()) > PI/6.0:
				strength = 0
			im.set_pixel(x,y,Color(1,1,1,strength))
	return ImageTexture.create_from_image(im)

func _message(data: Dictionary) -> void:
	match str(data.get("t", "")):
		"game.snap": _snap(data)
		"game.wall":
			for cell: Dictionary in data.cells:
				var x: int = int(cell.x)
				var y: int = int(cell.y)
				if x >= 0 and y >= 0 and x < int(map.w) and y < int(map.h):
					tiles[y*int(map.w)+x] = int(cell.tile)
					_update_cell(x,y,int(cell.tile))
		"game.caught":
			fx.append({"kind":"caught","x":data.x,"y":data.y,"until":Time.get_ticks_msec()+1000})
			if data.victimId == Session.user.get("id") or data.hunterId == Session.user.get("id"):
				freeze_until = Time.get_ticks_msec()+300
				shake_until = freeze_until+200
				Audio.cue(true)
				Audio.vibrate()
		"game.fx":
			var entry: Dictionary = data.duplicate()
			entry.until = Time.get_ticks_msec()+1400
			fx.append(entry)

func _snap(data: Dictionary) -> void:
	if data.is_empty() or not initialized:
		return
	var authoritative: Vector2 = _xy(data.you)
	var ack: int = int(data.you.get("ackSeq", -1))
	var remaining: Array[Dictionary] = []
	for step: Dictionary in pending:
		if int(step.seq) > ack:
			remaining.append(step)
			authoritative = _move_position(authoritative, step.displacement, str(data.you.get("state","normal")) == "ghost")
	pending = remaining
	if local_position.distance_to(authoritative) > 3.0:
		local_position = authoritative
		correction = Vector2.ZERO
	else:
		correction = authoritative-local_position
	snapshots.append({"received":Time.get_ticks_msec(),"players":data.get("players",[])})
	while snapshots.size() > 10:
		snapshots.pop_front()
	# Remove immediately when visibility is revoked; interpolation never reveals stale actors.
	var allowed: Dictionary = {str(Session.user.get("id","local")):true}
	for p: Dictionary in data.get("players",[]):
		allowed[str(p.id)] = true
	for id: String in actor_nodes.keys():
		if not allowed.has(id):
			(actor_nodes[id] as Node).queue_free()
			actor_nodes.erase(id)

func _physics_process(delta: float) -> void:
	if not initialized:
		return
	var me: Dictionary = Session.me()
	if direction != last_direction or run != last_run or send_time >= 0.09:
		Net.input_vector(direction,run)
		send_time = 0
		last_direction = direction
		last_run = run
	send_time += delta
	var speed: float = 4.0 if Session.role() == "hunter" else 3.0
	if run and (float(me.get("stamina",4)) > 0 or Session.role() == "hunter" or me.get("state") == "ghost"):
		speed = 5.0 if Session.role() == "hunter" else 5.5
	if Session.phase == "final" and Session.role() == "hunter":
		speed *= 1.2
	if Session.event.get("kind") == "adrenaline" and Session.event.get("stage") == "start":
		speed *= 1.5
	var can_move: bool = Session.phase in ["hide","hunt","final"] and me.get("state") not in ["caged","stunned"] and not (Session.phase == "hide" and Session.role() == "hunter")
	if can_move and Time.get_ticks_msec() >= freeze_until and Net.connected:
		var displacement: Vector2 = direction * speed * delta
		local_position = _move_position(local_position,displacement,me.get("state") == "ghost")
		pending.append({"seq":Net.seq,"displacement":displacement})
		if pending.size() > 30:
			pending.pop_front()
	var ease: Vector2 = correction * minf(delta*12.0,1.0)
	local_position += ease
	correction -= ease
	light.position = local_position * 32
	light.texture_scale = maxf(0.05,float(me.get("visionRadius",5))*32/128.0)
	flashlight.position = light.position
	flashlight.rotation = direction.angle() if direction.length() > 0.01 else float(me.get("dir",0))
	flashlight.texture_scale = 6.0*32/128.0
	flashlight.visible = Session.role() == "hunter" and bool(me.get("flashlight",true)) and Session.phase != "hide"
	light.visible = not (Session.role() == "hunter" and Session.phase == "hide")
	darkness.color = Color("68647b") if Session.event.get("kind") == "emergency_light" and Session.event.get("stage") == "start" else Color("0c0a1a")
	var target: Vector2 = local_position*32
	if actor_nodes.has(spectating):
		target = (actor_nodes[spectating] as Node2D).position
	camera.position = camera.position.lerp(target, minf(1.0,delta*12))
	camera.offset = Vector2(randf_range(-5,5),randf_range(-5,5)) if Config.settings.shake and Time.get_ticks_msec()<shake_until else Vector2.ZERO
	_update_actors()
	signals_layer.queue_redraw()
	objects.queue_redraw()

func _move_position(pos: Vector2, displacement: Vector2, ghost: bool) -> Vector2:
	if ghost:
		return (pos+displacement).clamp(Vector2(0.4,0.4),Vector2(float(map.w)-0.4,float(map.h)-0.4))
	var next: Vector2 = pos
	if _walkable(Vector2(pos.x+displacement.x,pos.y)):
		next.x += displacement.x
	if _walkable(Vector2(next.x,pos.y+displacement.y)):
		next.y += displacement.y
	return next

func _walkable(pos: Vector2) -> bool:
	for corner: Vector2 in [Vector2(-.35,-.35),Vector2(.35,-.35),Vector2(-.35,.35),Vector2(.35,.35)]:
		var p: Vector2i = Vector2i((pos+corner).floor())
		if p.x < 0 or p.y < 0 or p.x >= int(map.w) or p.y >= int(map.h):
			return false
		if tiles[p.y*int(map.w)+p.x] in BLOCKING:
			return false
	return true

func _update_actors() -> void:
	var me: Dictionary = Session.me().duplicate()
	me.id = str(Session.user.get("id","local"))
	me.x = local_position.x
	me.y = local_position.y
	_actor(me,true)
	if snapshots.is_empty():
		return
	var render_at: int = Time.get_ticks_msec()-100
	var a: Dictionary = snapshots.front()
	var b: Dictionary = snapshots.back()
	for i: int in range(snapshots.size()-1):
		if int(snapshots[i].received) <= render_at and int(snapshots[i+1].received) >= render_at:
			a = snapshots[i]
			b = snapshots[i+1]
			break
	var fraction: float = clampf(float(render_at-int(a.received))/maxf(1,float(int(b.received)-int(a.received))),0,1)
	var latest: Array = Session.snap.get("players",[])
	for current: Dictionary in latest:
		var first: Dictionary = current
		var second: Dictionary = current
		for p: Dictionary in a.players:
			if p.id == current.id: first = p
		for p: Dictionary in b.players:
			if p.id == current.id: second = p
		var rendered: Dictionary = current.duplicate()
		var pos: Vector2 = _xy(first).lerp(_xy(second),fraction)
		rendered.x = pos.x
		rendered.y = pos.y
		_actor(rendered,false)

func _actor(data: Dictionary, local: bool) -> void:
	var id: String = str(data.id)
	var node: Node2D
	if not actor_nodes.has(id):
		node = Node2D.new()
		actors.add_child(node)
		actor_nodes[id] = node
		node.draw.connect(func() -> void: _draw_actor(node))
	else:
		node = actor_nodes[id]
	node.set_meta("data",data)
	node.set_meta("local",local)
	node.position = _xy(data)*32
	node.z_index = 2
	node.queue_redraw()

func _draw_actor(node: Node2D) -> void:
	var p: Dictionary = node.get_meta("data")
	var local: bool = node.get_meta("local")
	var role: String = Session.role() if local else "hider"
	for ally: Dictionary in Session.game.get("allies",[]):
		if ally.id == p.id:
			role = str(ally.role)
	# A visible hunter's role is not exposed in snap; hunter visuals use known allies only.
	var color: Color = Color("5890ff")
	for player: Dictionary in Session.game.get("players",[]):
		if player.id == p.id:
			color = UiAssets.player_color(str(player.get("color","blue")))
	var state: String = str(p.get("state","normal"))
	var asset_name: String = "sprite-ghost" if state == "ghost" else ("sprite-hunter" if role == "hunter" else "sprite-hider")
	if state == "disguised" and p.get("prop") != null:
		asset_name = "prop-"+str(p.prop).replace("_","-")
	var tex: Texture2D = UiAssets.asset("sprite/"+asset_name)
	if state == "ghost": color.a = 0.5
	if tex:
		# Characters are 2:3 (128x192) with feet at the bottom; props are square.
		var rect: Rect2 = Rect2(-16,-16,32,32) if asset_name.begins_with("prop-") else Rect2(-18,-40,36,54)
		node.draw_texture_rect(tex,rect,false,color if asset_name == "sprite-hider" else Color(1,1,1,color.a))
	elif state == "disguised":
		node.draw_rect(Rect2(-12,-12,24,24),Color("b69363"))
		node.draw_line(Vector2(0,-12),Vector2(0,12),Color("73573c"),2)
	else:
		node.draw_circle(Vector2(0,11),14,Color(0,0,0,.45))
		node.draw_rect(Rect2(-10,-4,20,21),Color("3c3756") if role == "hunter" else color)
		node.draw_circle(Vector2(0,-9),12,Color("262032") if role == "hunter" else color.lightened(.25))
		node.draw_rect(Rect2(-8,-12,16,8),Color("f7d6b5"))
		node.draw_rect(Rect2(-6,-10,3,3),UiAssets.COLOR_RED if role == "hunter" else Color("20203e"))
		node.draw_rect(Rect2(3,-10,3,3),UiAssets.COLOR_RED if role == "hunter" else Color("20203e"))
	if local:
		node.draw_arc(Vector2(0,15),14,0,TAU,24,Color("ffc857"),1.2)
	if Config.settings.colorblind:
		node.draw_string(ThemeDB.fallback_font,Vector2(-5,-28),"H" if role == "hunter" else "C",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.WHITE)

func _draw_objects() -> void:
	if not initialized:
		return
	for d: Dictionary in map.get("decor",[]):
		var tex: Texture2D = UiAssets.asset("sprite/decor-"+str(d.kind).replace("_","-"))
		if tex:
			var cells: Vector2 = DECOR_SIZE.get(str(d.kind), Vector2.ONE)
			objects.draw_texture_rect(tex,Rect2(_xy(d)*32,cells*32),false)
	for f: Dictionary in map.get("furniture",[]):
		var tex: Texture2D = UiAssets.asset("sprite/furn-"+str(f.kind).replace("_","-"))
		if tex:
			objects.draw_texture_rect(tex,Rect2(_xy(f)*32,Vector2(float(f.w),float(f.h))*32),false)
	for prop: Dictionary in map.get("props",[]):
		_object("prop-"+str(prop.prop).replace("_","-"),_xy(prop)*32,Color("b79577"))
	for gen: Dictionary in Session.snap.get("generators",map.get("generators",[])):
		var pos: Vector2 = _xy(gen)*32
		# Generators are objectives: drawn larger than props, progress bar right above.
		_object("sprite-generator-fixed" if gen.get("fixed",false) else "sprite-generator",pos,Color("91b678") if gen.get("fixed",false) else Color("d4af67"),40)
		objects.draw_rect(Rect2(pos+Vector2(-18,-22),Vector2(36,5)),Color("282438"))
		objects.draw_rect(Rect2(pos+Vector2(-18,-22),Vector2(36*float(gen.get("progress",0)),5)),Color("ffc857"))
	_object("sprite-cage",_xy(map.get("cage",{}))*32,Color("a8a9b4"),48)
	for drop: Dictionary in Session.drops:
		if drop.get("stage") == "landed":
			_object("sprite-item-box",_xy(drop)*32,Color("d0a34e"))

func _object(asset_name: String, pos: Vector2, color: Color, extent: float = 26) -> void:
	var tex: Texture2D = UiAssets.asset("sprite/"+asset_name)
	if tex:
		objects.draw_texture_rect(tex,Rect2(pos-Vector2.ONE*extent/2,Vector2.ONE*extent),false)
	else:
		objects.draw_rect(Rect2(pos-Vector2.ONE*extent/2,Vector2.ONE*extent),color)
		objects.draw_rect(Rect2(pos-Vector2.ONE*extent/2,Vector2.ONE*extent),color.darkened(.5),false,2)
		if "cage" in asset_name:
			for x: int in range(-20,21,8):
				objects.draw_line(pos+Vector2(x,-24),pos+Vector2(x,24),Color("222436"),3)
		elif "generator" in asset_name:
			objects.draw_string(ThemeDB.fallback_font,pos+Vector2(-8,7),"G",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("282338"))

func _draw_signals() -> void:
	var now: float = Time.get_ticks_msec()*0.001
	for ripple: Dictionary in Session.snap.get("ripples",[]):
		var radius: float = float(ripple.get("r",3))*32
		var amount: float = fmod(now + float(ripple.x)*.13,1.4)/1.4
		var color: Color = Color("f95668") if ripple.get("hunter",false) else Color("e8e4ff")
		# Thin rings that fade as they grow: big noises must not smear across the whole screen.
		color.a = (.55 if Config.settings.visual_audio else .4)*(1-amount)*(1-amount)
		signals_layer.draw_arc(_xy(ripple)*32,maxf(2,radius*amount),0,TAU,48,color,2.0 if Config.settings.visual_audio else 1.2)
	for footprint: Dictionary in Session.snap.get("footprints",[]):
		var pos: Vector2 = _xy(footprint)*32
		signals_layer.draw_line(pos,pos+Vector2(4,0).rotated(float(footprint.get("dir",0))),Color(0.8,.8,1,.4),3)
	for mark: Dictionary in Session.snap.get("marks",[]):
		signals_layer.draw_arc(_xy(mark)*32,18,0,TAU,20,Color("f8ca65"),2)
	for drop: Dictionary in Session.drops:
		if drop.get("stage") != "taken":
			var pos: Vector2 = _xy(drop)*32
			signals_layer.draw_line(pos,pos-Vector2(0,80),Color(.9,.75,.35,.45),7)
	var remaining: Array[Dictionary] = []
	for effect: Dictionary in fx:
		if int(effect.until) > Time.get_ticks_msec():
			remaining.append(effect)
			var pos: Vector2 = _xy(effect)*32
			if effect.kind == "caught":
				signals_layer.draw_string(ThemeDB.fallback_font,pos+Vector2(-40,-40),"抓到了！",HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("ffc857"))
			else:
				signals_layer.draw_circle(pos,24,Color(.8,.8,1,.35))
	fx = remaining

func _xy(data: Dictionary) -> Vector2:
	return Vector2(float(data.get("x",0)),float(data.get("y",0)))

func screen_position(world_position: Vector2) -> Vector2:
	return (world_position*32-camera.position)*camera.zoom+get_viewport_rect().size*0.5
