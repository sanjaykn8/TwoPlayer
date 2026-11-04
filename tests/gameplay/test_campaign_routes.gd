extends GameTestCase
## Every jump on every level's main route is made by the real knight with real input
## (RouteValidator). A jump that the analyzer allows but the knight cannot make would be an
## impossible mandatory jump (a P1 progression blocker). Results also go to
## user://route_validation_results.json for the validation matrix.

const RESULTS := "user://route_validation_results.json"

static var _all := {}


func after_each() -> void:
	for action in [&"p1_move_left", &"p1_move_right", &"p1_move_up", &"p1_move_down"]:
		Input.action_release(action)
	var f := FileAccess.open(RESULTS, FileAccess.WRITE)
	f.store_string(JSON.stringify(_all, "\t"))
	f.close()


func _world(index: int) -> void:
	for id in LevelCatalog.levels_of(LevelCatalog.world_ids()[index]):
		RunState.reset()
		var report: Dictionary = await RouteValidator.new(self).validate(id)
		_all[id] = report
		assert_true(report.route_ok, "%s: a route to the exit the knight can make (%s)" % [id, report.failed])
		assert_gt(int(report.jumps) + int(report.skipped_moving), 0, "%s: the route was walked" % id)


func test_world_1() -> void:
	await _world(0)


func test_world_2() -> void:
	await _world(1)


func test_world_3() -> void:
	await _world(2)


func test_world_4() -> void:
	await _world(3)


func test_world_5() -> void:
	await _world(4)


func test_world_6() -> void:
	await _world(5)
