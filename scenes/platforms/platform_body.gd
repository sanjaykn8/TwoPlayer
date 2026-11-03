@tool
class_name PlatformBody
extends AnimatableBody2D
## Base for the floating platforms (moving, timed, disappearing, collapsing).
## - Drawn from res://assets/sprites/platforms.png (9 px tall pieces; row = material).
## - Origin is the TOP-LEFT; `width_tiles` x 16 px wide.
## - One-way (layer 2, knights can drop through) or solid (layer 1). Knights and slimes are
##   carried by Godot's moving-platform handling (AnimatableBody2D, sync_to_physics).
## - Always in the "unsafe_ground" group: a fall never respawns a knight onto one.
## - Collision is only ever switched off through set_collision_enabled(); is_occupied()
##   lets subclasses wait until nobody is inside before switching it back on.

const SHEET := preload("res://assets/sprites/platforms.png")
const UNSAFE_GROUND := &"unsafe_ground"
const HEIGHT := 9.0
const ONE_WAY_THICKNESS := 6.0
## Bodies and hurtboxes that block reappearance: players (3), enemies (4), player hurtboxes (5).
const OCCUPANT_MASK := SpaceQuery.OCCUPANT_MASK

@export_range(1, 16) var width_tiles := 3:
	set(value):
		width_tiles = value
		_rebuild()
@export var one_way := true:
	set(value):
		one_way = value
		_rebuild()
## Stable id within its level (Phase 8 saves). Empty: its live state is not saved.
@export var save_id := ""
## platforms.png row: 0 grass, 1 sand/wood, 2 orange, 3 ice.
@export_range(0, 3) var material_row := 1:
	set(value):
		material_row = value
		queue_redraw()

## Visual-only state used by subclasses (collision never moves with these).
var visual_alpha := 1.0
var visual_offset := Vector2.ZERO
var visual_tint := Color.WHITE

var _shape_node: CollisionShape2D
var _collision_on := true


func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group(UNSAFE_GROUND)
	_rebuild()


func width_px() -> float:
	return width_tiles * 16.0


func collision_enabled() -> bool:
	return _collision_on


func set_collision_enabled(on: bool) -> void:
	_collision_on = on
	if _shape_node != null:
		_shape_node.set_deferred(&"disabled", not on)


## True when a knight (body or hurtbox) or an enemy overlaps the platform's space.
func is_occupied() -> bool:
	var rect := Rect2(global_position - Vector2.ONE, Vector2(width_px(), HEIGHT) + Vector2(2, 2))
	return SpaceQuery.rect_occupied(get_world_2d(), rect, OCCUPANT_MASK, [get_rid()])


## The platform's solid space below its top surface (global). A knight standing ON the
## platform does not intersect it; one inside it does.
func interior_rect() -> Rect2:
	return Rect2(global_position + Vector2(0, 1), Vector2(width_px(), HEIGHT - 1))


## Restoring a save found someone inside this platform: become solid only once they leave
## (timed and collapsing platforms override this; others cannot vanish).
func fade_in_safely() -> void:
	pass


## Live state for saves (subclasses). Empty: nothing to save.
func capture_live() -> Dictionary:
	return {}


## Applies a captured live state (subclasses validate their own fields).
func apply_live(_data: Dictionary) -> void:
	pass


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _shape_node == null:
		_shape_node = CollisionShape2D.new()
		add_child(_shape_node, false, Node.INTERNAL_MODE_FRONT)
	var thickness := ONE_WAY_THICKNESS if one_way else HEIGHT
	var box := RectangleShape2D.new()
	box.size = Vector2(width_px(), thickness)
	_shape_node.shape = box
	_shape_node.position = Vector2(width_px() * 0.5, thickness * 0.5)
	_shape_node.one_way_collision = one_way
	_shape_node.disabled = not _collision_on
	collision_layer = 2 if one_way else 1
	collision_mask = 0
	queue_redraw()


func _draw() -> void:
	if visual_alpha <= 0.0:
		return
	var colour := Color(visual_tint, visual_tint.a * visual_alpha)
	# The sheet has a short piece (column 0) and a two-cell long piece (columns 1 + 2) with
	# no repeatable middle: lay long pieces in pairs, finishing odd widths with a short one.
	for i in width_tiles:
		var piece := 0
		if not (i == width_tiles - 1 and width_tiles % 2 == 1):
			piece = 1 if i % 2 == 0 else 2
		var src := Rect2(piece * 16, material_row * 16, 16, 16)
		draw_texture_rect_region(SHEET, Rect2(Vector2(i * 16, 0) + visual_offset, Vector2(16, 16)), src, colour)
