extends GameTestCase
## Combat and health in the real combat test room (floor y=448). The room's own targets are
## removed in before_each; each test places training dummies and walls where it needs them.
## A dummy's hurtbox is 10x16 px above its feet. A standing knight's right slash covers
## x = +4..+18 and y = -16..-2 relative to its feet.

const ROOM := "res://scenes/dev/combat_test_room.tscn"
const DUMMY := "res://scenes/objects/training_dummy.tscn"
const FLOOR := 448.0
const ALL_ACTIONS := [&"p1_move_left", &"p1_move_right", &"p1_move_up", &"p1_move_down", &"p1_attack",
	&"p2_move_left", &"p2_move_right", &"p2_move_up", &"p2_move_down", &"p2_attack"]
const Dir := AttackDirection.Direction
const S := CombatComponent.State

var room: Node
var level: Node2D
var rig: SplitScreenRig
var k1: Knight
var k2: Knight


func before_each() -> void:
	TrainingDummy.console_log = false
	_release_all()
	room = (load(ROOM) as PackedScene).instantiate()
	add_child(room)
	level = room.get("level")
	rig = room.get("rig")
	k1 = room.get("knight_1")
	k2 = room.get("knight_2")
	for dummy in level.get_node("Targets").get_children():
		dummy.queue_free()
	k1.teleport_to(Vector2(100, FLOOR))
	k2.teleport_to(Vector2(400, FLOOR))
	await physics_frames(10)


func after_each() -> void:
	_release_all()
	room.queue_free()
	await physics_frames(2)
	TrainingDummy.console_log = true


func _release_all() -> void:
	for a in ALL_ACTIONS:
		Input.action_release(a)


func _tap(actions: Array) -> void:
	for a in actions:
		Input.action_press(a)
	await physics_frames(1)
	for a in actions:
		Input.action_release(a)


func _dummy(at: Vector2, hp := 3) -> TrainingDummy:
	var dummy: TrainingDummy = (load(DUMMY) as PackedScene).instantiate()
	dummy.max_health = hp
	dummy.position = at
	level.add_child(dummy)
	return dummy


func _wall(rect: Rect2, layer := 1, one_way := false) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = rect.get_center()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.one_way_collision = one_way
	body.add_child(shape)
	level.add_child(body)
	return body


# --- Independence -------------------------------------------------------------------------

func test_player_one_attacks_independently() -> void:
	var d1 := _dummy(Vector2(114, FLOOR))
	var d2 := _dummy(Vector2(414, FLOOR))
	await _tap([&"p1_attack"])
	await physics_frames(12)
	assert_eq(d1.hits_taken(), 1, "P1's target hit once")
	assert_eq(d2.hits_taken(), 0, "P2's target untouched")
	assert_eq(k2.combat.attack_id, 0, "P2 never attacked")
	assert_eq(d1.damage_log[0].attacker, 1, "hit attributed to P1")


func test_player_two_attacks_independently() -> void:
	var d1 := _dummy(Vector2(114, FLOOR))
	var d2 := _dummy(Vector2(414, FLOOR))
	await _tap([&"p2_attack"])
	await physics_frames(12)
	assert_eq(d2.hits_taken(), 1, "P2's target hit once")
	assert_eq(d1.hits_taken(), 0, "P1's target untouched")
	assert_eq(d2.damage_log[0].attacker, 2, "hit attributed to P2")


func test_simultaneous_attacks() -> void:
	var d1 := _dummy(Vector2(114, FLOOR))
	var d2 := _dummy(Vector2(414, FLOOR))
	var both_active := [false]
	await _tap([&"p1_attack", &"p2_attack"])
	for i in 12:
		if k1.combat.is_hit_window_open() and k2.combat.is_hit_window_open():
			both_active[0] = true
		await physics_frames(1)
	assert_true(both_active[0], "both hit windows were open in the same frame")
	assert_eq(d1.hits_taken(), 1, "P1 hit")
	assert_eq(d2.hits_taken(), 1, "P2 hit")
	assert_false(k1.combat.attack_id == k2.combat.attack_id, "attack ids are unique per knight")


func test_attack_does_not_interrupt_other_player() -> void:
	await _tap([&"p1_attack"])
	await physics_frames(2)
	var p1_id := k1.combat.attack_id
	await _tap([&"p2_attack"])
	assert_eq(k1.combat.attack_id, p1_id, "P1's attack keeps its id")
	assert_eq(k1.combat.state, S.ATTACKING, "P1 still attacking after P2 starts")
	await physics_frames(20)
	assert_eq(k1.combat.state, S.IDLE, "P1 finished normally")


func test_knights_cannot_hit_each_other() -> void:
	k2.teleport_to(Vector2(112, FLOOR))
	await physics_frames(5)
	await _tap([&"p1_attack"])
	await physics_frames(12)
	assert_eq(k2.health.current_health, 3, "no friendly fire")
	assert_eq(k1.health.current_health, 3, "no self-damage")
	assert_eq(k1.combat.hit_log.size(), 0, "nothing was hit")


# --- Direction and animation -----------------------------------------------------------

func test_four_directions_and_animation_selection() -> void:
	await _tap([&"p1_attack"])
	assert_eq(k1.combat.animation_name(), "attack_right", "default facing: right")
	assert_eq(k1.sprite.animation, &"attack_side", "the knight's own slash animation shows")
	assert_false(k1.sprite.flip_h, "slash faces right")
	assert_false(k1.combat.weapon.visible, "side slashes need no knife overlay")
	await physics_frames(20)
	assert_false(k1.sprite.animation == &"attack_side", "slash pose ends with the attack")
	Input.action_press(&"p1_move_left")
	await physics_frames(3)
	Input.action_release(&"p1_move_left")
	await physics_frames(10)
	await _tap([&"p1_attack"])
	assert_eq(k1.combat.animation_name(), "attack_left", "after moving left: left")
	assert_true(k1.sprite.flip_h, "slash mirrored")
	await physics_frames(20)
	await _tap([&"p1_move_up", &"p1_attack"])
	assert_eq(k1.combat.direction, Dir.UP, "Up held: UP")
	assert_eq(k1.combat.animation_name(), "attack_up", "up animation")
	assert_near(k1.combat.weapon.rotation, -PI * 0.5, 0.0001, "weapon rotated up")
	await physics_frames(60)
	assert_eq(k1.facing, -1, "jumping with Up did not change facing")
	await _tap([&"p1_move_down", &"p1_attack"])
	assert_eq(k1.combat.animation_name(), "attack_low_left", "Down on the ground: low slash toward facing (D-2)")
	await physics_frames(20)
	Input.action_press(&"p1_move_up")
	await physics_frames(8)
	Input.action_release(&"p1_move_up")
	assert_eq(k1.state, Knight.State.AIRBORNE, "airborne")
	await _tap([&"p1_move_down", &"p1_attack"])
	assert_eq(k1.combat.animation_name(), "attack_down", "Down in the air: downward slash")
	assert_near(k1.combat.weapon.rotation, PI * 0.5, 0.0001, "weapon rotated down")


func test_down_attack_from_ladder_hits_target_below() -> void:
	k1.teleport_to(Vector2(552, FLOOR))
	await physics_frames(5)
	Input.action_press(&"p1_move_up")
	await physics_frames(20)  # climb ~23 px up the ladder
	Input.action_release(&"p1_move_up")
	assert_eq(k1.state, Knight.State.CLIMBING, "on the ladder")
	var target := _dummy(Vector2(552, FLOOR))
	await _tap([&"p1_move_down", &"p1_attack"])
	await physics_frames(12)
	assert_eq(k1.combat.animation_name(), "attack_down", "down slash on a ladder")
	assert_eq(target.hits_taken(), 1, "target below the ladder hit")


# --- Timing -----------------------------------------------------------------------------

func test_hit_frames_and_animation_are_synchronised() -> void:
	var target := _dummy(Vector2(114, FLOOR))
	var c := k1.combat
	var opened := []
	var closed := []
	var at_hit := []
	c.hit_window_opened.connect(func(_id: int) -> void: opened.append(c.elapsed()))
	c.hit_window_closed.connect(func(_id: int) -> void: closed.append(c.elapsed()))
	target.hit.connect(func(_e: DamageEvent, _a: int) -> void: at_hit.append([c.elapsed(), k1.sprite.frame]))
	var active_frames := 0
	var weapon_frames_while_active := {}
	var weapon_frames_before := {}
	await _tap([&"p1_attack"])
	for i in 25:
		if c.hitbox.active:
			active_frames += 1
			weapon_frames_while_active[k1.sprite.frame] = true
		elif c.state == S.ATTACKING:
			weapon_frames_before[k1.sprite.frame] = true
		await physics_frames(1)
	var cfg := c.config
	assert_eq(active_frames, int(round(cfg.active_time * 60.0)), "hitbox active for exactly the hit frames")
	assert_near(opened[0], cfg.windup_time + 1.0 / 60.0, 0.001, "opens on the first tick after the windup")
	assert_near(closed[0], cfg.hit_window_end() + 1.0 / 60.0, 0.001, "closes right after the hit frames")
	# Soldier slash sheet: frame 1 sword raised (windup), 3-4 the arc (hit frames), 5 follow-through.
	assert_eq(weapon_frames_while_active.keys().all(func(f: int) -> bool: return f == 3 or f == 4), true, "arc frames 3-4 shown only during hit frames")
	assert_eq(weapon_frames_before.keys(), [1], "windup frame 1 before the hit frames")
	assert_eq(at_hit.size(), 1, "one hit")
	assert_near(at_hit[0][0], opened[0], 0.0001, "damage lands on the first hit frame")
	assert_eq(at_hit[0][1], 3, "the arc frame is showing when damage lands")
	assert_false(c.hitbox.active, "hitbox closed after the attack")
	assert_eq(c.state, S.IDLE, "back to idle")


func test_cooldown_and_input_buffer() -> void:
	var c := k1.combat
	var starts := []
	c.attack_started.connect(func(_id: int, _d: Dir) -> void: starts.append(Engine.get_physics_frames()))
	await _tap([&"p1_attack"])
	await physics_frames(4)
	await _tap([&"p1_attack"])  # at ~0.1 s: too early to buffer, ignored
	await physics_frames(10)
	assert_eq(starts.size(), 1, "spam during the cooldown does not start attacks")
	await _tap([&"p1_attack"])  # at ~0.25 s: inside the 0.1 s buffer window
	await physics_frames(10)
	assert_eq(starts.size(), 2, "buffered press starts when the cooldown ends")
	assert_eq(starts[1] - starts[0], int(round(c.config.cooldown * 60.0)), "second attack starts exactly one cooldown later")
	# Holding the button does not repeat attacks.
	await physics_frames(20)  # let the second attack finish
	Input.action_press(&"p1_attack")
	await physics_frames(60)
	Input.action_release(&"p1_attack")
	assert_eq(starts.size(), 3, "holding attack starts only one attack")


# --- Hit rules ---------------------------------------------------------------------------

func test_one_hit_per_target_per_attack() -> void:
	var target := _dummy(Vector2(114, FLOOR), 10)
	await _tap([&"p1_attack"])
	await physics_frames(20)
	assert_eq(target.hits_taken(), 1, "inside the hitbox for 6 frames, hit once")
	assert_eq(target.health.current_health, 9, "1 damage (attack power 1)")
	await physics_frames(5)
	await _tap([&"p1_attack"])
	await physics_frames(20)
	assert_eq(target.hits_taken(), 2, "a new attack can hit again")
	assert_false(target.damage_log[0].attack_id == target.damage_log[1].attack_id, "different attack ids")


func test_one_swing_hits_several_targets() -> void:
	var a := _dummy(Vector2(108, FLOOR))
	var b := _dummy(Vector2(116, FLOOR))
	await _tap([&"p1_attack"])
	await physics_frames(12)
	assert_eq(a.hits_taken(), 1, "first target hit")
	assert_eq(b.hits_taken(), 1, "second target hit by the same swing")
	assert_eq(a.damage_log[0].attack_id, b.damage_log[0].attack_id, "same attack id")


func test_attack_power_sets_damage() -> void:
	var target := _dummy(Vector2(114, FLOOR), 10)
	k1.combat.stats.attack_power = 2
	await _tap([&"p1_attack"])
	await physics_frames(12)
	assert_eq(target.health.current_health, 8, "power 2 removes 2")
	assert_eq(target.damage_log[0].amount, 2, "event carries the attack power")


func test_range_edge() -> void:
	var inside := _dummy(Vector2(122, FLOOR))  # hurtbox x 117..127 overlaps the reach end (x 118)
	await _tap([&"p1_attack"])
	await physics_frames(25)
	assert_eq(inside.hits_taken(), 1, "target overlapping the reach end is hit")
	inside.queue_free()
	var far := _dummy(Vector2(124, FLOOR))     # hurtbox x 119..129: 1 px beyond the reach
	await physics_frames(2)
	await _tap([&"p1_attack"])
	await physics_frames(25)
	assert_eq(far.hits_taken(), 0, "target 1 px beyond the reach is not hit")
	k1.combat.stats.range_multiplier = 1.3     # future red fruit tier 3
	await _tap([&"p1_attack"])
	await physics_frames(25)
	assert_eq(far.hits_taken(), 1, "with +30 % range the same target is hit")


func test_walls_block_attacks() -> void:
	var target := _dummy(Vector2(114, FLOOR))
	var wall := _wall(Rect2(106, FLOOR - 40, 4, 40))  # between the knight and the target
	await _tap([&"p1_attack"])
	await physics_frames(12)
	assert_eq(target.hits_taken(), 0, "a solid wall between knight and target blocks the hit")
	wall.queue_free()
	await physics_frames(15)
	await _tap([&"p1_attack"])
	await physics_frames(12)
	assert_eq(target.hits_taken(), 1, "the same target is hit once the wall is gone")


func test_low_obstacle_and_corner() -> void:
	# An 8 px step between knight and target: the body-height slash passes over its corner,
	# the low slash at the feet is blocked by it.
	var target := _dummy(Vector2(114, FLOOR))
	_wall(Rect2(106, FLOOR - 8, 4, 8))
	await _tap([&"p1_attack"])
	await physics_frames(12)
	assert_eq(target.hits_taken(), 1, "slash over the top of a low step hits")
	await physics_frames(10)
	await _tap([&"p1_move_down", &"p1_attack"])
	await physics_frames(12)
	assert_eq(k1.combat.animation_name(), "attack_low_right", "low slash")
	assert_eq(target.hits_taken(), 1, "low slash is blocked by the step")


func test_one_way_platform_does_not_block() -> void:
	var target := _dummy(Vector2(100, FLOOR - 20))  # hanging above the knight's head
	_wall(Rect2(90, FLOOR - 21, 20, 2), 2, true)    # one-way platform between head and target
	await _tap([&"p1_move_up", &"p1_attack"])
	await physics_frames(12)
	assert_eq(target.hits_taken(), 1, "up slash through a one-way platform hits")


func test_room_thin_wall_target_is_protected() -> void:
	var target := _dummy(Vector2(690, FLOOR))
	k1.teleport_to(Vector2(675, FLOOR))
	await physics_frames(10)
	Input.action_press(&"p1_move_right")
	await physics_frames(10)  # walk into the room's thin wall
	Input.action_release(&"p1_move_right")
	await physics_frames(5)
	var reach_end := k1.global_position.x + 18.0
	assert_gt(reach_end, target.hurtbox.world_rect().position.x, "the hitbox does overlap the target")
	await _tap([&"p1_attack"])
	await physics_frames(12)
	assert_eq(target.hits_taken(), 0, "the thin wall protects the target")


# --- Health, invulnerability and death -------------------------------------------------

func test_knights_have_independent_health() -> void:
	assert_eq([k1.health.current_health, k1.health.max_health], [3, 3], "P1 3/3")
	assert_eq([k2.health.current_health, k2.health.max_health], [3, 3], "P2 3/3")
	k1.health.take_damage(DamageEvent.create(1, DamageEvent.Category.CONTACT))
	assert_eq(k1.health.current_health, 2, "P1 damaged")
	assert_eq(k2.health.current_health, 3, "P2 unaffected")
	assert_true(k1.health.is_invulnerable() and not k2.health.is_invulnerable(), "only P1 invulnerable")


func test_contact_damage_with_invulnerability_on_knight() -> void:
	var applied := 0
	var saw_blink := false
	var saw_solid := false
	for i in 120:  # 2 s of continuous contact
		applied += k1.health.take_damage(DamageEvent.create(1, DamageEvent.Category.CONTACT))
		await physics_frames(1)
		if k1.health.is_invulnerable():
			if k1.sprite.self_modulate.a < 1.0:
				saw_blink = true
			else:
				saw_solid = true
	assert_eq(applied, 2, "two hits in two seconds (1 s invulnerability)")
	assert_eq(k1.health.current_health, 1, "3 - 2")
	assert_true(saw_blink and saw_solid, "the knight blinks while invulnerable")


func test_death_state() -> void:
	var deaths := [0]
	k1.died.connect(func() -> void: deaths[0] += 1)
	var target := _dummy(Vector2(114, FLOOR))
	await _tap([&"p1_attack"])
	await physics_frames(1)
	assert_eq(k1.combat.state, S.ATTACKING, "attack in progress")
	var id_before_death := k1.combat.attack_id
	k1.health.take_damage(DamageEvent.create(1, DamageEvent.Category.LAVA))
	await physics_frames(1)
	assert_eq(k1.state, Knight.State.DEAD, "DEAD state")
	assert_eq(k1.combat.state, S.IDLE, "the attack was cancelled")
	assert_false(k1.combat.hitbox.active or k1.combat.weapon.visible, "no hitbox or weapon left behind")
	assert_eq(k1.sprite.animation, &"death", "death animation")
	await physics_frames(10)
	assert_eq(target.hits_taken(), 0, "the cancelled attack never hit")
	var x := k1.global_position.x
	await _tap([&"p1_attack"])
	Input.action_press(&"p1_move_right")
	Input.action_press(&"p1_move_up")
	await physics_frames(30)
	_release_all()
	assert_eq(k1.combat.state, S.IDLE, "dead knight cannot attack")
	assert_eq(k1.combat.attack_id, id_before_death, "no new attack started while dead")
	assert_eq(k1.global_position.x, x, "dead knight cannot move")
	assert_eq(k1.state, Knight.State.DEAD, "still dead")
	assert_eq(k1.health.heal(3), 0, "healing does not revive")
	assert_eq(k1.health.take_damage(DamageEvent.create(1, DamageEvent.Category.CONTACT)), 0, "no further damage")
	assert_eq(deaths[0], 1, "died emitted exactly once")
	k1.revive()
	await physics_frames(5)
	assert_eq(k1.health.current_health, 3, "revived at full health")
	await _tap([&"p1_attack"])
	assert_eq(k1.combat.state, S.ATTACKING, "can attack again after an explicit revive")


func test_dead_knight_while_climbing() -> void:
	k1.teleport_to(Vector2(552, FLOOR))
	await physics_frames(5)
	Input.action_press(&"p1_move_up")
	await physics_frames(20)
	Input.action_release(&"p1_move_up")
	assert_eq(k1.state, Knight.State.CLIMBING, "climbing")
	k1.health.take_damage(DamageEvent.create(1, DamageEvent.Category.LAVA))
	await physics_frames(60)
	assert_eq(k1.state, Knight.State.DEAD, "dead")
	assert_near(k1.global_position.y, FLOOR, 0.5, "falls off the ladder to the floor")


# --- Integration with movement and camera ---------------------------------------------

func test_attack_while_running() -> void:
	var target := _dummy(Vector2(155, FLOOR))  # ahead of where the running knight swings
	Input.action_press(&"p1_move_right")
	await physics_frames(18)  # running toward the target
	await _tap([&"p1_attack"])
	Input.action_press(&"p1_move_right")
	await physics_frames(12)
	_release_all()
	assert_eq(target.hits_taken(), 1, "the hitbox follows the running knight")


func test_attacks_during_camera_transitions() -> void:
	var t1 := _dummy(Vector2(114, FLOOR), 20)
	var hits_per_attack := []
	for i in 6:
		# Force a split, then a merge, while P1 attacks.
		k2.teleport_to(Vector2(1000, FLOOR) if i % 2 == 0 else Vector2(160, FLOOR))
		await _tap([&"p1_attack"])
		await physics_frames(45)  # long enough for a merge (hold 0.25 s + alignment 0.3 s)
		hits_per_attack.append(t1.hits_taken())
		assert_eq(k1.combat.state, S.IDLE, "attack %d completed normally" % i)
		if i % 2 == 0:
			assert_true(rig.is_split(), "camera split during attack %d" % i)
		else:
			assert_false(rig.is_split(), "camera merged during attack %d" % i)
	assert_eq(hits_per_attack, [1, 2, 3, 4, 5, 6], "every attack hit exactly once despite camera changes")
	assert_gt(rig.layout_change_count, 2, "the camera really changed modes")


func test_combat_never_changes_camera_state() -> void:
	_dummy(Vector2(114, FLOOR), 20)
	await physics_frames(30)
	var mode := rig.mode
	var centre := rig.camera_center(SplitScreenRig.VIEW_A)
	var changes := rig.layout_change_count
	for i in 4:
		await _tap([&"p1_attack"])
		await physics_frames(20)
	assert_eq(rig.mode, mode, "camera mode unchanged")
	assert_eq(rig.layout_change_count, changes, "no layout change caused by attacks")
	assert_true(rig.camera_center(SplitScreenRig.VIEW_A).distance_to(centre) < 0.001, "camera did not move")


func test_no_nodes_created_per_attack() -> void:
	_dummy(Vector2(114, FLOOR), 50)
	await physics_frames(5)
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	for i in 10:
		await _tap([&"p1_attack", &"p2_attack"])
		await physics_frames(20)
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes, "attacks reuse the same hitbox and weapon nodes")
