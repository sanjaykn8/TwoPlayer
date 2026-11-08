@tool
class_name FireJet
extends Node2D
## A floor nozzle that breathes fire on a fixed cycle: OFF, then a sputtering WARNING, then ON
## (a column of flame `height_tiles` tall). Standing in the flame costs 1 health (HOT_GROUND:
## shields and invulnerability apply). The origin is on the floor surface at the nozzle centre;
## the nozzle is part of the floor (walkable). `start_offset` advances the cycle.

const CONFIG := preload("res://resources/config/mechanism_config.tres")

enum Phase { OFF, WARNING, ON }

@export_range(1, 8) var height_tiles := 3:
	set(value):
		height_tiles = value
		queue_redraw()
@export var start_offset := 0.0
## 0 = config times.
@export var on_time := 0.0
@export var off_time := 0.0

var phase := Phase.OFF
var _t := 0.0
var _hit_cooldowns := {}
var _shape := RectangleShape2D.new()


func _ready() -> void:
	_t = start_offset
	z_index = 2


func cycle_length() -> float:
	return _off() + CONFIG.fire_warning_time + _on()


func _off() -> float:
	return off_time if off_time > 0.0 else CONFIG.fire_off_time


func _on() -> float:
	return on_time if on_time > 0.0 else CONFIG.fire_on_time


func is_burning() -> bool:
	return phase == Phase.ON


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	var c := fposmod(_t, cycle_length())
	var next := Phase.OFF
	if c >= _off() + CONFIG.fire_warning_time:
		next = Phase.ON
	elif c >= _off():
		next = Phase.WARNING
	if next == Phase.ON and phase != Phase.ON:
		Sfx.cue(&"fire", self)
	phase = next
	for key in _hit_cooldowns.keys():
		_hit_cooldowns[key] -= delta
		if _hit_cooldowns[key] <= 0.0:
			_hit_cooldowns.erase(key)
	if phase == Phase.ON:
		var h := height_tiles * 16.0
		_shape.size = Vector2(10, h)
		for hurt in SpaceQuery.knight_hurtboxes(get_world_2d(), _shape, Transform2D(0.0, global_position + Vector2(0, -h * 0.5))):
			if not _hit_cooldowns.has(hurt):
				_hit_cooldowns[hurt] = CONFIG.fire_hit_interval
				hurt.receive_hit(DamageEvent.create(1, DamageEvent.Category.HOT_GROUND, self))
	queue_redraw()


func _draw() -> void:
	# Nozzle: an iron grate set into the floor; it glows during the warning.
	draw_rect(Rect2(-7, -3, 14, 3), Color(0.12, 0.1, 0.1))
	draw_rect(Rect2(-6, -2, 12, 1), Color(0.45, 0.32, 0.25) if phase != Phase.WARNING else Color(1.0, 0.55, 0.2))
	var h := height_tiles * 16.0
	match phase:
		Phase.WARNING:
			for i in 3:
				var y := -4.0 - fposmod(_t * 40.0 + i * 5.0, 12.0)
				draw_rect(Rect2(-3 + i * 3, y, 2, 2), Color(1.0, 0.6, 0.2, 0.9))
		Phase.ON:
			var rows := int(h / 4.0)
			for i in rows:
				var y := -4.0 - i * 4.0
				var w := 10.0 - 4.0 * (float(i) / rows) + sin(_t * 30.0 + i) * 1.5
				var col := Color(1.0, 0.85, 0.35) if i % 3 == 0 else (Color(1.0, 0.5, 0.15) if i % 3 == 1 else Color(0.95, 0.3, 0.1))
				draw_rect(Rect2(-w * 0.5, y - 4.0, w, 4.0), col)
	if Engine.is_editor_hint():
		draw_rect(Rect2(-5, -h, 10, h), Color(1, 0.4, 0.1, 0.25), false, 1.0)
