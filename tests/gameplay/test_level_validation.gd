extends GameTestCase
## Runs LevelProbe (20 runtime checks, real input and physics) on every campaign level, one
## test per world. Results are also written to user://level_validation_results.json, from
## which tools/write_validation_matrix.gd builds docs/LEVEL_VALIDATION_MATRIX.md.

const DIR := "user://test_saves_validation/"
const RESULTS := "user://level_validation_results.json"

static var _all := {}


func before_each() -> void:
	SaveTestUtil.clean(DIR)
	LevelCatalog.use_production()
	RunState.reset()


func after_each() -> void:
	for node in get_children():
		node.queue_free()
	await physics_frames(2)
	SaveTestUtil.clean(DIR)
	LevelCatalog.use_production()
	var f := FileAccess.open(RESULTS, FileAccess.WRITE)
	f.store_string(JSON.stringify(_all, "\t"))
	f.close()


func _validate_world(index: int) -> void:
	var world_id: String = LevelCatalog.world_ids()[index]
	for id in LevelCatalog.levels_of(world_id):
		for node in get_children():
			node.queue_free()
		await physics_frames(2)
		SaveTestUtil.clean(DIR)
		LevelCatalog.use_production()
		RunState.reset()
		var game := SaveTestUtil.make_game(self, 1, CampaignGame.StartMode.NEW, DIR, true)
		assert_eq(game.begin(), OK, "%s: campaign begins" % id)
		RunState.current().campaign.enter_level(id)
		assert_eq(game._load_level(id, {}), "", "%s loads" % id)
		var probe := LevelProbe.new(self, game, id, DIR)
		var results: Dictionary = await probe.run()
		_all[id] = results
		for check in LevelProbe.CHECKS:
			var result := str(results.get(check, "FAIL: not run"))
			assert_false(result.begins_with("FAIL"), "%s %s: %s" % [id, check, result])


func test_world_1() -> void:
	await _validate_world(0)


func test_world_2() -> void:
	await _validate_world(1)


func test_world_3() -> void:
	await _validate_world(2)


func test_world_4() -> void:
	await _validate_world(3)


func test_world_5() -> void:
	await _validate_world(4)


func test_world_6() -> void:
	await _validate_world(5)
