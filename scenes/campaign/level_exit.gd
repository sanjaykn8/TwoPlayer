@tool
class_name LevelExit
extends Area2D
## The level's exit portal. When EITHER living knight enters it, the level is complete and
## both surviving knights move on together (GDD section 10); CampaignGame listens to
## `activated`. It fires once. Origin = bottom-left; `size` in pixels.

signal activated(knight: Knight)

const GROUP := &"campaign_exits"
const FRAME := Color("3d3550")
const GLOW := Color(0.55, 0.85, 1.0, 0.75)

@export var size := Vector2(24, 40):
	set(value):
		size = value.max(Vector2(8, 8))
		queue_redraw()

var used := false
var _time := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 << 4  # knight hurtboxes
	monitorable = false
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = size
	shape.shape = box
	shape.position = Vector2(size.x * 0.5, -size.y * 0.5)
	add_child(shape, false, Node.INTERNAL_MODE_FRONT)
	if Engine.is_editor_hint():
		return
	add_to_group(GROUP)
	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _on_area_entered(area: Area2D) -> void:
	var hurtbox := area as HurtboxComponent
	if used or hurtbox == null or not (hurtbox.entity is Knight) or (hurtbox.entity as Knight).is_dead():
		return
	used = true
	activated.emit(hurtbox.entity)


func _draw() -> void:
	draw_rect(Rect2(0, -size.y, size.x, size.y), FRAME)
	var inner := Rect2(2, -size.y + 2, size.x - 4, size.y - 2)
	draw_rect(inner, Color(GLOW, 0.35 + 0.15 * sin(_time * 3.0)))
	for i in 3:
		var y := -fmod(_time * 18.0 + i * 13.0, size.y - 4.0) - 2.0
		draw_rect(Rect2(Vector2(size.x * 0.5 - 1 + (i - 1) * 4, y).round(), Vector2(2, 2)), GLOW)
