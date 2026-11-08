extends GameTestCase
## Overhaul combat in the real combat test room (floor y=448): the charged heavy slash, the
## co-op strike, the pogo bounce, the hit pause and the soldier attack poses. Everything goes
## through real input actions.

const ROOM := "res://scenes/dev/combat_test_room.tscn"
const DUMMY := "res://scenes/objects/training_dummy.tscn"
const FLOOR := 448.0
const ALL_ACTIONS := [&"p1_move_left", &"p1_move_right", &"p1_move_up", &"p1_move_down", &"p1_attack",
	&"p2_move_left", &"p2_move_right", &"p2_move_up", &"p2_move_down", &"p2_attack"]

var room: Node
var level: Node2D
var k1: Knight
var k2: Knight


func before_each() -> void:
	TrainingDummy.console_log = false
	_release_all()
	room = (load(ROOM) as PackedScene).instantiate()
	add_child(room)
	level = room.get("level")
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


func _dummy(at: Vector2, hp := 9) -> TrainingDummy:
	var dummy: TrainingDummy = (load(DUMMY) as PackedScene).instantiate()
	dummy.max_health = hp
	dummy.position = at
	level.add_child(dummy)
	return dummy


func _hits(dummy: TrainingDummy) -> Array:
	var log := []
	dummy.hit.connect(func(e: DamageEvent, _applied: int) -> void: log.append(e))
	return log


func test_holding_attack_charges_a_heavy_slash() -> void:
	var dummy := _dummy(Vector2(114, FLOOR))
	var log := _hits(dummy)
	var cfg := k1.combat.config
	Input.action_press(&"p1_attack")
	await physics_frames(8)
	assert_eq(log.size(), 1, "the press itself is an ordinary slash")
	assert_false(log[0].heavy, "first hit is light")
	assert_false(k1.combat.charge_is_ready, "not charged yet")
	await physics_frames(int(cfg.charge_time * 60.0) - 4)
	assert_true(k1.combat.charge_is_ready, "charged after holding charge_time")
	Input.action_release(&"p1_attack")
	await physics_frames(int((cfg.heavy_windup_time + cfg.heavy_active_time) * 60.0) + 3)
	assert_eq(log.size(), 2, "releasing strikes again")
	assert_true(log[1].heavy, "the second hit is heavy")
	assert_eq(log[1].amount, 1 + cfg.heavy_power_bonus, "heavy power = base + bonus")
	assert_false(k1.combat.charge_is_ready, "charge consumed")


func test_releasing_early_does_not_strike() -> void:
	var dummy := _dummy(Vector2(114, FLOOR))
	var log := _hits(dummy)
	Input.action_press(&"p1_attack")
	await physics_frames(15)
	Input.action_release(&"p1_attack")
	await physics_frames(40)
	assert_eq(log.size(), 1, "only the press hit")
	assert_false(k1.combat.heavy, "no heavy slash")


func test_heavy_slash_reaches_further() -> void:
	# A light slash reaches 18 px past the feet; 21 px is out of reach for it, in reach for heavy.
	var dummy := _dummy(Vector2(100 + 26, FLOOR))
	var log := _hits(dummy)
	Input.action_press(&"p1_attack")
	await physics_frames(int(k1.combat.config.charge_time * 60.0) + 4)
	assert_eq(log.size(), 0, "light slash misses at this distance")
	k1.velocity = Vector2.ZERO
	Input.action_release(&"p1_attack")
	await physics_frames(20)
	assert_eq(log.size(), 1, "heavy slash connects")


func test_coop_strike_bonus() -> void:
	var dummy := _dummy(Vector2(120, FLOOR))
	var log := _hits(dummy)
	k2.teleport_to(Vector2(140, FLOOR))
	k2.facing = -1
	await physics_frames(5)
	Input.action_press(&"p1_attack")
	await physics_frames(1)
	Input.action_release(&"p1_attack")
	await physics_frames(6)
	Input.action_press(&"p2_attack")
	await physics_frames(1)
	Input.action_release(&"p2_attack")
	await physics_frames(10)
	assert_eq(log.size(), 2, "both knights hit")
	assert_false(log[0].coop, "the first hit is ordinary")
	assert_true(log[1].coop, "the second knight's hit inside the window is a co-op strike")
	assert_eq(log[1].amount, 1 + k2.combat.config.coop_bonus, "co-op bonus applied")


func test_same_knight_twice_is_not_coop_and_window_expires() -> void:
	var dummy := _dummy(Vector2(120, FLOOR))
	var log := _hits(dummy)
	for i in 2:
		Input.action_press(&"p1_attack")
		await physics_frames(1)
		Input.action_release(&"p1_attack")
		await physics_frames(25)
	assert_false(log[1].coop, "one knight hitting twice is not co-op")
	k2.teleport_to(Vector2(140, FLOOR))
	k2.facing = -1
	await physics_frames(int(k1.combat.config.coop_window * 60.0) + 10)
	Input.action_press(&"p2_attack")
	await physics_frames(1)
	Input.action_release(&"p2_attack")
	await physics_frames(10)
	assert_eq(log.size(), 3, "partner hit")
	assert_false(log[2].coop, "after the window it is an ordinary hit")


func test_pogo_bounces_off_a_target_below() -> void:
	var dummy := _dummy(Vector2(100, FLOOR))
	k1.teleport_to(Vector2(100, FLOOR - 60))
	await physics_frames(12)
	assert_eq(k1.state, Knight.State.AIRBORNE, "falling onto the target")
	Input.action_press(&"p1_move_down")
	Input.action_press(&"p1_attack")
	await physics_frames(1)
	Input.action_release(&"p1_attack")
	var bounced := false
	for i in 30:
		await physics_frames(1)
		if k1.velocity.y < -200.0:
			bounced = true
			break
	Input.action_release(&"p1_move_down")
	assert_true(bounced, "a downward air hit launches the knight upward")
	assert_gt(dummy.hits_taken(), 0, "the target was hit")


func test_hit_pause_freezes_only_the_attacker() -> void:
	_dummy(Vector2(114, FLOOR))
	Input.action_press(&"p2_move_left")
	await physics_frames(3)
	var x2 := k2.global_position.x
	Input.action_press(&"p1_attack")
	await physics_frames(1)
	Input.action_release(&"p1_attack")
	await physics_frames(5)
	assert_lt(k2.global_position.x, x2 - 2.0, "the other knight keeps moving during the hit pause")
	Input.action_release(&"p2_move_left")


func test_heavy_slash_lunges_forward() -> void:
	Input.action_press(&"p1_attack")
	await physics_frames(int(k1.combat.config.charge_time * 60.0) + 4)
	var x := k1.global_position.x
	Input.action_release(&"p1_attack")
	await physics_frames(8)
	assert_gt(k1.global_position.x, x + 4.0, "a grounded heavy slash steps forward")
