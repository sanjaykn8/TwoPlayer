extends GameTestCase
## Pure enemy rules: SlimeStagger, TargetSelector, CoinDropper.roll and the slime stats.

const O := SlimeStagger.Outcome


func test_green_stagger_sequence() -> void:
	var s := SlimeStagger.new(2, 10.0)
	assert_eq(s.progress, 0, "starts at zero")
	assert_eq(s.register_melee_hit(1, 1), O.PROGRESS, "first base hit: progress")
	assert_eq(s.progress, 1, "progress 1")
	assert_eq(s.register_melee_hit(1, 2), O.STAGGERED, "second base hit: stagger")
	assert_eq(s.register_melee_hit(1, 2), O.IGNORED, "the staggering attack cannot also kill")
	assert_false(s.dead, "not dead after the staggering hit")
	assert_eq(s.register_melee_hit(1, 3), O.KILLED, "next distinct attack kills")
	assert_eq(s.register_melee_hit(1, 4), O.IGNORED, "dead slimes ignore hits")


func test_purple_stagger_sequence() -> void:
	var s := SlimeStagger.new(4, 10.0)
	for i in 3:
		assert_eq(s.register_melee_hit(1, 10 + i), O.PROGRESS, "hit %d: progress" % (i + 1))
		assert_eq(s.progress, i + 1, "progress %d" % (i + 1))
	assert_eq(s.register_melee_hit(1, 13), O.STAGGERED, "fourth base hit: stagger")
	assert_eq(s.register_melee_hit(1, 13), O.IGNORED, "same attack again: ignored")
	assert_eq(s.register_melee_hit(1, 14), O.KILLED, "distinct attack: killed")


func test_upgraded_attack_power() -> void:
	var green := SlimeStagger.new(2)
	assert_eq(green.register_melee_hit(2, 1), O.STAGGERED, "power 2 staggers green in one hit")
	assert_eq(green.register_melee_hit(2, 2), O.KILLED, "one more distinct hit kills")
	var purple := SlimeStagger.new(4)
	assert_eq(purple.register_melee_hit(2, 1), O.PROGRESS, "power 2 vs purple: progress")
	assert_eq(purple.progress, 2, "two points from one hit")
	assert_eq(purple.register_melee_hit(2, 2), O.STAGGERED, "second power-2 hit staggers purple")
	assert_eq(purple.register_melee_hit(1, 3), O.KILLED, "any distinct hit kills a staggered slime")
	var mixed := SlimeStagger.new(4)
	mixed.register_melee_hit(3, 1)
	assert_eq(mixed.register_melee_hit(3, 2), O.STAGGERED, "overshooting the threshold still staggers")


func test_duration_minimum_and_recovery() -> void:
	assert_eq(SlimeStagger.new(2, 3.0).duration, 10.0, "durations below 10 s are raised to 10 s")
	assert_eq(SlimeStagger.new(2, 12.0).duration, 12.0, "longer durations are kept")
	var s := SlimeStagger.new(2, 10.0)
	s.register_melee_hit(1, 1)
	s.register_melee_hit(1, 2)
	var recovered_at := -1
	for i in 700:
		if s.tick(1.0 / 60.0):
			recovered_at = i + 1
			break
	assert_eq(recovered_at, 600, "recovers after exactly 10 s of ticks")
	assert_eq(s.progress, 0, "recovery resets progress")
	assert_false(s.staggered, "no longer staggered")
	assert_eq(s.register_melee_hit(1, 3), O.PROGRESS, "starts again from zero")
	assert_eq(s.register_melee_hit(1, 4), O.STAGGERED, "can be staggered again")


func test_hits_do_not_restart_the_timer() -> void:
	var s := SlimeStagger.new(2)
	s.register_melee_hit(2, 1)
	for i in 300:
		s.tick(1.0 / 60.0)
	s.register_melee_hit(1, 1)  # the staggering attack again (ignored)
	s.add_stagger_progress(5)
	assert_near(s.time_left, 5.0, 0.001, "timer keeps running down")


func test_non_melee_progress_cannot_kill() -> void:
	var s := SlimeStagger.new(2)
	assert_eq(s.add_stagger_progress(1), O.PROGRESS, "poison-style progress counts")
	assert_eq(s.add_stagger_progress(1), O.STAGGERED, "and can stagger")
	assert_eq(s.add_stagger_progress(1), O.IGNORED, "but never kills a staggered slime")
	assert_eq(s.register_melee_hit(1, 7), O.KILLED, "any melee attack kills after a non-melee stagger")


func test_target_selector() -> void:
	var a := Node.new()
	var b := Node.new()
	assert_eq(TargetSelector.pick(null, [], [], 24.0), null, "no candidates: no target")
	assert_eq(TargetSelector.pick(null, [a, b], [50.0, 30.0], 24.0), b, "nearest wins")
	assert_eq(TargetSelector.pick(null, [a, b], [40.0, 40.0], 24.0), a, "tie: first candidate (Player One)")
	assert_eq(TargetSelector.pick(a, [a, b], [50.0, 35.0], 24.0), a, "current kept when the other is only slightly closer")
	assert_eq(TargetSelector.pick(a, [a, b], [80.0, 40.0], 24.0), b, "switch when meaningfully closer")
	assert_eq(TargetSelector.pick(a, [b], [90.0], 24.0), b, "current no longer valid: take the other")
	a.free()
	b.free()


func test_coin_roll_range_and_reproducibility() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var seen := {}
	var first_run: Array[int] = []
	for i in 1000:
		var n := CoinDropper.roll(rng, 4, 6)
		assert_true(n >= 4 and n <= 6, "roll %d in 4..6 (got %d)" % [i, n])
		seen[n] = true
		if i < 20:
			first_run.append(n)
	assert_eq(seen.keys().size(), 3, "all of 4, 5 and 6 occur")
	var again := RandomNumberGenerator.new()
	again.seed = 42
	var second_run: Array[int] = []
	for i in 20:
		second_run.append(CoinDropper.roll(again, 4, 6))
	assert_eq(second_run, first_run, "same seed, same rolls")


func test_slime_stats() -> void:
	var green: SlimeStats = load("res://resources/enemies/green_slime.tres")
	var purple: SlimeStats = load("res://resources/enemies/purple_slime.tres")
	for s: SlimeStats in [green, purple]:
		assert_eq(s.validate().size(), 0, "%s valid: %s" % [s.display_name, s.validate()])
		assert_eq(s.chase_speed(), s.patrol_speed * 2.0, "%s chase speed exactly twice patrol speed" % s.display_name)
		assert_true(s.effective_stagger_duration() >= 10.0, "%s staggers at least 10 s" % s.display_name)
		assert_eq([s.coin_min, s.coin_max], [4, 6], "%s drops 4-6 coins" % s.display_name)
	assert_eq(green.stagger_threshold, 2, "green threshold 2")
	assert_eq(purple.stagger_threshold, 4, "purple threshold 4")
	assert_false(green.sprite_frames == purple.sprite_frames, "different sprites")
	assert_eq(green.patrol_speed, purple.patrol_speed, "same movement apart from thresholds and visuals")
	var short := SlimeStats.new()
	short.stagger_duration = 4.0
	assert_eq(short.effective_stagger_duration(), 10.0, "a 4 s config is raised to 10 s")
	assert_gt(short.validate().size(), 0, "and reported by validate()")
