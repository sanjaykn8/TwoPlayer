class_name PauseMenu
extends MenuScreen
## Shown over the frozen game (the whole gameplay tree is paused: knights, slimes, physics,
## platforms, puzzle timers, timed effects and play time all stop; music plays quieter).
## Resume / Esc continues. Restart Campaign and leaving always go through GameApp:
## restarting asks first and replaces the campaign in this slot (never a team wipe);
## Save and Quit and Return to Main Menu save first and leave only after the save succeeded.

var buttons := {}
var info: Label
var status: Label


func build() -> void:
	name = "PauseMenu"
	add_child(MenuScreen.dimmer(0.55))
	var box := MenuScreen.centered_panel(self, 200)
	box.add_child(MenuScreen.label("PAUSED", &"TitleLabel", HORIZONTAL_ALIGNMENT_CENTER))
	info = MenuScreen.label("", &"DimLabel", HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(info)
	for spec: Array in [
			["resume", "Resume", &""], ["settings", "Settings", &""],
			["restart", "Restart Campaign", &"DangerButton"], ["save_quit", "Save and Quit", &""],
			["main_menu", "Return to Main Menu", &""]]:
		var b := UiButton.new(spec[1], spec[2])
		b.name = str(spec[0]).to_pascal_case()
		b.pressed.connect(_on_pressed.bind(spec[0]))
		box.add_child(b)
		buttons[spec[0]] = b
	status = MenuScreen.wrapped("", 200, &"", HORIZONTAL_ALIGNMENT_CENTER)
	status.add_theme_color_override(&"font_color", UiTheme.DANGER)
	box.add_child(status)
	MenuScreen.link_vertical(buttons.values())
	if app != null and app.campaign != null:
		info.text = "Slot %d  -  %s" % [app.campaign.slot, LevelCatalog.location_title(RunState.current().campaign.level_id)]


func first_focus() -> Control:
	return buttons["resume"]


func back() -> void:
	Sfx.cue(&"ui_cancel", self, true)
	if app != null:
		app.resume_game()


## Shows why leaving failed (the game stays paused and nothing is lost).
func show_error(text: String) -> void:
	status.text = text


func _on_pressed(action: String) -> void:
	if app == null:
		return
	status.text = ""
	match action:
		"resume":
			app.resume_game()
		"settings":
			app.open_settings()
		"restart":
			var dialog := ConfirmDialog.create("Restart campaign?",
				"Restarting will erase the current campaign progress for this slot. Both knights start again from the first level with no coins or upgrades. The other slots are not affected.",
				"Restart", "Cancel", true)
			dialog.confirmed.connect(app.restart_campaign)
			stack.push(dialog, app)
		"save_quit":
			app.save_and_quit()
		"main_menu":
			app.return_to_menu()
