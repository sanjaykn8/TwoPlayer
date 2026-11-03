class_name PuzzleRegistry
extends RefCounted
## Puzzle progress for the current run (owned by RunState, so it follows the same lifetime:
## kept across scene changes, replaced by RunState.reset()).
##
## Saved state: scope key -> puzzle id -> small JSON-compatible Dictionary written by a
## persistent puzzle node (a completed lock, an opened latch gate, a toggled switch).
## Scope keys: a level id for level-scoped puzzles, CAMPAIGN for campaign-wide ones.
## Temporary states (a held plate, a running timer) are never written here.
##
## Live registration: every puzzle node in the tree registers under its scope key and id,
## so duplicate ids are reported and tools/tests can list the live puzzles.

signal state_changed(scope_key: String, puzzle_id: String)
## restore() replaced everything; live persistent nodes re-read their state.
signal restored

const VERSION := 1
const CAMPAIGN := "campaign"

## scope key -> {puzzle id -> Dictionary}
var _states := {}
## scope key -> {puzzle id -> Node}
var _live := {}


func get_state(scope_key: String, puzzle_id: String) -> Dictionary:
	return _states.get(scope_key, {}).get(puzzle_id, {})


func has_state(scope_key: String, puzzle_id: String) -> bool:
	return _states.has(scope_key) and _states[scope_key].has(puzzle_id)


## Stores (or with an empty Dictionary, erases) one puzzle's saved state.
func set_state(scope_key: String, puzzle_id: String, state: Dictionary) -> void:
	if scope_key == "" or puzzle_id == "":
		return
	if state.is_empty():
		if not has_state(scope_key, puzzle_id):
			return
		_states[scope_key].erase(puzzle_id)
		if _states[scope_key].is_empty():
			_states.erase(scope_key)
	else:
		if not _states.has(scope_key):
			_states[scope_key] = {}
		if _states[scope_key].get(puzzle_id, {}) == state:
			return
		_states[scope_key][puzzle_id] = state.duplicate(true)
	state_changed.emit(scope_key, puzzle_id)


## Forgets every saved state of one level (a future "restart level" would use this).
func clear_scope(scope_key: String) -> void:
	_states.erase(scope_key)


## How many saved states, over every level, have an id starting with `prefix` (for example
## defeated enemies: SaveIds.ENEMY_PREFIX).
func count_with_prefix(prefix: String, contains := "") -> int:
	var n := 0
	for scope: String in _states:
		for id: String in _states[scope]:
			if id.begins_with(prefix) and (contains == "" or id.contains(contains)):
				n += 1
	return n


func scope_keys() -> Array:
	var keys := _states.keys()
	keys.sort()
	return keys


# --- Live registration -------------------------------------------------------------

## Returns false (and, with `report`, reports an error) when another live node already
## uses the id.
func register(scope_key: String, puzzle_id: String, node: Node, report := true) -> bool:
	if puzzle_id == "":
		return true  # anonymous helpers are allowed; they cannot persist anything
	if not _live.has(scope_key):
		_live[scope_key] = {}
	var other: Node = _live[scope_key].get(puzzle_id)
	if other != null and is_instance_valid(other) and other != node:
		if report:
			push_error("Duplicate puzzle id '%s' in %s (%s and %s)" % [puzzle_id, scope_key, other.get_path(), node.get_path()])
		return false
	_live[scope_key][puzzle_id] = node
	return true


func unregister(scope_key: String, puzzle_id: String, node: Node) -> void:
	if _live.has(scope_key) and _live[scope_key].get(puzzle_id) == node:
		_live[scope_key].erase(puzzle_id)
		if _live[scope_key].is_empty():
			_live.erase(scope_key)


func live_node(scope_key: String, puzzle_id: String) -> Node:
	var node: Node = _live.get(scope_key, {}).get(puzzle_id)
	return node if is_instance_valid(node) else null


func live_ids(scope_key: String) -> Array:
	var ids: Array = _live.get(scope_key, {}).keys()
	ids.sort()
	return ids


# --- Snapshot ------------------------------------------------------------------------

func snapshot() -> Dictionary:
	return {"version": VERSION, "states": _states.duplicate(true)}


## True when `data` is a valid snapshot (checked before anything changes).
static func is_valid_snapshot(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or not data.has("version") or not data.has("states"):
		return false
	if int(data.version) > VERSION or typeof(data.states) != TYPE_DICTIONARY:
		return false
	for scope_key: Variant in data.states:
		if typeof(scope_key) != TYPE_STRING or typeof(data.states[scope_key]) != TYPE_DICTIONARY:
			return false
		for puzzle_id: Variant in data.states[scope_key]:
			if typeof(puzzle_id) != TYPE_STRING or typeof(data.states[scope_key][puzzle_id]) != TYPE_DICTIONARY:
				return false
	return true


func restore(data: Variant) -> bool:
	if not is_valid_snapshot(data):
		return false
	_states = (data.states as Dictionary).duplicate(true)
	restored.emit()
	return true
