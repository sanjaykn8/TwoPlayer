@tool
class_name SawBlade
extends Node2D
## A spinning saw that runs back and forth along a rail from its origin to origin + `travel`
## (pixels). Touching the blade costs 1 health (SPIKE damage: shields and invulnerability apply).
## The rail is always drawn, so the blade's path is readable before it arrives.

const CONFIG := preload("res://resources/config/mechanism_config.tres")

@export var travel := Vector2(64, 0):
	set(value):
		travel = value
		queue_redraw()
## 0 = config speed (px/s).
@export var speed := 0.0
## Fraction (0..1) of the path the blade starts at.
@export_range(0.0, 1.0) var start_phase := 0.0

var _t := 0.0
var _spin := 0.0
var _shape := CircleShape2D.new()


func _ready() -> void:
	_shape.radius = CONFIG.saw_radius
	if travel.length() > 0.0:
		_t = start_phase * 2.0 * travel.length() / _speed()
	z_index = 2


func _speed() -> float:
	return speed if speed > 0.0 else CONFIG.saw_speed


## Blade centre in local coordinates (ping-pong along the rail).
func blade_position() -> Vector2:
	var length := travel.length()
	if length <= 0.0:
		return Vector2.ZERO
	var d := fposmod(_t * _speed(), 2.0 * length)
	var f := d / length if d <= length else 2.0 - d / length
	return travel * f


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	_spin += delta * 18.0
	var centre := global_position + blade_position()
	for hurt in SpaceQuery.knight_hurtboxes(get_world_2d(), _shape, Transform2D(0.0, centre)):
		hurt.receive_hit(DamageEvent.create(1, DamageEvent.Category.SPIKE, self))
	queue_redraw()


func _draw() -> void:
	draw_line(Vector2.ZERO, travel, Color(0.15, 0.13, 0.13), 3.0)
	draw_line(Vector2.ZERO, travel, Color(0.45, 0.42, 0.4), 1.0)
	for p in [Vector2.ZERO, travel]:
		draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), Color(0.2, 0.18, 0.18))
	var c := blade_position()
	var r := CONFIG.saw_radius
	var teeth := PackedVector2Array()
	for i in 16:
		var a := _spin + i * TAU / 16.0
		teeth.append(c + Vector2(cos(a), sin(a)) * (r + (1.5 if i % 2 == 0 else -0.5)))
	draw_colored_polygon(teeth, Color(0.12, 0.11, 0.12))
	draw_circle(c, r - 1.0, Color(0.72, 0.74, 0.78))
	draw_circle(c, r - 3.0, Color(0.55, 0.57, 0.62))
	draw_circle(c, 1.5, Color(0.2, 0.2, 0.22))
	draw_line(c, c + Vector2(cos(_spin), sin(_spin)) * (r - 2.0), Color(0.9, 0.92, 0.95), 1.0)
