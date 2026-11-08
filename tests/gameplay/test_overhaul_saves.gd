extends GameTestCase
## Overhaul save behaviour on the production campaign: new enemy types, cracked blocks and arena
## locks persist through save and load; a mid-level save made with an older layout of a
## rebuilt level starts that level from its spawn instead of restoring stale positions.
## Folder user://test_saves_overhaul/ (never the player's real saves).

const DIR := "user://test_saves_overhaul/"

var games: Array[CampaignGame] = []


func before_each() -> void:
	SaveTestUtil.clean(DIR)
	LevelCatalog.use_production()
	RunState.reset()


func after_each() -> void:
	for g in games:
		if is_instance_valid(g):
			g.queue_free()
	games.clear()
	await physics_frames(2)
	SaveTestUtil.clean(DIR)
	LevelCatalog.use_production()


func _game(slot: int, mode: CampaignGame.StartMode) -> CampaignGame:
	var g := SaveTestUtil.make_game(self, slot, mode, DIR, true)
	games.append(g)
	return g


func _enter(g: CampaignGame, level_id: String) -> void:
	var run := RunState.current()
	for id in LevelCatalog.all_levels():
		if id == level_id:
			break
		run.campaign.complete_level(id)
	run.campaign.enter_level(level_id)
	g._load_level(level_id, {})
	await physics_frames(3)


func _first(level: Node, type: Variant) -> Node:
	for node in level.find_children("*", "", true, false):
		if is_instance_of(node, type) and not node.is_queued_for_deletion():
			return node
	return null


func test_new_enemies_blocks_and_arenas_persist() -> void:
	var g := _game(1, CampaignGame.StartMode.NEW)
	assert_eq(g.begin(), OK, "begins")
	await _enter(g, "l09")
	var guard := _first(g.level, OrcGuard) as OrcGuard
	var hit := DamageEvent.create(1, DamageEvent.Category.MELEE, g.knights[0])
	hit.direction = Vector2i(guard.facing, 0)  # from behind
	guard.hurtbox.receive_hit(hit)
	var guard_id := guard.save_id
	var guard_max := guard.stats.max_health
	var grunt := _first(g.level, OrcGrunt) as OrcGrunt
	var grunt_id := grunt.save_id
	grunt.kill()
	var block := _first(g.level, BreakableBlock) as BreakableBlock
	var blast := DamageEvent.create(2, DamageEvent.Category.MELEE, g.knights[0])
	blast.heavy = true
	block._on_hit(blast)
	var zone := _first(g.level, EncounterZone) as EncounterZone
	for e in zone._tracked:
		e.kill()
	await physics_frames(5)
	assert_eq(zone.phase, EncounterZone.Phase.DONE, "arena finished")
	assert_eq(g.save_now("test"), OK, "saved")
	g.queue_free()
	await physics_frames(2)
	RunState.reset()
	var g2 := _game(1, CampaignGame.StartMode.LOAD)
	assert_eq(g2.begin(), OK, "loads")
	await physics_frames(3)
	var guards := g2.level.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is OrcGuard and n.save_id == guard_id)
	assert_eq(guards.size(), 1, "the wounded guard is back")
	assert_eq((guards[0] as OrcGuard).health, guard_max - 1, "with its saved health")
	var grunts := g2.level.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is OrcGrunt and n.save_id == grunt_id and not n.is_queued_for_deletion())
	assert_eq(grunts.size(), 0, "the killed grunt stays dead")
	var block2 := _first(g2.level, BreakableBlock) as BreakableBlock
	assert_true(block2.is_broken, "the cracked block stays broken")
	var zone2 := _first(g2.level, EncounterZone) as EncounterZone
	assert_eq(zone2.phase, EncounterZone.Phase.DONE, "the arena stays finished (its gates open)")


func test_world_records_its_layout_and_old_layouts_start_fresh() -> void:
	var g := _game(1, CampaignGame.StartMode.NEW)
	assert_eq(g.begin(), OK, "begins")
	await _enter(g, "l03")
	var world := WorldSnapshot.capture(g.level, g.knights)
	assert_eq(world.layout, LevelCatalog.level("l03").layout_version, "the save names the layout it was made with")
	assert_eq(WorldSnapshot.for_current_layout(world, "l03"), world, "same layout: restored")
	var old := world.duplicate(true)
	old.layout = 1
	assert_true(WorldSnapshot.for_current_layout(old, "l03").is_empty(), "older layout: the level starts fresh")
	old.erase("layout")
	assert_true(WorldSnapshot.for_current_layout(old, "l03").is_empty(), "a pre-versioning save counts as layout 1")
	assert_eq(WorldSnapshot.validate(old, "l03"), "", "an old-format world still validates (no save is rejected for it)")
