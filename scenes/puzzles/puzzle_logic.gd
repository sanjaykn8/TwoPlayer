@tool
class_name PuzzleLogic
extends PuzzleSource
## A lock that combines other PuzzleSources (plates, switches, targets, other locks) and is
## itself a PuzzleSource, so gates and platform controllers can follow it and locks can be
## chained. No custom code per puzzle: set `inputs`, `mode` and options.
##
## Modes:
##   ALL       every input active at the same time
##   ANY       at least one input active
##   SYNC      every input pulsed within `window` seconds of the first (synchronised strikes);
##             a partial attempt that runs out of time FAILS and resets safely
##   SEQUENCE  inputs pulsed in the listed order; a wrong one FAILS and resets
## `distinct_players`: each input must be credited to a different knight (one knight cannot
## satisfy a two-knight condition, e.g. by standing on two adjacent plates).
## `latch`: once satisfied it is COMPLETED for good, emits `completed` exactly once and is
## saved with the run. Without latch, ALL/ANY follow their inputs; SYNC/SEQUENCE stay ACTIVE
## for `active_time` seconds, then reset.
## States: INACTIVE, PARTIAL, ACTIVE, COMPLETED, FAILED. All timers run in physics frames, so
## they stop while the game is paused.

signal completed
signal failed
signal state_changed(state: PuzzleLogic.State)

enum Mode { ALL, ANY, SYNC, SEQUENCE }
enum State { INACTIVE, PARTIAL, ACTIVE, COMPLETED, FAILED }

@export var inputs: Array[NodePath] = []
@export var mode := Mode.ALL
@export var distinct_players := false
@export var latch := false
@export var window := 2.0
@export var active_time := 4.0
## After a failure, call reset_source() on every input (lights out, toggles off).
@export var reset_inputs_on_fail := true

var state := State.INACTIVE
var completions := 0
var failures := 0
var time_in_state := 0.0

var _sources: Array[PuzzleSource] = []
## SYNC: input index -> seconds since its pulse; and -> pulsing player id.
var _ages := {}
var _pulse_players := {}
## SEQUENCE: index of the next expected input.
var _step := 0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	for i in inputs.size():
		var source := resolve_source(inputs[i])
		if source == null:
			continue
		_sources.append(source)
		source.changed.connect(_on_input_changed.unbind(1))
		source.credit_changed.connect(_on_input_changed)
		source.pulsed.connect(_on_input_pulsed.bind(_sources.size() - 1))
	restore_saved_state()
	if state != State.COMPLETED:
		_on_input_changed()


func sources() -> Array[PuzzleSource]:
	return _sources


func state_name() -> String:
	return State.keys()[state]


func debug_state() -> String:
	var text := "%s %s" % [Mode.keys()[mode], state_name()]
	if mode == Mode.SYNC and state == State.PARTIAL:
		text += " %.1fs" % maxf(window - _oldest_age(), 0.0)
	elif mode == Mode.SEQUENCE:
		text += " %d/%d" % [_step, _sources.size()]
	return text


## Seconds left in the current SYNC attempt (0 when none is running).
func sync_time_left() -> float:
	return maxf(window - _oldest_age(), 0.0) if state == State.PARTIAL and mode == Mode.SYNC else 0.0


func active_players() -> Array[int]:
	var players: Array[int] = []
	for source in _sources:
		for id in source.active_players():
			if not players.has(id):
				players.append(id)
	players.sort()
	return players


## Back to the initial state (a COMPLETED lock stays completed).
func reset_source() -> void:
	if state == State.COMPLETED:
		return
	_clear_attempt()
	_enter(State.INACTIVE)


## True when every entry of `options` (one Array[int] of candidate players per input) can be
## given a different player.
static func can_assign_distinct(options: Array, used: Array = []) -> bool:
	if options.is_empty():
		return true
	var rest := options.slice(1)
	for id: int in options[0]:
		if not used.has(id) and can_assign_distinct(rest, used + [id]):
			return true
	return false


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	time_in_state += delta
	match state:
		State.PARTIAL:
			if mode == Mode.SYNC:
				for i: int in _ages:
					_ages[i] += delta
				if _oldest_age() > window:
					_fail()
		State.ACTIVE:
			if (mode == Mode.SYNC or mode == Mode.SEQUENCE) and time_in_state >= active_time:
				_reset_inputs()
				_clear_attempt()
				_enter(State.INACTIVE)
		State.FAILED:
			if time_in_state >= CONFIG.fail_display_time:
				_enter(State.INACTIVE)
				_on_input_changed()


func _on_input_changed() -> void:
	if state == State.COMPLETED or state == State.FAILED:
		return
	if mode != Mode.ALL and mode != Mode.ANY:
		return
	var any_on := false
	var all_on := not _sources.is_empty()
	var options := []
	for source in _sources:
		var on := source.is_active()
		any_on = any_on or on
		all_on = all_on and on
		options.append(source.active_players())
	var satisfied := any_on if mode == Mode.ANY else all_on
	if satisfied and mode == Mode.ALL and distinct_players:
		satisfied = can_assign_distinct(options)
	if satisfied:
		_succeed()
	elif any_on:
		_enter(State.PARTIAL)
	else:
		_enter(State.INACTIVE)


func _on_input_pulsed(player_id: int, index: int) -> void:
	if mode == Mode.ANY:
		pulsed.emit(player_id)  # lets a TIMED gate restart from any of several switches
	if mode == Mode.ALL or mode == Mode.ANY:
		_on_input_changed()  # credit may have moved to the other knight without a state change
		return
	if state == State.COMPLETED or state == State.FAILED or state == State.ACTIVE:
		return
	match mode:
		Mode.SYNC:
			_ages[index] = 0.0
			_pulse_players[index] = player_id
			if _ages.size() < _sources.size():
				_enter(State.PARTIAL)
				return
			var options := []
			for i in _sources.size():
				options.append([_pulse_players[i]])
			if distinct_players and not can_assign_distinct(options):
				_enter(State.PARTIAL)  # the same knight struck again: keep waiting for the other
				return
			_succeed()
		Mode.SEQUENCE:
			if index != _step:
				_fail()
				return
			_step += 1
			if _step >= _sources.size():
				_succeed()
			else:
				_enter(State.PARTIAL)


func _succeed() -> void:
	if latch:
		_enter(State.COMPLETED)
		completions += 1
		save_state()
		_feedback(Sfx.POWER_UP)
		completed.emit()
	elif state != State.ACTIVE:
		_enter(State.ACTIVE)
		completions += 1
		_feedback(Sfx.POWER_UP, 1.2)


func _fail() -> void:
	failures += 1
	_clear_attempt()
	if reset_inputs_on_fail:
		_reset_inputs()
	_enter(State.FAILED)
	_feedback(Sfx.TAP, 0.55)
	failed.emit()


func _reset_inputs() -> void:
	for source in _sources:
		source.reset_source()


func _clear_attempt() -> void:
	_ages.clear()
	_pulse_players.clear()
	_step = 0


func _oldest_age() -> float:
	var oldest := 0.0
	for i: int in _ages:
		oldest = maxf(oldest, _ages[i])
	return oldest


func _enter(next: State) -> void:
	if next == state:
		return
	state = next
	time_in_state = 0.0
	_set_active(next == State.ACTIVE or next == State.COMPLETED)
	state_changed.emit(next)
	queue_redraw()


func _save_state() -> Dictionary:
	return {"completed": true} if state == State.COMPLETED else {}


func _apply_saved_state(saved: Dictionary) -> void:
	if saved.get("completed", false) and state != State.COMPLETED:
		_clear_attempt()
		_enter(State.COMPLETED)


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(-4, -4, 8, 8), Color(0.8, 0.5, 1.0, 0.8), false, 1.0)
		for path in inputs:
			var node := get_node_or_null(path) as Node2D
			if node != null:
				draw_line(Vector2.ZERO, to_local(node.global_position), Color(0.8, 0.5, 1.0, 0.4), 1.0)
	_draw_debug(Vector2(-4, -8))
