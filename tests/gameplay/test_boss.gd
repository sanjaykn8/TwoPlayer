extends GameTestCase
## Optional bosses at run time (Phase 10 Part L), in their real arenas: they wake when a knight
## enters, telegraph (squash, "!", a landing mark) before every leap, land with a shockwave
## that hurts grounded knights close by, are dazed afterwards, and follow their damage rules.

const DIR := "user://test_saves_boss/"

var game: CampaignGame
var _attack := 81000


func before_each() -> void:
	SaveTestUtil.clean(DIR)
	LevelCatalog.use_production()
	RunState.reset()
	game = SaveTestUtil.make_game(self, 1, CampaignGame.StartMode.NEW, DIR, true)
	assert_eq(game.begin(), OK, "campaign begins")


func after_each() -> void:
	if is_instance_valid(game):
		game.queue_free()
	await physics_frames(2)
	SaveTestUtil.clean(DIR)
	LevelCatalog.use_production()


func _boss_in(level_id: String) -> BossSlime:
	RunState.current().campaign.enter_level(level_id)
	assert_eq(game._load_level(level_id, {}), "", "%s loads" % level_id)
	for node in game.level.find_children("*", "", true, false):
		if node is BossSlime:
			return node
	return null


func _hit(boss: BossSlime, knight: Knight) -> void:
	_attack += 1
	var e := DamageEvent.create(1, DamageEvent.Category.MELEE, knight)
	e.attack_id = _attack
	boss.hurtbox.receive_hit(e)


func test_boss_wakes_telegraphs_leaps_and_shocks() -> void:
	var boss := _boss_in("l07")
	await physics_frames(5)
	assert_eq(boss.state, BossSlime.State.DORMANT, "asleep while nobody is in the arena")
	var k := game.knights[0]
	k.teleport_to(boss.global_position + Vector2(40, 0))
	game.knights[1].teleport_to(Vector2(40, 24 * 16))
	var saw := {}
	var shocked := false
	var start_health := k.health.current_health
	for i in 600:
		await physics_frames(1)
		saw[boss.state] = true
		if k.health.current_health < start_health:
			shocked = true
		if saw.has(BossSlime.State.DAZED):
			break
	assert_true(saw.has(BossSlime.State.STALK), "wakes and stalks the knight")
	assert_true(saw.has(BossSlime.State.TELEGRAPH), "telegraphs before leaping")
	assert_true(saw.has(BossSlime.State.LEAP), "leaps")
	assert_true(saw.has(BossSlime.State.DAZED), "is dazed after landing")
	assert_true(shocked, "the landing (or contact) hurt the grounded knight next to it")
	assert_true(boss.arena_rect().has_point(boss.global_position), "never leaves its arena")


func test_magma_heart_is_only_hurt_while_dazed_and_leaves_embers() -> void:
	var boss := _boss_in("l15")
	await physics_frames(2)
	var k := game.knights[0]
	boss.state = BossSlime.State.STALK
	_hit(boss, k)
	assert_eq(boss.health, boss.stats.max_health, "a hit outside the daze clangs off")
	boss.state = BossSlime.State.DAZED
	_hit(boss, k)
	assert_eq(boss.health, boss.stats.max_health - 1, "a hit while dazed counts")
	boss._land()
	var embers := game.level.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is BossEmber)
	assert_gt(embers.size(), 0, "landing leaves burning ground")


func test_citadel_warden_needs_both_knights_together() -> void:
	var boss := _boss_in("l23")
	await physics_frames(2)
	boss.state = BossSlime.State.STALK
	var full := boss.stats.max_health
	_hit(boss, game.knights[0])
	await physics_frames(5)
	_hit(boss, game.knights[0])
	assert_eq(boss.health, full, "one knight alone cannot break the armour")
	await physics_frames(int(boss.stats.sync_window * 60.0) + 10)
	_hit(boss, game.knights[1])
	assert_eq(boss.health, full, "a strike long after the other knight's does not count")
	await physics_frames(10)
	_hit(boss, game.knights[0])
	assert_eq(boss.health, full - 1, "strikes from both knights within the window count")


func test_brood_mother_summons_minions() -> void:
	var boss := _boss_in("l07")
	await physics_frames(2)
	game.knights[0].teleport_to(boss.global_position + Vector2(60, 0))
	for i in boss.stats.minion_every_leaps:
		boss._land()
	await physics_frames(2)
	assert_gt(boss.minions.size(), 0, "minions appear after her leaps")
	for m in boss.minions:
		assert_true(m is Slime and (m as Slime).save_id == "", "minions are ordinary slimes and are not saved")
