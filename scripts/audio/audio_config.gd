class_name AudioConfig
extends Resource
## Every music and sound-effect choice (resources/config/audio_config.tres). Only files that
## exist in assets/ are referenced; validate() checks them. The bundle has one music track and
## six short effects, so several entries reuse a file with a different pitch or volume
## (documented in docs/ASSET_CATALOG.md and docs/KNOWN_ISSUES.md).

## track id -> {"path": String, "volume_db": float, "pitch": float}
@export var music_tracks: Dictionary = {}
## Game context -> track id ("" = silence). Contexts: menu, game_over, victory.
@export var context_tracks: Dictionary = {}
## World id (LevelCatalog) -> track id. Worlds without an entry use default_world_track.
@export var world_tracks: Dictionary = {}
@export var default_world_track := ""
## cue id -> {"path": String, "volume_db": float, "pitch": float, "jitter": float}
@export var cues: Dictionary = {}

@export_group("Behaviour")
## Seconds for a music fade out / fade in.
@export_range(0.0, 3.0) var music_fade_seconds := 0.4
## Music volume change while the game is paused (the gameplay sounds pause).
@export_range(-40.0, 0.0) var pause_duck_db := -8.0
## Gameplay sound effects playing at once; extra requests are dropped.
@export_range(1, 32) var max_voices := 6
## Menu sound effects playing at once (separate pool, so paused gameplay sounds never block menus).
@export_range(1, 8) var max_ui_voices := 3


func track(id: String) -> Dictionary:
	return music_tracks.get(id, {})


func track_for_world(world_id: String) -> String:
	return str(world_tracks.get(world_id, default_world_track))


func track_for_context(context: String) -> String:
	return str(context_tracks.get(context, ""))


## Returns a list of problems ("" entries never appear). Empty means valid.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	for id: String in music_tracks:
		_check_entry("music '%s'" % id, music_tracks[id], problems)
	for id: String in cues:
		_check_entry("cue '%s'" % id, cues[id], problems)
	for context: String in context_tracks:
		var t := str(context_tracks[context])
		if t != "" and not music_tracks.has(t):
			problems.append("context '%s' names unknown track '%s'" % [context, t])
	for world: String in world_tracks:
		if not music_tracks.has(str(world_tracks[world])):
			problems.append("world '%s' names unknown track '%s'" % [world, world_tracks[world]])
	if default_world_track != "" and not music_tracks.has(default_world_track):
		problems.append("default world track '%s' is unknown" % default_world_track)
	return problems


static func _check_entry(label: String, entry: Variant, problems: PackedStringArray) -> void:
	if typeof(entry) != TYPE_DICTIONARY or not entry.has("path"):
		problems.append("%s: missing path" % label)
		return
	var path := str(entry.path)
	if not ResourceLoader.exists(path):
		problems.append("%s: file not found %s" % [label, path])
	elif not load(path) is AudioStream:
		problems.append("%s: not an audio stream %s" % [label, path])
