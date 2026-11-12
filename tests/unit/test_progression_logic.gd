extends GameTestCase
## Progression rules without scenes: PlayerEffects, PlayerStats, RunState, PoisonStatus.

const F := PlayerStats.FruitType
const J := PlayerStats.JarType
const C := DamageEvent.Category
const TICK := 1.0 / 60.0

var config: ProgressionConfig


func before_each() -> void:
	config = load("res://resources/config/progression_config.tres")


func _stats(id := 1) -> PlayerStats:
	return PlayerStats.new(id, config, 3, 1, 1.0)


func _ticks(effects: PlayerEffects, count: int) -> void:
	for i in count:
		effects.tick(TICK)


# --- Probabilities ---------------------------------------------------------------------

func test_percent_rolls_are_exact() -> void:
	for percent in [10, 50]:
		var hits := 0
		for value in 100:
			if PlayerEffects.is_percent_hit(value, percent):
				hits += 1
		assert_eq(hits, percent, "exactly %d of the 100 roll values succeed" % percent)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var hits10 := 0
	var hits50 := 0
	for i in 20000:
		hits10 += int(PlayerEffects.roll_percent(rng, 10))
		hits50 += int(PlayerEffects.roll_percent(rng, 50))
	assert_near(hits10 / 20000.0, 0.10, 0.01, "10 % over 20 000 seeded rolls")
	assert_near(hits50 / 20000.0, 0.50, 0.015, "50 % over 20 000 seeded rolls")
	assert_eq(config.coin_heal_chance_percent, 10, "coins: 10 %")
	assert_eq(config.validate().size(), 0, "progression config valid: %s" % config.validate())


# --- Timed effects --------------------------------------------------------------------

func test_tile_effects_last_their_time_and_refresh() -> void:
	var fx := PlayerEffects.new(config)
	var ticks := int(round(config.tile_effect_seconds * 60.0))
	fx.add_tile_effect(PlayerEffects.SPEED_BOOST)
	_ticks(fx, ticks - 1)
	assert_true(fx.has(PlayerEffects.SPEED_BOOST), "active until the last tick")
	_ticks(fx, 1)
	assert_false(fx.has(PlayerEffects.SPEED_BOOST), "gone after exactly %d ticks (12 s)" % ticks)
	assert_eq(config.tile_effect_seconds, 12.0, "haste and frenzy last 12 s")
	fx.add_tile_effect(PlayerEffects.ATTACK_SPEED)
	_ticks(fx, 200)
	fx.add_tile_effect(PlayerEffects.ATTACK_SPEED)
	assert_near(fx.remaining(PlayerEffects.ATTACK_SPEED), 12.0, 0.0001, "taking it again refreshes to the full time")
	assert_eq(fx.cooldown_multiplier(), 0.65, "cooldown x0.65, never lower from repeats")
	fx.add_tile_effect(PlayerEffects.SPEED_BOOST)
	fx.add_tile_effect(PlayerEffects.SPEED_BOOST)
	assert_eq(fx.speed_bonus(), 0.3, "speed +30 %, not +60 % from repeats")
	assert_eq(fx.active_ids().size(), 2, "different effects coexist")
	fx.add_tile_effect(PlayerEffects.TILE_SHIELD)
	assert_eq([fx.charges(PlayerEffects.TILE_SHIELD), fx.remaining(PlayerEffects.TILE_SHIELD)], [1, 20.0], "guard: one hit, 20 s")


func test_fruit_shield_tiers_and_policy() -> void:
	for tier in [1, 2, 3]:
		var fx := PlayerEffects.new(config)
		fx.add_fruit_shield(tier)
		assert_eq(fx.charges(PlayerEffects.FRUIT_SHIELD), tier, "tier %d: %d charges" % [tier, tier])
		assert_eq(fx.remaining(PlayerEffects.FRUIT_SHIELD), [20.0, 30.0, 45.0][tier - 1], "tier %d duration" % tier)
		var blocked := 0
		for i in tier + 1:
			blocked += int(fx.resolve_protection(DamageEvent.create(1, C.CONTACT)))
		assert_eq(blocked, tier, "tier %d blocks exactly %d hits" % [tier, tier])
		assert_false(fx.has(PlayerEffects.FRUIT_SHIELD), "tier %d shield gone when charges are used" % tier)
	var fx := PlayerEffects.new(config)
	fx.add_fruit_shield(1)
	_ticks(fx, 1200)
	assert_false(fx.has(PlayerEffects.FRUIT_SHIELD), "tier 1 expires after 20 s unused")
	fx.add_fruit_shield(3)
	fx.resolve_protection(DamageEvent.create(1, C.CONTACT))
	fx.add_fruit_shield(1)
	assert_eq(fx.charges(PlayerEffects.FRUIT_SHIELD), 2, "a weaker shield does not lower charges")
	fx.add_fruit_shield(3)
	fx.add_fruit_shield(3)
	assert_eq(fx.charges(PlayerEffects.FRUIT_SHIELD), 3, "shields never stack beyond the strongest tier")
	assert_eq(fx.remaining(PlayerEffects.FRUIT_SHIELD), 45.0, "duration capped at the strongest tier")


func test_protection_order_and_bypass() -> void:
	var fx := PlayerEffects.new(config)
	fx.add_tile_effect(PlayerEffects.TILE_SHIELD)
	fx.add_fruit_shield(2)
	fx.add_ward()
	var layers := []
	fx.protected.connect(func(layer: StringName, _e: DamageEvent) -> void: layers.append(layer))
	assert_true(fx.resolve_protection(DamageEvent.create(1, C.SPIKE)), "first hit blocked")
	assert_eq(layers, [PlayerEffects.TILE_SHIELD], "power-tile shield first, and only one layer used")
	assert_eq(fx.charges(PlayerEffects.FRUIT_SHIELD), 2, "fruit charges untouched by that hit")
	fx.resolve_protection(DamageEvent.create(1, C.CONTACT))
	assert_eq(layers[1], PlayerEffects.FRUIT_SHIELD, "then the fruit shield")
	for kind: C in [C.FALL, C.LAVA]:
		assert_false(fx.resolve_protection(DamageEvent.create(1, kind)), "%s bypasses every protection" % C.keys()[kind])
	assert_eq(fx.charges(PlayerEffects.FRUIT_SHIELD), 1, "bypassing events consume nothing")
	assert_true(fx.ward_is_ready(), "the ward is kept until the timed shields are spent")
	fx.resolve_protection(DamageEvent.create(1, C.CONTACT))
	assert_true(fx.resolve_protection(DamageEvent.create(1, C.CONTACT)), "with no shield left the ward blocks")
	assert_eq(layers[-1], PlayerEffects.WARD, "the ward is the last layer")


func test_ward_blocks_recharges_and_levels_up() -> void:
	var fx := PlayerEffects.new(config)
	assert_false(fx.has(PlayerEffects.WARD), "no ward without a yellow jar")
	fx.add_ward()
	assert_true(fx.ward_is_ready(), "a new ward is ready at once")
	assert_true(fx.resolve_protection(DamageEvent.create(1, C.CONTACT)), "it blocks a hit")
	assert_false(fx.ward_is_ready(), "then it is spent")
	assert_false(fx.resolve_protection(DamageEvent.create(1, C.CONTACT)), "the next hit lands")
	assert_eq(fx.remaining(PlayerEffects.WARD), 25.0, "recharge 25 s")
	_ticks(fx, 25 * 60 - 1)
	assert_false(fx.ward_is_ready(), "not ready one tick early")
	_ticks(fx, 1)
	assert_true(fx.ward_is_ready(), "ready again after the recharge")
	assert_true(fx.has(PlayerEffects.WARD), "the ward is permanent: it never expires")
	fx.clear()
	assert_true(fx.has(PlayerEffects.WARD), "clearing timed effects keeps the ward")
	fx.add_ward()
	assert_eq(fx.ward_recharge_seconds(), 20.0, "a second jar: recharge 20 s")
	fx.add_ward()
	fx.add_ward()
	assert_eq(fx.ward_recharge_seconds(), 15.0, "never below the minimum 15 s")
	for kind: C in [C.FALL, C.LAVA]:
		assert_false(fx.resolve_protection(DamageEvent.create(1, kind)), "%s passes the ward" % C.keys()[kind])
	assert_true(fx.ward_is_ready(), "and does not spend it")


func test_venom_is_timed_and_refreshes() -> void:
	for tier in [1, 2, 3]:
		var fx := PlayerEffects.new(config)
		fx.add_venom(tier)
		assert_eq(fx.remaining(PlayerEffects.VENOM), [30.0, 45.0, 60.0][tier - 1], "tier %d venom time" % tier)
		assert_eq(fx.poison_seconds(), 3.0, "every hit poisons for 3 s while venom lasts")
	var fx := PlayerEffects.new(config)
	fx.add_venom(3)
	_ticks(fx, 600)
	fx.add_venom(1)
	assert_near(fx.remaining(PlayerEffects.VENOM), 50.0, 0.001, "a weaker fruit never shortens venom")
	_ticks(fx, 50 * 60)
	assert_false(fx.has(PlayerEffects.VENOM), "venom ends")
	assert_eq(fx.poison_seconds(), 0.0, "and hits stop poisoning")


func test_effects_snapshot_round_trip() -> void:
	var fx := PlayerEffects.new(config)
	fx.add_fruit_shield(2)
	fx.add_tile_effect(PlayerEffects.SPEED_BOOST)
	_ticks(fx, 60)
	var copy := PlayerEffects.new(config)
	assert_true(copy.restore(fx.snapshot()), "restores")
	assert_near(copy.remaining(PlayerEffects.FRUIT_SHIELD), 29.0, 0.001, "remaining shield time")
	assert_eq(copy.charges(PlayerEffects.FRUIT_SHIELD), 2, "charges")
	assert_near(copy.remaining(PlayerEffects.SPEED_BOOST), 11.0, 0.001, "remaining boost time")
	assert_false(copy.restore({"bogus_effect": {"remaining": 1.0, "charges": 0}}), "unknown effect rejected")
	assert_false(copy.restore({"venom": {"remaining": -5.0, "charges": 0}}), "negative time rejected")
	assert_eq(copy.charges(PlayerEffects.FRUIT_SHIELD), 2, "a rejected restore changes nothing")
	# The ward (permanent) travels with the effects: level and recharge left.
	fx.add_ward()
	fx.add_ward()
	fx.resolve_protection(DamageEvent.create(1, C.CONTACT))
	fx.resolve_protection(DamageEvent.create(1, C.CONTACT))
	fx.resolve_protection(DamageEvent.create(1, C.CONTACT))
	var warded := PlayerEffects.new(config)
	assert_true(warded.restore(JSON.parse_string(JSON.stringify(fx.snapshot()))), "ward restores from JSON")
	assert_eq(warded.ward_level, 2, "ward level kept")
	assert_near(warded.remaining(PlayerEffects.WARD), 20.0, 0.001, "recharge left kept")
	# A save from before the redesign: the yellow jar's 60 s of luck becomes a ward.
	var legacy := PlayerEffects.new(config)
	assert_true(legacy.restore({"jar_luck": {"remaining": 31.5, "charges": 0}}), "old yellow-jar saves load")
	assert_true(legacy.ward_is_ready(), "as a ready ward")


# --- Player stats ---------------------------------------------------------------------

func test_fruit_effects() -> void:
	for tier in [1, 2, 3]:
		var s := _stats()
		s.current_health = 0 + 1  # wounded
		s.collect_fruit(F.GREEN, tier)
		assert_eq(s.current_health, mini(1 + tier, 3), "green tier %d heals %d (capped at max)" % [tier, tier])
		var r := _stats()
		r.collect_fruit(F.RED, tier)
		assert_near(r.range_multiplier(), [1.1, 1.15, 1.2][tier - 1], 0.000001, "red tier %d range" % tier)
		assert_eq(r.combat.range_multiplier, r.range_multiplier(), "combat cache updated")
		assert_eq(r.attack_power(), 1, "red fruit does not change power")
		var p := _stats()
		p.collect_fruit(F.PURPLE, tier)
		assert_true(p.effects.has(PlayerEffects.VENOM), "purple tier %d gives venom" % tier)
		assert_eq(p.combat.poison_seconds, 3.0, "the combat cache poisons while venom lasts")
	var stacked := _stats()
	stacked.collect_fruit(F.RED, 1)
	stacked.collect_fruit(F.RED, 3)
	assert_near(stacked.range_multiplier(), 1.3, 0.000001, "distinct red fruits add up relative to the base")
	stacked.collect_fruit(F.RED, 3)
	assert_near(stacked.range_multiplier(), 1.4, 0.000001, "reach is capped at +40 %")
	assert_false(stacked.can_use_fruit(F.RED), "at the cap a red fruit is left for the partner")
	var full := _stats()
	assert_false(full.can_use_fruit(F.GREEN), "a green fruit is not wasted at full health")
	full.current_health = 2
	assert_true(full.can_use_fruit(F.GREEN), "it is taken when hurt")
	var dead := _stats()
	dead.current_health = 0
	dead.collect_fruit(F.GREEN, 3)
	assert_eq(dead.current_health, 0, "green fruit never revives")


func test_jar_effects_and_stat_calculation() -> void:
	var s := _stats()
	s.current_health = 2
	s.collect_jar(J.GREEN)
	assert_eq([s.current_health, s.max_health()], [3, 4], "green jar: 2/3 -> 3/4")
	s.collect_jar(J.RED)
	assert_eq(s.attack_power(), 2, "red jar: power 2")
	assert_eq(s.combat.attack_power, 2, "combat cache power 2")
	s.collect_jar(J.BLUE)
	assert_near(s.speed_multiplier(), 1.08, 0.000001, "blue jar: +8 %")
	s.collect_jar(J.BLUE)
	assert_near(s.speed_multiplier(), 1.16, 0.000001, "two blue jars: +16 % of base")
	s.effects.add_tile_effect(PlayerEffects.SPEED_BOOST)
	assert_near(s.speed_multiplier(), 1.46, 0.000001, "permanent +16 % plus haste +30 %")
	s.effects.add_tile_effect(PlayerEffects.ATTACK_SPEED)
	assert_eq(s.combat.cooldown_multiplier, 0.65, "frenzy reaches the combat cache")
	s.collect_jar(J.YELLOW)
	assert_true(s.effects.ward_is_ready(), "yellow jar: a permanent ward")
	s.collect_jar(J.RED)
	assert_eq(s.attack_power(), 3, "a second red jar: power 3")
	assert_false(s.can_use_jar(J.RED), "power is capped at +2: the next jar is left for the partner")
	s.collect_jar(J.BLUE)
	assert_false(s.can_use_jar(J.BLUE), "speed is capped at +24 %")
	var other := _stats(2)
	assert_eq([other.max_health(), other.attack_power(), other.speed_multiplier()], [3, 1, 1.0], "the other player's record is separate")


func test_player_stats_snapshot_round_trip() -> void:
	var s := _stats()
	s.collect_jar(J.GREEN)
	s.collect_jar(J.RED)
	s.collect_fruit(F.RED, 2)
	s.collect_fruit(F.PURPLE, 2)
	s.collect_jar(J.BLUE)
	s.effects.add_fruit_shield(1)
	var copy := _stats()
	assert_true(copy.restore(JSON.parse_string(JSON.stringify(s.snapshot()))), "restores from JSON text")
	assert_eq([copy.max_health(), copy.current_health, copy.attack_power()], [4, 4, 2], "health and power")
	assert_near(copy.range_multiplier(), 1.15, 0.000001, "range")
	assert_near(copy.speed_multiplier(), 1.08, 0.000001, "speed")
	assert_near(copy.effects.remaining(PlayerEffects.VENOM), 45.0, 0.001, "venom time")
	assert_eq(copy.effects.charges(PlayerEffects.FRUIT_SHIELD), 1, "shield")
	var bad := s.snapshot()
	bad.current_health = 99
	assert_false(copy.restore(bad), "health above maximum rejected")
	bad = s.snapshot()
	bad.player_id = 2
	assert_false(copy.restore(bad), "wrong player rejected")


# --- Run state --------------------------------------------------------------------------

func test_coin_collection_and_healing_without_knights() -> void:
	var run := RunState.reset()
	run.config = run.config.duplicate()
	run.config.coin_heal_chance_percent = 0
	run.player(1).current_health = 1
	assert_false(run.collect_coin(1), "0 %: no heal")
	assert_eq(run.coins, 1, "one coin")
	run.config.coin_heal_chance_percent = 100
	run.player(2).current_health = 0  # dead
	var rolls := [0]
	run.coin_collected.connect(func(_id: int, _h: bool) -> void: rolls[0] += 1)
	assert_true(run.collect_coin(2), "100 %: heal")
	assert_eq(run.coins, 2, "shared total")
	assert_eq(rolls[0], 1, "one roll per coin")
	assert_eq(run.player(1).current_health, 2, "living player healed by 1")
	assert_eq(run.player(2).current_health, 0, "dead player not revived")
	run.collect_coin(1)
	run.collect_coin(1)
	assert_eq(run.player(1).current_health, 3, "never above maximum")


func test_collected_ids_and_run_snapshot() -> void:
	var run := RunState.reset()
	assert_true(run.mark_collected("jar_a", 1, "jar_red"), "first collection recorded")
	assert_false(run.mark_collected("jar_a", 2, "jar_red"), "duplicate id refused")
	run.collect_coin(1)
	run.player(2).collect_jar(J.GREEN)
	var data: Dictionary = JSON.parse_string(JSON.stringify(run.snapshot()))
	var fresh := RunState.reset()
	assert_true(fresh.restore(data), "snapshot restores")
	assert_eq(fresh.coins, 1, "coins")
	assert_true(fresh.is_collected("jar_a"), "collected ids")
	assert_eq(fresh.player(2).max_health(), 4, "player 2 upgrade")
	assert_eq(fresh.player(1).max_health(), 3, "player 1 unchanged")
	var newer: Dictionary = data.duplicate(true)
	newer.version = RunState.VERSION + 1
	assert_false(fresh.restore(newer), "newer version rejected")
	var broken: Dictionary = data.duplicate(true)
	broken.players.erase("2")
	assert_false(fresh.restore(broken), "missing player rejected")
	assert_false(fresh.restore("not a dictionary"), "garbage rejected")
	assert_eq(fresh.coins, 1, "failed restores leave the state unchanged")


# --- Poison -----------------------------------------------------------------------------

func _poison_points(seconds: float, frames: int) -> int:
	var p := PoisonStatus.new()
	p.apply(seconds)
	var total := 0
	for i in frames:
		total += p.tick(TICK)
	return total


func test_poison_points_per_tier() -> void:
	for tier in [1, 2, 3]:
		assert_eq(_poison_points(float(tier), 400), tier, "tier %d: %d points" % [tier, tier])
	assert_eq(_poison_points(2.0, 59), 0, "no point before the first full second")
	var p := PoisonStatus.new()
	p.apply(2.0)
	var points := 0
	for i in 30:
		points += p.tick(TICK)
	p.apply(1.0)  # weaker re-application during an active poison
	assert_near(p.remaining, 1.5, 0.001, "re-applying keeps the longer remaining time")
	p.apply(2.0)
	assert_near(p.remaining, 2.0, 0.001, "re-applying refreshes, never stacks")
	for i in 300:
		points += p.tick(TICK)
	assert_eq(points, 2, "one timer: 2.5 s of poison gives 2 points, no duplicate ticks")
	assert_false(p.is_active(), "expired")
