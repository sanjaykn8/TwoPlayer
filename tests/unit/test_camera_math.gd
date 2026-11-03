extends GameTestCase
## Pure camera rules (CameraMath), CameraConfig validation and CameraBounds.

const O := CameraMath.Orientation
const FULL := Vector2(640, 360)
const MARGIN := Vector2(48, 40)  # safe region 544 x 280


func test_midpoint() -> void:
	assert_eq(CameraMath.midpoint(Vector2(0, 0), Vector2(100, 40)), Vector2(50, 20), "midpoint")
	assert_eq(CameraMath.midpoint(Vector2(-10, 5), Vector2(10, 5)), Vector2(0, 5), "symmetric midpoint")


func test_separation_ratio_axes() -> void:
	var r := CameraMath.separation_ratio(Vector2(0, 0), Vector2(272, 0), FULL, MARGIN)
	assert_near(r.x, 0.5, 0.0001, "horizontal: 272 of 544")
	assert_near(r.y, 0.0, 0.0001, "no vertical separation")
	r = CameraMath.separation_ratio(Vector2(0, 280), Vector2(0, 0), FULL, MARGIN)
	assert_near(r.y, 1.0, 0.0001, "vertical: 280 of 280")
	assert_near(r.x, 0.0, 0.0001, "no horizontal separation")
	r = CameraMath.separation_ratio(Vector2(300, 0), Vector2(0, 0), FULL, MARGIN)
	assert_eq(CameraMath.separation_ratio(Vector2(0, 0), Vector2(300, 0), FULL, MARGIN), r, "order does not matter")


func test_split_and_merge_thresholds_with_hysteresis() -> void:
	var enter := 0.85
	var exit := 0.55
	assert_true(CameraMath.should_split(Vector2(0.86, 0.0), enter), "split above enter (x)")
	assert_true(CameraMath.should_split(Vector2(0.1, 0.9), enter), "split above enter (y)")
	assert_false(CameraMath.should_split(Vector2(0.849, 0.849), enter), "no split just below enter")
	assert_true(CameraMath.should_merge(Vector2(0.54, 0.3), exit), "merge below exit")
	assert_false(CameraMath.should_merge(Vector2(0.54, 0.56), exit), "both axes must be below exit")
	# Inside the band neither rule fires, so the current mode is kept.
	for ratio in [Vector2(0.6, 0.0), Vector2(0.84, 0.2), Vector2(0.3, 0.7)]:
		assert_false(CameraMath.should_split(ratio, enter), "band %s: no split" % ratio)
		assert_false(CameraMath.should_merge(ratio, exit), "band %s: no merge" % ratio)


func test_orientation_selection_and_hysteresis() -> void:
	assert_eq(CameraMath.preferred_orientation(Vector2(1.0, 0.2)), O.SIDE_BY_SIDE, "horizontal dominant: side by side")
	assert_eq(CameraMath.preferred_orientation(Vector2(0.2, 1.0)), O.STACKED, "vertical dominant: stacked")
	assert_eq(CameraMath.preferred_orientation(Vector2(1.0, 1.0)), O.SIDE_BY_SIDE, "tie: side by side")
	var h := 1.35
	assert_eq(CameraMath.next_orientation(O.SIDE_BY_SIDE, Vector2(1.0, 1.3), h), O.SIDE_BY_SIDE, "slightly vertical: keep")
	assert_eq(CameraMath.next_orientation(O.SIDE_BY_SIDE, Vector2(1.0, 1.4), h), O.STACKED, "clearly vertical: switch")
	assert_eq(CameraMath.next_orientation(O.STACKED, Vector2(1.3, 1.0), h), O.STACKED, "slightly horizontal: keep")
	assert_eq(CameraMath.next_orientation(O.STACKED, Vector2(1.4, 1.0), h), O.SIDE_BY_SIDE, "clearly horizontal: switch")


func test_layout_rectangles() -> void:
	var shared := CameraMath.layout(false, O.SIDE_BY_SIDE, Vector2i(640, 360), 2)
	assert_eq(shared["a"], Rect2i(0, 0, 640, 360), "shared: A fills the screen")
	assert_eq(shared["b"], Rect2i(), "shared: no B")
	var side := CameraMath.layout(true, O.SIDE_BY_SIDE, Vector2i(640, 360), 2)
	assert_eq(side["a"], Rect2i(0, 0, 320, 360), "side: P1 left")
	assert_eq(side["b"], Rect2i(320, 0, 320, 360), "side: P2 right")
	assert_eq(side["divider"], Rect2i(319, 0, 2, 360), "side: vertical divider on the seam")
	var stacked := CameraMath.layout(true, O.STACKED, Vector2i(640, 360), 2)
	assert_eq(stacked["a"], Rect2i(0, 0, 640, 180), "stacked: P1 top")
	assert_eq(stacked["b"], Rect2i(0, 180, 640, 180), "stacked: P2 bottom")
	assert_eq(stacked["divider"], Rect2i(0, 179, 640, 2), "stacked: horizontal divider")
	var odd := CameraMath.layout(true, O.SIDE_BY_SIDE, Vector2i(641, 361), 2)
	assert_eq(odd["a"].size.x + odd["b"].size.x, 641, "odd width fully covered")
	assert_eq(odd["b"].position.x, odd["a"].end.x, "no gap or overlap between views")


func test_sub_view_center_is_seamless() -> void:
	var c := Vector2(1000, 500)
	var side := CameraMath.layout(true, O.SIDE_BY_SIDE, Vector2i(640, 360), 2)
	var a := CameraMath.sub_view_center(c, FULL, Rect2(side["a"]))
	var b := CameraMath.sub_view_center(c, FULL, Rect2(side["b"]))
	assert_eq(a, Vector2(840, 500), "left camera centre")
	assert_eq(b, Vector2(1160, 500), "right camera centre")
	# The world point under any screen pixel is identical before and after the split.
	for screen_x: float in [0.0, 100.0, 319.0]:
		var shared_world := c.x - FULL.x * 0.5 + screen_x
		var split_world := a.x - 160.0 + screen_x
		assert_near(split_world, shared_world, 0.0001, "left half pixel %d unchanged" % screen_x)
	var stacked := CameraMath.layout(true, O.STACKED, Vector2i(640, 360), 2)
	assert_eq(CameraMath.sub_view_center(c, FULL, Rect2(stacked["b"])), Vector2(1000, 590), "bottom camera centre")


func test_clamp_center_to_bounds() -> void:
	var bounds := Rect2(0, 0, 1920, 960)
	assert_eq(CameraMath.clamp_center(Vector2(100, 100), FULL, bounds), Vector2(320, 180), "top-left corner clamp")
	assert_eq(CameraMath.clamp_center(Vector2(1900, 950), FULL, bounds), Vector2(1600, 780), "bottom-right clamp")
	assert_eq(CameraMath.clamp_center(Vector2(800, 400), FULL, bounds), Vector2(800, 400), "inside: unchanged")
	var narrow := Rect2(100, 0, 300, 2000)
	assert_eq(CameraMath.clamp_center(Vector2(900, 50), FULL, narrow).x, 250.0, "bounds narrower than view: centred")
	assert_eq(CameraMath.clamp_center(Vector2(900, 50), FULL, narrow).y, 180.0, "tall bounds still clamp vertically")
	var half := Vector2(320, 360)
	assert_eq(CameraMath.clamp_center(Vector2(0, 0), half, bounds), Vector2(160, 180), "split view clamps with its own size")


func test_deadzone() -> void:
	var dz := Vector2(12, 8)
	assert_eq(CameraMath.apply_deadzone(Vector2.ZERO, Vector2(10, -7), dz), Vector2.ZERO, "inside deadzone: no move")
	assert_eq(CameraMath.apply_deadzone(Vector2.ZERO, Vector2(20, 0), dz), Vector2(8, 0), "pushes only to the edge")
	assert_eq(CameraMath.apply_deadzone(Vector2.ZERO, Vector2(-20, 30), dz), Vector2(-8, 22), "both axes")


func test_smoothing_is_frame_rate_independent() -> void:
	var at_60 := Vector2.ZERO
	for i in 60:
		at_60 = CameraMath.smooth(at_60, Vector2(100, 0), 8.0, 1.0 / 60.0)
	var at_30 := Vector2.ZERO
	for i in 30:
		at_30 = CameraMath.smooth(at_30, Vector2(100, 0), 8.0, 1.0 / 30.0)
	assert_near(at_60.x, at_30.x, 0.001, "same result after 1 s at 60 and 30 fps")
	assert_gt(at_60.x, 99.0, "converges within a second at speed 8")
	assert_eq(CameraMath.smooth(Vector2.ZERO, Vector2(5, 5), 0.0, 0.016), Vector2(5, 5), "speed 0 snaps")


func test_camera_config_validation() -> void:
	var config: CameraConfig = load("res://resources/config/camera_config.tres")
	assert_eq(config.validate().size(), 0, "shipped config is valid: %s" % config.validate())
	assert_eq(config.zoom, 1, "no zoom (D-8)")
	var bad := CameraConfig.new()
	bad.split_exit_ratio = 0.9
	bad.split_enter_ratio = 0.8
	assert_gt(bad.validate().size(), 0, "exit >= enter is rejected")
	bad = CameraConfig.new()
	bad.split_enter_ratio = 0.99
	bad.split_exit_ratio = 0.5
	assert_eq(bad.validate().size(), 0, "0.99 is allowed")


func test_camera_bounds_rect_and_tilemap_fit() -> void:
	var bounds := CameraBounds.new()
	bounds.position = Vector2(16, 32)
	bounds.size = Vector2(800, 400)
	add_child(bounds)
	assert_eq(bounds.get_world_rect(), Rect2(16, 32, 800, 400), "explicit size")
	assert_true(bounds.is_in_group(CameraBounds.GROUP), "registered in group")
	var layer := TileMapLayer.new()
	layer.tile_set = load("res://resources/tilesets/dev_world_tileset.tres")
	layer.set_cell(Vector2i(2, 3), 0, Vector2i(0, 0))
	layer.set_cell(Vector2i(5, 7), 0, Vector2i(0, 0))
	add_child(layer)
	bounds.fit_to_tile_map = layer
	assert_eq(bounds.get_world_rect(), Rect2(32, 48, 64, 80), "fits the used tile rectangle")
	bounds.queue_free()
	layer.queue_free()
