extends GameTestCase
## Advanced platforms in the real hazard room (floor y=512). Room platforms: MovingH (576,480)
## over a pit, MovingV (736,496) rising to the ledge at y=336. Behaviour tests spawn their own
## platforms with known timings over the open landing floor at x 1350-1700.

const ROOM := "res://scenes/dev/hazard_test_room.tscn"
const MOVING := "res://scenes/platforms/moving_platform.tscn"
const TIMED := "res://scenes/platforms/timed_platform.tscn"
const BLINK := "res://scenes/platforms/disappearing_platform.tscn"
const CRUMBLE := "res://scenes/platforms/collapsing_platform.tscn"
const GREEN := "res://scenes/enemies/green_slime.tscn"
const FLOOR := 512.0
const OPEN_X := 1400.0
const PLATFORM_Y := 480.0
const ALL_ACTIONS := [&"p1_move_left", &"p1_move_right", &"p1_move_up", &"p1_move_down", &"p1_attack",
	&"p2_move_left", &"p2_move_right", &"p2_move_up", &"p2_move_down", &"p2_attack"]
const TS := TimedPlatform.State
const CS := CollapsingPlatform.State

var room: Node
var level: Node2D
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
	rig.snap_to_targets()
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
	level.add_child(node)
	return node


func _platform(node_name: String) -> PlatformBody:
	return level.get_node("Platforms/" + node_name) as PlatformBody


## The physics shape really is (or is not) collidable.
func _solid(platform: PlatformBody) -> bool:
	for child in platform.get_children(true):
		if child is CollisionShape2D:
			return not (child as CollisionShape2D).disabled
	return false


func _frames_until(condition: Callable, limit: int) -> int:
	for i in limit:
		if condition.call():
			return i
		await physics_frames(1)
	return -1


# --- Moving platforms -------------------------------------------------------------------

func test_moving_platform_ping_pong_with_pause() -> void:
	var p := _spawn(MOVING, Vector2(OPEN_X, 440), {"travel": Vector2(64, 0), "speed": 64.0, "pause_time": 0.5}) as MovingPlatform
	await physics_frames(61)
	assert_near(p.position.x, OPEN_X + 64.0, 1.5, "reached the far end after 1 s")
	assert_eq(p.arrivals, 1, "one arrival")
	var x := p.position.x
	await physics_frames(25)
	assert_near(p.position.x, x, 0.01, "pauses at the end")
	await physics_frames(70)
	assert_near(p.position.x, OPEN_X, 1.5, "came back to the start")
	assert_eq(p.arrivals, 2, "two arrivals")


func test_moving_platform_one_shot_stops_at_end() -> void:
	var p := _spawn(MOVING, Vector2(OPEN_X, 440), {"travel": Vector2(0, -48), "speed": 96.0, "ping_pong": false}) as MovingPlatform
	await physics_frames(150)
	assert_near(p.position.y, 440.0 - 48.0, 0.5, "stays at the far end")
	assert_eq(p.arrivals, 1, "arrived once")


func test_moving_platform_carries_both_knights() -> void:
	var p := _platform("MovingH") as MovingPlatform
	k1.teleport_to(p.global_position + Vector2(10, -1))
	k2.teleport_to(p.global_position + Vector2(38, -1))
	await physics_frames(10)
	var off1 := k1.global_position.x - p.global_position.x
	var off2 := k2.global_position.x - p.global_position.x
	var start_x := p.global_position.x
	await physics_frames(60)
	assert_gt(absf(p.global_position.x - start_x), 20.0, "the platform moved")
	assert_true(k1.is_on_floor() and k2.is_on_floor(), "both still standing")
	assert_near(k1.global_position.x - p.global_position.x, off1, 1.0, "P1 carried with it")
	assert_near(k2.global_position.x - p.global_position.x, off2, 1.0, "P2 carried with it")
	assert_near(k1.global_position.y, p.global_position.y, 1.0, "P1 on the surface")
	assert_eq(k1.safe_spot.fall_count + k2.safe_spot.fall_count, 0, "nobody fell")


func test_vertical_platform_lifts_knight_to_the_ledge() -> void:
	var p := _platform("MovingV") as MovingPlatform
	k1.teleport_to(p.global_position + Vector2(16, -1))
	var lowest_gap := [0.0]
	var reached := await _frames_until(func() -> bool:
		lowest_gap[0] = maxf(lowest_gap[0], absf(k1.global_position.y - p.global_position.y))
		return p.position.y <= p.start_position.y - 159.0, 360)
	assert_true(reached >= 0, "platform reached the top")
	assert_near(k1.global_position.y, 336.0, 1.5, "knight lifted to ledge height")
	assert_lt(lowest_gap[0], 3.0, "knight stayed on the platform while rising")
	Input.action_press(&"p1_move_right")
	await physics_frames(40)
	Input.action_release(&"p1_move_right")
	await physics_frames(5)
	assert_gt(k1.global_position.x, 772.0, "walked onto the ledge")
	assert_near(k1.global_position.y, 336.0, 0.5, "standing on the ledge")


func test_vertical_platform_lowers_knight_without_dropping_it() -> void:
	var p := _spawn(MOVING, Vector2(OPEN_X, 400), {"travel": Vector2(0, 64), "speed": 60.0, "start_delay": 0.3}) as MovingPlatform
	k1.teleport_to(Vector2(OPEN_X + 24, 399))
	await physics_frames(18)
	var airborne := 0
	for i in 60:
		await physics_frames(1)
		if absf(k1.global_position.y - p.global_position.y) > 3.0:
			airborne += 1
	assert_eq(airborne, 0, "knight followed the platform down")


func test_one_way_moving_platform_can_be_jumped_through_and_dropped_from() -> void:
	var p := _spawn(MOVING, Vector2(OPEN_X, PLATFORM_Y), {"travel": Vector2(8, 0), "speed": 4.0}) as MovingPlatform
	k1.teleport_to(Vector2(OPEN_X + 24, FLOOR))
	await physics_frames(10)
	Input.action_press(&"p1_move_up")
	await physics_frames(18)  # a held (full) jump
	Input.action_release(&"p1_move_up")
	await physics_frames(50)
	assert_near(k1.global_position.y, p.global_position.y, 1.0, "jumped up through and landed on it")
	assert_eq(k1.floor_kind, Knight.FloorKind.ONE_WAY, "classified as one-way floor")
	Input.action_press(&"p1_move_down")
	await physics_frames(30)
	Input.action_release(&"p1_move_down")
	await physics_frames(10)
	assert_near(k1.global_position.y, FLOOR, 0.5, "dropped through to the floor")


func test_solid_platform_blocks_from_below() -> void:
	_spawn(MOVING, Vector2(OPEN_X, 470), {"travel": Vector2(4, 0), "speed": 1.0, "one_way": false})
	k1.teleport_to(Vector2(OPEN_X + 24, FLOOR))
	await physics_frames(5)
	var top := [INF]
	Input.action_press(&"p1_move_up")
	await physics_frames(2)
	Input.action_release(&"p1_move_up")
	for i in 50:
		await physics_frames(1)
		top[0] = minf(top[0], k1.global_position.y)
	assert_gt(top[0], 470.0 + 9.0 + 18.0 - 1.0, "head stopped by the solid underside")


func test_slime_rides_a_moving_platform() -> void:
	var p := _spawn(MOVING, Vector2(OPEN_X, 440), {"width_tiles": 4, "travel": Vector2(48, 0), "speed": 30.0}) as MovingPlatform
	var slime := _spawn(GREEN, Vector2(OPEN_X + 32, 438), {"patrol_left": 0.0, "patrol_right": 0.0}) as Slime
	await physics_frames(20)
	for i in 120:
		await physics_frames(1)
		if absf(slime.global_position.y - p.global_position.y) > 3.0:
			fail("slime left the platform surface at frame %d" % i)
			return
	assert_gt(p.position.x - OPEN_X, 10.0, "platform moved under the slime")


func test_moving_platforms_are_not_safe_ground() -> void:
	var p := _platform("MovingH")
	await physics_frames(20)
	var before := k1.safe_spot.last_safe_position
	k1.teleport_to(p.global_position + Vector2(24, -1))
	await physics_frames(60)
	assert_true(k1.is_on_floor(), "standing on the platform")
	assert_false(k1.safe_spot.is_safe_now(), "not safe")
	assert_eq(k1.safe_spot.last_safe_position, before, "not recorded")


# --- Timed platforms --------------------------------------------------------------------

func test_triggered_timed_platform_full_cycle() -> void:
	var p := _spawn(TIMED, Vector2(OPEN_X, PLATFORM_Y), {"start_active": false, "auto_reactivate": false,
		"active_time": 1.0, "warning_time": 0.5, "disabled_time": 0.5}) as TimedPlatform
	await physics_frames(3)
	assert_eq(p.state, TS.INACTIVE, "waits for a trigger")
	assert_false(_solid(p), "no collision while inactive")
	var states: Array = []
	p.state_changed.connect(func(s: TimedPlatform.State) -> void: states.append(s))
	p.activate()
	await physics_frames(30)
	assert_eq(p.state, TS.ACTIVE, "active after the fade-in")
	assert_true(_solid(p), "solid while active")
	await physics_frames(66)
	assert_eq(p.state, TS.WARNING, "warning before disabling")
	assert_true(_solid(p), "still solid during the warning")
	await physics_frames(33)
	assert_eq(p.state, TS.DISABLED, "disabled")
	assert_false(_solid(p), "no collision while disabled")
	await physics_frames(35)
	assert_eq(p.state, TS.INACTIVE, "back to inactive (no auto reactivation)")
	assert_eq(states, [TS.REACTIVATING, TS.ACTIVE, TS.WARNING, TS.DISABLED, TS.INACTIVE], "state order")


func test_knight_falls_when_timed_platform_disables() -> void:
	var p := _spawn(TIMED, Vector2(OPEN_X, PLATFORM_Y), {"active_time": 0.5, "warning_time": 0.3, "disabled_time": 2.0}) as TimedPlatform
	k1.teleport_to(Vector2(OPEN_X + 16, PLATFORM_Y - 1))
	await physics_frames(20)
	assert_near(k1.global_position.y, PLATFORM_Y, 1.0, "standing on it")
	await physics_frames(50)
	assert_eq(p.state, TS.DISABLED, "disabled")
	assert_near(k1.global_position.y, FLOOR, 0.5, "fell to the floor below")


func test_timed_platform_never_reappears_inside_a_knight() -> void:
	var p := _spawn(BLINK, Vector2(OPEN_X, 500), {"active_time": 0.3, "warning_time": 0.2, "disabled_time": 0.3}) as TimedPlatform
	k1.teleport_to(Vector2(OPEN_X - 40, FLOOR))
	await physics_frames(40)  # now disabled
	assert_eq(p.state, TS.DISABLED, "disabled")
	k1.teleport_to(Vector2(OPEN_X + 16, FLOOR))  # stands where the platform would appear
	await physics_frames(80)
	assert_eq(p.state, TS.REACTIVATING, "waits while occupied")
	assert_false(_solid(p), "no collision inside the knight")
	k1.teleport_to(Vector2(OPEN_X - 40, FLOOR))
	await physics_frames(5)
	assert_eq(p.state, TS.ACTIVE, "reappears once the space is clear")
	assert_true(_solid(p), "solid again")


func test_disappearing_platform_schedule_and_offset() -> void:
	var a := _spawn(BLINK, Vector2(OPEN_X, PLATFORM_Y)) as TimedPlatform
	var b := _spawn(BLINK, Vector2(OPEN_X + 64, PLATFORM_Y), {"start_offset": 1.5}) as TimedPlatform
	await physics_frames(36)  # 0.6 s
	assert_eq(a.state, TS.ACTIVE, "A still active")
	assert_eq(b.state, TS.WARNING, "B is 1.5 s ahead: warning")
	await physics_frames(150)  # 3.1 s
	assert_eq(a.state, TS.DISABLED, "A invisible after active + warning")
	assert_false(_solid(a), "A has no collision")
	await physics_frames(144)  # 5.5 s: reactivation (0.4 s) is over
	assert_eq(a.state, TS.ACTIVE, "A back again (schedule repeats)")


func test_timed_platform_pauses_with_the_game() -> void:
	var p := _spawn(BLINK, Vector2(OPEN_X, PLATFORM_Y)) as TimedPlatform
	await physics_frames(30)
	var t := p.time_in_state
	get_tree().paused = true
	await physics_frames(120)
	assert_eq(p.time_in_state, t, "no time passes while paused")
	assert_eq(p.state, TS.ACTIVE, "state unchanged")
	get_tree().paused = false
	await physics_frames(30)
	assert_near(p.time_in_state, t + 0.5, 0.02, "resumes")


# --- Collapsing platforms ---------------------------------------------------------------

func test_collapsing_platform_cycle() -> void:
	var p := _spawn(CRUMBLE, Vector2(OPEN_X, PLATFORM_Y)) as CollapsingPlatform
	await physics_frames(5)
	assert_eq(p.state, CS.STABLE, "stable")
	k1.teleport_to(Vector2(OPEN_X + 16, PLATFORM_Y - 4))
	var landed := await _frames_until(func() -> bool: return p.state == CS.SHAKING, 30)
	assert_true(landed >= 0, "landing starts the shake")
	assert_true(_solid(p), "solid while shaking")
	await physics_frames(40)
	assert_eq(p.state, CS.COLLAPSED, "collapsed after the delay")
	assert_false(_solid(p), "no collision")
	await physics_frames(20)
	assert_near(k1.global_position.y, FLOOR, 0.5, "knight fell through")
	k1.teleport_to(Vector2(OPEN_X - 40, FLOOR))
	await physics_frames(3 * 60 + 30)
	assert_eq(p.state, CS.STABLE, "reappeared after the recovery time")
	assert_true(_solid(p), "solid again")
	assert_eq(p.collapses, 1, "collapsed once")


func test_collapsing_platform_ignores_knights_below_and_beside() -> void:
	var p := _spawn(CRUMBLE, Vector2(OPEN_X, PLATFORM_Y)) as CollapsingPlatform
	k1.teleport_to(Vector2(OPEN_X - 30, FLOOR))
	await physics_frames(5)
	Input.action_press(&"p1_move_right")
	await physics_frames(50)  # walks right under it
	Input.action_release(&"p1_move_right")
	await physics_frames(5)
	assert_gt(k1.global_position.x, OPEN_X + 32.0, "walked past underneath")
	assert_eq(p.state, CS.STABLE, "still stable")
	k1.teleport_to(Vector2(OPEN_X + 16, FLOOR))
	Input.action_press(&"p1_move_up")
	await physics_frames(2)
	Input.action_release(&"p1_move_up")
	# Jumping up through the one-way platform does not count until the knight lands on it.
	var shaking_while_rising := false
	for i in 12:
		await physics_frames(1)
		if k1.velocity.y < 0.0 and p.state != CS.STABLE:
			shaking_while_rising = true
	assert_false(shaking_while_rising, "passing up through does not trigger it")


func test_collapsing_platform_waits_for_clear_space() -> void:
	var p := _spawn(CRUMBLE, Vector2(OPEN_X, 500), {"collapse_delay": 0.2, "recovery_time": 0.5}) as CollapsingPlatform
	k1.teleport_to(Vector2(OPEN_X + 16, 499))
	await physics_frames(30)
	assert_eq(p.state, CS.COLLAPSED, "collapsed under the knight")
	assert_near(k1.global_position.y, FLOOR, 0.5, "knight on the floor, inside the platform's space")
	await physics_frames(90)
	assert_eq(p.state, CS.REAPPEARING, "does not reappear inside the knight")
	assert_false(_solid(p), "no collision")
	k1.teleport_to(Vector2(OPEN_X - 40, FLOOR))
	await physics_frames(5)
	assert_eq(p.state, CS.STABLE, "reappears once clear")


func test_permanent_collapse_stays_gone() -> void:
	var p := _spawn(CRUMBLE, Vector2(OPEN_X, PLATFORM_Y), {"permanent": true, "collapse_delay": 0.2, "recovery_time": 0.5}) as CollapsingPlatform
	k1.teleport_to(Vector2(OPEN_X + 16, PLATFORM_Y - 1))
	await physics_frames(30)
	k1.teleport_to(Vector2(OPEN_X - 40, FLOOR))
	await physics_frames(120)
	assert_eq(p.state, CS.COLLAPSED, "permanently collapsed")
	assert_false(_solid(p), "no collision")


func test_collapsing_platform_is_never_a_respawn_point() -> void:
	var p := _spawn(CRUMBLE, Vector2(OPEN_X, PLATFORM_Y), {"collapse_delay": 5.0}) as CollapsingPlatform
	await physics_frames(20)
	var before := k1.safe_spot.last_safe_position
	k1.teleport_to(Vector2(OPEN_X + 16, PLATFORM_Y - 1))
	await physics_frames(60)
	assert_eq(p.state, CS.SHAKING, "standing on it")
	assert_eq(k1.safe_spot.last_safe_position, before, "not recorded as safe")


func test_fall_from_room_collapsing_platform_respawns_on_safe_ground() -> void:
	var p := _platform("CrumbleA") as CollapsingPlatform
	k1.teleport_to(Vector2(1176, FLOOR))  # the safe floor between pits
	await physics_frames(20)
	var safe := k1.safe_spot.last_safe_position
	k1.teleport_to(p.global_position + Vector2(16, -1))
	await physics_frames(150)
	assert_eq(k1.safe_spot.fall_count, 1, "fell once into the pit")
	assert_near(k1.global_position.x, safe.x, 1.0, "back on the safe floor, not the platform")
