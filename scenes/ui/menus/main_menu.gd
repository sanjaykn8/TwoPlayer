class_name MainMenu
extends MenuScreen
## Title screen: New Game, Continue, Save Slots, Settings, Controls, Exit.
## Continue is disabled (with a hint to start a New Game) when no slot holds a loadable
## campaign; a campaign lost in a team wipe never counts. Every action is delegated to
## GameApp; this screen only presents and navigates.

var buttons := {}
var continue_hint: Label


func build() -> void:
	name = "MainMenu"
	add_child(MenuBackdrop.new())
	var title := MenuScreen.label(app.ui_config.game_title if app != null else "UNTITLED", &"TitleLabel", HORIZONTAL_ALIGNMENT_CENTER)
	title.name = "Title"
	title.add_theme_font_size_override(&"font_size", 32)
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title.offset_top = 34
	add_child(title)
	var subtitle := MenuScreen.label(app.ui_config.subtitle if app != null else "", &"DimLabel", HORIZONTAL_ALIGNMENT_CENTER)
	subtitle.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	subtitle.grow_horizontal = Control.GROW_DIRECTION_BOTH
	subtitle.offset_top = 74
	add_child(subtitle)

	var column := VBoxContainer.new()
	column.name = "Buttons"
	column.add_theme_constant_override(&"separation", 5)
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.offset_top = 104
	column.custom_minimum_size.x = 150
	add_child(column)
	for spec: Array in [
			["new_game", "New Game"], ["continue", "Continue"], ["save_slots", "Save Slots"],
			["settings", "Settings"], ["controls", "Controls"], ["exit", "Exit"]]:
		var b := UiButton.new(spec[1])
		b.name = str(spec[0]).to_pascal_case()
		column.add_child(b)
		buttons[spec[0]] = b
		b.pressed.connect(_on_pressed.bind(spec[0]))
	continue_hint = MenuScreen.label("", &"DimLabel", HORIZONTAL_ALIGNMENT_CENTER)
	continue_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	continue_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	continue_hint.offset_top = 232
	add_child(continue_hint)

	var band := ColorRect.new()
	band.color = Color(UiTheme.BG, 0.85)
	band.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	band.offset_top = -16
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(band)
	var footer := MenuScreen.label("Arrows: move    Enter: select    Esc: back", &"DimLabel", HORIZONTAL_ALIGNMENT_CENTER)
	footer.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	footer.grow_horizontal = Control.GROW_DIRECTION_BOTH
	footer.offset_top = -12
	footer.offset_bottom = -4
	add_child(footer)
	if app != null:
		var version := MenuScreen.label(app.ui_config.version_label, &"DimLabel")
		version.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		version.position = Vector2(6, 4)
		add_child(version)
	refresh()


## Re-checks whether any campaign can be continued (after returning from other screens).
func refresh() -> void:
	var can_continue := app != null and app.any_loadable_slot()
	var b: UiButton = buttons["continue"]
	b.disabled = not can_continue
	b.focus_mode = Control.FOCUS_ALL if can_continue else Control.FOCUS_NONE
	continue_hint.text = "" if can_continue else "No saved campaign yet. Choose New Game to begin."
	var order: Array = []
	for key in ["new_game", "continue", "save_slots", "settings", "controls", "exit"]:
		if not (buttons[key] as UiButton).disabled:
			order.append(buttons[key])
	MenuScreen.link_vertical(order)


func activate() -> void:
	refresh()
	super.activate()


func first_focus() -> Control:
	var c: UiButton = buttons["continue"]
	return c if not c.disabled else buttons["new_game"]


func back() -> void:
	UiButton.focus_quietly(buttons["exit"])


func _on_pressed(action: String) -> void:
	if app == null:
		return
	match action:
		"new_game":
			app.open_slot_screen(SaveSlotScreen.Mode.NEW_GAME)
		"continue":
			app.open_slot_screen(SaveSlotScreen.Mode.CONTINUE)
		"save_slots":
			app.open_slot_screen(SaveSlotScreen.Mode.MANAGE)
		"settings":
			app.open_settings()
		"controls":
			app.open_controls()
		"exit":
			app.request_exit()
