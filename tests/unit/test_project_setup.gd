extends GameTestCase
## Project configuration, InputMap and save-directory checks.

const ACTIONS := {
	&"p1_move_left": KEY_A, &"p1_move_right": KEY_D, &"p1_move_up": KEY_W,
	&"p1_move_down": KEY_S, &"p1_attack": KEY_V,
	&"p2_move_left": KEY_LEFT, &"p2_move_right": KEY_RIGHT, &"p2_move_up": KEY_UP,
	&"p2_move_down": KEY_DOWN, &"p2_attack": KEY_ALT,
}


func _key(physical: Key, location := KEY_LOCATION_UNSPECIFIED, alt := false) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = physical
	e.keycode = physical
	e.location = location
	e.alt_pressed = alt
	e.pressed = true
	return e


func _matching_gameplay_actions(event: InputEvent) -> Array:
	var hits := []
	for action in ACTIONS:
		if InputMap.event_is_action(event, action):
			hits.append(action)
	return hits


func test_rendering_and_window_settings() -> void:
	var s := ProjectSettings
	assert_eq(s.get_setting("rendering/renderer/rendering_method"), "gl_compatibility", "Compatibility renderer")
	assert_eq(s.get_setting("display/window/size/viewport_width"), 640, "logical width")
	assert_eq(s.get_setting("display/window/size/viewport_height"), 360, "logical height")
	assert_eq(s.get_setting("display/window/size/window_width_override"), 1280, "window width")
	assert_eq(s.get_setting("display/window/size/window_height_override"), 720, "window height")
	assert_eq(s.get_setting("display/window/stretch/mode"), "viewport", "viewport stretch")
	assert_eq(s.get_setting("display/window/stretch/aspect"), "keep", "keep aspect (letterbox)")
	assert_eq(s.get_setting("display/window/stretch/scale_mode"), "integer", "integer scaling")
	assert_eq(s.get_setting("rendering/textures/canvas_textures/default_texture_filter"), 0, "nearest filter")


func test_save_directory_identity() -> void:
	assert_eq(ProjectSettings.get_setting("application/config/use_custom_user_dir"), true, "custom user dir on")
	assert_eq(ProjectSettings.get_setting("application/config/custom_user_dir_name"), SavePaths.USER_DIR_NAME, "dir name")
	var user_dir := ProjectSettings.globalize_path("user://").replace("\\", "/").trim_suffix("/")
	assert_true(user_dir.ends_with("/TwoKnightCoop"), "user:// resolves to .../TwoKnightCoop (got %s)" % user_dir)
	var appdata := OS.get_environment("APPDATA").replace("\\", "/")
	if appdata != "":
		assert_eq(user_dir.to_lower(), (appdata + "/TwoKnightCoop").to_lower(), "user:// is %APPDATA%/TwoKnightCoop")
	assert_eq(SavePaths.ensure_save_dir(), OK, "saves dir can be created")
	assert_true(DirAccess.dir_exists_absolute("user://saves"), "user://saves exists")
	var project_dir := ProjectSettings.globalize_path("res://")
	assert_false(SavePaths.absolute_save_dir().begins_with(project_dir), "saves are outside the project folder")
	assert_eq(SavePaths.slot_path(4), "user://saves/slot_4.json", "slot path format")


func test_gameplay_actions_exist_with_correct_keys() -> void:
	for action: StringName in ACTIONS:
		if not InputMap.has_action(action):
			fail("missing action %s" % action)
			continue
		var events := InputMap.action_get_events(action)
		assert_gt(events.size(), 0, "%s has events" % action)
		for e in events:
			var key := e as InputEventKey
			assert_true(key != null, "%s uses keyboard events" % action)
			if key:
				assert_eq(key.physical_keycode, ACTIONS[action], "%s physical key" % action)
				assert_eq(key.device, -1, "%s applies to all devices" % action)


func test_actions_are_exclusive_per_player() -> void:
	# Every gameplay key must map to exactly one gameplay action.
	for action: StringName in ACTIONS:
		var hits := _matching_gameplay_actions(_key(ACTIONS[action], KEY_LOCATION_LEFT))
		assert_eq(hits.size(), 1, "%s key triggers only one gameplay action (got %s)" % [action, hits])


func test_alt_variants_and_modifier_independence() -> void:
	assert_eq(_matching_gameplay_actions(_key(KEY_ALT, KEY_LOCATION_LEFT, true)), [&"p2_attack"], "Left Alt")
	assert_eq(_matching_gameplay_actions(_key(KEY_ALT, KEY_LOCATION_RIGHT, true)), [&"p2_attack"], "Right Alt")
	assert_eq(_matching_gameplay_actions(_key(KEY_ALT, KEY_LOCATION_UNSPECIFIED, true)), [&"p2_attack"], "Alt without location")
	# While Player Two holds Alt, Player One's keys arrive with alt_pressed = true.
	for key: Key in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_V, KEY_UP, KEY_LEFT]:
		assert_eq(_matching_gameplay_actions(_key(key, KEY_LOCATION_UNSPECIFIED, true)).size(), 1,
			"%s still matches while Alt is held" % OS.get_keycode_string(key))
	# The fake Left Ctrl that AltGr layouts send must not trigger anything.
	assert_eq(_matching_gameplay_actions(_key(KEY_CTRL, KEY_LOCATION_LEFT)), [], "Ctrl is unbound")


func test_profiles_reference_valid_actions() -> void:
	for i in [1, 2]:
		var profile: KnightProfile = load("res://resources/players/p%d_profile.tres" % i)
		assert_eq(profile.player_id, i, "profile %d id" % i)
		assert_eq(profile.missing_actions().size(), 0, "profile %d actions exist" % i)
		for action in profile.actions():
			assert_true(String(action).begins_with("p%d_" % i), "profile %d uses only its own actions (%s)" % [i, action])
