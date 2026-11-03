class_name PlayerStatusPanel
extends PanelContainer
## One knight's HUD block: "P1"/"P2" tag and portrait in that knight's colours, hearts and
## "current/max", permanent upgrades that differ from the base values, and one indicator
## per active timed effect. Player Two's panel is mirrored to the right edge.
##
## Updates come from signals (health_changed, PlayerStats.changed, PlayerEffects.changed);
## the only per-frame work is refreshing the seconds shown on active effect indicators.

const KNIGHT_SHEET := preload("res://assets/sprites/knight.png")
const PALETTE_SHADER := preload("res://resources/shaders/knight_palette.gdshader")

var player_id := 1
var stats: PlayerStats
var health: HealthComponent

var tag: Label
var portrait: TextureRect
var hearts: HealthDisplay
var health_text: Label
var upgrades: Label
var effects_row: HBoxContainer

var _indicators := {}


func _init(id: int) -> void:
	player_id = id
	name = "P%dPanel" % id
	theme_type_variation = &"HudPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var right := id == 2
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override(&"separation", 4)
	top.alignment = BoxContainer.ALIGNMENT_END if right else BoxContainer.ALIGNMENT_BEGIN
	box.add_child(top)
	tag = MenuScreen.label("P%d" % id, &"HudLabel")
	tag.add_theme_font_override(&"font", UiTheme.FONT_BOLD)
	tag.add_theme_color_override(&"font_color", UiTheme.player_color(id))
	portrait = TextureRect.new()
	portrait.texture = UiTheme.sprite(KNIGHT_SHEET, Rect2(8, 12, 16, 16))
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var profile: KnightProfile = load("res://resources/players/p%d_profile.tres" % id)
	var material := ShaderMaterial.new()
	material.shader = PALETTE_SHADER
	material.set_shader_parameter(&"target_tunic", profile.tunic_color)
	material.set_shader_parameter(&"target_plume", profile.plume_color)
	portrait.material = material
	hearts = HealthDisplay.new()
	hearts.right_aligned = right
	hearts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	health_text = MenuScreen.label("", &"HudLabel")
	var order: Array[Control] = [tag, portrait, hearts, health_text]
	if right:
		order.reverse()
	for c in order:
		top.add_child(c)

	upgrades = MenuScreen.label("", &"HudLabel", HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT)
	upgrades.add_theme_color_override(&"font_color", UiTheme.TEXT_DIM.lightened(0.2))
	box.add_child(upgrades)
	effects_row = HBoxContainer.new()
	effects_row.name = "Effects"
	effects_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects_row.add_theme_constant_override(&"separation", 6)
	effects_row.alignment = BoxContainer.ALIGNMENT_END if right else BoxContainer.ALIGNMENT_BEGIN
	box.add_child(effects_row)


## Connects to this player's run record and, when present, the knight's live health.
func bind(record: PlayerStats, knight_health: HealthComponent) -> void:
	unbind()
	stats = record
	health = knight_health
	if stats != null:
		stats.changed.connect(_refresh_record)
		stats.effects.changed.connect(_rebuild_effects)
	if health != null:
		health.health_changed.connect(_on_health_changed)
	_refresh_record()
	_rebuild_effects()


func unbind() -> void:
	if stats != null:
		if stats.changed.is_connected(_refresh_record):
			stats.changed.disconnect(_refresh_record)
		if stats.effects.changed.is_connected(_rebuild_effects):
			stats.effects.changed.disconnect(_rebuild_effects)
	if health != null and is_instance_valid(health) and health.health_changed.is_connected(_on_health_changed):
		health.health_changed.disconnect(_on_health_changed)
	stats = null
	health = null


## Per frame: only the seconds on active effect indicators.
func tick() -> void:
	if stats == null:
		return
	for id: StringName in _indicators:
		(_indicators[id] as EffectIndicator).update_from(stats.effects)


func indicator(effect: StringName) -> EffectIndicator:
	return _indicators.get(effect)


func indicator_ids() -> Array:
	return _indicators.keys()


func _on_health_changed(current: int, maximum: int) -> void:
	_show_health(current, maximum)


func _refresh_record() -> void:
	if stats == null:
		_show_health(0, 0)
		upgrades.text = ""
		return
	if health != null and is_instance_valid(health):
		_show_health(health.current_health, health.max_health)
	else:
		_show_health(stats.current_health, stats.max_health())
	upgrades.text = upgrade_summary(stats)
	upgrades.visible = upgrades.text != ""


func _show_health(current: int, maximum: int) -> void:
	hearts.set_health(current, maximum)
	if maximum > 0 and current <= 0:
		health_text.text = "DOWN"
		health_text.add_theme_color_override(&"font_color", UiTheme.DANGER)
	else:
		health_text.text = "%d/%d" % [current, maximum]
		health_text.remove_theme_color_override(&"font_color")


## Permanent upgrades that differ from the starting values ("" when none).
static func upgrade_summary(record: PlayerStats) -> String:
	var parts := PackedStringArray()
	if record.attack_power_bonus > 0:
		parts.append("PWR %d" % record.attack_power())
	if record.range_bonus > 0.0:
		parts.append("RANGE +%d%%" % roundi(record.range_bonus * 100.0))
	if record.speed_bonus > 0.0:
		parts.append("SPEED +%d%%" % roundi(record.speed_bonus * 100.0))
	if record.poison_seconds > 0.0:
		parts.append("POISON %ds" % roundi(record.poison_seconds))
	return "  ".join(parts)


## Adds and removes indicators only when the set of active effects changes.
func _rebuild_effects() -> void:
	var active: Array[StringName] = stats.effects.active_ids() if stats != null else []
	for id: StringName in _indicators.keys():
		if not active.has(id):
			var old: EffectIndicator = _indicators[id]
			_indicators.erase(id)
			effects_row.remove_child(old)
			old.queue_free()
	for id in active:
		if not _indicators.has(id):
			var ind := EffectIndicator.new(id)
			_indicators[id] = ind
			effects_row.add_child(ind)
	effects_row.visible = not _indicators.is_empty()
	tick()
