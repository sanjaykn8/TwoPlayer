@tool
class_name TimedPlatform
extends PlatformBody
## A platform that is solid only part of the time.
## State machine (time counts only in physics frames, so it pauses with the game):
##   ACTIVE (solid) -> WARNING (solid, blinking red) -> DISABLED (no collision, faint ghost)
##   -> REACTIVATING (no collision, blinking in; waits until its space is empty) -> ACTIVE
## Modes:
##   SCHEDULE  (disappearing platform): cycles on its own forever.
##   TRIGGERED (timed platform): runs one ACTIVE -> WARNING -> DISABLED cycle after
##             activate(); then INACTIVE again, or cycles on if `auto_reactivate`.
## Collision is never restored while a knight or enemy overlaps the platform, so nobody can
## be trapped inside it.

signal state_changed(state: TimedPlatform.State)

enum Mode { SCHEDULE, TRIGGERED }
enum State { INACTIVE, ACTIVE, WARNING, DISABLED, REACTIVATING }

@export var mode := Mode.SCHEDULE
## Seconds fully solid, before the warning.
@export var active_time := 3.0
## Seconds of blinking warning while still solid.
@export var warning_time := 1.0
## Seconds without collision (cooldown / invisible time).
@export var disabled_time := 2.0
## Minimum seconds of the fade-in before collision returns.
@export var reactivate_time := 0.4
## Seconds already elapsed in the first ACTIVE phase (stagger platforms in a row).
@export var start_offset := 0.0
## TRIGGERED: begin ACTIVE (true) or INACTIVE waiting for activate() (false).
@export var start_active := true
## TRIGGERED: after the cooldown, reactivate automatically instead of waiting.
@export var auto_reactivate := false

var state := State.ACTIVE
var time_in_state := 0.0


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	if mode == Mode.TRIGGERED and not start_active:
		_enter(State.INACTIVE)
	else:
		_enter(State.ACTIVE)
		time_in_state = start_offset


## Starts an ACTIVE cycle (TRIGGERED platforms; Phase 7 switches will call this).
func activate() -> void:
	if state == State.INACTIVE:
		_enter(State.REACTIVATING)


func state_name() -> String:
	return State.keys()[state]


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	time_in_state += delta
	match state:
		State.ACTIVE:
			if time_in_state >= active_time:
				_enter(State.WARNING)
		State.WARNING:
			if time_in_state >= warning_time:
				_enter(State.DISABLED)
		State.DISABLED:
			if time_in_state >= disabled_time:
				if mode == Mode.SCHEDULE or auto_reactivate:
					_enter(State.REACTIVATING)
				else:
					_enter(State.INACTIVE)
		State.REACTIVATING:
			if time_in_state >= reactivate_time and not is_occupied():
				_enter(State.ACTIVE)
	_update_visual()


func _enter(next: State) -> void:
	state = next
	time_in_state = 0.0
	set_collision_enabled(next == State.ACTIVE or next == State.WARNING)
	state_changed.emit(next)


func capture_live() -> Dictionary:
	return {"state": state, "time": time_in_state}


func apply_live(data: Dictionary) -> void:
	var next := int(data.get("state", State.ACTIVE))
	if next < 0 or next >= State.size():
		return
	_enter(next as State)
	time_in_state = clampf(float(data.get("time", 0.0)), 0.0, 3600.0)
	_update_visual()


func fade_in_safely() -> void:
	if collision_enabled():
		_enter(State.REACTIVATING)
		_update_visual()


func _update_visual() -> void:
	visual_tint = Color.WHITE
	match state:
		State.ACTIVE:
			visual_alpha = 1.0
		State.WARNING:
			# Blinks faster as the end approaches.
			var rate := lerpf(6.0, 18.0, clampf(time_in_state / maxf(warning_time, 0.01), 0.0, 1.0))
			visual_alpha = 0.45 if sin(time_in_state * rate) < 0.0 else 1.0
			visual_tint = Color(1.0, 0.65, 0.6)
		State.DISABLED, State.INACTIVE:
			visual_alpha = 0.15
		State.REACTIVATING:
			visual_alpha = 0.3 + 0.3 * absf(sin(time_in_state * 12.0))
	queue_redraw()
