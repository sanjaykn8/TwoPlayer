extends GameTestCase
## SettingsManager: user://settings.cfg (tests use user://test_settings_ui.cfg), per-value
## validation, persistence across a restart, real bus volumes, display requests, and complete
## independence from the campaign save slots.

const PATH := UiTestUtil.SETTINGS

func before_each() -> void:
	UiTestUtil.clean()


func after_each() -> void:
	UiTestUtil.clean()
	for bus in [&"Master", &"Music", &"SFX"]:
		AudioManager.set_bus_percent(bus, 100)  # the bus layout's 0 dB


func _manager() -> SettingsManager:
	var s := SettingsManager.new(PATH)
	s.touch_window = false
	return s


func test_location_is_separate_from_saves() -> void:
	assert_eq(SettingsManager.PATH, "user://settings.cfg", "real settings file")
	assert_false(SettingsManager.PATH.begins_with(SavePaths.SAVE_DIR), "not inside the saves folder")
	assert_false(SettingsManager.PATH.begins_with("res://"), "not in the project")


func test_missing_file_gives_defaults() -> void:
	var s := _manager()
	assert_eq(s.load_settings(), OK, "missing file is fine")
	assert_eq(s.values, SettingsManager.DEFAULTS, "all defaults")
	assert_eq(s.warnings.size(), 0, "no warnings")


func test_values_survive_a_restart() -> void:
	var s := _manager()
	s.load_settings()
	assert_true(s.set_value("master_volume", 55), "master accepted")
	assert_true(s.set_value("music_volume", 20), "music accepted")
	assert_true(s.set_value("sfx_volume", 0), "sfx accepted")
	assert_true(s.set_value("fullscreen", true), "fullscreen accepted")
	assert_true(FileAccess.file_exists(PATH), "written at once")
	assert_false(FileAccess.file_exists(PATH + ".tmp"), "no temporary file left")
	var again := _manager()  # a new application start
	again.load_settings()
	assert_eq([again.get_value("master_volume"), again.get_value("music_volume"), again.get_value("sfx_volume"), again.get_value("fullscreen")],
		[55, 20, 0, true], "same values after a restart")


func test_invalid_values_fall_back_individually() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_volume", 250)
	cfg.set_value("audio", "music_volume", "loud")
	cfg.set_value("audio", "sfx_volume", 35)
	cfg.set_value("display", "fullscreen", "yes")
	cfg.set_value("display", "window_scale", -3)
	cfg.save(PATH)
	var s := _manager()
	assert_eq(s.load_settings(), OK, "file read")
	assert_eq(s.get_value("master_volume"), 80, "out of range -> default")
	assert_eq(s.get_value("music_volume"), 70, "wrong type -> default")
	assert_eq(s.get_value("sfx_volume"), 35, "valid value kept")
	assert_eq(s.get_value("fullscreen"), false, "non-bool -> default")
	assert_eq(s.get_value("window_scale"), 2, "bad scale -> default")
	assert_eq(s.warnings.size(), 4, "each problem reported")
	assert_false(s.set_value("music_volume", -1), "setter refuses invalid values")
	assert_false(s.set_value("unknown_key", 1), "unknown keys refused")
	assert_eq(s.get_value("music_volume"), 70, "unchanged after a refused value")


func test_malformed_file_gives_defaults() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("[audio\nmaster_volume = = =\ngarbage ][[ \"")
	f.close()
	var s := _manager()
	assert_true(s.load_settings() != OK, "parse error reported")
	assert_eq(s.values, SettingsManager.DEFAULTS, "defaults used")
	assert_gt(s.warnings.size(), 0, "warning recorded")


func test_volumes_set_real_bus_levels_independently() -> void:
	var s := _manager()
	s.load_settings()
	s.set_value("master_volume", 50)
	assert_eq(AudioManager.bus_percent(&"Master"), 50, "master bus at 50 %")
	assert_near(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Master")), linear_to_db(0.5), 0.01, "master dB")
	s.set_value("music_volume", 25)
	assert_eq(AudioManager.bus_percent(&"Music"), 25, "music bus at 25 %")
	assert_eq(AudioManager.bus_percent(&"Master"), 50, "master unchanged by music")
	s.set_value("sfx_volume", 0)
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"SFX")), "0 % mutes the SFX bus")
	assert_eq(AudioManager.bus_percent(&"Music"), 25, "music unchanged by effects")
	s.set_value("sfx_volume", 90)
	assert_false(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"SFX")), "unmuted again")
	assert_eq(AudioManager.bus_percent(&"SFX"), 90, "effects at 90 %")
	s.reset_audio()
	assert_eq([AudioManager.bus_percent(&"Master"), AudioManager.bus_percent(&"Music"), AudioManager.bus_percent(&"SFX")],
		[80, 70, 80], "reset restores the default buses")


func test_display_requests_keep_the_pixel_grid() -> void:
	var s := _manager()
	s.load_settings()
	s.apply_display()
	assert_eq(s.last_display_request, {"fullscreen": false, "size": Vector2i(1280, 720)}, "default window 1280x720")
	s.set_value("window_scale", 3)
	assert_eq(s.last_display_request.size, Vector2i(1920, 1080), "3x is 1920x1080 (16:9, whole multiple)")
	s.set_value("fullscreen", true)
	assert_eq(s.last_display_request.fullscreen, true, "fullscreen requested")
	s.reset_display()
	assert_eq(s.last_display_request, {"fullscreen": false, "size": Vector2i(1280, 720)}, "reset to the default window")
	for scale in SettingsManager.available_scales():
		var size := SettingsManager.LOGICAL_SIZE * scale
		assert_eq(size.x * 9, size.y * 16, "%s is 16:9" % SettingsManager.resolution_label(scale))
	# Project rendering stays 640x360, integer scaled, nearest filter.
	assert_eq(ProjectSettings.get_setting("display/window/stretch/scale_mode"), "integer", "integer scaling")
	assert_eq(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter"), 0, "nearest")


func test_campaign_deletion_and_wipes_never_touch_settings() -> void:
	var s := _manager()
	s.load_settings()
	s.set_value("music_volume", 33)
	var before := FileAccess.get_file_as_string(PATH)
	UiTestUtil.write_campaign(1, 5)
	var manager := SaveManager.new(UiTestUtil.DIR)
	manager.delete_slot(1)
	manager.start_new_run(2)
	manager.invalidate_run_after_death(2, RunState.current().campaign.campaign_id)
	assert_eq(FileAccess.get_file_as_string(PATH), before, "settings file unchanged")
	assert_false(DirAccess.get_files_at(UiTestUtil.DIR).has("settings.cfg"), "no settings in the saves folder")
	for file in DirAccess.get_files_at(UiTestUtil.DIR):
		assert_false(SaveTestUtil.read(UiTestUtil.DIR, file).contains("music_volume"), "%s holds no preferences" % file)
