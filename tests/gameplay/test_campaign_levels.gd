extends GameTestCase
## Content validation of the production campaign (Phase 10, prompt Parts P and Q): the
## registry, every level scene, ids, spawns, exits, and a static playability analysis of every
## level (tools/level_analyzer.gd, calibrated in test_campaign_physics.gd).

const Analyzer := preload("res://tools/level_analyzer.gd")
const Builder := preload("res://tools/campaign/campaign_builder.gd")
const Themes := preload("res://tools/campaign/themes.gd")


func _scene(level_id: String) -> Node:
	return (load(LevelCatalog.scene_for(level_id)) as PackedScene).instantiate()


func test_registry_is_linear_and_trusted() -> void:
	var levels := LevelCatalog.all_levels()
	assert_gt(levels.size(), 0, "levels registered")
	assert_false(LevelCatalog.is_development(), "production campaign by default")
	var seen := {}
	var order := 0
	for world_id in LevelCatalog.world_ids():
		var world := LevelCatalog.world(world_id)
		assert_eq(world.levels.size(), 4, "%s has four main levels" % world_id)
		assert_true(world.title != "" and world.music_track != "", "%s has a title and music" % world_id)
		for def in world.levels:
			order += 1
			assert_false(seen.has(def.id), "%s unique" % def.id)
			seen[def.id] = true
			assert_eq(def.order, order, "%s order" % def.id)
			assert_eq(def.world_id, world_id, "%s world" % def.id)
			assert_true(def.scene_path.begins_with("res://scenes/worlds/"), "%s scene from the campaign folder" % def.id)
			assert_true(ResourceLoader.exists(def.scene_path), "%s scene exists" % def.id)
			assert_true(def.title != "" and def.difficulty >= 1 and def.estimated_minutes > 0.0, "%s metadata" % def.id)
			assert_eq(def.completion, "exit", "%s completes at its exit" % def.id)
			assert_true(def.camera_bounds.size.x >= 640 and def.camera_bounds.size.y >= 360, "%s camera bounds cover a screen" % def.id)
	for i in levels.size():
		assert_eq(LevelCatalog.next_level(levels[i]), levels[i + 1] if i + 1 < levels.size() else "", "%s -> next" % levels[i])
		if i > 0:
			assert_eq(LevelCatalog.previous_level(levels[i]), levels[i - 1], "%s <- previous" % levels[i])
	assert_true(LevelCatalog.is_final_level(levels.back()), "the last level ends the campaign")
	assert_eq(LevelCatalog.first_level(), levels[0], "the campaign starts at its first level")
	for bad in ["", "w1_l1", "res://scenes/worlds/world_01_ancient_forest/level_01.tscn", "../l01"]:
		assert_false(LevelCatalog.is_known_level(bad), "%s refused in production" % bad)


func test_every_level_scene_is_complete() -> void:
	var collectible_ids := {}
	for id in LevelCatalog.all_levels():
		var root := _scene(id)
		var def := LevelCatalog.level(id)
		assert_eq(str(root.get_meta(&"level_id", "")), id, "%s level_id metadata" % id)
		for path in ["Terrain", "CameraBounds", "SpawnP1", "SpawnP2", "Knights/Knight1", "Knights/Knight2", "Campaign/Exit", "Hazards/FallBoundary"]:
			assert_true(root.get_node_or_null(path) != null, "%s has %s" % [id, path])
		assert_eq((root.get_node("SpawnP1") as Node2D).position, def.spawn_p1, "%s P1 spawn matches the registry" % id)
		assert_eq((root.get_node("SpawnP2") as Node2D).position, def.spawn_p2, "%s P2 spawn matches the registry" % id)
		var exits := root.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is LevelExit)
		assert_eq(exits.size(), 1, "%s has exactly one exit" % id)
		var level_ids := {}
		for node in root.find_children("*", "", true, false):
			var key := ""
			if node is Collectible and node.collectible_id != "":
				assert_false(collectible_ids.has(node.collectible_id), "%s collectible id unique in the campaign" % node.collectible_id)
				collectible_ids[node.collectible_id] = true
				assert_true(SaveIds.is_valid_id(node.collectible_id), "%s valid id" % node.collectible_id)
			elif node is Collectible and not (node is DroppedCoin):
				fail("%s: %s has no collectible_id" % [id, node.name])
			if node is PuzzleSource and node.puzzle_id != "":
				key = "puzzle:" + node.puzzle_id
			elif (node is Slime or node is BossSlime or node is PlatformBody or node is SavePoint) and str(node.get(&"save_id")) != "":
				key = "save:" + str(node.get(&"save_id"))
			elif node is Slime or node is PlatformBody:
				fail("%s: %s has no save_id" % [id, node.name])
			if key != "":
				assert_false(level_ids.has(key), "%s: %s unique" % [id, key])
				level_ids[key] = true
			if node is Slime:
				assert_true((node as Slime).stats != null, "%s: %s has stats" % [id, node.name])
			if node is BossSlime:
				assert_true((node as BossSlime).stats != null and node.get_node_or_null((node as BossSlime).seal) is BossSeal, "%s: boss configured" % id)
			if node is Hazard:
				var h := node as Hazard
				assert_true(h.size.x >= 16 and h.size.y >= 16, "%s: %s has a size" % [id, node.name])
		root.free()


func test_every_level_is_playable() -> void:
	for id in LevelCatalog.all_levels():
		var root := _scene(id)
		var a = Analyzer.new(root)
		for s: Vector2i in a.spawn:
			assert_true(a.standable(s), "%s: spawn %s is a free, safe standing place" % [id, s])
		var main: Dictionary = a.analyze(false)
		assert_true(a.exit_reachable(main), "%s: the exit is reachable without optional content" % id)
		assert_eq(a.open_gates.size(), a.gates.size() - _boss_gates(a), "%s: every non-boss gate can be opened" % id)
		var unreachable: PackedStringArray = a.unreachable_things(main)
		var optional: Dictionary = a.analyze(true)
		var still: PackedStringArray = a.unreachable_things(optional)
		assert_eq(still.size(), 0, "%s: everything reachable (with optional bosses): %s" % [id, still])
		if LevelCatalog.level(id).boss_id == "":
			assert_eq(unreachable.size(), 0, "%s: no boss here, so nothing may need one: %s" % [id, unreachable])
		assert_eq(a.impossible_locks().size(), 0, "%s: no lock needs more than two knights" % id)
		root.free()


func _boss_gates(a) -> int:
	var n := 0
	for g: Node in a.gates:
		var c := g.get_node_or_null((g as PuzzleGate).controller)
		if c is BossSeal:
			n += 1
	return n


func test_the_analyzer_finds_blocked_levels() -> void:
	# A gate whose plate is behind the gate itself: the exit can never be reached.
	var spec := {"id": "broken", "title": "", "width": 60, "height": 20, "spawn": [3, 16], "ops": [
		["fill", 0, 0, 0, 19], ["fill", 59, 0, 59, 19], ["ground", 1, 58, 16],
		["plate", "Plate", 40, 16], ["gate", "Gate", 30, 16, 6, "Plate", 1], ["exit", 50, 16],
		["ground", 20, 24, 4], ["coins", 3, 22, 4]]}
	var builder = Builder.new()
	var root: Node2D = builder.build(spec, Themes.THEMES.forest)
	var a = Analyzer.new(root)
	var area: Dictionary = a.analyze(false)
	assert_false(a.exit_reachable(area), "blocked exit detected")
	assert_gt(a.unreachable_things(area).size(), 0, "unreachable coins and plate reported")
	root.free()
	# Duplicate ids are reported by the builder.
	var dup := {"id": "dup", "title": "", "width": 30, "height": 20, "spawn": [3, 16], "ops": [
		["ground", 1, 28, 16], ["plate", "Same", 10, 16], ["plate", "Same", 14, 16], ["exit", 20, 16]]}
	var b2 = Builder.new()
	var r2: Node2D = b2.build(dup, Themes.THEMES.forest)
	assert_gt(b2.errors.size(), 0, "duplicate ids reported")
	r2.free()
