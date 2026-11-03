class_name HurtboxComponent
extends Area2D
## The area that can be hit. Attacks find hurtboxes with a shape query on its collision layer
## and call receive_hit(); the owning entity listens to hit_received.
## Needs one CollisionShape2D child with a RectangleShape2D (used for line-of-sight checks).

signal hit_received(event: DamageEvent)

## The entity this hurtbox belongs to (used to ignore self-hits and to count one hit per
## entity per attack). Defaults to the parent node.
@export var entity: Node
## Disabled hurtboxes are ignored by attacks.
@export var enabled := true:
	set(value):
		enabled = value
		monitorable = value

var _shape_node: CollisionShape2D


func _ready() -> void:
	monitoring = false
	monitorable = enabled
	if entity == null:
		entity = get_parent()
	for child in get_children():
		if child is CollisionShape2D:
			_shape_node = child
			break
	if _shape_node == null or not (_shape_node.shape is RectangleShape2D):
		push_error("%s: HurtboxComponent needs a CollisionShape2D with a RectangleShape2D" % get_path())


func receive_hit(event: DamageEvent) -> void:
	if enabled:
		hit_received.emit(event)


## The hurtbox rectangle in world coordinates.
func world_rect() -> Rect2:
	var size := (_shape_node.shape as RectangleShape2D).size
	return Rect2(_shape_node.global_position - size * 0.5, size)


## Resizes the hurtbox (crouching). The shape is made unique to this instance first.
func set_box(size: Vector2, center: Vector2) -> void:
	if not _shape_node.shape.resource_local_to_scene:
		_shape_node.shape = _shape_node.shape.duplicate()
		_shape_node.shape.resource_local_to_scene = true
	(_shape_node.shape as RectangleShape2D).size = size
	_shape_node.position = center
