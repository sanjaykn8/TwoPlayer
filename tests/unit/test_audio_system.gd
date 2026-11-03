extends GameTestCase
## Audio buses, AudioConfig, Sfx routing and limits, and AudioManager music behaviour.

var audio: AudioManager


func before_each() -> void:
	audio = AudioManager.new()
	add_child(audio)
	await get_tree().process_frame


func after_each() -> void:
	get_tree().paused = false
	audio.queue_free()
	await get_tree().process_frame


func _music_players() -> int:
	var count := 0
	for node in get_tree().root.find_children("*", "AudioStreamPlayer", true, false):
		if (node as AudioStreamPlayer).bus == &"Music":
			count += 1
	return count


func test_bus_layout() -> void:
	assert_eq(AudioServer.bus_count, 3, "three buses")
	for bus in [&"Master", &"Music", &"SFX"]:
		assert_true(AudioServer.get_bus_index(bus) >= 0, "%s exists" % bus)
	assert_eq(AudioServer.get_bus_send(AudioServer.get_bus_index(&"Music")), &"Master", "Music -> Master")
	assert_eq(AudioServer.get_bus_send(AudioServer.get_bus_index(&"SFX")), &"Master", "SFX -> Master")


func test_config_only_names_existing_files() -> void:
	var config: AudioConfig = load(Sfx.AUDIO_CONFIG)
	assert_eq(config.validate().size(), 0, "valid: %s" % ", ".join(config.validate()))
	for cue in ["ui_move", "ui_confirm", "ui_cancel", "attack", "enemy_hit", "enemy_death", "player_damage",
			"player_death", "level_transition", "victory", "game_over"]:
		assert_true(config.cues.has(cue), "cue %s configured" % cue)
	assert_true(config.track_for_context("menu") != "", "menu music")
	assert_true(config.track_for_world("w1") != "", "world 1 music")
	for world in LevelCatalog.WORLDS:
		assert_true(config.music_tracks.has(config.track_for_world(world)), "%s has a track" % world)


func test_effects_play_on_the_sfx_bus_and_pause_with_the_game() -> void:
	var player := Sfx.cue(&"enemy_hit", self)
	assert_true(player != null, "played")
	assert_eq(player.bus, &"SFX", "gameplay effect on SFX")
	assert_eq(player.process_mode, Node.PROCESS_MODE_PAUSABLE, "gameplay effects pause with the game")
	await get_tree().process_frame
	var ui := Sfx.cue(&"ui_confirm", self, true)
	assert_eq(ui.bus, &"SFX", "menu effect on SFX")
	assert_eq(ui.process_mode, Node.PROCESS_MODE_ALWAYS, "menu effects work while paused")


func test_bursts_are_limited() -> void:
	await get_tree().process_frame
	var first := Sfx.play(Sfx.COIN, self)
	var same_frame := Sfx.play(Sfx.COIN, self)
	assert_true(first != null, "first coin plays")
	assert_true(same_frame == null, "the same sound twice in one frame plays once")
	# Many different sounds in one frame: only max_voices play at once.
	await get_tree().process_frame
	var started := 0
	for i in 20:
		if Sfx.play(Sfx.TAP.duplicate(), self) != null:
			started += 1
	assert_true(Sfx._playing <= Sfx.config().max_voices, "never more than the voice limit at once (%d)" % Sfx._playing)
	assert_true(started < 20, "extra requests are dropped (%d of 20 started)" % started)


func test_music_starts_once_and_never_restarts() -> void:
	audio.play_context("menu")
	await get_tree().process_frame
	audio.play_context("menu")
	audio.play_track("menu")
	for i in 40:
		await get_tree().process_frame
	assert_eq(audio.current_track, "menu", "menu track")
	assert_eq(audio.start_count, 1, "started once")
	assert_true(audio.is_music_playing(), "playing")
	assert_eq(audio.music_player().bus, &"Music", "on the Music bus")
	assert_eq(_music_players(), 1, "one music player")


func test_tracks_switch_and_stop_cleanly() -> void:
	audio.play_context("menu")
	for i in 40:
		await get_tree().process_frame
	audio.play_level("w1_l2")
	for i in 60:
		await get_tree().process_frame
	assert_eq(audio.current_track, "world_1", "world track for a world 1 level")
	assert_eq(audio.start_count, 2, "one start per change")
	assert_eq(audio.music_player().pitch_scale, 1.0, "gameplay settings applied")
	audio.play_context("game_over")
	for i in 60:
		await get_tree().process_frame
	assert_eq(audio.current_track, "", "game over is silent")
	assert_false(audio.is_music_playing(), "stopped")
	assert_eq(_music_players(), 1, "still one music player")


func test_pause_policy_ducks_music() -> void:
	audio.play_level("w1_l1")
	for i in 60:
		await get_tree().process_frame
	var normal := audio.music_player().volume_db
	get_tree().paused = true
	audio.set_ducked(true)
	await get_tree().process_frame
	assert_near(audio.music_player().volume_db, normal + Sfx.config().pause_duck_db, 0.01, "quieter while paused")
	assert_true(audio.is_music_playing(), "music keeps playing while paused")
	audio.set_ducked(false)
	get_tree().paused = false
	assert_near(audio.music_player().volume_db, normal, 0.01, "back to normal")
