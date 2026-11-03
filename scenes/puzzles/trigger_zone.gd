@tool
class_name TriggerZone
extends PressurePlate
## An invisible area that activates while living knights are inside it (standing, jumping or
## climbing). Same modes and rules as PressurePlate; origin = top-left of `size`.
## Used for "reach this place" conditions such as the end of a separate route.

@export var size := Vector2(32, 32):
	set(value):
		size = value.max(Vector2(4, 4))
		width = size.x
		_rebuild()


func _knight_counts(knight: Knight) -> bool:
	return not knight.is_dead()


func _sensor_rect() -> Rect2:
	return Rect2(Vector2.ZERO, size)


func _draw() -> void:
	if Engine.is_editor_hint() or (debug_visible and OS.is_debug_build()):
		draw_rect(_sensor_rect(), Color(0.3, 0.9, 1.0, 0.35 if _active else 0.15))
		draw_rect(_sensor_rect(), Color(0.3, 0.9, 1.0, 0.8), false, 1.0)
	_draw_debug(Vector2(0, -4))
