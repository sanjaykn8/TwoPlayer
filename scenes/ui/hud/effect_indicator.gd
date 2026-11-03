class_name EffectIndicator
extends HBoxContainer
## One active timed effect of one knight: the pickup's own sprite (yellow fruit, yellow jar,
## or the "?" power tile), a short name, the remaining hit charges where they apply, and the
## seconds left. The text is only rewritten when the shown whole second or charge changes.

const FRUIT_SHEET := preload("res://assets/sprites/fruit.png")
const WORLD_SHEET := preload("res://assets/sprites/world_tileset.png")

## effect id -> [name, sheet, region, colour]
const INFO := {
	PlayerEffects.FRUIT_SHIELD: ["SHIELD", "fruit", Rect2(0, 16, 16, 16), Color(1.0, 0.9, 0.3)],
	PlayerEffects.JAR_LUCK: ["LUCK", "world", Rect2(16, 112, 16, 16), Color(1.0, 0.78, 0.2)],
	PlayerEffects.TILE_SHIELD: ["GUARD", "world", Rect2(0, 32, 16, 16), Color(0.85, 0.95, 1.0)],
	PlayerEffects.SPEED_BOOST: ["SPEED", "world", Rect2(0, 32, 16, 16), Color(0.4, 0.85, 1.0)],
	PlayerEffects.ATTACK_SPEED: ["FAST ATK", "world", Rect2(0, 32, 16, 16), Color(1.0, 0.6, 0.25)],
}

var effect_id: StringName
var _label: Label
var _shown_seconds := -1
var _shown_charges := -1


func _init(effect: StringName) -> void:
	effect_id = effect
	name = String(effect).to_pascal_case()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override(&"separation", 2)
	var info: Array = INFO.get(effect, [String(effect).to_upper(), "world", Rect2(0, 32, 16, 16), Color.WHITE])
	var icon := TextureRect.new()
	icon.texture = UiTheme.sprite(FRUIT_SHEET if info[1] == "fruit" else WORLD_SHEET, info[2])
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	add_child(icon)
	_label = MenuScreen.label("", &"HudLabel")
	_label.add_theme_color_override(&"font_color", info[3])
	add_child(_label)


func update_from(effects: PlayerEffects) -> void:
	var seconds := ceili(effects.remaining(effect_id))
	var charges := effects.charges(effect_id)
	if seconds == _shown_seconds and charges == _shown_charges:
		return
	_shown_seconds = seconds
	_shown_charges = charges
	var name_text: String = INFO.get(effect_id, [String(effect_id).to_upper()])[0]
	_label.text = "%s x%d %ds" % [name_text, charges, seconds] if charges > 0 else "%s %ds" % [name_text, seconds]


func text() -> String:
	return _label.text
