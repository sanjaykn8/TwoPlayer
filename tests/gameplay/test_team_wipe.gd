extends GameTestCase
## Campaign-wide team wipe: either knight's death (health or lava) resets the whole run for
## both, only in the active slot; the dead campaign can never be loaded again; races (both
## dying, deaths during transitions and pending saves, duplicate signals) wipe exactly once;
## storage failures fail closed. Folder user://test_saves/ (wipe delay 0.1 s).

const FLOOR := 448.0

var game: CampaignGame
var _attack := 95000


func before_each() -> void:
	SaveTestUtil.clean()
	SlotStore.fault = ""


func after_each() -> void:
	SlotStore.fault = ""
	if is_instance_valid(game):
		game.queue_free()
	await physics_frames(2)
	SaveTestUtil.clean()


func _start(slot := 1) -> void:
	game = SaveTestUtil.make_game(self, slot, CampaignGame.StartMode.NEW, SaveTestUtil.DIR, true)
	assert_eq(game.begin(), OK, "campaign begins")
	await physics_frames(5)


func _k(i: int) -> Knight:
	return game.knights[i]


func _node(path: String) -> Node:
	var node := game.level.get_node_or_null(path)
	return node if node != null and not node.is_queued_for_deletion() else null


## Health to zero (raw, like any depletion; shields from _make_progress cannot block it).
func _kill(knight: Knight) -> void:
	knight.health.apply_damage(99)


func _wait_wipe() -> bool:
	for i in 120:
		if game.phase == CampaignGame.Phase.PLAYING and game.wipes > 0:
			return true
		await physics_frames(1)
	return false


## Collects upgrades, kills slime A, opens the puzzle gate, earns coins, then saves.
func _make_progress() -> void:
	var run := RunState.current()
	var slime := _node("Enemies/SlimeA") as Slime
	for i in 3:
		_attack += 1
		var event := DamageEvent.create(1, DamageEvent.Category.MELEE, _k(0))
		event.attack_id = _attack
		slime.hurtbox.receive_hit(event)
	await physics_frames(40)
	for x in [352.0, 320.0, 384.0]:
		_k(0).teleport_to(Vector2(x, FLOOR))
		await physics_frames(8)
	run.player(1).collect_jar(PlayerStats.JarType.RED)
	run.player(2).collect_jar(PlayerStats.JarType.BLUE)
	run.player(2).collect_fruit(PlayerStats.FruitType.PURPLE, 2)
	run.player(2).effects.add_tile_effect(PlayerEffects.TILE_SHIELD)
	run.coins = 25
	_k(0).teleport_to(Vector2(496, FLOOR))
	_k(1).teleport_to(Vector2(560, FLOOR))
	await physics_frames(20)
	assert_eq(game.save_now("progress"), OK, "progress saved")


## Every run-wide value is back at the start, and the world is the fresh first level.
func _assert_fresh(old_id: String) -> void:
	var run := RunState.current()
	assert_true(run.campaign.campaign_id != old_id, "a new campaign id")
	assert_eq(run.campaign.level_id, LevelCatalog.FIRST_LEVEL, "first level")
	assert_eq(run.campaign.completed_levels.size(), 0, "no completed levels")
	assert_eq(run.coins, 0, "coins back to zero")
	assert_eq(run.collected.size(), 0, "no collected items")
	for id in RunState.PLAYER_IDS:
		var s := run.player(id)
		assert_eq([s.max_health(), s.current_health, s.attack_power()], [3, 3, 1], "P%d health 3/3, power 1" % id)
		assert_eq(s.range_multiplier(), 1.0, "P%d base range" % id)
		assert_eq(s.speed_multiplier(), 1.0, "P%d base speed" % id)
		assert_eq(s.poison_seconds, 0.0, "P%d no poison" % id)
		assert_eq(s.effects.active_ids().size(), 0, "P%d no effects" % id)
	assert_eq(run.puzzles.scope_keys().size(), 0, "no puzzle or enemy progress")
	for knight in game.knights:
		assert_false(knight.is_dead(), "P%d alive in the new run" % knight.player_id())
		assert_eq(knight.health.max_health, 3, "P%d knight at 3 max health" % knight.player_id())
		assert_lt(knight.global_position.x, 120.0, "P%d at the start" % knight.player_id())
	assert_true(_node("Enemies/SlimeA") != null, "the defeated slime is back")
	assert_true(_node("Items/JarGreen") != null, "the collected jar is back")
	assert_eq((_node("Puzzles/Gate") as PuzzleGate).state, PuzzleGate.State.CLOSED, "the gate is closed again")
	assert_eq((_node("Puzzles/Lock") as PuzzleLogic).state, PuzzleLogic.State.INACTIVE, "the puzzle is unsolved")


## The slot holds only the fresh campaign; no file anywhere still names the dead one.
func _assert_slot_fresh(slot: int, old_id: String) -> void:
	var mgr := SaveManager.new(SaveTestUtil.DIR)
	assert_eq(mgr.slot_status(slot), SaveManager.Status.VALID, "slot %d valid" % slot)
	var meta := mgr.get_slot_metadata(slot)
	assert_eq(meta.campaign_id, RunState.current().campaign.campaign_id, "slot %d holds the new campaign" % slot)
	assert_eq([meta.coins, meta.level_id, meta.p1_max_health], [0, "w1_l1", 3], "slot %d metadata is fresh" % slot)
	for ext in ["save", "bak", "tmp", "dead"]:
		assert_false(SaveTestUtil.read(SaveTestUtil.DIR, "slot_%d.%s" % [slot, ext]).contains(old_id), "slot_%d.%s does not hold the dead campaign" % [slot, ext])


# --- Who dies --------------------------------------------------------------------------------

func test_player_one_death_resets_both() -> void:
	await _start()
	await _make_progress()
	var old_id := RunState.current().campaign.campaign_id
	var started := [0]
	game.team_wipe_started.connect(func() -> void: started[0] += 1)
	_kill(_k(0))
	assert_eq(game.phase, CampaignGame.Phase.WIPING, "wipe starts at once")
	assert_eq(game.saves.slot_status(1), SaveManager.Status.INVALIDATED, "the old campaign is invalidated before anything else")
	await physics_frames(1)
	assert_eq(game.level.process_mode, Node.PROCESS_MODE_DISABLED, "the world is frozen by the end of that frame")
	assert_false(_k(1).is_dead(), "P2 did not die, but the run is lost for both")
	assert_true(await _wait_wipe(), "the new run started")
	assert_eq(started[0], 1, "one wipe")
	_assert_fresh(old_id)
	_assert_slot_fresh(1, old_id)


func test_player_two_death_resets_both() -> void:
	await _start()
	await _make_progress()
	var old_id := RunState.current().campaign.campaign_id
	_kill(_k(1))
	assert_true(await _wait_wipe(), "new run")
	_assert_fresh(old_id)
	_assert_slot_fresh(1, old_id)


func test_lava_death_resets_both() -> void:
	await _start()
	await _make_progress()
	var old_id := RunState.current().campaign.campaign_id
	_k(0).teleport_to(Vector2(1208, FLOOR + 6))
	assert_true(await _wait_wipe(), "lava wiped the run")
	assert_eq(game.wipes, 1, "once")
	_assert_fresh(old_id)


func test_zero_health_through_ordinary_hits_resets_both() -> void:
	await _start()
	var old_id := RunState.current().campaign.campaign_id
	for i in 3:
		_k(1).health.clear_invulnerability()
		_k(1).health.take_damage(DamageEvent.create(1, DamageEvent.Category.CONTACT, self))
	assert_true(await _wait_wipe(), "health reached zero: wiped")
	_assert_fresh(old_id)


func test_fatal_fall_resets_both() -> void:
	await _start()
	var old_id := RunState.current().campaign.campaign_id
	_k(0).health.set_current_health(1)
	_k(0).teleport_to(Vector2(800, 380))  # over the pit, clear of the lift
	assert_true(await _wait_wipe(), "a fall at 1 HP wiped the run")
	_assert_fresh(old_id)


# --- Exactly once ----------------------------------------------------------------------------

func test_both_dying_in_one_frame_wipes_once() -> void:
	await _start()
	var count := [0]
	game.team_wipe_started.connect(func() -> void: count[0] += 1)
	_k(0).teleport_to(Vector2(1208, FLOOR + 6))  # lava ...
	_kill(_k(1))                                  # ... and a lethal hit in the same frame
	_kill(_k(0))
	_k(0).died.emit()                             # duplicate death signals
	_k(1).died.emit()
	assert_true(await _wait_wipe(), "new run")
	await physics_frames(30)
	assert_eq(count[0], 1, "exactly one team wipe")
	assert_eq(game.wipes, 1, "counted once")


func test_death_during_a_level_transition_wins() -> void:
	await _start()
	var old_id := RunState.current().campaign.campaign_id
	game.complete_level()           # transition scheduled for this frame's idle time
	assert_eq(game.phase, CampaignGame.Phase.TRANSITIONING, "transitioning")
	_kill(_k(0))                    # ... and a knight dies before it runs
	assert_true(await _wait_wipe(), "new run")
	assert_eq(RunState.current().campaign.level_id, LevelCatalog.FIRST_LEVEL, "back at the first level, not level 2")
	_assert_fresh(old_id)


func test_a_pending_autosave_cannot_bring_the_old_run_back() -> void:
	await _start()
	await _make_progress()
	var old_id := RunState.current().campaign.campaign_id
	game.request_autosave("pending")   # deferred to the end of the frame ...
	_kill(_k(0))                       # ... but the wipe happens first
	assert_true(await _wait_wipe(), "new run")
	await physics_frames(10)
	_assert_slot_fresh(1, old_id)
	assert_eq(game.saves.save_active_run({}, old_id), ERR_INVALID_DATA, "an explicit stale save is refused too")
	_assert_slot_fresh(1, old_id)


func test_close_request_during_the_wipe_never_saves_the_dead_run() -> void:
	await _start()
	await _make_progress()
	var old_id := RunState.current().campaign.campaign_id
	game.wipe_delay = 5.0
	_kill(_k(0))
	# Simulate the exit path without quitting the test runner: the phase is WIPING, so the
	# close handler must not save. (A real process exit is tested in test_exit_save.gd.)
	assert_eq(game.phase, CampaignGame.Phase.WIPING, "wiping")
	var before := game.saves.save_count
	game.save_now("exit attempt during wipe")
	assert_eq(game.saves.save_count, before, "a save during the wipe is refused")
	assert_eq(game.saves.slot_status(1), SaveManager.Status.INVALIDATED, "the dead campaign stays unloadable")
	assert_false(SaveTestUtil.read(SaveTestUtil.DIR, "slot_1.save").contains(old_id), "and is not on disk")


# --- Only the active slot ----------------------------------------------------------------------

func test_only_the_active_slot_is_reset() -> void:
	var mgr := SaveManager.new(SaveTestUtil.DIR)
	for s in [1, 2, 4]:
		mgr.start_new_run(s)
		RunState.current().coins = s * 100
		mgr.save_active_run({})
	var before := {}
	for s in [1, 2, 4]:
		before[s] = [SaveTestUtil.read(SaveTestUtil.DIR, "slot_%d.save" % s), SaveTestUtil.read(SaveTestUtil.DIR, "slot_%d.bak" % s)]
	await _start(3)
	await _make_progress()
	var old_id := RunState.current().campaign.campaign_id
	_kill(_k(0))
	assert_true(await _wait_wipe(), "slot 3 wiped")
	_assert_slot_fresh(3, old_id)
	for s in [1, 2, 4]:
		assert_eq([SaveTestUtil.read(SaveTestUtil.DIR, "slot_%d.save" % s), SaveTestUtil.read(SaveTestUtil.DIR, "slot_%d.bak" % s)], before[s], "slot %d untouched" % s)


func test_the_wipe_works_in_every_slot() -> void:
	for s in [1, 2, 3, 4]:
		RunState.reset()
		await _start(s)
		var old_id := RunState.current().campaign.campaign_id
		RunState.current().coins = 7
		game.save_now("progress")
		_kill(_k(1))
		assert_true(await _wait_wipe(), "slot %d wiped" % s)
		_assert_slot_fresh(s, old_id)
		game.queue_free()
		await physics_frames(2)


# --- Storage failures (fail-closed) ----------------------------------------------------------

func test_invalidation_failure_halts_instead_of_pretending() -> void:
	await _start()
	await _make_progress()
	var old_id := RunState.current().campaign.campaign_id
	SlotStore.fault = "marker"
	_kill(_k(0))
	await physics_frames(30)
	assert_eq(game.phase, CampaignGame.Phase.WIPE_FAILED, "halted")
	assert_eq(game.level.process_mode, Node.PROCESS_MODE_DISABLED, "the game does not continue")
	assert_eq(RunState.current().campaign.campaign_id, old_id, "no new run was faked")
	assert_true(game.last_notice.begins_with("STORAGE FAILURE"), "reported: %s" % game.last_notice)
	assert_true(game.saves.wipe_lock, "saving stays locked")


func test_fresh_run_save_failure_keeps_the_old_run_dead() -> void:
	await _start()
	await _make_progress()
	var old_id := RunState.current().campaign.campaign_id
	game.team_wipe_started.connect(func() -> void: SlotStore.fault = "tmp_write")
	_kill(_k(0))
	assert_true(await _wait_wipe(), "the new run started in memory")
	assert_true(game.fresh_run_unsaved, "reported as unsaved")
	assert_eq(game.saves.slot_status(1), SaveManager.Status.INVALIDATED, "the old campaign is still unloadable")
	SlotStore.fault = ""
	game.request_autosave("retry")
	await physics_frames(3)
	assert_false(game.fresh_run_unsaved, "the next save stores the fresh run")
	_assert_slot_fresh(1, old_id)
