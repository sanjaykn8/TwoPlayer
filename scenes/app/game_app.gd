class_name GameApp
extends Node
## The application root (main scene). It owns the things that live for the whole session:
## one SaveManager (shared with the campaign), the SettingsManager, the single AudioManager,
## and the UiStack of menu screens. It moves between the main menu and a CampaignGame and
## is the only place that pauses the game.
##
## Modes:
##   MENU       title screen and its sub-screens; no campaign exists
##   PLAYING    a CampaignGame runs (HUD visible, Esc pauses)
##   PAUSED     the game tree is paused under the pause menu (and its sub-screens)
##   GAME_OVER  a team wipe is shown; the fresh run waits (paused) for Begin Again
##   VICTORY    the campaign was completed; paused under the victory screen
##   LEAVING    a verified save has been made and the application is quitting
##
## Rules kept here: leaving a campaign (Main Menu, Save and Quit) happens only after a
## verified save; a voluntary restart is never a death; the game-over choices appear only
## after CampaignGame has invalidated the lost run and created the fresh one; menus never
## parse save files (SaveManager does).

signal mode_changed(mode: Mode)

enum Mode { MENU, PLAYING, PAUSED, GAME_OVER, VICTORY, LEAVING }

const CAMPAIGN_SCENE := preload("res://scenes/campaign/campaign_game.tscn")
const MAIN_MENU := preload("res://scenes/ui/menus/main_menu.tscn")
const SETTINGS_SCREEN := preload("res://scenes/ui/menus/settings_screen.tscn")
const CONTROLS_SCREEN := preload("res://scenes/ui/menus/controls_screen.tscn")
const PAUSE_MENU := preload("res://scenes/ui/menus/pause_menu.tscn")
const GAME_OVER_SCREEN := preload("res://scenes/ui/menus/game_over_screen.tscn")
const VICTORY_SCREEN := preload("res://scenes/ui/menus/victory_screen.tscn")
const UI_CONFIG := "res://resources/config/ui_config.tres"

## Where campaigns are saved. Tests and development rooms use their own folders.
@export var save_dir := SavePaths.SAVE_DIR
## Where preferences are stored. Tests and development rooms use their own file.
@export var settings_path := SettingsManager.PATH
@export var show_menu_on_start := true
@export var wipe_delay := CampaignGame.DEFAULT_WIPE_DELAY
## false: settings never resize or switch the real window (tests).
@export var touch_window := true

var mode := Mode.MENU
var saves: SaveManager
var settings: SettingsManager
var ui_config: UiConfig
var audio: AudioManager
var stack: UiStack
var world: Node
var campaign: CampaignGame
## Replaces the real shutdown (tests record the request instead of ending the run).
var quit_handler := Callable()
var quit_requested := false

var _fade: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ui_config = load(UI_CONFIG)
	settings = SettingsManager.new(settings_path)
	settings.touch_window = touch_window
	settings.load_settings()
	for warning in settings.warnings:
		push_warning("Settings: " + warning)
	saves = SaveManager.new(save_dir)

	audio = AudioManager.new()
	audio.name = "AudioManager"
	add_child(audio)
	world = Node.new()
	world.name = "World"
	add_child(world)
	var ui_layer := CanvasLayer.new()
	ui_layer.name = "UiLayer"
	ui_layer.layer = 20
	add_child(ui_layer)
	stack = UiStack.new()
	stack.name = "Stack"
	ui_layer.add_child(stack)
	var fade_layer := CanvasLayer.new()
	fade_layer.name = "FadeLayer"
	fade_layer.layer = 30
	add_child(fade_layer)
	_fade = ColorRect.new()
	_fade.color = Color(UiTheme.BG, 0.0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(_fade)

	# Closing the window is handled here (menus) or by CampaignGame (saves first), so audio
	# can be stopped before the engine exits.
	get_tree().set_auto_accept_quit(false)
	settings.apply_all()
	if touch_window:
		get_window().title = ui_config.game_title
	if show_menu_on_start:
		show_main_menu()


func _exit_tree() -> void:
	get_tree().set_auto_accept_quit(true)


func _set_mode(next: Mode) -> void:
	if mode != next:
		mode = next
		mode_changed.emit(next)


# --- Menus ---------------------------------------------------------------------------------

func show_main_menu() -> void:
	_set_mode(Mode.MENU)
	stack.clear()
	stack.push(MAIN_MENU.instantiate(), self)
	audio.play_context("menu")


func open_slot_screen(screen_mode: SaveSlotScreen.Mode, replacing: MenuScreen = null) -> SaveSlotScreen:
	if replacing != null:
		stack.pop(replacing)
	return stack.push(SaveSlotScreen.create(screen_mode), self) as SaveSlotScreen


func open_settings() -> SettingsScreen:
	return stack.push(SETTINGS_SCREEN.instantiate(), self) as SettingsScreen


func open_controls() -> ControlsScreen:
	return stack.push(CONTROLS_SCREEN.instantiate(), self) as ControlsScreen


## A message box (single OK).
func show_message(title: String, text: String) -> ConfirmDialog:
	return stack.push(ConfirmDialog.create(title, text, "OK", ""), self) as ConfirmDialog


# --- Slot information and management (always through SaveManager) -------------------------

func slot_metadata(slot: int) -> Dictionary:
	return saves.get_slot_metadata(slot)


func any_loadable_slot() -> bool:
	for slot in range(1, 5):
		if saves.has_valid_save(slot):
			return true
	return false


func delete_slot(slot: int) -> Error:
	return saves.delete_slot(slot)


func repair_slot(slot: int) -> Error:
	return saves.recover_backup(slot)


# --- Starting and leaving a campaign -------------------------------------------------------

## Starts a new campaign in `slot` (SaveManager.start_new_run). `overwrite` must only be true
## after the player confirmed replacing an existing campaign.
func start_new_campaign(slot: int, overwrite := false) -> Error:
	return _start(slot, CampaignGame.StartMode.NEW, overwrite)


## Resumes the campaign saved in `slot` (a recovered backup is repaired and reported).
func continue_campaign(slot: int) -> Error:
	return _start(slot, CampaignGame.StartMode.LOAD, false)


func _start(slot: int, start_mode: CampaignGame.StartMode, overwrite: bool) -> Error:
	if campaign != null:
		return ERR_BUSY
	var game := CAMPAIGN_SCENE.instantiate() as CampaignGame
	game.saves = saves
	game.save_dir = save_dir
	game.slot = slot
	game.start_mode = start_mode
	game.overwrite = overwrite
	game.auto_begin = false
	game.wipe_delay = wipe_delay
	world.add_child(game)
	var err := game.begin()
	if err != OK:
		var why := game.last_notice
		world.remove_child(game)
		game.queue_free()
		get_tree().set_auto_accept_quit(false)
		Sfx.cue(&"ui_error", self, true)
		show_message("Slot %d" % slot, why if why != "" else "The campaign could not be started.")
		return err
	campaign = game
	game.quit_handler = func(code: int) -> void:
		quit_requested = true
		if quit_handler.is_valid():
			quit_handler.call()
		else:
			shutdown(code)
	game.team_wipe_started.connect(_on_team_wipe_started)
	game.team_wipe_finished.connect(_on_team_wipe_finished)
	game.team_wipe_failed.connect(_on_team_wipe_failed)
	game.campaign_completed.connect(_on_campaign_completed)
	game.level_started.connect(_on_level_started)
	stack.clear()
	get_tree().paused = false
	audio.set_ducked(false)
	_set_mode(Mode.PLAYING)
	audio.play_level(RunState.current().campaign.level_id)
	_fade_in()
	return OK


## Saves the campaign, then shows the main menu. Never a death and never a silent loss: if
## the save fails, the game stays where it is (paused) and says why.
func return_to_menu() -> Error:
	if campaign != null:
		var err := _save_before_leaving("main_menu")
		if err != OK:
			return err
		_close_campaign()
	show_main_menu()
	_fade_in()
	return OK


## Saves, then quits the application only after the save was verified.
func save_and_quit() -> Error:
	if campaign == null:
		quit_game()
		return OK
	var err := _save_before_leaving("save_and_quit")
	if err != OK:
		return err
	quit_game()
	return OK


## Main menu "Exit". With a campaign running, the Phase 8 close-request path saves first.
func request_exit() -> void:
	if campaign != null:
		campaign.handle_close_request()
	else:
		quit_game()


func quit_game() -> void:
	quit_requested = true
	if quit_handler.is_valid():
		quit_handler.call()
	else:
		shutdown(0)


## Stops all audio, gives the audio thread a moment to release it, then exits.
func shutdown(code: int) -> void:
	_set_mode(Mode.LEAVING)
	audio.stop_all()
	await get_tree().create_timer(0.15, true, false, true).timeout
	get_tree().quit(code)


func _notification(what: int) -> void:
	# With a campaign running, CampaignGame handles the close request (save first).
	if what == NOTIFICATION_WM_CLOSE_REQUEST and campaign == null and mode != Mode.LEAVING:
		quit_game()


func _save_before_leaving(reason: String) -> Error:
	match campaign.phase:
		CampaignGame.Phase.PLAYING:
			pass
		CampaignGame.Phase.WIPE_FAILED:
			return ERR_UNAVAILABLE  # the lost run is still on disk: never leave to the menu
		_:
			return ERR_BUSY  # restoring, transitioning or wiping: try again in a moment
	var err := campaign.save_before_leaving(reason)
	if err != OK:
		Sfx.cue(&"ui_error", self, true)
		var text := "Could not save (%s). Nothing was lost; the game is still running." % saves.last_error
		var pause := stack.find_screen(PauseMenu) as PauseMenu
		if pause != null:
			pause.show_error(text)
		else:
			show_message("Save failed", text)
	return err


func _close_campaign() -> void:
	world.remove_child(campaign)
	campaign.queue_free()
	campaign = null
	get_tree().set_auto_accept_quit(false)  # CampaignGame restores the default when it leaves
	stack.clear()
	get_tree().paused = false
	audio.set_ducked(false)


# --- Pause -----------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") and stack.is_empty() and mode == Mode.PLAYING:
		get_viewport().set_input_as_handled()
		pause_game()


## Freezes the whole gameplay tree (knights, slimes, physics, platforms, puzzle timers, timed
## effects, play time) and shows the pause menu. Only during ordinary play.
func pause_game() -> bool:
	if mode != Mode.PLAYING or campaign == null or campaign.phase != CampaignGame.Phase.PLAYING:
		return false
	_set_mode(Mode.PAUSED)
	get_tree().paused = true
	audio.set_ducked(true)
	Sfx.cue(&"ui_confirm", self, true)
	stack.push(PAUSE_MENU.instantiate(), self)
	return true


func resume_game() -> void:
	if mode != Mode.PAUSED:
		return
	stack.clear()
	get_tree().paused = false
	audio.set_ducked(false)
	_set_mode(Mode.PLAYING)


## Pause menu, after confirmation: a new campaign replaces this one in the same slot.
func restart_campaign() -> Error:
	if campaign == null:
		return ERR_UNCONFIGURED
	var err := campaign.restart_run()
	if err != OK:
		var pause := stack.find_screen(PauseMenu) as PauseMenu
		if pause != null:
			pause.show_error("Could not restart (%s). The campaign was not changed." % saves.last_error)
		return err
	resume_game()
	audio.play_level(RunState.current().campaign.level_id)
	_fade_in()
	return OK


# --- Team wipe and victory -------------------------------------------------------------------

func _on_team_wipe_started() -> void:
	stack.clear()
	get_tree().paused = false
	audio.set_ducked(false)
	_set_mode(Mode.GAME_OVER)
	stack.push(GAME_OVER_SCREEN.instantiate(), self)
	audio.play_context("game_over")
	Sfx.cue(&"game_over", self, true)


## The lost run is invalidated and the fresh run exists: hold it (paused) until a choice.
func _on_team_wipe_finished(saved: bool) -> void:
	get_tree().paused = true
	var screen := stack.find_screen(GameOverScreen) as GameOverScreen
	if screen == null:
		screen = stack.push(GAME_OVER_SCREEN.instantiate(), self) as GameOverScreen
	screen.show_ready(campaign.slot, saved)


func _on_team_wipe_failed(reason: String) -> void:
	_set_mode(Mode.GAME_OVER)
	var screen := stack.find_screen(GameOverScreen) as GameOverScreen
	if screen == null:
		screen = stack.push(GAME_OVER_SCREEN.instantiate(), self) as GameOverScreen
	screen.show_failed(reason)


## Game over: play the fresh run.
func begin_again() -> void:
	if mode != Mode.GAME_OVER or campaign == null or campaign.phase != CampaignGame.Phase.PLAYING:
		return
	stack.clear()
	get_tree().paused = false
	_set_mode(Mode.PLAYING)
	audio.play_level(RunState.current().campaign.level_id)
	_fade_in()


func _on_campaign_completed() -> void:
	show_victory(false)


## The victory screen. `preview` (development only) shows the current run without a finish.
func show_victory(preview: bool) -> VictoryScreen:
	_set_mode(Mode.VICTORY)
	stack.clear()
	get_tree().paused = true
	var screen := VICTORY_SCREEN.instantiate() as VictoryScreen
	screen.preview = preview
	stack.push(screen, self)
	audio.play_context("victory")
	return screen


func _on_level_started(level_id: String) -> void:
	if mode == Mode.PLAYING:
		audio.play_level(level_id)


func _fade_in() -> void:
	if ui_config.fade_seconds <= 0.0:
		return
	_fade.color.a = 1.0
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_fade, ^"color:a", 0.0, ui_config.fade_seconds)
