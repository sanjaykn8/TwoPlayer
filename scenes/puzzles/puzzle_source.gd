@tool
class_name PuzzleSource
extends Node2D
## Base of every puzzle element that has an on/off state other elements can listen to:
## pressure plates, trigger zones, attack switches and targets, logic locks and gates.
##
## Contract (all communication is through these signals and methods):
##   changed(active)     the on/off state changed
##   pulsed(player_id)   a fresh activation happened (a plate pressed, a switch struck);
##                       SYNC and SEQUENCE locks listen to this
##   credit_changed      active_players() changed while the state did not (a second knight
##                       stepped onto a pressed plate); ALL/ANY locks re-check "different knights"
##   is_active()         current state
##   active_players()    ids of the knights currently credited with the activation
##   reset_source()      return to the safe initial state (locks call it after a failure)
##
## Identity and persistence: `puzzle_id` must be unique within its scope. Scope LEVEL stores
## saved state under the level's id (the nearest ancestor's "level_id" metadata, else its
## scene path); CAMPAIGN under PuzzleRegistry.CAMPAIGN. Only states a subclass returns from
## _save_state() are kept (completed locks, latched gates, toggles); temporary states never.

signal changed(active: bool)
signal pulsed(player_id: int)
signal credit_changed

enum Scope { LEVEL, CAMPAIGN }

const CONFIG := preload("res://resources/config/puzzle_config.tres")

## Development-only: draw ids and states over every puzzle element.
static var debug_visible := false

@export var puzzle_id := ""
@export var scope := Scope.LEVEL
## false: never written to the run's puzzle registry.
@export var persistent := true

var _active := false
var _scope_key := ""
var _registry: PuzzleRegistry


## The level id puzzle states of `node` are stored under.
static func level_id_for(node: Node) -> String:
	var at := node.get_parent()
	while at != null:
		if at.has_meta(&"level_id"):
			return str(at.get_meta(&"level_id"))
		if at.scene_file_path != "":
			return at.scene_file_path
		at = at.get_parent()
	return ""


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	_scope_key = PuzzleRegistry.CAMPAIGN if scope == Scope.CAMPAIGN else level_id_for(self)
	_registry = RunState.current().puzzles
	_registry.register(_scope_key, puzzle_id, self)
	if not _registry.restored.is_connected(restore_saved_state):
		_registry.restored.connect(restore_saved_state)


func _exit_tree() -> void:
	if Engine.is_editor_hint() or _registry == null:
		return
	_registry.unregister(_scope_key, puzzle_id, self)
	if _registry.restored.is_connected(restore_saved_state):
		_registry.restored.disconnect(restore_saved_state)


func is_active() -> bool:
	return _active


func active_players() -> Array[int]:
	return []


func reset_source() -> void:
	pass


func scope_key() -> String:
	return _scope_key


## One-line description for overlays and debug drawing.
func debug_state() -> String:
	return "on" if _active else "off"


## Writes this element's persistent state (if any) to the run's registry.
func save_state() -> void:
	if persistent and puzzle_id != "" and _registry != null:
		_registry.set_state(_scope_key, puzzle_id, _save_state())


## Re-reads the saved state (on ready and after the run is restored from a snapshot).
func restore_saved_state() -> void:
	if persistent and puzzle_id != "" and _registry != null:
		_apply_saved_state(_registry.get_state(_scope_key, puzzle_id))


func _save_state() -> Dictionary:
	return {}


func _apply_saved_state(_state: Dictionary) -> void:
	pass


## Changes the on/off state; emits `changed` only on a real change.
func _set_active(on: bool) -> void:
	if on == _active:
		return
	_active = on
	changed.emit(on)
	queue_redraw()


func _feedback(stream: AudioStream, pitch := 1.0) -> void:
	if not Engine.is_editor_hint():
		Sfx.play(stream, self, CONFIG.feedback_volume_db, pitch)


func _draw_debug(offset := Vector2(0, -24)) -> void:
	if not (debug_visible and OS.is_debug_build()) or Engine.is_editor_hint():
		return
	draw_string(ThemeDB.fallback_font, offset, "%s %s" % [puzzle_id, debug_state()],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, 0.9))


## Resolves a NodePath export to a PuzzleSource (reports an error when it is not one).
func resolve_source(path: NodePath) -> PuzzleSource:
	if path.is_empty():
		return null
	var node := get_node_or_null(path)
	if not (node is PuzzleSource):
		push_error("%s: '%s' is not a PuzzleSource" % [get_path(), path])
		return null
	return node
