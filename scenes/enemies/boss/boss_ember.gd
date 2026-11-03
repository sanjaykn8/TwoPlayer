class_name BossEmber
extends Area2D
## A burning patch left where the Magma boss lands. While it burns, a knight that touches it
## gets one HOT_GROUND DamageEvent per entry (shields and the yellow jar can block it, like
## hot ground). Not solid; disappears after `lifetime` seconds.

const COLOUR := Color(1.0, 0.45, 0.1)

var width := 48.0
var lifetime := 3.0
var _left := 0.0
var _inside := {}


func _ready() -> void:
	collision_layer = 1 << 8
	collision_mask = 1 << 4
	monitorable = false
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(width, 6)
	shape.shape = box
	shape.position = Vector2(0, -3)
	add_child(shape)
	_left = lifetime
	area_entered.connect(_on_area_entered)
	area_exited.connect(func(area: Area2D) -> void: _inside.erase(area.get_instance_id()))


func _physics_process(delta: float) -> void:
	_left -= delta
	queue_redraw()
	if _left <= 0.0:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	var hurtbox := area as HurtboxComponent
	if hurtbox == null or not (hurtbox.entity is Knight) or _inside.has(area.get_instance_id()):
		return
	_inside[area.get_instance_id()] = true
	hurtbox.receive_hit(DamageEvent.create(1, DamageEvent.Category.HOT_GROUND, self))


func _draw() -> void:
	var fade := clampf(_left / 0.5, 0.0, 1.0)
	for i in int(width / 4.0):
		var flicker := 2.0 + float((i * 7 + int(_left * 12.0)) % 4)
		draw_rect(Rect2(-width * 0.5 + i * 4, -flicker, 3, flicker), Color(COLOUR, 0.85 * fade))
