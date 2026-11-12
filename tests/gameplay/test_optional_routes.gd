extends GameTestCase
## The optional routes added in the final pass, replayed by the real knight with real input
## (RouteValidator with the reward's standing cell as the goal): every jump, spring, wind
## and crumbling stone on the way to each new reward can actually be made with base stats.
## Routes that need a bounce off a spirit lantern or a partner's boost are not replayed here
## (the validator plans without them); they are listed in docs/LEVEL_BY_LEVEL_QA.md.

## [level, goal cell (x, floor row), what it is, optional start cell]
const ROUTES := [
	["l01", Vector2i(74, 10), "the shield fruit on the old tree's roof"],
	["l02", Vector2i(56, 32), "the green fruit in the root tunnel"],
	["l03", Vector2i(38, 18), "the green fruit in the nest"],
	["l05", Vector2i(11, 14), "the shield fruit in the cliff room"],
	["l05", Vector2i(103, 30), "the yellow jar behind the held door"],
	["l06", Vector2i(62, 58), "the purple fruit on the low road's island"],
	["l06", Vector2i(57, 42), "the middle shelf, by the island's wind", Vector2i(60, 58)],
	["l07", Vector2i(28, 18), "the shield fruit at the end of the gallery"],
	["l07", Vector2i(34, 27), "the coins in the brood nest"],
	["l08", Vector2i(36, 56), "the blue jar in the hidden room"],
	["l09", Vector2i(66, 44), "the venom fruit in the cistern"],
	["l10", Vector2i(136, 26), "the yellow jar on the blade ledge"],
	["l13", Vector2i(22, 22), "the coins above the steam vent"],
	["l14", Vector2i(49, 36), "the shield fruit on the shelf under the bridge"],
	["l15", Vector2i(39, 38), "the venom fruit in the forge cellar"],
	["l18", Vector2i(123, 32), "the shield fruit above the ticking steps"],
	["l19", Vector2i(115, 44), "the shield fruit in the tower's foot"],
	["l21", Vector2i(66, 42), "the yellow jar in the archer's alcove"],
	["l22", Vector2i(116, 66), "the cache at the foot of the spire"],
]


func after_each() -> void:
	for action in [&"p1_move_left", &"p1_move_right", &"p1_move_up", &"p1_move_down"]:
		Input.action_release(action)


func _check(from: int, to: int) -> void:
	for i in range(from, mini(to, ROUTES.size())):
		var entry: Array = ROUTES[i]
		RunState.reset()
		var validator := RouteValidator.new(self)
		validator.goal_cells = [entry[1]]
		if entry.size() > 3:
			validator.start_cell = entry[3]
		var report: Dictionary = await validator.validate(entry[0])
		assert_true(report.route_ok, "%s: the knight can reach %s (%s; banned %s)" % [entry[0], entry[2], report.failed, report.banned])


func test_optional_routes_worlds_1_and_2() -> void:
	await _check(0, 10)


func test_optional_routes_worlds_3_to_6() -> void:
	await _check(10, ROUTES.size())
