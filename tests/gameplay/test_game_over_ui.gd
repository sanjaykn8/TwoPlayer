extends GameTestCase
## Game-over screen on top of the Phase 8 team wipe, and the victory screen, through the real
## GameApp (folder user://test_saves_ui/, wipe delay 0.1 s).

var app: GameApp


func before_each() -> void:
	UiTestUtil.clean()
	SlotStore.fault = ""


func after_each() -> void:
	SlotStore.fault = ""
	UiTestUtil.free_app(app)
	await physics_frames(2)
	UiTestUtil.clean()


func _play(slot := 1) -> void:
	app = UiTestUtil.make_app(self)
	await get_tree().process_frame
	assert_eq(app.start_new_campaign(slot), OK, "campaign started")
	await physics_frames(5)


func _screen() -> GameOverScreen:
	return app.stack.top() as GameOverScreen


func _wait_ready() -> bool:
	for i in 120:
		if _screen() != null and _screen().state != GameOverScreen.State.WIPING:
			return true
		await physics_frames(1)
	return false


func _progress() -> String:
	var run := RunState.current()
	run.collect_coin(1)
	run.player(1).collect_jar(PlayerStats.JarType.RED)
	assert_eq(app.campaign.save_now("test"), OK, "progress saved")
	return run.campaign.campaign_id


func test_wipe_shows_run_lost_after_durable_invalidation() -> void:
	UiTestUtil.write_campaign(2, 20)
	UiTestUtil.write_campaign(4, 40)
	var others := UiTestUtil.snapshot_files()
	await _play(1)
	var old_id := _progress()
	app.campaign.knights[1].health.apply_damage(99)
	assert_true(_screen() != null, "game-over screen opens at once")
	assert_eq(app.mode, GameApp.Mode.GAME_OVER, "game-over mode")
	assert_eq(_screen().state, GameOverScreen.State.WIPING, "still clearing the lost run")
	assert_false(_screen().begin_button.visible or _screen().menu_button.visible, "no choices yet")
	assert_eq(app.saves.store.read_marker(1), old_id, "the lost run is already marked dead on disk")
	assert_false(app.saves.has_valid_save(1), "the lost run is already unloadable")
	await UiTestUtil.tap(get_tree(), KEY_ESCAPE)
	assert_true(_screen() != null, "Escape cannot skip the screen")
	assert_true(await _wait_ready(), "wipe finished")
	assert_eq(_screen().state, GameOverScreen.State.READY, "ready")
	assert_true(_screen().begin_button.visible and _screen().menu_button.visible, "Begin Again and Main Menu offered")
	assert_eq(UiTestUtil.focus_owner(get_tree()), _screen().begin_button, "Begin Again focused")
	assert_true(get_tree().paused, "the fresh run waits for the players")
	var meta := SaveManager.new(UiTestUtil.DIR).get_slot_metadata(1)
	assert_true(str(meta.campaign_id) != old_id, "slot 1 now holds a different campaign")
	assert_eq([int(meta.coins), str(meta.level_id)], [0, LevelCatalog.first_level()], "the fresh run at the first level")
	var check := SaveManager.new(UiTestUtil.DIR).load_run(1)
	assert_true(check.ok and RunState.current().campaign.campaign_id != old_id, "loading slot 1 never returns the lost run")
	for file: String in others:
		if not file.begins_with("slot_1"):
			assert_eq(SaveTestUtil.read(UiTestUtil.DIR, file), others[file], "%s untouched" % file)


func test_begin_again_plays_the_fresh_run() -> void:
	await _play()
	var old_id := _progress()
	app.campaign.knights[0].health.apply_damage(99)
	assert_true(await _wait_ready(), "ready")
	_screen().begin_button.pressed.emit()
	await physics_frames(3)
	assert_eq(app.mode, GameApp.Mode.PLAYING, "playing")
	assert_false(get_tree().paused, "unpaused")
	assert_true(app.stack.is_empty(), "screen closed")
	var run := RunState.current()
	assert_true(run.campaign.campaign_id != old_id, "a new run")
	assert_eq([run.coins, run.player(1).attack_power(), run.campaign.level_id], [0, 1, LevelCatalog.first_level()], "nothing carried over")
	assert_eq([app.campaign.knights[0].health.current_health, app.campaign.knights[1].health.current_health], [3, 3], "both knights at 3/3")
	assert_eq(app.saves.active_slot, 1, "same slot")


func test_main_menu_never_offers_the_lost_run() -> void:
	await _play()
	var old_id := _progress()
	app.campaign.knights[0].health.apply_damage(99)
	assert_true(await _wait_ready(), "ready")
	_screen().menu_button.pressed.emit()
	await get_tree().process_frame
	assert_true(app.stack.top() is MainMenu, "main menu")
	assert_true(app.campaign == null, "campaign closed")
	var slots := app.open_slot_screen(SaveSlotScreen.Mode.CONTINUE)
	await get_tree().process_frame
	var card := slots.card(1)
	assert_true(str(card.meta.campaign_id) != old_id, "slot 1 offers only the fresh run")
	assert_eq(str(card._coins.text), "0", "no coins from the lost run")
	assert_eq(card._location.text, LevelCatalog.location_title(LevelCatalog.first_level()), "at the first level")


func test_storage_failure_offers_only_quitting() -> void:
	await _play()
	var old_id := _progress()
	SlotStore.fault = "marker"
	app.campaign.knights[0].health.apply_damage(99)
	await physics_frames(3)
	assert_eq(_screen().state, GameOverScreen.State.FAILED, "failure shown")
	assert_true(_screen().quit_button.visible, "Quit offered")
	assert_false(_screen().begin_button.visible or _screen().menu_button.visible, "no way back into a lost run")
	assert_eq(app.return_to_menu(), ERR_UNAVAILABLE, "cannot leave to the menu (the lost run is still on disk)")
	assert_eq(app.saves.get_slot_metadata(1).campaign_id, old_id, "the old file is still there (known limitation KI-70)")
	_screen().quit_button.pressed.emit()
	assert_true(app.quit_requested, "quits")


func test_victory_screen_after_the_last_level() -> void:
	await _play()
	RunState.current().collect_coin(1)
	app.campaign.complete_level()
	await physics_frames(5)
	assert_eq(RunState.current().campaign.level_id, "w1_l2", "level 2")
	assert_eq(app.audio.current_track, "world_1", "world music kept")
	app.campaign.complete_level()
	await physics_frames(3)
	var screen := app.stack.top() as VictoryScreen
	assert_true(screen != null, "victory screen")
	assert_eq(app.mode, GameApp.Mode.VICTORY, "victory mode")
	assert_true(get_tree().paused, "game paused under it")
	assert_false(screen.preview, "a real completion")
	assert_eq(app.audio.current_track, "victory", "victory music")
	var rows := VictoryScreen.summary(RunState.current())
	assert_eq(rows[0], ["Status", "Campaign complete"], "status")
	assert_eq(rows[1], ["Levels completed", "2 of 2"], "levels")
	assert_eq(rows[2], ["Coins", "1"], "real coin total")
	assert_eq(screen.stats_grid.get_child_count(), rows.size() * 2, "every statistic shown")
	assert_true(app.saves.get_slot_metadata(1).valid, "completion saved")
	screen.menu_button.pressed.emit()
	await get_tree().process_frame
	assert_true(app.stack.top() is MainMenu, "back to the main menu")


func test_victory_preview_is_labelled_and_changes_nothing() -> void:
	await _play()
	var screen := app.show_victory(true)
	await get_tree().process_frame
	assert_true(screen.preview, "preview")
	var texts := screen.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	assert_true(texts.any(func(t: String) -> bool: return t.contains("DEVELOPMENT PREVIEW")), "labelled as a preview")
	assert_false(texts.any(func(t: String) -> bool: return t.contains("Congratulations")), "no completion claim")
	assert_false(RunState.current().campaign.flags.get("finished", false), "the campaign is not marked finished")
	assert_eq(VictoryScreen.summary(RunState.current())[0], ["Status", "In progress"], "status says in progress")
