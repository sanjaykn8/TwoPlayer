@tool
class_name SpringMushroom
extends Area2D
## A bouncy mushroom (the tileset's large red mushroom). A knight touching its cap while not
## rising is launched upward to `height_tiles` above the cap (0 = config default). The origin is
## on the floor surface at the mushroom's centre; the mushroom fills the tile above it.

const CONFIG := preload("res://resources/config/mechanism_config.tres")
const TILESET := preload("res://assets/sprites/world_tileset.png")
## world_tileset.png (7,5): large red mushroom.
const MUSHROOM := Rect2(112, 80, 16, 16)

signal bounced(knight: Knight)

@export var height_tiles := 0.0

var _squash := 0.0
var _cooldowns := {}


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 << 2  # knight bodies
	monitorable = false
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(12, 10)
	shape.shape = box
	shape.position = Vector2(0, -7)
	add_child(shape, false, Node.INTERNAL_MODE_FRONT)


func launch_speed(knight: Knight) -> float:
	var tiles := height_tiles if height_tiles > 0.0 else CONFIG.spring_height_tiles
	# Rise from the cap (about 10 px above the floor) to `tiles` above it: v = sqrt(2 g h).
	return sqrt(2.0 * knight.config.rise_gravity * (tiles * 16.0 + 4.0))


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_squash = maxf(_squash - delta * 4.0, 0.0)
	for key in _cooldowns.keys():
		_cooldowns[key] -= delta
		if _cooldowns[key] <= 0.0:
			_cooldowns.erase(key)
	for body in get_overlapping_bodies():
		var knight := body as Knight
		if knight == null or knight.is_dead() or knight.is_climbing() or knight.velocity.y < 0.0:
			continue
		if _cooldowns.has(knight.get_instance_id()):
			continue
		_cooldowns[knight.get_instance_id()] = CONFIG.spring_cooldown
		knight.bounce(launch_speed(knight))
		_squash = 1.0
		Sfx.cue(&"spring", self)
		bounced.emit(knight)
	if _squash > 0.0:
		queue_redraw()


func _draw() -> void:
	var s := 1.0 - 0.3 * _squash
	var h := 16.0 * s
	draw_texture_rect_region(TILESET, Rect2(-8 - (1.0 - s) * 4.0, -h, 16 + (1.0 - s) * 8.0, h), MUSHROOM)
