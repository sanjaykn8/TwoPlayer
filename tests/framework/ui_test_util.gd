class_name UiTestUtil
extends RefCounted
## Helpers for Phase 9 UI tests. Every app made here uses user://test_saves_ui/ and
## user://test_settings_ui.cfg, never the player's user://saves/ or user://settings.cfg, and
## records quit requests instead of ending the test run.

const DIR := "user://test_saves_ui/"
const SETTINGS := "user://test_settings_ui.cfg"
const APP := "res://scenes/app/game_app.tscn"


static func clean() -> void:
	SaveTestUtil.clean(DIR)
	for path in [SETTINGS, SETTINGS + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


## A GameApp on the test folder, added to `parent` and showing the main menu.
static func make_app(parent: Node, show_menu := true) -> GameApp:
	var app := (load(APP) as PackedScene).instantiate() as GameApp
	app.save_dir = DIR
	app.settings_path = SETTINGS
	app.touch_window = false
	app.show_menu_on_start = show_menu
	app.wipe_delay = 0.1
	app.quit_handler = func() -> void: pass
	parent.add_child(app)
	return app


## Removes an app and leaves the tree unpaused.
static func free_app(app: GameApp) -> void:
	if is_instance_valid(app):
		app.get_tree().paused = false
		app.get_parent().remove_child(app)
		app.queue_free()


## Writes a campaign into `slot` of the test folder (coins, a level) through SaveManager.
static func write_campaign(slot: int, coins := 0, level_id := "w1_l1") -> String:
	var manager := SaveManager.new(DIR)
	manager.start_new_run(slot, true)
	var run := RunState.current()
	run.coins = coins
	if level_id != LevelCatalog.FIRST_LEVEL:
		run.campaign.complete_level(LevelCatalog.FIRST_LEVEL)
		run.campaign.enter_level(level_id)
	manager.save_active_run({}, run.campaign.campaign_id)
	var id := run.campaign.campaign_id
	RunState.reset()
	return id


static func damage(slot: int, kind := SlotStore.Kind.SAVE) -> void:
	SaveTestUtil.write(DIR, SlotStore.new(DIR).path(slot, kind).get_file(), "TKCSAVE 1 0\n{ broken")


## Every file of the test folder with its exact text (to prove other slots stay identical).
static func snapshot_files() -> Dictionary:
	var files := {}
	for file in DirAccess.get_files_at(DIR):
		files[file] = SaveTestUtil.read(DIR, file)
	return files


## Presses and releases a real key, as the keyboard would.
static func tap(tree: SceneTree, keycode: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = keycode
		e.physical_keycode = keycode
		e.pressed = pressed
		Input.parse_input_event(e)
		await tree.process_frame
	await tree.process_frame


static func focus_owner(tree: SceneTree) -> Control:
	return tree.root.gui_get_focus_owner()
