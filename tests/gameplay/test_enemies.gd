extends GameTestCase
## The overhaul enemies in the real enemy test room (floor y=512, open floor x 32..560, the
## room's slimes removed). Knights wait far right (x 1400/1440) unless a test moves them.

const ROOM := "res://scenes/dev/enemy_test_room.tscn"
const FLOOR := 512.0
const ALL_ACTIONS := [&"p1_move_left", &"p1_move_right", &"p1_move_up", &"p1_move_down", &"p1_attack",
	&"p2_move_left", &"p2_move_right", &"p2_move_up", &"p2_move_down", &"p2_attack"]
const E := "res://scenes/enemies/"
const St := Enemy.State

var room: Node
var level: Node2D
var k1: Knight
var k2: Knight
var _attack := 90000


func before_each() -> void:
	for a in ALL_ACTIONS:
		Input.action_release(a)
	room = (load(ROOM) as PackedScene).instantiate()
	add_child(room)
	level = room.get("level")
	k1 = room.get("knight_1")
	k2 = room.get("knight_2")
	for slime in room.get("enemies").get_children():
		slime.queue_free()
	k1.teleport_to(Vector2(1400, FLOOR))
	k2.teleport_to(Vector2(1440, FLOOR))
	await physics_frames(5)


func after_each() -> void:
	for a in ALL_ACTIONS:
		Input.action_release(a)
	room.queue_free()
	await physics_frames(2)


func _spawn(path: String, at: Vector2, left := -48.0, right := 48.0) -> Node2D:
	var enemy: Node2D = (load(path) as PackedScene).instantiate()
	enemy.position = at
	if "patrol_left" in enemy:
		enemy.patrol_left = left
		enemy.patrol_right = right
	if "free_on_death" in enemy:
		enemy.free_on_death = false
	level.add_child(enemy)
	return enemy


func _hit(target: Node2D, from: Knight, dir := Vector2i.RIGHT, power := 1, heavy := false) -> void:
	_attack += 1
	var event := DamageEvent.create(power, DamageEvent.Category.MELEE, from)
	event.attack_id = _attack
	event.attacker_player_id = from.player_id()
	event.direction = dir
	event.heavy = heavy
	(target.get_node("Hurtbox") as HurtboxComponent).receive_hit(event)


func _wait_state(enemy: Enemy, wanted: Enemy.State, max_frames := 300) -> int:
	for f in max_frames:
		if enemy.state == wanted:
			return f
		await physics_frames(1)
	return -1


func test_grunt_telegraphs_then_hits_the_knight_in_front() -> void:
	var grunt := _spawn(E + "orc_grunt.tscn", Vector2(300, FLOOR)) as Enemy
	await physics_frames(5)
	k1.teleport_to(Vector2(322, FLOOR))
	var hp := k1.health.current_health
	var wind := await _wait_state(grunt, St.WINDUP)
	assert_gt(wind, -1, "the grunt notices the knight and winds up")
	assert_eq(k1.health.current_health, hp, "no damage during the wind-up")
	assert_true(grunt.alert_label.visible, "the wind-up shows a warning")
	var frames := await _wait_state(grunt, St.ATTACK)
	assert_gt(frames, int(grunt.stats.windup_time * 60.0) - 3, "the telegraph lasts the configured wind-up")
	await physics_frames(12)
	assert_eq(k1.health.current_health, hp - 1, "the swing hits a knight standing in front")


func test_stepping_back_during_the_windup_dodges() -> void:
	var grunt := _spawn(E + "orc_grunt.tscn", Vector2(300, FLOOR)) as Enemy
	await physics_frames(5)
	k1.teleport_to(Vector2(322, FLOOR))
	assert_gt(await _wait_state(grunt, St.WINDUP), -1, "wind-up starts")
	k1.teleport_to(Vector2(380, FLOOR))
	var hp := k1.health.current_health
	await _wait_state(grunt, St.RECOVER)
	assert_eq(k1.health.current_health, hp, "out of reach when the axe lands")


func test_grunt_chases_at_twice_patrol_speed_and_dies_with_coins() -> void:
	var grunt := _spawn(E + "orc_grunt.tscn", Vector2(200, FLOOR), -200, 200) as Enemy
	assert_eq(grunt.stats.chase_speed(), grunt.stats.patrol_speed * 2.0, "chase = 2x patrol")
	await physics_frames(3)
	for i in grunt.stats.max_health:
		_hit(grunt, k1)
		await physics_frames(2)
	assert_true(grunt.is_dead(), "dies after max_health light hits")
	assert_true(grunt.drop_result.count >= grunt.stats.coin_min and grunt.drop_result.count <= grunt.stats.coin_max, "coin drop in range")


func test_heavy_hit_counts_double_and_breaks_a_windup() -> void:
	var grunt := _spawn(E + "orc_grunt.tscn", Vector2(300, FLOOR)) as Enemy
	await physics_frames(5)
	k1.teleport_to(Vector2(322, FLOOR))
	assert_gt(await _wait_state(grunt, St.WINDUP), -1, "wind-up")
	_hit(grunt, k1, Vector2i.LEFT, 2, true)
	await physics_frames(1)
	assert_eq(grunt.health, grunt.stats.max_health - 2, "heavy power 2")
	assert_eq(grunt.state, St.STUNNED, "a heavy hit interrupts a movable enemy's wind-up")


func test_brute_slam_sends_shockwaves_that_jumping_avoids() -> void:
	var brute := _spawn(E + "orc_brute.tscn", Vector2(300, FLOOR)) as Enemy
	await physics_frames(5)
	k1.teleport_to(Vector2(330, FLOOR))
	assert_gt(await _wait_state(brute, St.ATTACK, 400), -1, "the brute smashes")
	# P2 hangs in the air above the left wave's path (as at the top of a jump).
	k2.teleport_to(Vector2(250, FLOOR - 24))
	k2.set_physics_process(false)
	await physics_frames(1)
	var waves := level.find_children("*", "Node2D", true, false).filter(func(n: Node) -> bool: return n is Shockwave)
	assert_eq(waves.size(), 2, "two shockwaves, one each way")
	await physics_frames(40)
	assert_lt(k1.health.current_health, k1.health.max_health, "the knight on the ground is hit")
	assert_eq(k2.health.current_health, k2.health.max_health, "a knight in the air is not")
	k2.set_physics_process(true)


func test_shieldbearer_blocks_the_front_not_the_back() -> void:
	var guard := _spawn(E + "orc_guard.tscn", Vector2(300, FLOOR)) as OrcGuard
	await physics_frames(3)
	guard.facing = 1
	_hit(guard, k1, Vector2i.LEFT)  # attack travelling left hits its right (front) side
	await physics_frames(1)
	assert_eq(guard.health, guard.stats.max_health, "frontal light hit blocked")
	_hit(guard, k2, Vector2i.RIGHT)  # from behind
	await physics_frames(1)
	assert_eq(guard.health, guard.stats.max_health - 1, "hit from behind lands")
	_hit(guard, k1, Vector2i.DOWN)
	await physics_frames(1)
	assert_eq(guard.health, guard.stats.max_health - 2, "a downward strike from above lands")


func test_heavy_slash_breaks_the_guard() -> void:
	var guard := _spawn(E + "orc_guard.tscn", Vector2(300, FLOOR)) as OrcGuard
	await physics_frames(3)
	guard.facing = 1
	_hit(guard, k1, Vector2i.LEFT, 2, true)
	await physics_frames(1)
	assert_eq(guard.state, St.STUNNED, "guard broken")
	_hit(guard, k1, Vector2i.LEFT)
	await physics_frames(1)
	assert_eq(guard.health, guard.stats.max_health - 1, "open while stunned")


func test_archer_arrow_hits_standing_but_not_crouching_knights() -> void:
	var archer := _spawn(E + "hollow_archer.tscn", Vector2(200, FLOOR), 0, 0) as Enemy
	k1.teleport_to(Vector2(320, FLOOR))
	Input.action_press(&"p1_move_down")
	await physics_frames(5)
	assert_eq(k1.state, Knight.State.CROUCHING, "P1 crouches")
	assert_gt(await _wait_state(archer, St.ATTACK, 400), -1, "the archer looses an arrow")
	var hp := k1.health.current_health
	await physics_frames(60)
	assert_eq(k1.health.current_health, hp, "the arrow flies over a crouching knight")
	Input.action_release(&"p1_move_down")
	assert_gt(await _wait_state(archer, St.ATTACK, 400), -1, "second arrow")
	await physics_frames(60)
	assert_eq(k1.health.current_health, hp - 1, "a standing knight is hit")


func test_arrows_can_be_cut_down() -> void:
	var arrow := (load(E + "projectiles/arrow.tscn") as PackedScene).instantiate() as EnemyArrow
	level.add_child(arrow)
	arrow.launch(Vector2(200, FLOOR - 14), Vector2.RIGHT, 0.0, 400.0, null)
	await physics_frames(1)
	_hit(arrow, k1, Vector2i.LEFT)
	await physics_frames(2)
	assert_false(is_instance_valid(arrow), "a melee hit destroys the arrow")


func test_bat_roosts_swoops_and_returns() -> void:
	var bat := _spawn(E + "cave_bat.tscn", Vector2(300, FLOOR - 80)) as Enemy
	await physics_frames(10)
	assert_eq(bat.state, St.IDLE, "roosting while nobody is near")
	k1.teleport_to(Vector2(330, FLOOR))
	assert_gt(await _wait_state(bat, St.SPECIAL), -1, "swoops at the knight")
	var lowest := bat.global_position.y
	for i in 80:
		await physics_frames(1)
		lowest = maxf(lowest, bat.global_position.y)
	assert_gt(lowest, FLOOR - 30.0, "the swoop comes down to the knight's height")
	assert_gt(await _wait_state(bat, St.IDLE, 400), -1, "flies back to roost")
	assert_lt(bat.global_position.distance_to(Vector2(300, FLOOR - 80)), 4.0, "back home")


func test_ember_slime_fuses_and_explodes() -> void:
	var ember := _spawn(E + "ember_slime.tscn", Vector2(300, FLOOR)) as Enemy
	var green: Slime = (load(E + "green_slime.tscn") as PackedScene).instantiate()
	green.position = Vector2(318, FLOOR)
	green.patrol_left = 0
	green.patrol_right = 0
	green.free_on_death = false
	level.add_child(green)
	k1.teleport_to(Vector2(290, FLOOR))
	await physics_frames(3)
	_hit(ember, k1)
	await physics_frames(1)
	assert_eq(ember.state, St.SPECIAL, "a hit lights the fuse instead of killing")
	var hp := k1.health.current_health
	await physics_frames(int(ember.stats.special_time * 60.0) + 4)
	assert_true(ember.is_dead(), "exploded")
	assert_eq(k1.health.current_health, hp - 1, "the blast hurts a knight in range")
	assert_true(green.is_staggered(), "the blast's 2 points stagger a green slime")


func test_enemy_save_round_trip_and_validation() -> void:
	var grunt := _spawn(E + "orc_grunt.tscn", Vector2(250, FLOOR)) as Enemy
	await physics_frames(3)
	_hit(grunt, k1)
	await physics_frames(1)
	var data := grunt.save_state()
	assert_eq(data.type, "orc_grunt", "type is the scene name")
	assert_true(LevelCatalog.ENTITY_SCENES.has(data.type), "type is whitelisted")
	var copy := _spawn(E + "orc_grunt.tscn", Vector2(100, FLOOR)) as Enemy
	await physics_frames(1)
	assert_true(copy.restore_state(data), "valid state restores")
	assert_eq(copy.health, grunt.health, "health restored")
	var bad := data.duplicate()
	bad.health = 99
	assert_false(copy.restore_state(bad), "health above max is refused")
	for key in ["orc_brute", "orc_guard", "hollow_archer", "cave_bat", "ember_slime", "orc_warchief", "hollow_captain", "crowned_hollow"]:
		assert_true(LevelCatalog.ENTITY_SCENES.has(key), "%s whitelisted" % key)


func test_warchief_phase_two_summons_once_and_reports_to_listeners() -> void:
	var listener := BossListener.new()
	add_child(listener)
	var boss := _spawn(E + "boss/orc_warchief.tscn", Vector2(300, FLOOR), 0, 0) as OrcWarchief
	k1.teleport_to(Vector2(400, FLOOR))
	await physics_frames(30)
	assert_true(boss.engaged, "engages when it sees a knight")
	assert_eq(listener.engaged, 1, "HUD told once")
	for i in boss.stats.max_health / 2:
		_hit(boss, k1)
	await physics_frames(2)
	assert_eq(boss.phase, 2, "phase 2 at half health")
	var grunts := level.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is OrcGrunt)
	assert_eq(grunts.size(), 2, "two grunts summoned")
	_hit(boss, k1)
	await physics_frames(2)
	grunts = level.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is OrcGrunt)
	assert_eq(grunts.size(), 2, "summoned only once")
	boss.kill()
	await physics_frames(2)
	assert_eq(listener.defeated, 1, "HUD told about the defeat")
	assert_gt(listener.last_max, 0, "health reported")
	listener.queue_free()


func test_captain_guard_blocks_from_the_front() -> void:
	var boss := _spawn(E + "boss/hollow_captain.tscn", Vector2(300, FLOOR), 0, 0) as HollowCaptain
	await physics_frames(2)
	boss.facing = 1
	boss._move = &"guard"
	boss._enter(Enemy.State.SPECIAL)
	_hit(boss, k1, Vector2i.LEFT)
	await physics_frames(1)
	assert_eq(boss.health, boss.stats.max_health, "guard blocks the front")
	_hit(boss, k2, Vector2i.RIGHT)
	await physics_frames(1)
	assert_eq(boss.health, boss.stats.max_health - 1, "a partner behind it gets through")


class BossListener extends Node:
	var engaged := 0
	var defeated := 0
	var last_max := 0

	func _ready() -> void:
		add_to_group(BossEnemy.LISTENERS)

	func on_boss_engaged(_boss: Node) -> void:
		engaged += 1

	func on_boss_health(_boss: Node, _current: int, maximum: int) -> void:
		last_max = maximum

	func on_boss_defeated(_boss: Node) -> void:
		defeated += 1
