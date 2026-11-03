extends GameTestCase
## The production campaign at run time (Phase 10, prompt Parts F, G, H, L, O, T), played
## through the real CampaignGame on the test folder user://test_saves_campaign/.

const DIR := "user://test_saves_campaign/"

var game: CampaignGame


func before_each() -> void:
	SaveTestUtil.clean(DIR)
	LevelCatalog.use_production()  # clean() selects the development campaign; this suite needs production
	RunState.reset()


func after_each() -> void:
	get_tree().paused = false
	if is_instance_valid(game):
		game.queue_free()
	await physics_frames(2)
	SaveTestUtil.clean(DIR)
	LevelCatalog.use_production()


func _start() -> void:
	game = SaveTestUtil.make_game(self, 1, CampaignGame.StartMode.NEW, DIR, true)
	assert_eq(game.begin(), OK, "campaign begins")
	await physics_frames(3)


func _k(i: int) -> Knight:
	return game.knights[i]


## Loads `level_id` as the current campaign level (as a transition would).
func _go(level_id: String) -> void:
	RunState.current().campaign.enter_level(level_id)
	assert_eq(game._load_level(level_id, {}), "", "%s loads" % level_id)
	await physics_frames(2)


func test_new_campaign_starts_at_level_one() -> void:
	await _start()
	assert_eq(RunState.current().campaign.level_id, LevelCatalog.first_level(), "first level")
	assert_eq(LevelCatalog.first_level(), "l01", "l01")
	assert_eq(game.level.get_meta(&"level_id"), "l01", "level 1 scene")


func test_every_level_spawns_both_knights_safely() -> void:
	await _start()
	for id in LevelCatalog.all_levels():
		await _go(id)
		var bounds := LevelCatalog.level(id).camera_bounds
		assert_eq(game.rig.bounds, bounds, "%s: the camera uses this level's bounds" % id)
		for k in game.knights:
			assert_true(WorldSnapshot.knight_position_is_clear(k), "%s: P%d not inside geometry" % [id, k.player_id()])
		var hurt_before := [_k(0).health.current_health, _k(1).health.current_health]
		await physics_frames(45)
		for k in game.knights:
			assert_true(k.is_on_floor(), "%s: P%d stands at its spawn" % [id, k.player_id()])
			assert_true(k.global_position.distance_to(LevelCatalog.level(id).spawn_p1 if k.player_id() == 1 else LevelCatalog.level(id).spawn_p2) < 24.0,
				"%s: P%d did not fall or get pushed away" % [id, k.player_id()])
		assert_eq([_k(0).health.current_health, _k(1).health.current_health], hurt_before, "%s: nothing hurts the knights at spawn" % id)
		for slime in get_tree().get_nodes_in_group(&"slimes"):
			if game.level.is_ancestor_of(slime):
				for k in game.knights:
					assert_gt((slime as Node2D).global_position.distance_to(k.global_position), 48.0, "%s: %s not on top of P%d" % [id, slime.name, k.player_id()])
		assert_eq(game.phase, CampaignGame.Phase.PLAYING, "%s: playing" % id)


func test_one_knight_at_the_exit_moves_both_and_keeps_progress() -> void:
	await _start()
	var run := RunState.current()
	run.collect_coin(1)
	run.player(2).collect_jar(PlayerStats.JarType.RED)
	_k(1).health.take_damage(DamageEvent.create(1, DamageEvent.Category.CONTACT, self))
	run.campaign.playtime = 50.0
	var exit := game.level.get_node("Campaign/Exit") as LevelExit
	# P2 stays far behind at the spawn (split-screen) while P1 reaches the exit.
	_k(0).teleport_to(exit.global_position + Vector2(-40, 0))
	game.rig.snap_to_targets()
	Input.action_press(&"p1_move_right")
	for i in 180:
		await physics_frames(1)
		if run.campaign.level_id != "l01":
			break
	Input.action_release(&"p1_move_right")
	await physics_frames(3)
	assert_eq(run.campaign.level_id, "l02", "the level was completed by P1 alone")
	assert_true(run.campaign.completed_levels.has("l01"), "l01 marked completed")
	assert_true(run.campaign.level_times.has("l01"), "completion time recorded")
	assert_eq(game.knights.size(), 2, "both knights in the next level")
	assert_near(_k(0).global_position.x, LevelCatalog.level("l02").spawn_p1.x, 1.0, "P1 at the new spawn")
	assert_near(_k(1).global_position.x, LevelCatalog.level("l02").spawn_p2.x, 1.0, "P2 at the new spawn")
	assert_eq(_k(1).health.current_health, 2, "health is not refilled by a transition")
	assert_eq(run.player(2).attack_power(), 2, "upgrades kept")
	assert_eq(run.coins, 1, "shared coins kept")
	assert_eq(game.saves.get_slot_metadata(1).level_id, "l02", "the new level was saved")


func test_split_screen_exit_and_single_transition() -> void:
	await _start()
	var exit := game.level.get_node("Campaign/Exit") as LevelExit
	_k(0).teleport_to(exit.global_position + Vector2(-64, 0))
	await physics_frames(40)
	assert_true(game.rig.is_split(), "the knights are in split-screen (P2 far behind)")
	_k(0).teleport_to(exit.global_position + Vector2(8, 0))
	game.complete_level()  # the exit and a second completion request in the same frame
	await physics_frames(30)
	assert_eq(RunState.current().campaign.level_id, "l02", "exactly one transition")
	assert_eq(RunState.current().campaign.completed_levels.count("l01"), 1, "l01 completed once")
	assert_false(RunState.current().campaign.completed_levels.has("l02"), "l02 not skipped")


func test_save_and_resume_in_every_world() -> void:
	await _start()
	for world_id in LevelCatalog.world_ids():
		var id: String = LevelCatalog.levels_of(world_id)[1]
		await _go(id)
		RunState.current().collect_coin(1)
		_k(0).teleport_to(_k(0).global_position + Vector2(24, 0))
		await physics_frames(10)
		var x := _k(0).global_position.x
		var coins := RunState.current().coins
		assert_eq(game.save_now("test"), OK, "%s saved" % id)
		game.queue_free()
		await physics_frames(2)
		RunState.reset()
		game = SaveTestUtil.make_game(self, 1, CampaignGame.StartMode.LOAD, DIR)
		assert_eq(game.begin(), OK, "%s loads" % id)
		await physics_frames(2)
		assert_eq(RunState.current().campaign.level_id, id, "%s resumed in the right level" % id)
		assert_eq(RunState.current().campaign.world_id, world_id, "%s right world" % id)
		assert_eq(RunState.current().coins, coins, "%s coins" % id)
		assert_near(_k(0).global_position.x, x, 2.0, "%s position" % id)


func test_team_wipe_in_a_later_world_resets_everything() -> void:
	await _start()
	var late: String = LevelCatalog.levels_of(LevelCatalog.world_ids().back())[0]
	await _go(late)
	var run := RunState.current()
	run.collect_coin(1)
	run.player(1).collect_jar(PlayerStats.JarType.GREEN)
	run.campaign.complete_level("l01")
	var old_id := run.campaign.campaign_id
	_k(1).health.apply_damage(99)
	for i in 120:
		await physics_frames(1)
		if game.wipes > 0 and game.phase == CampaignGame.Phase.PLAYING:
			break
	var fresh := RunState.current()
	assert_true(fresh.campaign.campaign_id != old_id, "a new run")
	assert_eq([fresh.campaign.level_id, fresh.coins, fresh.player(1).max_health(), fresh.campaign.completed_levels.size()],
		["l01", 0, 3, 0], "back to l01 with nothing")
	assert_eq(game.saves.get_slot_metadata(1).level_id, "l01", "the fresh run is saved")


func test_optional_boss_defeat_and_reward_persist() -> void:
	await _start()
	var boss_levels: Array[String] = []
	for id in LevelCatalog.all_levels():
		if LevelCatalog.level(id).boss_id != "":
			boss_levels.append(id)
	assert_gt(boss_levels.size(), 0, "optional bosses exist (the full count is in test_campaign_complete)")
	for id in boss_levels:
		await _go(id)
		var boss: BossSlime
		for node in game.level.find_children("*", "", true, false):
			if node is BossSlime:
				boss = node
		assert_true(boss != null, "%s has its boss" % id)
		var seal := boss.get_node(boss.seal) as BossSeal
		var gates := game.level.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is PuzzleGate and n.get_node_or_null((n as PuzzleGate).controller) == seal)
		assert_eq(gates.size(), 1, "%s: a reward gate wired to the seal" % id)
		assert_false((gates[0] as PuzzleGate).is_open(), "%s: reward closed before the fight" % id)
		# Defeat it with legitimate hits from both knights (each rule: daze window, armour).
		boss.state = BossSlime.State.DAZED
		var attack := 70000
		while boss.health > 0:
			for k in game.knights:
				attack += 1
				var e := DamageEvent.create(1, DamageEvent.Category.MELEE, k)
				e.attack_id = attack
				boss.hurtbox.receive_hit(e)
		assert_true(boss.is_dead(), "%s: boss defeated" % id)
		assert_true(seal.is_active(), "%s: seal active" % id)
		await physics_frames(40)
		assert_true((gates[0] as PuzzleGate).is_open() or (gates[0] as PuzzleGate).state == PuzzleGate.State.OPENING, "%s: reward gate opens" % id)
		assert_eq(game.save_now("boss"), OK, "%s saved" % id)
		game.queue_free()
		await physics_frames(2)
		RunState.reset()
		game = SaveTestUtil.make_game(self, 1, CampaignGame.StartMode.LOAD, DIR)
		assert_eq(game.begin(), OK, "%s reloads" % id)
		await physics_frames(3)
		var again := game.level.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is BossSlime and not n.is_queued_for_deletion())
		assert_eq(again.size(), 0, "%s: a defeated boss stays defeated" % id)
		var seal2 := game.level.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is BossSeal)[0] as BossSeal
		assert_true(seal2.is_active(), "%s: reward stays open after loading" % id)


func test_main_route_never_needs_a_boss() -> void:
	# Static proof is in test_campaign_levels (exit reachable with seals closed); here the
	# exit of each boss level works with the boss alive.
	await _start()
	for id in LevelCatalog.all_levels():
		if LevelCatalog.level(id).boss_id == "":
			continue
		await _go(id)
		game.complete_level()
		await physics_frames(3)
		assert_true(RunState.current().campaign.completed_levels.has(id), "%s completed with its boss alive" % id)


func test_final_level_completes_the_campaign() -> void:
	await _start()
	var final_id: String = LevelCatalog.all_levels().back()
	for id in LevelCatalog.all_levels():
		RunState.current().campaign.complete_level(id)
	await _go(final_id)
	var completed := [false]
	game.campaign_completed.connect(func() -> void: completed[0] = true)
	var exit := game.level.get_node("Campaign/Exit") as LevelExit
	_k(0).teleport_to(exit.global_position + Vector2(8, 0))
	await physics_frames(10)
	assert_true(completed[0], "campaign_completed emitted")
	var run := RunState.current()
	assert_true(run.campaign.flags.get("finished", false), "finished flag")
	assert_eq(run.campaign.completed_levels.size(), LevelCatalog.all_levels().size(), "all levels completed")
	var meta := game.saves.get_slot_metadata(1)
	assert_true(meta.finished and meta.valid, "the completed result is saved (not deleted)")
	assert_eq(int(meta.levels_completed), LevelCatalog.all_levels().size(), "every level recorded")


func test_wipe_beats_victory() -> void:
	await _start()
	await _go(LevelCatalog.all_levels().back())
	_k(1).health.apply_damage(99)
	game.complete_level()  # the exit reached in the same frame as the death
	await physics_frames(3)
	assert_false(RunState.current().campaign.flags.get("finished", false), "no victory for a dead team")
	assert_eq(game.phase, CampaignGame.Phase.WIPING, "the team wipe wins")
