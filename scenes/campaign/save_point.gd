@tool
class_name SavePoint
extends Area2D
## A designated safe place: when a living knight reaches it, the campaign autosaves
## (CampaignGame listens to `reached`). Fires again only after both knights have left it and
## one returns, so standing on it never spams saves. Origin = its foot on the floor.

signal reached(save_point: SavePoint)

const GROUP := &"campaign_save_points"
const POLE := Color("5b4636")
const CLOTH := Color("b8c2cc")
const CLOTH_LIT := Color("f2c14e")

@export var save_id := ""

var lit := false
var times_reached := 0

var _inside := {}


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 << 4  # knight hurtboxes
	monitorable = false
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(24, 32)
	shape.shape = box
	shape.position = Vector2(0, -16)
	add_child(shape, false, Node.INTERNAL_MODE_FRONT)
	if Engine.is_editor_hint():
		return
	add_to_group(GROUP)
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _on_area_entered(area: Area2D) -> void:
	var hurtbox := area as HurtboxComponent
	if hurtbox == null or not (hurtbox.entity is Knight) or (hurtbox.entity as Knight).is_dead():
		return
	var was_empty := _inside.is_empty()
	_inside[hurtbox.entity.get_instance_id()] = true
	if was_empty:
		times_reached += 1
		lit = true
		queue_redraw()
		reached.emit(self)


func _on_area_exited(area: Area2D) -> void:
	var hurtbox := area as HurtboxComponent
	if hurtbox != null and hurtbox.entity != null:
		_inside.erase(hurtbox.entity.get_instance_id())


func _draw() -> void:
	draw_rect(Rect2(-1, -28, 2, 28), POLE)
	draw_rect(Rect2(-3, -1, 6, 1), POLE)
	var cloth := CLOTH_LIT if lit else CLOTH
	draw_colored_polygon(PackedVector2Array([Vector2(1, -28), Vector2(11, -24), Vector2(1, -20)]), cloth)
