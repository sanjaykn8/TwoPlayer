class_name CampaignGame
extends Node
## Plays one campaign in one save slot: builds the current level from the run, restores the
## saved world, moves between levels, autosaves at milestones, saves when the window is
## closed, and runs the team wipe. It is the only place gameplay talks to the SaveManager.
##
## Phases:
##   RESTORING      building a level (synchronous; processing disabled, nothing can happen)
##   PLAYING        normal play
##   TRANSITIONING  a level exit was taken; the next level loads on the next idle frame
##   WIPING         a knight died: the run is being invalidated and replaced (locked)
##   WIPE_FAILED    the old campaign could not be invalidated on disk: frozen (fail-closed)
##   EXITING        saving before the window closes
## Save requests are centralised: request_autosave() coalesces requests to one deferred save
## per frame, carrying the campaign id as a token; a request whose campaign is no longer the
## current run, or that arrives outside PLAYING, is dropped. Saves never run every frame.

signal level_started(level_id: String)
signal autosaved(reason: String, ok: bool)
signal team_wipe_started
signal team_wipe_finished(saved: bool)
## A message for the player/developer (save failures, recoveries, wipes).
signal notice(text: String)

enum Phase { IDLE, RESTORING, PLAYING, TRANSITIONING, WIPING, WIPE_FAILED, EXITING }
enum StartMode { NEW, LOAD, CONTINUE }

## Seconds the team wipe holds the frozen scene before the new run starts.
const DEFAULT_WIPE_DELAY := 1.2

@export var save_dir := SavePaths.SAVE_DIR
@export_range(1, 4) var slot := 1
@export var start_mode := StartMode.CONTINUE
## NEW mode: replace an existing campaign in the slot (the Phase 9 menu confirms this).
@export var overwrite := false
@export var wipe_delay := DEFAULT_WIPE_DELAY
## false: begin() must be called by the owner (tests).
@export var auto_begin := true

var saves: SaveManager
var phase := Phase.IDLE
var level: Node2D
var knights: Array[Knight] = []
var wipes := 0
var last_save_reason := ""
var last_save_ok := false
## A fresh run after a team wipe that could not be written yet (retried by the next autosave).
var fresh_run_unsaved := false
var last_notice := ""
var restore_problems := PackedStringArray()

var _pending_reason := ""
var _pending_token := ""
var _transition_target := ""
var _exit_save_failed := false

@onready var rig: SplitScreenRig = $SplitScreenRig


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rig.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().set_auto_accept_quit(false)
	saves = SaveManager.new(save_dir)
	saves.recovered.connect(func(s: int, why: String) -> void: _notice("Slot %d: %s" % [s, why]))
	if auto_begin:
		begin.call_deferred()


func _exit_tree() -> void:
	get_tree().set_auto_accept_quit(true)


## Starts the campaign according to `start_mode`. Returns OK or the failure.
func begin() -> Error:
	var world := {}
	match start_mode:
		StartMode.NEW:
			var err := saves.start_new_run(slot, overwrite)
			if err != OK:
				_notice("Cannot start a new campaign in slot %d: %s" % [slot, saves.last_error])
				return err
		StartMode.LOAD, StartMode.CONTINUE:
			var result := saves.load_run(slot)
			if result.ok:
				world = result.world
				for warning: String in result.warnings:
					_notice("Slot %d: %s" % [slot, warning])
			elif start_mode == StartMode.CONTINUE and saves.slot_status(slot) == SaveManager.Status.EMPTY:
				var err := saves.start_new_run(slot)
				if err != OK:
					_notice("Cannot start a campaign in slot %d: %s" % [slot, saves.last_error])
					return err
			else:
				_notice("Slot %d cannot be loaded (%s). Start a new campaign explicitly." % [slot, result.status])
				return ERR_FILE_CORRUPT
	var problem := _load_level(RunState.current().campaign.level_id, world)
	return OK if problem == "" else ERR_CANT_CREATE


func run() -> RunState:
	return RunState.current()


func phase_name() -> String:
	return Phase.keys()[phase]


# --- Level building ------------------------------------------------------------------------

## Replaces the current level with `level_id`, restoring `world` (empty = a fresh start).
## Everything happens in this call with processing disabled, so nothing can interact with a
## half-restored level. Returns "" or the failure.
func _load_level(level_id: String, world: Dictionary) -> String:
	if not LevelCatalog.is_known_level(level_id):
		return _abort_load("unknown level id '%s'" % level_id)
	phase = Phase.RESTORING
	if level != null:
		_disconnect_level()
		level.get_parent().remove_child(level)
		level.queue_free()
		level = null
	knights.clear()
	var scene := load(LevelCatalog.scene_for(level_id)) as PackedScene
	if scene == null:
		return _abort_load("level scene for '%s' failed to load" % level_id)
	var instance := scene.instantiate() as Node2D
	instance.set_meta(&"level_id", level_id)
	instance.process_mode = Node.PROCESS_MODE_DISABLED
	WorldSnapshot.before_tree(instance, world)
	rig.attach_world(instance)
	level = instance
	restore_problems = WorldSnapshot.after_ready(instance, world)
	for problem in restore_problems:
		_notice("Restore: " + problem)
	for node in instance.find_children("*", "", true, false):
		if node is Knight:
			knights.append(node)
	knights.sort_custom(func(a: Knight, b: Knight) -> bool: return a.player_id() < b.player_id())
	_connect_level()
	instance.process_mode = Node.PROCESS_MODE_INHERIT
	rig.refresh_world()
	phase = Phase.PLAYING
	level_started.emit(level_id)
	return ""


func _abort_load(reason: String) -> String:
	phase = Phase.IDLE
	_notice("Level load failed: " + reason)
	return reason


func _connect_level() -> void:
	for knight in knights:
		knight.died.connect(_on_knight_died)
	for node in get_tree().get_nodes_in_group(SavePoint.GROUP):
		if level.is_ancestor_of(node):
			(node as SavePoint).reached.connect(_on_save_point)
	for node in get_tree().get_nodes_in_group(LevelExit.GROUP):
		if level.is_ancestor_of(node):
			(node as LevelExit).activated.connect(_on_exit_activated)
	for node in level.find_children("*", "", true, false):
		if node is PuzzleLogic and (node as PuzzleLogic).latch:
			(node as PuzzleLogic).completed.connect(request_autosave.bind("puzzle:" + node.puzzle_id))


func _disconnect_level() -> void:
	for knight in knights:
		if is_instance_valid(knight) and knight.died.is_connected(_on_knight_died):
			knight.died.disconnect(_on_knight_died)


# --- Autosave ------------------------------------------------------------------------------

## Asks for a save at the end of this frame (coalesced; ignored outside PLAYING).
func request_autosave(reason: String) -> void:
	if phase != Phase.PLAYING:
		return
	var first := _pending_reason == ""
	_pending_reason = reason
	_pending_token = run().campaign.campaign_id
	if first:
		_flush_autosave.call_deferred()


func _flush_autosave() -> void:
	var reason := _pending_reason
	var token := _pending_token
	_pending_reason = ""
	_pending_token = ""
	if reason == "" or phase != Phase.PLAYING or token != run().campaign.campaign_id:
		return  # superseded: a wipe or transition happened, or the request is stale
	save_now(reason, token)


## Saves the current run and level immediately. Returns OK or the failure (never claims success).
func save_now(reason: String, token := "") -> Error:
	if level == null or not is_instance_valid(level):
		return ERR_UNCONFIGURED
	var err := saves.save_active_run(WorldSnapshot.capture(level, knights), token if token != "" else run().campaign.campaign_id)
	last_save_reason = reason
	last_save_ok = err == OK
	if err == OK:
		if fresh_run_unsaved:
			fresh_run_unsaved = false
			saves.clear_invalidation(saves.active_slot)
	else:
		_notice("SAVE FAILED (%s): %s" % [reason, saves.last_error])
	autosaved.emit(reason, err == OK)
	return err


func _on_save_point(point: SavePoint) -> void:
	request_autosave("save_point:" + point.save_id)


# --- Level completion and transitions -------------------------------------------------------

func _on_exit_activated(_knight: Knight) -> void:
	complete_level()


## The current level is done: both surviving knights move to the next level (or the campaign
## ends). The new level is saved once it has been built, so a save never mixes two levels.
func complete_level() -> void:
	if phase != Phase.PLAYING:
		return
	var campaign := run().campaign
	campaign.complete_level(campaign.level_id)
	var next := LevelCatalog.next_level(campaign.level_id)
	if next == "":
		campaign.flags["finished"] = true
		_notice("Campaign complete!")
		request_autosave("campaign_complete")
		return
	phase = Phase.TRANSITIONING
	_transition_target = next
	_do_transition.call_deferred()


func _do_transition() -> void:
	if phase != Phase.TRANSITIONING:
		return  # a team wipe (or exit) took over
	var next := _transition_target
	_transition_target = ""
	run().campaign.enter_level(next)
	if _load_level(next, {}) == "":
		save_now("level_start:" + next)


# --- Team wipe -------------------------------------------------------------------------------

func _on_knight_died() -> void:
	if phase == Phase.WIPING or phase == Phase.WIPE_FAILED or phase == Phase.IDLE:
		return  # already handling a death (both knights in one frame, lava + damage, ...)
	start_team_wipe()


## Either knight died: the whole run is lost for both. Runs exactly once per run.
func start_team_wipe() -> void:
	phase = Phase.WIPING
	wipes += 1
	_pending_reason = ""
	_transition_target = ""
	# Logical lock now (no saves, transitions or second wipe); the physics freeze is deferred
	# to the end of the frame because a death can arrive inside a physics callback (falls,
	# lava), where collision objects must not be disabled.
	for knight in knights:
		if is_instance_valid(knight):
			knight.combat.cancel()
	_freeze_level.call_deferred()
	team_wipe_started.emit()
	_notice("A knight has fallen. The run is lost for both.")
	var dead_id := run().campaign.campaign_id
	var err := saves.invalidate_run_after_death(saves.active_slot, dead_id)
	if err != OK:
		phase = Phase.WIPE_FAILED
		_notice("STORAGE FAILURE: the lost campaign could not be invalidated (%s). The game is halted." % saves.last_error)
		return
	await get_tree().create_timer(maxf(wipe_delay, 0.0), true, false, true).timeout
	if phase != Phase.WIPING:
		return  # the window was closed meanwhile
	_finish_team_wipe()


func _finish_team_wipe() -> void:
	RunState.reset()  # clears coins, collected items, upgrades, effects, puzzles, enemies, campaign
	if _load_level(LevelCatalog.FIRST_LEVEL, {}) != "":
		phase = Phase.WIPE_FAILED
		return
	var err := saves.save_active_run(WorldSnapshot.capture(level, knights), run().campaign.campaign_id, true)
	saves.wipe_lock = false
	if err == OK:
		saves.clear_invalidation(saves.active_slot)
		fresh_run_unsaved = false
		_notice("A new run begins.")
	else:
		fresh_run_unsaved = true
		_notice("A new run begins, but it could not be saved yet (%s). The old run stays invalidated." % saves.last_error)
	last_save_reason = "team_wipe_new_run"
	last_save_ok = err == OK
	team_wipe_finished.emit(err == OK)


func _freeze_level() -> void:
	if level != null and (phase == Phase.WIPING or phase == Phase.WIPE_FAILED):
		level.process_mode = Node.PROCESS_MODE_DISABLED


# --- Application exit ------------------------------------------------------------------------

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		handle_close_request()


## The window is being closed. Quitting is never dying: an ordinary campaign is saved first
## and the process exits only after the save has been verified. During a team wipe nothing
## is saved (the old campaign is already invalidated). If the save fails, the game stays open
## and reports it; closing again quits without saving.
func handle_close_request() -> void:
	match phase:
		Phase.EXITING:
			return
		Phase.PLAYING, Phase.TRANSITIONING:
			if _exit_save_failed:
				get_tree().quit(1)
				return
			# No new transitions, autosaves or wipes from here on. A pending transition is
			# dropped: the valid pre-transition level is what gets saved.
			phase = Phase.EXITING
			_transition_target = ""
			_pending_reason = ""
			if level != null:
				level.process_mode = Node.PROCESS_MODE_DISABLED
			var err := save_now("exit")
			if err == OK:
				get_tree().quit(0)
			else:
				_exit_save_failed = true
				phase = Phase.PLAYING
				if level != null:
					level.process_mode = Node.PROCESS_MODE_INHERIT
				_notice("Could not save before closing (%s). Close again to quit without saving." % saves.last_error)
		_:
			phase = Phase.EXITING
			get_tree().quit(0)


# --- Play time ---------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if phase == Phase.PLAYING and not get_tree().paused:
		run().campaign.playtime += delta


func _notice(text: String) -> void:
	last_notice = text
	if text.begins_with("SAVE FAILED") or text.begins_with("STORAGE FAILURE") or text.begins_with("Could not save"):
		printerr("[CampaignGame] " + text)
	notice.emit(text)
