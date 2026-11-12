extends GameTestCase
## Co-op edge cases in EVERY campaign level (final pass), through the real CampaignGame on
## its own save folder: one knight finishing alone while the partner is far behind, a death
## (either knight) restarting the campaign, quitting and reopening with effects running, and
## pickups, deaths and simultaneous actions under the redesigned power-ups. Then the co-op
## mechanisms added in the final pass, in their real levels.

const DIR := "user://test_saves_final/"
const ACTIONS := [&"p1_move_left", &"p1_move_right", &"p1_move_up", &"p1_move_down", &"p1_attack",
	&"p2_move_left", &"p2_move_right", &"p2_move_up", &"p2_move_down", &"p2_attack"]
const T := 16.0

var game: CampaignGame


func before_each() -> void:
	SaveTestUtil.clean(DIR)
	LevelCatalog.use_production()
	RunState.reset()
	for a in ACTIONS:
		Input.action_release(a)


func after_each() -> void:
	for a in ACTIONS:
		Input.action_release(a)
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


func _go(level_id: String) -> void:
	RunState.current().campaign.enter_level(level_id)
	assert_eq(game._load_level(level_id, {}), "", "%s loads" % level_id)
	await physics_frames(2)


func _node(node_name: String) -> Node:
	return game.level.find_child(node_name, true, false)


## Feet position of tile column x on floor row r.
func _at(x: float, r: int) -> Vector2:
	return Vector2(x * T + 8.0, r * T)


func _tap(actions: Array) -> void:
	for a: StringName in actions:
		Input.action_press(a)
	await physics_frames(1)
	for a: StringName in actions:
		Input.action_release(a)


# --- Every level ----------------------------------------------------------------------------

func test_either_knight_alone_at_the_exit_finishes_every_level() -> void:
	await _start()
	var levels := LevelCatalog.all_levels()
	var completed := [false]
	game.campaign_completed.connect(func() -> void: completed[0] = true)
	for i in levels.size():
		var id: String = levels[i]
		await _go(id)
		var run := RunState.current()
		var mover := i % 2  # P1 on odd levels, P2 on even ones
		var partner := _k(1 - mover)
		var partner_spawn := partner.global_position
		var hp := [_k(0).health.current_health, _k(1).health.current_health]
		var exit := game.level.get_node("Campaign/Exit") as LevelExit
		_k(mover).teleport_to(exit.global_position + Vector2(exit.size.x * 0.5, 0))
		assert_gt(partner_spawn.distance_to(exit.global_position), 400.0, "%s: the partner is far from the exit" % id)
		var done := false
		for f in 240:
			await physics_frames(1)
			if run.campaign.completed_levels.has(id):
				done = true
				break
		assert_true(done, "%s: P%d alone at the exit completes the level" % [id, mover + 1])
		await physics_frames(5)
		assert_eq(game.wipes, 0, "%s: nobody died" % id)
		if i + 1 < levels.size():
			assert_eq(run.campaign.level_id, levels[i + 1], "%s leads to %s" % [id, levels[i + 1]])
			assert_eq(game.knights.size(), 2, "%s: both knights arrive in the next level" % id)
			for n in 2:
				var spawn: Vector2 = LevelCatalog.level(levels[i + 1]).spawn_p1 if n == 0 else LevelCatalog.level(levels[i + 1]).spawn_p2
				assert_lt(_k(n).global_position.distance_to(spawn), 24.0, "%s: P%d starts the next level at its spawn" % [id, n + 1])
				assert_eq(_k(n).health.current_health, hp[n], "%s: P%d's health is carried over unchanged" % [id, n + 1])
		else:
			assert_true(completed[0], "the last level completes the campaign")


func test_a_death_in_any_level_restarts_the_campaign() -> void:
	await _start()
	var levels := LevelCatalog.all_levels()
	for i in levels.size():
		var id: String = levels[i]
		await _go(id)
		var run := RunState.current()
		run.collect_coin(3)
		run.player(1).collect_jar(PlayerStats.JarType.YELLOW)
		run.player(2).collect_fruit(PlayerStats.FruitType.PURPLE, 3)
		run.player(2).effects.add_tile_effect(PlayerEffects.SPEED_BOOST)
		var old_id := run.campaign.campaign_id
		var wipes := game.wipes
		_k(i % 2).health.apply_damage(99)
		for f in 180:
			await physics_frames(1)
			if game.wipes > wipes and game.phase == CampaignGame.Phase.PLAYING:
				break
		var fresh := RunState.current()
		assert_eq(game.wipes, wipes + 1, "%s: P%d dying is exactly one team wipe" % [id, i % 2 + 1])
		assert_true(fresh.campaign.campaign_id != old_id, "%s: a new run" % id)
		assert_eq(fresh.campaign.level_id, "l01", "%s: back to the first level" % id)
		assert_eq(fresh.coins, 0, "%s: coins reset" % id)
		for n in [1, 2]:
			assert_eq(fresh.player(n).effects.active_ids().size(), 0, "%s: P%d keeps no effect or ward from the dead run" % [id, n])
			assert_eq(fresh.player(n).max_health(), 3, "%s: P%d back to base health" % [id, n])
		assert_eq(game.saves.get_slot_metadata(1).level_id, "l01", "%s: only the fresh run is on disk" % id)


func test_quit_and_reopen_in_every_level_with_effects_running() -> void:
	await _start()
	for id: String in LevelCatalog.all_levels():
		await _go(id)
		var run := RunState.current()
		run.collect_coin(1)
		var p1 := run.player(1)
		var p2 := run.player(2)
		p1.effects.add_venom(2)
		p1.effects.add_tile_effect(PlayerEffects.SPEED_BOOST)
		if p2.can_use_jar(PlayerStats.JarType.YELLOW):
			p2.collect_jar(PlayerStats.JarType.YELLOW)
		if p2.effects.ward_is_ready():
			p2.effects.resolve_protection(DamageEvent.create(1, DamageEvent.Category.CONTACT))
		_k(1).teleport_to(_k(1).global_position + Vector2(24, 0))
		await physics_frames(20)
		var want := [run.coins, p1.effects.remaining(PlayerEffects.VENOM), p1.effects.remaining(PlayerEffects.SPEED_BOOST),
			p2.effects.ward_level, p2.effects.ward_cooldown, _k(1).global_position.x]
		# The window's close request: quitting is not dying. The run is saved, then the game
		# asks to quit (here the quit handler only records it).
		var quit_codes: Array[int] = []
		game.quit_handler = func(code: int) -> void: quit_codes.append(code)
		game.handle_close_request()
		await physics_frames(3)
		assert_eq(quit_codes, [0] as Array[int], "%s: the close request saved and quit cleanly" % id)
		game.queue_free()
		await physics_frames(2)
		RunState.reset()
		game = SaveTestUtil.make_game(self, 1, CampaignGame.StartMode.LOAD, DIR)
		assert_eq(game.begin(), OK, "%s: the save loads" % id)
		await physics_frames(2)
		run = RunState.current()
		p1 = run.player(1)
		p2 = run.player(2)
		assert_eq(run.campaign.level_id, id, "%s: resumed in the same level" % id)
		assert_eq(game.wipes, 0, "%s: quitting killed nobody" % id)
		assert_eq(run.coins, want[0], "%s: coins" % id)
		assert_near(p1.effects.remaining(PlayerEffects.VENOM), want[1], 0.1, "%s: P1's venom timer" % id)
		assert_near(p1.effects.remaining(PlayerEffects.SPEED_BOOST), want[2], 0.1, "%s: P1's haste timer" % id)
		assert_false(p2.effects.has(PlayerEffects.VENOM), "%s: P2 did not gain P1's venom" % id)
		assert_eq(p2.effects.ward_level, want[3], "%s: P2's ward level" % id)
		assert_near(p2.effects.ward_cooldown, want[4], 0.1, "%s: P2's ward recharge" % id)
		assert_near(_k(1).global_position.x, want[5], 2.0, "%s: P2's position" % id)


# --- Power-ups between two knights -----------------------------------------------------------

func test_a_pickup_far_from_the_partner_affects_only_the_collector_except_the_feast() -> void:
	await _start()
	await _go("l04")
	var run := RunState.current()
	# The venom fruit on the lantern islet; P2 stays at the spawn, far away.
	_k(0).teleport_to(_at(71, 27))
	await physics_frames(6)
	assert_true(run.player(1).effects.has(PlayerEffects.VENOM), "P1 took the venom fruit")
	assert_false(run.player(2).effects.has(PlayerEffects.VENOM), "P2, elsewhere, did not")
	assert_gt(_k(0).combat.stats.poison_seconds, 0.0, "P1's blade is venomous")
	assert_eq(_k(1).combat.stats.poison_seconds, 0.0, "P2's is not")
	# The feast on the temple roof heals the eater by 3 and the far partner by 1.
	await _go("l11")
	run = RunState.current()
	for n in [1, 2]:
		run.player(n).collect_jar(PlayerStats.JarType.GREEN)
		run.player(n).collect_jar(PlayerStats.JarType.GREEN)
	_k(0).health.apply_damage(4)
	_k(1).health.apply_damage(2)
	await physics_frames(2)
	_k(0).teleport_to(_at(69, 12))
	await physics_frames(6)
	assert_eq(_k(0).health.current_health, 4, "the eater heals 3 (1 -> 4)")
	assert_eq(_k(1).health.current_health, 4, "the partner, far away, heals 1 (3 -> 4)")


func test_both_knights_on_one_jar_in_the_same_frame() -> void:
	await _start()
	await _go("l03")
	var run := RunState.current()
	var jar := _node("JarGreen1") as Jar
	if jar == null:
		for node in game.level.find_children("*", "", true, false):
			if node is Jar:
				jar = node
	assert_not_null(jar, "l03 has its green jar")
	_k(0).teleport_to(jar.global_position)
	_k(1).teleport_to(jar.global_position)
	await physics_frames(8)
	assert_true(jar.claimed, "the jar is taken")
	assert_eq(run.player(1).max_health_bonus + run.player(2).max_health_bonus, 1, "by exactly one knight, once")


func test_death_under_temporary_effects_leaves_nothing_behind() -> void:
	await _start()
	await _go("l13")
	var run := RunState.current()
	var p1 := run.player(1)
	p1.collect_fruit(PlayerStats.FruitType.YELLOW, 3)
	p1.collect_fruit(PlayerStats.FruitType.PURPLE, 3)
	p1.effects.add_tile_effect(PlayerEffects.ATTACK_SPEED)
	p1.collect_jar(PlayerStats.JarType.YELLOW)
	await physics_frames(5)
	# Lava ignores every protection: three shield charges and a ready ward do not save the knight.
	var hp := _k(0).health.current_health
	assert_eq(_k(0).health.take_damage(DamageEvent.create(99, DamageEvent.Category.LAVA)), hp, "lava passes shield and ward")
	for f in 180:
		await physics_frames(1)
		if game.wipes > 0 and game.phase == CampaignGame.Phase.PLAYING:
			break
	assert_eq(game.wipes, 1, "one team wipe")
	var fresh := RunState.current()
	assert_eq(fresh.player(1).effects.active_ids().size(), 0, "no effect survives the wipe")
	assert_eq(fresh.player(1).effects.ward_level, 0, "the ward was earned in the dead run and is gone")
	assert_eq(_k(0).combat.stats.poison_seconds, 0.0, "the new knight's blade is clean")
	assert_eq(_k(0).combat.effective_cooldown(), _k(0).combat.config.cooldown, "and swings at the base pace")


# --- The co-op mechanisms added in the final pass ---------------------------------------------

func test_l05_jar_door_opens_only_while_the_partner_holds_the_stone() -> void:
	await _start()
	await _go("l05")
	var gate := _node("JarGate") as PuzzleGate
	var plate := _node("WindPlate") as PressurePlate
	assert_not_null(gate, "JarGate")
	assert_not_null(plate, "WindPlate")
	_k(0).teleport_to(_at(99, 30))  # in the crystal room, before the door
	await physics_frames(20)
	assert_false(gate.is_open(), "the door is shut while nobody holds the stone")
	_k(1).teleport_to(plate.global_position + Vector2(plate.width * 0.5, 0))
	for f in 90:
		await physics_frames(1)
		if gate.is_open():
			break
	assert_true(gate.is_open(), "P2 on the stone below opens the door above")
	_k(0).teleport_to(_at(103, 30))
	await physics_frames(8)
	assert_true(RunState.current().player(1).effects.has(PlayerEffects.WARD), "P1 takes the yellow jar: a ward")
	assert_false(RunState.current().player(2).effects.has(PlayerEffects.WARD), "the holder gets none (the jar is the collector's)")
	# The holder walks away while P1 is still inside the niche: the door never shuts on a
	# knight in its doorway, so P1 is unhurt and can simply walk out.
	var hp := _k(0).health.current_health
	_k(1).teleport_to(_at(84, 44))
	await physics_frames(120)
	assert_eq(_k(0).health.current_health, hp, "the knight inside is not hurt")
	assert_false(gate.is_solid(), "the door does not shut on the knight in the niche")
	Input.action_press(&"p1_move_left")
	await physics_frames(40)
	Input.action_release(&"p1_move_left")
	assert_lt(_k(0).global_position.x, 102.0 * T, "P1 walks out through the doorway")
	_k(0).teleport_to(_at(97, 30))
	await physics_frames(120)
	assert_false(gate.is_open(), "with the doorway clear and the stone released, the door shuts")
	_k(1).teleport_to(plate.global_position + Vector2(plate.width * 0.5, 0))
	for f in 90:
		await physics_frames(1)
		if gate.is_open():
			break
	assert_true(gate.is_open(), "and opens again when the partner returns")


func test_l19_span_runs_while_held_and_stays_running_once_latched() -> void:
	await _start()
	await _go("l19")
	var span := _node("Span") as MovingPlatform
	var plate := _node("SpanPlate") as PressurePlate
	var latch := _node("SpanLatch") as AttackSwitch
	assert_not_null(span, "Span")
	# The tower's shieldbearer and archer are not part of this check.
	for node in game.level.find_children("*", "", true, false):
		if node is Enemy:
			node.queue_free()
	await physics_frames(30)
	var rest := span.global_position
	assert_lt(span.global_position.distance_to(rest), 0.5, "the span waits while nobody holds its plate")
	_k(1).teleport_to(plate.global_position + Vector2(plate.width * 0.5, 0))
	await physics_frames(60)
	assert_gt(span.global_position.distance_to(rest), 8.0, "it runs while P2 holds the plate")
	_k(1).teleport_to(_at(55, 18))
	await physics_frames(20)
	var parked := span.global_position
	await physics_frames(40)
	assert_lt(span.global_position.distance_to(parked), 0.5, "and stops when the plate is released")
	# P1, on the third tower, strikes the latch with a real swing.
	_k(0).teleport_to(Vector2(latch.global_position.x - 14.0, 20 * T))
	await physics_frames(5)
	await _tap([&"p1_attack"])
	await physics_frames(20)
	assert_eq(latch.activations, 1, "the latch was struck once")
	parked = span.global_position
	await physics_frames(60)
	assert_gt(span.global_position.distance_to(parked), 8.0, "latched: the span runs with nobody on the plate")


func test_l16_summit_gate_needs_both_knights_striking_together() -> void:
	await _start()
	await _go("l16")
	var gate := _node("HeartGate") as PuzzleGate
	var a := _node("HeartA") as AttackSwitch
	var b := _node("HeartB") as AttackSwitch
	assert_not_null(gate, "HeartGate")
	for node in game.level.find_children("*", "", true, false):
		if node is Slime or node is Enemy:
			node.queue_free()
	await physics_frames(3)
	# One knight striking both hearts in a row does not count.
	_k(0).teleport_to(Vector2(a.global_position.x - 14.0, 24 * T))
	await physics_frames(5)
	await _tap([&"p1_attack"])
	await physics_frames(25)
	_k(0).teleport_to(Vector2(b.global_position.x - 14.0, 24 * T))
	await physics_frames(5)
	await _tap([&"p1_attack"])
	await physics_frames(40)
	assert_false(gate.is_open(), "one knight alone cannot open the summit gate")
	await physics_frames(150)  # the window passes
	# Both knights, each on its own heart, in the same frame.
	_k(0).teleport_to(Vector2(a.global_position.x - 14.0, 24 * T))
	_k(1).teleport_to(Vector2(b.global_position.x - 14.0, 24 * T))
	await physics_frames(25)
	await _tap([&"p1_attack", &"p2_attack"])
	for f in 120:
		await physics_frames(1)
		if gate.is_open():
			break
	assert_true(gate.is_open(), "two knights striking together open it")
