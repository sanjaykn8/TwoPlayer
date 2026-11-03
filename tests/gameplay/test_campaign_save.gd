extends GameTestCase
## Saving and restoring a real campaign (CampaignGame + development levels w1_l1 / w1_l2):
## players, stats, effects, coins, collectibles, enemies (defeated, staggered), dropped coins,
## puzzles, gates, platforms; the restoration guard; autosave triggers; transitions.
## Floor y = 448 in both levels. Folder user://test_saves/.

const FLOOR := 448.0

var game: CampaignGame
var _attack := 90000


func before_each() -> void:
	SaveTestUtil.clean()
	SlotStore.fault = ""


func after_each() -> void:
	if is_instance_valid(game):
		game.queue_free()
	await physics_frames(2)
	SaveTestUtil.clean()


func _start(slot := 1, mode := CampaignGame.StartMode.NEW) -> CampaignGame:
	game = SaveTestUtil.make_game(self, slot, mode, SaveTestUtil.DIR, true)
	assert_eq(game.begin(), OK, "campaign begins")
	return game


## Frees the game and forgets the run, like quitting and launching again.
func _relaunch(slot := 1, frames_closed := 0) -> CampaignGame:
	game.queue_free()
	await physics_frames(2)
	RunState.reset()
	await physics_frames(frames_closed)
	return _start(slot, CampaignGame.StartMode.LOAD)


func _k(i: int) -> Knight:
	return game.knights[i]


func _node(path: String) -> Node:
	var node := game.level.get_node_or_null(path)
	return node if node != null and not node.is_queued_for_deletion() else null


func _hit(slime: Slime) -> void:
	_attack += 1
	var event := DamageEvent.create(1, DamageEvent.Category.MELEE, _k(0))
	event.attack_id = _attack
	slime.hurtbox.receive_hit(event)


func _stand(knight: Knight, x: float, frames := 8) -> void:
	knight.teleport_to(Vector2(x, FLOOR))
	await physics_frames(frames)


# --- Full save and restore --------------------------------------------------------------------

func test_everything_restores_after_a_relaunch() -> void:
	_start()
	await physics_frames(5)
	var run := RunState.current()
	# Defeat slime A (2 hits stagger, 1 more kills); its coins drop and settle.
	var slime_a := _node("Enemies/SlimeA") as Slime
	for i in 3:
		_hit(slime_a)
	await physics_frames(70)
	# Collect: P1 green jar + yellow fruit, P2 red fruit.
	await _stand(_k(0), 352)
	await _stand(_k(0), 320)
	await _stand(_k(1), 384)
	_k(1).health.take_damage(DamageEvent.create(1, DamageEvent.Category.CONTACT, self))
	run.player(2).effects.add_tile_effect(PlayerEffects.SPEED_BOOST)
	# Puzzle: both plates -> lock completed, gate latched open.
	_k(0).teleport_to(Vector2(496, FLOOR))
	_k(1).teleport_to(Vector2(560, FLOOR))
	await physics_frames(30)
	# Slime B: staggered (purple: 4 hits), then let its timer run a bit.
	var slime_b := _node("Enemies/SlimeB") as Slime
	for i in 4:
		_hit(slime_b)
	run.coins += 3
	await _stand(_k(0), 590, 30)
	_k(0).facing = -1
	await _stand(_k(1), 640, 30)
	# Expectations, captured in the same frame as the save.
	var lift := _node("Platforms/Lift") as MovingPlatform
	var timed := _node("Platforms/Timed") as TimedPlatform
	var coins_left := {}
	for node in game.level.find_children("*", "DroppedCoin", true, false):
		if not node.is_queued_for_deletion() and not (node as DroppedCoin).is_collected():
			coins_left[(node as DroppedCoin).save_id] = (node as DroppedCoin).global_position
	var exp := {
		"p1": _k(0).global_position, "p2": _k(1).global_position, "p1_facing": _k(0).facing,
		"p1_safe": _k(0).safe_spot.last_safe_position, "hp1": _k(0).health.current_health,
		"max1": _k(0).health.max_health, "hp2": _k(1).health.current_health, "coins": run.coins,
		"shield": run.player(1).effects.charges(PlayerEffects.FRUIT_SHIELD),
		"shield_left": run.player(1).effects.remaining(PlayerEffects.FRUIT_SHIELD),
		"speed_left": run.player(2).effects.remaining(PlayerEffects.SPEED_BOOST),
		"range2": run.player(2).range_multiplier(),
		"b_progress": slime_b.stagger.progress, "b_left": slime_b.stagger.time_left,
		"lift": lift.progress, "timed_state": timed.state, "timed_time": timed.time_in_state,
		"campaign": run.campaign.campaign_id,
	}
	assert_true(slime_b.stagger.staggered, "precondition: slime B staggered")
	assert_eq((_node("Puzzles/Lock") as PuzzleLogic).state, PuzzleLogic.State.COMPLETED, "precondition: lock done")
	assert_gt(float(coins_left.size()), 0.0, "precondition: dropped coins on the ground")
	assert_eq(game.save_now("test"), OK, "saved")
	await _relaunch(1, 120)  # two seconds pass while the game is closed
	# Checked before a single physics frame of the restored level has run.
	run = RunState.current()
	assert_eq(run.campaign.campaign_id, exp.campaign, "same campaign")
	assert_eq(_k(0).global_position, exp.p1, "P1 position")
	assert_eq(_k(1).global_position, exp.p2, "P2 position")
	assert_eq(_k(0).facing, exp.p1_facing, "P1 facing")
	assert_eq(_k(0).safe_spot.last_safe_position, exp.p1_safe, "P1 last safe position")
	assert_eq(_k(0).health.current_health, exp.hp1, "P1 health")
	assert_eq(_k(0).health.max_health, exp.max1, "P1 maximum health (green jar)")
	assert_eq(_k(1).health.current_health, exp.hp2, "P2 health")
	assert_eq(run.coins, exp.coins, "shared coins")
	assert_near(run.player(2).range_multiplier(), exp.range2, 0.0001, "P2 range upgrade (red fruit)")
	assert_eq(run.player(1).effects.charges(PlayerEffects.FRUIT_SHIELD), exp.shield, "P1 shield charges")
	assert_near(run.player(1).effects.remaining(PlayerEffects.FRUIT_SHIELD), exp.shield_left, 0.0001, "shield time did not run while closed")
	assert_near(run.player(2).effects.remaining(PlayerEffects.SPEED_BOOST), exp.speed_left, 0.0001, "speed boost time did not run while closed")
	for item in ["Items/JarGreen", "Items/FruitYellow", "Items/FruitRed"]:
		assert_true(_node(item) == null, "%s stays collected" % item)
	assert_true(_node("Enemies/SlimeA") == null, "defeated slime does not respawn")
	var b := _node("Enemies/SlimeB") as Slime
	assert_true(b.stagger.staggered and b.state == Slime.State.STAGGERED, "slime B still staggered")
	assert_eq(b.stagger.progress, exp.b_progress, "stagger progress")
	assert_near(b.stagger.time_left, exp.b_left, 0.0001, "remaining stagger time")
	assert_eq((_node("Puzzles/Lock") as PuzzleLogic).state, PuzzleLogic.State.COMPLETED, "puzzle completed")
	assert_eq((_node("Puzzles/Gate") as PuzzleGate).state, PuzzleGate.State.OPEN, "gate open")
	assert_near((_node("Platforms/Lift") as MovingPlatform).progress, exp.lift, 0.0001, "moving platform position")
	assert_eq((_node("Platforms/Timed") as TimedPlatform).state, exp.timed_state, "timed platform state")
	assert_near((_node("Platforms/Timed") as TimedPlatform).time_in_state, exp.timed_time, 0.0001, "timed platform timer")
	var restored := {}
	for node in game.level.find_children("*", "DroppedCoin", true, false):
		restored[(node as DroppedCoin).save_id] = (node as DroppedCoin).global_position
	assert_eq(restored, coins_left, "uncollected dropped coins restored with their ids and positions")
	assert_eq(game.restore_problems, PackedStringArray(), "no restore problems")
	assert_false(_k(0).is_dead() or _k(1).is_dead(), "nobody restored dead")
	assert_eq(_k(0).combat.state, CombatComponent.State.IDLE, "no attack carried over")


func test_nothing_interacts_before_restoration_finishes() -> void:
	_start()
	await physics_frames(5)
	var jar := _node("Items/JarGreen") as Node2D
	var slime_b := _node("Enemies/SlimeB") as Slime
	_k(0).teleport_to(jar.global_position)        # standing on an uncollected jar
	_k(1).teleport_to(slime_b.global_position)    # standing inside a slime
	assert_eq(game.save_now("test"), OK, "saved in the same frame")
	await _relaunch()
	var events := []
	RunState.current().item_collected.connect(func(id: String, _p: int, _k2: String) -> void: events.append(id))
	_k(1).health.damage_received.connect(func(_e: DamageEvent, _a: int) -> void: events.append("damage"))
	assert_true(_node("Items/JarGreen") != null, "the jar is still there right after loading")
	assert_eq(events, [], "no pickup or damage happened during restoration")
	assert_eq(game.phase, CampaignGame.Phase.PLAYING, "gameplay enabled only after restoring")
	await physics_frames(10)
	assert_true(events.has("w1_l1_jar_green"), "interactions resume once play starts")


func test_unsafe_restored_positions_are_corrected() -> void:
	_start()
	await physics_frames(20)
	var world := WorldSnapshot.capture(game.level, game.knights)
	world.players["1"].x = 8.0                     # inside the left wall
	world.players["1"].y = 300.0
	var timed := _node("Platforms/Timed") as TimedPlatform
	world.platforms["w1l1_timed"] = {"state": TimedPlatform.State.ACTIVE, "time": 0.5}
	world.players["2"].x = timed.global_position.x + 16.0   # inside the timed platform
	world.players["2"].y = timed.global_position.y + 8.0
	world.enemies["w1l1_slime_b"].stagger_left = -5.0       # corrupt entity
	assert_eq(game.saves.save_active_run(world), OK, "saved")
	await _relaunch()
	assert_true(WorldSnapshot.knight_position_is_clear(_k(0)), "P1 moved out of the wall")
	assert_eq((_node("Platforms/Timed") as TimedPlatform).state, TimedPlatform.State.REACTIVATING, "platform does not become solid inside P2")
	assert_eq(game.restore_problems.size(), 3, "all three problems reported (%s)" % str(game.restore_problems))
	var b := _node("Enemies/SlimeB") as Slime
	assert_true(b != null and not b.is_dead(), "the bad entity falls back to its level start; the rest loads")


# --- Autosave ----------------------------------------------------------------------------------

func test_save_point_autosaves_once_per_visit() -> void:
	_start()
	await physics_frames(5)
	var before := game.saves.save_count
	await _stand(_k(0), 430, 10)
	assert_eq(game.saves.save_count, before + 1, "reaching the save point saved")
	assert_eq(game.last_save_reason, "save_point:w1l1_sp_1", "reason")
	await physics_frames(60)
	assert_eq(game.saves.save_count, before + 1, "standing there does not save again")


func test_puzzle_completion_autosaves() -> void:
	_start()
	await physics_frames(5)
	_k(0).teleport_to(Vector2(496, FLOOR))
	_k(1).teleport_to(Vector2(560, FLOOR))
	await physics_frames(20)
	assert_eq(game.last_save_reason, "puzzle:w1l1_lock", "milestone saved")
	assert_true(game.saves.get_slot_metadata(1).valid, "slot valid")


func test_requests_in_one_frame_coalesce() -> void:
	_start()
	await physics_frames(5)
	var before := game.saves.save_count
	for i in 5:
		game.request_autosave("burst %d" % i)
	await physics_frames(3)
	assert_eq(game.saves.save_count, before + 1, "one save for a burst of requests")


func test_level_transition_saves_the_new_level_and_keeps_progress() -> void:
	_start()
	await physics_frames(5)
	await _stand(_k(0), 352)  # green jar
	var max_hp := _k(0).health.max_health
	var campaign := RunState.current().campaign
	await _stand(_k(1), 1510, 2)  # P2 reaches the exit; P1 is elsewhere
	await physics_frames(5)
	assert_eq(campaign.level_id, "w1_l2", "moved to the next level")
	assert_true(campaign.completed_levels.has("w1_l1"), "w1_l1 completed")
	assert_eq(game.last_save_reason, "level_start:w1_l2", "saved after the new level was built")
	assert_eq(game.saves.get_slot_metadata(1).level_id, "w1_l2", "slot points at level 2")
	assert_eq(game.knights.size(), 2, "both knights in the new level")
	assert_lt(_k(0).global_position.x, 120.0, "P1 came along too, at the spawn")
	assert_eq(_k(0).health.max_health, max_hp, "upgrade carried over")
	# Progress in level 2, then relaunch: it resumes in level 2.
	await _stand(_k(0), 900)
	game.save_now("test")
	await _relaunch()
	assert_eq(RunState.current().campaign.level_id, "w1_l2", "resumes in level 2")
	assert_true(RunState.current().is_collected("w1_l2_jar_blue"), "level 2 jar kept")
	assert_eq(_k(0).health.max_health, max_hp, "upgrade kept")


func test_finishing_the_last_level_marks_the_campaign_complete() -> void:
	_start()
	await physics_frames(5)
	game.complete_level()
	await physics_frames(5)
	await _stand(_k(0), 1070, 5)
	assert_true(RunState.current().campaign.flags.get("finished", false), "finished")
	assert_eq(game.last_save_reason, "campaign_complete", "saved")


func test_playtime_counts_and_restores() -> void:
	_start()
	await physics_frames(60)
	var time := RunState.current().campaign.playtime
	assert_near(time, 1.0, 0.1, "about one second of play")
	game.save_now("test")
	await _relaunch(1, 120)
	assert_near(RunState.current().campaign.playtime, time, 0.0001, "restored, not advanced while closed")


func test_campaign_levels_have_unique_ids() -> void:
	for level_id in LevelCatalog.all_levels():
		var level := (load(LevelCatalog.scene_for(level_id)) as PackedScene).instantiate()
		assert_eq(SaveIds.find_duplicates(level), PackedStringArray(), "%s: no duplicate ids" % level_id)
		for node in level.find_children("*", "", true, false):
			if node is Slime or node is PlatformBody:
				assert_true(SaveIds.is_valid_id(str(node.get(&"save_id"))), "%s: %s has a save id" % [level_id, node.name])
		level.free()
	var probe := Node2D.new()
	for i in 2:
		var plate := (load("res://scenes/puzzles/pressure_plate.tscn") as PackedScene).instantiate()
		plate.set(&"puzzle_id", "same")
		probe.add_child(plate)
	var dupes := SaveIds.find_duplicates(probe)
	assert_eq(dupes.size(), 1, "a duplicate is detected")
	assert_true(dupes[0].contains("puzzle:same") and dupes[0].contains("PressurePlate"), "and named with its nodes: %s" % dupes[0])
	probe.free()
