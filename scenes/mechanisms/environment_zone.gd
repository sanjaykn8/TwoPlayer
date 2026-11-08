@tool
class_name EnvironmentZone
extends Area2D
## A region that changes how knights move inside it. Origin = top-left of `size`.
##   UPDRAFT  rising wind: knights float upward at `strength` px/s (or the config speed)
##   WIND     a steady push sideways: `direction` * `strength` px/s added to the run speed
##   ICE      slippery ground: acceleration and deceleration scaled by the config friction
## Knights register themselves on entry (Knight.enter_zone) and apply the effect in their own
## movement code, so both knights are affected the same way and independently.

enum Kind { UPDRAFT, WIND, ICE }

const CONFIG := preload("res://resources/config/mechanism_config.tres")

@export var kind := Kind.UPDRAFT:
	set(value):
		kind = value
		queue_redraw()
@export var size := Vector2(32, 96):
	set(value):
		size = value.max(Vector2(8, 8))
		_rebuild()
## -1 left, 1 right (WIND only).
@export var direction := 1
## 0 = the config value.
@export var strength := 0.0

var _shape: CollisionShape2D
var _t := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 << 2  # knight bodies
	monitorable = false
	monitoring = true
	_rebuild()
	if Engine.is_editor_hint():
		return
	body_entered.connect(func(b: Node) -> void:
		if b is Knight:
			(b as Knight).enter_zone(self))
	body_exited.connect(func(b: Node) -> void:
		if b is Knight:
			(b as Knight).leave_zone(self))


func _rebuild() -> void:
	if _shape == null:
		_shape = CollisionShape2D.new()
		add_child(_shape, false, Node.INTERNAL_MODE_FRONT)
	var box := RectangleShape2D.new()
	box.size = size
	_shape.shape = box
	_shape.position = size * 0.5
	queue_redraw()


func lift_speed() -> float:
	return strength if strength > 0.0 else CONFIG.updraft_speed


func push() -> float:
	return direction * (strength if strength > 0.0 else CONFIG.wind_push)


func friction() -> float:
	return CONFIG.ice_friction


func _process(delta: float) -> void:
	if kind != Kind.ICE:
		_t += delta
		queue_redraw()


func _draw() -> void:
	match kind:
		Kind.UPDRAFT:
			# Rising streaks: readable from a distance, light enough to see through.
			for i in int(size.x / 6.0):
				var x := 3.0 + i * 6.0
				var y := fposmod(-_t * 90.0 + i * 37.0, size.y)
				draw_rect(Rect2(x, y, 1, 6), Color(0.85, 0.95, 1.0, 0.45))
				draw_rect(Rect2(x, fposmod(y + size.y * 0.5, size.y), 1, 4), Color(0.85, 0.95, 1.0, 0.25))
			draw_rect(Rect2(0, size.y - 2, size.x, 2), Color(0.8, 0.9, 1.0, 0.35))
		Kind.WIND:
			for i in int(size.y / 8.0):
				var y := 4.0 + i * 8.0
				var x := fposmod(_t * 120.0 * direction + i * 53.0, size.x)
				draw_rect(Rect2(x, y, 8, 1), Color(1, 1, 1, 0.35))
		Kind.ICE:
			draw_rect(Rect2(0, size.y - 1, size.x, 1), Color(0.75, 0.95, 1.0, 0.8))
			for i in int(size.x / 12.0):
				draw_rect(Rect2(4 + i * 12, size.y - 1, 3, 1), Color(1, 1, 1, 0.95))
