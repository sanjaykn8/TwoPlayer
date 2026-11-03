class_name VictoryScreen
extends MenuScreen
## Campaign-complete presentation with the run's real statistics (from RunState, never made
## up): levels completed, shared coins, play time, items found, and each knight's health and
## upgrades. CampaignGame emits campaign_completed after the last catalog level; GameApp then
## opens this screen. While the catalog is the development campaign the screen says so, and a
## development preview never claims a finished campaign.

var run: RunState
var stats_grid: GridContainer
var menu_button: UiButton
var preview := false


func build() -> void:
	name = "VictoryScreen"
	if run == null:
		run = RunState.current()
	add_child(MenuScreen.dimmer(0.85))
	var box := MenuScreen.centered_panel(self, 340, &"DialogPanel")
	var title := MenuScreen.label("VICTORY", &"TitleLabel", HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_font_size_override(&"font_size", 32)
	box.add_child(title)
	if preview:
		var note := MenuScreen.label("DEVELOPMENT PREVIEW of this screen. The campaign is not finished.", &"", HORIZONTAL_ALIGNMENT_CENTER)
		note.add_theme_color_override(&"font_color", UiTheme.WARNING)
		box.add_child(note)
	else:
		box.add_child(MenuScreen.label("Congratulations! Both knights reached the end of the campaign.", &"", HORIZONTAL_ALIGNMENT_CENTER))
		if LevelCatalog.DEVELOPMENT_CAMPAIGN:
			box.add_child(MenuScreen.label("Development campaign: only the test levels exist so far.", &"DimLabel", HORIZONTAL_ALIGNMENT_CENTER))
	stats_grid = GridContainer.new()
	stats_grid.name = "Stats"
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override(&"h_separation", 16)
	stats_grid.add_theme_constant_override(&"v_separation", 3)
	stats_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(stats_grid)
	for row: Array in summary(run):
		stats_grid.add_child(MenuScreen.label(row[0], &"DimLabel"))
		stats_grid.add_child(MenuScreen.label(row[1]))
	menu_button = UiButton.new("Main Menu")
	menu_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu_button.custom_minimum_size.x = 120
	menu_button.pressed.connect(func() -> void:
		if app != null:
			app.return_to_menu())
	box.add_child(menu_button)
	Sfx.cue(&"victory", self, true)


func first_focus() -> Control:
	return menu_button


func back() -> void:
	UiButton.focus_quietly(menu_button)


## The run's final numbers as [caption, value] rows.
static func summary(r: RunState) -> Array:
	var rows := [
		["Status", "Campaign complete" if r.campaign.flags.get("finished", false) else "In progress"],
		["Levels completed", "%d of %d" % [r.campaign.completed_levels.size(), LevelCatalog.all_levels().size()]],
		["Coins", str(r.coins)],
		["Play time", SaveSlotCard.format_playtime(r.campaign.playtime)],
		["Jars and fruit found", str(r.collected.size())],
	]
	for id in RunState.PLAYER_IDS:
		var p := r.player(id)
		var ups := PlayerStatusPanel.upgrade_summary(p)
		rows.append(["Player %d" % id, "%d/%d health%s" % [p.current_health, p.max_health(), ("  " + ups) if ups != "" else ""]])
	return rows
