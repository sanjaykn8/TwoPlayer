extends GameTestCase
## The production campaign is complete (Phase 10 acceptance): six worlds of four main levels,
## 24 unique levels in order, three optional bosses in worlds 2, 4 and 6 (never on the main
## route), every collectible type placed, and difficulty that rises from world to world.

func test_six_worlds_of_four_levels() -> void:
	var worlds := LevelCatalog.world_ids()
	assert_eq(worlds, ["forest", "caves", "ruins", "lava", "fortress", "citadel"] as Array[String], "six worlds in order")
	var levels := LevelCatalog.all_levels()
	assert_eq(levels.size(), 24, "24 main levels")
	for i in levels.size():
		assert_eq(levels[i], "l%02d" % (i + 1), "level %d id" % (i + 1))
		assert_eq(LevelCatalog.world_of(levels[i]), worlds[i / 4], "%s in world %d" % [levels[i], i / 4 + 1])
	assert_eq(LevelCatalog.first_level(), "l01", "the campaign starts at l01")
	assert_true(LevelCatalog.is_final_level("l24"), "l24 ends the campaign")
	var titles := {}
	for id in levels:
		assert_false(titles.has(LevelCatalog.level_title(id)), "%s has its own name" % id)
		titles[LevelCatalog.level_title(id)] = true


func test_three_optional_bosses() -> void:
	var bosses := {}
	for id in LevelCatalog.all_levels():
		var def := LevelCatalog.level(id)
		if def.boss_id != "":
			bosses[def.world_id] = id
			assert_true(def.optional_content.has(def.boss_id), "%s: the boss is listed as optional" % id)
	assert_eq(bosses.keys(), ["caves", "lava", "citadel"], "one boss each in worlds 2, 4 and 6")


func test_every_collectible_type_is_placed() -> void:
	var found := {}
	for id in LevelCatalog.all_levels():
		var root := (load(LevelCatalog.scene_for(id)) as PackedScene).instantiate()
		for node in root.find_children("*", "", true, false):
			if node is Fruit:
				found["fruit_%d" % (node as Fruit).fruit_type] = true
			elif node is Jar:
				found["jar_%d" % (node as Jar).jar_type] = true
			elif node is CoinStash:
				found["coins"] = true
			elif node is PowerTile:
				found["tile"] = true
			elif node is Slime:
				found["slime_%s" % (node as Slime).stats.display_name] = true
		root.free()
	for key in ["fruit_0", "fruit_1", "fruit_2", "fruit_3", "jar_0", "jar_1", "jar_2", "jar_3", "coins", "tile"]:
		assert_true(found.has(key), "%s placed somewhere in the campaign" % key)
	assert_eq(found.keys().filter(func(k: String) -> bool: return k.begins_with("slime_")).size(), 2, "green and purple slimes used")


func test_difficulty_rises_by_world() -> void:
	var previous := 0.0
	var total := 0.0
	for world_id in LevelCatalog.world_ids():
		var sum := 0.0
		for id in LevelCatalog.levels_of(world_id):
			sum += LevelCatalog.level(id).difficulty
			total += LevelCatalog.level(id).estimated_minutes
		assert_gt(sum / 4.0, previous, "%s is harder on average than the world before" % world_id)
		previous = sum / 4.0
	# A design estimate only (no measured play times exist yet); see docs/CAMPAIGN_PLAN.md.
	assert_true(total >= 90.0 and total <= 130.0, "estimated first play %.0f min is near the 90-120 min target" % total)


func test_victory_result_is_kept_and_replay_needs_confirmation() -> void:
	UiTestUtil.clean()
	LevelCatalog.use_production()
	RunState.reset()
	var app := UiTestUtil.make_app(self)
	await get_tree().process_frame
	assert_eq(app.start_new_campaign(1), OK, "new campaign in slot 1")
	var run := RunState.current()
	for id in LevelCatalog.all_levels():
		if id != "l24":
			run.campaign.complete_level(id)
	run.campaign.enter_level("l24")
	app.campaign._load_level("l24", {})
	await physics_frames(2)
	app.campaign.complete_level()
	await physics_frames(3)
	var screen := app.stack.top() as VictoryScreen
	assert_true(screen != null and not screen.preview, "the real victory screen")
	var rows := VictoryScreen.summary(RunState.current())
	assert_eq(rows[0], ["Status", "Campaign complete"], "complete")
	assert_eq(rows[1], ["Levels completed", "24 of 24"], "all 24 levels")
	assert_true(app.saves.get_slot_metadata(1).finished, "the result is saved")
	screen.menu_button.pressed.emit()
	await get_tree().process_frame
	var slots := app.open_slot_screen(SaveSlotScreen.Mode.MANAGE)
	await get_tree().process_frame
	assert_true(slots.card(1)._detail.text.contains("CAMPAIGN COMPLETE"), "the slot shows the completed campaign")
	slots.close()
	assert_eq(app.continue_campaign(1), OK, "the completed campaign can be opened")
	await get_tree().process_frame
	assert_true(app.stack.top() is VictoryScreen, "continuing shows its result again")
	(app.stack.top() as VictoryScreen).menu_button.pressed.emit()
	await get_tree().process_frame
	var new_game := app.open_slot_screen(SaveSlotScreen.Mode.NEW_GAME)
	new_game.card(1).pressed.emit()
	assert_true(app.stack.top() is ConfirmDialog, "starting over in that slot asks first")
	UiTestUtil.free_app(app)
	await physics_frames(2)
	UiTestUtil.clean()
	LevelCatalog.use_production()
