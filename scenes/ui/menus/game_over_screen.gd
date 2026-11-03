class_name GameOverScreen
extends MenuScreen
## The team-wipe presentation. It opens the moment a knight dies (the run is already being
## invalidated by CampaignGame / SaveManager) and fades in over the frozen world. The choices
## appear only after CampaignGame reports the wipe finished: the old campaign is invalidated
## on disk and the fresh run (first level) exists in the same slot.
##   Begin Again  play the fresh run.
##   Main Menu    leave; Continue will offer the fresh run, never the lost one.
## If the old campaign could not be invalidated (storage failure), the only choice is to quit.

enum State { WIPING, READY, FAILED }

var state := State.WIPING
var title_label: Label
var body: Label
var detail: Label
var begin_button: UiButton
var menu_button: UiButton
var quit_button: UiButton

var _shade: ColorRect
var _row: HBoxContainer


func build() -> void:
	name = "GameOverScreen"
	_shade = MenuScreen.dimmer(0.0)
	add_child(_shade)
	var box := MenuScreen.centered_panel(self, 330, &"DialogPanel")
	title_label = MenuScreen.label("RUN LOST", &"TitleLabel", HORIZONTAL_ALIGNMENT_CENTER)
	title_label.add_theme_color_override(&"font_color", UiTheme.DANGER)
	title_label.add_theme_font_size_override(&"font_size", 32)
	box.add_child(title_label)
	body = MenuScreen.wrapped("A knight has fallen, so both knights lose this run: its coins, upgrades and progress are gone.", 330, &"", HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(body)
	detail = MenuScreen.wrapped("Clearing the lost run...", 330, &"DimLabel", HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(detail)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override(&"separation", 16)
	box.add_child(_row)
	begin_button = UiButton.new("Begin Again")
	begin_button.name = "BeginAgain"
	begin_button.custom_minimum_size.x = 110
	begin_button.pressed.connect(func() -> void:
		if app != null:
			app.begin_again())
	menu_button = UiButton.new("Main Menu")
	menu_button.name = "MainMenu"
	menu_button.custom_minimum_size.x = 110
	menu_button.pressed.connect(func() -> void:
		if app != null:
			app.return_to_menu())
	quit_button = UiButton.new("Quit Game", &"DangerButton")
	quit_button.name = "Quit"
	quit_button.custom_minimum_size.x = 110
	quit_button.pressed.connect(func() -> void:
		if app != null:
			app.quit_game())
	for b in [begin_button, menu_button, quit_button]:
		_row.add_child(b)
	_show_buttons([])
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_shade, ^"color:a", 0.78, 0.6)


func first_focus() -> Control:
	return begin_button if begin_button.visible else quit_button if quit_button.visible else null


## Escape cannot skip the choice.
func back() -> void:
	pass


## The wipe finished: the fresh run exists (saved = written to disk).
func show_ready(slot: int, saved: bool) -> void:
	state = State.READY
	var start := LevelCatalog.location_title(LevelCatalog.FIRST_LEVEL)
	detail.text = "A new run begins in slot %d at %s." % [slot, start] if saved \
		else "A new run begins in slot %d at %s. It could not be saved yet; the lost run stays erased." % [slot, start]
	_show_buttons([begin_button, menu_button])


## The lost campaign could not be invalidated: halt (never offer to keep playing it).
func show_failed(reason: String) -> void:
	state = State.FAILED
	title_label.text = "STORAGE ERROR"
	body.text = "The lost run could not be cleared from the save folder (%s). The game is halted so the lost run cannot be continued." % reason
	detail.text = "Check that the disk is writable, then start the game again."
	_show_buttons([quit_button])


func _show_buttons(visible_buttons: Array) -> void:
	for b: UiButton in [begin_button, menu_button, quit_button]:
		b.visible = visible_buttons.has(b)
	MenuScreen.link_horizontal(visible_buttons)
	if is_top() and not visible_buttons.is_empty():
		UiButton.focus_quietly(visible_buttons[0])
