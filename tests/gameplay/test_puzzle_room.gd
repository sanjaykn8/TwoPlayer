extends GameTestCase
## The ten sections of the puzzle test room, solved by two knights with real movement and
## attacks, plus failure / softlock scenarios and persistence across reloads. Floor y = 512.
## Layout reference: tools/build_phase7_content.gd. The runner gives every test a fresh run.

const ROOM := "res://scenes/dev/puzzle_test_room.tscn"
const FLOOR := 512.0
const LEDGE_Y := 400.0   # section 4 switch ledge
const BAND_Y := 320.0    # section 5 upper route
const ALL_ACTIONS := [&"p1_move_left", &"p1_move_right", &"p1_move_up", &"p1_move_down", &"p1_attack",
	&"p2_move_left", &"p2_move_right", &"p2_move_up", &"p2_move_down", &"p2_attack"]
const LS := PuzzleLogic.State
const GS := PuzzleGate.State

var room: Node
var level: Node2D
var rig: SplitScreenRig
var k1: Knight
var k2: Knight
var run: RunState


func before_each() -> void:
	_release_all()
	run = RunState.current()
	await _load_room()


func after_each() -> void:
	_release_all()
	get_tree().paused = false
	if is_instance_valid(room):
		room.queue_free()
	await physics_frames(2)


func _load_room() -> void:
	room = (load(ROOM) as PackedScene).instantiate()
	add_child(room)
	level = room.get("level")
	rig = room.get("rig")
	k1 = room.get("knight_1")
	k2 = room.get("knight_2")
	rig.snap_to_targets()
	await physics_frames(5)


func _reload_room() -> void:
	room.free()
	await physics_frames(1)
	await _load_room()


func _release_all() -> void:
	for a in ALL_ACTIONS:
		Input.action_release(a)


func _p(node_name: String) -> Node:
	return level.get_node("Puzzles/" + node_name)


func _action(knight: Knight, what: String) -> StringName:
	return StringName("p%d_%s" % [knight.player_id(), what])


func _stand(knight: Knight, x: float, y := FLOOR, frames := 6) -> void:
	knight.teleport_to(Vector2(x, y))
	rig.snap_to_targets()
	await physics_frames(frames)


func _attack(knight: Knight, side: int) -> void:
	knight.facing = side
	Input.action_press(_action(knight, "attack"))
	await physics_frames(1)
	Input.action_release(_action(knight, "attack"))
	await physics_frames(24)


## Stands next to `target` (left side for side 1, right side for -1) on floor `y` and strikes.
func _strike(knight: Knight, target: Node2D, side := 1, y := FLOOR) -> void:
	var x := target.position.x - 10.0 if side == 1 else target.position.x + 26.0
	await _stand(knight, x, y, 4)
	await _attack(knight, side)


## Walks toward `target_x`, jumping when passing each x in `jumps`. Returns true if reached.
func _walk_to(knight: Knight, target_x: float, jumps: Array = [], limit := 600) -> bool:
	var right := target_x > knight.global_position.x
	var move := _action(knight, "move_right" if right else "move_left")
	var up := _action(knight, "move_up")
	var pending := jumps.duplicate()
	var hold := 0
	var reached := false
	Input.action_press(move)
	for i in limit:
		var x := knight.global_position.x
		if (right and x >= target_x) or (not right and x <= target_x):
			reached = true
			break
		if not pending.is_empty() and ((right and x >= pending[0]) or (not right and x <= pending[0])):
			pending.pop_front()
			Input.action_press(up)
			hold = 14
		if hold > 0:
			hold -= 1
			if hold == 0:
				Input.action_release(up)
		await physics_frames(1)
	Input.action_release(move)
	Input.action_release(up)
	await physics_frames(4)
	return reached


func _frames_until(condition: Callable, limit: int) -> int:
	for i in limit:
		if condition.call():
			return i
		await physics_frames(1)
	return -1


# --- 1 Two stones ---------------------------------------------------------------------------

func test_s1_two_plates_open_gate_for_good() -> void:
	var lock := _p("S1Lock") as PuzzleLogic
	var gate := _p("Gate1") as PuzzleGate
	var done := [0]
	lock.completed.connect(func() -> void: done[0] += 1)
	await _stand(k1, 144)
	assert_eq(lock.state, LS.PARTIAL, "one stone: partial")
	assert_eq(gate.state, GS.CLOSED, "gate closed")
	await _stand(k2, 208, FLOOR, 30)
	assert_eq(lock.state, LS.COMPLETED, "two stones: completed")
	assert_true(gate.is_open(), "gate opens")
	for i in 3:  # step off and on again: nothing more happens
		await _stand(k1, 100)
		await _stand(k1, 144)
	assert_eq(done[0], 1, "completion happened exactly once")
	await _stand(k1, 280)
	await _stand(k2, 260, FLOOR, 30)
	assert_true(await _walk_to(k1, 360), "P1 walks through Gate1")
	assert_true(await _walk_to(k2, 340), "P2 walks through Gate1")


# --- 2 Hold the light -----------------------------------------------------------------------

func test_s2_hold_plate_lets_partner_cross_then_far_switch_keeps_it_open() -> void:
	var gate := _p("Gate2") as PuzzleGate
	await _stand(k2, 368, FLOOR, 30)
	assert_true(gate.is_open(), "held plate opens Gate2")
	await _stand(k1, 440)
	var hp := k1.health.current_health
	assert_true(await _walk_to(k1, 724, [460]), "P1 crosses the spikes and the gate")
	assert_eq(k1.health.current_health, hp, "jumped clear of the spikes")
	await _attack(k1, 1)
	assert_true((_p("S2FarSwitch") as AttackSwitch).is_active(), "far switch latched")
	await _stand(k2, 420, FLOOR, 120)
	assert_true(gate.is_open(), "gate stays open after the holder leaves")
	assert_true(await _walk_to(k2, 760, [460]), "P2 follows")


func test_s2_holder_leaving_early_never_traps_the_partner() -> void:
	var gate := _p("Gate2") as PuzzleGate
	await _stand(k2, 368, FLOOR, 30)
	await _stand(k1, 712)  # in the doorway
	await _stand(k2, 300, FLOOR, 120)  # the holder walks away
	assert_eq(gate.state, GS.WAITING, "gate waits instead of closing on P1")
	assert_false(gate.is_solid(), "not solid around P1")
	assert_true(await _walk_to(k1, 724), "P1 can still walk out")
	var closed := await _frames_until(func() -> bool: return gate.state == GS.CLOSED, 60)
	assert_true(closed >= 0, "closes once clear")
	await _attack(k1, 1)  # from the far side
	await physics_frames(30)
	assert_true(gate.is_open(), "P1 reopens it for P2 from the far side")


func test_s2_holder_dies_while_partner_in_doorway() -> void:
	var gate := _p("Gate2") as PuzzleGate
	await _stand(k2, 368, FLOOR, 30)
	await _stand(k1, 712)
	k2.health.apply_damage(99)
	await physics_frames(90)
	assert_true(k2.is_dead(), "holder dead")
	assert_false((_p("S2HoldPlate") as PressurePlate).is_active(), "a dead holder releases the plate")
	assert_eq(gate.state, GS.WAITING, "gate waits for P1")
	assert_true(await _walk_to(k1, 724), "P1 walks out unharmed")
	assert_false(k1.is_dead(), "P1 alive (team wipe is Phase 8)")


# --- 3 Two blades -----------------------------------------------------------------------------

func test_s3_targets_in_one_heartbeat() -> void:
	var lock := _p("S3Lock") as PuzzleLogic
	await _stand(k2, 1040)
	await _strike(k1, _p("S3TargetL"), 1)
	assert_eq(lock.state, LS.PARTIAL, "first target lit")
	await _strike(k2, _p("S3TargetR"), -1)
	assert_eq(lock.state, LS.COMPLETED, "second in time: completed")
	await physics_frames(30)
	assert_true((_p("Gate3") as PuzzleGate).is_open(), "Gate3 open")


func test_s3_failed_sync_resets_and_can_be_retried() -> void:
	var lock := _p("S3Lock") as PuzzleLogic
	await _strike(k1, _p("S3TargetL"), 1)
	await physics_frames(150)
	assert_eq(lock.failures, 1, "out of time: failed")
	await _strike(k2, _p("S3TargetR"), -1)
	assert_true(lock.state != LS.COMPLETED, "a late strike does not complete it")
	await physics_frames(150)
	await _strike(k1, _p("S3TargetL"), 1)
	await _strike(k2, _p("S3TargetR"), -1)
	assert_eq(lock.state, LS.COMPLETED, "retry succeeds")


# --- 4 Timed gate -----------------------------------------------------------------------------

func test_s4_one_strikes_one_runs() -> void:
	var gate := _p("Gate4") as PuzzleGate
	await _stand(k2, 1540)
	await _strike(k1, _p("S4LedgeSwitch"), -1, LEDGE_Y)
	assert_true(gate.is_open(), "the ledge switch opens Gate4")
	assert_true(await _walk_to(k2, 1650, [], 120), "P2 runs through in time")
	var closed := await _frames_until(func() -> bool: return gate.state == GS.CLOSED, 300)
	assert_true(closed >= 0, "the gate closes behind P2")
	await _stand(k1, 1560, FLOOR, 30)
	await _strike(k2, _p("S4FarSwitch"), -1)
	assert_true(gate.is_open(), "the far switch reopens it")
	assert_true(await _walk_to(k1, 1620, [], 120), "P1 follows")


func test_s4_cannot_be_done_alone() -> void:
	var gate := _p("Gate4") as PuzzleGate
	await _strike(k1, _p("S4LedgeSwitch"), -1, LEDGE_Y)
	assert_true(gate.is_open(), "opened")
	var made_it := await _walk_to(k1, 1610, [], 330)
	assert_false(made_it, "a lone knight cannot reach the gate before it closes")
	assert_eq(gate.state, GS.CLOSED, "closed")


func test_s4_timer_expiry_and_pause() -> void:
	var gate := _p("Gate4") as PuzzleGate
	var stats := run.player(1)
	stats.effects.add_tile_effect(PlayerEffects.SPEED_BOOST)
	await _strike(k1, _p("S4LedgeSwitch"), -1, LEDGE_Y)
	await physics_frames(30)
	var gate_left := gate.time_left
	var effect_left := stats.effects.remaining(PlayerEffects.SPEED_BOOST)
	get_tree().paused = true
	await physics_frames(90)
	assert_eq(gate.time_left, gate_left, "gate timer paused")
	assert_eq(stats.effects.remaining(PlayerEffects.SPEED_BOOST), effect_left, "speed effect paused with it")
	get_tree().paused = false
	var closed := await _frames_until(func() -> bool: return gate.state == GS.CLOSED, 300)
	assert_true(closed >= 0, "nobody passed: it closes")
	await physics_frames(10)
	await _attack(k1, -1)
	assert_true(gate.is_open(), "and opens again on the next strike")


# --- 5 Separate routes ------------------------------------------------------------------------

func test_s5_upper_and_lower_routes() -> void:
	var lock := _p("S5Lock") as PuzzleLogic
	# P1: climb the ladder to the upper route.
	await _stand(k1, 1672)
	Input.action_press(&"p1_move_up")
	var top := await _frames_until(func() -> bool: return k1.global_position.y <= BAND_Y + 0.5 and k1.state == Knight.State.GROUNDED, 300)
	Input.action_release(&"p1_move_up")
	assert_true(top >= 0, "P1 climbed to the upper route")
	assert_true(await _walk_to(k1, 2086, [1822]), "P1 crossed the upper route")
	assert_near(k1.global_position.y, BAND_Y, 1.0, "still on the upper route")
	# P2: the lower route.
	await _stand(k2, 1700)
	var split_seen := [false]
	rig.mode_changed.connect(func(_m: SplitScreenRig.Mode) -> void: split_seen[0] = split_seen[0] or rig.is_split())
	assert_true(await _walk_to(k2, 2086, [1868]), "P2 crossed the lower route")
	await _attack(k2, 1)
	assert_eq(lock.state, LS.PARTIAL, "one switch: partial")
	await _attack(k1, 1)
	assert_eq(lock.state, LS.COMPLETED, "both switches, two knights: completed")
	# Reunite: P1 drops from the end of the upper route.
	assert_true(await _walk_to(k1, 2180), "P1 walks off the upper route")
	await physics_frames(30)
	assert_near(k1.global_position.y, FLOOR, 1.0, "P1 back on the floor")
	assert_true(await _walk_to(k1, 2280) and await _walk_to(k2, 2260), "both pass Gate5 together")
	assert_eq(k1.safe_spot.fall_count + k2.safe_spot.fall_count, 0, "nobody fell out of the level")
	print("    (camera split while the routes were separated: %s)" % split_seen[0])


func test_s5_one_knight_on_both_switches_is_recoverable() -> void:
	var lock := _p("S5Lock") as PuzzleLogic
	await _strike(k1, _p("S5UpperSwitch"), 1, BAND_Y)
	await _strike(k1, _p("S5LowerSwitch"), 1)
	assert_eq(lock.state, LS.PARTIAL, "one knight cannot open it alone")
	await physics_frames(30)
	await _strike(k2, _p("S5LowerSwitch"), 1)
	assert_eq(lock.state, LS.COMPLETED, "the other knight re-strikes one switch: completed")


func test_s5_routes_work_with_roles_swapped() -> void:
	var lock := _p("S5Lock") as PuzzleLogic
	await _strike(k2, _p("S5UpperSwitch"), 1, BAND_Y)
	await _strike(k1, _p("S5LowerSwitch"), 1)
	assert_eq(lock.state, LS.COMPLETED, "either knight can take either route")


# --- 6 Both sides ---------------------------------------------------------------------------

func test_s6_each_knight_holds_the_gate_for_the_other() -> void:
	var gate := _p("Gate6") as PuzzleGate
	await _stand(k2, 2288, FLOOR, 30)
	assert_true(gate.is_open(), "left plate holds it")
	await _stand(k1, 2400)
	assert_true(await _walk_to(k1, 2608), "P1 passes to the right plate")
	await physics_frames(10)
	assert_true(await _walk_to(k2, 2500), "P2 passes while P1 holds the right plate")
	await _stand(k1, 2650, FLOOR, 20)
	await _stand(k2, 2520, FLOOR, 60)
	assert_eq(gate.state, GS.CLOSED, "closes when nobody holds it")


func test_s6_cannot_be_done_alone() -> void:
	var gate := _p("Gate6") as PuzzleGate
	await _stand(k1, 2288, FLOOR, 30)
	var made_it := await _walk_to(k1, 2480, [], 180)
	assert_false(made_it, "the gate closes before a lone knight reaches it")
	assert_eq(gate.state, GS.CLOSED, "closed")


# --- 7 Bridge ---------------------------------------------------------------------------------

func test_s7_bridge_carries_each_knight_across() -> void:
	var bridge := level.get_node("Platforms/BridgeS7") as MovingPlatform
	await _stand(k1, bridge.global_position.x + 24, FLOOR - 1)
	await _stand(k2, 2688, FLOOR, 4)
	var across := await _frames_until(func() -> bool: return bridge.progress >= 1.0, 400)
	assert_true(across >= 0, "near plate extends the bridge")
	assert_true(k1.is_on_floor() and absf(k1.global_position.y - bridge.global_position.y) < 1.0, "P1 rode it")
	assert_true(await _walk_to(k1, 3104), "P1 steps onto the far plate")
	await _stand(k2, 2650, FLOOR, 4)
	await physics_frames(20)
	assert_eq(bridge.progress, 1.0, "the far plate keeps it extended")
	await _stand(k1, 3200, FLOOR, 4)
	var home := await _frames_until(func() -> bool: return bridge.progress <= 0.0, 400)
	assert_true(home >= 0, "released: the bridge comes home")
	await _stand(k2, bridge.global_position.x + 24, FLOOR - 1)
	await _stand(k1, 3104, FLOOR, 4)
	across = await _frames_until(func() -> bool: return bridge.progress >= 1.0, 400)
	assert_true(across >= 0, "the far plate brings it across with P2")
	assert_true(await _walk_to(k2, 3080), "P2 steps off on the far side")
	assert_eq(k1.safe_spot.fall_count + k2.safe_spot.fall_count, 0, "nobody fell")
	var platforms := level.find_children("*", "AnimatableBody2D", true, false)
	assert_eq(platforms.size(), 1, "one bridge instance, never duplicated")


func test_s7_falling_rider_is_recoverable() -> void:
	var bridge := level.get_node("Platforms/BridgeS7") as MovingPlatform
	await _stand(k1, 2660, FLOOR, 20)  # safe ground on the near side (off the plate)
	await _stand(k1, bridge.global_position.x + 24, FLOOR - 1)
	await _stand(k2, 2688, FLOOR, 4)
	await physics_frames(150)  # mid-pit
	k1.safe_spot.resolve_fall(null)
	await physics_frames(5)
	assert_lt(k1.global_position.x, 2720.0, "P1 respawned on the near side")
	await _stand(k2, 2650, FLOOR, 4)
	var home := await _frames_until(func() -> bool: return bridge.progress <= 0.0, 400)
	assert_true(home >= 0, "the bridge returns: the crossing can be retried")


# --- 8 Distraction ----------------------------------------------------------------------------

func test_s8_one_lures_the_slime_while_the_other_strikes() -> void:
	var slime := level.get_node("Enemies/GuardS8") as Slime
	var gate := _p("Gate8") as PuzzleGate
	await _stand(k1, 3392)
	var lured := await _frames_until(func() -> bool: return slime.target == k1, 120)
	assert_true(lured >= 0, "the slime targets P1")
	assert_true(await _walk_to(k1, 3330), "P1 backs away")
	var away := await _frames_until(func() -> bool: return slime.global_position.x < 3420.0, 240)
	assert_true(away >= 0, "the slime follows P1 away from the switch")
	var hp := k2.health.current_health
	await _strike(k2, _p("S8Switch"), 1)
	await physics_frames(30)
	assert_true(gate.is_open(), "P2 opened Gate8")
	assert_eq(k2.health.current_health, hp, "P2 was not touched")


func test_s8_slime_ignores_dead_knights_and_never_triggers_the_switch() -> void:
	var slime := level.get_node("Enemies/GuardS8") as Slime
	await _stand(k1, 3420)
	var lured := await _frames_until(func() -> bool: return slime.target == k1, 120)
	assert_true(lured >= 0, "targets P1")
	k1.health.apply_damage(99)
	await physics_frames(10)
	assert_true(slime.target != k1, "a dead knight is no longer a target")
	await physics_frames(300)
	assert_eq((_p("S8Switch") as AttackSwitch).activations, 0, "the patrolling slime never activates the switch")


# --- 9 Controlled risk ------------------------------------------------------------------------

func test_s9_one_pays_both_pass() -> void:
	var gate := _p("Gate9") as PuzzleGate
	var hp2 := k2.health.current_health
	var hp1 := k1.health.current_health
	await _stand(k2, 3712, FLOOR, 30)
	assert_eq(k2.health.current_health, hp2 - 1, "the holder pays 1 HP on the hot plate")
	assert_true(gate.is_open(), "Gate9 open")
	await _stand(k1, 3800)
	assert_true(await _walk_to(k1, 3984), "P1 passes to the safe plate")
	await physics_frames(60)
	assert_eq(k2.health.current_health, hp2 - 1, "standing on does not cost more")
	assert_true(await _walk_to(k2, 3950), "P2 passes while P1 holds")
	assert_eq(k1.health.current_health, hp1, "P1 unharmed")
	assert_false(k2.is_dead(), "the risk is survivable")


func test_s9_cannot_be_done_alone() -> void:
	await _stand(k1, 3712, FLOOR, 30)
	var made_it := await _walk_to(k1, 3950, [], 180)
	assert_false(made_it, "the gate closes before a lone knight reaches it")


# --- 10 End and clues -------------------------------------------------------------------------

func test_end_zone_needs_both_knights() -> void:
	var zone := _p("EndZone") as TriggerZone
	await _stand(k1, 4090, FLOOR, 10)
	assert_false(zone.is_active(), "one knight is not a reunion")
	await _stand(k2, 4120, FLOOR, 10)
	assert_true(zone.is_active(), "both knights together")


func test_clues_are_short_and_reveal_when_near() -> void:
	var clues := level.get_node("Clues").get_children()
	assert_eq(clues.size(), 10, "a clue in every section")
	for clue: PuzzleClue in clues:
		assert_true(clue.lines().size() <= 2, "%s: at most two lines" % clue.name)
		for line in clue.lines():
			assert_true(line.length() <= 24, "%s: short line '%s'" % [clue.name, line])
	var near := level.get_node("Clues/ClueS3") as PuzzleClue
	await _stand(k1, 100)
	await _stand(k2, 120, FLOOR, 4)
	assert_near(near.reveal, PuzzleConfig.new().clue_min_alpha, 0.01, "dim from far away")
	await _stand(k1, near.global_position.x, FLOOR, 4)
	assert_near(near.reveal, 1.0, 0.01, "fully readable up close")


# --- Persistence and scope ----------------------------------------------------------------------

func test_reload_keeps_completed_puzzles_and_upgrades() -> void:
	run.player(1).collect_jar(PlayerStats.JarType.GREEN)
	await _stand(k1, 144)
	await _stand(k2, 208, FLOOR, 30)
	(_p("S2FarSwitch") as AttackSwitch).activate(1)
	await _stand(k2, 368, FLOOR, 10)  # a held plate: temporary, never saved
	await _reload_room()
	assert_eq((_p("S1Lock") as PuzzleLogic).state, LS.COMPLETED, "completed lock restored")
	assert_eq((_p("Gate1") as PuzzleGate).state, GS.OPEN, "latched gate open at once")
	assert_true((_p("S2FarSwitch") as AttackSwitch).is_active(), "latched switch restored")
	assert_false((_p("S2HoldPlate") as PressurePlate).is_active(), "held plate starts released")
	assert_eq((_p("S3Lock") as PuzzleLogic).state, LS.INACTIVE, "untouched puzzles unchanged")
	assert_eq(k1.health.max_health, 4, "the jar upgrade survived the reload")
	RunState.reset()
	await _reload_room()
	assert_eq((_p("S1Lock") as PuzzleLogic).state, LS.INACTIVE, "a new run starts with every puzzle reset")
	assert_eq((_p("Gate1") as PuzzleGate).state, GS.CLOSED, "gate closed in a new run")


func test_snapshot_restore_updates_live_puzzles() -> void:
	(_p("S3TargetL") as AttackSwitch).activate(1)
	(_p("S3TargetR") as AttackSwitch).activate(2)
	var data: Dictionary = JSON.parse_string(JSON.stringify(run.snapshot()))
	assert_true(data.puzzles.states.has("dev/puzzle_test"), "puzzle states in the run snapshot")
	RunState.reset()
	await _reload_room()
	assert_eq((_p("S3Lock") as PuzzleLogic).state, LS.INACTIVE, "fresh run: not completed")
	assert_true(RunState.current().restore(data), "restore accepted")
	await physics_frames(30)
	assert_eq((_p("S3Lock") as PuzzleLogic).state, LS.COMPLETED, "live lock re-read its state")
	assert_true((_p("Gate3") as PuzzleGate).is_open(), "and its gate opened")


func test_every_puzzle_id_is_unique_and_registered() -> void:
	var ids := []
	for node in level.get_node("Puzzles").get_children():
		if node is PuzzleSource and node.puzzle_id != "":
			assert_false(ids.has(node.puzzle_id), "unique id %s" % node.puzzle_id)
			ids.append(node.puzzle_id)
	ids.sort()
	assert_eq(run.puzzles.live_ids("dev/puzzle_test"), ids, "all registered under the level id")


func test_split_screen_does_not_affect_puzzles() -> void:
	await _stand(k1, 144)
	await _stand(k2, 3984, FLOOR, 40)
	assert_true(rig.is_split(), "knights far apart: split screen")
	assert_true((_p("Gate9") as PuzzleGate).is_open(), "P2's plate works in its own view")
	assert_eq((_p("S1Lock") as PuzzleLogic).state, LS.PARTIAL, "P1's plate works in the other view")
	await _stand(k2, 208, FLOOR, 30)
	assert_eq((_p("S1Lock") as PuzzleLogic).state, LS.COMPLETED, "completed after reuniting")
