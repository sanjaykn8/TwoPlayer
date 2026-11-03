class_name Sfx
extends RefCounted
## Fire-and-forget sound effects: the one place gameplay and menus play short sounds.
## - Every effect plays on the "SFX" bus, so the Settings volume applies to all of them.
## - Gameplay effects pause with the game; menu effects (`ui = true`) keep playing.
## - Bursts stay quiet: at most AudioConfig.max_voices gameplay effects (max_ui_voices for
##   menus) play at once, and the same stream starts at most once per frame (six coins
##   collected together sound once, not six times louder).
## Named cues (Sfx.cue) come from resources/config/audio_config.tres.

const COIN := preload("res://assets/sounds/coin.wav")
const POWER_UP := preload("res://assets/sounds/power_up.wav")
const TAP := preload("res://assets/sounds/tap.wav")
const HURT := preload("res://assets/sounds/hurt.wav")
const EXPLOSION := preload("res://assets/sounds/explosion.wav")
const BUS := &"SFX"
const AUDIO_CONFIG := "res://resources/config/audio_config.tres"

static var _playing := 0
static var _ui_playing := 0
## stream instance id -> process frame it last started
static var _started_frame := {}
static var _config: AudioConfig
static var _streams := {}
## For tests and the debug overlay: total effects started, and the last one.
static var started := 0
static var last_cue := &""
static var last_bus := &""


static func config() -> AudioConfig:
	if _config == null:
		_config = load(AUDIO_CONFIG)
	return _config


## Plays a named cue from the audio config. Returns the player, or null when dropped.
static func cue(id: StringName, context: Node, ui := false) -> AudioStreamPlayer:
	var entry: Dictionary = config().cues.get(String(id), {})
	if entry.is_empty():
		push_warning("Sfx: unknown cue '%s'" % id)
		return null
	var stream := stream_for(str(entry.path))
	var jitter := float(entry.get("jitter", 0.0))
	var pitch := float(entry.get("pitch", 1.0)) * (randf_range(1.0 - jitter, 1.0 + jitter) if jitter > 0.0 else 1.0)
	var player := play(stream, context, float(entry.get("volume_db", -8.0)), pitch, ui)
	if player != null:
		last_cue = id
	return player


## Plays `stream` once. Returns the player, or null when the sound was dropped (no tree,
## voice limit, or the same stream already started this frame).
static func play(stream: AudioStream, context: Node, volume_db := -8.0, pitch := 1.0, ui := false) -> AudioStreamPlayer:
	if stream == null or context == null or not context.is_inside_tree():
		return null
	var limit := config().max_ui_voices if ui else config().max_voices
	if (_ui_playing if ui else _playing) >= limit:
		return null
	var frame := Engine.get_process_frames()
	var key := stream.get_instance_id()
	if _started_frame.get(key, -1) == frame:
		return null
	_started_frame[key] = frame
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.bus = BUS if AudioServer.get_bus_index(BUS) >= 0 else &"Master"
	# Menu sounds must work while the game is paused; gameplay sounds pause with it.
	player.process_mode = Node.PROCESS_MODE_ALWAYS if ui else Node.PROCESS_MODE_PAUSABLE
	var tree := context.get_tree()
	tree.root.add_child(player)
	if ui:
		_ui_playing += 1
	else:
		_playing += 1
	started += 1
	last_bus = player.bus
	player.play()
	# Free the player after the sound's length (works even where `finished` never fires,
	# e.g. the headless test audio driver). The timer pauses with gameplay sounds.
	var length := stream.get_length() / maxf(pitch, 0.01) + 0.05
	tree.create_timer(length, ui).timeout.connect(func() -> void:
		if ui:
			_ui_playing = maxi(_ui_playing - 1, 0)
		else:
			_playing = maxi(_playing - 1, 0)
		if is_instance_valid(player):
			player.queue_free())
	return player


## Loads (once) and returns the audio file at `path`.
static func stream_for(path: String) -> AudioStream:
	if not _streams.has(path):
		_streams[path] = load(path)
	return _streams[path]
