extends GameTestCase
## Main menu, screen navigation and keyboard behaviour (real key events through Input), on
## the test folder user://test_saves_ui/.

var app: GameApp


func before_each() -> void:
	UiTestUtil.clean()


func after_each() -> void:
	UiTestUtil.free_app(app)
	await get_tree().process_frame
	UiTestUtil.clean()


func _open() -> void:
	app = UiTestUtil.make_app(self)
	await get_tree().process_frame
	await get_tree().process_frame


func _menu() -> MainMenu:
	return app.stack.top() as MainMenu


func _button(key: String) -> UiButton:
	return _menu().buttons[key]


func test_main_menu_loads() -> void:
	await _open()
	assert_true(_menu() != null, "main menu on top")
	assert_eq(app.mode, GameApp.Mode.MENU, "menu mode")
	for key in ["new_game", "continue", "save_slots", "settings", "controls", "exit"]:
		assert_true(_menu().buttons.has(key), "%s button" % key)
	assert_eq((_menu().get_node("Title") as Label).text, (load(GameApp.UI_CONFIG) as UiConfig).game_title, "configured title")
	assert_eq((load(GameApp.UI_CONFIG) as UiConfig).game_title, "UNTITLED", "placeholder title until one is chosen")
	assert_eq(app.audio.current_track, "menu", "menu music")
	assert_true(app.campaign == null, "no campaign while on the menu")


func test_continue_disabled_without_campaigns() -> void:
	SaveManager.new(UiTestUtil.DIR).start_new_run(2)
	SaveManager.new(UiTestUtil.DIR).invalidate_run_after_death(2, RunState.current().campaign.campaign_id)
	UiTestUtil.damage(3)
	await _open()
	assert_true(_button("continue").disabled, "nothing to continue (lost and damaged slots do not count)")
	assert_eq(_button("continue").focus_mode, Control.FOCUS_NONE, "cannot be focused")
	assert_true(_menu().continue_hint.text.contains("New Game"), "guides to New Game")
	assert_eq(UiTestUtil.focus_owner(get_tree()), _button("new_game"), "focus starts on New Game")


func test_continue_enabled_with_a_campaign() -> void:
	UiTestUtil.write_campaign(3, 7)
	await _open()
	assert_false(_button("continue").disabled, "Continue available")
	assert_eq(UiTestUtil.focus_owner(get_tree()), _button("continue"), "focus starts on Continue")
	_button("continue").pressed.emit()
	var screen := app.stack.top() as SaveSlotScreen
	assert_true(screen != null and screen.mode == SaveSlotScreen.Mode.CONTINUE, "Continue opens the campaign selection")


func test_buttons_open_their_screens() -> void:
	await _open()
	var cases := [["new_game", SaveSlotScreen, SaveSlotScreen.Mode.NEW_GAME], ["save_slots", SaveSlotScreen, SaveSlotScreen.Mode.MANAGE],
		["settings", SettingsScreen, -1], ["controls", ControlsScreen, -1]]
	for c: Array in cases:
		_button(c[0]).pressed.emit()
		await get_tree().process_frame
		var top := app.stack.top()
		assert_true(is_instance_of(top, c[1]), "%s opens its screen" % c[0])
		if c[2] >= 0:
			assert_eq((top as SaveSlotScreen).mode, c[2], "%s mode" % c[0])
		assert_false(_menu_node().visible, "the menu is hidden under %s" % c[0])
		top.close()
		await get_tree().process_frame
		assert_true(app.stack.top() is MainMenu, "back to the menu after %s" % c[0])


func _menu_node() -> MainMenu:
	return app.stack.screens[0] as MainMenu


func test_exit_uses_the_quit_path() -> void:
	await _open()
	_button("exit").pressed.emit()
	assert_true(app.quit_requested, "quit requested through GameApp")
	assert_true(app.campaign == null, "no campaign was created or saved")
	assert_eq(DirAccess.get_files_at(UiTestUtil.DIR).size(), 0, "nothing written")


func test_keyboard_navigation_confirm_and_back() -> void:
	await _open()
	var tree := get_tree()
	assert_eq(UiTestUtil.focus_owner(tree), _button("new_game"), "start on New Game")
	await UiTestUtil.tap(tree, KEY_DOWN)
	assert_eq(UiTestUtil.focus_owner(tree), _button("save_slots"), "Down skips the disabled Continue")
	await UiTestUtil.tap(tree, KEY_DOWN)
	assert_eq(UiTestUtil.focus_owner(tree), _button("settings"), "Down")
	await UiTestUtil.tap(tree, KEY_UP)
	await UiTestUtil.tap(tree, KEY_DOWN)
	assert_eq(UiTestUtil.focus_owner(tree), _button("settings"), "Up then Down")
	await UiTestUtil.tap(tree, KEY_ENTER)
	assert_true(app.stack.top() is SettingsScreen, "Enter opens Settings")
	assert_true((app.stack.top() as Control).is_ancestor_of(UiTestUtil.focus_owner(tree)), "focus moved into Settings")
	await UiTestUtil.tap(tree, KEY_ESCAPE)
	assert_true(app.stack.top() is MainMenu, "Escape goes back")
	assert_eq(UiTestUtil.focus_owner(tree), _button("settings"), "focus restored to the button that opened it")
	# Wrapping: Up from the first button reaches Exit; no focus trap.
	UiButton.focus_quietly(_button("new_game"))
	await UiTestUtil.tap(tree, KEY_UP)
	assert_eq(UiTestUtil.focus_owner(tree), _button("exit"), "Up wraps to Exit")
	await UiTestUtil.tap(tree, KEY_ESCAPE)
	assert_true(app.stack.top() is MainMenu, "Escape on the main menu stays on it")
	assert_false(app.quit_requested, "Escape never quits")


func test_focus_is_clearly_visible() -> void:
	await _open()
	var theme := UiTheme.theme()
	var focus := theme.get_stylebox(&"focus", &"Button") as StyleBoxFlat
	assert_true(focus != null and focus.border_color == UiTheme.GOLD and focus.border_width_left >= 1, "gold focus frame")
	assert_true(theme.get_color(&"font_focus_color", &"Button") != theme.get_color(&"font_color", &"Button"), "focused text colour differs")
	var b := _button("new_game")
	assert_true(b.has_focus(), "focused")
	assert_false(_button("settings").has_focus(), "only one focused button")
	assert_true(UiTheme.FONT.antialiasing == TextServer.FONT_ANTIALIASING_NONE, "pixel font without anti-aliasing")


func test_modal_dialog_blocks_the_screen_behind() -> void:
	UiTestUtil.write_campaign(1, 4)
	await _open()
	var tree := get_tree()
	var slots := app.open_slot_screen(SaveSlotScreen.Mode.MANAGE)
	await tree.process_frame
	slots.delete_slot(1)
	await tree.process_frame
	var dialog := app.stack.top() as ConfirmDialog
	assert_true(dialog != null, "confirmation open")
	assert_true(slots.visible, "the slot screen stays visible behind the dialog")
	assert_eq(slots.focus_behavior_recursive, Control.FOCUS_BEHAVIOR_DISABLED, "nothing behind can take focus")
	assert_eq(slots.mouse_behavior_recursive, Control.MOUSE_BEHAVIOR_DISABLED, "nothing behind can be clicked")
	assert_eq(UiTestUtil.focus_owner(tree), dialog.cancel_button, "destructive question starts on Cancel")
	for key: Key in [KEY_UP, KEY_DOWN, KEY_TAB, KEY_LEFT]:
		await UiTestUtil.tap(tree, key)
		assert_true(dialog.is_ancestor_of(UiTestUtil.focus_owner(tree)), "focus stays in the dialog after %s" % OS.get_keycode_string(key))
	await UiTestUtil.tap(tree, KEY_ESCAPE)
	assert_true(app.stack.top() == slots, "Escape closes only the dialog")
	assert_true(app.saves.has_valid_save(1), "cancel deleted nothing")
	assert_eq(slots.focus_behavior_recursive, Control.FOCUS_BEHAVIOR_INHERITED, "the slot screen is interactive again")


func test_menu_has_no_gameplay_and_ignores_gameplay_keys() -> void:
	await _open()
	var tree := get_tree()
	for key: Key in [KEY_V, KEY_W, KEY_A, KEY_D, KEY_ALT]:
		await UiTestUtil.tap(tree, key)
	assert_true(app.stack.top() is MainMenu, "gameplay keys change no screen")
	assert_eq(get_tree().get_nodes_in_group(&"knights").size(), 0, "no knights exist on the menu")
	assert_true(app.campaign == null, "no campaign started")
