@tool
class_name BreakableBlock
extends StaticBody2D
## A cracked block of terrain. It is solid like the world until a heavy (charged) slash or a
## blast breaks it; ordinary hits only chip it (a spark and a "tink", which teaches the charged
## slash). Broken blocks stay broken for the run (saved under the level's id). Used for hidden
## rooms, shortcuts and cracked floors. Origin = top-left; size in whole tiles.

const TILESET := preload("res://assets/sprites/world_tileset.png")
const PREFIX := "break:"

signal broken

@export var block_id := ""
@export var size_tiles := Vector2i(1, 2):
	set(value):
		size_tiles = value.max(Vector2i.ONE)
		_rebuild()
## Tileset cell the block is drawn with (the level theme's fill tile).
@export var tile_region := Rect2(16, 16, 16, 16):
	set(value):
		tile_region = value
		queue_redraw()

var is_broken := false
var _body_shape: CollisionShape2D
var _hurtbox: HurtboxComponent


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_rebuild()
	if Engine.is_editor_hint():
		return
	if block_id != "" and RunState.current().puzzles.has_state(SaveIds.level_key(self), PREFIX + block_id):
		_remove(false)


func _rebuild() -> void:
	var px := Vector2(size_tiles) * 16.0
	if _body_shape == null:
		_body_shape = CollisionShape2D.new()
		add_child(_body_shape, false, Node.INTERNAL_MODE_FRONT)
		_hurtbox = HurtboxComponent.new()
		_hurtbox.collision_layer = 1 << 6
		_hurtbox.collision_mask = 0
		_hurtbox.entity = self
		var hurt_shape := CollisionShape2D.new()
		hurt_shape.shape = RectangleShape2D.new()
		_hurtbox.add_child(hurt_shape)
		add_child(_hurtbox, false, Node.INTERNAL_MODE_FRONT)
		if not Engine.is_editor_hint():
			_hurtbox.hit_received.connect(_on_hit)
	var box := RectangleShape2D.new()
	box.size = px
	_body_shape.shape = box
	_body_shape.position = px * 0.5
	# The hurtbox sticks out 2 px so a knight's line of sight reaches it past the block's own
	# solid body.
	var hurt := _hurtbox.get_child(0) as CollisionShape2D
	(hurt.shape as RectangleShape2D).size = px + Vector2(4, 4)
	hurt.position = px * 0.5
	queue_redraw()


func _on_hit(event: DamageEvent) -> void:
	if is_broken or event.category != DamageEvent.Category.MELEE:
		return
	var centre := global_position + Vector2(size_tiles) * 8.0
	if event.heavy or event.blast:
		Sfx.cue(&"break", self)
		Fx.burst(self, centre, Color(0.6, 0.5, 0.42), 14, 90.0, 0.5)
		Fx.shake(self, 1.5, 0.15)
		_remove(true)
	else:
		Sfx.cue(&"arrow_hit", self)
		Fx.spark(self, centre)


func _remove(record: bool) -> void:
	is_broken = true
	if record and block_id != "":
		RunState.current().puzzles.set_state(SaveIds.level_key(self), PREFIX + block_id, {"broken": true})
	collision_layer = 0
	_hurtbox.enabled = false
	visible = false
	broken.emit()


func _draw() -> void:
	for y in size_tiles.y:
		for x in size_tiles.x:
			draw_texture_rect_region(TILESET, Rect2(x * 16, y * 16, 16, 16), tile_region)
	# Cracks: a dark zig-zag across each tile, readable on every theme.
	var dark := Color(0.08, 0.06, 0.06, 0.85)
	for y in size_tiles.y:
		for x in size_tiles.x:
			var o := Vector2(x * 16, y * 16)
			draw_line(o + Vector2(3, 2), o + Vector2(7, 7), dark, 1.0)
			draw_line(o + Vector2(7, 7), o + Vector2(5, 11), dark, 1.0)
			draw_line(o + Vector2(7, 7), o + Vector2(13, 9), dark, 1.0)
			draw_line(o + Vector2(5, 11), o + Vector2(8, 15), dark, 1.0)
