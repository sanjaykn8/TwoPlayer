extends GameTestCase
## Puzzle state registry, scoping, snapshots, the "different knights" rule and configuration.

func test_distinct_player_assignment() -> void:
	assert_true(PuzzleLogic.can_assign_distinct([[1], [2]]), "P1 and P2")
	assert_false(PuzzleLogic.can_assign_distinct([[1], [1]]), "P1 twice")
	assert_true(PuzzleLogic.can_assign_distinct([[1], [1, 2]]), "P1, and P1+P2 together")
	assert_true(PuzzleLogic.can_assign_distinct([[1, 2], [1, 2]]), "both on both")
	assert_false(PuzzleLogic.can_assign_distinct([[1], []]), "an empty input")
	assert_false(PuzzleLogic.can_assign_distinct([[1, 2], [1, 2], [1, 2]]), "three inputs, two knights")
	assert_true(PuzzleLogic.can_assign_distinct([]), "nothing required")


func test_registry_scopes_never_overwrite_each_other() -> void:
	var reg := PuzzleRegistry.new()
	reg.set_state("level_a", "door", {"open": true})
	reg.set_state("level_b", "door", {"open": false, "x": 1})
	reg.set_state(PuzzleRegistry.CAMPAIGN, "door", {"seen": true})
	assert_eq(reg.get_state("level_a", "door"), {"open": true}, "level A kept")
	assert_eq(reg.get_state("level_b", "door"), {"open": false, "x": 1}, "level B kept")
	assert_eq(reg.get_state(PuzzleRegistry.CAMPAIGN, "door"), {"seen": true}, "campaign kept")
	reg.set_state("level_a", "door", {})
	assert_false(reg.has_state("level_a", "door"), "an empty state erases")
	assert_true(reg.has_state("level_b", "door"), "other scopes untouched")
	reg.clear_scope("level_b")
	assert_false(reg.has_state("level_b", "door"), "a level's states can be cleared")
	assert_true(reg.has_state(PuzzleRegistry.CAMPAIGN, "door"), "campaign untouched")


func test_registry_changes_are_signalled_once() -> void:
	var reg := PuzzleRegistry.new()
	var count := [0]
	reg.state_changed.connect(func(_s: String, _i: String) -> void: count[0] += 1)
	reg.set_state("l", "a", {"on": true})
	reg.set_state("l", "a", {"on": true})
	assert_eq(count[0], 1, "an identical write is not a change")


func test_registry_snapshot_round_trip_and_validation() -> void:
	var reg := PuzzleRegistry.new()
	reg.set_state("dev/x", "lock", {"completed": true})
	var text := JSON.stringify(reg.snapshot())
	var copy := PuzzleRegistry.new()
	assert_true(copy.restore(JSON.parse_string(text)), "restores from JSON")
	assert_eq(copy.get_state("dev/x", "lock"), {"completed": true}, "state restored")
	for bad: Variant in [null, {}, {"version": 1}, {"version": 99, "states": {}},
			{"version": 1, "states": {"l": 5}}, {"version": 1, "states": {"l": {"p": "x"}}}]:
		assert_false(PuzzleRegistry.is_valid_snapshot(bad), "rejects %s" % str(bad))
	assert_false(copy.restore({"version": 1, "states": {"l": 5}}), "invalid data refused")
	assert_eq(copy.get_state("dev/x", "lock"), {"completed": true}, "refused data changed nothing")


func test_duplicate_live_ids_are_detected() -> void:
	var reg := PuzzleRegistry.new()
	var a := Node.new()
	var b := Node.new()
	assert_true(reg.register("lvl", "gate", a, false), "first registration")
	assert_false(reg.register("lvl", "gate", b, false), "duplicate id refused")
	assert_true(reg.register("other", "gate", b, false), "same id in another level is fine")
	reg.unregister("lvl", "gate", a)
	assert_true(reg.register("lvl", "gate", b, false), "free again after unregistering")
	assert_eq(reg.live_node("lvl", "gate"), b, "the live node is tracked")
	a.free()
	b.free()


func test_run_snapshot_carries_puzzles_and_reads_old_versions() -> void:
	var run := RunState.reset()
	run.puzzles.set_state("dev/puzzle_test", "s1_lock", {"completed": true})
	var data: Dictionary = JSON.parse_string(JSON.stringify(run.snapshot()))
	assert_eq(int(data.version), RunState.VERSION, "current version")
	var copy := RunState.new()
	assert_true(copy.restore(data), "restores")
	assert_eq(copy.puzzles.get_state("dev/puzzle_test", "s1_lock"), {"completed": true}, "puzzle state restored")
	var old := data.duplicate(true)
	old.erase("puzzles")
	old.version = 1
	assert_true(copy.restore(old), "a version-1 snapshot (no puzzles) still loads")
	assert_false(copy.puzzles.has_state("dev/puzzle_test", "s1_lock"), "with no puzzle progress")
	var broken := data.duplicate(true)
	broken.erase("puzzles")
	assert_false(copy.restore(broken), "a version-2 snapshot must contain puzzles")
	broken = data.duplicate(true)
	broken.puzzles = {"version": 1, "states": {"x": 3}}
	assert_false(copy.restore(broken), "malformed puzzle data refused")


func test_new_run_forgets_puzzles() -> void:
	RunState.current().puzzles.set_state("l", "a", {"on": true})
	assert_false(RunState.reset().puzzles.has_state("l", "a"), "a new run (and later a team wipe) starts clean")


func test_level_id_lookup() -> void:
	var level := Node2D.new()
	level.set_meta(&"level_id", "world1/level2")
	var group := Node2D.new()
	var child := Node2D.new()
	level.add_child(group)
	group.add_child(child)
	assert_eq(PuzzleSource.level_id_for(child), "world1/level2", "nearest level_id metadata")
	var orphan := Node2D.new()
	assert_eq(PuzzleSource.level_id_for(orphan), "", "no level: empty id")
	level.free()
	orphan.free()


func test_puzzle_config_is_valid() -> void:
	var config := load("res://resources/config/puzzle_config.tres") as PuzzleConfig
	assert_true(config != null, "loads as PuzzleConfig")
	assert_eq(config.validate(), PackedStringArray(), "no problems")
	assert_near(config.switch_cooldown, 0.35, 0.001, "switch cooldown")
	var bad := PuzzleConfig.new()
	bad.gate_move_time = 0.0
	assert_gt(bad.validate().size(), 0.0, "invalid values reported")
