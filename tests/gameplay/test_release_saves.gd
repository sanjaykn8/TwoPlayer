extends GameTestCase
## Save integrity and the team wipe on the PRODUCTION campaign (Phase 11, Part H). Phase 8
## tests cover the same mechanisms on the development levels; these repeat the critical cases
## with real campaign levels from different worlds. Folder user://test_saves_release/.

const DIR := "user://test_saves_release/"

var games: Array[CampaignGame] = []
var _attack := 91000


func before_each() -> void:
	SaveTestUtil.clean(DIR)
	SlotStore.fault = ""
	LevelCatalog.use_production()
	RunState.reset()


func after_each() -> void:
	SlotStore.fault = ""
	for g in games:
		if is_instance_valid(g):
			g.queue_free()
	games.clear()
	await physics_frames(2)
	SaveTestUtil.clean(DIR)
	LevelCatalog.use_production()


func _game(slot: int, mode: CampaignGame.StartMode) -> CampaignGame:
	var g := SaveTestUtil.make_game(self, slot, mode, DIR, true)
	games.append(g)
	return g


## A campaign in `slot`, played into `level_id` with progress, saved. Returns its state.
func _progress(slot: int, level_id: String, coins: int) -> Dictionary:
	RunState.reset()
	var g := _game(slot, CampaignGame.StartMode.NEW)
	assert_eq(g.begin(), OK, "slot %d begins" % slot)
	var run := RunState.current()
	for id in LevelCatalog.all_levels():
		if id == level_id:
			break
		run.campaign.complete_level(id)
	run.campaign.enter_level(level_id)
	g._load_level(level_id, {})
	await physics_frames(3)
	for i in coins:
		run.collect_coin(1)
	run.player(1).collect_jar(PlayerStats.JarType.RED)
	run.player(2).collect_jar(PlayerStats.JarType.GREEN)
	run.player(2).collect_fruit(PlayerStats.FruitType.YELLOW, 3)
	run.player(1).collect_fruit(PlayerStats.FruitType.PURPLE, 2)
	g.knights[1].health.take_damage(DamageEvent.create(1, DamageEvent.Category.CONTACT, self))
	g.knights[0].teleport_to(g.knights[0].global_position + Vector2(32, 0))
	await physics_frames(20)
	# Defeat one slime of the level (if any) so enemy state is part of the save.
	var defeated := ""
	for node in g.level.find_children("*", "", true, false):
		if node is Slime:
			_attack += 1
			(node as Slime).stagger.staggered = true
			(node as Slime)._apply_outcome(SlimeStagger.Outcome.KILLED, g.knights[0])
			defeated = (node as Slime).save_id
			break
	await physics_frames(5)
	assert_eq(g.save_now("test"), OK, "slot %d saved" % slot)
	var state := {
		"campaign_id": run.campaign.campaign_id, "level": level_id, "coins": run.coins,
		"p1_power": run.player(1).attack_power(), "p2_max": run.player(2).max_health(),
		"p2_hp": g.knights[1].health.current_health, "poison": run.player(1).poison_seconds,
		"shield_left": run.player(2).effects.remaining(PlayerEffects.FRUIT_SHIELD),
		"p1_x": g.knights[0].global_position.x, "defeated": defeated,
		"completed": run.campaign.completed_levels.size(),
	}
	g.queue_free()
	await physics_frames(2)
	return state


func _check_resume(slot: int, expected: Dictionary) -> void:
	RunState.reset()
	var g := _game(slot, CampaignGame.StartMode.LOAD)
	assert_eq(g.begin(), OK, "slot %d loads" % slot)
	await physics_frames(3)
	var run := RunState.current()
	var label := "slot %d (%s)" % [slot, expected.level]
	assert_eq(run.campaign.campaign_id, expected.campaign_id, "%s: same campaign" % label)
	assert_eq(run.campaign.level_id, expected.level, "%s: level" % label)
	assert_eq(run.coins, expected.coins, "%s: shared coins" % label)
	assert_eq(run.player(1).attack_power(), expected.p1_power, "%s: P1 red jar power" % label)
	assert_eq(run.player(2).max_health(), expected.p2_max, "%s: P2 green jar max health" % label)
	assert_eq(g.knights[1].health.current_health, expected.p2_hp, "%s: P2 health" % label)
	assert_eq(run.player(1).poison_seconds, expected.poison, "%s: P1 poison" % label)
	assert_near(run.player(2).effects.remaining(PlayerEffects.FRUIT_SHIELD), expected.shield_left, 0.05, "%s: P2 shield time kept" % label)
	assert_near(g.knights[0].global_position.x, expected.p1_x, 2.0, "%s: P1 position" % label)
	assert_eq(run.campaign.completed_levels.size(), expected.completed, "%s: completed levels" % label)
	if expected.defeated != "":
		var alive := g.level.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is Slime and (n as Slime).save_id == expected.defeated and not n.is_queued_for_deletion())
		assert_eq(alive.size(), 0, "%s: the defeated slime stays defeated" % label)
	g.queue_free()
	await physics_frames(2)


func test_four_slots_in_four_worlds_restore_exactly() -> void:
	var states := {}
	var plan := {1: "l03", 2: "l10", 3: "l17", 4: "l23"}
	for slot: int in plan:
		states[slot] = await _progress(slot, plan[slot], slot * 3)
	var manager := SaveManager.new(DIR)
	for slot: int in plan:
		var meta := manager.get_slot_metadata(slot)
		assert_eq([str(meta.level_id), int(meta.coins), str(meta.campaign_id)], [plan[slot], slot * 3, states[slot].campaign_id], "slot %d metadata" % slot)
	for slot: int in plan:
		await _check_resume(slot, states[slot])


func test_wipe_in_world_five_touches_only_its_slot() -> void:
	for slot in [1, 2, 3, 4]:
		await _progress(slot, ["l04", "l18", "l12", "l21"][slot - 1], 5)
	var before := {}
	for file in DirAccess.get_files_at(DIR):
		before[file] = SaveTestUtil.read(DIR, file)
	RunState.reset()
	var g := _game(2, CampaignGame.StartMode.LOAD)
	assert_eq(g.begin(), OK, "slot 2 loads")
	await physics_frames(3)
	var old_id := RunState.current().campaign.campaign_id
	g.knights[0].health.apply_damage(99)
	for i in 120:
		await physics_frames(1)
		if g.wipes > 0 and g.phase == CampaignGame.Phase.PLAYING:
			break
	var fresh := RunState.current()
	assert_true(fresh.campaign.campaign_id != old_id, "a new run")
	assert_eq([fresh.campaign.level_id, fresh.coins, fresh.player(1).attack_power(), fresh.player(2).max_health(), fresh.collected.size(), fresh.campaign.completed_levels.size()],
		["l01", 0, 1, 3, 0, 0], "everything reset to the start of the campaign")
	assert_eq([g.knights[0].health.current_health, g.knights[1].health.current_health], [3, 3], "both knights fresh")
	var manager := SaveManager.new(DIR)
	assert_true(manager.get_slot_metadata(2).campaign_id != old_id, "slot 2 holds the fresh run")
	assert_false(FileAccess.file_exists(DIR + "slot_2.bak") and SaveSchema.decode(SaveTestUtil.read(DIR, "slot_2.bak"), 2).ok \
		and str(SaveSchema.decode(SaveTestUtil.read(DIR, "slot_2.bak"), 2).doc.header.campaign_id) == old_id, "no backup of the dead run")
	var loaded := manager.load_run(2)
	assert_true(loaded.ok and RunState.current().campaign.campaign_id != old_id, "loading slot 2 never returns the dead run")
	for file: String in before:
		if not file.begins_with("slot_2"):
			assert_eq(SaveTestUtil.read(DIR, file), before[file], "%s byte-identical" % file)


func test_death_during_a_transition_and_a_pending_save() -> void:
	await _progress(1, "l14", 2)
	RunState.reset()
	var g := _game(1, CampaignGame.StartMode.LOAD)
	assert_eq(g.begin(), OK, "loads")
	await physics_frames(3)
	var old_id := RunState.current().campaign.campaign_id
	g.request_autosave("pending")
	g.complete_level()
	g.knights[1].health.apply_damage(99)  # dies in the same frame as the exit and the save request
	for i in 120:
		await physics_frames(1)
		if g.wipes > 0 and g.phase == CampaignGame.Phase.PLAYING:
			break
	assert_eq(g.wipes, 1, "one team wipe")
	assert_eq(RunState.current().campaign.level_id, "l01", "back to level 1, not on to level 15")
	var meta := SaveManager.new(DIR).get_slot_metadata(1)
	assert_true(str(meta.campaign_id) != old_id and str(meta.level_id) == "l01", "neither the pending save nor the transition saved the dead run")


func test_both_knights_dying_together_and_lava() -> void:
	await _progress(3, "l15", 4)
	RunState.reset()
	var g := _game(3, CampaignGame.StartMode.LOAD)
	assert_eq(g.begin(), OK, "loads")
	await physics_frames(3)
	var lava: Hazard
	for node in g.level.find_children("*", "", true, false):
		if node is Hazard and (node as Hazard).kind == Hazard.Kind.LAVA:
			lava = node
			break
	assert_true(lava != null, "the level has lava")
	g.knights[0].teleport_to(lava.global_position + Vector2(lava.size.x * 0.5, 4))
	g.knights[1].health.apply_damage(99)
	for i in 120:
		await physics_frames(1)
		if g.wipes > 0 and g.phase == CampaignGame.Phase.PLAYING:
			break
	assert_eq(g.wipes, 1, "lava and a second death in the same moment: one wipe")
	assert_eq(RunState.current().coins, 0, "coins reset")


func test_corrupted_production_saves_are_never_accepted() -> void:
	await _progress(1, "l09", 3)
	var good := SaveTestUtil.read(DIR, "slot_1.save")
	var body := SaveTestUtil.body_of(good)
	var doc: Dictionary = JSON.parse_string(body)
	var cases := {
		"tampered checksum": good.replace("\"coins\": 3", "\"coins\": 99"),
		"invalid JSON": "TKCSAVE 1 abc\n{ not json",
		"future format": SaveTestUtil.resign(JSON.stringify(_with(doc, ["format_version"], 99))),
		"missing players": SaveTestUtil.resign(JSON.stringify(_without(doc, ["header", "players"]))),
		"health above maximum": SaveTestUtil.resign(JSON.stringify(_with(doc, ["run", "players", "1", "current_health"], 40))),
		"negative upgrade": SaveTestUtil.resign(JSON.stringify(_with(doc, ["run", "players", "2", "attack_power_bonus"], -3))),
		"unknown level id": SaveTestUtil.resign(JSON.stringify(_with(_with(doc, ["header", "level_id"], "l99"), ["run", "campaign", "level_id"], "l99"))),
		"scene path as level": SaveTestUtil.resign(JSON.stringify(_with(doc, ["header", "level_id"], "res://scenes/worlds/world_01_ancient_forest/level_01.tscn"))),
		"duplicate coin ids": SaveTestUtil.resign(JSON.stringify(_with(doc, ["world", "coins"], [
			{"id": "dup", "x": 10.0, "y": 10.0, "vx": 0.0, "vy": 0.0, "resting": true, "delay": 0.0},
			{"id": "dup", "x": 12.0, "y": 10.0, "vx": 0.0, "vy": 0.0, "resting": true, "delay": 0.0}]))),
	}
	for name: String in cases:
		SaveTestUtil.write(DIR, "slot_1.save", cases[name])
		DirAccess.remove_absolute(DIR + "slot_1.bak")
		var manager := SaveManager.new(DIR)
		assert_eq(manager.slot_status(1), SaveManager.Status.CORRUPTED, "%s: reported damaged" % name)
		RunState.reset()
		var before := RunState.current().campaign.campaign_id
		assert_false(manager.load_run(1).ok, "%s: refused" % name)
		assert_eq(RunState.current().campaign.campaign_id, before, "%s: nothing applied" % name)
	# A damaged primary with a valid backup is recovered (and says so).
	SaveTestUtil.write(DIR, "slot_1.save", "TKCSAVE 1 abc\n{ not json")
	SaveTestUtil.write(DIR, "slot_1.bak", good)
	var m := SaveManager.new(DIR)
	assert_eq(m.slot_status(1), SaveManager.Status.RECOVERED, "backup found")
	var result := m.load_run(1)
	assert_true(result.ok and result.status == "RECOVERED", "loaded from the backup")
	assert_eq(m.slot_status(1), SaveManager.Status.VALID, "primary repaired")


static func _with(doc: Dictionary, path: Array, value: Variant) -> Dictionary:
	var copy := doc.duplicate(true)
	var node: Dictionary = copy
	for i in path.size() - 1:
		node = node[path[i]]
	node[path[-1]] = value
	return copy


static func _without(doc: Dictionary, path: Array) -> Dictionary:
	var copy := doc.duplicate(true)
	var node: Dictionary = copy
	for i in path.size() - 1:
		node = node[path[i]]
	node.erase(path[-1])
	return copy
