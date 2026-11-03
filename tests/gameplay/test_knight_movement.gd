extends GameTestCase
## Simulated gameplay in the real Phase 1 test room, driven through the real InputMap
## actions. Room geometry (pixels): floor top y=320; one-way platforms at y=272 (x 32-112),
## y=224 (x 64-144), y=176 (x 32-112); crouch tunnel x 208-304 (16 px gap); corridor
## x 336-448 (32 px gap); ladder x=488 from y=176 to 320; ledge y=176 from x 480;
## passage x 544-592 from y=64 to 176; right wall at x=624.

const ROOM := "res://scenes/dev/phase_1_test_room.tscn"
const ALL_ACTIONS := [&"p1_move_left", &"p1_move_right", &"p1_move_up", &"p1_move_down", &"p1_attack",
	&"p2_move_left", &"p2_move_right", &"p2_move_up", &"p2_move_down", &"p2_attack"]

var room: Node2D
var k1: Knight
var k2: Knight


func before_each() -> void:
	_release_all()
	room = (load(ROOM) as PackedScene).instantiate()
	add_child(room)
	k1 = room.get_node("Knights/Knight1")
	k2 = room.get_node("Knights/Knight2")
	await physics_frames(5)


func after_each() -> void:
	_release_all()
	room.queue_free()
	await physics_frames(2)


func _release_all() -> void:
	for a in ALL_ACTIONS:
		Input.action_release(a)


func _press(actions: Array) -> void:
	for a in actions:
		Input.action_press(a)


func _release(actions: Array) -> void:
	for a in actions:
		Input.action_release(a)


func _hold(actions: Array, frames: int) -> void:
	_press(actions)
	await physics_frames(frames)
	_release(actions)


## Like _hold, then waits one tick so the release is seen before the next press
## (a human cannot release and re-press a key within a single 16 ms tick).
func _tap(actions: Array, frames := 2) -> void:
	await _hold(actions, frames)
	await physics_frames(1)


func _place(k: Knight, at: Vector2, settle := 20) -> void:
	k.teleport_to(at)
	await physics_frames(settle)


# --- Spawning and identity ---------------------------------------------------------

func test_knights_spawn_independent() -> void:
	await physics_frames(10)
	assert_eq(k1.player_id(), 1, "knight 1 id")
	assert_eq(k2.player_id(), 2, "knight 2 id")
	assert_true(k1.config == k2.config, "both knights share one movement config")
	assert_false(k1.body_shape.shape == k2.body_shape.shape, "collision shapes are per instance")
	assert_false(k1.sprite.material == k2.sprite.material, "palette materials are per instance")
	assert_eq(k1.health.current_health, 3, "P1 health 3")
	assert_eq(k2.health.max_health, 3, "P2 max health 3")
	assert_eq(k1.state, Knight.State.GROUNDED, "P1 grounded on spawn")
	assert_eq(k2.state, Knight.State.GROUNDED, "P2 grounded on spawn")
	assert_near(k1.global_position.y, 320.0, 0.5, "P1 on floor")
	var p1_tunic: Color = (k1.sprite.material as ShaderMaterial).get_shader_parameter(&"target_tunic")
	var p2_tunic: Color = (k2.sprite.material as ShaderMaterial).get_shader_parameter(&"target_tunic")
	assert_false(p1_tunic.is_equal_approx(p2_tunic), "knights have different tunic colours")
	k1.health.apply_damage(1)
	assert_eq(k2.health.current_health, 3, "damaging P1 does not affect P2")


# --- Horizontal movement and simultaneity ------------------------------------------

func test_players_move_independently_and_simultaneously() -> void:
	await _place(k1, Vector2(40, 320))
	await _place(k2, Vector2(600, 320))
	var x1 := k1.global_position.x
	var x2 := k2.global_position.x
	await _hold([&"p1_move_right"], 30)
	assert_gt(k1.global_position.x - x1, 30.0, "P1 moved right")
	assert_near(k2.global_position.x, x2, 0.01, "P2 did not move")
	await physics_frames(20)
	x1 = k1.global_position.x
	await _hold([&"p2_move_left"], 30)
	assert_lt(k2.global_position.x - x2, -30.0, "P2 moved left")
	assert_near(k1.global_position.x, x1, 0.01, "P1 did not move")
	await physics_frames(20)
	x1 = k1.global_position.x
	x2 = k2.global_position.x
	await _hold([&"p1_move_left", &"p2_move_right"], 20)
	assert_lt(k1.global_position.x - x1, -10.0, "P1 moved left while P2 moved right")
	assert_gt(k2.global_position.x - x2, 10.0, "P2 moved right while P1 moved left")


func test_left_and_right_together_cancel() -> void:
	await _place(k1, Vector2(40, 320))
	var x1 := k1.global_position.x
	await _hold([&"p1_move_left", &"p1_move_right"], 20)
	assert_near(k1.global_position.x, x1, 0.01, "opposite directions cancel")


# --- Jumping -----------------------------------------------------------------------

func _jump_peak(k: Knight, action: StringName, hold_frames: int, total_frames: int) -> float:
	var start_y := k.global_position.y
	var min_y := start_y
	_press([action])
	for i in total_frames:
		if i == hold_frames:
			_release([action])
		await physics_frames(1)
		min_y = minf(min_y, k.global_position.y)
	_release([action])
	return start_y - min_y


func test_full_jump_height_and_landing() -> void:
	await _place(k1, Vector2(530, 320))
	await _place(k2, Vector2(600, 320))
	var peak := await _jump_peak(k1, &"p1_move_up", 60, 70)
	assert_near(peak, k1.config.jump_height(), 4.0, "full jump reaches the configured height")
	await physics_frames(10)
	assert_eq(k1.state, Knight.State.GROUNDED, "landed")
	assert_near(k1.global_position.y, 320.0, 0.5, "landed on the floor")


func test_variable_jump_height() -> void:
	await _place(k1, Vector2(530, 320))
	var full := k1.config.jump_height()
	var tapped := await _jump_peak(k1, &"p1_move_up", 4, 60)
	assert_gt(tapped, 10.0, "tap still jumps")
	assert_lt(tapped, full * 0.6, "releasing early cuts the jump")


func test_no_double_jump_and_no_hold_bunny_hop() -> void:
	await _place(k1, Vector2(530, 320))
	var jumps := [0]
	k1.jumped.connect(func() -> void: jumps[0] += 1)
	await _hold([&"p1_move_up"], 5)
	await physics_frames(5)
	await _hold([&"p1_move_up"], 5)  # second press while airborne
	await physics_frames(40)
	assert_eq(jumps[0], 1, "airborne press does not jump again")
	_press([&"p1_move_up"])
	await physics_frames(90)  # holding Up through landing
	_release([&"p1_move_up"])
	assert_eq(jumps[0], 2, "holding Up jumps once, not repeatedly")


func test_jump_buffer_before_landing() -> void:
	await _place(k1, Vector2(530, 240), 1)
	var jumps := [0]
	k1.jumped.connect(func() -> void: jumps[0] += 1)
	for i in 60:
		await physics_frames(1)
		if k1.global_position.y > 306.0 and k1.velocity.y > 0.0:
			break
	assert_eq(k1.state, Knight.State.AIRBORNE, "still falling when Up is pressed")
	await _hold([&"p1_move_up"], 10)
	assert_eq(jumps[0], 1, "buffered press jumps on landing")


func test_both_jump_in_same_frame() -> void:
	await _place(k1, Vector2(530, 320))
	await _place(k2, Vector2(600, 320))
	var frames := {}
	k1.jumped.connect(func() -> void: frames[1] = Engine.get_physics_frames())
	k2.jumped.connect(func() -> void: frames[2] = Engine.get_physics_frames())
	await _hold([&"p1_move_up", &"p2_move_up"], 3)
	assert_true(frames.has(1) and frames.has(2), "both knights jumped")
	assert_eq(frames.get(1), frames.get(2), "both jumps happened on the same physics frame")


# --- Crouching ---------------------------------------------------------------------

func test_crouch_under_low_ceiling() -> void:
	await _place(k1, Vector2(198, 320))
	await _place(k2, Vector2(600, 320))
	await _hold([&"p1_move_right"], 40)
	assert_lt(k1.global_position.x, 204.0, "standing knight cannot enter the 16 px tunnel")
	await _hold([&"p1_move_down"], 5)
	assert_eq(k1.state, Knight.State.CROUCHING, "Down on solid ground crouches")
	assert_near((k1.body_shape.shape as RectangleShape2D).size.y, k1.config.crouch_size.y, 0.01, "crouch shape")
	await _hold([&"p1_move_down", &"p1_move_right"], 70)
	assert_gt(k1.global_position.x, 225.0, "crouched knight moves into the tunnel")
	await physics_frames(10)
	assert_eq(k1.state, Knight.State.CROUCHING, "cannot stand under the ceiling after releasing Down")
	await _hold([&"p1_move_up"], 3)
	assert_eq(k1.state, Knight.State.CROUCHING, "cannot jump under the ceiling")
	await _hold([&"p1_move_right"], 150)
	await physics_frames(5)
	assert_gt(k1.global_position.x, 309.0, "crawled out of the tunnel")
	assert_eq(k1.state, Knight.State.GROUNDED, "stands up automatically when clear")
	assert_near((k1.body_shape.shape as RectangleShape2D).size.y, k1.config.standing_size.y, 0.01, "standing shape restored")


func test_down_on_solid_floor_does_not_drop() -> void:
	await _place(k1, Vector2(530, 320))
	await _hold([&"p1_move_down"], 30)
	assert_near(k1.global_position.y, 320.0, 0.5, "still on the floor")
	await physics_frames(5)
	assert_eq(k1.state, Knight.State.GROUNDED, "stands again after releasing Down")


# --- One-way platforms -------------------------------------------------------------

func test_drop_through_one_way_and_jump_back_up() -> void:
	await _place(k1, Vector2(72, 266))
	assert_near(k1.global_position.y, 272.0, 0.5, "standing on the one-way platform")
	assert_eq(k1.floor_kind, Knight.FloorKind.ONE_WAY, "floor detected as one-way")
	await _hold([&"p1_move_down"], 3)
	await physics_frames(40)
	assert_near(k1.global_position.y, 320.0, 0.5, "dropped to the floor")
	assert_true(k1.get_collision_mask_value(2), "one-way collision restored after the drop")
	assert_true(k1.get_collision_mask_value(1), "solid collision was never disabled")
	await _hold([&"p1_move_up"], 40)
	await physics_frames(30)
	assert_near(k1.global_position.y, 272.0, 0.5, "jumped up through the platform and landed on it")


func test_drop_passes_only_one_platform() -> void:
	await _place(k1, Vector2(72, 170))
	assert_near(k1.global_position.y, 176.0, 0.5, "on the top one-way platform")
	await _hold([&"p1_move_down"], 3)
	await physics_frames(50)
	assert_near(k1.global_position.y, 224.0, 0.5, "caught by the next platform, not falling through the level")


func test_other_knight_unaffected_by_drop() -> void:
	await _place(k1, Vector2(48, 266))
	await _place(k2, Vector2(96, 266))
	await _hold([&"p1_move_down"], 3)
	await physics_frames(40)
	assert_near(k1.global_position.y, 320.0, 0.5, "P1 dropped")
	assert_near(k2.global_position.y, 272.0, 0.5, "P2 still standing on the same platform")
	assert_true(k2.get_collision_mask_value(2), "P2 one-way collision untouched")


# --- Ladders and passages ----------------------------------------------------------

func test_ladder_climb_up_hold_and_exit_top() -> void:
	await _place(k1, Vector2(488, 320))
	await _hold([&"p1_move_up"], 40)
	assert_eq(k1.state, Knight.State.CLIMBING, "Up at a ladder climbs")
	assert_lt(k1.global_position.y, 300.0, "climbed upward")
	var y := k1.global_position.y
	await physics_frames(30)
	assert_eq(k1.state, Knight.State.CLIMBING, "stays on the ladder with no input")
	assert_near(k1.global_position.y, y, 0.01, "no gravity while climbing")
	await _hold([&"p1_move_up"], 150)
	await physics_frames(10)
	assert_eq(k1.state, Knight.State.GROUNDED, "climbed out at the top")
	assert_near(k1.global_position.y, 176.0, 0.5, "standing on the ladder top")
	assert_true(k1.get_collision_mask_value(2), "one-way collision restored after climbing")
	assert_true(k1.get_collision_layer_value(3), "knight collision restored after climbing")


func test_ladder_climb_down_from_top() -> void:
	await _place(k1, Vector2(488, 170))
	assert_near(k1.global_position.y, 176.0, 0.5, "standing on the ladder top")
	await _hold([&"p1_move_down"], 10)
	assert_eq(k1.state, Knight.State.CLIMBING, "Down above a ladder climbs down instead of dropping")
	await _hold([&"p1_move_down"], 150)
	await physics_frames(5)
	assert_eq(k1.state, Knight.State.GROUNDED, "left the ladder at the bottom")
	assert_near(k1.global_position.y, 320.0, 0.5, "on the floor")


func test_ladder_side_release() -> void:
	await _place(k1, Vector2(488, 320))
	await _hold([&"p1_move_up"], 40)
	assert_eq(k1.state, Knight.State.CLIMBING, "climbing")
	await _hold([&"p1_move_right"], 3)
	assert_eq(k1.state, Knight.State.AIRBORNE, "sideways input lets go of the ladder")
	await physics_frames(40)
	assert_eq(k1.state, Knight.State.GROUNDED, "fell back to the floor")
	assert_gt(k1.global_position.x, 488.0, "stepped off to the right")


func test_passage_allows_free_movement() -> void:
	await _place(k1, Vector2(560, 170))
	assert_near(k1.global_position.y, 176.0, 0.5, "on the ledge inside the passage")
	await _hold([&"p1_move_up"], 10)
	assert_eq(k1.state, Knight.State.CLIMBING, "Up in a passage climbs")
	var x := k1.global_position.x
	await _hold([&"p1_move_up", &"p1_move_right"], 12)
	assert_gt(k1.global_position.x, x + 5.0, "sideways movement inside the passage")
	assert_eq(k1.state, Knight.State.CLIMBING, "still in the passage")
	await _hold([&"p1_move_up"], 120)
	await physics_frames(10)
	assert_eq(k1.state, Knight.State.GROUNDED, "climbed out of the passage top")
	assert_near(k1.global_position.y, 64.0, 0.5, "standing on the passage exit")


# --- Attack input (no combat in Phase 1) -------------------------------------------

func test_attack_inputs_are_independent() -> void:
	await _place(k1, Vector2(530, 320))
	await _place(k2, Vector2(600, 320))
	await _tap([&"p1_attack"])
	assert_eq(k1.attack_count, 1, "P1 attack registered")
	assert_eq(k2.attack_count, 0, "P2 attack not triggered by V")
	await _tap([&"p2_attack"])
	assert_eq(k2.attack_count, 1, "P2 attack registered")
	assert_eq(k1.attack_count, 1, "P1 attack not triggered by Alt")
	await _tap([&"p1_attack", &"p2_attack"])
	assert_eq(k1.attack_count, 2, "P1 attack in the same frame as P2")
	assert_eq(k2.attack_count, 2, "P2 attack in the same frame as P1")
	await _hold([&"p1_attack"], 30)
	assert_eq(k1.attack_count, 3, "holding attack does not repeat")


func test_attack_direction_from_input() -> void:
	await _place(k1, Vector2(560, 320))
	await _hold([&"p1_move_left"], 5)
	await physics_frames(10)
	assert_eq(k1.facing, -1, "facing left")
	await _tap([&"p1_move_up", &"p1_attack"])
	assert_eq(k1.last_attack_direction, AttackDirection.Direction.UP, "Up held: upward attack")
	await physics_frames(60)
	assert_eq(k1.facing, -1, "jumping with Up did not change facing")
	await _tap([&"p1_attack"])
	assert_eq(k1.last_attack_direction, AttackDirection.Direction.LEFT, "no vertical key: last facing")
	await _tap([&"p1_move_down", &"p1_attack"])
	assert_eq(k1.last_attack_direction, AttackDirection.Direction.DOWN, "Down held: downward attack")
	await physics_frames(10)
	await _tap([&"p1_move_up", &"p1_move_down", &"p1_attack"])
	assert_eq(k1.last_attack_direction, AttackDirection.Direction.LEFT, "Up and Down: last facing")
	assert_eq(k1.facing, -1, "Up/Down never change facing")


# --- Knight-to-knight interaction --------------------------------------------------

func test_push_moves_the_other_knight() -> void:
	await _place(k1, Vector2(520, 320))
	await _place(k2, Vector2(535, 320))
	var x2 := k2.global_position.x
	await _hold([&"p1_move_right"], 60)
	assert_gt(k2.global_position.x - x2, 15.0, "P2 was pushed")
	assert_lt(k2.global_position.x - x2, 60.0 * k1.config.push_speed / 60.0 + 2.0, "push speed is capped")
	assert_gt(k2.global_position.x - k1.global_position.x, 9.5, "knights never overlap")
	assert_eq(k2.state, Knight.State.GROUNDED, "pushed knight stays grounded")
	assert_lt(absf(k2.velocity.x), 0.01, "push adds no velocity (no impulses)")


func test_push_against_wall_does_not_trap() -> void:
	await _place(k2, Vector2(617, 320))
	await _place(k1, Vector2(600, 320))
	await _hold([&"p1_move_right"], 60)
	assert_lt(k2.global_position.x, 619.6, "wall stops the pushed knight")
	assert_gt(k2.global_position.x - k1.global_position.x, 9.5, "no overlap against the wall")
	var x1 := k1.global_position.x
	await _hold([&"p1_move_left"], 30)
	assert_lt(k1.global_position.x, x1 - 20.0, "pusher can walk away")
	await _hold([&"p2_move_up"], 3)
	assert_eq(k2.state, Knight.State.AIRBORNE, "pinned knight can still jump")


func test_corridor_mutual_push_never_locks() -> void:
	await _place(k1, Vector2(370, 320))
	await _place(k2, Vector2(400, 320))
	await _hold([&"p1_move_right", &"p2_move_left"], 90)
	var gap := k2.global_position.x - k1.global_position.x
	assert_gt(gap, 9.5, "no overlap while pushing head-on")
	await _hold([&"p1_move_left", &"p2_move_right"], 40)
	assert_gt(k2.global_position.x - k1.global_position.x, gap + 40.0, "both can separate again")
	await _hold([&"p1_move_up", &"p2_move_up"], 3)
	assert_eq(k1.state, Knight.State.AIRBORNE, "P1 can jump in the corridor")
	assert_eq(k2.state, Knight.State.AIRBORNE, "P2 can jump in the corridor")
	await physics_frames(40)
	assert_eq(k1.state, Knight.State.GROUNDED, "P1 landed")
	assert_eq(k2.state, Knight.State.GROUNDED, "P2 landed")


func test_push_off_platform_edge() -> void:
	await _place(k2, Vector2(490, 170))
	await _place(k1, Vector2(510, 170))
	_press([&"p1_move_left"])
	for i in 90:
		await physics_frames(1)
		if k2.state == Knight.State.AIRBORNE:
			break
	_release([&"p1_move_left"])
	assert_eq(k2.state, Knight.State.AIRBORNE, "P2 was pushed off the edge")
	await physics_frames(60)
	assert_eq(k2.state, Knight.State.GROUNDED, "P2 landed safely below")
	assert_near(k2.global_position.y, 320.0, 0.5, "P2 on the floor")
	assert_near(k1.global_position.y, 176.0, 0.5, "P1 stopped on the ledge")
	assert_eq(k2.health.current_health, 3, "no damage in Phase 1")


func test_standing_on_knight_carry_and_lift() -> void:
	await _place(k1, Vector2(560, 320))
	await _place(k2, Vector2(560, 298), 30)
	assert_eq(k2.floor_kind, Knight.FloorKind.KNIGHT, "P2 stands on P1")
	assert_near(k2.global_position.y, 302.0, 0.5, "P2 rests on P1's head")
	await _hold([&"p1_move_right"], 20)
	assert_near(k2.global_position.x, k1.global_position.x, 3.0, "rider is carried along")
	var rider_y := k2.global_position.y
	var min_y := rider_y
	_press([&"p1_move_up"])
	for i in 20:
		await physics_frames(1)
		min_y = minf(min_y, k2.global_position.y)
	_release([&"p1_move_up"])
	assert_lt(min_y, rider_y - 30.0, "rider is lifted when the lower knight jumps")
	await physics_frames(60)
	assert_eq(k1.state, Knight.State.GROUNDED, "lower knight landed")
	assert_true(k2.state == Knight.State.GROUNDED, "rider landed")
	await _hold([&"p2_move_up"], 3)
	assert_eq(k2.state, Knight.State.AIRBORNE, "rider can jump away")


func test_spawn_overlap_resolves_without_impulse() -> void:
	await _place(k1, Vector2(560, 320))
	k2.teleport_to(k1.global_position)
	var max_speed := 0.0
	for i in 15:
		await physics_frames(1)
		max_speed = maxf(max_speed, maxf(k1.velocity.length(), k2.velocity.length()))
	assert_lt(max_speed, 50.0, "overlapping spawn does not fling knights")
	await _hold([&"p1_move_right"], 30)
	await physics_frames(10)
	assert_gt(absf(k1.global_position.x - k2.global_position.x), 10.0, "knights separated")
	assert_true(k1.get_collision_layer_value(3) and k2.get_collision_layer_value(3), "knight collision restored")


# --- Raw key events (InputEventKey -> InputMap -> knights) -------------------------
# These go through the same event path as a real keyboard, except the OS driver itself.

func _key(key: Key, pressed: bool, location := KEY_LOCATION_UNSPECIFIED, alt := false) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = key
	e.keycode = key
	e.location = location
	e.pressed = pressed
	e.alt_pressed = alt
	Input.parse_input_event(e)


func test_raw_key_events_drive_both_knights() -> void:
	await _place(k1, Vector2(40, 320))
	await _place(k2, Vector2(560, 320))
	var hud := room.get_node("InputDebugHud")
	var x1 := k1.global_position.x
	var x2 := k2.global_position.x
	_key(KEY_D, true)
	_key(KEY_LEFT, true)
	await physics_frames(20)
	_key(KEY_D, false)
	_key(KEY_LEFT, false)
	assert_gt(k1.global_position.x - x1, 10.0, "D moves P1 right")
	assert_lt(k2.global_position.x - x2, -10.0, "Left Arrow moves P2 left")
	await physics_frames(5)

	_key(KEY_ALT, true, KEY_LOCATION_LEFT, true)
	await physics_frames(2)
	assert_eq(k2.attack_count, 1, "Left Alt attacks for P2")
	_key(KEY_ALT, false, KEY_LOCATION_LEFT)
	await physics_frames(2)
	_key(KEY_ALT, true, KEY_LOCATION_RIGHT, true)
	await physics_frames(2)
	assert_eq(k2.attack_count, 2, "Right Alt attacks for P2")
	# While P2 holds Right Alt, P1's keys arrive with alt_pressed = true.
	_key(KEY_V, true, KEY_LOCATION_UNSPECIFIED, true)
	_key(KEY_W, true, KEY_LOCATION_UNSPECIFIED, true)
	await physics_frames(3)
	assert_eq(k1.attack_count, 1, "V still attacks while Alt is held")
	assert_eq(k1.state, Knight.State.AIRBORNE, "W still jumps while Alt is held")
	assert_eq(k2.attack_count, 2, "P1 keys do not trigger P2 attacks")
	_key(KEY_V, false, KEY_LOCATION_UNSPECIFIED, true)
	_key(KEY_W, false, KEY_LOCATION_UNSPECIFIED, true)
	_key(KEY_ALT, false, KEY_LOCATION_RIGHT)
	await physics_frames(2)
	assert_eq(hud.get("_alt_counts")["LEFT"], 1, "debug HUD saw one Left Alt press")
	assert_eq(hud.get("_alt_counts")["RIGHT"], 1, "debug HUD saw one Right Alt press")
