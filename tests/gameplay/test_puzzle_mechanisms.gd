extends GameTestCase
## Puzzle components on their own, in the real puzzle room with its puzzles removed. Each
## test builds what it needs from the reusable scenes at x 100-300 (floor y = 512, open
## floor in section 1) and drives it with real knights: standing, walking and attacking
## through CombatComponent. Knights start at x 40 and 72.

const ROOM := "res://scenes/dev/puzzle_test_room.tscn"
const PLATE := "res://scenes/puzzles/pressure_plate.tscn"
const SWITCH := "res://scenes/puzzles/attack_switch.tscn"
const TARGET := "res://scenes/puzzles/puzzle_target.tscn"
const LOGIC := "res://scenes/puzzles/puzzle_logic.tscn"
const GATE := "res://scenes/puzzles/puzzle_gate.tscn"
const GREEN := "res://scenes/enemies/green_slime.tscn"
const FLOOR := 512.0
const SW_Y := 490.0
const ALL_ACTIONS := [&"p1_move_left", &"p1_move_right", &"p1_move_up", &"p1_move_down", &"p1_attack",
	&"p2_move_left", &"p2_move_right", &"p2_move_up", &"p2_move_down", &"p2_attack"]
const LS := PuzzleLogic.State
const GS := PuzzleGate.State

var room: Node
var level: Node2D
var puzzles: Node2D
var rig: SplitScreenRig
var k1: Knight
var k2: Knight


func before_each() -> void:
	_release_all()
	room = (load(ROOM) as PackedScene).instantiate()
	add_child(room)
	level = room.get("level")
	rig = room.get("rig")
	k1 = room.get("knight_1")
	k2 = room.get("knight_2")
	puzzles = level.get_node("Puzzles")
	for node in puzzles.get_children():
		node.free()
	await physics_frames(5)


func after_each() -> void:
	_release_all()
	get_tree().paused = false
	room.queue_free()
	await physics_frames(2)


func _release_all() -> void:
	for a in ALL_ACTIONS:
		Input.action_release(a)


func _spawn(path: String, at: Vector2, props := {}) -> Node2D:
	var node: Node2D = (load(path) as PackedScene).instantiate()
	node.position = at
	for key: String in props:
		node.set(key, props[key])
	puzzles.add_child(node)
	return node


func _logic(inputs: Array, mode: PuzzleLogic.Mode, props := {}) -> PuzzleLogic:
	var paths: Array[NodePath] = []
	for node: Node in inputs:
		paths.append(node.get_path())
	props["inputs"] = paths
	props["mode"] = mode
	return _spawn(LOGIC, Vector2(250, 420), props) as PuzzleLogic


func _gate(controller: Node, mode: PuzzleGate.Mode, at_x := 240.0, props := {}) -> PuzzleGate:
	props["controller"] = controller.get_path()
	props["mode"] = mode
	return _spawn(GATE, Vector2(at_x, 464), props) as PuzzleGate


func _stand(knight: Knight, x: float, frames := 6) -> void:
	await _stand_at(knight, Vector2(x, FLOOR), frames)


func _stand_at(knight: Knight, at: Vector2, frames := 6) -> void:
	knight.teleport_to(at)
	await physics_frames(frames)


## Attacks with `knight` facing `side` (1 right, -1 left) and waits for the swing to finish.
func _attack(knight: Knight, side: int) -> void:
	knight.facing = side
	var action := &"p1_attack" if knight.player_id() == 1 else &"p2_attack"
	Input.action_press(action)
	await physics_frames(1)
	Input.action_release(action)
	await physics_frames(24)


## Puts the knight next to `target` on the chosen side and strikes it.
func _strike(knight: Knight, target: Node2D, side := 1) -> void:
	var x := target.position.x - 10.0 if side == 1 else target.position.x + 26.0
	await _stand(knight, x, 4)
	await _attack(knight, side)


func _wall(rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.position = rect.get_center()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	body.add_child(shape)
	level.add_child(body)
	return body


# --- Pressure plates --------------------------------------------------------------------

func test_single_plate_detects_the_knight_and_releases() -> void:
	var plate := _spawn(PLATE, Vector2(150, FLOOR), {"puzzle_id": "p"}) as PressurePlate
	await physics_frames(2)
	assert_false(plate.is_active(), "starts released")
	await _stand(k1, 166)
	assert_true(plate.is_active(), "P1 standing presses it")
	assert_eq(plate.active_players(), [1] as Array[int], "credited to Player One")
	await _stand(k1, 100)
	assert_false(plate.is_active(), "released when P1 leaves")
	assert_eq(plate.press_count, 1, "one press")


func test_two_plates_need_two_different_knights() -> void:
	var a := _spawn(PLATE, Vector2(120, FLOOR)) as PressurePlate
	var b := _spawn(PLATE, Vector2(200, FLOOR)) as PressurePlate
	var lock := _logic([a, b], PuzzleLogic.Mode.ALL, {"distinct_players": true})
	await _stand(k1, 136)
	assert_eq(lock.state, LS.PARTIAL, "one plate: partial")
	k2.teleport_to(Vector2(216, FLOOR))
	await physics_frames(6)
	assert_eq(lock.state, LS.ACTIVE, "both plates, both knights: active")
	await _stand(k2, 300)
	assert_eq(lock.state, LS.PARTIAL, "back to partial when one leaves")


func test_one_knight_cannot_satisfy_two_plates() -> void:
	var a := _spawn(PLATE, Vector2(184, FLOOR), {"width": 16.0}) as PressurePlate
	var b := _spawn(PLATE, Vector2(200, FLOOR), {"width": 16.0}) as PressurePlate
	var lock := _logic([a, b], PuzzleLogic.Mode.ALL, {"distinct_players": true, "latch": true})
	await _stand(k1, 199)  # straddles both plates
	assert_true(a.is_active() and b.is_active(), "both plates pressed by one knight")
	assert_eq(lock.state, LS.PARTIAL, "still not satisfied: one knight")
	assert_eq(lock.completions, 0, "not completed")
	k2.teleport_to(Vector2(212, FLOOR))
	await physics_frames(6)
	assert_eq(lock.state, LS.COMPLETED, "second knight completes it")


func test_both_knights_arriving_on_the_same_frame() -> void:
	var a := _spawn(PLATE, Vector2(120, FLOOR)) as PressurePlate
	var b := _spawn(PLATE, Vector2(200, FLOOR)) as PressurePlate
	var lock := _logic([a, b], PuzzleLogic.Mode.ALL, {"distinct_players": true, "latch": true})
	var done := [0]
	lock.completed.connect(func() -> void: done[0] += 1)
	k1.teleport_to(Vector2(136, FLOOR))
	k2.teleport_to(Vector2(216, FLOOR))
	await physics_frames(8)
	assert_eq(lock.state, LS.COMPLETED, "completed")
	assert_eq(done[0], 1, "completed exactly once")


func test_two_knight_plate_needs_both_on_it() -> void:
	var plate := _spawn(PLATE, Vector2(160, FLOOR), {"width": 48.0, "required_count": 2}) as PressurePlate
	await _stand(k1, 170)
	assert_false(plate.is_active(), "one knight is not enough")
	k2.teleport_to(Vector2(196, FLOOR))
	await physics_frames(6)
	assert_true(plate.is_active(), "both knights press it")
	assert_eq(plate.active_players(), [1, 2] as Array[int], "both credited")


func test_player_specific_plate() -> void:
	var plate := _spawn(PLATE, Vector2(150, FLOOR), {"allowed_player": 2}) as PressurePlate
	await _stand(k1, 166)
	assert_false(plate.is_active(), "Player One is ignored")
	await _stand(k1, 100)
	await _stand(k2, 166)
	assert_true(plate.is_active(), "Player Two presses it")


func test_timed_plate_runs_out_even_while_standing() -> void:
	var plate := _spawn(PLATE, Vector2(150, FLOOR), {"mode": PressurePlate.Mode.TIMED, "active_time": 1.0}) as PressurePlate
	await _stand(k1, 166)
	assert_true(plate.is_active(), "stepping on starts it")
	await physics_frames(62)
	assert_false(plate.is_active(), "ends after 1 s")
	await _stand(k1, 100)
	await _stand(k1, 166)
	assert_true(plate.is_active(), "stepping on again restarts it")
	assert_eq(plate.press_count, 2, "two presses")


func test_dead_knight_releases_the_plate() -> void:
	var plate := _spawn(PLATE, Vector2(150, FLOOR)) as PressurePlate
	await _stand(k1, 166)
	assert_true(plate.is_active(), "held")
	k1.health.apply_damage(99)
	await physics_frames(2)
	assert_true(k1.is_dead(), "dead")
	assert_false(plate.is_active(), "a dead knight does not hold a plate")


func test_removed_knight_releases_the_plate() -> void:
	var plate := _spawn(PLATE, Vector2(150, FLOOR)) as PressurePlate
	await _stand(k2, 166)
	assert_true(plate.is_active(), "held by P2")
	rig.set_targets(k1, k1)
	k2.queue_free()
	await physics_frames(3)
	assert_false(plate.is_active(), "released when the knight is removed")
	assert_eq(plate.tracked_count(), 0, "no stale reference kept")


func test_slimes_never_press_plates_unless_allowed() -> void:
	var plate := _spawn(PLATE, Vector2(150, FLOOR), {"width": 48.0}) as PressurePlate
	var heavy := _spawn(PLATE, Vector2(230, FLOOR), {"width": 48.0, "accept_slimes": true}) as PressurePlate
	var s1 := _spawn(GREEN, Vector2(174, FLOOR), {"patrol_left": 0.0, "patrol_right": 0.0}) as Slime
	var s2 := _spawn(GREEN, Vector2(254, FLOOR), {"patrol_left": 0.0, "patrol_right": 0.0, "free_on_death": false}) as Slime
	await physics_frames(20)
	assert_false(plate.is_active(), "an ordinary plate ignores slimes")
	assert_true(heavy.is_active(), "a slime plate counts a living slime")
	assert_eq(heavy.active_players(), [] as Array[int], "no knight is credited")
	s2.add_stagger_progress(5)
	await physics_frames(3)
	assert_true(s2.is_staggered(), "staggered")
	assert_false(heavy.is_active(), "a staggered slime does not hold it")
	s1.free()


# --- Attack switches --------------------------------------------------------------------

func test_attack_activates_a_switch() -> void:
	var sw := _spawn(SWITCH, Vector2(200, SW_Y), {"puzzle_id": "sw"}) as AttackSwitch
	await _strike(k1, sw)
	assert_true(sw.is_active(), "struck on")
	assert_eq(sw.last_player, 1, "credited to Player One")
	assert_eq(sw.activations, 1, "one activation for one swing")
	assert_eq(k1.combat.hit_log.size(), 1, "the normal melee hit landed once")


func test_attack_out_of_range_does_nothing() -> void:
	var sw := _spawn(SWITCH, Vector2(200, SW_Y)) as AttackSwitch
	await _stand(k1, 170)
	await _attack(k1, 1)
	assert_false(sw.is_active(), "too far away")


func test_wall_blocks_the_attack() -> void:
	var sw := _spawn(SWITCH, Vector2(200, SW_Y)) as AttackSwitch
	_wall(Rect2(196, 440, 3, 72))
	await _stand(k1, 190)
	await _attack(k1, 1)
	assert_false(sw.is_active(), "no activation through a wall")
	assert_eq(k1.combat.hit_log.size(), 0, "no hit at all")


func test_non_attackable_switch_ignores_attacks() -> void:
	var sw := _spawn(SWITCH, Vector2(200, SW_Y), {"attackable": false}) as AttackSwitch
	await _strike(k1, sw)
	assert_false(sw.is_active(), "ignored")
	assert_eq(sw.activations, 0, "no activation")


func test_toggle_is_stable_and_respects_cooldown() -> void:
	var sw := _spawn(SWITCH, Vector2(200, SW_Y)) as AttackSwitch
	sw.activate(1)
	assert_true(sw.is_active(), "on")
	await _strike(k2, sw, -1)  # lands inside the 0.35 s switch cooldown
	assert_true(sw.is_active(), "a hit during the cooldown is ignored")
	assert_eq(sw.activations, 1, "still one activation")
	await physics_frames(10)
	await _strike(k2, sw, -1)
	assert_false(sw.is_active(), "a later accepted hit toggles it off")
	assert_eq(sw.activations, 2, "two activations, no extra ones")
	# Two knights striking it in the same frame toggle it once.
	k1.teleport_to(Vector2(190, FLOOR))
	k2.teleport_to(Vector2(226, FLOOR))
	await physics_frames(25)
	k1.facing = 1
	k2.facing = -1
	Input.action_press(&"p1_attack")
	Input.action_press(&"p2_attack")
	await physics_frames(1)
	_release_all()
	await physics_frames(24)
	assert_eq(sw.activations, 3, "one activation for two simultaneous hits")
	assert_true(sw.is_active(), "on again")


func test_momentary_switch_turns_itself_off() -> void:
	var sw := _spawn(SWITCH, Vector2(200, SW_Y), {"mode": AttackSwitch.Mode.MOMENTARY, "active_time": 1.0}) as AttackSwitch
	await _strike(k1, sw)
	assert_true(sw.is_active(), "lit")
	await physics_frames(60)
	assert_false(sw.is_active(), "off after its time")


func test_direction_and_player_filters() -> void:
	var only_left := _spawn(SWITCH, Vector2(200, SW_Y), {"accept_directions": AttackSwitch.DIR_LEFT}) as AttackSwitch
	await _strike(k1, only_left, 1)  # a rightward swing
	assert_false(only_left.is_active(), "rightward swing ignored")
	await _strike(k1, only_left, -1)  # from the right side, swinging left
	assert_true(only_left.is_active(), "leftward swing accepted")
	var p2_only := _spawn(SWITCH, Vector2(120, SW_Y), {"allowed_player": 2}) as AttackSwitch
	await _strike(k1, p2_only)
	assert_false(p2_only.is_active(), "Player One cannot use Player Two's switch")
	await _strike(k2, p2_only)
	assert_true(p2_only.is_active(), "Player Two can")


func test_enemies_cannot_activate_switches() -> void:
	var sw := _spawn(SWITCH, Vector2(200, SW_Y)) as AttackSwitch
	_spawn(GREEN, Vector2(208, FLOOR), {"patrol_left": -20.0, "patrol_right": 20.0})
	await physics_frames(120)
	assert_eq(sw.activations, 0, "a slime touching it does nothing")


# --- Synchronised targets ---------------------------------------------------------------

func _sync_pair(window := 2.0) -> Array:
	var left := _spawn(TARGET, Vector2(120, SW_Y), {"active_time": window}) as AttackSwitch
	var right := _spawn(TARGET, Vector2(260, SW_Y), {"active_time": window}) as AttackSwitch
	var lock := _logic([left, right], PuzzleLogic.Mode.SYNC, {"distinct_players": true, "latch": true, "window": window})
	return [left, right, lock]


func test_targets_struck_within_the_window_complete() -> void:
	var pair := _sync_pair()
	await _stand(k2, 300)
	await _strike(k1, pair[0], 1)
	assert_eq(pair[2].state, LS.PARTIAL, "first strike starts the window")
	await _strike(k2, pair[1], -1)  # from the right, swinging left
	assert_eq(pair[2].state, LS.COMPLETED, "second strike in time completes it")
	assert_eq(pair[2].completions, 1, "once")


func test_late_second_strike_fails_and_resets() -> void:
	var pair := _sync_pair(1.0)
	await _strike(k1, pair[0], 1)
	await physics_frames(70)  # the window runs out
	assert_eq(pair[2].failures, 1, "failed once")
	assert_false(pair[0].is_active(), "the lit target was reset")
	await _strike(k2, pair[1], -1)
	assert_ne_state(pair[2], LS.COMPLETED, "a late strike alone does not complete it")
	await physics_frames(60)
	# A clean attempt still works afterwards.
	await _strike(k1, pair[0], 1)
	await _strike(k2, pair[1], -1)
	assert_eq(pair[2].state, LS.COMPLETED, "recovers: a correct attempt completes")


func test_same_knight_cannot_strike_both_targets() -> void:
	var pair := _sync_pair(3.0)
	await _strike(k1, pair[0], 1)
	await _strike(k1, pair[1], -1)
	assert_eq(pair[2].state, LS.PARTIAL, "one knight on both targets is not enough")
	await _strike(k2, pair[1], 1)
	assert_eq(pair[2].state, LS.COMPLETED, "the other knight completes it in time")


func assert_ne_state(lock: PuzzleLogic, state: PuzzleLogic.State, message: String) -> void:
	assert_true(lock.state != state, "%s (state %s)" % [message, lock.state_name()])


# --- Gates --------------------------------------------------------------------------------

func test_timed_gate_cycle() -> void:
	var sw := _spawn(SWITCH, Vector2(150, SW_Y), {"mode": AttackSwitch.Mode.MOMENTARY, "active_time": 0.5}) as AttackSwitch
	var gate := _gate(sw, PuzzleGate.Mode.TIMED, 260, {"open_time": 2.0, "warning_time": 0.5})
	await physics_frames(3)
	assert_true(gate.is_solid(), "closed gate is solid")
	await _strike(k1, sw)
	assert_true(gate.state == GS.OPEN or gate.state == GS.OPENING, "opened")
	assert_false(gate.is_solid(), "not solid while open")
	assert_true(gate.time_left > 1.5 and gate.time_left <= 2.0, "timer started at 2 s (%.2f)" % gate.time_left)
	var states: Array = []
	gate.state_changed.connect(func(s: PuzzleGate.State) -> void: states.append(s))
	var closed := await _frames_until(func() -> bool: return gate.state == GS.CLOSED, 200)
	assert_true(closed >= 0, "closed once the doorway is clear")
	assert_eq(states, [GS.WARNING, GS.CLOSING, GS.CLOSED], "warning, then closing, then closed")
	assert_true(gate.is_solid(), "solid again")
	await _strike(k1, sw)
	assert_true(gate.is_open(), "can be opened again")
	assert_eq(gate.opens, 2, "two openings")


func test_gate_never_closes_on_a_knight() -> void:
	var sw := _spawn(SWITCH, Vector2(150, SW_Y), {"mode": AttackSwitch.Mode.MOMENTARY}) as AttackSwitch
	var gate := _gate(sw, PuzzleGate.Mode.TIMED, 260, {"open_time": 1.0, "warning_time": 0.5})
	sw.activate(1)
	await physics_frames(5)
	await _stand(k2, 268)  # in the doorway
	var hp := k2.health.current_health
	await physics_frames(120)
	assert_eq(gate.state, GS.WAITING, "waits while occupied")
	assert_false(gate.is_solid(), "never solid around the knight")
	assert_near(k2.global_position.x, 268.0, 0.5, "the knight is not pushed")
	assert_eq(k2.health.current_health, hp, "the knight is not hurt")
	await _stand(k2, 320, 2)
	await physics_frames(30)
	assert_eq(gate.state, GS.CLOSED, "closes once the doorway is clear")


func test_closing_gate_bounces_open_when_entered() -> void:
	var sw := _spawn(SWITCH, Vector2(150, SW_Y), {"mode": AttackSwitch.Mode.MOMENTARY}) as AttackSwitch
	var gate := _gate(sw, PuzzleGate.Mode.TIMED, 260, {"open_time": 0.5, "warning_time": 0.2})
	sw.activate(1)
	var closing := await _frames_until(func() -> bool: return gate.state == GS.CLOSING, 120)
	assert_true(closing >= 0, "started closing")
	k2.teleport_to(Vector2(268, FLOOR))
	await physics_frames(2)
	assert_eq(gate.state, GS.OPENING, "reopens instead of closing")
	assert_gt(gate.blocked_closings, 0.0, "the blocked closing was counted")
	await physics_frames(30)
	assert_eq(gate.state, GS.WAITING, "then waits for the doorway to clear")
	assert_false(gate.is_solid(), "never solid around the knight")


func test_follow_gate_follows_a_held_plate() -> void:
	var plate := _spawn(PLATE, Vector2(150, FLOOR)) as PressurePlate
	var gate := _gate(plate, PuzzleGate.Mode.FOLLOW, 260, {"close_delay": 0.5})
	await _stand(k1, 166, 30)
	assert_eq(gate.state, GS.OPEN, "open while held")
	await _stand(k1, 100, 10)
	assert_eq(gate.state, GS.WARNING, "warning during the close delay")
	await physics_frames(40)
	assert_eq(gate.state, GS.CLOSED, "closed after the delay")


func test_pause_stops_gate_timers() -> void:
	var sw := _spawn(SWITCH, Vector2(150, SW_Y), {"mode": AttackSwitch.Mode.MOMENTARY}) as AttackSwitch
	var gate := _gate(sw, PuzzleGate.Mode.TIMED, 260, {"open_time": 3.0})
	sw.activate(1)
	await physics_frames(30)
	var left := gate.time_left
	get_tree().paused = true
	await physics_frames(120)
	assert_eq(gate.time_left, left, "no time passes while paused")
	get_tree().paused = false
	await physics_frames(30)
	assert_near(gate.time_left, left - 0.5, 0.02, "resumes")


func test_latch_gate_stays_open() -> void:
	var plate := _spawn(PLATE, Vector2(150, FLOOR)) as PressurePlate
	var gate := _gate(plate, PuzzleGate.Mode.LATCH, 260, {"puzzle_id": "latch_gate"})
	await _stand(k1, 166, 30)
	await _stand(k1, 100, 120)
	assert_eq(gate.state, GS.OPEN, "still open after the plate is released")


# --- Locks: sequence, reset ---------------------------------------------------------------

func test_sequence_wrong_order_fails_and_resets() -> void:
	var a := _spawn(SWITCH, Vector2(120, SW_Y)) as AttackSwitch
	var b := _spawn(SWITCH, Vector2(180, SW_Y)) as AttackSwitch
	var c := _spawn(SWITCH, Vector2(240, SW_Y)) as AttackSwitch
	var lock := _logic([a, b, c], PuzzleLogic.Mode.SEQUENCE, {"latch": true})
	a.activate(1)
	c.activate(2)  # wrong: b expected
	assert_eq(lock.state, LS.FAILED, "wrong order fails")
	assert_false(a.is_active() or c.is_active(), "inputs reset")
	await physics_frames(60)
	assert_eq(lock.state, LS.INACTIVE, "back to the start")
	a.activate(1)
	await physics_frames(25)
	b.activate(2)
	await physics_frames(25)
	c.activate(1)
	assert_eq(lock.state, LS.COMPLETED, "correct order completes")


func test_unlatched_sync_lock_resets_after_its_active_time() -> void:
	var left := _spawn(TARGET, Vector2(120, SW_Y)) as AttackSwitch
	var right := _spawn(TARGET, Vector2(260, SW_Y)) as AttackSwitch
	var lock := _logic([left, right], PuzzleLogic.Mode.SYNC, {"active_time": 1.0})
	left.activate(1)
	right.activate(2)
	assert_eq(lock.state, LS.ACTIVE, "active")
	await physics_frames(65)
	assert_eq(lock.state, LS.INACTIVE, "reset after 1 s")
	assert_false(left.is_active() or right.is_active(), "targets reset too")


func _frames_until(condition: Callable, limit: int) -> int:
	for i in limit:
		if condition.call():
			return i
		await physics_frames(1)
	return -1


# --- Platform coordination ----------------------------------------------------------------

func _platform(path: String, at: Vector2, props: Dictionary) -> PlatformBody:
	var node := (load(path) as PackedScene).instantiate() as PlatformBody
	node.position = at
	for key: String in props:
		node.set(key, props[key])
	level.get_node("Platforms").add_child(node)
	return node


func _controller(platform: PlatformBody, source: Node, mode: PlatformController.Mode) -> PlatformController:
	var controller := PlatformController.new()
	controller.platform = platform.get_path()
	controller.controller = source.get_path()
	controller.mode = mode
	puzzles.add_child(controller)
	return controller


func test_switch_drives_the_partners_platform() -> void:
	var sw := _spawn(SWITCH, Vector2(120, SW_Y)) as AttackSwitch
	var lift := _platform("res://scenes/platforms/moving_platform.tscn", Vector2(220, 480),
		{"travel": Vector2(0, -96), "speed": 80.0, "auto_start": false}) as MovingPlatform
	_controller(lift, sw, PlatformController.Mode.EXTEND_WHILE_ACTIVE)
	await _stand_at(k2, Vector2(244, 479), 20)
	assert_eq(lift.progress, 0.0, "waits for the switch")
	await _strike(k1, sw)
	var up := await _frames_until(func() -> bool: return lift.progress >= 1.0, 200)
	assert_true(up >= 0, "P1's switch raises P2's lift")
	assert_near(k2.global_position.y, 480.0 - 96.0, 1.0, "P2 carried up")
	await physics_frames(30)
	await _attack(k1, 1)  # toggle off: the lift comes back down with P2
	var down := await _frames_until(func() -> bool: return lift.progress <= 0.0, 200)
	assert_true(down >= 0, "lowered again")
	assert_near(k2.global_position.y, 480.0, 1.0, "P2 rode it down")


func test_both_knights_on_different_platforms_at_once() -> void:
	var sw := _spawn(SWITCH, Vector2(60, SW_Y)) as AttackSwitch
	var a := _platform("res://scenes/platforms/moving_platform.tscn", Vector2(140, 470),
		{"travel": Vector2(0, -64), "speed": 64.0, "auto_start": false}) as MovingPlatform
	var b := _platform("res://scenes/platforms/moving_platform.tscn", Vector2(220, 470),
		{"travel": Vector2(64, 0), "speed": 64.0, "auto_start": false}) as MovingPlatform
	_controller(a, sw, PlatformController.Mode.RUN_WHILE_ACTIVE)
	_controller(b, sw, PlatformController.Mode.RUN_WHILE_ACTIVE)
	await _stand_at(k1, Vector2(164, 469), 10)
	await _stand_at(k2, Vector2(244, 469), 10)
	sw.activate(1)  # one switch starts both platforms together
	var jitter := [0.0, 0.0]
	for i in 120:
		await physics_frames(1)
		jitter[0] = maxf(jitter[0], absf(k1.global_position.y - a.global_position.y))
		jitter[1] = maxf(jitter[1], absf(k2.global_position.y - b.global_position.y))
	assert_gt(absf(a.position.y - 470.0) + absf(b.position.x - 220.0), 30.0, "both platforms moved")
	assert_lt(jitter[0], 1.5, "P1 rode its platform steadily")
	assert_lt(jitter[1], 1.5, "P2 rode its platform steadily")
	assert_eq(k1.safe_spot.fall_count + k2.safe_spot.fall_count, 0, "nobody fell")


func test_timed_platform_triggered_by_a_plate() -> void:
	var plate := _spawn(PLATE, Vector2(120, FLOOR)) as PressurePlate
	var timed := _platform("res://scenes/platforms/timed_platform.tscn", Vector2(220, 470),
		{"start_active": false, "auto_reactivate": false, "active_time": 1.0, "warning_time": 0.5, "disabled_time": 0.5}) as TimedPlatform
	_controller(timed, plate, PlatformController.Mode.TRIGGER)
	await physics_frames(3)
	assert_eq(timed.state, TimedPlatform.State.INACTIVE, "inactive until triggered")
	await _stand(k1, 136, 40)
	assert_eq(timed.state, TimedPlatform.State.ACTIVE, "the plate brought it in")
	await _stand(k1, 60, 140)
	assert_eq(timed.state, TimedPlatform.State.INACTIVE, "ran one cycle and stopped safely")
