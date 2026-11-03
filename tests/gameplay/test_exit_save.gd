extends GameTestCase
## Save-on-exit through a real Godot process: a child process plays a campaign and receives
## the window-close notification (tests/integration/exit_save_child.gd); this test checks how
## it exited and what it left in user://test_saves_exit/. Ordinary closing only: abrupt
## termination or power loss is not covered (the last completed save remains).

const DIR := "user://test_saves_exit/"


func before_each() -> void:
	SaveTestUtil.clean(DIR)


func after_each() -> void:
	SaveTestUtil.clean(DIR)


func _run_child(mode: String) -> int:
	var output := []
	var args := ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--fixed-fps", "60",
		"--script", "res://tests/integration/exit_save_child.gd", "--", mode]
	return OS.execute(OS.get_executable_path(), args, output, true)


func _expected() -> Dictionary:
	var data: Variant = JSON.parse_string(SaveTestUtil.read(DIR, "expected.json"))
	return data if typeof(data) == TYPE_DICTIONARY else {}


func test_closing_the_window_saves_before_the_process_exits() -> void:
	assert_eq(_run_child("exit"), 0, "the child quit by itself after saving")
	var exp := _expected()
	assert_false(exp.is_empty(), "the child recorded its state")
	var mgr := SaveManager.new(DIR)
	assert_eq(mgr.slot_status(3), SaveManager.Status.VALID, "slot 3 holds a valid save")
	assert_false(FileAccess.file_exists(DIR + "slot_3.dead"), "closing is not dying: nothing invalidated")
	for other in [1, 2, 4]:
		assert_eq(mgr.slot_status(other), SaveManager.Status.EMPTY, "slot %d untouched" % other)
	var result := mgr.load_run(3)
	assert_true(result.ok, "loads")
	var run := RunState.current()
	assert_eq(run.campaign.campaign_id, exp.campaign_id, "the same campaign (not a fresh one)")
	assert_eq(run.coins, int(exp.coins), "coins")
	assert_eq(run.player(2).current_health, int(exp.p2_health), "P2 health")
	assert_near(run.player(1).effects.remaining(PlayerEffects.SPEED_BOOST), float(exp.speed_left), 0.0001, "effect time as at closing")
	assert_near(run.campaign.playtime, float(exp.playtime), 0.05, "play time")
	assert_near(float(result.world.players["1"].x), float(exp.p1_x), 0.001, "P1 position")
	assert_near(float(result.world.players["1"].y), float(exp.p1_y), 0.001, "P1 height")
	# Relaunch in this process and check the knights come back where they were.
	var game := SaveTestUtil.make_game(self, 3, CampaignGame.StartMode.LOAD, DIR)
	assert_eq(game.begin(), OK, "the next launch resumes")
	assert_near(game.knights[0].global_position.x, float(exp.p1_x), 0.001, "P1 restored")
	assert_eq(game.wipes, 0, "no team wipe")
	game.queue_free()
	await physics_frames(2)


func test_quitting_during_a_team_wipe_never_restores_the_dead_run() -> void:
	var mgr := SaveManager.new(DIR)
	for s in [1, 2]:
		mgr.start_new_run(s)
		RunState.current().coins = s
		mgr.save_active_run({})
	var others := [SaveTestUtil.read(DIR, "slot_1.save"), SaveTestUtil.read(DIR, "slot_2.save")]
	assert_eq(_run_child("wipe_quit"), 0, "the child quit by itself")
	var exp := _expected()
	assert_eq(exp.get("phase_at_close"), "WIPING", "closed while the wipe was running")
	var status := mgr.slot_status(3)
	assert_true(status == SaveManager.Status.INVALIDATED, "slot 3 needs a new campaign (got %s)" % SaveManager.status_name(status))
	assert_false(mgr.load_run(3).ok, "the dead campaign cannot be loaded")
	assert_false(SaveTestUtil.read(DIR, "slot_3.save").contains(exp.campaign_id), "not on disk as a save")
	assert_false(SaveTestUtil.read(DIR, "slot_3.bak").contains(exp.campaign_id), "not on disk as a backup")
	assert_eq([SaveTestUtil.read(DIR, "slot_1.save"), SaveTestUtil.read(DIR, "slot_2.save")], others, "slots 1 and 2 untouched")
	assert_eq(mgr.start_new_run(3), OK, "an explicit new campaign starts in slot 3")
