class_name UiAssets
extends RefCounted

const COLOR_BG: Color = Color("0c0a1a")
const COLOR_PANEL: Color = Color("1b1633")
const COLOR_PANEL_2: Color = Color("2a2350")
const COLOR_GOLD: Color = Color("ffc857")
const COLOR_TEXT: Color = Color("fff4d2")
const COLOR_MUTED: Color = Color("aaa3c7")
const COLOR_RED: Color = Color("e5383b")
const COLOR_GREEN: Color = Color("07c160")
const COLORS: Array[Color] = [Color("f04b5f"), Color("f28f3b"), Color("ffd166"), Color("65c466"), Color("35c9d5"), Color("4b83ff"), Color("a66cff"), Color("f28cc5")]

static func bg_for(page: int) -> Color:
	return Color("101331") if page >= 13 else Color("12132b")

static func panel() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.border_color = Color("6456a4")
	style.set_border_width_all(2)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 8
	return style

static func button(color: Color = COLOR_GOLD) -> StyleBoxFlat:
	var style: StyleBoxFlat = panel()
	style.bg_color = color.darkened(0.5) if color != COLOR_GOLD else Color("493b72")
	style.border_color = color
	style.set_border_width_all(2)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	return style

# Textures are cached for the lifetime of the app. Callers such as _draw() only hold the
# texture for the duration of the call; without a live reference the texture is freed
# before the frame renders and Godot substitutes its default white texture (solid blocks).
static var _cache: Dictionary = {}

static func asset(filename: String) -> Texture2D:
	if _cache.has(filename):
		return _cache[filename]
	var texture: Texture2D = null
	for path: String in ["res://assets/ui/" + filename + ".png", "res://assets/ui/" + filename + ".webp"]:
		if ResourceLoader.exists(path):
			texture = load(path)
			break
	_cache[filename] = texture
	return texture

static func nine_patch(filename: String, fallback: StyleBoxFlat, margin: int = 16) -> StyleBox:
	var texture: Texture2D = asset(filename)
	if texture == null:
		return fallback
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = margin
	style.texture_margin_top = margin
	style.texture_margin_right = margin
	style.texture_margin_bottom = margin
	return style

# --- Styled widgets built from 素材 art ------------------------------------------------

const COLOR_DARK_TEXT: Color = Color("2a1a0a")
const HIDER_COLORS: Array[String] = ["red","orange","yellow","green","cyan","blue","purple","pink"]
static var _used_rect_cache: Dictionary = {}
static var _pixel_font: Font = null

## Title font (Fusion Pixel); body text keeps the theme's Noto Sans SC.
static func pixel_font() -> Font:
	if _pixel_font == null:
		_pixel_font = load("res://assets/fonts/FusionPixelZH.ttf")
	return _pixel_font

## The generated art sits inside generous transparent padding (a 480x120 button canvas
## holds a ~55px tall button). Styles use only the opaque bounds so buttons fill their rect.
static func used_rect(filename: String) -> Rect2:
	if _used_rect_cache.has(filename):
		return _used_rect_cache[filename]
	var tex: Texture2D = asset(filename)
	var rect: Rect2 = Rect2()
	if tex:
		var img: Image = tex.get_image()
		if img.is_compressed():
			img.decompress()
		rect = Rect2(img.get_used_rect())
	_used_rect_cache[filename] = rect
	return rect

## Nine-patch StyleBoxTexture over the art's opaque bounds; falls back to a flat style
## when the art is missing. `margin` is the stretch border in texture pixels.
static func tex_style(filename: String, fallback: StyleBox, margin: Vector2 = Vector2(22, 14), content: Vector2 = Vector2(18, 6), tint: Color = Color.WHITE) -> StyleBox:
	var tex: Texture2D = asset(filename)
	if tex == null:
		return fallback
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = tex
	style.region_rect = used_rect(filename)
	style.texture_margin_left = margin.x
	style.texture_margin_right = margin.x
	style.texture_margin_top = margin.y
	style.texture_margin_bottom = margin.y
	style.content_margin_left = content.x
	style.content_margin_right = content.x
	style.content_margin_top = content.y
	style.content_margin_bottom = content.y
	style.modulate_color = tint
	return style

## Button art for a flat colour role used across pages.
static func button_art(color: Color) -> String:
	if color == COLOR_GOLD: return "button/button_primary_yellow"
	if color == COLOR_GREEN: return "button/button_ready_green"
	if color == COLOR_RED: return "button/button_danger_red"
	if color == Color("3959b8"): return "button/button_phone_blue"
	if color == Color("7047b9"): return "button/button_account_purple"
	return "button/button_secondary_dark"

## A TextureRect sized to `size` that keeps the art's aspect ratio.
static func picture(filename: String, pos: Vector2, size: Vector2, tint: Color = Color.WHITE) -> TextureRect:
	var rect: TextureRect = TextureRect.new()
	rect.texture = asset(filename)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.position = pos
	rect.size = size
	rect.modulate = tint
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

static func player_color(name: String) -> Color:
	var names: Array[String] = ["red","orange","yellow","green","cyan","blue","purple","pink"]
	var index: int = names.find(name)
	return COLORS[index] if index >= 0 else COLORS[5]
