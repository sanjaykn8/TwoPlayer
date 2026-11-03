extends GameTestCase
## Level catalog, campaign state, ids, the save encoding and RunState snapshot versions.


func before_each() -> void:
	LevelCatalog.use_development()  # written against the Phase 8 development levels
	RunState.reset()

func test_level_catalog_is_a_closed_whitelist() -> void:
	assert_true(LevelCatalog.is_known_level(LevelCatalog.first_level()), "first level known")
	assert_eq(LevelCatalog.world_of("w1_l2"), "w1", "world of a level")
	assert_eq(LevelCatalog.next_level("w1_l1"), "w1_l2", "campaign order")
	assert_eq(LevelCatalog.next_level("w1_l2"), "", "end of the campaign")
	for bad in ["", "w1_l9", "res://scenes/levels/w1/w1_l1.tscn", "../w1_l1"]:
		assert_false(LevelCatalog.is_known_level(bad), "%s refused" % bad)
		assert_eq(LevelCatalog.scene_for(bad), "", "no scene for %s" % bad)
	for level_id in LevelCatalog.all_levels():
		assert_true(ResourceLoader.exists(LevelCatalog.scene_for(level_id)), "%s scene exists" % level_id)


func test_campaign_state_round_trip_and_validation() -> void:
	var c := CampaignState.new()
	assert_eq(c.campaign_id.length(), 16, "16 hex digits")
	assert_true(c.campaign_id != CampaignState.new().campaign_id, "unique per run")
	c.complete_level("w1_l1")
	c.complete_level("w1_l1")
	assert_true(c.enter_level("w1_l2"), "enter known level")
	assert_false(c.enter_level("w9_l9"), "unknown level refused")
	c.playtime = 42.5
	var copy := CampaignState.new()
	assert_true(copy.restore(JSON.parse_string(JSON.stringify(c.snapshot()))), "restores from JSON")
	assert_eq([copy.campaign_id, copy.level_id, copy.world_id, copy.completed_levels.size(), copy.playtime],
		[c.campaign_id, "w1_l2", "w1", 1, 42.5], "same values")
	var bad := c.snapshot()
	bad.world_id = "w2"
	assert_false(CampaignState.is_valid_snapshot(bad), "level/world mismatch refused")
	bad = c.snapshot()
	bad.campaign_id = "not hex!"
	assert_false(CampaignState.is_valid_snapshot(bad), "bad id refused")


func test_run_snapshot_versions() -> void:
	var run := RunState.reset()
	run.campaign.enter_level("w1_l2")
	run.coins = 3
	var data: Dictionary = JSON.parse_string(JSON.stringify(run.snapshot()))
	assert_eq(int(data.version), 3, "version 3")
	var copy := RunState.new()
	assert_true(copy.restore(data), "v3 restores")
	assert_eq(copy.campaign.level_id, "w1_l2", "campaign restored")
	var v2 := data.duplicate(true)
	v2.erase("campaign")
	v2.version = 2
	var keep := RunState.new()
	var before := keep.campaign.campaign_id
	assert_true(keep.restore(v2), "v2 still restores")
	assert_eq(keep.campaign.campaign_id, before, "v2 keeps the current campaign")
	var broken := data.duplicate(true)
	broken.erase("campaign")
	assert_false(RunState.new().restore(broken), "v3 without campaign refused")


func test_ids() -> void:
	for good in ["w1l1_slime_a", "enemy:w1l1_slime_a", "dev/puzzle_test", "coin_0", "w1_l1_jar_green"]:
		assert_true(SaveIds.is_valid_id(good), "%s valid" % good)
	for bad in ["", "Has Caps", "res://x.tscn", "a b", "x".repeat(65), "semi;colon"]:
		assert_false(SaveIds.is_valid_id(bad), "%s invalid" % bad)


func test_encoding_round_trip() -> void:
	var run := RunState.reset()
	run.coins = 12
	var text := SaveSchema.encode(SaveSchema.build(2, run, {}))
	assert_true(text.begins_with("TKCSAVE 1 "), "header line")
	var result := SaveSchema.decode(text, 2)
	assert_true(result.ok, "decodes: %s" % result.error)
	assert_eq(int(result.doc.header.coins), 12, "header summary")
	assert_eq(str(result.doc.header.campaign_id), run.campaign.campaign_id, "campaign id")
	assert_false(SaveSchema.decode(text, 3).ok, "another slot's file refused")
	assert_true(JSON.parse_string(SaveTestUtil.body_of(text)) is Dictionary, "the body is plain JSON")


func test_save_location_is_permanent() -> void:
	assert_eq(SavePaths.SAVE_DIR, "user://saves/", "user://saves/")
	assert_true(SavePaths.absolute_save_dir().contains("TwoKnightCoop"), "under the TwoKnightCoop user folder")
	assert_eq(SaveManager.new().store.dir, "user://saves/", "the default SaveManager uses it")
	assert_eq(SlotStore.new().path(1, SlotStore.Kind.SAVE), "user://saves/slot_1.save", "slot_1.save")
	assert_eq(SlotStore.new().path(3, SlotStore.Kind.BACKUP), "user://saves/slot_3.bak", "backup name")
