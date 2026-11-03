extends GameTestCase
## Hazards and falling in the real hazard room (floor y=512). Layout (x ranges):
## spikes 160-208 (on the floor), hot ground 256-320 (is the floor), lava 352-416 (16 px deep),
## pits 448-496 / 560-720 / ..., FallBoundary along y 576. Open safe floor: x 16-150.
## Knights start at the spawns (40,512) and (72,512). The runner gives every test a fresh run.

const ROOM := "res://scenes/dev/hazard_test_room.tscn"
const FLOOR := 512.0
const SAFE_A := Vector2(100, FLOOR)
const SPIKES_AT := Vector2(184, FLOOR)
const HOT_AT := Vector2(288, FLOOR)
const LAVA_AT := Vector2(384, 520)
const PIT_DROP := Vector2(472, 480)
const ALL_ACTIONS := [&"p1_move_left", &"p1_move_right", &"p1_move_up", &"p1_move_down", &"p1_attack",
	&"p2_move_left", &"p2_move_right", &"p2_move_up", &"p2_move_down", &"p2_attack"]

var room: Node
var level: Node2D
var rig: SplitScreenRig
var k1: Knight
var k2: Knight
var run: RunState


func before_each() -> void:
	_release_all()
	run = RunState.current()
	run.config = run.config.duplicate()
	run.config.coin_heal_chance_percent = 0
	room = (load(ROOM) as PackedScene).instantiate()
	add_child(room)
	level = room.get("level")
	rig = room.get("rig")
	k1 = room.get("knight_1")
	k2 = room.get("knight_2")
	rig.snap_to_targets()
	await physics_frames(10)


func after_each() -> void:
	_release_all()
	get_tree().paused = false
	room.queue_free()
	await physics_frames(2)


func _release_all() -> void:
	for a in ALL_ACTIONS:
		Input.action_release(a)


func _hazard(node_name: String) -> Hazard:
	return level.get_node("Hazards/" + node_name) as Hazard


## Teleports and waits until the knight has stood still long enough to record a safe spot.
func _stand(knight: Knight, at: Vector2, frames := 20) -> void:
	knight.teleport_to(at)
	await physics_frames(frames)


func _record_events(knight: Knight) -> Array:
	var events := []
	knight.health.damage_received.connect(func(event: DamageEvent, applied: int) -> void:
		events.append([event.category, applied]))
	return events


# --- Spikes -----------------------------------------------------------------------------

func test_spikes_deal_one_spike_damage_per_entry() -> void:
	var events := _record_events(k1)
	var hp := k1.health.current_health
	k1.teleport_to(SPIKES_AT)
	await physics_frames(5)
	assert_eq(k1.health.current_health, hp - 1, "spikes take exactly 1 HP")
	assert_eq(events.size(), 1, "one damage event")
	assert_eq(events[0][0], DamageEvent.Category.SPIKE, "category SPIKE")
	await physics_frames(150)  # stays inside past the invulnerability window
	assert_eq(k1.health.current_health, hp - 1, "no repeated damage while staying inside")
	assert_eq(events.size(), 1, "still one event")
	await _stand(k1, SAFE_A, 5)
	k1.teleport_to(SPIKES_AT)
	await physics_frames(5)
	assert_eq(k1.health.current_health, hp - 2, "re-entry deals another hit")


func test_spikes_respect_invulnerability() -> void:
	var hp := k1.health.current_health
	k1.health.start_invulnerability(1.0)
	k1.teleport_to(SPIKES_AT)
	await physics_frames(5)
	assert_eq(k1.health.current_health, hp, "invulnerable knight is not hurt by spikes")


func test_spikes_are_blocked_by_fruit_shield() -> void:
	var stats := run.player(1)
	stats.collect_fruit(PlayerStats.FruitType.YELLOW, 1)
	assert_eq(stats.effects.charges(PlayerEffects.FRUIT_SHIELD), 1, "shield ready")
	var hp := k1.health.current_health
	k1.teleport_to(SPIKES_AT)
	await physics_frames(5)
	assert_eq(k1.health.current_health, hp, "shield absorbed the spike hit")
	assert_false(stats.effects.has(PlayerEffects.FRUIT_SHIELD), "the one charge was consumed")


func test_walking_into_spikes_hurts_once() -> void:
	await _stand(k1, Vector2(140, FLOOR))
	var hp := k1.health.current_health
	Input.action_press(&"p1_move_right")
	await physics_frames(40)  # walks across the whole spike strip
	Input.action_release(&"p1_move_right")
	await physics_frames(5)
	assert_eq(k1.health.current_health, hp - 1, "one hit for one walk through")


# --- Hot ground -------------------------------------------------------------------------

func test_hot_ground_is_solid_and_hurts_once_per_entry() -> void:
	var events := _record_events(k1)
	var hp := k1.health.current_health
	k1.teleport_to(HOT_AT + Vector2(0, -2))
	await physics_frames(10)
	assert_true(k1.is_on_floor(), "knight stands on hot ground")
	assert_near(k1.global_position.y, FLOOR, 0.5, "does not sink into it")
	assert_eq(k1.health.current_health, hp - 1, "1 HP")
	assert_eq(events.size(), 1, "one event")
	assert_eq(events[0][0], DamageEvent.Category.HOT_GROUND, "category HOT_GROUND")
	await physics_frames(120)
	assert_eq(events.size(), 1, "standing on it does not repeat damage")


func test_hot_ground_blocked_by_tile_shield() -> void:
	var stats := run.player(1)
	stats.effects.add_tile_effect(PlayerEffects.TILE_SHIELD)
	var hp := k1.health.current_health
	k1.teleport_to(HOT_AT + Vector2(0, -2))
	await physics_frames(10)
	assert_eq(k1.health.current_health, hp, "tile shield blocks hot ground")
	assert_false(stats.effects.has(PlayerEffects.TILE_SHIELD), "shield consumed")


func test_walking_onto_hot_ground_never_records_it() -> void:
	await _stand(k1, Vector2(230, FLOOR))
	Input.action_press(&"p1_move_right")
	await physics_frames(25)  # walks well onto the hot ground
	Input.action_release(&"p1_move_right")
	await physics_frames(30)
	assert_gt(k1.global_position.x, 256.0, "on the hot ground")
	assert_lt(k1.safe_spot.last_safe_position.x + 5.0, 256.0, "last safe spot is clear of the hot ground")


func test_hazard_position_is_never_safe() -> void:
	await _stand(k1, SAFE_A)
	assert_true(k1.safe_spot.has_safe_position, "safe floor recorded")
	k1.teleport_to(HOT_AT + Vector2(0, -2))
	await physics_frames(60)
	assert_eq(k1.safe_spot.hazard_contacts, 1, "one hazard contact")
	assert_near(k1.safe_spot.last_safe_position.x, SAFE_A.x, 0.5, "hot ground never recorded as safe")


# --- Lava -------------------------------------------------------------------------------

func test_lava_kills_through_every_protection_once() -> void:
	var stats := run.player(1)
	stats.collect_fruit(PlayerStats.FruitType.YELLOW, 3)
	stats.collect_jar(PlayerStats.JarType.YELLOW)
	stats.effects.add_tile_effect(PlayerEffects.TILE_SHIELD)
	k1.health.start_invulnerability(5.0)
	var deaths := [0]
	k1.died.connect(func() -> void: deaths[0] += 1)
	var k2_hp := k2.health.current_health
	var k2_pos := k2.global_position
	k1.teleport_to(LAVA_AT)
	await physics_frames(30)
	assert_eq(k1.health.current_health, 0, "lava empties health")
	assert_true(k1.is_dead(), "knight is DEAD")
	assert_eq(deaths[0], 1, "death emitted exactly once")
	assert_eq(stats.effects.charges(PlayerEffects.FRUIT_SHIELD), 3, "shields were not spent on lava")
	assert_eq(k2.health.current_health, k2_hp, "other knight unharmed")
	assert_near(k2.global_position.distance_to(k2_pos), 0.0, 0.5, "other knight not moved")
	assert_false(k2.is_dead(), "other knight alive (no team wipe in Phase 6)")


func test_dead_knight_in_lava_is_not_hit_again() -> void:
	var events := _record_events(k1)
	k1.teleport_to(LAVA_AT)
	await physics_frames(10)
	k1.teleport_to(LAVA_AT + Vector2(24, 0))
	await physics_frames(10)
	var lava_events := events.filter(func(e: Array) -> bool: return e[1] > 0)
	assert_eq(lava_events.size(), 1, "one applied lava event")


# --- Falling ----------------------------------------------------------------------------

func test_fall_costs_one_hp_and_respawns_at_last_safe_position() -> void:
	await _stand(k1, SAFE_A)
	var events := _record_events(k1)
	var falls := []
	k1.safe_spot.fell.connect(func(k: Knight, survived: bool) -> void: falls.append(survived))
	var hp := k1.health.current_health
	var k2_pos := k2.global_position
	k1.teleport_to(PIT_DROP)
	await physics_frames(90)
	assert_eq(falls, [true], "one fall, survived")
	assert_eq(k1.safe_spot.fall_count, 1, "processed once")
	assert_eq(k1.health.current_health, hp - 1, "exactly 1 HP")
	assert_eq(events.size(), 1, "one damage event")
	assert_eq(events[0][0], DamageEvent.Category.FALL, "category FALL")
	assert_near(k1.global_position.x, SAFE_A.x, 1.0, "back at the last safe x")
	assert_near(k1.global_position.y, FLOOR, 1.0, "standing on the floor again")
	assert_near(k2.global_position.distance_to(k2_pos), 0.0, 0.5, "other knight not moved")


func test_fall_damage_ignores_shields_and_invulnerability() -> void:
	await _stand(k1, SAFE_A)
	var stats := run.player(1)
	stats.effects.add_tile_effect(PlayerEffects.TILE_SHIELD)
	var hp := k1.health.current_health
	k1.teleport_to(PIT_DROP)
	k1.health.start_invulnerability(5.0)
	await physics_frames(90)
	assert_eq(k1.health.current_health, hp - 1, "fall damage is unblockable")
	assert_true(stats.effects.has(PlayerEffects.TILE_SHIELD), "shield not consumed by a fall")


func test_respawn_protection_and_reset_motion() -> void:
	await _stand(k1, SAFE_A)
	var landed := [false]
	k1.safe_spot.fell.connect(func(_k: Knight, _s: bool) -> void:
		landed[0] = true
		assert_eq(k1.velocity, Vector2.ZERO, "velocity reset on respawn")
		assert_true(k1.health.is_invulnerable(), "respawn protection active")
		assert_near(k1.health.invulnerability_left(), 1.0, 0.05, "about 1 s of protection"))
	k1.teleport_to(PIT_DROP)
	for i in 120:
		if landed[0]:
			break
		await physics_frames(1)
	assert_true(landed[0], "fell")
	var hp := k1.health.current_health
	await physics_frames(20)
	k1.teleport_to(SPIKES_AT)  # straight into spikes while still protected
	await physics_frames(3)
	assert_eq(k1.health.current_health, hp, "respawn protection blocks the next hit")


func test_fall_preserves_progression() -> void:
	var stats := run.player(1)
	stats.collect_jar(PlayerStats.JarType.GREEN)
	stats.collect_jar(PlayerStats.JarType.RED)
	stats.effects.add_tile_effect(PlayerEffects.SPEED_BOOST)
	run.coins = 7
	await _stand(k1, SAFE_A)
	var max_hp := k1.health.max_health
	var power := stats.attack_power()
	k1.teleport_to(PIT_DROP)
	await physics_frames(90)
	assert_eq(k1.health.max_health, max_hp, "max health kept")
	assert_eq(stats.attack_power(), power, "attack power kept")
	assert_true(stats.effects.has(PlayerEffects.SPEED_BOOST), "timed effect kept")
	assert_eq(run.coins, 7, "shared coins kept")


func test_fall_at_one_hp_kills_once() -> void:
	await _stand(k1, SAFE_A)
	k1.health.set_current_health(1)
	var falls := []
	var deaths := [0]
	k1.safe_spot.fell.connect(func(_k: Knight, survived: bool) -> void: falls.append(survived))
	k1.died.connect(func() -> void: deaths[0] += 1)
	k1.teleport_to(PIT_DROP)
	await physics_frames(120)
	assert_eq(falls, [false], "one fall, not survived")
	assert_true(k1.is_dead(), "DEAD")
	assert_eq(deaths[0], 1, "died once")
	assert_eq(k1.safe_spot.fall_count, 1, "the body is not re-processed")
	assert_false(k2.is_dead(), "other knight alive")


func test_fall_without_safe_position_uses_spawn() -> void:
	var spawn := k1.safe_spot.spawn_position
	k1.safe_spot.has_safe_position = false
	k1.teleport_to(PIT_DROP)
	await physics_frames(3)  # no frames on safe ground before falling
	k1.safe_spot.has_safe_position = false
	await physics_frames(90)
	assert_eq(k1.safe_spot.fall_count, 1, "fell")
	assert_near(k1.global_position.x, spawn.x, 1.0, "respawned at the level spawn")


func test_fall_line_works_without_fall_boundary() -> void:
	_hazard("FallBoundary").free()
	await _stand(k1, SAFE_A)
	var hp := k1.health.current_health
	k1.teleport_to(PIT_DROP)
	await physics_frames(120)
	assert_eq(k1.safe_spot.fall_count, 1, "the fall line caught it once")
	assert_eq(k1.health.current_health, hp - 1, "1 HP")
	assert_near(k1.global_position.x, SAFE_A.x, 1.0, "respawned")


func test_both_knights_fall_independently() -> void:
	await _stand(k1, SAFE_A)
	await _stand(k2, Vector2(130, FLOOR))
	var hp1 := k1.health.current_health
	var hp2 := k2.health.current_health
	k1.teleport_to(PIT_DROP)
	k2.teleport_to(PIT_DROP + Vector2(10, -20))
	await physics_frames(120)
	assert_eq(k1.health.current_health, hp1 - 1, "P1 -1")
	assert_eq(k2.health.current_health, hp2 - 1, "P2 -1")
	assert_near(k1.global_position.x, SAFE_A.x, 1.0, "P1 at its own safe spot")
	assert_near(k2.global_position.x, 130.0, 1.0, "P2 at its own safe spot")


# --- Safe position tracking -------------------------------------------------------------

func test_safe_position_needs_stable_ground() -> void:
	k1.teleport_to(SAFE_A + Vector2(0, -40))  # airborne
	await physics_frames(4)
	assert_false(k1.safe_spot.is_safe_now(), "airborne is not safe")
	await physics_frames(30)
	assert_true(k1.safe_spot.is_safe_now(), "grounded on plain floor is safe")
	assert_near(k1.safe_spot.last_safe_position.x, SAFE_A.x, 0.5, "recorded")


func test_standing_on_the_other_knight_is_not_safe() -> void:
	await _stand(k2, SAFE_A)
	var before := k1.safe_spot.last_safe_position
	k1.teleport_to(SAFE_A + Vector2(0, -24))
	await physics_frames(30)
	assert_eq(k1.floor_kind, Knight.FloorKind.KNIGHT, "P1 rides P2")
	assert_false(k1.safe_spot.is_safe_now(), "a knight is not safe ground")
	assert_eq(k1.safe_spot.last_safe_position, before, "not recorded")


func test_dead_knight_never_records() -> void:
	await _stand(k1, SAFE_A)
	k1.health.apply_damage(99)
	await physics_frames(2)
	k1.teleport_to(Vector2(130, FLOOR))
	await physics_frames(30)
	assert_near(k1.safe_spot.last_safe_position.x, SAFE_A.x, 0.5, "dead knight records nothing")


func test_camera_shows_the_knight_after_a_far_respawn() -> void:
	await _stand(k1, SAFE_A)
	k1.teleport_to(Vector2(960, 470))  # over a pit far from the safe spot
	var fell := [false]
	k1.safe_spot.fell.connect(func(_k: Knight, _s: bool) -> void: fell[0] = true)
	for i in 120:
		if fell[0]:
			break
		await physics_frames(1)
	assert_true(fell[0], "fell")
	await physics_frames(20)
	var visible := false
	for view in 2:
		if rig.view_world_rect(view).has_point(k1.global_position + Vector2(0, -9)):
			visible = true
	assert_true(visible, "respawned knight is inside a camera view")
	assert_true(rig.view_world_rect(0).has_point(k2.global_position + Vector2(0, -9)) \
		or rig.view_world_rect(1).has_point(k2.global_position + Vector2(0, -9)), "other knight still visible")
