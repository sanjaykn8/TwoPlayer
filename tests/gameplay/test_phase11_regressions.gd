extends GameTestCase
## Regression tests for defects found and fixed in Phase 11 (docs/KNOWN_ISSUES.md).

const Analyzer := preload("res://tools/level_analyzer.gd")


## KI-99: teleporting a knight off a ladder left the anti-regrab delay running, so Up at the
## next ladder jumped instead of grabbing it.
func test_teleport_clears_the_ladder_regrab_delay() -> void:
	LevelCatalog.use_production()
	var level: Node = (load(LevelCatalog.scene_for("l18")) as PackedScene).instantiate()
	add_child(level)
	await physics_frames(5)
	var k := level.get_node("Knights/Knight1") as Knight
	for ladder_name in ["Ladder3", "Ladder2"]:
		var ladder := level.get_node("Climbables/" + ladder_name) as Climbable
		k.teleport_to(Vector2(ladder.global_position.x, ladder.bottom_y()))
		await physics_frames(3)
		Input.action_press(&"p1_move_up")
		await physics_frames(6)
		assert_true(k.is_climbing(), "%s grabbed right after a teleport" % ladder_name)
		Input.action_release(&"p1_move_up")
		await physics_frames(20)
	Input.action_release(&"p1_move_up")
	level.queue_free()
	await physics_frames(2)


## KI-100: the analyzer let a jump pass through the slab above the Heart of the Grove corridor
## (from the upper walkway straight into the corridor beyond the gate). Since the overhaul the
## walkway is 4 rows lower (slab top row 27, corridor floor row 31).
func test_analyzer_never_jumps_through_solid() -> void:
	LevelCatalog.use_production()
	var root: Node = (load(LevelCatalog.scene_for("l04")) as PackedScene).instantiate()
	var a = Analyzer.new(root)
	for g: Node in a.gates:
		a.open_gates[g] = true
	assert_true(a.standable(Vector2i(107, 27)) and a.standable(Vector2i(113, 31)), "both places exist (walkway, corridor)")
	assert_false(a.neighbours(Vector2i(107, 27)).has(Vector2i(113, 31)), "no jump through the slab")
	root.free()


## KI-108: a short downward jump could drop straight through solid ground, because the landing
## column under the arc was never checked (Crystal Descent: from the shelf edge into the hidden
## crystal room below it).
func test_analyzer_never_falls_through_the_landing_column() -> void:
	LevelCatalog.use_production()
	var root: Node = (load(LevelCatalog.scene_for("l05")) as PackedScene).instantiate()
	var a = Analyzer.new(root)
	assert_true(a.standable(Vector2i(59, 24)) and a.standable(Vector2i(58, 32)), "shelf edge and room floor exist")
	assert_false(a.neighbours(Vector2i(59, 24)).has(Vector2i(58, 32)), "no drop through the shelf into the room")
	root.free()
