@tool
class_name CollapsingPlatform
extends PlatformBody
## Collapses after a knight lands on it.
##   STABLE -> (a knight stands on it) -> SHAKING for `collapse_delay` -> COLLAPSED (no
##   collision; pieces drop and fade) -> after `recovery_time` REAPPEARING (blinking, waits
##   until its space is empty) -> STABLE.  With `permanent`, it stays COLLAPSED.
## Only a knight STANDING on top starts it: a knight passing below or beside does not.

signal state_changed(state: CollapsingPlatform.State)

enum State { STABLE, SHAKING, COLLAPSED, REAPPEARING }

@export var collapse_delay := 0.6
@export var recovery_time := 3.0
## Shake amplitude in pixels (visual only).
@export var shake_intensity := 1.0
## Never comes back (for future one-shot sections).
@export var permanent := false
@export var reappear_time := 0.4

var state := State.STABLE
var time_in_state := 0.0
var collapses := 0

## knight instance id -> Knight overlapping the sensor above the platform
var _riders := {}
var _sensor: Area2D


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	_build_sensor()


func state_name() -> String:
	return State.keys()[state]


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	time_in_state += delta
	match state:
		State.STABLE:
			if _has_standing_knight():
				_enter(State.SHAKING)
		State.SHAKING:
			if time_in_state >= collapse_delay:
				collapses += 1
				_enter(State.COLLAPSED)
		State.COLLAPSED:
			if not permanent and time_in_state >= recovery_time:
				_enter(State.REAPPEARING)
		State.REAPPEARING:
			if time_in_state >= reappear_time and not is_occupied():
				_enter(State.STABLE)
	_update_visual()


func _enter(next: State) -> void:
	state = next
	time_in_state = 0.0
	set_collision_enabled(next == State.STABLE or next == State.SHAKING)
	state_changed.emit(next)


func capture_live() -> Dictionary:
	return {"state": state, "time": time_in_state, "collapses": collapses}


func apply_live(data: Dictionary) -> void:
	var next := int(data.get("state", State.STABLE))
	if next < 0 or next >= State.size():
		return
	_enter(next as State)
	time_in_state = clampf(float(data.get("time", 0.0)), 0.0, 3600.0)
	collapses = maxi(int(data.get("collapses", 0)), 0)
	_update_visual()


func fade_in_safely() -> void:
	if collision_enabled():
		_enter(State.REAPPEARING)
		_update_visual()


## A knight counts only when it is on the floor with its feet at the platform's top surface.
func _has_standing_knight() -> bool:
	for knight: Knight in _riders.values():
		if is_instance_valid(knight) and knight.is_on_floor() and knight.velocity.y >= 0.0 \
				and absf(knight.global_position.y - global_position.y) <= 2.0:
			return true
	return false


func _build_sensor() -> void:
	_sensor = Area2D.new()
	_sensor.collision_layer = 0
	_sensor.collision_mask = 1 << 4  # player_hurtbox
	_sensor.monitorable = false
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(width_px(), 4)
	shape.shape = box
	shape.position = Vector2(width_px() * 0.5, -2)  # just above the top surface
	_sensor.add_child(shape)
	add_child(_sensor, false, Node.INTERNAL_MODE_FRONT)
	_sensor.area_entered.connect(func(area: Area2D) -> void:
		var hurtbox := area as HurtboxComponent
		if hurtbox != null and hurtbox.entity is Knight:
			_riders[hurtbox.entity.get_instance_id()] = hurtbox.entity)
	_sensor.area_exited.connect(func(area: Area2D) -> void:
		var hurtbox := area as HurtboxComponent
		if hurtbox != null and hurtbox.entity is Knight:
			_riders.erase(hurtbox.entity.get_instance_id()))


func _update_visual() -> void:
	visual_offset = Vector2.ZERO
	visual_tint = Color.WHITE
	visual_alpha = 1.0
	match state:
		State.SHAKING:
			var t := time_in_state * 40.0
			visual_offset = Vector2(roundf(sin(t) * shake_intensity), roundf(cos(t * 1.3) * shake_intensity * 0.5))
			visual_tint = Color(1.0, 0.8, 0.7)
		State.COLLAPSED:
			var fall := clampf(time_in_state / 0.3, 0.0, 1.0)
			visual_offset = Vector2(0, roundf(fall * 10.0))
			visual_alpha = 1.0 - fall
		State.REAPPEARING:
			visual_alpha = 0.3 + 0.3 * absf(sin(time_in_state * 12.0))
	queue_redraw()
