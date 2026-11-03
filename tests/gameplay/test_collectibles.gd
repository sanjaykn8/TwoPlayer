extends GameTestCase
## Collectibles in the real collectible room (floor y=448). The room's items and slimes are
## removed; each test places what it needs. Power tiles stay at x 560, 600, 640 (top y=432).
## Open floor x 680-900 is used for most tests. The runner gives every test a fresh RunState.

const ROOM := "res://scenes/dev/collectible_test_room.tscn"
const FRUIT := "res://scenes/collectibles/fruit.tscn"
const JAR := "res://scenes/collectibles/jar.tscn"
const COIN := "res://scenes/objects/dropped_coin.tscn"
const GREEN := "res://scenes/enemies/green_slime.tscn"
const PURPLE := "res://scenes/enemies/purple_slime.tscn"
const DUMMY := "res://scenes/objects/training_dummy.tscn"
const FLOOR := 448.0
const ALL_ACTIONS := [&"p1_move_left", &"p1_move_right", &"p1_move_up", &"p1_move_down", &"p1_attack",
	&"p2_move_left", &"p2_move_right", &"p2_move_up", &"p2_move_down", &"p2_attack"]
const F := PlayerStats.FruitType
const J := PlayerStats.JarType

var room: Node
var level: Node2D
var rig: SplitScreenRig
var k1: Knight
var k2: Knight
var run: RunState
var _next_attack := 70000


func before_each() -> void:
	TrainingDummy.console_log = false
	_release_all()
	run = RunState.current()
	room = (load(ROOM) as PackedScene).instantiate()
	add_child(room)
	level = room.get("level")
	rig = room.get("rig")
	k1 = room.get("knight_1")
	k2 = room.get("knight_2")
	for group in ["Items", "Enemies"]:
		for node in level.get_node(group).get_children():
			node.queue_free()
	k1.teleport_to(Vector2(700, FLOOR))
	k2.teleport_to(Vector2(860, FLOOR))
	rig.snap_to_targets()
	await physics_frames(5)


func after_each() -> void:
	_release_all()
	get_tree().paused = false
	room.queue_free()
	await physics_frames(2)


func _release_all() -> void:
	for a in ALL_ACTIONS:
		Input.action_release(a)


func _tap(actions: Array) -> void:
	for a in actions:
		Input.action_press(a)
	await physics_frames(1)
	for a in actions:
		Input.action_release(a)


func _spawn(path: String, at: Vector2, props := {}) -> Node2D:
	var node: Node2D = (load(path) as PackedScene).instantiate()
	node.position = at
	for key: String in props:
		node.set(key, props[key])
	level.add_child(node)
	return node


func _melee(slime: Slime, power := 1, poison := 0.0) -> void:
	_next_attack += 1
	var event := DamageEvent.create(power, DamageEvent.Category.MELEE, k1)
	event.attack_id = _next_attack
	event.poison_seconds = poison
	slime.hurtbox.receive_hit(event)


func _heal_chance(percent: int) -> void:
	run.config = run.config.duplicate()
	run.config.coin_heal_chance_percent = percent


# --- Coins ------------------------------------------------------------------------------

func test_slime_drop_coins_are_collected_into_the_shared_total() -> void:
	_heal_chance(0)
	var slime := _spawn(GREEN, Vector2(780, FLOOR), {"patrol_left": 0.0, "patrol_right": 0.0, "free_on_death": false}) as Slime
	slime.get_node("CoinDropper").rng_seed = 777
	await physics_frames(2)
	for i in 3:
		_melee(slime)
	var count := slime.drop_result.count
	assert_true(count >= 4 and count <= 6, "4-6 coins dropped (got %d)" % count)
	await physics_frames(3)
	var coins := get_tree().get_nodes_in_group(DroppedCoin.GROUP)
	assert_eq(coins.size(), count, "that many individual coin objects")
	var rolls := [0]
	run.coin_collected.connect(func(_id: int, _h: bool) -> void: rolls[0] += 1)
	await physics_frames(60)  # let them settle and become collectable
	k1.teleport_to(Vector2(740, FLOOR))
	Input.action_press(&"p1_move_right")
	await physics_frames(60)
	Input.action_release(&"p1_move_right")
	await physics_frames(15)
	assert_eq(run.coins, count, "every coin added exactly one to the shared total")
	assert_eq(rolls[0], count, "one healing roll per coin")
	assert_eq(get_tree().get_nodes_in_group(DroppedCoin.GROUP).size(), 0, "collected coins removed")


func test_either_knight_collects_into_one_total() -> void:
	_heal_chance(0)
	var a := _spawn(COIN, Vector2(700, FLOOR))
	var b := _spawn(COIN, Vector2(860, FLOOR))
	await physics_frames(40)
	assert_eq(run.coins, 2, "P1's and P2's coins share one total")
	assert_false(is_instance_valid(a) and not a.is_queued_for_deletion(), "coin A taken")
	assert_false(is_instance_valid(b) and not b.is_queued_for_deletion(), "coin B taken")


func test_two_knights_on_one_coin_collect_it_once() -> void:
	_heal_chance(0)
	k2.teleport_to(Vector2(702, FLOOR))
	await physics_frames(5)
	var events := [0]
	run.coin_collected.connect(func(_id: int, _h: bool) -> void: events[0] += 1)
	_spawn(COIN, Vector2(701, FLOOR))
	await physics_frames(40)
	assert_eq(run.coins, 1, "one coin, one increment")
	assert_eq(events[0], 1, "one collection event")


func test_coin_heal_roll_heals_both_living_knights() -> void:
	_heal_chance(100)
	k1.health.take_damage(DamageEvent.create(2, DamageEvent.Category.FALL))
	k2.health.take_damage(DamageEvent.create(1, DamageEvent.Category.FALL))
	_spawn(COIN, Vector2(700, FLOOR))
	await physics_frames(40)
	assert_eq(k1.health.current_health, 2, "collector healed 1")
	assert_eq(k2.health.current_health, 3, "partner healed 1 (to max)")
	_spawn(COIN, Vector2(700, FLOOR))
	await physics_frames(40)
	assert_eq(k2.health.current_health, 3, "never above maximum")
	k2.health.take_damage(DamageEvent.create(1, DamageEvent.Category.LAVA))
	_spawn(COIN, Vector2(700, FLOOR))
	await physics_frames(40)
	assert_eq(k2.health.current_health, 0, "a dead knight is not revived by coins")
	assert_eq(k1.health.current_health, 3, "the living knight still heals")


# --- Fruit ------------------------------------------------------------------------------

func test_green_fruit_tiers_heal_only_the_collector() -> void:
	for tier in [1, 2, 3]:
		k1.health.revive()
		k2.health.revive()
		k1.health.take_damage(DamageEvent.create(2, DamageEvent.Category.FALL))
		k2.health.take_damage(DamageEvent.create(2, DamageEvent.Category.FALL))
		_spawn(FRUIT, Vector2(700, FLOOR), {"fruit_type": F.GREEN, "tier": tier})
		await physics_frames(5)
		assert_eq(k1.health.current_health, mini(1 + tier, 3), "tier %d heals %d (capped)" % [tier, tier])
		assert_eq(k2.health.current_health, 1, "the other knight is not healed (tier %d)" % tier)


func test_yellow_fruit_shield_blocks_slime_contact() -> void:
	_spawn(FRUIT, Vector2(700, FLOOR), {"fruit_type": F.YELLOW, "tier": 2})
	await physics_frames(5)
	assert_eq(run.player(1).effects.charges(PlayerEffects.FRUIT_SHIELD), 2, "2 charges")
	k1.set_physics_process(false)
	_spawn(GREEN, Vector2(700, FLOOR), {"patrol_left": 0.0, "patrol_right": 0.0})
	await physics_frames(10)
	assert_eq(k1.health.current_health, 3, "first contact blocked")
	assert_eq(run.player(1).effects.charges(PlayerEffects.FRUIT_SHIELD), 1, "one charge used")
	await physics_frames(40)
	assert_eq(run.player(1).effects.charges(PlayerEffects.FRUIT_SHIELD), 1, "the block's invulnerability stops continuous contact draining charges")
	await physics_frames(40)
	assert_eq(k1.health.current_health, 3, "second contact blocked")
	assert_false(run.player(1).effects.has(PlayerEffects.FRUIT_SHIELD), "shield used up")
	await physics_frames(70)
	assert_eq(k1.health.current_health, 2, "then contact damage applies normally")
	assert_eq(k2.health.current_health, 3, "P2 unaffected")


func test_shields_do_not_stop_falling_or_lava() -> void:
	run.player(1).collect_fruit(F.YELLOW, 3)
	run.player(1).collect_jar(J.YELLOW)
	run.player(1).effects.add_tile_effect(PlayerEffects.TILE_SHIELD)
	k1.health.take_damage(DamageEvent.create(1, DamageEvent.Category.FALL))
	assert_eq(k1.health.current_health, 2, "falling is never blocked")
	assert_eq(run.player(1).effects.charges(PlayerEffects.TILE_SHIELD), 1, "no charge spent on a fall")
	k1.health.take_damage(DamageEvent.create(1, DamageEvent.Category.LAVA))
	assert_true(k1.is_dead() or not k1.health.is_alive(), "lava kills through every protection")


func test_red_fruit_range_reaches_further_targets() -> void:
	var far := _spawn(DUMMY, Vector2(724, FLOOR)) as TrainingDummy  # hurtbox 719-729: beyond base reach (718)
	k1.facing = 1
	await _tap([&"p1_attack"])
	await physics_frames(25)
	assert_eq(far.hits_taken(), 0, "out of base range")
	_spawn(FRUIT, Vector2(700, FLOOR), {"fruit_type": F.RED, "tier": 3})
	await physics_frames(5)
	assert_near(k1.combat.stats.range_multiplier, 1.3, 0.000001, "x1.3 range on P1's attacks")
	assert_eq(k2.combat.stats.range_multiplier, 1.0, "P2 unchanged")
	await _tap([&"p1_attack"])
	await physics_frames(25)
	assert_eq(far.hits_taken(), 1, "the same target is now in range")
	assert_eq(k1.combat.stats.attack_power, 1, "power unchanged")


func test_purple_fruit_poison_staggers_but_never_kills() -> void:
	run.player(1).collect_fruit(F.PURPLE, 3)
	var green := _spawn(GREEN, Vector2(790, FLOOR), {"patrol_left": 0.0, "patrol_right": 0.0}) as Slime
	await physics_frames(2)
	_melee(green, 1, run.player(1).poison_seconds)
	assert_eq(green.stagger.progress, 1, "the hit adds 1 point")
	assert_true(green.poison.is_active(), "poisoned")
	await physics_frames(61)
	assert_true(green.is_staggered(), "one poison point reaches the green threshold: staggered")
	assert_false(green.poison.is_active(), "poison stops when staggered")
	assert_eq(green.add_stagger_progress(5), SlimeStagger.Outcome.IGNORED, "poison can never execute")
	assert_false(green.is_dead(), "alive")
	_melee(green)
	assert_true(green.is_dead(), "a direct melee hit still kills")


func test_poison_points_and_reapplication_on_purple() -> void:
	var purple := _spawn(PURPLE, Vector2(790, FLOOR), {"patrol_left": 0.0, "patrol_right": 0.0}) as Slime
	await physics_frames(2)
	_melee(purple, 1, 2.0)
	await physics_frames(30)
	_melee(purple, 1, 2.0)  # re-applied 0.5 s in: refreshes to 2 s, no second timer
	assert_eq(purple.stagger.progress, 2, "two hits")
	await physics_frames(200)
	assert_eq(purple.stagger.progress, 4, "2.5 s of poison added exactly 2 points (no duplicate ticks)")
	assert_true(purple.is_staggered(), "4 points: staggered by poison")
	assert_false(purple.is_dead(), "poison did not kill")


# --- Jars --------------------------------------------------------------------------------

func test_green_jar_and_unique_ids() -> void:
	k1.health.take_damage(DamageEvent.create(1, DamageEvent.Category.FALL))
	_spawn(JAR, Vector2(700, FLOOR), {"jar_type": J.GREEN, "collectible_id": "test_jar_green"})
	await physics_frames(5)
	assert_eq([k1.health.current_health, k1.health.max_health], [3, 4], "2/3 -> 3/4")
	assert_eq(k2.health.max_health, 3, "P2 unchanged")
	assert_true(run.is_collected("test_jar_green"), "id recorded")
	var again := _spawn(JAR, Vector2(700, FLOOR), {"jar_type": J.GREEN, "collectible_id": "test_jar_green"})
	await physics_frames(5)
	assert_false(is_instance_valid(again) and not again.is_queued_for_deletion(), "an already-collected jar removes itself")
	assert_eq(k1.health.max_health, 4, "no second upgrade")


func test_red_jar_power_staggers_green_in_one_real_hit() -> void:
	_spawn(JAR, Vector2(700, FLOOR), {"jar_type": J.RED, "collectible_id": "test_jar_red"})
	await physics_frames(5)
	assert_eq(k1.combat.stats.attack_power, 2, "power 2")
	var green := _spawn(GREEN, Vector2(712, FLOOR), {"patrol_left": 0.0, "patrol_right": 0.0}) as Slime
	run.player(1).effects.add_jar_luck()  # irrelevant; makes sure effects do not disturb power
	k1.health.start_invulnerability(30.0)
	await physics_frames(5)
	k1.facing = 1
	await _tap([&"p1_attack"])
	await physics_frames(15)
	assert_true(green.is_staggered(), "one power-2 swing staggers a green slime")
	var purple := _spawn(PURPLE, Vector2(712, FLOOR), {"patrol_left": 0.0, "patrol_right": 0.0}) as Slime
	await physics_frames(25)
	k1.facing = 1
	await _tap([&"p1_attack"])
	await physics_frames(25)
	assert_eq(purple.stagger.progress, 2, "power 2 adds 2 points to purple")


func test_yellow_jar_rolls_on_contact() -> void:
	var stats := run.player(1)
	stats.effects.rng.seed = 12345
	_spawn(JAR, Vector2(700, FLOOR), {"jar_type": J.YELLOW, "collectible_id": "test_jar_yellow"})
	await physics_frames(5)
	assert_near(stats.effects.remaining(PlayerEffects.JAR_LUCK), 60.0, 0.1, "60 s")
	var outcomes := []
	stats.effects.protected.connect(func(layer: StringName, _e: DamageEvent) -> void: outcomes.append(layer))
	var applied := 0
	for i in 40:
		k1.health.clear_invulnerability()
		applied += k1.health.take_damage(DamageEvent.create(0 + 1, DamageEvent.Category.CONTACT))
		k1.health.revive()
	assert_eq(outcomes.size() + applied, 40, "every event was either negated or applied")
	assert_gt(outcomes.size(), 10.0, "some negated (%d of 40)" % outcomes.size())
	assert_gt(applied, 10.0, "failed rolls fall through to normal damage (%d of 40)" % applied)
	assert_false(stats.effects.has(PlayerEffects.FRUIT_SHIELD), "no shield charges involved")


func test_blue_jar_speed_only_for_collector() -> void:
	_spawn(JAR, Vector2(700, FLOOR), {"jar_type": J.BLUE, "collectible_id": "test_jar_blue"})
	await physics_frames(5)
	k1.teleport_to(Vector2(680, FLOOR))
	k2.teleport_to(Vector2(680, FLOOR - 0) + Vector2(0, 0))
	k2.teleport_to(Vector2(780, FLOOR))
	await physics_frames(5)
	Input.action_press(&"p1_move_right")
	Input.action_press(&"p2_move_right")
	await physics_frames(40)
	assert_near(absf(k1.velocity.x), 110.0 * 1.05, 0.0001, "P1 runs at 115.5 px/s")
	assert_near(absf(k2.velocity.x), 110.0, 0.0001, "P2 runs at 110 px/s")
	_release_all()
	await physics_frames(20)
	assert_eq(k1.state, Knight.State.GROUNDED, "stable on the ground after running")


# --- Power tiles -------------------------------------------------------------------------

func _tile(index: int) -> PowerTile:
	return level.get_node("PowerTiles/PowerTile%d" % index) as PowerTile


func test_power_tile_fires_once_per_visit() -> void:
	var tile := _tile(2)
	tile.forced_effect = PlayerEffects.SPEED_BOOST
	k1.teleport_to(Vector2(600, 420))
	await physics_frames(30)
	assert_eq(tile.activations, 1, "stepping on it fires once")
	assert_true(run.player(1).effects.has(PlayerEffects.SPEED_BOOST), "P1 got the effect")
	assert_false(run.player(2).effects.has(PlayerEffects.SPEED_BOOST), "P2 did not")
	await physics_frames(120)
	assert_eq(tile.activations, 1, "standing on it does not repeat")
	k1.teleport_to(Vector2(700, FLOOR))
	await physics_frames(10)
	k1.teleport_to(Vector2(600, 420))
	await physics_frames(30)
	assert_eq(tile.activations, 2, "leaving and returning fires again")


func test_both_knights_activate_independently() -> void:
	var tile := _tile(1)
	tile.rng_seed = 0
	tile.rng.seed = 2024
	var got := {}
	tile.activated.connect(func(k: Knight, effect: StringName) -> void: got[k.player_id()] = effect)
	k1.teleport_to(Vector2(556, 420))
	k2.teleport_to(Vector2(564, 420))
	await physics_frames(30)
	assert_eq(tile.activations, 2, "one activation per knight")
	assert_true(got.has(1) and got.has(2), "each knight got an effect")
	assert_true(run.player(1).effects.has(got[1]), "P1's effect on P1")
	assert_true(run.player(2).effects.has(got[2]), "P2's effect on P2")


func test_tile_effects_values_and_duration() -> void:
	var stats := run.player(1)
	stats.effects.add_tile_effect(PlayerEffects.ATTACK_SPEED)
	assert_near(k1.combat.effective_cooldown(), 0.225, 0.000001, "cooldown exactly 25 % shorter")
	stats.effects.add_tile_effect(PlayerEffects.SPEED_BOOST)
	assert_near(k1.progress.speed_multiplier(), 1.25, 0.000001, "speed exactly +25 %")
	Input.action_press(&"p1_move_right")
	await physics_frames(40)
	assert_near(absf(k1.velocity.x), 137.5, 0.0001, "runs at 137.5 px/s")
	_release_all()
	await physics_frames(260)  # 300 ticks of the effects in total
	assert_false(stats.effects.has(PlayerEffects.SPEED_BOOST), "speed boost lasted 5 s")
	assert_false(stats.effects.has(PlayerEffects.ATTACK_SPEED), "attack boost lasted 5 s")
	assert_near(k1.combat.effective_cooldown(), 0.30, 0.000001, "cooldown back to normal")
	stats.effects.add_tile_effect(PlayerEffects.TILE_SHIELD)
	assert_eq(k1.health.take_damage(DamageEvent.create(1, DamageEvent.Category.SPIKE)), 0, "tile shield blocks one hit")
	assert_false(stats.effects.has(PlayerEffects.TILE_SHIELD), "and is gone")


func test_pause_stops_effect_timers() -> void:
	var stats := run.player(2)
	stats.effects.add_tile_effect(PlayerEffects.SPEED_BOOST)
	await physics_frames(60)
	var left := stats.effects.remaining(PlayerEffects.SPEED_BOOST)
	get_tree().paused = true
	await physics_frames(120)
	assert_eq(stats.effects.remaining(PlayerEffects.SPEED_BOOST), left, "no countdown while paused")
	get_tree().paused = false
	await physics_frames(60)
	assert_near(stats.effects.remaining(PlayerEffects.SPEED_BOOST), left - 1.0, 0.02, "resumes after unpausing")


# --- Persistence ------------------------------------------------------------------------

func test_progress_survives_scene_change() -> void:
	_heal_chance(0)
	var s1 := run.player(1)
	s1.collect_jar(J.GREEN)
	s1.collect_jar(J.RED)
	s1.collect_fruit(F.RED, 2)
	s1.collect_jar(J.BLUE)
	run.player(2).collect_fruit(F.PURPLE, 1)
	run.collect_coin(1)
	run.mark_collected("level_jar", 1, "jar_green")
	s1.effects.add_tile_effect(PlayerEffects.SPEED_BOOST)
	await physics_frames(60)
	k1.health.take_damage(DamageEvent.create(1, DamageEvent.Category.FALL))
	room.queue_free()
	await physics_frames(2)  # the level (and its knights) is now gone
	var left := s1.effects.remaining(PlayerEffects.SPEED_BOOST)
	await physics_frames(30)  # no level: effects do not count down
	assert_eq(s1.effects.remaining(PlayerEffects.SPEED_BOOST), left, "timers frozen between levels")
	assert_eq(s1.current_health, 3, "record kept the health (4 max - 1)")
	var next: Node = (load("res://scenes/dev/enemy_test_room.tscn") as PackedScene).instantiate()
	add_child(next)
	room = next
	await physics_frames(5)
	left = s1.effects.remaining(PlayerEffects.SPEED_BOOST)
	var nk1: Knight = next.get("knight_1")
	var nk2: Knight = next.get("knight_2")
	assert_eq([nk1.health.current_health, nk1.health.max_health], [3, 4], "health carried into the new level")
	assert_eq(nk1.combat.stats.attack_power, 2, "power carried")
	assert_near(nk1.combat.stats.range_multiplier, 1.2, 0.000001, "range carried")
	assert_near(nk1.progress.speed_multiplier(), 1.30, 0.000001, "blue jar + active speed boost carried")
	assert_eq(nk2.combat.stats.poison_seconds, 1.0, "P2 poison carried")
	assert_eq(nk2.combat.stats.attack_power, 1, "P2 power unchanged")
	assert_eq(run.coins, 1, "coins carried")
	assert_true(run.is_collected("level_jar"), "collected ids carried")
	await physics_frames(60)
	assert_near(s1.effects.remaining(PlayerEffects.SPEED_BOOST), left - 1.0, 0.02, "timer continues in the new level")


func test_snapshot_restore_updates_live_knights() -> void:
	run.player(1).collect_jar(J.GREEN)
	run.collect_coin(2)
	var data := run.snapshot()
	run.player(1).collect_jar(J.RED)
	k1.health.take_damage(DamageEvent.create(2, DamageEvent.Category.FALL))
	assert_true(run.restore(data), "restore accepted")
	await physics_frames(2)
	assert_eq([k1.health.current_health, k1.health.max_health], [4, 4], "live knight health restored")
	assert_eq(k1.combat.stats.attack_power, 1, "power restored to the snapshot value")
	assert_eq(run.coins, 1, "coins restored")


func test_two_knights_collect_different_items_at_once() -> void:
	_spawn(JAR, Vector2(700, FLOOR), {"jar_type": J.RED, "collectible_id": "simul_red"})
	_spawn(FRUIT, Vector2(860, FLOOR), {"fruit_type": F.RED, "tier": 1})
	await physics_frames(5)
	assert_eq(k1.combat.stats.attack_power, 2, "P1 got the jar")
	assert_eq(k1.combat.stats.range_multiplier, 1.0, "not the fruit")
	assert_near(k2.combat.stats.range_multiplier, 1.1, 0.000001, "P2 got the fruit")
	assert_eq(k2.combat.stats.attack_power, 1, "not the jar")


func test_speed_upgrade_during_camera_split() -> void:
	run.player(1).collect_jar(J.BLUE)
	run.player(1).effects.add_tile_effect(PlayerEffects.SPEED_BOOST)
	# Open floor: P1 runs left from x 420 toward the wall, P2 right toward the pens.
	k1.teleport_to(Vector2(420, FLOOR))
	k2.teleport_to(Vector2(700, FLOOR))
	rig.snap_to_targets()
	await physics_frames(5)
	Input.action_press(&"p1_move_left")
	Input.action_press(&"p2_move_right")
	var visible_ok := true
	for i in 120:
		await physics_frames(1)
		var view := rig.view_world_rect(SplitScreenRig.VIEW_A)
		if not view.has_point(k1.global_position + Vector2(0, -9)):
			visible_ok = false
	_release_all()
	assert_true(rig.is_split(), "the knights separated into split-screen")
	assert_true(visible_ok, "the faster knight stayed in its view throughout")
