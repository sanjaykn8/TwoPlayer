@tool
class_name FallingRock
extends Node2D
## A loose rock hanging from the ceiling. When a knight passes below it (within `trigger_width`
## px sideways and `drop_range` px down) it shakes for the config shake time (the telegraph),
## falls, and shatters on the ground. A knight it lands on loses 1 health (SPIKE damage). It
## grows back after the respawn time. The origin is the ceiling point it hangs from.

const CONFIG := preload("res://resources/config/mechanism_config.tres")

enum Phase { HANGING, SHAKING, FALLING, GONE }

@export var trigger_width := 20.0
@export var drop_range := 160.0

var phase := Phase.HANGING
var _t := 0.0
var _y := 0.0
var _vy := 0.0
var _ray := PhysicsRayQueryParameters2D.new()
var _shape := RectangleShape2D.new()


func _ready() -> void:
	_shape.size = Vector2(10, 10)
	_ray.collision_mask = 1 | 2
	z_index = 2


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	match phase:
		Phase.HANGING:
			for node in get_tree().get_nodes_in_group(Knight.GROUP):
				var k := node as Knight
				var d := k.global_position - global_position
				if not k.is_dead() and absf(d.x) <= trigger_width and d.y > 0.0 and d.y <= drop_range:
					phase = Phase.SHAKING
					_t = 0.0
					Sfx.cue(&"rock", self)
					break
		Phase.SHAKING:
			if _t >= CONFIG.rock_shake_time:
				phase = Phase.FALLING
				_vy = 0.0
		Phase.FALLING:
			_vy += CONFIG.rock_gravity * delta
			var step := _vy * delta
			var from := global_position + Vector2(0, _y + 10.0)
			_ray.from = from
			_ray.to = from + Vector2(0, step)
			var hit := get_world_2d().direct_space_state.intersect_ray(_ray)
			_y += step
			for hurt in SpaceQuery.knight_hurtboxes(get_world_2d(), _shape, Transform2D(0.0, global_position + Vector2(0, _y + 5.0))):
				hurt.receive_hit(DamageEvent.create(1, DamageEvent.Category.SPIKE, self))
				_shatter()
				return
			if not hit.is_empty() or _y > drop_range + 64.0:
				_shatter()
		Phase.GONE:
			if _t >= CONFIG.rock_respawn_time:
				phase = Phase.HANGING
				_y = 0.0
	queue_redraw()


func _shatter() -> void:
	Fx.burst(self, global_position + Vector2(0, _y + 6.0), Color(0.55, 0.5, 0.48), 8, 70.0, 0.35)
	Sfx.cue(&"rock", self)
	phase = Phase.GONE
	_t = 0.0


func _draw() -> void:
	if phase == Phase.GONE:
		if _t > CONFIG.rock_respawn_time * 0.6:
			draw_rect(Rect2(-2, 0, 4, 3), Color(0.4, 0.36, 0.35))
		return
	var shake := Vector2(roundf(sin(_t * 70.0)), 0) if phase == Phase.SHAKING else Vector2.ZERO
	var o := Vector2(0, _y) + shake
	var pts := PackedVector2Array([o + Vector2(-6, 0), o + Vector2(6, 0), o + Vector2(4, 6), o + Vector2(1, 12), o + Vector2(-2, 9), o + Vector2(-5, 5)])
	draw_colored_polygon(pts, Color(0.1, 0.09, 0.09))
	var inner := PackedVector2Array([o + Vector2(-5, 1), o + Vector2(5, 1), o + Vector2(3, 6), o + Vector2(1, 10), o + Vector2(-2, 8), o + Vector2(-4, 5)])
	draw_colored_polygon(inner, Color(0.52, 0.47, 0.45))
	draw_rect(Rect2(o + Vector2(-3, 2), Vector2(2, 2)), Color(0.68, 0.63, 0.6))
