extends GameTestCase
## Calibrates the level analyzer's movement model against the real knight: every jump the
## analyzer allows at its limits is performed with real input (run, then jump at the edge)
## and must land. Built with the campaign builder in a throw-away room.

const Builder := preload("res://tools/campaign/campaign_builder.gd")
const Themes := preload("res://tools/campaign/themes.gd")
const Analyzer := preload("res://tools/level_analyzer.gd")

var room: Node2D


func after_each() -> void:
	for action in [&"p1_move_right", &"p1_move_up", &"p1_move_left"]:
		Input.action_release(action)
	if is_instance_valid(room):
		room.queue_free()
	await physics_frames(2)


## A floor ending at column 10, then the landing surface `gap` columns later and `up` rows
## higher. Returns the knight after the attempt.
func _attempt(gap: int, up: int) -> Knight:
	var ops := [["fill", 0, 0, 0, 29], ["fill", 59, 0, 59, 29], ["ground", 1, 10, 20],
		["ground", 11 + gap, 40, 20 - up]]
	var spec := {"id": "calib", "title": "", "width": 60, "height": 30, "spawn": [3, 20], "ops": ops}
	room = Builder.new().build(spec, Themes.THEMES.forest)
	add_child(room)
	await physics_frames(5)
	var k := room.get_node("Knights/Knight1") as Knight
	var k2 := room.get_node("Knights/Knight2") as Knight
	k2.global_position = Vector2(-500, -500)
	k2.set_physics_process(false)
	Input.action_press(&"p1_move_right")
	var jumped := false
	for i in 240:
		await physics_frames(1)
		if not jumped and k.global_position.x >= 11 * 16 - 4:
			Input.action_press(&"p1_move_up")
			jumped = true
		if jumped and k.is_on_floor() and k.global_position.x > (11 + gap) * 16:
			break
	Input.action_release(&"p1_move_right")
	Input.action_release(&"p1_move_up")
	return k


func _check(gap: int, up: int) -> void:
	var k := await _attempt(gap, up)
	assert_true(k.is_on_floor(), "gap %d up %d: landed" % [gap, up])
	assert_near(k.global_position.y, (20 - up) * 16.0, 1.0, "gap %d up %d: on the far surface" % [gap, up])
	# And the analyzer agrees this jump exists.
	var a = Analyzer.new(room)
	var area: Dictionary = a.reachable_from([Vector2i(10, 20)] as Array[Vector2i])
	assert_true(area.has(Vector2i(11 + gap, 20 - up)), "gap %d up %d: analyzer allows it" % [gap, up])


func test_flat_jump_over_three_tiles() -> void:
	await _check(3, 0)


func test_one_up_over_three_tiles() -> void:
	await _check(3, 1)


func test_two_up_over_two_tiles() -> void:
	await _check(2, 2)


func test_three_up_over_one_tile() -> void:
	await _check(1, 3)


func test_analyzer_refuses_what_physics_cannot_do() -> void:
	var spec := {"id": "calib", "title": "", "width": 60, "height": 30, "spawn": [3, 20], "ops": [
		["fill", 0, 0, 0, 29], ["ground", 1, 10, 20], ["ground", 16, 40, 20], ["ground", 12, 13, 16]]}
	room = Builder.new().build(spec, Themes.THEMES.forest)
	var a = Analyzer.new(room)
	var area: Dictionary = a.reachable_from([Vector2i(10, 20)] as Array[Vector2i])
	assert_false(area.has(Vector2i(16, 20)), "a five-tile gap is not jumpable")
	assert_false(area.has(Vector2i(12, 16)), "four rows up is not jumpable")
