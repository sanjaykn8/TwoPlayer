extends SceneTree
## Child process for tests/gameplay/test_exit_save.gd (not discovered by the test runner).
## Plays a campaign in slot 3 of user://test_saves_exit/, then sends the window-close
## notification the OS sends when the player closes the window. Modes:
##   exit       make progress, record what is expected, close -> must save, then exit 0
##   wipe_quit  save progress, kill P1 (team wipe starts), close during the wipe -> exit 0
## Exit code 3 means the game did not quit by itself.

const DIR := "user://test_saves_exit/"
const GAME := "res://scenes/campaign/campaign_game.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var mode: String = OS.get_cmdline_user_args()[0]
	LevelCatalog.use_development()  # the exit tests use the Phase 8 levels
	RunState.reset()
	var game := (load(GAME) as PackedScene).instantiate() as CampaignGame
	game.save_dir = DIR
	game.slot = 3
	game.start_mode = CampaignGame.StartMode.NEW
	game.overwrite = true
	game.auto_begin = false
	game.wipe_delay = 3.0
	root.add_child(game)
	if game.begin() != OK:
		quit(4)
		return
	for i in 10:
		await physics_frame
	var k1: Knight = game.knights[0]
	var k2: Knight = game.knights[1]
	var run := RunState.current()
	var expected := {"mode": mode, "campaign_id": run.campaign.campaign_id}
	match mode:
		"exit":
			run.coins = 7
			run.player(1).effects.add_tile_effect(PlayerEffects.SPEED_BOOST)
			k1.teleport_to(Vector2(300, 448))
			k2.health.take_damage(DamageEvent.create(1, DamageEvent.Category.CONTACT, null))
			for i in 30:
				await physics_frame
			expected.merge({"coins": 7, "p1_x": k1.global_position.x, "p1_y": k1.global_position.y,
				"p2_health": k2.health.current_health,
				"speed_left": run.player(1).effects.remaining(PlayerEffects.SPEED_BOOST),
				"playtime": run.campaign.playtime})
		"wipe_quit":
			run.coins = 9
			game.save_now("progress")
			k1.health.apply_damage(99)
			await physics_frame
			expected.merge({"phase_at_close": game.phase_name()})
	var file := FileAccess.open(DIR + "expected.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(expected))
	file.close()
	root.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	for i in 120:
		await process_frame
	quit(3)
