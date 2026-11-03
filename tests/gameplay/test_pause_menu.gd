extends GameTestCase
## Pause menu through the real GameApp (folder user://test_saves_ui/): everything gameplay
## stops while the menu stays usable, Settings keeps the pause, Restart asks first and is never
## a death, and leaving (Save and Quit, Main Menu) happens only after a verified save.

var app: GameApp


func before_each() -> void:
	UiTestUtil.clean()
	SlotStore.fault = ""
	for action in [&"p1_move_right", &"p2_move_left"]:
		Input.action_release(action)


func after_each() -> void:
	SlotStore.fault = ""
	for action in [&"p1_move_right", &"p2_move_left"]:
		Input.action_release(action)
	UiTestUtil.free_app(app)
	await physics_frames(2)
	UiTestUtil.clean()


func _play(slot := 1, level_id := "w1_l1") -> void:
	if level_id != LevelCatalog.FIRST_LEVEL:
		UiTestUtil.write_campaign(slot, 0, level_id)
	app = UiTestUtil.make_app(self)
	await get_tree().process_frame
	var err := app.continue_campaign(slot) if level_id != LevelCatalog.FIRST_LEVEL else app.start_new_campaign(slot)
	assert_eq(err, OK, "campaign started")
	await physics_frames(10)


func _k(i: int) -> Knight:
	return app.campaign.knights[i]


func _node(path: String) -> Node:
	return app.campaign.level.get_node_or_null(path)


func _pause_menu() -> PauseMenu:
	return app.stack.top() as PauseMenu


func test_escape_pauses_and_resumes() -> void:
	await _play()
	await UiTestUtil.tap(get_tree(), KEY_ESCAPE)
	assert_eq(app.mode, GameApp.Mode.PAUSED, "paused")
	assert_true(get_tree().paused, "game tree paused")
	assert_true(_pause_menu() != null, "pause menu open")
	assert_eq(UiTestUtil.focus_owner(get_tree()), _pause_menu().buttons["resume"], "Resume focused")
	for key in ["resume", "settings", "restart", "save_quit", "main_menu"]:
		assert_true(_pause_menu().buttons.has(key), "%s option" % key)
	await UiTestUtil.tap(get_tree(), KEY_DOWN)
	assert_eq(UiTestUtil.focus_owner(get_tree()), _pause_menu().buttons["settings"], "menu works while paused")
	await UiTestUtil.tap(get_tree(), KEY_ESCAPE)
	assert_eq(app.mode, GameApp.Mode.PLAYING, "Escape resumes")
	assert_false(get_tree().paused, "unpaused")
	assert_true(app.stack.is_empty(), "menu closed")
	await UiTestUtil.tap(get_tree(), KEY_ESCAPE)
	assert_true(_pause_menu() != null, "pauses again")
	_pause_menu().buttons["resume"].pressed.emit()
	assert_false(get_tree().paused, "Resume button resumes")


func test_everything_stops_while_paused() -> void:
	await _play()
	var lift := _node("Platforms/Lift") as MovingPlatform
	_k(1).teleport_to(lift.global_position + Vector2(16, -2))
	await physics_frames(20)
	RunState.current().player(1).collect_fruit(PlayerStats.FruitType.YELLOW, 3)
	var slime := _node("Enemies/SlimeA") as Slime
	assert_true(app.pause_game(), "paused")
	Input.action_press(&"p1_move_right")
	var before := {
		"k1": _k(0).global_position, "k2": _k(1).global_position, "lift": lift.progress,
		"slime": slime.global_position, "effect": RunState.current().player(1).effects.remaining(PlayerEffects.FRUIT_SHIELD),
		"playtime": RunState.current().campaign.playtime,
	}
	await physics_frames(90)
	assert_eq(_k(0).global_position, before.k1, "P1 does not move although its key is held")
	assert_eq(_k(1).global_position, before.k2, "P2 (standing on the lift) does not move")
	assert_eq(lift.progress, before.lift, "moving platform stopped")
	assert_eq(slime.global_position, before.slime, "slime AI stopped")
	assert_eq(RunState.current().player(1).effects.remaining(PlayerEffects.FRUIT_SHIELD), before.effect, "fruit effect timer stopped")
	assert_eq(RunState.current().campaign.playtime, before.playtime, "play time stopped")
	Input.action_release(&"p1_move_right")
	app.resume_game()
	await physics_frames(60)
	assert_true(lift.progress != before.lift, "the lift moves again after resuming")
	assert_lt(RunState.current().player(1).effects.remaining(PlayerEffects.FRUIT_SHIELD), before.effect, "the effect counts down again")
	assert_gt(RunState.current().campaign.playtime, before.playtime, "play time counts again")


func test_timed_gate_waits_while_paused() -> void:
	await _play(1, "w1_l2")
	var gate := _node("Puzzles/Gate") as PuzzleGate
	gate.open()
	await physics_frames(30)
	app.pause_game()
	var left := gate.time_left
	await physics_frames(120)
	assert_eq(gate.time_left, left, "the timed gate's countdown waits")
	assert_true(gate.is_open() or gate.state != PuzzleGate.State.CLOSED, "still open")
	app.resume_game()
	await physics_frames(30)
	assert_lt(gate.time_left, left, "counts down again after resuming")


func test_settings_from_pause_keep_the_game_paused() -> void:
	await _play()
	app.pause_game()
	await UiTestUtil.tap(get_tree(), KEY_DOWN)
	await UiTestUtil.tap(get_tree(), KEY_ENTER)
	assert_true(app.stack.top() is SettingsScreen, "settings open")
	assert_true(get_tree().paused, "still paused")
	assert_eq(app.mode, GameApp.Mode.PAUSED, "still in the pause menu flow")
	(app.stack.top() as SettingsScreen).settings.set_value("music_volume", 40)
	await UiTestUtil.tap(get_tree(), KEY_ESCAPE)
	assert_true(_pause_menu() != null, "back to the pause menu")
	assert_true(get_tree().paused, "still paused after settings")
	assert_eq(UiTestUtil.focus_owner(get_tree()), _pause_menu().buttons["settings"], "focus back on Settings")
	assert_eq(AudioManager.bus_percent(&"Music"), 40, "the change applied")
	AudioManager.set_bus_percent(&"Music", 100)


func test_restart_requires_confirmation_and_is_not_a_death() -> void:
	UiTestUtil.write_campaign(3, 11)
	var slot3 := SaveTestUtil.read(UiTestUtil.DIR, "slot_3.save")
	await _play()
	var run := RunState.current()
	run.collect_coin(1)
	run.collect_coin(2)
	run.player(1).collect_jar(PlayerStats.JarType.RED)
	var old_id := run.campaign.campaign_id
	app.pause_game()
	_pause_menu().buttons["restart"].pressed.emit()
	var dialog := app.stack.top() as ConfirmDialog
	assert_true(dialog != null, "confirmation shown")
	assert_true(dialog.message.begins_with("Restarting will erase the current campaign progress for this slot."), "the required warning")
	assert_eq(UiTestUtil.focus_owner(get_tree()), dialog.cancel_button, "Cancel focused")
	await UiTestUtil.tap(get_tree(), KEY_ESCAPE)
	assert_true(_pause_menu() != null, "cancel returns to the pause menu")
	assert_eq([RunState.current().campaign.campaign_id, RunState.current().coins, RunState.current().player(1).attack_power()], [old_id, 2, 2], "cancel changes nothing")
	_pause_menu().buttons["restart"].pressed.emit()
	(app.stack.top() as ConfirmDialog).confirm_button.pressed.emit()
	await physics_frames(3)
	var fresh := RunState.current()
	assert_true(fresh.campaign.campaign_id != old_id, "a new campaign")
	assert_eq([fresh.coins, fresh.player(1).attack_power(), fresh.collected.size(), fresh.campaign.level_id], [0, 1, 0, LevelCatalog.FIRST_LEVEL], "coins, upgrades, items and level reset")
	assert_eq([_k(0).health.current_health, _k(1).health.current_health], [3, 3], "both knights reset")
	assert_eq(app.campaign.wipes, 0, "not a team wipe")
	assert_eq(app.saves.store.read_marker(1), "", "no death marker")
	assert_eq(app.saves.get_slot_metadata(1).campaign_id, fresh.campaign.campaign_id, "the fresh campaign is saved in slot 1")
	assert_false(get_tree().paused, "play continues")
	assert_eq(SaveTestUtil.read(UiTestUtil.DIR, "slot_3.save"), slot3, "other slots untouched")


func test_save_and_quit_waits_for_a_verified_save() -> void:
	await _play()
	RunState.current().collect_coin(1)
	app.pause_game()
	SlotStore.fault = "tmp_write"
	_pause_menu().buttons["save_quit"].pressed.emit()
	assert_false(app.quit_requested, "no quit when the save failed")
	assert_true(get_tree().paused and _pause_menu() != null, "still paused in the pause menu")
	assert_true(_pause_menu().status.text.contains("Could not save"), "the failure is shown")
	assert_eq(app.campaign.phase, CampaignGame.Phase.PLAYING, "the campaign keeps running")
	SlotStore.fault = ""
	_pause_menu().buttons["save_quit"].pressed.emit()
	assert_true(app.quit_requested, "quits after the save succeeded")
	assert_eq(int(app.saves.get_slot_metadata(1).coins), 1, "the latest state was saved")
	assert_eq(app.saves.store.read_marker(1), "", "quitting is not dying")


func test_return_to_main_menu_preserves_the_campaign() -> void:
	await _play(2)
	var run := RunState.current()
	run.collect_coin(1)
	run.player(2).collect_fruit(PlayerStats.FruitType.YELLOW, 3)
	_k(0).teleport_to(Vector2(300, 448))
	await physics_frames(10)
	var id := run.campaign.campaign_id
	var left := run.player(2).effects.remaining(PlayerEffects.FRUIT_SHIELD)
	app.pause_game()
	_pause_menu().buttons["main_menu"].pressed.emit()
	await get_tree().process_frame
	assert_true(app.stack.top() is MainMenu, "main menu shown")
	assert_true(app.campaign == null, "campaign closed")
	assert_false(get_tree().paused, "menu not paused")
	assert_eq(app.audio.current_track, "menu", "menu music")
	assert_false((app.stack.top() as MainMenu).buttons["continue"].disabled, "Continue available")
	var meta := app.saves.get_slot_metadata(2)
	assert_eq([str(meta.status), str(meta.campaign_id), int(meta.coins)], ["VALID", id, 1], "slot 2 holds the same campaign")
	assert_eq(app.saves.store.read_marker(2), "", "not a death")
	assert_eq(app.continue_campaign(2), OK, "resume it")
	await physics_frames(3)
	assert_eq(RunState.current().campaign.campaign_id, id, "same campaign resumed")
	assert_eq(RunState.current().coins, 1, "coins kept")
	assert_near(RunState.current().player(2).effects.remaining(PlayerEffects.FRUIT_SHIELD), left, 0.1, "effect time kept")
	assert_near(_k(0).global_position.x, 300.0, 1.0, "position kept")


func test_failed_save_never_leaves_the_game() -> void:
	await _play()
	RunState.current().collect_coin(2)
	app.pause_game()
	SlotStore.fault = "replace"
	_pause_menu().buttons["main_menu"].pressed.emit()
	assert_true(app.campaign != null, "still in the campaign")
	assert_true(_pause_menu() != null, "still in the pause menu")
	assert_eq(RunState.current().coins, 1, "nothing lost in memory")
	assert_true(_pause_menu().status.text.contains("Nothing was lost"), "explained")


func test_pause_is_refused_outside_ordinary_play() -> void:
	await _play()
	_k(0).health.apply_damage(99)
	await physics_frames(1)
	assert_false(app.pause_game(), "no pause during a team wipe")
	assert_true(app.stack.top() is GameOverScreen, "game-over screen instead")
