extends GameTestCase
## The four-slot screen: status display, metadata, confirmation before every destructive
## change, slot isolation, recovery and lost campaigns. Folder user://test_saves_ui/.

var app: GameApp


func before_each() -> void:
	UiTestUtil.clean()


func after_each() -> void:
	UiTestUtil.free_app(app)
	await get_tree().process_frame
	UiTestUtil.clean()


func _open(mode: SaveSlotScreen.Mode) -> SaveSlotScreen:
	app = UiTestUtil.make_app(self)
	await get_tree().process_frame
	var screen := app.open_slot_screen(mode)
	await get_tree().process_frame
	return screen


func _lost(slot: int) -> void:
	var manager := SaveManager.new(UiTestUtil.DIR)
	manager.start_new_run(slot)
	manager.invalidate_run_after_death(slot, RunState.current().campaign.campaign_id)
	RunState.reset()


func _recovered(slot: int) -> String:
	var id := UiTestUtil.write_campaign(slot, 9)
	var manager := SaveManager.new(UiTestUtil.DIR)
	manager.load_run(slot)
	manager.save_active_run({}, id)  # a second save, so a backup exists
	UiTestUtil.damage(slot)
	RunState.reset()
	return id


func test_four_slots_with_their_states() -> void:
	UiTestUtil.write_campaign(1, 12, "w1_l2")
	_lost(2)
	UiTestUtil.damage(3)
	_recovered(4)
	var screen := await _open(SaveSlotScreen.Mode.MANAGE)
	assert_eq(screen.cards.size(), 4, "four slots")
	var expected := {1: "ACTIVE", 2: "INVALIDATED", 3: "CORRUPTED", 4: "RECOVERED"}
	for slot: int in expected:
		assert_eq(screen.card(slot).status_word(), expected[slot], "slot %d status" % slot)
		assert_true(screen.card(slot)._badge.text.contains(expected[slot]), "slot %d shows the word %s" % [slot, expected[slot]])
	assert_true(screen.card(3)._detail.text.contains("damaged"), "corruption warning")
	assert_true(screen.card(2)._detail.text.contains("team wipe"), "lost campaign explained")
	assert_true(screen.card(4)._detail.text.contains("backup"), "recovery explained")


func test_empty_and_occupied_metadata() -> void:
	UiTestUtil.write_campaign(2, 31, "w1_l2")
	var screen := await _open(SaveSlotScreen.Mode.MANAGE)
	for slot in [1, 3, 4]:
		assert_eq(screen.card(slot).status_word(), "EMPTY", "slot %d empty" % slot)
		assert_false(screen.card(slot)._stats_row.visible, "no stats for an empty slot")
	var c := screen.card(2)
	assert_eq(c.status_word(), "ACTIVE", "occupied")
	assert_eq(c._title.text, "SLOT 2", "slot number")
	assert_eq(c._location.text, "World 1 - Level 2", "world and level from the catalog")
	assert_eq(c._coins.text, "31", "coins")
	assert_eq(c._p1.text, "P1 3/3", "player one health")
	assert_eq(c._p2.text, "P2 3/3", "player two health")
	assert_true(c._time.text.begins_with("Time "), "play time")
	assert_true(c._detail.text.begins_with("Saved 20"), "local save date and time")


func test_continue_only_offers_loadable_campaigns() -> void:
	UiTestUtil.write_campaign(1, 3)
	_lost(2)
	UiTestUtil.damage(3)
	var screen := await _open(SaveSlotScreen.Mode.CONTINUE)
	assert_false(screen.card(1).disabled, "active campaign can be chosen")
	for slot in [2, 3, 4]:
		assert_true(screen.card(slot).disabled, "slot %d cannot be chosen" % slot)
		assert_eq(screen.card(slot).focus_mode, Control.FOCUS_NONE, "slot %d skipped by the keyboard" % slot)
	screen.card(2).pressed.emit()
	assert_true(app.campaign == null, "a lost campaign never loads")
	assert_eq(app.continue_campaign(2), ERR_FILE_CORRUPT, "direct load of the lost campaign is refused")
	assert_true(app.campaign == null, "still no campaign")
	assert_true(app.stack.top() is ConfirmDialog, "the refusal is explained")


func test_continue_without_campaigns_guides_to_new_game() -> void:
	_lost(1)
	var screen := await _open(SaveSlotScreen.Mode.CONTINUE)
	assert_true(screen.empty_note.visible, "message shown")
	assert_true(screen.new_game_button.visible, "New Game offered")
	assert_eq(UiTestUtil.focus_owner(get_tree()), screen.new_game_button, "focus on New Game")
	screen.new_game_button.pressed.emit()
	await get_tree().process_frame
	var top := app.stack.top() as SaveSlotScreen
	assert_true(top != null and top.mode == SaveSlotScreen.Mode.NEW_GAME, "switched to slot selection for a new game")


func test_loading_a_slot_uses_save_manager() -> void:
	UiTestUtil.write_campaign(3, 17, "w1_l2")
	var screen := await _open(SaveSlotScreen.Mode.CONTINUE)
	screen.card(3).pressed.emit()
	await get_tree().process_frame
	assert_true(app.campaign != null, "campaign started")
	assert_eq(app.saves.active_slot, 3, "slot 3 active")
	assert_eq(RunState.current().coins, 17, "the saved run was loaded")
	assert_eq(RunState.current().campaign.level_id, "w1_l2", "in the saved level")
	assert_eq(app.mode, GameApp.Mode.PLAYING, "playing")
	assert_true(app.stack.is_empty(), "menus closed")


func test_recovered_slot_loads_and_reports_recovery() -> void:
	var id := _recovered(2)
	var screen := await _open(SaveSlotScreen.Mode.CONTINUE)
	assert_false(screen.card(2).disabled, "a recoverable slot can be continued")
	screen.card(2).pressed.emit()
	await get_tree().process_frame
	assert_true(app.campaign != null, "loaded from the backup")
	assert_eq(RunState.current().campaign.campaign_id, id, "the same campaign")
	assert_eq(app.saves.slot_status(2), SaveManager.Status.VALID, "primary repaired by SaveManager.recover_backup")
	assert_true(app.campaign.last_notice.contains("backup"), "the recovery is reported to the players")


func test_repair_action_uses_the_recovery_interface() -> void:
	_recovered(1)
	UiTestUtil.write_campaign(2, 4)
	var other := UiTestUtil.snapshot_files()
	var screen := await _open(SaveSlotScreen.Mode.MANAGE)
	UiButton.focus_quietly(screen.card(1))
	await get_tree().process_frame
	assert_false((screen.actions["repair"] as UiButton).disabled, "Repair offered for a recovered slot")
	(screen.actions["repair"] as UiButton).pressed.emit()
	assert_eq(screen.card(1).status_word(), "ACTIVE", "repaired")
	assert_true(screen.message.text.contains("restored from its backup"), "told what happened")
	assert_eq(SaveTestUtil.read(UiTestUtil.DIR, "slot_2.save"), other["slot_2.save"], "slot 2 untouched")


func test_delete_requires_confirmation_and_touches_one_slot() -> void:
	UiTestUtil.write_campaign(1, 5)
	UiTestUtil.write_campaign(2, 6)
	UiTestUtil.write_campaign(4, 8)
	var before := UiTestUtil.snapshot_files()
	var screen := await _open(SaveSlotScreen.Mode.MANAGE)
	screen.delete_slot(2)
	var dialog := app.stack.top() as ConfirmDialog
	assert_true(dialog != null and dialog.danger, "destructive confirmation shown")
	assert_true(dialog.message.contains("slot 2") and dialog.message.contains("cannot be undone"), "states what is lost")
	assert_true(app.saves.has_valid_save(2), "nothing deleted before confirming")
	dialog.cancel_button.pressed.emit()
	assert_eq(UiTestUtil.snapshot_files(), before, "cancel changes no file")
	screen.delete_slot(2)
	(app.stack.top() as ConfirmDialog).confirm_button.pressed.emit()
	assert_eq(app.saves.slot_status(2), SaveManager.Status.EMPTY, "slot 2 deleted")
	assert_eq(screen.card(2).status_word(), "EMPTY", "card refreshed")
	for file: String in before:
		if not file.begins_with("slot_2"):
			assert_eq(SaveTestUtil.read(UiTestUtil.DIR, file), before[file], "%s byte-identical" % file)


func test_new_game_on_an_empty_slot_starts_at_once() -> void:
	UiTestUtil.write_campaign(1, 5)
	var keep := SaveTestUtil.read(UiTestUtil.DIR, "slot_1.save")
	var screen := await _open(SaveSlotScreen.Mode.NEW_GAME)
	screen.card(3).pressed.emit()
	await get_tree().process_frame
	assert_true(app.campaign != null, "campaign started without a question")
	assert_eq(app.saves.active_slot, 3, "in slot 3")
	assert_eq(RunState.current().campaign.level_id, LevelCatalog.first_level(), "first level")
	assert_eq(SaveTestUtil.read(UiTestUtil.DIR, "slot_1.save"), keep, "slot 1 untouched")


func test_overwrite_requires_confirmation() -> void:
	var old_id := UiTestUtil.write_campaign(2, 40, "w1_l2")
	UiTestUtil.write_campaign(3, 2)
	var slot3 := SaveTestUtil.read(UiTestUtil.DIR, "slot_3.save")
	var screen := await _open(SaveSlotScreen.Mode.NEW_GAME)
	screen.card(2).pressed.emit()
	var dialog := app.stack.top() as ConfirmDialog
	assert_true(dialog != null, "overwrite confirmation shown")
	assert_true(dialog.message.contains("erases") and dialog.message.contains("40 coins"), "says progress will be lost")
	assert_true(app.campaign == null, "nothing started yet")
	dialog.back()
	assert_eq(SaveManager.new(UiTestUtil.DIR).get_slot_metadata(2).campaign_id, old_id, "cancel keeps the campaign")
	screen.card(2).pressed.emit()
	(app.stack.top() as ConfirmDialog).confirm_button.pressed.emit()
	await get_tree().process_frame
	assert_true(app.campaign != null, "new campaign after confirming")
	var meta := app.saves.get_slot_metadata(2)
	assert_true(meta.campaign_id != old_id, "a different campaign now")
	assert_eq([int(meta.coins), str(meta.level_id)], [0, LevelCatalog.first_level()], "fresh start")
	assert_eq(SaveTestUtil.read(UiTestUtil.DIR, "slot_3.save"), slot3, "slot 3 untouched")


func test_damaged_slot_is_never_replaced_silently() -> void:
	UiTestUtil.damage(1)
	var screen := await _open(SaveSlotScreen.Mode.NEW_GAME)
	screen.card(1).pressed.emit()
	var dialog := app.stack.top() as ConfirmDialog
	assert_true(dialog != null and dialog.title.contains("damaged"), "asks before replacing a damaged slot")
	assert_true(app.campaign == null, "nothing replaced yet")
	dialog.confirm_button.pressed.emit()
	await get_tree().process_frame
	assert_true(app.campaign != null, "replaced after confirming")
	assert_true(FileAccess.file_exists(UiTestUtil.DIR + "slot_1.corrupt"), "a copy of the damaged file is kept")


func test_manage_actions_follow_the_slot_state() -> void:
	UiTestUtil.write_campaign(1, 1)
	_lost(2)
	var screen := await _open(SaveSlotScreen.Mode.MANAGE)
	var expect := {1: [true, true, true, false], 2: [false, true, true, false], 3: [false, true, false, false]}
	for slot: int in expect:
		UiButton.focus_quietly(screen.card(slot))
		await get_tree().process_frame
		var got := []
		for key in ["load", "new", "delete", "repair"]:
			got.append(not (screen.actions[key] as UiButton).disabled)
		assert_eq(got, expect[slot], "slot %d actions (load, new, delete, repair)" % slot)
	# Keyboard: Enter on a card moves to its actions; Escape leaves the screen.
	UiButton.focus_quietly(screen.card(1))
	await UiTestUtil.tap(get_tree(), KEY_ENTER)
	assert_eq(UiTestUtil.focus_owner(get_tree()), screen.actions["load"], "Enter moves to the first action")
	await UiTestUtil.tap(get_tree(), KEY_ESCAPE)
	assert_true(app.stack.top() is MainMenu, "Escape returns to the main menu")
