extends GameTestCase
## The gameplay HUD inside a real CampaignGame (folder user://test_saves_ui/): both knights'
## health, upgraded maximum health, the shared coin counter, timed-effect indicators, the
## level name, and one HUD in every camera mode (never inside the camera SubViewports).

var game: CampaignGame
var hud: GameHud


func before_each() -> void:
	UiTestUtil.clean()
	game = SaveTestUtil.make_game(self, 1, CampaignGame.StartMode.NEW, UiTestUtil.DIR, true)
	assert_eq(game.begin(), OK, "campaign begins")
	hud = game.get_node("GameHud") as GameHud
	await physics_frames(5)


func after_each() -> void:
	get_tree().paused = false
	if is_instance_valid(game):
		game.queue_free()
	await physics_frames(2)
	UiTestUtil.clean()


func _k(i: int) -> Knight:
	return game.knights[i]


func _hold(p1: Vector2, p2: Vector2) -> void:
	for i in 2:
		_k(i).set_physics_process(false)
		_k(i).global_position = [p1, p2][i]


func test_both_players_health_is_shown_independently() -> void:
	assert_eq([hud.panel(1).hearts.current, hud.panel(1).hearts.maximum], [3, 3], "P1 3 of 3")
	assert_eq([hud.panel(2).hearts.current, hud.panel(2).hearts.maximum], [3, 3], "P2 3 of 3")
	_k(1).health.take_damage(DamageEvent.create(1, DamageEvent.Category.CONTACT, self))
	assert_eq(hud.panel(2).hearts.full_hearts(), 2, "P2 lost one heart at once")
	assert_eq(hud.panel(2).hearts.empty_hearts(), 1, "missing health shown as an empty heart")
	assert_eq(hud.panel(2).health_text.text, "2/3", "P2 text")
	assert_eq(hud.panel(1).health_text.text, "3/3", "P1 unaffected")
	assert_eq(hud.panel(1).tag.text, "P1", "P1 labelled, not only coloured")
	assert_eq(hud.panel(2).tag.text, "P2", "P2 labelled")
	assert_true(hud.panel(1).tag.get_theme_color(&"font_color") != hud.panel(2).tag.get_theme_color(&"font_color"), "different colours")
	_k(1).health.heal(1)
	assert_eq(hud.panel(2).health_text.text, "3/3", "healing shown")


func test_more_than_three_hearts() -> void:
	var p1 := RunState.current().player(1)
	p1.collect_jar(PlayerStats.JarType.GREEN)
	assert_eq([hud.panel(1).hearts.current, hud.panel(1).hearts.maximum], [4, 4], "green jar: 4 of 4")
	assert_eq(hud.panel(1).health_text.text, "4/4", "text follows the new maximum")
	for i in 8:
		p1.collect_jar(PlayerStats.JarType.GREEN)
	assert_eq(hud.panel(1).hearts.maximum, 12, "12 hearts")
	assert_eq(hud.panel(1).hearts.custom_minimum_size.y, float(2 * HealthDisplay.STEP - 1), "wraps onto a second row")
	_k(0).health.apply_damage(5)
	assert_eq([hud.panel(1).hearts.full_hearts(), hud.panel(1).hearts.empty_hearts()], [7, 5], "7 full, 5 empty")


func test_death_is_shown_clearly() -> void:
	_k(1).health.apply_damage(99)
	assert_true(hud.panel(2).hearts.dead, "hearts greyed")
	assert_eq(hud.panel(2).hearts.full_hearts(), 0, "no full hearts")
	assert_eq(hud.panel(2).health_text.text, "DOWN", "DOWN instead of a number")


func test_shared_coin_counter() -> void:
	assert_eq(hud.coin_label.text, "0", "starts at 0")
	RunState.current().collect_coin(1)
	assert_eq(hud.coin_label.text, "1", "P1 coin counted at once")
	RunState.current().collect_coin(2)
	assert_eq(hud.coin_label.text, "2", "P2 coin adds to the same total")
	assert_eq(hud.find_children("*", "Label", true, false).filter(func(l: Label) -> bool: return l == hud.coin_label).size(), 1, "one coin counter")


func test_effects_appear_under_the_right_player_and_count_down() -> void:
	var p2 := RunState.current().player(2)
	p2.collect_fruit(PlayerStats.FruitType.YELLOW, 2)
	p2.collect_jar(PlayerStats.JarType.YELLOW)
	var shield := hud.panel(2).indicator(PlayerEffects.FRUIT_SHIELD)
	assert_true(shield != null, "yellow fruit shield under P2")
	assert_true(hud.panel(2).indicator(PlayerEffects.JAR_LUCK) != null, "yellow jar luck under P2")
	assert_eq(hud.panel(1).indicator_ids().size(), 0, "nothing under P1")
	assert_eq(shield.text(), "SHIELD x2 10s", "identity, charges and seconds")
	await physics_frames(130)
	assert_eq(shield.text(), "SHIELD x2 8s", "the seconds count down")
	assert_true(hud.panel(2).indicator(PlayerEffects.FRUIT_SHIELD) == shield, "the same indicator (not rebuilt)")
	_k(1).health.take_damage(DamageEvent.create(1, DamageEvent.Category.CONTACT, self))
	await physics_frames(1)
	assert_true(shield.text().begins_with("SHIELD x1"), "a blocked hit uses a charge")
	assert_eq(_k(1).health.current_health, 3, "the hit was blocked")


func test_expired_effects_disappear() -> void:
	var p1 := RunState.current().player(1)
	p1.effects.add_tile_effect(PlayerEffects.SPEED_BOOST)
	assert_true(hud.panel(1).indicator(PlayerEffects.SPEED_BOOST) != null, "speed boost shown")
	assert_eq(hud.panel(1).indicator(PlayerEffects.SPEED_BOOST).text(), "SPEED 5s", "5 seconds")
	await physics_frames(int(5.2 * 60))
	assert_true(hud.panel(1).indicator(PlayerEffects.SPEED_BOOST) == null, "removed when it expires")
	assert_false(hud.panel(1).effects_row.visible, "empty row hidden")


func test_permanent_upgrades_shown() -> void:
	var p1 := RunState.current().player(1)
	assert_eq(hud.panel(1).upgrades.text, "", "nothing at the start")
	p1.collect_jar(PlayerStats.JarType.RED)
	p1.collect_fruit(PlayerStats.FruitType.PURPLE, 2)
	p1.collect_fruit(PlayerStats.FruitType.RED, 1)
	assert_eq(hud.panel(1).upgrades.text, "PWR 2  RANGE +10%  POISON 2s", "power, range and poison")
	assert_eq(hud.panel(2).upgrades.text, "", "P2 unaffected")


func test_world_and_level_from_the_catalog() -> void:
	assert_eq(hud.location_label.text, LevelCatalog.location_title("w1_l1"), "level 1")
	game.complete_level()
	await physics_frames(3)
	assert_eq(hud.location_label.text, "World 1 - Level 2", "updated for level 2")
	assert_eq([hud.panel(1).hearts.maximum, hud.panel(2).hearts.maximum], [3, 3], "rebound to the new knights")
	_k(0).health.apply_damage(1)
	assert_eq(hud.panel(1).health_text.text, "2/3", "follows the new level's knight")


func test_one_hud_in_every_camera_mode() -> void:
	var rig := game.rig
	var p1_rect := hud.panel(1).get_global_rect()
	var p2_rect := hud.panel(2).get_global_rect()
	_check_single_hud("shared")
	assert_eq(rig.mode, SplitScreenRig.Mode.SHARED, "starts shared")
	_hold(Vector2(80, 448), Vector2(1100, 448))
	await physics_frames(60)
	assert_eq([rig.mode, rig.orientation], [SplitScreenRig.Mode.SPLIT, CameraMath.Orientation.SIDE_BY_SIDE], "side-by-side split")
	_check_single_hud("side by side")
	assert_eq(hud.panel(1).get_global_rect(), p1_rect, "P1 panel stays put")
	assert_eq(hud.panel(2).get_global_rect(), p2_rect, "P2 panel stays put")
	_hold(Vector2(200, 448), Vector2(200, 120))
	await physics_frames(90)
	assert_eq([rig.mode, rig.orientation], [SplitScreenRig.Mode.SPLIT, CameraMath.Orientation.STACKED], "stacked split")
	_check_single_hud("stacked")
	assert_eq(hud.panel(2).get_global_rect(), p2_rect, "P2 panel stays put")
	# Back together: the merge transition and the shared view keep the same single HUD.
	_hold(Vector2(200, 448), Vector2(240, 448))
	var saw_merge := false
	for i in 120:
		await physics_frames(1)
		if rig.mode == SplitScreenRig.Mode.MERGING:
			saw_merge = true
			_check_single_hud("merging")
			assert_eq(hud.panel(1).get_global_rect(), p1_rect, "P1 panel steady while merging")
		if rig.mode == SplitScreenRig.Mode.SHARED:
			break
	assert_true(saw_merge, "went through the merge transition")
	assert_eq(rig.mode, SplitScreenRig.Mode.SHARED, "shared again")
	_check_single_hud("shared again")
	var screen := Rect2(Vector2.ZERO, Vector2(640, 360))
	for p in hud.panels:
		assert_true(screen.encloses(p.get_global_rect()), "%s fully on screen" % p.name)
	assert_false(hud.panel(1).get_global_rect().intersects(hud.panel(2).get_global_rect()), "panels never overlap")


func _check_single_hud(label: String) -> void:
	var huds := get_tree().root.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is GameHud)
	assert_eq(huds.size(), 1, "%s: exactly one HUD" % label)
	var node: Node = hud
	while node != null:
		assert_false(node is SubViewport, "%s: the HUD is not inside a camera SubViewport" % label)
		node = node.get_parent()
	assert_eq(hud.get_viewport(), get_tree().root, "%s: drawn in the main window" % label)
	for view in [SplitScreenRig.VIEW_A, SplitScreenRig.VIEW_B]:
		assert_eq(game.rig.viewport(view).find_children("*", "CanvasLayer", true, false).size(), 0, "%s: no UI layer in view %d" % [label, view])
