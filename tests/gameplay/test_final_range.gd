extends GameTestCase
## The longer blade (final pass) against every enemy type and boss, with REAL attacks (the
## attack key, the combat timeline, the hitbox query) in the enemy test room (floor y=512).
## For each enemy: a swing from the edge of the new reach hits exactly once, a swing from just
## beyond it misses, and a wall between the two blocks it. Then the balance side: no melee
## enemy can be poked from a place its own strike cannot answer.

const ROOM := "res://scenes/dev/enemy_test_room.tscn"
const FLOOR := 512.0
const ALL_ACTIONS := [&"p1_move_left", &"p1_move_right", &"p1_move_up", &"p1_move_down", &"p1_attack",
	&"p2_move_left", &"p2_move_right", &"p2_move_up", &"p2_move_down", &"p2_attack"]
const E := "res://scenes/enemies/"
const CONFIG: CombatConfig = preload("res://resources/config/combat_config.tres")
## Every enemy scene in the game: name -> [scene, boss stats for the slime bosses].
const TYPES := {
	"green slime": [E + "green_slime.tscn", ""],
	"purple slime": [E + "purple_slime.tscn", ""],
	"orc grunt": [E + "orc_grunt.tscn", ""],
	"orc brute": [E + "orc_brute.tscn", ""],
	"orc shieldbearer": [E + "orc_guard.tscn", ""],
	"hollow archer": [E + "hollow_archer.tscn", ""],
	"cave bat": [E + "cave_bat.tscn", ""],
	"ember slime": [E + "ember_slime.tscn", ""],
	"orc warchief": [E + "boss/orc_warchief.tscn", ""],
	"hollow captain": [E + "boss/hollow_captain.tscn", ""],
	"crowned hollow": [E + "boss/crowned_hollow.tscn", ""],
	"brood mother": [E + "boss/boss_slime.tscn", "res://resources/enemies/boss_brood_mother.tres"],
	"magma heart": [E + "boss/boss_slime.tscn", "res://resources/enemies/boss_magma_heart.tres"],
	"citadel warden": [E + "boss/boss_slime.tscn", "res://resources/enemies/boss_citadel_warden.tres"],
}

var room: Node
var level: Node2D
var k1: Knight
var k2: Knight
var _hits := 0


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


func _tap_attack() -> void:
	Input.action_press(&"p1_attack")
	await physics_frames(1)
	Input.action_release(&"p1_attack")
	await physics_frames(16)


## A frozen enemy (no AI, no movement): only its hurtbox matters here.
func _frozen(kind: String, at: Vector2) -> Node2D:
	var enemy: Node2D = (load(TYPES[kind][0]) as PackedScene).instantiate()
	enemy.position = at
	if TYPES[kind][1] != "":
		enemy.set(&"stats", load(TYPES[kind][1]))
	if "free_on_death" in enemy:
		enemy.free_on_death = false
	level.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.set_process(false)
	return enemy


func _hurtbox(enemy: Node) -> HurtboxComponent:
	for node in enemy.find_children("*", "", true, false):
		if node is HurtboxComponent:
			return node
	return null


func _wall(rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = rect.get_center()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	body.add_child(shape)
	level.add_child(body)
	return body


func test_reach_is_between_1_35_and_1_5_times_the_old_one() -> void:
	# Before the final pass the slash ended 18 px from the knight's centre (offset 4 + reach 14).
	var old_end := 18.0
	for reach: float in [CONFIG.side_reach, CONFIG.vertical_reach, CONFIG.low_reach]:
		var ratio := (4.0 + reach) / old_end
		assert_gt(ratio, 1.3, "reach grew by at least about a third (x%.2f)" % ratio)
		assert_lt(ratio, 1.5001, "and by no more than half (x%.2f)" % ratio)
	assert_eq(CONFIG.side_reach, CONFIG.vertical_reach, "sideways and up/down reach the same distance")
	assert_eq(CONFIG.side_reach, CONFIG.low_reach, "the crouched slash reaches as far as the standing one")


func test_a_real_swing_reaches_every_enemy_type_once_and_no_further() -> void:
	var reach_end := 4.0 + CONFIG.side_reach
	for kind: String in TYPES:
		var enemy := _frozen(kind, Vector2(300, FLOOR))
		await physics_frames(3)
		var box := _hurtbox(enemy)
		assert_not_null(box, "%s has a hurtbox" % kind)
		if box == null:
			continue
		# Bring the hurtbox to slash height whatever the enemy's shape (the bat hangs).
		var rect := box.world_rect()
		enemy.position.y += (FLOOR - 9.0) - clampf(FLOOR - 9.0, rect.position.y + 1.0, rect.end.y - 1.0)
		await physics_frames(2)
		rect = box.world_rect()
		_hits = 0
		var count := func(_event: DamageEvent) -> void: _hits += 1
		box.hit_received.connect(count)
		# 1. Just beyond the reach: the far edge of the slash stops 3 px short of the hurtbox.
		k1.teleport_to(Vector2(rect.position.x - reach_end - 3.0, FLOOR))
		await physics_frames(3)
		await _tap_attack()
		assert_eq(_hits, 0, "%s: a swing from 3 px beyond the reach misses" % kind)
		# 2. A wall between them, with the enemy inside the reach.
		k1.teleport_to(Vector2(rect.position.x - reach_end + 3.0, FLOOR))
		var wall := _wall(Rect2(rect.position.x - 5.0, FLOOR - 48.0, 3.0, 48.0))
		await physics_frames(3)
		await _tap_attack()
		assert_eq(_hits, 0, "%s: a wall between knight and enemy blocks the longer blade" % kind)
		wall.free()
		await physics_frames(2)
		# 3. The edge of the new reach (beyond the old 18 px): one hit, and only one.
		assert_gt(rect.position.x - k1.global_position.x, 18.0, "%s stands beyond the OLD reach" % kind)
		await _tap_attack()
		assert_eq(_hits, 1, "%s: a swing from the edge of the new reach hits exactly once" % kind)
		box.hit_received.disconnect(count)
		enemy.free()
		k1.teleport_to(Vector2(1400, FLOOR))
		await physics_frames(20)  # the attack cooldown


func test_up_and_down_swings_reach_as_far_as_side_swings() -> void:
	# A grunt frozen above the knight, then below it (the knight in the air).
	var reach_end := 4.0 + CONFIG.vertical_reach
	var enemy := _frozen("orc grunt", Vector2(300, FLOOR - 60.0))
	await physics_frames(3)
	var box := _hurtbox(enemy)
	var body_top := FLOOR - 22.0  # the standing knight's head
	enemy.position.y += (body_top - reach_end + 2.0) - box.world_rect().end.y
	k1.teleport_to(Vector2(300, FLOOR))
	await physics_frames(3)
	_hits = 0
	box.hit_received.connect(func(_event: DamageEvent) -> void: _hits += 1)
	Input.action_press(&"p1_move_up")
	await physics_frames(2)
	await _tap_attack()
	Input.action_release(&"p1_move_up")
	assert_eq(_hits, 1, "an up-swing reaches a target whose feet are 2 px inside the vertical reach")


func test_no_melee_enemy_can_be_poked_from_outside_its_own_strike() -> void:
	# The furthest a standing knight can hit an enemy from: reach end + half the enemy's
	# hurtbox. The enemy's strike must cover that distance (its rect end + half the knight's
	# hurtbox), or the longer blade would make it harmless.
	var knight_half := k1.hurtbox.world_rect().size.x * 0.5
	for kind: String in ["orc grunt", "orc shieldbearer", "orc brute", "orc warchief", "hollow captain", "crowned hollow"]:
		var enemy := _frozen(kind, Vector2(300, FLOOR)) as Enemy
		await physics_frames(2)
		var half := _hurtbox(enemy).world_rect().size.x * 0.5
		var poke := 4.0 + CONFIG.side_reach + half
		var answer := enemy.stats.attack_rect.end.x + knight_half
		assert_gt(answer, poke - 0.01, "%s: its strike (%.0f px) covers the knight's longest poke (%.0f px)" % [kind, answer, poke])
		assert_gt(enemy.stats.windup_time, 0.19, "%s keeps a readable wind-up" % kind)
		enemy.free()


func test_a_grunt_answers_a_knight_standing_at_full_reach() -> void:
	var grunt := (load(TYPES["orc grunt"][0]) as PackedScene).instantiate() as Enemy
	grunt.position = Vector2(300, FLOOR)
	grunt.patrol_left = -48.0
	grunt.patrol_right = 48.0
	grunt.free_on_death = false
	level.add_child(grunt)
	await physics_frames(5)
	var half := _hurtbox(grunt).world_rect().size.x * 0.5
	k1.teleport_to(Vector2(300.0 + 4.0 + CONFIG.side_reach + half - 1.0, FLOOR))
	var hp := k1.health.current_health
	for f in 240:
		if k1.health.current_health < hp:
			break
		await physics_frames(1)
	assert_eq(k1.health.current_health, hp - 1, "a knight who stands at the edge of its reach is hit by the grunt")
