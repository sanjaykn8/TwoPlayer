class_name AudioManager
extends Node
## Music and the mixer. Exactly one lives in the application (GameApp), so music never
## doubles up across screen changes; short sound effects go through Sfx.
##
## Buses (default_bus_layout.tres): Master -> Music, SFX. Settings change bus volumes only,
## never individual players.
## Music: one player on the Music bus. play_track() with the track already playing does
## nothing (no restart); a different track fades the old one out and the new one in.
## While the game is paused, music keeps playing a few dB quieter and gameplay sounds pause.

signal track_changed(track_id: String)

const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"
const MASTER_BUS := &"Master"
const SILENT_DB := -40.0

@export var config: AudioConfig

## The track playing or fading in ("" = silence).
var current_track := ""
## How many times a track was actually (re)started. Tests use it to prove no restarts.
var start_count := 0
var ducked := false

var _player: AudioStreamPlayer
var _tween: Tween
var _target_db := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if config == null:
		config = Sfx.config()
	for problem in config.validate():
		push_error("AudioConfig: " + problem)
	_player = AudioStreamPlayer.new()
	_player.name = "Music"
	_player.bus = MUSIC_BUS if AudioServer.get_bus_index(MUSIC_BUS) >= 0 else MASTER_BUS
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_player)


# --- Music -----------------------------------------------------------------------------

## Plays the track for a context (menu, game_over, victory).
func play_context(context: String) -> void:
	play_track(config.track_for_context(context))


## Plays the track for the world that contains `level_id` (LevelCatalog).
func play_level(level_id: String) -> void:
	play_track(config.track_for_world(LevelCatalog.world_of(level_id)))


## Switches to `track_id` ("" = fade to silence). The same track never restarts.
func play_track(track_id: String) -> void:
	if track_id == current_track:
		return
	var entry := config.track(track_id)
	if track_id != "" and entry.is_empty():
		push_warning("AudioManager: unknown track '%s'" % track_id)
		track_id = ""
	current_track = track_id
	track_changed.emit(track_id)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var fade := config.music_fade_seconds
	if _player.playing:
		_tween.tween_property(_player, ^"volume_db", SILENT_DB, fade)
	_tween.tween_callback(_start.bind(entry))
	if not entry.is_empty():
		_target_db = float(entry.get("volume_db", 0.0))
		_tween.tween_property(_player, ^"volume_db", _effective_db(), fade)


func stop_music() -> void:
	play_track("")


func is_music_playing() -> bool:
	return _player.playing


func music_player() -> AudioStreamPlayer:
	return _player


## Pause policy: quieter music while the game is paused.
func set_ducked(on: bool) -> void:
	if ducked == on:
		return
	ducked = on
	if current_track != "" and not (_tween != null and _tween.is_running()):
		_player.volume_db = _effective_db()


func _start(entry: Dictionary) -> void:
	_player.stop()
	if entry.is_empty():
		_player.stream = null
		return
	_player.stream = load(str(entry.path)) as AudioStream
	_player.pitch_scale = float(entry.get("pitch", 1.0))
	_player.volume_db = SILENT_DB
	_player.play()
	start_count += 1


func _effective_db() -> float:
	return _target_db + (config.pause_duck_db if ducked else 0.0)


## Application shutdown: stops the music and every sound now, so the audio thread can
## release them before the engine exits (otherwise playing streams are reported as leaked).
func stop_all() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	current_track = ""
	_player.stop()
	_player.stream = null
	for node in get_tree().root.find_children("*", "AudioStreamPlayer", true, false):
		(node as AudioStreamPlayer).stop()


# --- Sound effects -------------------------------------------------------------------------

## A menu sound (keeps playing while the game is paused).
func ui(cue_id: StringName) -> void:
	Sfx.cue(cue_id, self, true)


# --- Mixer -------------------------------------------------------------------------------

## Sets a bus to `percent` (0-100) of full volume. 0 mutes it.
static func set_bus_percent(bus: StringName, percent: int) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		push_error("AudioManager: no audio bus '%s'" % bus)
		return
	var p := clampi(percent, 0, 100)
	AudioServer.set_bus_mute(index, p == 0)
	AudioServer.set_bus_volume_db(index, linear_to_db(p / 100.0) if p > 0 else -80.0)


## The bus volume as a 0-100 percentage (0 when muted).
static func bus_percent(bus: StringName) -> int:
	var index := AudioServer.get_bus_index(bus)
	if index < 0 or AudioServer.is_bus_mute(index):
		return 0
	return roundi(db_to_linear(AudioServer.get_bus_volume_db(index)) * 100.0)
