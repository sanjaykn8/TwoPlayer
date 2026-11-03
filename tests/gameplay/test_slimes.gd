extends GameTestCase
## Slimes in the real enemy test room. The room's own slimes are removed; each test spawns
## what it needs. Geometry (pixels): floor y=512; pillar x 576-608 (y 432-512); solid ledge
## x 704-864 at y=432; one-way platform x 800-944 at y=352; left wall ends at x=16.
## Knights wait at x 1400/1440 (no slimes there) unless a test moves them, and are protected
## from contact damage unless a test turns that off.

const ROOM := "res://scenes/dev/enemy_test_room.tscn"
const GREEN := "res://scenes/enemies/green_slime.tscn"
const PURPLE := "res://scenes/enemies/purple_slime.tscn"
const FLOOR := 512.0
const TICK := 1.0 / 60.0
const ALL_ACTIONS := [&"p1_move_left", &"p1_move_right", &"p1_move_up", &"p1_move_down", &"p1_attack",
	&"p2_move_left", &"p2_move_right", &"p2_move_up", &"p2_move_down", &"p2_attack"]
const St := Slime.State

var room: Node
var level: Node2D
var rig: SplitScreenRig
var k1: Knight
var k2: Knight
var _next_attack := 50000


func before_each() -> void:
	TrainingDummy.console_log = false
	for a in ALL_ACTIONS:
		Input.action_release(a)
	room = (load(ROOM) as PackedScene).instantiate()
	add_child(room)
	level = room.get("level")
	rig = room.get("rig")
	k1 = room.get("knight_1")
	k2 = room.get("knight_2")
	for slime in room.get("enemies").get_children():
		slime.queue_free()
	room.set_protected(true)
	k1.teleport_to(Vector2(1400, FLOOR))
	k2.teleport_to(Vector2(1440, FLOOR))
	await physics_frames(5)


func after_each() -> void:
	for a in ALL_ACTIONS:
		Input.action_release(a)
	room.queue_free()
	await physics_frames(2)


func _slime(scene: String, at: Vector2, left := -48.0, right := 48.0, radius := 0.0, seed := 1234) -> Slime:
	var slime: Slime = (load(scene) as PackedScene).instantiate()
	slime.position = at
	slime.patrol_left = left
	slime.patrol_right = right
	slime.detection_radius_override = radius
	slime.free_on_death = false
	slime.get_node("CoinDropper").rng_seed = seed
	level.add_child(slime)
	return slime


## A melee hit as a knight's CombatComponent would deliver it. Each call is a new attack id
## unless `attack_id` is given.
func _hit(slime: Slime, power := 1, attack_id := -1) -> int:
	if attack_id < 0:
		_next_attack += 1
		attack_id = _next_attack
	var event := DamageEvent.create(power, DamageEvent.Category.MELEE, k1)
	event.attack_id = attack_id
	event.attacker_player_id = 1
	slime.hurtbox.receive_hit(event)
	return attack_id


func _place(k: Knight, at: Vector2) -> void:
	k.teleport_to(at)


func _tap(actions: Array) -> void:
	for a in actions:
		Input.action_press(a)
	await physics_frames(1)
	for a in actions:
		Input.action_release(a)


# --- Patrol ------------------------------------------------------------------------------

func test_patrol_stays_within_bounds() -> void:
	var slime := _slime(GREEN, Vector2(300, FLOOR))
	assert_eq(slime.state, St.IDLE, "starts idle")
	await physics_frames(70)
	assert_eq(slime.state, St.PATROL, "patrols after the idle time")
	var lo := 9999.0
	var hi := -9999.0
	for i in 600:
		await physics_frames(1)
		lo = minf(lo, slime.global_position.x)
		hi = maxf(hi, slime.global_position.x)
	assert_gt(lo, 252.0 - 1.5, "never past the left limit (%.1f)" % lo)
	assert_lt(hi, 348.0 + 1.5, "never past the right limit (%.1f)" % hi)
	assert_lt(lo, 256.0, "reached the left limit")
	assert_gt(hi, 344.0, "reached the right limit")


func test_patrol_turns_at_platform_edges() -> void:
	var slime := _slime(GREEN, Vector2(784, 432), -200.0, 200.0)
	var lo := 9999.0
	var hi := -9999.0
	for i in 900:
		await physics_frames(1)
		lo = minf(lo, slime.global_position.x)
		hi = maxf(hi, slime.global_position.x)
	assert_near(slime.global_position.y, 432.0, 1.0, "never fell off")
	assert_gt(lo, 704.0, "turned at the left edge (%.1f)" % lo)
	assert_lt(hi, 864.0, "turned at the right edge (%.1f)" % hi)
	assert_lt(lo, 716.0, "walked up to the left edge")
	assert_gt(hi, 852.0, "walked up to the right edge")


func test_patrol_turns_at_walls() -> void:
	var slime := _slime(GREEN, Vector2(60, FLOOR), -200.0, 40.0)
	var lo := 9999.0
	for i in 600:
		await physics_frames(1)
		lo = minf(lo, slime.global_position.x)
	assert_gt(lo, 16.0 + 5.0, "stopped before the wall (%.1f)" % lo)
	assert_lt(lo, 30.0, "walked up to the wall")
	assert_eq(slime.state == St.PATROL or slime.state == St.IDLE, true, "still patrolling")


func test_patrol_and_chase_speeds() -> void:
	var slime := _slime(GREEN, Vector2(300, FLOOR), -200.0, 200.0)
	await physics_frames(100)
	assert_eq(slime.state, St.PATROL, "patrolling")
	assert_eq(absf(slime.velocity.x), slime.stats.patrol_speed, "patrol speed exactly %.0f" % slime.stats.patrol_speed)
	k1.set_physics_process(false)
	k1.global_position = Vector2(slime.global_position.x + 90.0, FLOOR)
	for i in 60:
		await physics_frames(1)
		if slime.state == St.CHASE and absf(slime.velocity.x) == slime.stats.chase_speed():
			break
	assert_eq(slime.state, St.CHASE, "chasing")
	assert_eq(absf(slime.velocity.x), slime.stats.chase_speed(), "chase speed reached")
	assert_eq(slime.stats.chase_speed(), 2.0 * slime.stats.patrol_speed, "chase = 2 x patrol")
	var x0 := slime.global_position.x
	await physics_frames(20)
	assert_near(slime.global_position.x - x0, slime.stats.chase_speed() * 20.0 * TICK, 0.5, "moved at chase speed")


# --- Detection and targets ---------------------------------------------------------

func test_detects_visible_player_and_chases() -> void:
	var slime := _slime(GREEN, Vector2(300, FLOOR))
	await physics_frames(10)
	assert_eq(slime.target, null, "nobody in range")
	_place(k1, Vector2(380, FLOOR))
	var seen_detect := false
	for i in 40:
		await physics_frames(1)
		if slime.state == St.DETECT_PLAYER:
			seen_detect = true
		if slime.state == St.CHASE:
			break
	assert_eq(slime.target, k1, "targets P1")
	assert_true(seen_detect, "went through DETECT_PLAYER")
	assert_eq(slime.state, St.CHASE, "then chases")
	assert_true(slime.alert_label.visible, "shows the alert mark")


func test_wall_blocks_detection() -> void:
	var slime := _slime(GREEN, Vector2(640, FLOOR), 0.0, 0.0, 160.0)
	_place(k1, Vector2(550, FLOOR))  # 90 px away, behind the pillar
	await physics_frames(60)
	assert_eq(slime.target, null, "no detection through the pillar")
	assert_false(slime.state == St.CHASE, "not chasing")
	_place(k1, Vector2(700, FLOOR))  # same side, 60 px
	await physics_frames(10)
	assert_eq(slime.target, k1, "detected once in sight")


func test_detects_knight_on_ladder_or_platform_through_one_way() -> void:
	var slime := _slime(GREEN, Vector2(872, FLOOR), 0.0, 0.0, 200.0)
	_place(k1, Vector2(872, 352))  # on the one-way platform above
	await physics_frames(20)
	assert_eq(slime.target, k1, "one-way platforms do not block sight")


func test_nearest_player_selected() -> void:
	var slime := _slime(GREEN, Vector2(300, FLOOR), 0.0, 0.0)
	k1.set_physics_process(false)
	k2.set_physics_process(false)
	k1.global_position = Vector2(380, FLOOR)  # 80 px
	k2.global_position = Vector2(240, FLOOR)  # 60 px
	await physics_frames(10)
	assert_eq(slime.target, k2, "nearer knight chosen")


func test_target_selection_does_not_flicker() -> void:
	# Starts at x=150 so the 4 s chase stays in open floor, clear of the pillar at x=576.
	var slime := _slime(GREEN, Vector2(150, FLOOR), 0.0, 0.0)
	k1.set_physics_process(false)
	k2.set_physics_process(false)
	var changes := [0]
	slime.target_changed.connect(func(_t: Node2D) -> void: changes[0] += 1)
	for i in 240:
		var jitter := 5.0 if (i / 7) % 2 == 0 else -5.0
		k1.global_position = Vector2(slime.global_position.x + 60.0 + jitter, FLOOR)
		k2.global_position = Vector2(slime.global_position.x - 60.0 + jitter, FLOOR)
		await physics_frames(1)
	assert_eq(changes[0], 1, "one acquisition, no flip-flopping between equidistant knights")


func test_dead_target_is_abandoned() -> void:
	var slime := _slime(GREEN, Vector2(300, FLOOR), 0.0, 0.0)
	k1.set_physics_process(false)
	k1.global_position = Vector2(340, FLOOR)
	await physics_frames(10)
	assert_eq(slime.target, k1, "targets P1")
	k2.set_physics_process(false)
	k2.global_position = Vector2(240, FLOOR)
	k1.health.take_damage(DamageEvent.create(1, DamageEvent.Category.LAVA))
	await physics_frames(1)
	assert_false(slime.target == k1, "dead knight dropped immediately")
	await physics_frames(10)
	assert_eq(slime.target, k2, "switched to the living knight")
	k2.global_position = Vector2(1440, FLOOR)
	await physics_frames(90)
	assert_eq(slime.target, null, "no target once nobody living is in range")


func test_returns_to_patrol_after_grace_period() -> void:
	var slime := _slime(GREEN, Vector2(300, FLOOR))
	_place(k1, Vector2(360, FLOOR))
	await physics_frames(30)
	assert_eq(slime.state, St.CHASE, "chasing")
	_place(k1, Vector2(1400, FLOOR))
	await physics_frames(30)
	assert_eq(slime.target, k1, "keeps the target during the grace period")
	await physics_frames(50)
	assert_eq(slime.target, null, "target dropped after the grace period")
	assert_eq(slime.state, St.PATROL, "back to patrol")


func test_unreachable_target_gives_up() -> void:
	var slime := _slime(GREEN, Vector2(872, FLOOR), -40.0, 40.0, 200.0)
	_place(k1, Vector2(872, 352))
	await physics_frames(30)
	assert_eq(slime.state, St.CHASE, "chases the knight on the platform above")
	var x := slime.global_position.x
	await physics_frames(int(slime.stats.give_up_time * 60.0) + 10)
	assert_eq(slime.state == St.PATROL or slime.state == St.IDLE, true, "gave up and patrols")
	assert_near(slime.global_position.y, FLOOR, 0.5, "never left the ground")
	assert_lt(absf(slime.global_position.x - x), 41.0, "did not wander off while waiting")


# --- Stagger: green -------------------------------------------------------------------

func test_green_stagger_and_kill() -> void:
	var slime := _slime(GREEN, Vector2(300, FLOOR), 0.0, 0.0)
	assert_eq(slime.stagger.progress, 0, "progress starts at 0")
	_hit(slime)
	assert_eq(slime.stagger.progress, 1, "one base hit: 1 point")
	assert_false(slime.is_staggered(), "not staggered yet")
	var trigger := _hit(slime)
	assert_true(slime.is_staggered(), "second base hit staggers")
	assert_false(slime.can_damage(), "staggered: harmless")
	_hit(slime, 1, trigger)
	assert_false(slime.is_dead(), "the staggering attack cannot kill")
	await physics_frames(int(9.9 * 60.0))
	assert_true(slime.is_staggered(), "still staggered after 9.9 s")
	_hit(slime)
	assert_true(slime.is_dead(), "next distinct attack kills")


func test_green_recovers_and_can_be_staggered_again() -> void:
	var slime := _slime(GREEN, Vector2(300, FLOOR), 0.0, 0.0)
	var recovered := [0]
	slime.recovered.connect(func() -> void: recovered[0] += 1)
	_hit(slime)
	_hit(slime)
	assert_true(slime.is_staggered(), "staggered")
	await physics_frames(598)
	assert_true(slime.is_staggered(), "staggered for the whole 10 s")
	await physics_frames(5)
	assert_false(slime.is_staggered(), "recovered after 10 s")
	assert_eq(recovered[0], 1, "recovered once")
	assert_eq(slime.stagger.progress, 0, "progress reset")
	assert_true(slime.can_damage(), "contact damage restored")
	_hit(slime)
	assert_false(slime.is_staggered(), "first hit after recovery: progress only")
	_hit(slime)
	assert_true(slime.is_staggered(), "staggered again")


# --- Stagger: purple ------------------------------------------------------------------

func test_purple_stagger_and_kill() -> void:
	var slime := _slime(PURPLE, Vector2(300, FLOOR), 0.0, 0.0)
	assert_eq(slime.stagger.threshold, 4, "threshold 4")
	for i in 3:
		_hit(slime)
		assert_eq(slime.stagger.progress, i + 1, "progress %d" % (i + 1))
		assert_false(slime.is_staggered(), "not staggered after %d hits" % (i + 1))
	var trigger := _hit(slime)
	assert_true(slime.is_staggered(), "fourth hit staggers")
	_hit(slime, 1, trigger)
	assert_false(slime.is_dead(), "staggering attack cannot kill")
	assert_false(slime.can_damage(), "harmless while staggered")
	await physics_frames(603)
	assert_false(slime.is_staggered(), "recovers after 10 s")
	assert_eq(slime.stagger.progress, 0, "progress reset")
	for i in 4:
		_hit(slime)
	assert_true(slime.is_staggered(), "staggered again from zero")
	_hit(slime)
	assert_true(slime.is_dead(), "distinct attack kills")


func test_upgraded_attack_power() -> void:
	var green := _slime(GREEN, Vector2(260, FLOOR), 0.0, 0.0)
	var purple := _slime(PURPLE, Vector2(340, FLOOR), 0.0, 0.0)
	_hit(green, 2)
	assert_true(green.is_staggered(), "power 2 staggers green in one hit")
	_hit(purple, 2)
	assert_eq(purple.stagger.progress, 2, "power 2 adds 2 points to purple")
	assert_false(purple.is_staggered(), "not yet")
	_hit(purple, 2)
	assert_true(purple.is_staggered(), "second power-2 hit staggers purple")
	_hit(green, 2)
	_hit(purple, 2)
	assert_true(green.is_dead() and purple.is_dead(), "one more distinct hit kills each")


func test_staggered_slime_does_not_move() -> void:
	var slime := _slime(GREEN, Vector2(300, FLOOR), -100.0, 100.0)
	_place(k1, Vector2(380, FLOOR))
	await physics_frames(40)
	assert_eq(slime.state, St.CHASE, "chasing")
	slime.add_stagger_progress(2, k1)
	assert_true(slime.is_staggered(), "staggered by add_stagger_progress")
	var x := slime.global_position.x
	await physics_frames(120)
	assert_eq(slime.global_position.x, x, "no movement while staggered")
	assert_eq(slime.target, null, "no target while staggered")
	assert_eq(slime.add_stagger_progress(5), SlimeStagger.Outcome.IGNORED, "non-melee progress cannot kill")
	assert_false(slime.is_dead(), "still alive")


func test_real_knight_attacks_green_then_purple() -> void:
	# End to end: the knight's CombatComponent hits the slime's hurtbox.
	for spec: Array in [[GREEN, 2], [PURPLE, 4]]:
		var slime := _slime(spec[0], Vector2(300, FLOOR), 0.0, 0.0)
		k1.set_physics_process(true)
		_place(k1, Vector2(290, FLOOR))
		k1.facing = 1
		await physics_frames(10)
		var defeats := [0]
		slime.defeated.connect(func(_s: Slime, _d: CoinDropResult) -> void: defeats[0] += 1)
		for i in spec[1]:
			assert_false(slime.is_staggered(), "not staggered before hit %d" % (i + 1))
			await _tap([&"p1_attack"])
			await physics_frames(25)
			k1.facing = 1
		assert_true(slime.is_staggered(), "%d real attacks stagger %s" % [spec[1], slime.stats.display_name])
		assert_false(slime.is_dead(), "not dead yet")
		await _tap([&"p1_attack"])
		await physics_frames(25)
		assert_true(slime.is_dead(), "one more real attack kills %s" % slime.stats.display_name)
		assert_eq(defeats[0], 1, "defeated once")
		slime.queue_free()
		await physics_frames(2)


# --- Contact damage ---------------------------------------------------------------------

func test_contact_damage_respects_invulnerability() -> void:
	room.set_protected(false)
	var slime := _slime(GREEN, Vector2(300, FLOOR), 0.0, 0.0)
	var blocked := [0]
	k1.health.damage_blocked.connect(func(_e: DamageEvent, reason: StringName) -> void: blocked[0] += int(reason == &"invulnerable"))
	k1.set_physics_process(false)
	k1.global_position = Vector2(300, FLOOR)  # standing inside the slime
	await physics_frames(5)
	assert_eq(k1.health.current_health, 2, "contact removes one point")
	await physics_frames(50)
	assert_eq(k1.health.current_health, 2, "invulnerability blocks continued contact")
	assert_gt(blocked[0], 0.0, "repeated contact was blocked, not ignored silently")
	await physics_frames(20)
	assert_eq(k1.health.current_health, 1, "damage again after invulnerability ends")


func test_staggered_and_dead_slimes_are_harmless() -> void:
	room.set_protected(false)
	var slime := _slime(GREEN, Vector2(300, FLOOR), 0.0, 0.0)
	_hit(slime)
	_hit(slime)
	assert_true(slime.is_staggered(), "staggered")
	k1.set_physics_process(false)
	k1.global_position = Vector2(300, FLOOR)
	await physics_frames(120)
	assert_eq(k1.health.current_health, 3, "staggered slime deals no damage")
	_hit(slime)
	assert_true(slime.is_dead(), "dead")
	await physics_frames(60)
	assert_eq(k1.health.current_health, 3, "dead slime deals no damage")


func test_contact_stops_after_slime_is_removed() -> void:
	room.set_protected(false)
	var slime := _slime(GREEN, Vector2(300, FLOOR), 0.0, 0.0)
	slime.free_on_death = true
	_hit(slime)
	_hit(slime)
	_hit(slime)
	await physics_frames(60)
	assert_false(is_instance_valid(slime), "slime freed after its death animation")
	k1.set_physics_process(false)
	k1.global_position = Vector2(300, FLOOR)
	await physics_frames(30)
	assert_eq(k1.health.current_health, 3, "no damage from a removed slime")


# --- Death and coins ----------------------------------------------------------------------

func test_death_and_coin_drop_happen_once() -> void:
	var slime := _slime(GREEN, Vector2(300, FLOOR), 0.0, 0.0)
	var drops: Array = []
	slime.defeated.connect(func(_s: Slime, d: CoinDropResult) -> void: drops.append(d))
	var coins_before := get_tree().get_nodes_in_group(DroppedCoin.GROUP).size()
	_hit(slime)
	_hit(slime)
	# Both knights' distinct attacks land on the staggered slime in the same tick.
	_hit(slime)
	_hit(slime)
	assert_eq(drops.size(), 1, "defeated emitted exactly once")
	var drop: CoinDropResult = drops[0]
	assert_eq(typeof(drop.count), TYPE_INT, "count is an integer")
	assert_true(drop.count >= 4 and drop.count <= 6, "4-6 coins (got %d)" % drop.count)
	assert_true(drop.position.is_finite() and drop.position.distance_to(slime.global_position) < 16.0, "drop at the slime")
	assert_eq(room.get("drops_announced"), 1, "listener group notified once")
	assert_eq(room.get("coins_announced"), drop.count, "listener received the count")
	assert_eq(slime.state, St.DEAD, "DEAD state")
	assert_false(slime.hurtbox.enabled, "hit detection disabled")
	await physics_frames(3)
	assert_eq(get_tree().get_nodes_in_group(DroppedCoin.GROUP).size() - coins_before, drop.count, "that many visible coins")
	await physics_frames(90)
	for coin in get_tree().get_nodes_in_group(DroppedCoin.GROUP):
		assert_true((coin as DroppedCoin).is_resting(), "coins come to rest")
		assert_lt(coin.global_position.y, FLOOR + 1.0, "coins rest on the floor")


func test_every_slime_rolls_its_own_drop() -> void:
	var counts: Array[int] = []
	for i in 12:
		var slime := _slime(GREEN if i % 2 == 0 else PURPLE, Vector2(200 + i * 20, FLOOR), 0.0, 0.0, 0.0, 100 + i)
		slime.get_node("CoinDropper").spawn_coins = false
		await physics_frames(1)
		for h in slime.stagger.threshold + 1:
			_hit(slime)
		assert_true(slime.is_dead(), "slime %d dead" % i)
		counts.append(slime.drop_result.count)
		assert_true(slime.drop_result.count >= 4 and slime.drop_result.count <= 6, "slime %d: 4-6 coins" % i)
	assert_eq(room.get("drops_announced"), 12, "one drop per slime")
	assert_gt(counts.max() - counts.min(), 0.0, "rolls are independent per slime (%s)" % [counts])


# --- Integration -------------------------------------------------------------------------

func test_both_knights_fight_several_slimes_simultaneously() -> void:
	var g := _slime(GREEN, Vector2(300, FLOOR), 0.0, 0.0)
	var p := _slime(PURPLE, Vector2(420, FLOOR), 0.0, 0.0)
	_place(k1, Vector2(290, FLOOR))
	_place(k2, Vector2(430, FLOOR))
	rig.snap_to_targets()  # respawn-style teleport: re-centre the camera
	await physics_frames(10)
	var changes := rig.layout_change_count
	for i in 6:
		k1.facing = 1
		k2.facing = -1
		await _tap([&"p1_attack", &"p2_attack"])
		await physics_frames(25)
	assert_true(g.is_dead(), "P1 defeated the green slime (2 + 1 hits)")
	assert_true(p.is_dead(), "P2 defeated the purple slime (4 + 1 hits)")
	assert_eq(rig.layout_change_count, changes, "camera undisturbed")
	assert_eq(k1.health.current_health, 3, "protected knights unharmed")


func test_recovered_slime_reacquires_visible_knight() -> void:
	var slime := _slime(GREEN, Vector2(300, FLOOR), 0.0, 0.0)
	k1.set_physics_process(false)
	k1.global_position = Vector2(350, FLOOR)
	await physics_frames(10)
	slime.add_stagger_progress(2)
	await physics_frames(603)
	assert_false(slime.is_staggered(), "recovered")
	await physics_frames(40)
	assert_eq(slime.target, k1, "re-detected the knight after recovering")
	assert_eq(slime.state, St.CHASE, "chasing again")
