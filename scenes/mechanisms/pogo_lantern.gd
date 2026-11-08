@tool
class_name PogoLantern
extends Node2D
## A hanging spirit lantern. It has no body (knights pass through it) but it can be struck:
## a downward air attack that hits it bounces the knight up (the knight's own pogo rule), so
## chains of lanterns make skill routes over pits and spikes. It flashes when struck.

const CONFIG := preload("res://resources/config/mechanism_config.tres")

signal struck(player_id: int)

var _flash := 0.0
var _t := 0.0
var _hurtbox: HurtboxComponent


func _ready() -> void:
	_hurtbox = HurtboxComponent.new()
	_hurtbox.collision_layer = 1 << 6
	_hurtbox.collision_mask = 0
	_hurtbox.entity = self
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(12, 12)
	shape.shape = box
	_hurtbox.add_child(shape)
	add_child(_hurtbox, false, Node.INTERNAL_MODE_FRONT)
	if not Engine.is_editor_hint():
		_hurtbox.hit_received.connect(_on_hit)


func _on_hit(event: DamageEvent) -> void:
	if event.category != DamageEvent.Category.MELEE:
		return
	_flash = 0.25
	Sfx.cue(&"charge_ready", self)
	Fx.burst(self, global_position, Color(0.6, 0.95, 1.0), 6, 50.0, 0.3)
	struck.emit(event.attacker_player_id)


func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(_flash - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	var bob := roundf(sin(_t * 3.0))
	var o := Vector2(0, bob)
	var glow := Color(0.55, 0.95, 1.0) if _flash <= 0.0 else Color(1, 1, 1)
	draw_line(Vector2(0, -12), o + Vector2(0, -6), Color(0.25, 0.22, 0.2), 1.0)
	draw_rect(Rect2(o + Vector2(-5, -6), Vector2(10, 12)), Color(0.12, 0.1, 0.1))
	draw_rect(Rect2(o + Vector2(-4, -5), Vector2(8, 10)), glow.darkened(0.25))
	draw_rect(Rect2(o + Vector2(-2, -3), Vector2(4, 6)), glow)
	draw_rect(Rect2(o + Vector2(-5, -7), Vector2(10, 2)), Color(0.45, 0.35, 0.25))
	draw_rect(Rect2(o + Vector2(-5, 5), Vector2(10, 2)), Color(0.45, 0.35, 0.25))
	# A small down arrow under it hints at the downward strike.
	var a := o + Vector2(0, 11)
	draw_rect(Rect2(a + Vector2(-1, 0), Vector2(2, 2)), Color(0.6, 0.95, 1.0, 0.6))
	draw_rect(Rect2(a + Vector2(-2, -1), Vector2(4, 1)), Color(0.6, 0.95, 1.0, 0.6))
