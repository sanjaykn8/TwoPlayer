class_name GameHud
extends CanvasLayer
## The gameplay HUD. One CanvasLayer in the main window, drawn once above the camera rig's
## SubViewports (it is never inside a viewport), so shared view, side-by-side split and
## stacked split all show exactly one HUD in the same places:
##   top-left   Player One (tag, portrait, hearts, upgrades, timed effects)
##   top-right  Player Two (mirrored)
##   top-centre the shared coin total and, under it in the same panel, world and level
##   bottom     short notices (save failures, recoveries) and a brief "Saved" mark; the boss
##              health bar while a mini-boss or the final boss is fighting
## Everything updates from signals; a new run (RunState.reset) is picked up automatically.

const COIN_SHEET := preload("res://assets/sprites/coin.png")
const NOTICE_SECONDS := 3.5
const SAVED_SECONDS := 1.5

var campaign: CampaignGame
var run: RunState
var panels: Array[PlayerStatusPanel] = []
var coin_label: Label
var location_label: Label
var notice_label: Label
var saved_label: Label
var boss_bar: BossBar

var _root: Control
var _notice_left := 0.0
var _saved_left := 0.0


func _init() -> void:
	layer = 10
	name = "GameHud"


func _ready() -> void:
	add_to_group(BossEnemy.LISTENERS)
	_build()
	var game := get_parent() as CampaignGame
	if game != null:
		bind_campaign(game)
	else:
		_bind_run()


func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.theme = UiTheme.theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	for id in [1, 2]:
		var panel := PlayerStatusPanel.new(id)
		_root.add_child(panel)
		if id == 1:
			panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
			panel.position = Vector2(4, 4)
		else:
			panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
			panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			panel.offset_right = -4
			panel.offset_top = 4
		panels.append(panel)

	var center := VBoxContainer.new()
	center.name = "Center"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_theme_constant_override(&"separation", 1)
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.offset_top = 4
	_root.add_child(center)
	var coin_panel := PanelContainer.new()
	coin_panel.name = "Coins"
	coin_panel.theme_type_variation = &"HudPanel"
	coin_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center.add_child(coin_panel)
	var center_box := VBoxContainer.new()
	center_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_box.add_theme_constant_override(&"separation", 1)
	coin_panel.add_child(center_box)
	var coin_row := HBoxContainer.new()
	coin_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_row.alignment = BoxContainer.ALIGNMENT_CENTER
	coin_row.add_theme_constant_override(&"separation", 3)
	center_box.add_child(coin_row)
	var coin_icon := TextureRect.new()
	coin_icon.texture = UiTheme.sprite(COIN_SHEET, Rect2(0, 0, 16, 16))
	coin_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_row.add_child(coin_icon)
	coin_label = MenuScreen.label("0", &"HudLabel")
	coin_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin_label.add_theme_color_override(&"font_color", UiTheme.GOLD)
	coin_row.add_child(coin_label)
	location_label = MenuScreen.label("", &"HudLabel", HORIZONTAL_ALIGNMENT_CENTER)
	location_label.add_theme_color_override(&"font_color", UiTheme.TEXT_DIM.lightened(0.15))
	center_box.add_child(location_label)

	notice_label = MenuScreen.label("", &"HudLabel", HORIZONTAL_ALIGNMENT_CENTER)
	notice_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	notice_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	notice_label.offset_top = -16
	notice_label.offset_bottom = -6
	notice_label.visible = false
	_root.add_child(notice_label)
	saved_label = MenuScreen.label("Saved", &"HudLabel", HORIZONTAL_ALIGNMENT_RIGHT)
	saved_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	saved_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	saved_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	saved_label.offset_right = -6
	saved_label.offset_bottom = -6
	saved_label.add_theme_color_override(&"font_color", UiTheme.TEXT_DIM)
	saved_label.visible = false
	_root.add_child(saved_label)
	boss_bar = BossBar.new()
	boss_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	boss_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	boss_bar.offset_left = -BossBar.WIDTH * 0.5
	boss_bar.offset_right = BossBar.WIDTH * 0.5
	boss_bar.offset_top = -40
	boss_bar.offset_bottom = -22
	_root.add_child(boss_bar)


func bind_campaign(game: CampaignGame) -> void:
	campaign = game
	game.level_started.connect(_on_level_started)
	game.notice.connect(show_notice)
	game.autosaved.connect(_on_autosaved)
	_bind_run()


## Re-reads the knights of the current level (after a level load, restart or team wipe).
func _on_level_started(_level_id: String) -> void:
	boss_bar.visible = false
	_bind_run()


# --- Boss bar (BossEnemy.LISTENERS) ---------------------------------------------------

func on_boss_engaged(boss: BossEnemy) -> void:
	boss_bar.show_boss(boss.boss_name(), boss.health, boss.stats.max_health)


func on_boss_health(_boss: BossEnemy, current: int, maximum: int) -> void:
	boss_bar.set_health(current, maximum)


func on_boss_defeated(_boss: BossEnemy) -> void:
	boss_bar.defeated()


func _bind_run() -> void:
	if run != null and run.coins_changed.is_connected(_on_coins_changed):
		run.coins_changed.disconnect(_on_coins_changed)
	run = RunState.current()
	run.coins_changed.connect(_on_coins_changed)
	_on_coins_changed(run.coins)
	for panel in panels:
		panel.bind(run.player(panel.player_id), _knight_health(panel.player_id))
	var level_id := run.campaign.level_id
	location_label.text = LevelCatalog.location_title(level_id)


func _knight_health(player_id: int) -> HealthComponent:
	if campaign == null:
		return null
	for knight in campaign.knights:
		if is_instance_valid(knight) and knight.player_id() == player_id:
			return knight.health
	return null


func _process(delta: float) -> void:
	if run != RunState.current():
		_bind_run()
	for panel in panels:
		panel.tick()
	if _notice_left > 0.0:
		_notice_left -= delta
		notice_label.visible = _notice_left > 0.0
	if _saved_left > 0.0:
		_saved_left -= delta
		saved_label.visible = _saved_left > 0.0


func _on_coins_changed(total: int) -> void:
	coin_label.text = str(total)


func show_notice(text: String) -> void:
	notice_label.text = text
	notice_label.visible = true
	_notice_left = NOTICE_SECONDS


func _on_autosaved(_reason: String, ok: bool) -> void:
	if ok:
		saved_label.visible = true
		_saved_left = SAVED_SECONDS


func panel(player_id: int) -> PlayerStatusPanel:
	return panels[player_id - 1]
