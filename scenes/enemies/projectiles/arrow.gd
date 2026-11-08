class_name EnemyArrow
extends Node2D
## A straight-flying arrow (hollow archers, the Hollow Captain). Hits the first knight hurtbox
## it touches (1 CONTACT damage) or stops at solid terrain. Knights can cut it out of the air:
## it has an ordinary hurtbox on the enemy-hurtbox layer.
## The arrow's box is 10x4 px around its origin; fired at chest height it misses a crouching
## knight (whose hurtbox is 11 px tall).

const KNIGHT_HURTBOX := 16
const WORLD := 1
const BOX := Vector2(10, 4)

var velocity := Vector2.ZERO
var damage := 1
var source: Node
var _range_left := 260.0
var _ray := PhysicsRayQueryParameters2D.new()
var _shape := RectangleShape2D.new()
var _params := PhysicsShapeQueryParameters2D.new()

@onready var hurtbox: HurtboxComponent = $Hurtbox
@onready var sprite: Sprite2D = $Sprite


func launch(from: Vector2, direction: Vector2, speed: float, max_range: float, by: Node) -> void:
	global_position = from
	velocity = direction.normalized() * speed
	_range_left = max_range
	source = by
	rotation = velocity.angle()


func _ready() -> void:
	hurtbox.entity = self
	hurtbox.hit_received.connect(_on_cut)
	_shape.size = BOX
	_params.shape = _shape
	_params.collision_mask = KNIGHT_HURTBOX
	_params.collide_with_areas = true
	_params.collide_with_bodies = false
	_ray.collision_mask = WORLD


func _physics_process(delta: float) -> void:
	var step := velocity * delta
	_ray.from = global_position
	_ray.to = global_position + step
	var wall := get_world_2d().direct_space_state.intersect_ray(_ray)
	if not wall.is_empty():
		Fx.burst(self, wall.position, Color(0.8, 0.75, 0.65), 3, 30.0, 0.2)
		queue_free()
		return
	global_position += step
	_range_left -= step.length()
	_params.transform = Transform2D(0.0, global_position)
	for hit in get_world_2d().direct_space_state.intersect_shape(_params, 4):
		var hurt := hit.collider as HurtboxComponent
		if hurt != null and hurt.enabled:
			hurt.receive_hit(DamageEvent.create(damage, DamageEvent.Category.CONTACT, self))
			Sfx.cue(&"arrow_hit", self)
			queue_free()
			return
	if _range_left <= 0.0:
		queue_free()


func _on_cut(event: DamageEvent) -> void:
	if event.category != DamageEvent.Category.MELEE:
		return
	Sfx.cue(&"arrow_hit", self)
	Fx.spark(self, global_position)
	queue_free()
