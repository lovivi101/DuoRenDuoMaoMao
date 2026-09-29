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

static func player_color(name: String) -> Color:
	var names: Array[String] = ["red","orange","yellow","green","cyan","blue","purple","pink"]
	var index: int = names.find(name)
	return COLORS[index] if index >= 0 else COLORS[5]
