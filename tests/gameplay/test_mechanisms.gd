extends GameTestCase
## Overhaul traversal objects, hazards and co-op mechanisms in the real combat test room
## (floor y=448, open floor x 16..280, ceiling y=16). Real knights, real input.

const ROOM := "res://scenes/dev/combat_test_room.tscn"
const M := "res://scenes/mechanisms/"
const FLOOR := 448.0
const ALL_ACTIONS := [&"p1_move_left", &"p1_move_right", &"p1_move_up", &"p1_move_down", &"p1_attack",
	&"p2_move_left", &"p2_move_right", &"p2_move_up", &"p2_move_down", &"p2_attack"]

var room: Node
var level: Node2D
var k1: Knight
var k2: Knight


func before_each() -> void:
	TrainingDummy.console_log = false
	for a in ALL_ACTIONS:
		Input.action_release(a)
	room = (load(ROOM) as PackedScene).instantiate()
	add_child(room)
	level = room.get("level")
	k1 = room.get("knight_1")
	k2 = room.get("knight_2")
	for dummy in level.get_node("Targets").get_children():
		dummy.queue_free()
	k1.teleport_to(Vector2(60, FLOOR))
	k2.teleport_to(Vector2(700, FLOOR))
	await physics_frames(8)


func after_each() -> void:
	for a in ALL_ACTIONS:
		Input.action_release(a)
	room.queue_free()
	await physics_frames(2)
	TrainingDummy.console_log = true


func _add(path: String, at: Vector2, props := {}) -> Node2D:
	var node: Node2D = (load(M + path) as PackedScene).instantiate()
	for key in props:
		node.set(key, props[key])
	node.position = at
	level.add_child(node)
	return node


func _peak_rise(k: Knight, frames: int) -> float:
	var start := k.global_position.y
	var top := start
	for i in frames:
		await physics_frames(1)
		top = minf(top, k.global_position.y)
	return start - top


func test_spring_launches_to_its_height() -> void:
	var spring := _add("spring_mushroom.tscn", Vector2(100, FLOOR)) as SpringMushroom
	await physics_frames(2)
	k1.teleport_to(Vector2(100, FLOOR - 20))
	await _peak_rise(k1, 90)
	var top := FLOOR
	k1.teleport_to(Vector2(100, FLOOR - 20))
	for i in 90:
		await physics_frames(1)
		top = minf(top, k1.global_position.y)
	var tiles := EnvironmentZone.CONFIG.spring_height_tiles
	assert_gt(FLOOR - top, tiles * 16.0, "the knight's feet rise above the configured height (from the floor)")
	assert_lt(FLOOR - top, tiles * 16.0 + 24.0, "but not far beyond it")
	assert_not_null(spring, "spring exists")


func test_updraft_lifts_a_knight() -> void:
	_add("environment_zone.tscn", Vector2(84, 200), {"kind": EnvironmentZone.Kind.UPDRAFT, "size": Vector2(32, 248)})
	await physics_frames(2)
	k1.teleport_to(Vector2(100, FLOOR))
	await physics_frames(45)
	assert_lt(k1.global_position.y, FLOOR - 80.0, "rising inside the updraft")
	assert_true(k1.in_zone(EnvironmentZone.Kind.UPDRAFT), "knight knows it is in the zone")


func test_wind_pushes_and_ice_slides() -> void:
	_add("environment_zone.tscn", Vector2(16, 400), {"kind": EnvironmentZone.Kind.WIND, "size": Vector2(260, 48), "direction": 1})
	await physics_frames(2)
	var x := k1.global_position.x
	await physics_frames(30)
	assert_gt(k1.global_position.x, x + 10.0, "an idle knight drifts with the wind")
	room.queue_free()
	await physics_frames(2)
	await before_each()
	# Ice: stopping takes longer.
	var stop_normal := await _stop_distance()
	_add("environment_zone.tscn", Vector2(16, 432), {"kind": EnvironmentZone.Kind.ICE, "size": Vector2(260, 16)})
	await physics_frames(2)
	k1.teleport_to(Vector2(60, FLOOR))
	await physics_frames(5)
	var stop_ice := await _stop_distance()
	assert_gt(stop_ice, stop_normal * 2.0, "much longer slide on ice")


func _stop_distance() -> float:
	Input.action_press(&"p1_move_right")
	await physics_frames(25)
	Input.action_release(&"p1_move_right")
	var x := k1.global_position.x
	await physics_frames(60)
	return k1.global_position.x - x


func test_saw_blade_hurts_on_its_rail() -> void:
	_add("saw_blade.tscn", Vector2(80, FLOOR - 8), {"travel": Vector2(80, 0)})
	k1.teleport_to(Vector2(120, FLOOR))
	var hp := k1.health.current_health
	await physics_frames(55)
	assert_eq(k1.health.current_health, hp - 1, "the blade passing over the knight hurts once (then invulnerability)")


func test_fire_jet_burns_only_when_lit() -> void:
	var jet := _add("fire_jet.tscn", Vector2(100, FLOOR)) as FireJet
	k1.teleport_to(Vector2(100, FLOOR))
	var hp := k1.health.current_health
	var c := EnvironmentZone.CONFIG
	await physics_frames(int((c.fire_off_time + c.fire_warning_time) * 60.0) - 3)
	assert_eq(jet.phase, FireJet.Phase.WARNING, "warning before the fire")
	assert_eq(k1.health.current_health, hp, "no damage while off or warning")
	await physics_frames(8)
	assert_true(jet.is_burning(), "burning")
	assert_eq(k1.health.current_health, hp - 1, "standing in the flame hurts")


func test_falling_rock_drops_on_a_knight_and_regrows() -> void:
	var rock := _add("falling_rock.tscn", Vector2(120, 300)) as FallingRock
	await physics_frames(2)
	assert_eq(rock.phase, FallingRock.Phase.HANGING, "hangs while nobody is below")
	k1.teleport_to(Vector2(120, FLOOR))
	var hp := k1.health.current_health
	await physics_frames(3)
	assert_eq(rock.phase, FallingRock.Phase.SHAKING, "shakes first (telegraph)")
	await physics_frames(90)
	assert_eq(k1.health.current_health, hp - 1, "the rock hits the knight below")
	assert_eq(rock.phase, FallingRock.Phase.GONE, "shattered")
	k1.teleport_to(Vector2(240, FLOOR))
	await physics_frames(int(EnvironmentZone.CONFIG.rock_respawn_time * 60.0) + 5)
	assert_eq(rock.phase, FallingRock.Phase.HANGING, "grows back")


func test_cracked_block_breaks_only_to_heavy_slashes_and_stays_broken() -> void:
	var block := _add("breakable_block.tscn", Vector2(80, FLOOR - 32), {"block_id": "t1", "size_tiles": Vector2i(1, 2)}) as BreakableBlock
	await physics_frames(2)
	k1.teleport_to(Vector2(68, FLOOR))
	await physics_frames(3)
	Input.action_press(&"p1_attack")
	await physics_frames(10)
	assert_false(block.is_broken, "an ordinary slash only chips it")
	await physics_frames(int(k1.combat.config.charge_time * 60.0))
	Input.action_release(&"p1_attack")
	await physics_frames(20)
	assert_true(block.is_broken, "the charged slash breaks it")
	var again := _add("breakable_block.tscn", Vector2(80, FLOOR - 32), {"block_id": "t1"}) as BreakableBlock
	await physics_frames(1)
	assert_true(again.is_broken, "a broken block stays broken for the run (same level and id)")


func test_pogo_lantern_bounces_a_downward_strike() -> void:
	_add("pogo_lantern.tscn", Vector2(100, FLOOR - 40))
	k1.teleport_to(Vector2(100, FLOOR - 90))
	await physics_frames(8)
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
	assert_true(bounced, "striking down onto the lantern bounces the knight")


func test_encounter_zone_locks_and_releases_the_arena() -> void:
	var zone := _add("encounter_zone.tscn", Vector2(40, 380), {"size": Vector2(200, 68), "puzzle_id": "arena_t"}) as EncounterZone
	var grunt: Enemy = (load("res://scenes/enemies/orc_grunt.tscn") as PackedScene).instantiate()
	grunt.position = Vector2(200, FLOOR)
	grunt.free_on_death = false
	level.add_child(grunt)
	var gate: PuzzleGate = (load("res://scenes/puzzles/puzzle_gate.tscn") as PackedScene).instantiate()
	gate.position = Vector2(256, FLOOR - 48)
	gate.controller = NodePath("../" + String(zone.name))
	level.add_child(gate)
	await physics_frames(5)
	assert_true(zone.is_active(), "waiting: gates open")
	assert_true(gate.is_open(), "gate open before the fight")
	k1.teleport_to(Vector2(80, FLOOR))
	k2.teleport_to(Vector2(100, FLOOR))
	await physics_frames(3)
	assert_eq(zone.phase, EncounterZone.Phase.FIGHTING, "both knights inside with an enemy alive")
	await physics_frames(40)
	assert_false(gate.is_open(), "the gate closed behind them")
	grunt.kill()
	await physics_frames(3)
	assert_eq(zone.phase, EncounterZone.Phase.DONE, "all enemies dead: done")
	await physics_frames(40)
	assert_true(gate.is_open(), "the gate reopened")
	assert_true(RunState.current().puzzles.has_state(zone.scope_key(), "arena_t"), "completion saved")


func test_stack_boost_jumps_higher() -> void:
	k1.teleport_to(Vector2(120, FLOOR))
	await physics_frames(5)
	Input.action_press(&"p1_move_up")
	var normal := await _peak_rise(k1, 50)
	Input.action_release(&"p1_move_up")
	await physics_frames(40)
	k2.teleport_to(Vector2(120, FLOOR))
	k1.teleport_to(Vector2(120, FLOOR - 30))
	await physics_frames(30)
	assert_eq(k1.floor_kind, Knight.FloorKind.KNIGHT, "P1 stands on P2")
	Input.action_press(&"p1_move_up")
	var boosted := await _peak_rise(k1, 60)
	Input.action_release(&"p1_move_up")
	assert_gt(boosted, normal * 1.4, "jumping off the partner goes much higher")


func test_darkness_lights_both_knights() -> void:
	_add("darkness.tscn", Vector2.ZERO)
	await physics_frames(2)
	assert_not_null(k1.get_node_or_null("CarriedLight"), "P1 carries a light")
	assert_not_null(k2.get_node_or_null("CarriedLight"), "P2 carries a light")
	var mods := level.find_children("*", "CanvasModulate", true, false)
	assert_eq(mods.size(), 1, "one canvas tint")
