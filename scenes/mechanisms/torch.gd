class_name Torch
extends Node2D
## A wall torch: a flickering flame and, in dark levels, a warm light. Origin = the bracket.

@export var radius := 72.0

var _t := 0.0
var _light: PointLight2D


func _ready() -> void:
	_t = fposmod(global_position.x * 0.37, 6.28)
	_light = Darkness.make_light(radius, Color(1.0, 0.7, 0.4), 0.9)
	_light.position = Vector2(0, -8)
	add_child(_light)


func _process(delta: float) -> void:
	_t += delta
	_light.energy = 0.85 + 0.1 * sin(_t * 9.0) + 0.05 * sin(_t * 23.0)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-1, -4, 2, 6), Color(0.3, 0.2, 0.12))
	draw_rect(Rect2(-2, -5, 4, 2), Color(0.18, 0.14, 0.12))
	var f := roundf(sin(_t * 12.0))
	draw_rect(Rect2(-2, -10 + f, 4, 5), Color(1.0, 0.5, 0.15))
	draw_rect(Rect2(-1, -12 + f, 2, 5), Color(1.0, 0.85, 0.4))
