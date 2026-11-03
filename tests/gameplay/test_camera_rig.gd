extends GameTestCase
## SplitScreenRig in the real camera test room. Level (pixels): bounds 0,0 - 1920,960;
## floor surface y=928; tower ladder x=1544 up to the tower top y=160; far right x=1848.
## Some tests freeze the knights (physics off) and place them directly so the camera
## geometry is exact; others drive real movement input.

const ROOM := "res://scenes/dev/camera_test_room.tscn"
const FLOOR := 928.0
const ALL_ACTIONS := [&"p1_move_left", &"p1_move_right", &"p1_move_up", &"p1_move_down", &"p1_attack",
	&"p2_move_left", &"p2_move_right", &"p2_move_up", &"p2_move_down", &"p2_attack"]
const Mode := SplitScreenRig.Mode
const O := CameraMath.Orientation

var room: Node
var rig: SplitScreenRig
var k1: Knight
var k2: Knight


func before_each() -> void:
	for a in ALL_ACTIONS:
		Input.action_release(a)
	room = (load(ROOM) as PackedScene).instantiate()
	add_child(room)
	rig = room.get_node("SplitScreenRig")
	k1 = room.get("knight_1")
	k2 = room.get("knight_2")
	await physics_frames(5)


func after_each() -> void:
	for a in ALL_ACTIONS:
		Input.action_release(a)
	room.queue_free()
	await physics_frames(2)


func _freeze_at(k: Knight, at: Vector2) -> void:
	k.set_physics_process(false)
	k.global_position = at


func _body_centre(k: Knight) -> Vector2:
	return k.global_position + Vector2(0, -9)


func _sees(view: int, k: Knight) -> bool:
	return rig.view_world_rect(view).has_point(_body_centre(k))


# --- Structure ----------------------------------------------------------------------

func test_shared_mode_at_start() -> void:
	await physics_frames(30)
	assert_eq(rig.mode, Mode.SHARED, "starts shared with knights together")
	assert_eq(rig.view_screen_rect(SplitScreenRig.VIEW_A), Rect2i(0, 0, 640, 360), "one full-screen view")
	assert_false(rig.get_node("ViewB").visible, "view B hidden")
	assert_eq(rig.viewport(SplitScreenRig.VIEW_B).render_target_update_mode, SubViewport.UPDATE_DISABLED, "view B not rendering")
	assert_false(rig.get_node("Divider").visible, "no divider")
	assert_true(_sees(SplitScreenRig.VIEW_A, k1) and _sees(SplitScreenRig.VIEW_A, k2), "both knights visible")
	assert_eq(rig.get_targets(), [k1, k2] as Array[Node2D], "P1 then P2")


func test_world_is_simulated_once() -> void:
	assert_eq(get_tree().get_nodes_in_group(&"knights").size(), 2, "exactly two knights exist")
	assert_true(rig.world_root.is_ancestor_of(k1) and rig.world_root.is_ancestor_of(k2), "knights live in view A's world")
	var vb := rig.viewport(SplitScreenRig.VIEW_B)
	assert_eq(vb.get_child_count(), 1, "view B contains only its camera")
	assert_true(vb.get_child(0) is Camera2D, "view B child is the camera")
	assert_true(vb.world_2d == rig.viewport(SplitScreenRig.VIEW_A).world_2d, "view B shares view A's World2D")
	assert_true(k1.get_world_2d() == rig.viewport(SplitScreenRig.VIEW_A).world_2d, "physics runs in the shared world")
	assert_eq(room.find_children("*", "TileMapLayer", true, false).size(), 1, "one terrain layer")
	assert_eq(room.find_children("*", "SubViewport", true, false).size(), 2, "two viewports")
	assert_eq(room.find_children("*", "CameraBounds", true, false).size(), 1, "one bounds node")


func test_pixel_art_settings() -> void:
	assert_eq(rig.size, Vector2(640, 360), "rig covers the 640x360 logical screen")
	for view in [SplitScreenRig.VIEW_A, SplitScreenRig.VIEW_B]:
		var vp := rig.viewport(view)
		assert_eq(vp.canvas_item_default_texture_filter, Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST, "view %d nearest filter" % view)
		assert_true(vp.snap_2d_transforms_to_pixel, "view %d snaps transforms" % view)
		assert_eq(rig.camera(view).zoom, Vector2.ONE, "view %d zoom 1" % view)
	assert_true(rig.has_bounds, "bounds found in the level")
	assert_eq(rig.bounds, Rect2(0, 0, 1920, 960), "bounds match the level")


# --- Split, orientation and assignment ---------------------------------------------

func test_horizontal_separation_splits_side_by_side() -> void:
	_freeze_at(k1, Vector2(400, FLOOR))
	_freeze_at(k2, Vector2(1400, FLOOR))
	await physics_frames(60)
	assert_eq(rig.mode, Mode.SPLIT, "split")
	assert_eq(rig.orientation, O.SIDE_BY_SIDE, "vertical divider")
	assert_eq(rig.view_screen_rect(SplitScreenRig.VIEW_A), Rect2i(0, 0, 320, 360), "P1 view on the left")
	assert_eq(rig.view_screen_rect(SplitScreenRig.VIEW_B), Rect2i(320, 0, 320, 360), "P2 view on the right")
	assert_eq(rig.viewport(SplitScreenRig.VIEW_A).size, Vector2i(320, 360), "viewport A resized")
	assert_eq(rig.viewport(SplitScreenRig.VIEW_B).size, Vector2i(320, 360), "viewport B resized")
	assert_true(rig.get_node("Divider").visible, "divider shown")
	assert_true(_sees(SplitScreenRig.VIEW_A, k1), "P1 in view A")
	assert_true(_sees(SplitScreenRig.VIEW_B, k2), "P2 in view B")
	assert_false(_sees(SplitScreenRig.VIEW_A, k2), "view A does not follow P2")


func test_vertical_separation_splits_stacked() -> void:
	_freeze_at(k1, Vector2(1592, 160))   # tower top
	_freeze_at(k2, Vector2(1544, FLOOR))  # tower foot
	await physics_frames(60)
	assert_eq(rig.mode, Mode.SPLIT, "split")
	assert_eq(rig.orientation, O.STACKED, "horizontal divider")
	assert_eq(rig.view_screen_rect(SplitScreenRig.VIEW_A), Rect2i(0, 0, 640, 180), "P1 view on top")
	assert_eq(rig.view_screen_rect(SplitScreenRig.VIEW_B), Rect2i(0, 180, 640, 180), "P2 view at the bottom")
	assert_true(_sees(SplitScreenRig.VIEW_A, k1), "P1 in the top view")
	assert_true(_sees(SplitScreenRig.VIEW_B, k2), "P2 in the bottom view")


func test_assignment_is_fixed_even_when_knights_cross() -> void:
	_freeze_at(k1, Vector2(1400, FLOOR))  # P1 on the right of P2
	_freeze_at(k2, Vector2(400, FLOOR))
	await physics_frames(60)
	assert_eq(rig.orientation, O.SIDE_BY_SIDE, "side by side")
	assert_true(_sees(SplitScreenRig.VIEW_A, k1), "P1 still uses view A (left)")
	assert_true(_sees(SplitScreenRig.VIEW_B, k2), "P2 still uses view B (right)")


func test_split_triggers_at_threshold_while_walking() -> void:
	k1.teleport_to(Vector2(900, FLOOR))
	k2.teleport_to(Vector2(940, FLOOR))
	rig.snap_to_targets()
	await physics_frames(20)
	var safe := rig.full_view_size().x - rig.config.safe_margin.x * 2.0
	var expected := rig.config.split_enter_ratio * safe
	Input.action_press(&"p1_move_left")
	Input.action_press(&"p2_move_right")
	var dx_at_split := -1.0
	for i in 240:
		await physics_frames(1)
		if rig.mode != Mode.SHARED:
			dx_at_split = k2.global_position.x - k1.global_position.x
			break
		assert_true(_sees(SplitScreenRig.VIEW_A, k1) and _sees(SplitScreenRig.VIEW_A, k2), "both visible before the split (frame %d)" % i)
	Input.action_release(&"p1_move_left")
	Input.action_release(&"p2_move_right")
	assert_gt(dx_at_split, expected - 0.01, "split no earlier than the threshold")
	assert_lt(dx_at_split, expected + 6.0, "split within one tick of the threshold")
	assert_eq(rig.orientation, O.SIDE_BY_SIDE, "walking apart horizontally gives side by side")


func test_independent_tracking() -> void:
	k1.teleport_to(Vector2(400, FLOOR))
	k2.teleport_to(Vector2(1400, FLOOR))
	await physics_frames(60)
	var b_before := rig.camera_center(SplitScreenRig.VIEW_B)
	var a_before := rig.camera_center(SplitScreenRig.VIEW_A)
	Input.action_press(&"p1_move_right")
	await physics_frames(40)
	Input.action_release(&"p1_move_right")
	await physics_frames(150)  # let P1's camera finish easing
	assert_gt(rig.camera_center(SplitScreenRig.VIEW_A).x - a_before.x, 30.0, "P1's camera followed P1")
	assert_eq(rig.camera_center(SplitScreenRig.VIEW_B), b_before, "P2's camera did not move")
	a_before = rig.camera_center(SplitScreenRig.VIEW_A)
	b_before = rig.camera_center(SplitScreenRig.VIEW_B)
	Input.action_press(&"p2_move_left")
	await physics_frames(40)
	Input.action_release(&"p2_move_left")
	await physics_frames(30)
	assert_lt(rig.camera_center(SplitScreenRig.VIEW_B).x - b_before.x, -30.0, "P2's camera followed P2")
	assert_eq(rig.camera_center(SplitScreenRig.VIEW_A), a_before, "P1's camera did not move")


# --- Merge and stability -------------------------------------------------------------

func test_reunification_by_walking() -> void:
	k1.teleport_to(Vector2(600, FLOOR))
	k2.teleport_to(Vector2(1100, FLOOR))  # x 1152-1456 is the corridor; stay outside it
	await physics_frames(40)
	assert_eq(rig.mode, Mode.SPLIT, "split while apart")
	var modes: Array = [rig.mode]
	rig.mode_changed.connect(func(m: SplitScreenRig.Mode) -> void: modes.append(m))
	Input.action_press(&"p2_move_left")
	for i in 400:
		await physics_frames(1)
		if rig.mode == Mode.SHARED:
			break
		if rig.mode != Mode.SHARED:
			assert_true(_sees(SplitScreenRig.VIEW_A, k1), "P1 visible in its view (frame %d)" % i)
			assert_true(_sees(SplitScreenRig.VIEW_B, k2), "P2 visible in its view (frame %d)" % i)
	Input.action_release(&"p2_move_left")
	assert_eq(rig.mode, Mode.SHARED, "merged back to shared")
	assert_eq(modes, [Mode.SPLIT, Mode.MERGING, Mode.SHARED], "split -> merging -> shared")
	assert_eq(rig.viewport(SplitScreenRig.VIEW_B).render_target_update_mode, SubViewport.UPDATE_DISABLED, "view B stops rendering")
	assert_false(rig.get_node("Divider").visible, "divider hidden")
	assert_true(_sees(SplitScreenRig.VIEW_A, k1) and _sees(SplitScreenRig.VIEW_A, k2), "both visible after the merge")


func test_reunification_initiated_by_either_player() -> void:
	for mover in [k1, k2]:
		k1.teleport_to(Vector2(600, FLOOR))
		k2.teleport_to(Vector2(1100, FLOOR))
		rig.snap_to_targets()
		await physics_frames(10)
		assert_eq(rig.mode, Mode.SPLIT, "split before reuniting")
		var action := &"p1_move_right" if mover == k1 else &"p2_move_left"
		Input.action_press(action)
		for i in 400:
			await physics_frames(1)
			if rig.mode == Mode.SHARED:
				break
		Input.action_release(action)
		assert_eq(rig.mode, Mode.SHARED, "merge when P%d walks over" % mover.player_id())


func test_no_flicker_inside_hysteresis_band() -> void:
	_freeze_at(k1, Vector2(600, FLOOR))
	_freeze_at(k2, Vector2(930, FLOOR))  # 330 px apart: inside the band, starts shared
	rig.snap_to_targets()
	assert_eq(rig.mode, Mode.SHARED, "starts shared at 330 px")
	var start_changes := rig.layout_change_count
	# Shared, then wander between the merge (299 px) and split (462 px) distances
	# at up to ~100 px/s (a knight runs at 110 px/s).
	for i in 600:
		k2.global_position.x = 600 + 385 - 55 * cos(i * 0.03)
		await physics_frames(1)
	assert_eq(rig.mode, Mode.SHARED, "stays shared inside the band")
	assert_eq(rig.layout_change_count, start_changes, "no layout changes inside the band (from shared)")
	# Split, then wander inside the same band: must stay split.
	k2.global_position.x = 600 + 520
	await physics_frames(5)
	assert_eq(rig.mode, Mode.SPLIT, "split beyond the enter distance")
	start_changes = rig.layout_change_count
	for i in 600:
		k2.global_position.x = 600 + 385 - 55 * cos(i * 0.03)
		await physics_frames(1)
	assert_eq(rig.mode, Mode.SPLIT, "stays split inside the band")
	assert_eq(rig.layout_change_count, start_changes, "no layout changes inside the band (from split)")


func test_jitter_at_split_threshold_switches_once() -> void:
	_freeze_at(k1, Vector2(600, FLOOR))
	_freeze_at(k2, Vector2(640, FLOOR))
	rig.snap_to_targets()
	var start_changes := rig.layout_change_count
	for i in 240:
		k2.global_position.x = 600 + (455.0 if (i / 5) % 2 == 0 else 470.0)
		await physics_frames(1)
	assert_eq(rig.layout_change_count - start_changes, 1, "exactly one switch despite jitter around the threshold")
	assert_eq(rig.mode, Mode.SPLIT, "ends split")


func test_merge_requires_hold_time() -> void:
	_freeze_at(k1, Vector2(600, FLOOR))
	_freeze_at(k2, Vector2(1300, FLOOR))
	rig.snap_to_targets()
	assert_eq(rig.mode, Mode.SPLIT, "split")
	k2.global_position.x = 700  # well inside the merge distance
	var hold_frames := int(ceil(rig.config.merge_hold_time * 60.0))
	await physics_frames(hold_frames - 3)
	assert_eq(rig.mode, Mode.SPLIT, "not merged before the hold time")
	k2.global_position.x = 1300  # leaves again: hold timer resets
	await physics_frames(5)
	k2.global_position.x = 700
	await physics_frames(hold_frames - 3)
	assert_eq(rig.mode, Mode.SPLIT, "hold timer restarted")
	await physics_frames(40)
	assert_eq(rig.mode, Mode.SHARED, "merged after holding")


func test_orientation_hysteresis_and_hold() -> void:
	_freeze_at(k1, Vector2(400, 600))
	_freeze_at(k2, Vector2(1000, 600))  # sx = 600/544 = 1.10, sy = 0
	rig.snap_to_targets()
	assert_eq(rig.orientation, O.SIDE_BY_SIDE, "starts side by side")
	k2.global_position.y = 600 - 1.3 * 1.10 * 280.0  # sy = 1.3 * sx: below the 1.35 factor
	await physics_frames(60)
	assert_eq(rig.orientation, O.SIDE_BY_SIDE, "slightly more vertical: unchanged")
	k2.global_position.y = 600 - 1.6 * 1.10 * 280.0  # clearly vertical...
	await physics_frames(10)                           # ...but shorter than the hold time
	k2.global_position.y = 600
	await physics_frames(30)
	assert_eq(rig.orientation, O.SIDE_BY_SIDE, "brief vertical spike ignored")
	k2.global_position.y = 600 - 1.6 * 1.10 * 280.0
	await physics_frames(int(ceil(rig.config.orientation_hold_time * 60.0)) + 3)
	assert_eq(rig.orientation, O.STACKED, "sustained vertical separation switches to stacked")
	assert_eq(rig.view_screen_rect(SplitScreenRig.VIEW_A).size, Vector2i(640, 180), "stacked layout applied")


# --- Bounds ---------------------------------------------------------------------------

func test_cameras_respect_level_bounds() -> void:
	var b := rig.bounds
	_freeze_at(k1, Vector2(24, FLOOR))
	_freeze_at(k2, Vector2(60, FLOOR))
	rig.snap_to_targets()
	await physics_frames(30)
	assert_true(b.encloses(rig.view_world_rect(SplitScreenRig.VIEW_A)), "shared view at the bottom-left corner stays inside")
	k2.global_position = Vector2(1900, 40)  # far top-right corner
	await physics_frames(60)
	assert_eq(rig.mode, Mode.SPLIT, "split")
	for view in [SplitScreenRig.VIEW_A, SplitScreenRig.VIEW_B]:
		assert_true(b.encloses(rig.view_world_rect(view)), "view %d inside bounds: %s" % [view, rig.view_world_rect(view)])
	assert_true(_sees(SplitScreenRig.VIEW_B, k2), "corner knight still visible")
	rig.clear_bounds()
	await physics_frames(60)
	assert_false(b.encloses(rig.view_world_rect(SplitScreenRig.VIEW_B)), "without bounds the camera centres freely")


func test_tall_section_tracking() -> void:
	k1.teleport_to(Vector2(1544, FLOOR))
	await physics_frames(10)
	Input.action_press(&"p1_move_up")
	var min_seen := 1.0
	for i in 720:
		await physics_frames(1)
		if not _sees(SplitScreenRig.VIEW_A, k1):
			min_seen = 0.0
		if k1.state == Knight.State.GROUNDED and k1.global_position.y < 200:
			break
	Input.action_release(&"p1_move_up")
	assert_near(k1.global_position.y, 160.0, 0.5, "P1 climbed the whole tower")
	assert_eq(min_seen, 1.0, "P1 stayed visible in its view for the entire climb")
	assert_true(rig.bounds.encloses(rig.view_world_rect(SplitScreenRig.VIEW_A)), "view stays inside bounds at the top")


# --- Resize ----------------------------------------------------------------------------

func test_layout_follows_rig_size() -> void:
	_freeze_at(k1, Vector2(400, FLOOR))
	_freeze_at(k2, Vector2(1400, FLOOR))
	rig.snap_to_targets()
	for new_size in [Vector2(800, 450), Vector2(641, 361), Vector2(640, 360)]:
		rig.size = new_size
		await physics_frames(2)
		var a := rig.view_screen_rect(SplitScreenRig.VIEW_A)
		var b := rig.view_screen_rect(SplitScreenRig.VIEW_B)
		assert_eq(a.size.x + b.size.x, int(new_size.x), "views cover the width at %s" % new_size)
		assert_eq(rig.viewport(SplitScreenRig.VIEW_A).size, a.size, "viewport A matches its rect at %s" % new_size)
		assert_eq(rig.viewport(SplitScreenRig.VIEW_B).size, b.size, "viewport B matches its rect at %s" % new_size)
		assert_eq(Vector2i(rig.get_node("ViewA").size), a.size, "container A matches at %s" % new_size)
		assert_true(_sees(SplitScreenRig.VIEW_A, k1) and _sees(SplitScreenRig.VIEW_B, k2), "both visible at %s" % new_size)


# --- Simulation integrity and resources ----------------------------------------------

func _record_p1_run(rig_active: bool) -> PackedVector2Array:
	k1.teleport_to(Vector2(600, FLOOR))
	k2.teleport_to(Vector2(660, FLOOR))
	rig.set_physics_process(rig_active)
	await physics_frames(10)
	var path := PackedVector2Array()
	var script := {0: [&"p1_move_right", true], 25: [&"p1_move_up", true], 35: [&"p1_move_up", false],
		60: [&"p1_move_right", false], 61: [&"p1_move_left", true], 100: [&"p1_move_left", false]}
	for frame in 140:
		if script.has(frame):
			if script[frame][1]:
				Input.action_press(script[frame][0])
			else:
				Input.action_release(script[frame][0])
		if frame in [10, 50, 90]:
			k2.teleport_to(Vector2(1800, FLOOR))  # forces a split when the rig is active
		if frame in [30, 70, 110]:
			k2.teleport_to(Vector2(660, FLOOR))
		await physics_frames(1)
		path.append(k1.global_position)
	return path


func test_camera_does_not_affect_simulation() -> void:
	var with_rig := await _record_p1_run(true)
	assert_gt(rig.layout_change_count, 1, "camera switched modes during the run")
	after_each_reset()
	await physics_frames(2)
	await before_each()
	var without_rig := await _record_p1_run(false)
	assert_eq(with_rig.size(), without_rig.size(), "same length")
	var identical := true
	for i in with_rig.size():
		if not with_rig[i].is_equal_approx(without_rig[i]):
			identical = false
			fail("P1 diverged at frame %d: %s vs %s" % [i, with_rig[i], without_rig[i]])
			break
	assert_true(identical, "P1's trajectory is identical with and without the camera")


func after_each_reset() -> void:
	for a in ALL_ACTIONS:
		Input.action_release(a)
	room.queue_free()


func test_camera_updates_never_move_knights() -> void:
	_freeze_at(k1, Vector2(400, FLOOR))
	_freeze_at(k2, Vector2(1400, FLOOR))
	var p1 := k1.global_position
	var p2 := k2.global_position
	rig.snap_to_targets()
	for i in 30:
		rig.update_cameras(1.0 / 60.0)
	k2.global_position = Vector2(450, FLOOR)
	p2 = k2.global_position
	for i in 90:
		rig.update_cameras(1.0 / 60.0)
	assert_eq(rig.mode, Mode.SHARED, "went through split and merge")
	assert_eq(k1.global_position, p1, "P1 position untouched by the camera")
	assert_eq(k2.global_position, p2, "P2 position untouched by the camera")


func test_repeated_switching_does_not_accumulate_resources() -> void:
	_freeze_at(k1, Vector2(600, FLOOR))
	_freeze_at(k2, Vector2(640, FLOOR))
	rig.snap_to_targets()
	await physics_frames(5)
	var nodes_before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var objects_before := Performance.get_monitor(Performance.OBJECT_COUNT)
	var resources_before := Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	for cycle in 40:
		k2.global_position = Vector2(1500, 300 if cycle % 2 == 0 else FLOOR)
		await physics_frames(3)
		k2.global_position = Vector2(640, FLOOR)
		await physics_frames(40)
	assert_gt(rig.layout_change_count, 60, "many layout switches happened (%d)" % rig.layout_change_count)
	assert_eq(rig.mode, Mode.SHARED, "ends shared")
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes_before, "node count unchanged")
	assert_lt(Performance.get_monitor(Performance.OBJECT_COUNT) - objects_before, 20.0, "object count stable")
	assert_lt(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT) - resources_before, 5.0, "resource count stable")
	assert_eq(room.find_children("*", "SubViewport", true, false).size(), 2, "still exactly two viewports")


# --- Phase 1 regression inside the rig (physics now runs in a SubViewport's World2D) ---

func test_phase1_mechanics_inside_the_rig() -> void:
	# Jump height on open floor near the tower.
	k1.teleport_to(Vector2(1580, FLOOR))
	k2.teleport_to(Vector2(1700, FLOOR))
	await physics_frames(15)
	var start_y := k1.global_position.y
	var min_y := start_y
	Input.action_press(&"p1_move_up")
	for i in 60:
		await physics_frames(1)
		min_y = minf(min_y, k1.global_position.y)
	Input.action_release(&"p1_move_up")
	assert_near(start_y - min_y, k1.config.jump_height(), 4.0, "full jump height unchanged")
	await physics_frames(20)
	# One-way drop: the lowest tower platform (x 1568-1616, y 880).
	k1.teleport_to(Vector2(1590, 874))
	await physics_frames(20)
	assert_eq(k1.floor_kind, Knight.FloorKind.ONE_WAY, "standing on a one-way platform")
	Input.action_press(&"p1_move_down")
	await physics_frames(3)
	Input.action_release(&"p1_move_down")
	await physics_frames(40)
	assert_near(k1.global_position.y, FLOOR, 0.5, "dropped through to the floor")
	# Crouch through the crawl section (16 px gap at x 1280-1360).
	k1.teleport_to(Vector2(1260, FLOOR))
	await physics_frames(10)
	Input.action_press(&"p1_move_down")
	Input.action_press(&"p1_move_right")
	await physics_frames(150)
	Input.action_release(&"p1_move_down")
	Input.action_release(&"p1_move_right")
	assert_gt(k1.global_position.x, 1330.0, "crawled into the low section")
	# Push and simultaneous attacks.
	k1.teleport_to(Vector2(600, FLOOR))
	k2.teleport_to(Vector2(615, FLOOR))
	await physics_frames(10)
	var x2 := k2.global_position.x
	Input.action_press(&"p1_move_right")
	await physics_frames(60)
	Input.action_release(&"p1_move_right")
	assert_gt(k2.global_position.x - x2, 15.0, "pushing still works")
	var a1 := k1.attack_count
	var a2 := k2.attack_count
	Input.action_press(&"p1_attack")
	Input.action_press(&"p2_attack")
	await physics_frames(2)
	Input.action_release(&"p1_attack")
	Input.action_release(&"p2_attack")
	assert_eq(k1.attack_count, a1 + 1, "P1 attack registered")
	assert_eq(k2.attack_count, a2 + 1, "P2 attack registered in the same frame")
