@tool
class_name Climbable
extends Area2D
## A ladder or designated vertical passage. Knights find it with point queries on the
## "climb" physics layer, so it needs no signals.
##
## The node origin is the TOP-CENTRE of the climbable area. Place the top on the surface
## the knight should stand on when it climbs out (for example a one-way platform).

enum Kind {
	## Snaps the knight to the centre. Sideways input lets go.
	LADDER,
	## Free movement in all four directions while inside the area.
	PASSAGE,
}

const CLIMB_LAYER := 1 << 9  # physics layer 10 "climb"

@export var kind := Kind.LADDER:
	set(value):
		kind = value
		queue_redraw()
## Width and height of the area in pixels.
@export var size := Vector2(16, 64):
	set(value):
		size = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))
		_update_shape()
		queue_redraw()
## Tiled vertically to draw a ladder. Leave empty for an invisible or tinted area.
@export var texture: Texture2D:
	set(value):
		texture = value
		queue_redraw()
## Fill drawn when there is no texture (used for passages).
@export var fill_color := Color(0.25, 0.7, 0.4, 0.25):
	set(value):
		fill_color = value
		queue_redraw()

var _shape_node: CollisionShape2D


func _ready() -> void:
	collision_layer = CLIMB_LAYER
	collision_mask = 0
	monitoring = false
	monitorable = true
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_update_shape()


func area_rect() -> Rect2:
	return Rect2(Vector2(-size.x * 0.5, 0.0), size)


func top_y() -> float:
	return global_position.y


func bottom_y() -> float:
	return global_position.y + size.y


func center_x() -> float:
	return global_position.x


## True while a climbing knight whose body centre is at `point` is still on this
## climbable. The top is not checked: knights leave upward through the top exit.
func holds(point: Vector2) -> bool:
	var half_width := size.x * 0.5
	return absf(point.x - global_position.x) <= half_width and point.y <= bottom_y()


func allows_horizontal_movement() -> bool:
	return kind == Kind.PASSAGE


func _update_shape() -> void:
	if not is_inside_tree() and _shape_node == null:
		return
	if _shape_node == null:
		_shape_node = CollisionShape2D.new()
		_shape_node.name = "Shape"
		add_child(_shape_node, false, Node.INTERNAL_MODE_FRONT)  # internal: never saved with the scene
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape_node.shape = rect
	_shape_node.position = Vector2(0.0, size.y * 0.5)


func _draw() -> void:
	var rect := area_rect()
	if texture != null:
		draw_texture_rect(texture, rect, true)
	else:
		draw_rect(rect, fill_color, true)
		draw_rect(rect, Color(fill_color, 0.8), false, 1.0)
