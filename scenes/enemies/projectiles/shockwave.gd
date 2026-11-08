class_name Shockwave
extends Node2D
## A ground shockwave (brute and warchief slams): runs along the floor at `speed` for `max_range`
## pixels, hurting knights it touches once each (1 CONTACT damage). Jumping over it is the
## counter. It stops at walls and ledges. Drawn by code as a rippling crest of dust.

const KNIGHT_HURTBOX := 16
const WORLD := 1 | 2
const HEIGHT := 12.0

var direction := 1
var speed := 120.0
var damage := 1
var _range_left := 96.0
var _hit := {}
var _t := 0.0
var _ray := PhysicsRayQueryParameters2D.new()
var _params := PhysicsShapeQueryParameters2D.new()


func launch(from: Vector2, dir: int, wave_speed: float, max_range: float) -> void:
	global_position = from
	direction = 1 if dir >= 0 else -1
	speed = wave_speed
	_range_left = max_range


func _ready() -> void:
	z_index = 3
	var shape := RectangleShape2D.new()
	shape.size = Vector2(10, HEIGHT)
	_params.shape = shape
	_params.collision_mask = KNIGHT_HURTBOX
	_params.collide_with_areas = true
	_params.collide_with_bodies = false


func _physics_process(delta: float) -> void:
	_t += delta
	var step := direction * speed * delta
	var ahead := global_position + Vector2(step + direction * 5.0, 0)
	# Floor under the next position, and no wall in the way.
	_ray.collision_mask = WORLD
	_ray.from = ahead + Vector2(0, -2)
	_ray.to = ahead + Vector2(0, 6)
	var floor_hit := get_world_2d().direct_space_state.intersect_ray(_ray)
	_ray.collision_mask = 1
	_ray.from = global_position + Vector2(0, -6)
	_ray.to = ahead + Vector2(0, -6)
	var wall := get_world_2d().direct_space_state.intersect_ray(_ray)
	if floor_hit.is_empty() or not wall.is_empty() or _range_left <= 0.0:
		Fx.dust(self, global_position, 4)
		queue_free()
		return
	global_position.x += step
	_range_left -= absf(step)
	_params.transform = Transform2D(0.0, global_position + Vector2(0, -HEIGHT * 0.5))
	for hit in get_world_2d().direct_space_state.intersect_shape(_params, 4):
		var hurt := hit.collider as HurtboxComponent
		if hurt != null and hurt.enabled and not _hit.has(hurt):
			_hit[hurt] = true
			hurt.receive_hit(DamageEvent.create(damage, DamageEvent.Category.CONTACT, self))
	queue_redraw()


func _draw() -> void:
	var c := Color(0.95, 0.85, 0.6)
	for i in 3:
		var h := HEIGHT * (1.0 - i * 0.3) * (0.8 + 0.2 * sin(_t * 30.0 + i))
		var x := -direction * i * 3.0
		draw_rect(Rect2(Vector2(x - 1, -h), Vector2(2, h)).abs(), Color(c, 1.0 - i * 0.3))
	draw_rect(Rect2(-6, -2, 12, 2), Color(0.6, 0.5, 0.4, 0.8))
