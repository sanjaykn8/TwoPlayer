@tool
class_name MovingPlatform
extends PlatformBody
## Moves back and forth between its start position and start + `travel` at `speed`, pausing
## `pause_time` at each end. Horizontal, vertical or diagonal. Riders are carried by physics
## (AnimatableBody2D with sync_to_physics), never teleported.

## Offset of the far end from the start position (pixels).
@export var travel := Vector2(64, 0):
	set(value):
		travel = value
		queue_redraw()
@export var speed := 40.0
@export var pause_time := 0.5
## Seconds to wait before the first move (stagger several platforms).
@export var start_delay := 0.0
## true: ping-pong forever. false: travel once to the far end and stop.
@export var ping_pong := true

## 0 at the start position, 1 at the far end.
var progress := 0.0
## 1 moving toward the far end, -1 back.
var direction := 1
var start_position := Vector2.ZERO
var arrivals := 0

var _pause_left := 0.0


func _ready() -> void:
	super._ready()
	sync_to_physics = true
	start_position = position
	_pause_left = start_delay


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _pause_left > 0.0:
		_pause_left = maxf(_pause_left - delta, 0.0)
		return
	var length := travel.length()
	if length <= 0.0 or speed <= 0.0:
		return
	progress += direction * speed * delta / length
	if progress >= 1.0 or progress <= 0.0:
		progress = clampf(progress, 0.0, 1.0)
		arrivals += 1
		_pause_left = pause_time
		if ping_pong:
			direction = -direction
		else:
			set_physics_process(false)
	position = start_position + travel * progress


func _draw() -> void:
	super._draw()
	if Engine.is_editor_hint():
		draw_line(Vector2(width_px() * 0.5, 4), Vector2(width_px() * 0.5, 4) + travel, Color(0.2, 0.6, 1.0, 0.8), 1.0)
