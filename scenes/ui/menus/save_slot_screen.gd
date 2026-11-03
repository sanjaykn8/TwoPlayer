class_name SaveSlotScreen
extends MenuScreen
## The four save slots, in one of three modes:
##   NEW_GAME  pick a slot for a new campaign. An occupied or damaged slot asks for explicit
##             confirmation first; nothing is ever overwritten silently.
##   CONTINUE  pick a campaign to resume. Only ACTIVE and RECOVERED slots can be chosen; a
##             lost (INVALIDATED), damaged or empty slot is shown but cannot be selected.
##   MANAGE    the Save Slots screen: focus a slot to see its details and actions
##             (Load, New Campaign, Delete, Repair). Deleting always asks first.
## Slot information comes only from SaveManager.get_slot_metadata() through GameApp; every
## change goes through GameApp / SaveManager, one slot at a time.

enum Mode { NEW_GAME, CONTINUE, MANAGE }

const TITLES := {
	Mode.NEW_GAME: ["NEW GAME", "Choose a slot for the new campaign."],
	Mode.CONTINUE: ["CONTINUE", "Choose a campaign to resume."],
	Mode.MANAGE: ["SAVE SLOTS", "Select a slot to see what you can do with it."],
}

var mode := Mode.MANAGE
var cards: Array[SaveSlotCard] = []
var selected_slot := 0
var message: Label
var back_button: UiButton
var actions := {}
var empty_note: Label
var new_game_button: UiButton

var _action_row: HBoxContainer


static func create(screen_mode: Mode) -> SaveSlotScreen:
	var s := (load("res://scenes/ui/menus/save_slot_screen.tscn") as PackedScene).instantiate() as SaveSlotScreen
	s.mode = screen_mode
	return s


func build() -> void:
	name = "SaveSlotScreen"
	add_child(MenuScreen.dimmer(1.0))
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 4)
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.offset_top = 12
	add_child(column)
	column.add_child(MenuScreen.label(TITLES[mode][0], &"TitleLabel", HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(MenuScreen.label(TITLES[mode][1], &"DimLabel", HORIZONTAL_ALIGNMENT_CENTER))
	for slot in range(1, 5):
		var card := SaveSlotCard.new(slot)
		card.pressed.connect(_on_card_pressed.bind(slot))
		card.focus_entered.connect(_on_card_focused.bind(slot))
		column.add_child(card)
		cards.append(card)

	if mode == Mode.MANAGE:
		_action_row = HBoxContainer.new()
		_action_row.name = "Actions"
		_action_row.alignment = BoxContainer.ALIGNMENT_CENTER
		_action_row.add_theme_constant_override(&"separation", 6)
		column.add_child(_action_row)
		for spec: Array in [["load", "Load", &""], ["new", "New Campaign", &""], ["delete", "Delete", &"DangerButton"], ["repair", "Repair", &""]]:
			var b := UiButton.new(spec[1], spec[2])
			b.name = str(spec[0]).to_pascal_case()
			b.custom_minimum_size.x = 92
			b.pressed.connect(_on_action.bind(spec[0]))
			_action_row.add_child(b)
			actions[spec[0]] = b

	empty_note = MenuScreen.label("No campaign can be continued. Start a New Game instead.", &"", HORIZONTAL_ALIGNMENT_CENTER)
	empty_note.visible = false
	column.add_child(empty_note)
	if mode == Mode.CONTINUE:
		new_game_button = UiButton.new("New Game")
		new_game_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		new_game_button.custom_minimum_size.x = 120
		new_game_button.visible = false
		new_game_button.pressed.connect(func() -> void:
			if app != null:
				app.open_slot_screen(Mode.NEW_GAME, self))
		column.add_child(new_game_button)
	message = MenuScreen.label("", &"", HORIZONTAL_ALIGNMENT_CENTER)
	message.name = "Message"
	column.add_child(message)
	back_button = UiButton.new("Back")
	back_button.name = "Back"
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_button.custom_minimum_size.x = 120
	back_button.confirm_cue = &"ui_cancel"
	back_button.pressed.connect(close)
	column.add_child(back_button)
	refresh()


## Re-reads all four slots and updates cards, actions and focus links.
func refresh() -> void:
	for card in cards:
		card.update_meta(app.slot_metadata(card.slot) if app != null else {"status": "EMPTY"})
		var usable := mode != Mode.CONTINUE or card.is_loadable()
		card.disabled = not usable
		card.focus_mode = Control.FOCUS_ALL if usable else Control.FOCUS_NONE
	var any := cards.any(func(c: SaveSlotCard) -> bool: return not c.disabled)
	empty_note.visible = mode == Mode.CONTINUE and not any
	if new_game_button != null:
		new_game_button.visible = empty_note.visible
	if selected_slot == 0:
		for card in cards:
			if not card.disabled:
				selected_slot = card.slot
				break
	_update_actions()
	_link()


func first_focus() -> Control:
	for card in cards:
		if card.slot == selected_slot and not card.disabled:
			return card
	if new_game_button != null and new_game_button.visible:
		return new_game_button
	return back_button


func card(slot: int) -> SaveSlotCard:
	return cards[slot - 1]


func _link() -> void:
	var column: Array = []
	for c in cards:
		if not c.disabled:
			column.append(c)
	if new_game_button != null and new_game_button.visible:
		column.append(new_game_button)
	column.append(back_button)
	MenuScreen.link_vertical(column)
	if mode == Mode.MANAGE:
		var row: Array = []
		for key in ["load", "new", "delete", "repair"]:
			if not (actions[key] as UiButton).disabled:
				row.append(actions[key])
		MenuScreen.link_horizontal(row)
		var card_node := card(selected_slot) if selected_slot > 0 else null
		for b: UiButton in row:
			if card_node != null:
				b.focus_neighbor_top = b.get_path_to(card_node)
			b.focus_neighbor_bottom = b.get_path_to(back_button)


func _update_actions() -> void:
	if mode != Mode.MANAGE:
		return
	var status := card(selected_slot).status() if selected_slot > 0 else "EMPTY"
	var loadable := status == "VALID" or status == "RECOVERED"
	_enable("load", loadable)
	_enable("new", selected_slot > 0)
	_enable("delete", status != "EMPTY")
	_enable("repair", status == "RECOVERED")


func _enable(key: String, on: bool) -> void:
	var b: UiButton = actions[key]
	b.disabled = not on
	b.focus_mode = Control.FOCUS_ALL if on else Control.FOCUS_NONE


func _on_card_focused(slot: int) -> void:
	if mode == Mode.MANAGE and slot != selected_slot:
		selected_slot = slot
		_update_actions()
		_link()
	selected_slot = slot


func _on_card_pressed(slot: int) -> void:
	selected_slot = slot
	match mode:
		Mode.NEW_GAME:
			new_campaign(slot)
		Mode.CONTINUE:
			if card(slot).is_loadable() and app != null:
				app.continue_campaign(slot)
		Mode.MANAGE:
			_update_actions()
			_link()
			for key in ["load", "new", "delete", "repair"]:
				if not (actions[key] as UiButton).disabled:
					UiButton.focus_quietly(actions[key])
					return


func _on_action(action: String) -> void:
	match action:
		"load":
			if app != null and card(selected_slot).is_loadable():
				app.continue_campaign(selected_slot)
		"new":
			new_campaign(selected_slot)
		"delete":
			delete_slot(selected_slot)
		"repair":
			_repair(selected_slot)


## Starts a new campaign in `slot`, asking first if that would replace anything.
func new_campaign(slot: int) -> void:
	var c := card(slot)
	var where := LevelCatalog.location_title(str(c.meta.get("level_id", "")))
	match c.status():
		"VALID", "RECOVERED":
			_ask("Overwrite slot %d?" % slot,
				"Slot %d holds a campaign (%s, %d coins). Starting a new campaign erases it permanently. The other slots are not affected." % [slot, where, int(c.meta.get("coins", 0))],
				"Overwrite", _start_new.bind(slot))
		"CORRUPTED":
			_ask("Replace damaged slot %d?" % slot,
				"Slot %d is damaged and cannot be loaded. A new campaign will replace it (a copy of the damaged file is kept). The other slots are not affected." % slot,
				"Replace", _start_new.bind(slot))
		_:
			_start_new(slot)


func delete_slot(slot: int) -> void:
	var c := card(slot)
	var what := "the campaign in slot %d (%s, %d coins)" % [slot, LevelCatalog.location_title(str(c.meta.get("level_id", ""))), int(c.meta.get("coins", 0))] \
		if c.is_loadable() else "the %s files of slot %d" % [c.status_word().to_lower(), slot]
	_ask("Delete slot %d?" % slot, "Delete %s? This cannot be undone. The other slots are not affected." % what,
		"Delete", func() -> void:
			var err: Error = app.delete_slot(slot) if app != null else ERR_UNCONFIGURED
			_say("Slot %d deleted." % slot if err == OK else "Slot %d could not be deleted completely." % slot, err == OK)
			refresh())


func _repair(slot: int) -> void:
	var err: Error = app.repair_slot(slot) if app != null else ERR_UNCONFIGURED
	_say("Slot %d was restored from its backup." % slot if err == OK else "Slot %d could not be repaired: %s" % [slot, app.saves.last_error if app != null else ""], err == OK)
	refresh()
	UiButton.focus_quietly(card(slot))


func _start_new(slot: int) -> void:
	if app != null:
		app.start_new_campaign(slot, true)


func _ask(title: String, text: String, confirm: String, on_yes: Callable) -> ConfirmDialog:
	var dialog := ConfirmDialog.create(title, text, confirm, "Cancel", true)
	dialog.confirmed.connect(on_yes)
	stack.push(dialog, app)
	return dialog


func _say(text: String, ok: bool) -> void:
	message.text = text
	message.add_theme_color_override(&"font_color", UiTheme.OK_GREEN if ok else UiTheme.DANGER)
