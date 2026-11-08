class_name UiTheme
extends RefCounted
## The game's single UI look: palette, fonts and the shared Theme every menu and the HUD use.
## Pixel Operator 8 at its native sizes (8 and 16 px) on the 640x360 canvas; flat 1 px
## borders, no rounding or anti-aliasing, so everything stays sharp at integer scales.
## Dark-fantasy palette: near-black violet panels, parchment text, gold for focus, and one
## colour per knight (always paired with a "P1"/"P2" label, never colour alone).

const FONT := preload("res://assets/fonts/PixelOperator8.ttf")
const FONT_BOLD := preload("res://assets/fonts/PixelOperator8-Bold.ttf")
const ICONS := preload("res://assets/created/ui_icons.png")

const BG := Color("0c0a12")
const PANEL := Color(0.075, 0.063, 0.106, 0.94)
const PANEL_LIGHT := Color("221c30")
const BORDER := Color("3d3352")
const TEXT := Color("e9e0cc")
const TEXT_DIM := Color("8c8399")
const GOLD := Color("e3b450")
const DANGER := Color("d4574b")
const WARNING := Color("e39a3c")
const OK_GREEN := Color("7fcf6e")
const P1 := Color("ff6b6b")
const P2 := Color("6a9cff")
const SHADOW := Color(0, 0, 0, 0.85)

const SIZE_TEXT := 8
const SIZE_TITLE := 16

## Icon cells in ui_icons.png (8x8 each).
const ICON_HEART := Rect2(0, 0, 8, 8)
const ICON_HEART_EMPTY := Rect2(8, 0, 8, 8)
const ICON_GRABBER := Rect2(16, 0, 8, 8)
const ICON_ARROW := Rect2(24, 0, 8, 8)

static var _theme: Theme
static var _atlas := {}


static func player_color(player_id: int) -> Color:
	return P1 if player_id == 1 else P2


## A cached AtlasTexture for one cell of ui_icons.png.
static func icon(region: Rect2) -> AtlasTexture:
	if not _atlas.has(region):
		var tex := AtlasTexture.new()
		tex.atlas = ICONS
		tex.region = region
		_atlas[region] = tex
	return _atlas[region]


## A cached AtlasTexture for any sprite-sheet region (fruit, jars, coin, knight portrait).
static func sprite(texture: Texture2D, region: Rect2) -> AtlasTexture:
	var key := [texture.resource_path, region]
	if not _atlas.has(key):
		var tex := AtlasTexture.new()
		tex.atlas = texture
		tex.region = region
		tex.filter_clip = true
		_atlas[key] = tex
	return _atlas[key]


static func theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


static func box(bg: Color, border: Color, width := 1, margin_h := 6, margin_v := 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.anti_aliasing = false
	s.content_margin_left = margin_h
	s.content_margin_right = margin_h
	s.content_margin_top = margin_v
	s.content_margin_bottom = margin_v
	return s


static func _build() -> Theme:
	var t := Theme.new()
	t.default_font = FONT
	t.default_font_size = SIZE_TEXT

	t.set_color(&"font_color", &"Label", TEXT)
	# Title: bold 16 px, gold.
	t.set_type_variation(&"TitleLabel", &"Label")
	t.set_font(&"font", &"TitleLabel", FONT_BOLD)
	t.set_font_size(&"font_size", &"TitleLabel", SIZE_TITLE)
	t.set_color(&"font_color", &"TitleLabel", GOLD)
	t.set_color(&"font_shadow_color", &"TitleLabel", SHADOW)
	t.set_constant(&"shadow_offset_x", &"TitleLabel", 1)
	t.set_constant(&"shadow_offset_y", &"TitleLabel", 1)
	# Section heading: bold 8 px.
	t.set_type_variation(&"HeaderLabel", &"Label")
	t.set_font(&"font", &"HeaderLabel", FONT_BOLD)
	t.set_color(&"font_color", &"HeaderLabel", TEXT)
	t.set_type_variation(&"DimLabel", &"Label")
	t.set_color(&"font_color", &"DimLabel", TEXT_DIM)
	# HUD text: shadowed so it reads over any background.
	t.set_type_variation(&"HudLabel", &"Label")
	t.set_color(&"font_color", &"HudLabel", TEXT)
	t.set_color(&"font_shadow_color", &"HudLabel", SHADOW)
	t.set_constant(&"shadow_offset_x", &"HudLabel", 1)
	t.set_constant(&"shadow_offset_y", &"HudLabel", 1)

	t.set_stylebox(&"panel", &"PanelContainer", box(PANEL, BORDER, 1, 8, 6))
	t.set_stylebox(&"panel", &"Panel", box(PANEL, BORDER, 1, 8, 6))
	t.set_type_variation(&"HudPanel", &"PanelContainer")
	t.set_stylebox(&"panel", &"HudPanel", box(Color(0.05, 0.04, 0.08, 0.72), BORDER, 1, 4, 3))
	t.set_type_variation(&"DialogPanel", &"PanelContainer")
	t.set_stylebox(&"panel", &"DialogPanel", box(PANEL, GOLD.darkened(0.35), 1, 12, 10))

	_button(t, &"Button", TEXT)
	t.set_type_variation(&"DangerButton", &"Button")
	_button(t, &"DangerButton", DANGER)
	t.set_type_variation(&"SlotCard", &"Button")
	_button(t, &"SlotCard", TEXT)
	t.set_stylebox(&"normal", &"SlotCard", box(PANEL, BORDER, 1, 8, 4))
	t.set_stylebox(&"disabled", &"SlotCard", box(Color(PANEL, 0.7), BORDER.darkened(0.3), 1, 8, 4))

	# Sliders: a 3 px track and a pixel grabber.
	var track := box(Color("1a1524"), BORDER, 1, 0, 1)
	t.set_stylebox(&"slider", &"HSlider", track)
	var filled := box(GOLD.darkened(0.45), GOLD.darkened(0.45), 1, 0, 1)
	t.set_stylebox(&"grabber_area", &"HSlider", filled)
	t.set_stylebox(&"grabber_area_highlight", &"HSlider", box(GOLD.darkened(0.2), GOLD.darkened(0.2), 1, 0, 1))
	t.set_icon(&"grabber", &"HSlider", icon(ICON_GRABBER))
	t.set_icon(&"grabber_highlight", &"HSlider", icon(ICON_GRABBER))
	t.set_icon(&"grabber_disabled", &"HSlider", icon(ICON_GRABBER))
	t.set_icon(&"tick", &"HSlider", ImageTexture.new())
	var focus := box(Color(0, 0, 0, 0), GOLD, 1, 0, 0)
	focus.expand_margin_left = 3
	focus.expand_margin_right = 3
	focus.expand_margin_top = 4
	focus.expand_margin_bottom = 4
	t.set_stylebox(&"focus", &"HSlider", focus)

	t.set_constant(&"separation", &"VBoxContainer", 4)
	t.set_constant(&"separation", &"HBoxContainer", 4)
	return t


static func _button(t: Theme, type: StringName, text: Color) -> void:
	t.set_color(&"font_color", type, text)
	t.set_color(&"font_hover_color", type, text.lightened(0.15))
	t.set_color(&"font_focus_color", type, GOLD if type != &"DangerButton" else DANGER.lightened(0.25))
	t.set_color(&"font_pressed_color", type, GOLD.lightened(0.2))
	t.set_color(&"font_hover_pressed_color", type, GOLD.lightened(0.2))
	t.set_color(&"font_disabled_color", type, TEXT_DIM.darkened(0.25))
	t.set_stylebox(&"normal", type, box(PANEL_LIGHT, BORDER))
	t.set_stylebox(&"hover", type, box(PANEL_LIGHT.lightened(0.06), BORDER.lightened(0.25)))
	t.set_stylebox(&"pressed", type, box(PANEL_LIGHT.darkened(0.2), GOLD))
	t.set_stylebox(&"hover_pressed", type, box(PANEL_LIGHT.darkened(0.2), GOLD))
	t.set_stylebox(&"disabled", type, box(Color(PANEL_LIGHT, 0.5), BORDER.darkened(0.3)))
	# Focus: a gold frame drawn over the normal style (UiButton adds a pointer arrow too).
	t.set_stylebox(&"focus", type, box(Color(GOLD, 0.08), GOLD))
