extends GameTestCase
## Pure-logic tests: attack direction, vertical intent priority, input frames, health.

const Dir := AttackDirection.Direction
const Intent := VerticalIntent.Intent


func test_attack_direction_table() -> void:
	# [up, down, facing] -> expected
	var cases := [
		[false, false, 1, Dir.RIGHT],
		[false, false, -1, Dir.LEFT],
		[true, false, 1, Dir.UP],
		[true, false, -1, Dir.UP],
		[false, true, 1, Dir.DOWN],
		[false, true, -1, Dir.DOWN],
		[true, true, 1, Dir.RIGHT],   # both held: fall back to facing
		[true, true, -1, Dir.LEFT],
	]
	for c in cases:
		assert_eq(AttackDirection.resolve(c[0], c[1], c[2]), c[3], "resolve(up=%s, down=%s, facing=%d)" % [c[0], c[1], c[2]])
	assert_eq(AttackDirection.to_vector(Dir.UP), Vector2i.UP, "UP vector")
	assert_eq(AttackDirection.to_vector(Dir.LEFT), Vector2i.LEFT, "LEFT vector")


func _ctx(fields: Dictionary) -> VerticalIntent.Context:
	var c := VerticalIntent.Context.new()
	for key: String in fields:
		c.set(key, fields[key])
	return c


func test_vertical_intent_priority_table() -> void:
	var cases := [
		[{}, Intent.NONE, "no input"],
		[{"on_floor": true, "jump_requested": true, "can_jump": true}, Intent.JUMP, "ground: up jumps"],
		[{"on_floor": true, "down_held": true, "down_pressed": true}, Intent.CROUCH, "ground: down crouches"],
		[{"on_floor": true, "on_one_way_only": true, "down_held": true, "down_pressed": true}, Intent.DROP_THROUGH, "one-way: down drops"],
		[{"on_floor": true, "on_one_way_only": true, "down_held": true}, Intent.NONE, "one-way: held down without new press does nothing"],
		[{"overlapping_climbable": true, "up_held": true, "on_floor": true, "jump_requested": true, "can_jump": true}, Intent.GRAB_CLIMB, "ladder: up grabs instead of jumping"],
		[{"overlapping_climbable": true, "up_held": true, "can_grab": false, "on_floor": true, "jump_requested": true, "can_jump": true}, Intent.JUMP, "regrab delay: up jumps"],
		[{"climbable_below_feet": true, "down_held": true, "down_pressed": true, "on_floor": true, "on_one_way_only": true}, Intent.GRAB_CLIMB, "ladder top: down climbs instead of dropping"],
		[{"overlapping_climbable": true, "down_held": true, "on_floor": true}, Intent.CROUCH, "ladder above only: down crouches"],
		[{"overlapping_climbable": true, "up_held": true, "down_held": true, "on_floor": true}, Intent.CROUCH, "up+down on ladder: no grab"],
		[{"jump_requested": true, "can_jump": false}, Intent.NONE, "air: no double jump"],
		[{"down_held": true, "down_pressed": true}, Intent.NONE, "air: down alone does nothing (no fast-fall)"],
		[{"climbable_below_feet": true, "down_held": true}, Intent.GRAB_CLIMB, "air: down grabs a ladder below"],
	]
	for c in cases:
		assert_eq(VerticalIntent.resolve(_ctx(c[0])), c[1], c[2])


func test_input_frame_edges_and_axes() -> void:
	var none := KnightInputFrame.new()
	var f1 := KnightInputFrame.capture(false, true, true, false, true, none)
	assert_eq(f1.move_x, 1, "right only")
	assert_true(f1.up_pressed and f1.attack_pressed, "first frame of a hold is a press")
	var f2 := KnightInputFrame.capture(false, true, true, false, true, f1)
	assert_false(f2.up_pressed or f2.attack_pressed, "holding is not a new press")
	var f3 := KnightInputFrame.capture(true, true, true, true, false, f2)
	assert_eq(f3.move_x, 0, "left+right cancel")
	assert_eq(f3.climb_axis(), 0, "up+down cancel")
	assert_true(f3.down_pressed, "down edge")
	var tap := KnightInputFrame.capture(false, false, false, false, false, f3, {&"attack": true})
	assert_true(tap.attack_pressed, "sub-tick tap reported by the engine still counts")
	var held := KnightInputFrame.capture(false, false, false, false, true, tap)
	var late := KnightInputFrame.capture(false, false, false, false, true, held, {&"attack": true})
	assert_false(late.attack_pressed, "a late engine just-pressed during a hold is not a second press")


func test_health_limits() -> void:
	var h := HealthComponent.new()
	add_child(h)
	h.initialize(3)
	assert_eq(h.current_health, 3, "starts full")
	assert_eq(h.max_health, 3, "max 3")
	var depleted_count := [0]
	h.depleted.connect(func() -> void: depleted_count[0] += 1)
	assert_eq(h.heal(5), 0, "cannot heal above max")
	assert_eq(h.apply_damage(2), 2, "damage applied")
	assert_eq(h.heal(5), 2, "heal clamps to max (1 -> 3)")
	assert_eq(h.current_health, 3, "back to full")
	assert_eq(h.apply_damage(10), 3, "damage clamps at zero")
	assert_eq(h.current_health, 0, "never negative")
	assert_eq(h.apply_damage(1), 0, "no damage past zero")
	assert_eq(depleted_count[0], 1, "depleted emitted exactly once")
	assert_eq(h.heal(1), 0, "a depleted entity is not healed")
	h.queue_free()


func test_health_max_changes() -> void:
	var h := HealthComponent.new()
	add_child(h)
	h.initialize(3)
	h.apply_damage(1)
	h.set_max_health(4, true)
	assert_eq(h.max_health, 4, "max raised")
	assert_eq(h.current_health, 3, "added point filled (2 + 1)")
	h.set_max_health(5)
	assert_eq(h.current_health, 3, "raise without fill keeps current")
	h.set_max_health(2)
	assert_eq(h.current_health, 2, "lowering max clamps current")
	h.set_max_health(0)
	assert_eq(h.max_health, 1, "max never below 1")
	h.queue_free()
