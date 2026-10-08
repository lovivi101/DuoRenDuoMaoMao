class_name CharacterArt
extends RefCounted
## Character sequence frames (素材 T6 anim-*.png strips, 128x192 per frame, feet at y=176),
## wardrobe hat overlays (T7 hat-<id>-<dir>.png, same canvas) and the pajama tint shader.

const FRAME: Vector2 = Vector2(128, 192)
const WALK_FPS: float = 8.0
const RUN_FPS: float = 12.0
const IDLE_FPS: float = 2.0

# Tints only bright, low-saturation pixels (the white pajamas); skin, hair, eyes and outlines
# keep their own colours, so players stay recognisable and no tint makes anyone darker.
const TINT_SHADER: String = """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(1.0);
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float hi = max(c.r, max(c.g, c.b));
	float lo = min(c.r, min(c.g, c.b));
	float sat = hi > 0.0 ? (hi - lo) / hi : 0.0;
	float w = (1.0 - smoothstep(0.12, 0.3, sat)) * smoothstep(0.5, 0.75, hi);
	COLOR = vec4(mix(c.rgb, c.rgb * tint.rgb * 1.08, w), c.a);
}
"""
static var _shader: Shader = null

static func tint_material(color: Color) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = TINT_SHADER
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("tint", color.lightened(0.15))
	return m

static func strip(name: String) -> Texture2D:
	return UiAssets.asset("sprite/anim-" + name)

static func frame_count(tex: Texture2D, width: float = FRAME.x) -> int:
	return maxi(1, int(tex.get_width() / width)) if tex else 1

## Source rect of frame `index` in a horizontal strip.
static func frame_rect(tex: Texture2D, index: int, size: Vector2 = FRAME) -> Rect2:
	return Rect2(Vector2(size.x * (index % frame_count(tex, size.x)), 0), size)

## Facing from a movement / aim vector: "down", "up" or "side" (+ flip for left).
static func facing(v: Vector2) -> Array:
	if v.length() < 0.01:
		return ["down", false]
	if absf(v.x) > absf(v.y):
		return ["side", v.x < 0]
	return ["down" if v.y > 0 else "up", false]

## Strip and frame for a character: role hider / hunter, state, moving, running, facing.
static func pick(role: String, state: String, moving: bool, running: bool, dir: String, t: float, slapping: bool = false) -> Dictionary:
	var name: String
	var fps: float = WALK_FPS
	if state == "ghost":
		name = "ghost-float"; fps = 6.0
	elif state in ["caged"]:
		name = "hider-caught"; fps = 3.0
	elif role == "hunter" and slapping:
		name = "hunter-slap"; fps = 10.0
	elif moving:
		name = ("hunter" if role == "hunter" else "hider") + "-walk-" + dir
		fps = RUN_FPS if running else WALK_FPS
	elif dir == "down":
		name = ("hunter" if role == "hunter" else "hider") + "-idle"; fps = IDLE_FPS
	else:
		name = ("hunter" if role == "hunter" else "hider") + "-walk-" + dir; fps = 0.0
	var tex: Texture2D = strip(name)
	return {"tex": tex, "index": int(t * fps), "name": name}

static func hat(id: String, dir: String) -> Texture2D:
	return UiAssets.asset("sprite/hat-%s-%s" % [id if not id.is_empty() else "nightcap", dir])

## A full-body standing figure for menus: idle frame + tint + equipped hat, `height` px tall.
static func figure(color: String, hat_id: String, pos: Vector2, height: float) -> Control:
	var box: Control = Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Whole-number scale keeps pixel art crisp.
	var s: float = maxf(1.0, roundf(height / FRAME.y))
	box.size = FRAME * s
	box.position = pos + (Vector2(height * 2.0 / 3.0, height) - box.size) * Vector2(0.5, 1.0)
	var body_tex: Texture2D = strip("hider-idle")
	if body_tex == null:
		body_tex = UiAssets.asset("sprite/sprite-hider")
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = body_tex
	atlas.region = frame_rect(body_tex, 0)
	for layer: Array in [[atlas, tint_material(UiAssets.player_color(color))], [hat(hat_id, "down"), null]]:
		var rect: TextureRect = TextureRect.new()
		rect.texture = layer[0]
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_SCALE
		rect.size = box.size
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if layer[1]:
			rect.material = layer[1]
		box.add_child(rect)
	return box
