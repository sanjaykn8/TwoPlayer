extends GameTestCase
## Audio in the running application (one music player, transitions, menu and gameplay sounds
## on the right bus, pause policy, sliders driving the buses) and the controls screen's
## accuracy against the InputMap. Folder user://test_saves_ui/.

var app: GameApp


func before_each() -> void:
	UiTestUtil.clean()


func after_each() -> void:
	UiTestUtil.free_app(app)
	await physics_frames(2)
	UiTestUtil.clean()
	for bus in [&"Master", &"Music", &"SFX"]:
		AudioManager.set_bus_percent(bus, 100)


func _open() -> void:
	app = UiTestUtil.make_app(self)
	for i in 3:
		await get_tree().process_frame


func _music_players() -> int:
	return get_tree().root.find_children("*", "AudioStreamPlayer", true, false).filter(
		func(p: AudioStreamPlayer) -> bool: return p.bus == &"Music").size()


func test_menu_music_plays_once() -> void:
	await _open()
	for i in 40:
		await get_tree().process_frame
	assert_eq(app.audio.current_track, "menu", "menu track")
	assert_eq(app.audio.start_count, 1, "started once")
	for i in 3:
		app.open_settings()
		await get_tree().process_frame
		app.stack.top().close()
		app.show_main_menu()
		await get_tree().process_frame
	assert_eq(app.audio.start_count, 1, "never restarted by screen changes")
	assert_eq(_music_players(), 1, "one music player")


func test_gameplay_music_transitions_without_duplicates() -> void:
	await _open()
	app.start_new_campaign(1)
	for i in 40:
		await get_tree().process_frame
	assert_eq(app.audio.current_track, "world_1", "world music in the level")
	app.return_to_menu()
	for i in 40:
		await get_tree().process_frame
	assert_eq(app.audio.current_track, "menu", "menu music again")
	app.continue_campaign(1)
	for i in 40:
		await get_tree().process_frame
	assert_eq(app.audio.current_track, "world_1", "world music again")
	assert_eq(app.audio.start_count, 4, "one start per change")
	assert_eq(_music_players(), 1, "still one music player")
	assert_eq(get_tree().root.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is AudioManager).size(), 1, "one AudioManager")


func test_menu_sounds() -> void:
	await _open()
	var before := Sfx.started
	await UiTestUtil.tap(get_tree(), KEY_DOWN)
	assert_eq(Sfx.last_cue, &"ui_move", "navigation sound")
	assert_eq(Sfx.last_bus, &"SFX", "on the SFX bus")
	await UiTestUtil.tap(get_tree(), KEY_ENTER)
	assert_eq(Sfx.last_cue, &"ui_confirm", "confirm sound")
	await UiTestUtil.tap(get_tree(), KEY_ESCAPE)
	assert_eq(Sfx.last_cue, &"ui_cancel", "cancel sound")
	assert_gt(Sfx.started, before, "sounds started")


func test_gameplay_sounds_use_the_sfx_bus_and_pause() -> void:
	await _open()
	app.start_new_campaign(1)
	await physics_frames(10)
	var knight := app.campaign.knights[0]
	await physics_frames(20)
	Input.action_press(&"p1_attack")
	await physics_frames(2)
	Input.action_release(&"p1_attack")
	assert_eq(Sfx.last_cue, &"attack", "attack sound")
	assert_eq(Sfx.last_bus, &"SFX", "on the SFX bus")
	knight.health.take_damage(DamageEvent.create(1, DamageEvent.Category.CONTACT, self))
	assert_eq(Sfx.last_cue, &"player_damage", "damage sound")
	await get_tree().process_frame
	var effect := Sfx.cue(&"enemy_death", knight)
	assert_true(effect != null, "a gameplay sound is playing")
	if effect == null:
		return
	app.pause_game()
	await get_tree().process_frame
	assert_false(effect.can_process(), "gameplay sounds pause with the game")
	assert_true(app.audio.ducked and app.audio.is_music_playing(), "music continues, quieter")
	app.resume_game()
	assert_false(app.audio.ducked, "full volume again")


func test_sliders_drive_the_real_buses() -> void:
	await _open()
	var screen := app.open_settings()
	await get_tree().process_frame
	var sfx: SettingsSlider = screen.sliders["sfx_volume"]
	sfx.slider.value = 30
	assert_eq(AudioManager.bus_percent(&"SFX"), 30, "SFX bus follows its slider")
	assert_eq(int(app.settings.get_value("sfx_volume")), 30, "stored")
	assert_eq(AudioManager.bus_percent(&"Music"), int(app.settings.get_value("music_volume")), "music unchanged")
	# Keyboard: the master slider has focus; Left lowers it by one step.
	assert_eq(UiTestUtil.focus_owner(get_tree()), (screen.sliders["master_volume"] as SettingsSlider).slider, "master slider focused")
	var master_before := AudioManager.bus_percent(&"Master")
	await UiTestUtil.tap(get_tree(), KEY_LEFT)
	assert_eq(AudioManager.bus_percent(&"Master"), master_before - 5, "Left lowers the master bus")
	await UiTestUtil.tap(get_tree(), KEY_DOWN)
	assert_eq(UiTestUtil.focus_owner(get_tree()), (screen.sliders["music_volume"] as SettingsSlider).slider, "Down moves to Music")
	screen.reset_audio_button.pressed.emit()
	assert_eq(AudioManager.bus_percent(&"SFX"), 80, "reset to default")
	assert_eq((screen.sliders["sfx_volume"] as SettingsSlider).value(), 80, "slider shows the reset")


func test_display_options() -> void:
	await _open()
	var screen := app.open_settings()
	await get_tree().process_frame
	screen.mode_option.step(1)
	assert_eq(app.settings.get_value("fullscreen"), true, "fullscreen chosen")
	assert_eq(app.settings.last_display_request.fullscreen, true, "fullscreen requested from the window")
	assert_true(screen.size_option.button.disabled, "window size is not used in fullscreen")
	screen.mode_option.step(1)
	assert_eq(app.settings.get_value("fullscreen"), false, "windowed again")
	screen.size_option.set_options(screen.size_option.options, 0)
	screen.size_option.step(1)
	assert_eq(app.settings.last_display_request.size, SettingsManager.LOGICAL_SIZE * SettingsManager.available_scales()[1], "next whole-number size")
	screen.reset_display_button.pressed.emit()
	assert_eq(app.settings.last_display_request, {"fullscreen": false, "size": Vector2i(1280, 720)}, "default display")


func test_controls_screen_matches_the_input_map() -> void:
	await _open()
	var screen := app.open_controls()
	await get_tree().process_frame
	var listed := ControlsScreen.listed_keys()
	var actions := ["move_up", "move_left", "move_down", "move_right", "attack"]
	for p in [1, 2]:
		for i in actions.size():
			var action := StringName("p%d_%s" % [p, actions[i]])
			for event in InputMap.action_get_events(action):
				var name := OS.get_keycode_string((event as InputEventKey).physical_keycode)
				assert_true(str(listed[p][i]).contains(name), "P%d %s lists %s (got %s)" % [p, actions[i], name, listed[p][i]])
	assert_eq(listed[1], ["W", "A", "S", "D", "V"], "Player One keys")
	assert_eq(listed[2], ["Up Arrow", "Left Arrow", "Down Arrow", "Right Arrow", "Left Alt / Right Alt"], "Player Two keys")
	var text := " ".join(screen.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text))
	for phrase in ["one keyboard", "climb", "drop", "crouch", "Attacks go the way you last moved", "no interact button"]:
		assert_true(text.contains(phrase), "explains: %s" % phrase)
	await UiTestUtil.tap(get_tree(), KEY_ESCAPE)
	assert_true(app.stack.top() is MainMenu, "Escape returns")
